--!strict
local Types = require(script.Parent.Parent.Config.Types)
local Pipeline = require(script.Parent.Parent.Parent.Server.Pipeline)
local Result = require(script.Parent.Parent.Parent.Shared.Result)

local RateLimiter = {}
RateLimiter.__index = RateLimiter

type Bucket = { tokens: number, updatedAt: number }

type RateLimiterData = {
	_clock: () -> number,
	_buckets: { [number]: { [string]: Bucket } }, -- UserId -> имя эндпоинта -> бакет
}

export type RateLimiter = typeof(setmetatable({} :: RateLimiterData, RateLimiter))

function RateLimiter.new(clock: (() -> number)?): RateLimiter
	local clk = if clock ~= nil then clock else os.clock

	local data: RateLimiterData = {
		_clock = clk,
		_buckets = {},
	}

	return setmetatable(data, RateLimiter)
end

function RateLimiter.tryConsume(
	self: RateLimiter,
	userId: number,
	endpointName: string,
	config: Types.RateLimitConfig
): boolean
	local now = self._clock()

	local playerBuckets = self._buckets[userId]
	if playerBuckets == nil then
		playerBuckets = {}
		self._buckets[userId] = playerBuckets
	end

	local bucket = playerBuckets[endpointName]
	if bucket == nil then
		-- Новое ведро создаётся полным: игрок может сразу сделать залп
		bucket = { tokens = config.bucketCapacity, updatedAt = now }
		playerBuckets[endpointName] = bucket
	end

	-- Ленивое восполнение: сколько токенов накопилось с прошлого запроса, но не больше ёмкости
	local elapsed = now - bucket.updatedAt
	bucket.tokens = math.min(config.bucketCapacity, bucket.tokens + elapsed * config.refillPerSecond)
	bucket.updatedAt = now

	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

function RateLimiter.middleware(self: RateLimiter): Pipeline.Middleware
	return function(ctx: Pipeline.Context, nextFn: Pipeline.Next)
		if ctx.config.rateLimit == "disabled" then
			return nextFn()
		end
		if self:tryConsume(ctx.player.UserId, ctx.endpointName, ctx.config.rateLimit) then
			return nextFn()
		end
		return Result.err("RATE_LIMITED")
	end
end

function RateLimiter.forgetPlayer(self: RateLimiter, userId: number)
	self._buckets[userId] = nil
end

return RateLimiter
