--!strict
local deepFreeze = require(script.Parent.Parent.Parent.Shared.Util.deepFreeze)
local Types = require(script.Parent.Types)

local ENDPOINT_KEYS = { "adminOnly", "rateLimit", "logLevel" }
local RATE_LIMIT_KEYS = { "bucketCapacity", "refillPerSecond", "onExceed" }

local function checkUnknownKeys(tbl: { [any]: unknown }, allowed: { string }, path: string, errors: { string })
	for k in tbl do
        if type(k) ~= "string" or table.find(allowed, k) == nil then
            table.insert(errors, `{path}: unknown option '{tostring(k)}'`)
        end
    end
end

local function isOneOf(value: string, enum: { [string]: string }): boolean
    return enum[value] ~= nil
end

local function parseEndpointConfig(input: unknown, endpointName: string): Types.EndpointConfig
	local path = `endpoint '{endpointName}'`

	if type(input) ~= "table" then
		error(`GuardLib: {path}: expected table, got {typeof(input)}`, 2)
	end

	local tbl = input :: { [any]: unknown }
	local errors: { string } = {}

	checkUnknownKeys(tbl, ENDPOINT_KEYS, path, errors)

	-- adminOnly: пример одного поля целиком
	local adminOnly = tbl.adminOnly
	if adminOnly ~= nil and type(adminOnly) ~= "boolean" then
		table.insert(errors, `{path}.adminOnly: expected boolean, got {typeof(adminOnly)}`)
	end

	-- logLevel: ваш код (nil → ок; не строка → ошибка; не из Types.LogLevel → ошибка)
    local logLevel = tbl.logLevel
    if logLevel == nil then

    elseif type(logLevel) ~= "string" then
        table.insert(errors, `{path}.logLevel: expected string, got {typeof(logLevel)}`)
    elseif not isOneOf(logLevel, Types.LogLevel :: any) then
        table.insert(errors, `{path}.logLevel: expected "debug" | "info" | "warn" | "error", got "{logLevel}"`)
    end
    
	local rateLimit = tbl.rateLimit
    if rateLimit == nil then
        -- не задан — нормально
    elseif type(rateLimit) == "string" then
        if rateLimit ~= "disabled" then
            table.insert(errors, `{path}.rateLimit: expected "disabled" or table, got "{rateLimit}"`)
        end
    elseif type(rateLimit) == "table" then
        local rateLimitTbl = rateLimit :: { [any]: unknown }
        checkUnknownKeys(rateLimitTbl, RATE_LIMIT_KEYS, `{path}.rateLimit`, errors)
        -- TODO: проверить типы bucketCapacity, refillPerSecond, onExceed
    else
        table.insert(errors, `{path}.rateLimit: expected "disabled" or table, got {typeof(rateLimit)}`)
    end

	if #errors > 0 then
		error(`GuardLib: invalid config:\n{table.concat(errors, "\n")}`, 2)
	end

	return (tbl :: any) :: Types.EndpointConfig
end

return deepFreeze({
	parseEndpointConfig = parseEndpointConfig,
})