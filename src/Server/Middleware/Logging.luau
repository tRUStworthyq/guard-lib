--!strict
local Types = require(script.Parent.Parent.Config.Types)
local Pipeline = require(script.Parent.Parent.Pipeline)
local Logger = require(script.Parent.Parent.Log.Logger)
local Result = require(script.Parent.Parent.Parent.Shared.Result)

local LEVEL_BY_CODE: { [Result.ErrorCode]: Types.LogLevel } = {
	RATE_LIMITED = "info",
	FORBIDDEN = "warn",
	INVALID_ARGS = "warn",
	INTERNAL = "error",
}

local MESSAGE_BY_CODE: { [Result.ErrorCode]: string } = {
	RATE_LIMITED = "rate limited",
	FORBIDDEN = "forbidden",
	INVALID_ARGS = "invalid arguments",
	INTERNAL = "internal error",
}

local function createLogging(logger: Logger.Logger, clock: (() -> number)?): Pipeline.Middleware
	local now: () -> number = if clock ~= nil then clock else os.clock

	return function(ctx: Pipeline.Context, nextFn: Pipeline.Next): Result.Result
		local startedAt = now()
		local result = nextFn()
		local durationMs = (now() - startedAt) * 1000

		local level: Types.LogLevel = if result.ok then "debug" else LEVEL_BY_CODE[result.code]
		local message = if result.ok then "ok" else MESSAGE_BY_CODE[result.code]

		if Logger.isEnabled(level, ctx.config.logLevel) then
			local fields: { [string]: any } = {
				endpoint = ctx.endpointName,
				player = ctx.player.Name,
				userId = ctx.player.UserId,
				durationMs = math.round(durationMs * 100) / 100,
			}
			if not result.ok then
				fields.code = result.code
			end

			logger:log(level, message, fields)
		end

		return result
	end
end

return createLogging
