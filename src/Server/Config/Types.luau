--!strict
local deepFreeze = require(script.Parent.Parent.Parent.Shared.Util.deepFreeze)
local LogLevel = {
	debug = "debug" :: LogLevel,
	info = "info" :: LogLevel,
	warn = "warn" :: LogLevel,
	error = "error" :: LogLevel,
}

export type LogLevel = "debug" | "info" | "warn" | "error"

local OnExceed = {
	ignore = "ignore" :: OnExceed,
	reject = "reject" :: OnExceed,
}

export type OnExceed = "ignore" | "reject"

local CacheScope = {
	global = "global" :: CacheScope,
	player = "player" :: CacheScope,
}

export type CacheScope = "global" | "player"

export type RateLimitConfig = {
	bucketCapacity: number,
	refillPerSecond: number,
	onExceed: OnExceed,
}

export type RateLimitOverride = {
	bucketCapacity: number?,
	refillPerSecond: number?,
	onExceed: OnExceed?,
}

export type RateLimitSettings = RateLimitConfig | "disabled"

export type CacheRegionConfig = {
	scope: CacheScope,
	ttlSeconds: number,
	maxCountOfRecords: number,
}

export type GlobalConfig = {
	adminIds: { number },
	logLevel: LogLevel,
	defaultRateLimit: RateLimitSettings | "disabled",
	cacheRegions: { [string]: CacheRegionConfig },
	rejectExtraFields: boolean,
}

export type GlobalConfigInput = {
	adminIds: { number }?,
	logLevel: LogLevel?,
	defaultRateLimit: (RateLimitOverride | "disabled")?,
	cacheRegions: { [string]: CacheRegionConfig }?,
	rejectExtraFields: boolean?,
}

export type EndpointConfig = {
	adminOnly: boolean?,
	rateLimit: (RateLimitOverride | "disabled")?,
	logLevel: LogLevel?,
}

export type ResolvedEndpointConfig = {
	adminOnly: boolean,
	rateLimit: RateLimitSettings | "disabled",
	logLevel: LogLevel,
}

return deepFreeze({
	LogLevel = LogLevel,
	OnExceed = OnExceed,
	CacheScope = CacheScope,
})
