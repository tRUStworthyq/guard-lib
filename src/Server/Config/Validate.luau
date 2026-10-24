--!strict
local isFiniteNumber = require(script.Parent.Parent.Parent.Shared.Util.isFiniteNumber)
local deepFreeze = require(script.Parent.Parent.Parent.Shared.Util.deepFreeze)
local Types = require(script.Parent.Types)
local closestMatch = require(script.Parent.Parent.Parent.Shared.Util.closestMatch)

local ENDPOINT_KEYS = { "adminOnly", "rateLimit", "logLevel" }
local RATE_LIMIT_KEYS = { "bucketCapacity", "refillPerSecond", "onExceed" }
local GLOBAL_KEYS = { "adminIds", "logLevel", "defaultRateLimit", "cacheRegions", "rejectExtraFields" }
local REGION_KEYS = { "scope", "ttlSeconds", "maxCountOfRecords" }

local function checkUnknownKeys(tbl: { [any]: unknown }, allowed: { string }, path: string, errors: { string })
	for k in tbl do
		if type(k) ~= "string" or table.find(allowed, k) == nil then
			local candidate = if type(k) == "string" then closestMatch(k, allowed) else nil
			local err = `{path}: unknown option '{tostring(k)}'`
			if candidate ~= nil then
				err = err .. `. Did you mean '{candidate}'?`
			end
			table.insert(errors, err)
		end
	end
end

local function isOneOf(value: string, enum: { [string]: string }): boolean
	return enum[value] ~= nil
end

local function checkEnum(value: unknown, enum: { [string]: string }, expected: string, path: string, errors: { string }, required: boolean?)
	if value == nil then
        if required then
            table.insert(errors, `{path}: required field, got nil`)
        end
	elseif type(value) ~= "string" then
		table.insert(errors, `{path}: expected string, got {typeof(value)}`)
	elseif not isOneOf(value, enum) then
		table.insert(errors, `{path}: expected {expected}, got "{value}"`)
	end
end

local function checkRateLimitOverride(value: unknown, path: string, errors: { string })
	if value == nil then
		-- не задан — нормально
	elseif type(value) == "string" then
		if value ~= "disabled" then
			table.insert(errors, `{path}: expected "disabled" or table, got "{value}"`)
		end
	elseif type(value) == "table" then
		local rateLimitTbl = value :: { [any]: unknown }
		checkUnknownKeys(rateLimitTbl, RATE_LIMIT_KEYS, `{path}`, errors)

		local bucketCapacity = rateLimitTbl.bucketCapacity
		if bucketCapacity == nil then
			-- не задан — нормально
		elseif type(bucketCapacity) ~= "number" then
			table.insert(errors, `{path}.bucketCapacity: expected number, got {typeof(bucketCapacity)}`)
		end

		local refillPerSecond = rateLimitTbl.refillPerSecond
		if refillPerSecond == nil then
			-- не задан — нормально
		elseif type(refillPerSecond) ~= "number" then
			table.insert(errors, `{path}.refillPerSecond: expected number, got {typeof(refillPerSecond)}`)
		end

		checkEnum(rateLimitTbl.onExceed, Types.OnExceed :: any, '"ignore" | "reject"', `{path}.onExceed`, errors)
	else
		table.insert(errors, `{path}: expected "disabled" or table, got {typeof(value)}`)
	end
end

local function checkCacheRegion(value: { [any]: unknown }, path: string, errors: { string })
    checkUnknownKeys(value, REGION_KEYS, path, errors)

    checkEnum(value.scope, Types.CacheScope :: any, '"global" | "player"', `{path}.scope`, errors, true)
                
    local ttlSeconds = value.ttlSeconds
    if ttlSeconds == nil then
        table.insert(errors, `{path}.ttlSeconds: required field, got nil`)
    elseif not isFiniteNumber(ttlSeconds) or (ttlSeconds :: number) <= 0 then 
        table.insert(errors, `{path}.ttlSeconds: expected finite number > 0, got {ttlSeconds}`)
    end

    local maxCountOfRecords = value.maxCountOfRecords
    if maxCountOfRecords == nil then
        table.insert(errors, `{path}.maxCountOfRecords: required field, got nil`)
    elseif not isFiniteNumber(maxCountOfRecords) or math.floor((maxCountOfRecords :: number)) ~= maxCountOfRecords or (maxCountOfRecords :: number) < 1 then
        table.insert(errors, `{path}.maxCountOfRecords: expected finite integer >= 1, got {maxCountOfRecords}`)
    end
