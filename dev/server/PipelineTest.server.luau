--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pipeline = require(ReplicatedStorage.GuardLib.Server.Pipeline)
local Result = require(ReplicatedStorage.GuardLib.Shared.Result)
local Defaults = require(ReplicatedStorage.GuardLib.Server.Config.Defaults)

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

-- Поддельный игрок: compose его только передаёт, поэтому подойдёт любая таблица
local fakePlayer = { Name = "TestPlayer" } :: any

local function makeCtx(...: any): Pipeline.Context
	return {
		player = fakePlayer,
		endpointName = "test",
		config = { adminOnly = false, rateLimit = "disabled", logLevel = "info" },
		globalConfig = Defaults,
		args = table.pack(...),
	}
end

-- P1. Без middleware: обработчик получает игрока и аргументы
do
	local gotPlayer, gotA, gotB
	local pipeline = Pipeline.compose({}, function(player, a, b)
		gotPlayer, gotA, gotB = player, a, b
		return a + b
	end)
	local result = pipeline(makeCtx(2, 3))
	check("P1. handler gets the player", gotPlayer == fakePlayer)
	check("P1. handler gets the arguments", gotA == 2 and gotB == 3)
	check("P1. result is ok with the return value", result.ok and result.values.n == 1 and result.values[1] == 5)
end

-- P2. Несколько возвращаемых значений с nil посередине
do
	local pipeline = Pipeline.compose({}, function()
		return 1, nil, 3
	end)
	local result = pipeline(makeCtx())
	check("P2. n counts all values including nil", result.ok and result.values.n == 3)
	check("P2. nil in the middle is kept", result.ok and result.values[2] == nil and result.values[3] == 3)
end

-- P3. nil среди аргументов доходит до обработчика
do
	local argCount = -1
	local gotSecond
	local pipeline = Pipeline.compose({}, function(_player, ...)
		argCount = select("#", ...)
		gotSecond = select(2, ...)
	end)
	pipeline(makeCtx(nil, "x"))
	check("P3. nil argument is passed through", argCount == 2 and gotSecond == "x")
end

-- P4. Обработчик ничего не вернул
do
	local pipeline = Pipeline.compose({}, function() end)
	local result = pipeline(makeCtx())
	check("P4. no return values → ok with n = 0", result.ok and result.values.n == 0)
end

-- P5. Порядок выполнения: матрёшка
do
	local log: { string } = {}
	local function tracer(label: string): Pipeline.Middleware
		return function(_ctx, nextFn)
			table.insert(log, `before {label}`)
			local result = nextFn()
			table.insert(log, `after {label}`)
			return result
		end
	end
	local pipeline = Pipeline.compose({ tracer("A"), tracer("B") }, function()
		table.insert(log, "handler")
	end)
	pipeline(makeCtx())
	check("P5. middleware order", table.concat(log, ", ") == "before A, before B, handler, after B, after A")
end

-- P6. Middleware останавливает запрос
do
	local handlerCalled = false
	local afterA = false
	local pipeline = Pipeline.compose({
		function(_ctx, nextFn)
			local result = nextFn()
			afterA = true
			return result
		end,
		function(_ctx, _nextFn)
			return Result.err("FORBIDDEN")
		end,
	}, function()
		handlerCalled = true
	end)
	local result = pipeline(makeCtx())
	check("P6. handler is not called", not handlerCalled)
	check("P6. outer middleware still finishes", afterA)
	check("P6. error result is returned", not result.ok and result.code == "FORBIDDEN")
end

-- P7. Middleware видит контекст
do
	local seenName
	local pipeline = Pipeline.compose({
		function(ctx, nextFn)
			seenName = ctx.endpointName
			return nextFn()
		end,
	}, function() end)
	pipeline(makeCtx())
	check("P7. middleware reads ctx.endpointName", seenName == "test")
end

-- P8. Ошибки не перехватываются: это работа Transport
do
	local pipeline = Pipeline.compose({}, function()
		error("boom")
	end)
	local ok = pcall(pipeline, makeCtx())
	check("P8. handler error propagates out of the pipeline", not ok)
end

-- P9. Пайплайн можно запускать много раз
do
	local pipeline = Pipeline.compose({}, function(_player, x)
		return x * 10
	end)
	local r1 = pipeline(makeCtx(1))
	local r2 = pipeline(makeCtx(2))
	check("P9. pipeline is reusable", r1.ok and r2.ok and r1.values[1] == 10 and r2.values[1] == 20)
end

print(`Done: {passed} passed, {failed} failed`)
