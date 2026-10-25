--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.GuardLib.Server.Log.Logger)
local consoleSink = require(ReplicatedStorage.GuardLib.Server.Log.ConsoleSink)
local createLogging = require(ReplicatedStorage.GuardLib.Server.Middleware.Logging)
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

-- Sink, который складывает записи в массив
local function collector(): (Logger.Sink, { Logger.LogRecord })
	local records: { Logger.LogRecord } = {}
	local function sink(record: Logger.LogRecord)
		table.insert(records, record)
	end
	return sink, records
end

-- ===== Logger.isEnabled =====

check("L1. warn passes info threshold", Logger.isEnabled("warn", "info"))
check("L1. info passes info threshold", Logger.isEnabled("info", "info"))
check("L1. debug does not pass info threshold", not Logger.isEnabled("debug", "info"))
check("L1. error passes debug threshold", Logger.isEnabled("error", "debug"))
check("L1. debug does not pass error threshold", not Logger.isEnabled("debug", "error"))

-- ===== Logger.log =====

do
	local sink1, records1 = collector()
	local sink2, records2 = collector()
	local logger = Logger.new({ sink1, sink2 })
	logger:log("info", "hello", { a = 1 })
	local r = records1[1]
	check("L2. record goes to every sink", #records1 == 1 and #records2 == 1)
	check("L2. record has level and message", r ~= nil and r.level == "info" and r.message == "hello")
	check("L2. record has fields", r ~= nil and r.fields.a == 1)
	check("L2. record has a timestamp", r ~= nil and type(r.timestamp) == "number")
end

do
	local sink, records = collector()
	Logger.new({ sink }):log("debug", "no fields")
	check("L3. fields default to an empty table", records[1] ~= nil and next(records[1].fields) == nil)
end

do
	local sink, records = collector()
	local function brokenSink(_record: Logger.LogRecord)
		error("sink is down")
	end
	local logger = Logger.new({ brokenSink, sink })
	local ok = pcall(function()
		logger:log("warn", "still delivered")
	end)
	check("L4. broken sink does not break log()", ok)
	check("L4. sinks after a broken one still get the record", #records == 1)
end

do
	local sink1, records1 = collector()
	local sink2, records2 = collector()
	local sinks = { sink1 }
	local logger = Logger.new(sinks)
	table.insert(sinks, sink2) -- меняем исходный список после создания
	logger:log("info", "x")
	check("L5. logger keeps its own copy of the sinks list", #records1 == 1 and #records2 == 0)
end

-- ===== consoleSink =====

do
	local allOk = true
	local levels: { Types.LogLevel } = { "debug", "info", "warn", "error" }
	for _, level: Types.LogLevel in levels do
		local record: Logger.LogRecord = {
			level = level,
			message = `console sink {level} check`,
			fields = { b = 2, a = 1 },
			timestamp = os.time(),
		}
		local ok = pcall(consoleSink, record)
		allOk = allOk and ok
	end

	local emptyRecord: Logger.LogRecord = { level = "info", message = "no fields", fields = {}, timestamp = os.time() }
	local okEmpty = pcall(consoleSink, emptyRecord)

	check("C1. consoleSink prints every level without errors", allOk)
	check("C1. consoleSink handles empty fields", okEmpty)
end

-- ===== Logging middleware =====

local now = 0
local function fakeClock(): number
	return now
end

local function makeCtx(logLevel: Types.LogLevel): Pipeline.Context
	return {
		player = { Name = "Tester", UserId = 7 } :: any,
		endpointName = "buyItem",
		config = { adminOnly = false, rateLimit = "disabled", logLevel = logLevel },
		globalConfig = Defaults,
		args = table.pack(),
	}
end

-- Пайплайн: Logging → (необязательная «заглушка» с ошибкой) → обработчик
local function run(logLevel: Types.LogLevel, failWith: Result.ErrorCode?)
	local sink, records = collector()
	local middlewares: { Pipeline.Middleware } = { createLogging(Logger.new({ sink }), fakeClock) }
	if failWith ~= nil then
		table.insert(middlewares, function(_ctx, _nextFn)
			return Result.err(failWith)
		end)
	end
	local pipeline = Pipeline.compose(middlewares, function()
		now += 0.0123 -- обработчик «работает» 12.3 мс
		return "done"
	end)
	now = 0
	local result = pipeline(makeCtx(logLevel))
	return result, records
end

do
	local _, records = run("debug")
	local r = records[1]
	check("G1. success is logged at debug", r ~= nil and r.level == "debug" and r.message == "ok")
	check(
		"G1. fields describe the call",
		r ~= nil and r.fields.endpoint == "buyItem" and r.fields.player == "Tester" and r.fields.userId == 7
	)
	check("G1. success has no code field", r ~= nil and r.fields.code == nil)
	check("G2. duration is measured in ms and rounded", r ~= nil and r.fields.durationMs == 12.3)
end

do
	local _, records = run("info")
	check("G3. success is not logged with info threshold", #records == 0)
end

do
	local result, records = run("info", "RATE_LIMITED")
	local r = records[1]
	check("G4. rate limited is logged at info", r ~= nil and r.level == "info" and r.message == "rate limited")
	check("G4. error code is in fields", r ~= nil and r.fields.code == "RATE_LIMITED")
	check("G4. result is passed through", not result.ok and result.code == "RATE_LIMITED")
end

do
	local _, records = run("info", "FORBIDDEN")
	check("G5. forbidden is logged at warn", records[1] ~= nil and records[1].level == "warn")
end

do
	local _, records = run("error", "FORBIDDEN")
	check("G6. warn is not logged with error threshold", #records == 0)
end

do
	local result = run("info")
	check("G7. success result is passed through", result.ok and result.values[1] == "done")
end

print(`Done: {passed} passed, {failed} failed`)
