--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.GuardLib.Server.Config.Types)
local Resolve = require(ReplicatedStorage.GuardLib.Server.Config.Resolve)
local Defaults = require(ReplicatedStorage.GuardLib.Server.Config.Defaults)
local isFiniteNumber = require(ReplicatedStorage.GuardLib.Shared.Util.isFiniteNumber)

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

local function expectError(name: string, fn: () -> ())
	local ok, err = pcall(fn :: any)
	if ok then
		failed += 1
		warn("FAIL", name, "— expected an error, got none")
	else
		passed += 1
		print("PASS", name, "→", err)
	end
end

-- Сравнение таблиц по содержимому, аналог equals(). Вложенные таблицы сравниваются по ссылке.
local function shallowEqual(a: any, b: any): boolean
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for k, v in a do
		if b[k] ~= v then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local enabled: Types.RateLimitConfig = { bucketCapacity = 30, refillPerSecond = 15, onExceed = "reject" }

-- resolveRateLimit: наследование и выключение
check("1. nil inherits global (same reference)", Resolve.resolveRateLimit(enabled, nil, "a") == enabled)
check("2. 'disabled' overrides enabled global", Resolve.resolveRateLimit(enabled, "disabled", "a") == "disabled")
check("2b. nil inherits disabled global", Resolve.resolveRateLimit("disabled", nil, "a") == "disabled")

-- resolveRateLimit: слияние по полям
check(
	"3. partial override merges with global",
	shallowEqual(
		Resolve.resolveRateLimit(enabled, { bucketCapacity = 5 }, "a"),
		{ bucketCapacity = 5, refillPerSecond = 15, onExceed = "reject" }
	)
)
check(
	"3b. only onExceed overridden",
	shallowEqual(
		Resolve.resolveRateLimit(enabled, { onExceed = "ignore" }, "a"),
		{ bucketCapacity = 30, refillPerSecond = 15, onExceed = "ignore" }
	)
)

-- resolveRateLimit: глобальный выключен (решение b)
expectError("4. partial override on disabled global", function()
	Resolve.resolveRateLimit("disabled", { bucketCapacity = 5 }, "buyItem")
end)
check(
	"5. full override on disabled global",
	shallowEqual(
		Resolve.resolveRateLimit("disabled", { bucketCapacity = 5, refillPerSecond = 2, onExceed = "ignore" }, "a"),
		{ bucketCapacity = 5, refillPerSecond = 2, onExceed = "ignore" }
	)
)

-- validateRateLimit через resolveRateLimit: некорректные значения
local invalidCases: { { label: string, override: Types.RateLimitOverride } } = {
	{ label = "capacity 0", override = { bucketCapacity = 0 } },
	{ label = "capacity -1", override = { bucketCapacity = -1 } },
	{ label = "capacity 2.5", override = { bucketCapacity = 2.5 } },
	{ label = "capacity NaN", override = { bucketCapacity = 0 / 0 } },
	{ label = "capacity inf", override = { bucketCapacity = math.huge } },
	{ label = "refill 0", override = { refillPerSecond = 0 } },
	{ label = "refill -5", override = { refillPerSecond = -5 } },
	{ label = "refill NaN", override = { refillPerSecond = 0 / 0 } },
	{ label = "refill inf", override = { refillPerSecond = math.huge } },
}
for _, case in invalidCases do
	expectError(`6. invalid {case.label}`, function()
		Resolve.resolveRateLimit(enabled, case.override, "buyItem")
	end)
end

check(
	"6b. fractional refill is allowed",
	shallowEqual(
		Resolve.resolveRateLimit(enabled, { refillPerSecond = 0.5 }, "a"),
		{ bucketCapacity = 30, refillPerSecond = 0.5, onExceed = "reject" }
	)
)
expectError("6c. values are validated on disabled global too", function()
	Resolve.resolveRateLimit("disabled", { bucketCapacity = 0, refillPerSecond = 1, onExceed = "reject" }, "buyItem")
end)

-- resolveEndpoint: пустой конфиг берёт всё из глобального
local resolved = Resolve.resolveEndpoint(Defaults, {}, "a")
check("7. empty endpoint: adminOnly = false", resolved.adminOnly == false)
check("7. empty endpoint: logLevel from global", resolved.logLevel == Defaults.logLevel)
check("7. empty endpoint: rateLimit from global", resolved.rateLimit == Defaults.defaultRateLimit)
check("7. result is frozen", table.isfrozen(resolved :: any))

-- resolveEndpoint: явные значения сохраняются
local custom =
	Resolve.resolveEndpoint(Defaults, { adminOnly = true, logLevel = "debug", rateLimit = "disabled" }, "admin")
check("8. adminOnly = true kept", custom.adminOnly == true)
check("8. logLevel override kept", custom.logLevel == "debug")
check("8. rateLimit 'disabled' kept", custom.rateLimit == "disabled")

-- resolveEndpoint: входные данные не меняются
local input: Types.EndpointConfig = { rateLimit = { bucketCapacity = 5 } }
Resolve.resolveEndpoint(Defaults, input, "a")
check(
	"9. input table is not mutated",
	input.adminOnly == nil and input.logLevel == nil and shallowEqual(input.rateLimit, { bucketCapacity = 5 })
)

check("finite: 1.5", isFiniteNumber(1.5))
check("finite: NaN rejected", not isFiniteNumber(0 / 0))
check("finite: inf rejected", not isFiniteNumber(math.huge))
check("finite: -inf rejected", not isFiniteNumber(-math.huge))
check("finite: string rejected", not isFiniteNumber("5"))
check("finite: nil rejected", not isFiniteNumber(nil))

print(`Done: {passed} passed, {failed} failed`)
