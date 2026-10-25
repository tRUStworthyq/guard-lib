--!strict
local Types = require(script.Parent.Parent.Config.Types)

local Logger = {}
Logger.__index = Logger

export type LogRecord = {
	level: Types.LogLevel,
	message: string,
	fields: { [string]: any },
	timestamp: number,
}

export type Sink = (record: LogRecord) -> ()

type LoggerData = {
	_sinks: { Sink },
}

export type Logger = typeof(setmetatable({} :: LoggerData, Logger))

local LEVEL_ORDER: { [Types.LogLevel]: number } = { debug = 1, info = 2, warn = 3, error = 4 }

function Logger.isEnabled(level: Types.LogLevel, threshold: Types.LogLevel): boolean
	return LEVEL_ORDER[level] >= LEVEL_ORDER[threshold]
end

function Logger.new(sinks: { Sink }): Logger
	local data: LoggerData = {
		_sinks = table.clone(sinks),
	}
	return setmetatable(data, Logger)
end

function Logger.log(self: Logger, level: Types.LogLevel, message: string, fields: { [string]: any }?)
	local logRecord: LogRecord = {
		level = level,
		message = message,
		fields = if fields ~= nil then fields else {},
		timestamp = os.time(),
	}

	for _, sink in self._sinks do
		local ok, err = pcall(sink :: any, logRecord)
		if not ok then
			warn(`GuardLib: log sink failed: {err}`)
		end
	end
end

return Logger