end

local function parseEndpointConfig(input: unknown, endpointName: string): Types.EndpointConfig
	local path = `endpoint '{endpointName}'`

	if type(input) ~= "table" then
		error(`GuardLib: {path}: expected table, got {typeof(input)}`, 2)
	end

	local tbl = input :: { [any]: unknown }
	local errors: { string } = {}

	checkUnknownKeys(tbl, ENDPOINT_KEYS, path, errors)

	local adminOnly = tbl.adminOnly
	if adminOnly ~= nil and type(adminOnly) ~= "boolean" then
		table.insert(errors, `{path}.adminOnly: expected boolean, got {typeof(adminOnly)}`)
	end

	checkEnum(tbl.logLevel, Types.LogLevel :: any, '"debug" | "info" | "warn" | "error"', `{path}.logLevel`, errors)

	checkRateLimitOverride(tbl.rateLimit, `{path}.rateLimit`, errors)

	if #errors > 0 then
		error(`GuardLib: invalid config:\n{table.concat(errors, "\n")}`, 2)
	end

	return (tbl :: any) :: Types.EndpointConfig
end

local function parseGlobalConfigInput(input: unknown): Types.GlobalConfigInput
    local path = `global config`

	if type(input) ~= "table" then
		error(`GuardLib: {path}: expected table, got {typeof(input)}`, 2)
	end

	local tbl = input :: { [any]: unknown }
	local errors: { string } = {}

    checkUnknownKeys(tbl, GLOBAL_KEYS, path, errors)

    checkEnum(tbl.logLevel, Types.LogLevel :: any, '"debug" | "info" | "warn" | "error"', `{path}.logLevel`, errors)

    checkRateLimitOverride(tbl.defaultRateLimit, `{path}.defaultRateLimit`, errors)

    local rejectExtraFields = tbl.rejectExtraFields
	if rejectExtraFields ~= nil and type(rejectExtraFields) ~= "boolean" then
		table.insert(errors, `{path}.rejectExtraFields: expected boolean, got {typeof(rejectExtraFields)}`)
	end

    local adminIds = tbl.adminIds
    if adminIds == nil then
	    -- не задан — нормально
    elseif type(adminIds) ~= "table" then
        table.insert(errors, `{path}.adminIds: expected table, got {typeof(adminIds)}`)
    else
        local ids = adminIds :: { [any]: unknown }
        for key, id in ids do
            if type(key) ~= "number" or math.floor(key) ~= key or key < 1 then
                table.insert(errors, `{path}.adminIds: expected array, got key {tostring(key)}`)
            elseif not isFiniteNumber(id) or math.floor(id :: number) ~= id or id == 0 then
                table.insert(errors, `{path}.adminIds.{key}: expected non-zero integer UserId, got {tostring(id)}`)
            end
        end
    end

    local cacheRegions = tbl.cacheRegions
    if cacheRegions == nil then
        -- не задан — нормально
    elseif type(cacheRegions) ~= "table" then
        table.insert(errors, `{path}.cacheRegions: expected table, got {typeof(cacheRegions)}`)
    else
        local regions = cacheRegions :: { [any]: unknown }
        for key, region in regions do 
            if type(key) ~= "string" or key == "" then
                table.insert(errors, `{path}.cacheRegions: expected string non-empty key, got key {tostring(key)}`)
            elseif type(region) ~= "table" then
                table.insert(errors, `{path}.cacheRegions.{key}: expected table, got {typeof(region)}`)
            else
                local currRegion = region :: { [any]: unknown }
                checkCacheRegion(currRegion, `{path}.cacheRegions.{key}`, errors)
            end
        end
    end

    if #errors > 0 then
		error(`GuardLib: invalid config:\n{table.concat(errors, "\n")}`, 2)
	end

    return (tbl :: any) :: Types.GlobalConfigInput
end

return deepFreeze({
	parseEndpointConfig = parseEndpointConfig,
    parseGlobalConfigInput = parseGlobalConfigInput,
})
