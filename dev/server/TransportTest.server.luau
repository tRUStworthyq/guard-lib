--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Transport = require(ReplicatedStorage.GuardLib.Server.Transport)
local EndpointBuilder = require(ReplicatedStorage.GuardLib.Server.EndpointBuilder)
local Logger = require(ReplicatedStorage.GuardLib.Server.Log.Logger)
local Pipeline = require(ReplicatedStorage.GuardLib.Server.Pipeline)
local Result = require(ReplicatedStorage.GuardLib.Shared.Result)
local Types = require(ReplicatedStorage.GuardLib.Server.Config.Types)
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

local fakePlayer = { Name = "Tester", UserId = 7 } :: any

local function collector(): (Logger.Logger, { Logger.LogRecord })
	local records: { Logger.LogRecord } = {}
	local logger = Logger.new({
		function(record: Logger.LogRecord)
			table.insert(records, record)
		end,
	})
	return logger, records
end

local function definition(kind: EndpointBuilder.Kind, rateLimit: Types.RateLimitSettings): EndpointBuilder.Definition
	return {
		name = "buyItem",
		kind = kind,
		config = { adminOnly = false, rateLimit = rateLimit, logLevel = "info" },
		handler = function() end,
	}
end

local function limit(onExceed: Types.OnExceed): Types.RateLimitConfig
	return { bucketCapacity = 1, refillPerSecond = 1, onExceed = onExceed }
end

-- ===== handle =====

do
	local logger = collector()
	local seenCtx: Pipeline.Context? = nil
	local result = Transport.handle(definition("invoke", "disabled"), Defaults, function(ctx)
		seenCtx = ctx
		return Result.ok("done")
	end, logger, fakePlayer, "sword", nil, 3)

	local ctx = seenCtx
	check("H1. pipeline result is returned", result.ok and result.values[1] == "done")
	check("H1. ctx has the player", ctx ~= nil and ctx.player == fakePlayer)
	check(
		"H1. ctx has endpoint name and config",
		ctx ~= nil and ctx.endpointName == "buyItem" and ctx.config.logLevel == "info"
	)
	check("H1. ctx has the global config", ctx ~= nil and ctx.globalConfig == Defaults)
	check(
		"H1. all args are packed, including nil",
		ctx ~= nil and ctx.args.n == 3 and ctx.args[1] == "sword" and ctx.args[2] == nil and ctx.args[3] == 3
	)
end

do
	local logger = collector()
	local result = Transport.handle(definition("invoke", "disabled"), Defaults, function()
		return Result.err("FORBIDDEN")
	end, logger, fakePlayer)
	check("H2. error result from pipeline is returned as is", not result.ok and result.code == "FORBIDDEN")
end

do
	local logger, records = collector()
	local ok, result = pcall(Transport.handle, definition("invoke", "disabled"), Defaults, function(): Result.Result
		error("secret internal details")
	end, logger, fakePlayer)

	check("H3. handle never throws", ok)
	check("H3. thrown error becomes INTERNAL", ok and not result.ok and result.code == "INTERNAL")
	local r = records[1]
	check("H3. error is logged at error level", r ~= nil and r.level == "error" and r.message == "handler error")
	check(
		"H3. log contains the original error text",
		r ~= nil and string.find(tostring(r.fields.error), "secret internal details", 1, true) ~= nil
	)
	check("H3. log has endpoint and player", r ~= nil and r.fields.endpoint == "buyItem" and r.fields.userId == 7)
end

-- ===== toWire =====

-- Упаковывает все значения toWire, чтобы посчитать их вместе с nil
local function wire(result: Result.Result, rateLimit: Types.RateLimitSettings)
	return table.pack(Transport.toWire(result, definition("invoke", rateLimit).config))
end

do
	local w = wire(Result.ok(1, nil, 3), "disabled")
	check("W1. ok → true + values", w[1] == true and w[2] == 1 and w[4] == 3)
	check("W1. nil in the middle is kept", w.n == 4 and w[3] == nil)
end

do
	local w = wire(Result.ok(), "disabled")
	check("W2. ok without values → just true", w.n == 1 and w[1] == true)
end

do
	local w = wire(Result.err("FORBIDDEN"), "disabled")
	check("W3. error → false + code", w.n == 2 and w[1] == false and w[2] == "FORBIDDEN")
end

do
	local w = wire(Result.err("RATE_LIMITED"), limit("reject"))
	check("W4. rate limited with reject → false + code", w[1] == false and w[2] == "RATE_LIMITED")
end

do
	local w = wire(Result.err("RATE_LIMITED"), limit("ignore"))
	check("W5. rate limited with ignore → empty success", w.n == 1 and w[1] == true)
end

do
	local w = wire(Result.err("FORBIDDEN"), limit("ignore"))
	check("W6. ignore applies only to RATE_LIMITED", w[1] == false and w[2] == "FORBIDDEN")
end

do
	local w = wire(Result.err("INTERNAL"), "disabled")
	check("W7. internal error → false + INTERNAL", w[1] == false and w[2] == "INTERNAL")
end

-- ===== bind =====

do
	local folder = Instance.new("Folder")
	local logger = collector()
	local noopRun = function(): Result.Result
		return Result.ok()
	end

	local fn = Transport.bind(folder, definition("invoke", "disabled"), Defaults, noopRun, logger)
	check("B1. invoke creates a RemoteFunction", fn:IsA("RemoteFunction"))
	check("B1. remote is named after the endpoint", fn.Name == "buyItem")
	check("B1. remote is placed into the folder", fn.Parent == folder)

	local eventDef = definition("event", "disabled")
	eventDef.name = "jump"
	local ev = Transport.bind(folder, eventDef, Defaults, noopRun, logger)
	check("B2. event creates a RemoteEvent", ev:IsA("RemoteEvent"))
	check("B2. remote is named after the endpoint", ev.Name == "jump" and ev.Parent == folder)

	folder:Destroy()
end

print(`Done: {passed} passed, {failed} failed`)
