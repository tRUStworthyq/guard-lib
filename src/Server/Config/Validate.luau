--!strict
local deepFreeze = require(script.Parent.Parent.Parent.Shared.Util.deepFreeze)
local Types = require(script.Parent.Types)
local closestMatch = require(script.Parent.Parent.Parent.Shared.Util.closestMatch)

local ENDPOINT_KEYS = { "adminOnly", "rateLimit", "logLevel" }
local RATE_LIMIT_KEYS = { "bucketCapacity", "refillPerSecond", "onExceed" }

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

local function checkEnum(value: unknown, enum: { [string]: string }, expected: string, path: string, errors: { string })
	if value == nil then
		-- не задан — нормально
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

return deepFreeze({
	parseEndpointConfig = parseEndpointConfig,
})
