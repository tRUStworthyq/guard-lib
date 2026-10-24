--!strict
local Types = require(script.Parent.Types)
local deepFreeze = require(script.Parent.Parent.Parent.Shared.Util.deepFreeze)

local function isInf(x): boolean
	if type(x) == "number" then
		return math.abs(x) == math.huge
	else
		return false
	end
end

local function validateRateLimit(config: Types.RateLimitConfig, context: string)
	-- Проверка на NaN
	if config.bucketCapacity ~= config.bucketCapacity then
		error(`GuardLib: invalid rateLimit in {context}: bucketCapacity must be a finite number, got nan`, 2)
	end
	if config.bucketCapacity < 1 then
		error(
			`GuardLib: invalid rateLimit in {context}: bucketCapacity must be >= 1, got {tostring(config.bucketCapacity)}`,
			2
		)
	end
	if math.floor(config.bucketCapacity) ~= config.bucketCapacity then
		error(
			`GuardLib: invalid rateLimit in {context}: bucketCapacity must be an integer >= 1, got {tostring(
				config.bucketCapacity
			)}`,
			2
		)
	end
	if isInf(config.bucketCapacity) then
		error(`GuardLib: invalid rateLimit in {context}: bucketCapacity must be a finite number, got inf`, 2)
	end

	-- Проверка на NaN
	if config.refillPerSecond ~= config.refillPerSecond then
		error(`GuardLib: invalid rateLimit in {context}: refillPerSecond must be a finite number, got nan`, 2)
	end
	if config.refillPerSecond <= 0 then
		error(
			`GuardLib: invalid rateLimit in {context}: refillPerSecond must be > 0, got {tostring(
				config.refillPerSecond
			)}`,
			2
		)
	end
	if isInf(config.refillPerSecond) then
		error(`GuardLib: invalid rateLimit in {context}: refillPerSecond must be a finite number, got inf`, 2)
	end
end

local function resolveRateLimit(
	global: Types.RateLimitSettings,
	override: (Types.RateLimitOverride | "disabled")?,
	endpointName: string
): Types.RateLimitSettings
	if override == nil then
		return global
	end
	if override == "disabled" then
		return override
	end
	if global == "disabled" then
		local bucketCap = override.bucketCapacity
		local refill = override.refillPerSecond
		local exceed: Types.OnExceed? = override.onExceed

		if bucketCap == nil or refill == nil or exceed == nil then
			local missing = {}
			if bucketCap == nil then
				table.insert(missing, "bucketCapacity")
			end
			if refill == nil then
				table.insert(missing, "refillPerSecond")
			end
			if exceed == nil then
				table.insert(missing, "onExceed")
			end
			local stringFields = table.concat(missing, ", ")
			error(
				`GuardLib: rateLimit for endpoint '{endpointName}' is partial, but the global rate limit is disabled. Missing: {stringFields}`,
				2
			)
		end

		local settings: Types.RateLimitConfig = {
			bucketCapacity = bucketCap,
			refillPerSecond = refill,
			onExceed = exceed,
		}

		validateRateLimit(settings, `endpoint '{endpointName}'`)

		return settings
	end

	local settings: Types.RateLimitConfig = {
		bucketCapacity = if override.bucketCapacity ~= nil then override.bucketCapacity else global.bucketCapacity,
		refillPerSecond = if override.refillPerSecond ~= nil then override.refillPerSecond else global.refillPerSecond,
		onExceed = if override.onExceed ~= nil then override.onExceed else global.onExceed,
	}

	validateRateLimit(settings, `endpoint '{endpointName}'`)

	return settings
end

local function resolveEndpoint(
	global: Types.GlobalConfig,
	endpoint: Types.EndpointConfig,
	endpointName: string
): Types.ResolvedEndpointConfig
	local resolvedConfig: Types.ResolvedEndpointConfig = {
		adminOnly = if endpoint.adminOnly ~= nil then endpoint.adminOnly else false,
		rateLimit = resolveRateLimit(global.defaultRateLimit, endpoint.rateLimit, endpointName),
		logLevel = if endpoint.logLevel ~= nil then endpoint.logLevel else global.logLevel,
	}
	return deepFreeze(resolvedConfig)
end

return deepFreeze({
	resolveRateLimit = resolveRateLimit,
	validateRateLimit = validateRateLimit,
	resolveEndpoint = resolveEndpoint,
})
