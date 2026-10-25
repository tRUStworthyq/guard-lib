--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pipeline = require(ReplicatedStorage.GuardLib.Server.Pipeline)
local Types = require(ReplicatedStorage.GuardLib.Server.Config.Types)
local Defaults = require(ReplicatedStorage.GuardLib.Server.Config.Defaults)
local access = require(ReplicatedStorage.GuardLib.Server.Middleware.Access)
local RateLimiter = require(ReplicatedStorage.GuardLib.Server.Middleware.RateLimit)

local passed, failed = 0, 0

local function check(name: string, condition: boolean)
	if condition then
		passed += 1
		print("PASS", name)
	else
		failed += 1
		warn("FAIL", name)
	end
end

-- Поддельное время: тест сам решает, сколько секунд «прошло»
local now = 0
local function fakeClock(): number
	return now
end

local function limit(capacity: number, refill: number): Types.RateLimitConfig
	return { bucketCapacity = capacity, refillPerSecond = refill, onExceed = "reject" }
end

-- Вызывает tryConsume count раз и возвращает, сколько раз запрос был разрешён
local function consumeMany(
	limiter: RateLimiter.RateLimiter,
	count: number,
	userId: number,
	endpoint: string,
	config: Types.RateLimitConfig
): number
	local allowed = 0
	for _ = 1, count do
		if limiter:tryConsume(userId, endpoint, config) then
			allowed += 1
		end
	end
	return allowed
end

-- ===== RateLimiter.tryConsume =====

do
	now = 0
	local limiter = RateLimiter.new(fakeClock)
	check("R1. new bucket allows exactly capacity requests", consumeMany(limiter, 5, 1, "a", limit(3, 1)) == 3)
end

do
	now = 0
	local limiter = RateLimiter.new(fakeClock)
	local config = limit(3, 2)
	consumeMany(limiter, 3, 1, "a", config)
	now = 1 -- прошла секунда: +2 токена
	check("R2. tokens refill over time", consumeMany(limiter, 5, 1, "a", config) == 2)
end

do
	now = 0
	local limiter = RateLimiter.new(fakeClock)
	local config = limit(1, 0.5)
	consumeMany(limiter, 1, 1, "a", config)
	now = 1 -- +0.5 токена, ещё мало
	check("R3. fractional refill: not enough after 1s", not limiter:tryConsume(1, "a", config))
	now = 2 -- всего +1.0
	check("R3. fractional refill: enough after 2s", limiter:tryConsume(1, "a", config))
end

do
	now = 0
	local limiter = RateLimiter.new(fakeClock)
	local config = limit(2, 1)
	consumeMany(limiter, 2, 1, "a", config)
	now = 100 -- за 100 секунд накопилось бы 100, но ёмкость 2
	check("R4. refill is capped by capacity", consumeMany(limiter, 10, 1, "a", config) == 2)
end

do
	now = 0
	local limiter = RateLimiter.new(fakeClock)
	local config = limit(1, 1)
	consumeMany(limiter, 1, 1, "a", config)
	check("R5. buckets are separate per endpoint", limiter:tryConsume(1, "b", config))
	check("R6. buckets are separate per player", limiter:tryConsume(2, "a", config))
end

do
	now = 0
	local limiter = RateLimiter.new(fakeClock)
	local config = limit(1, 1)
	consumeMany(limiter, 1, 1, "a", config)
	limiter:forgetPlayer(1)
	check("R7. forgetPlayer gives a fresh full bucket", limiter:tryConsume(1, "a", config))
end

do
	now = 0
	local limiter = RateLimiter.new(fakeClock)
	local config = limit(1, 1)
	limiter:tryConsume(1, "a", config) -- потратили единственный токен
	now = 0.5
	limiter:tryConsume(1, "a", config) -- отклонён, токенов 0.5
	now = 1.0
	check("R8. rejected requests do not consume tokens", limiter:tryConsume(1, "a", config))
end

-- ===== Контекст для middleware =====

local globalConfig: Types.GlobalConfig = {
	adminIds = { 42 },
	logLevel = Defaults.logLevel,
	defaultRateLimit = Defaults.defaultRateLimit,
	cacheRegions = {},
	rejectExtraFields = true,
}

local function makeCtx(userId: number, config: Types.ResolvedEndpointConfig): Pipeline.Context
	return {
		player = { UserId = userId } :: any,
		endpointName = "test",
		config = config,
		globalConfig = globalConfig,
		args = table.pack(),
	}
end

local function runOnce(middleware: Pipeline.Middleware, ctx: Pipeline.Context)
	local handlerCalled = false
	local pipeline = Pipeline.compose({ middleware }, function()
		handlerCalled = true
	end)
	return pipeline(ctx), handlerCalled
end

-- ===== RateLimiter.middleware =====

do
	now = 0
	local limiter = RateLimiter.new(fakeClock)
	local ctx = makeCtx(1, { adminOnly = false, rateLimit = "disabled", logLevel = "info" })
	local allOk = true
	for _ = 1, 100 do
		local result = runOnce(limiter:middleware(), ctx)
		allOk = allOk and result.ok
	end
	check("M1. disabled rate limit never blocks", allOk)
end

do
	now = 0
	local limiter = RateLimiter.new(fakeClock)
	local middleware = limiter:middleware()
	local ctx = makeCtx(1, { adminOnly = false, rateLimit = limit(1, 1), logLevel = "info" })
	local first = runOnce(middleware, ctx)
	local second, handlerCalled = runOnce(middleware, ctx)
	check("M2. first request passes", first.ok)
	check("M2. second request is rate limited", not second.ok and second.code == "RATE_LIMITED")
	check("M2. handler is not called when limited", not handlerCalled)
end

-- ===== Access =====

do
	local open = { adminOnly = false, rateLimit = "disabled", logLevel = "info" } :: Types.ResolvedEndpointConfig
	local closed = { adminOnly = true, rateLimit = "disabled", logLevel = "info" } :: Types.ResolvedEndpointConfig

	local r1 = runOnce(access, makeCtx(7, open))
	check("A1. open endpoint passes for anyone", r1.ok)

	local r2 = runOnce(access, makeCtx(42, closed))
	check("A2. admin passes admin-only endpoint", r2.ok)

	local r3, handlerCalled = runOnce(access, makeCtx(7, closed))
	check("A3. non-admin gets FORBIDDEN", not r3.ok and r3.code == "FORBIDDEN")
	check("A3. handler is not called for non-admin", not handlerCalled)
end

print(`Done: {passed} passed, {failed} failed`)
