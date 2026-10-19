--!strict
local Types = require(script.Parent.Types)
local deepFreeze = require(script.Parent.Parent.Parent.Shared.Util.deepFreeze)

local defaultRateLimit: Types.RateLimitSettings = {
	bucketCapacity = 30,
	refillPerSecond = 15,
	onExceed = Types.OnExceed.reject,
}

local Defaults: Types.GlobalConfig = {
	adminIds = {},
	logLevel = Types.LogLevel.info,
	defaultRateLimit = defaultRateLimit,
	cacheRegions = {},
	rejectExtraFields = true,
}

return deepFreeze(Defaults)
