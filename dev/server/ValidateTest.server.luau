--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Validate = require(ReplicatedStorage.GuardLib.Server.Config.Validate)

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

-- Проверяет, что fn бросает ошибку и что в её тексте есть все перечисленные фрагменты.
local function expectErrorWith(name: string, fn: () -> (), ...: string)
	local ok, err = pcall(fn :: any)
	if ok then
		failed += 1
		warn("FAIL", name, "— expected an error, got none")
		return
	end
	local message = tostring(err)
	for _, part in { ... } do
		if not string.find(message, part, 1, true) then
			failed += 1
			warn("FAIL", name, `— message does not contain [{part}]:\n{message}`)
			return
		end
	end
	passed += 1
	print("PASS", name)
end

local function parses(name: string, input: unknown)
	local ok, err = pcall(Validate.parseEndpointConfig, input, "test")
	if ok then
		passed += 1
		print("PASS", name)
	else
		failed += 1
		warn("FAIL", name, "— unexpected error:\n", err)
	end
end

local function parse(input: unknown)
	return function()
		Validate.parseEndpointConfig(input, "buyItem")
	end
end

local function parsesGlobal(name: string, input: unknown)
	local ok, err = pcall(Validate.parseGlobalConfigInput, input)
	if ok then
		passed += 1
		print("PASS", name)
	else
		failed += 1
		warn("FAIL", name, "— unexpected error:\n", err)
	end
end

local function parseGlobal(input: unknown)
	return function()
		Validate.parseGlobalConfigInput(input)
	end
end

-- Корректные конфиги
parses("1. empty config", {})
parses("2. all top-level fields", { adminOnly = true, logLevel = "debug", rateLimit = "disabled" })
parses("3. partial rateLimit", { rateLimit = { bucketCapacity = 5 } })
parses("4. full rateLimit", { rateLimit = { bucketCapacity = 5, refillPerSecond = 0.5, onExceed = "ignore" } })

local input = { adminOnly = true }
check("5. returns the same table", Validate.parseEndpointConfig(input, "a") == (input :: any))

-- Не таблица
expectErrorWith("6. string instead of table", parse("hello"), "endpoint 'buyItem'", "expected table, got string")
expectErrorWith("7. nil instead of table", parse(nil), "expected table, got nil")

-- Неизвестные ключи
expectErrorWith(
	"8. typo in top-level key",
	parse({ adminsOnly = true }),
	"unknown option 'adminsOnly'. Did you mean 'adminOnly'?"
)
expectErrorWith("9. non-string key", parse({ true }), "unknown option '1'")
expectErrorWith("9b. boolean key", parse({ [true] = 1 }), "unknown option 'true'")
expectErrorWith(
	"10. typo inside rateLimit",
	parse({ rateLimit = { bucketCapcity = 5 } }),
	"endpoint 'buyItem'.rateLimit: unknown option 'bucketCapcity'. Did you mean 'bucketCapacity'?"
)

-- Неверные типы и значения
expectErrorWith("11. adminOnly not boolean", parse({ adminOnly = "yes" }), ".adminOnly: expected boolean, got string")
expectErrorWith("12. logLevel not string", parse({ logLevel = 5 }), ".logLevel: expected string, got number")
expectErrorWith("13. logLevel not in enum", parse({ logLevel = "verbose" }), ".logLevel:", '"verbose"')
expectErrorWith("14. rateLimit wrong string", parse({ rateLimit = "disable" }), ".rateLimit:", '"disable"')
expectErrorWith("15. rateLimit wrong type", parse({ rateLimit = 5 }), ".rateLimit:", "got number")
expectErrorWith(
	"16. bucketCapacity not number",
	parse({ rateLimit = { bucketCapacity = "5" } }),
	".rateLimit.bucketCapacity: expected number, got string"
)
expectErrorWith(
	"17. refillPerSecond not number",
	parse({ rateLimit = { refillPerSecond = true } }),
	".rateLimit.refillPerSecond: expected number, got boolean"
)
expectErrorWith(
	"18. onExceed not in enum",
	parse({ rateLimit = { onExceed = "drop" } }),
	".rateLimit.onExceed:",
	'"drop"'
)

-- Все ошибки собираются в одно сообщение
expectErrorWith(
	"19. several errors reported together",
	parse({ adminsOnly = true, logLevel = "verbose", rateLimit = { onExceed = "drop" } }),
	"'adminsOnly'",
	'"verbose"',
	'"drop"'
)

parsesGlobal("G1. empty global config", {})
parsesGlobal("G2. full valid global config", {
	adminIds = { 123456, -1 },
	logLevel = "warn",
	defaultRateLimit = { bucketCapacity = 10 },
	cacheRegions = {
		inventory = { scope = "player", ttlSeconds = 30, maxCountOfRecords = 100 },
		leaderboard = { scope = "global", ttlSeconds = 0.5, maxCountOfRecords = 1 },
	},
	rejectExtraFields = false,
})
parsesGlobal("G3. defaultRateLimit disabled", { defaultRateLimit = "disabled" })

-- Верхний уровень
expectErrorWith("G4. not a table", parseGlobal("nope"), "global config: expected table, got string")
expectErrorWith(
	"G5. typo in key (case)",
	parseGlobal({ adminIDs = {} }),
	"unknown option 'adminIDs'. Did you mean 'adminIds'?"
)
expectErrorWith(
	"G6. logLevel not in enum",
	parseGlobal({ logLevel = "verbose" }),
	"global config.logLevel:",
	'"verbose"'
)
expectErrorWith(
	"G7. typo inside defaultRateLimit",
	parseGlobal({ defaultRateLimit = { bucketCapcity = 1 } }),
	"global config.defaultRateLimit: unknown option 'bucketCapcity'"
)
expectErrorWith(
	"G8. rejectExtraFields not boolean",
	parseGlobal({ rejectExtraFields = "yes" }),
	"global config.rejectExtraFields: expected boolean, got string"
)

-- adminIds
expectErrorWith("G9. adminIds not table", parseGlobal({ adminIds = 123 }), ".adminIds: expected table, got number")
expectErrorWith(
	"G10. adminIds is a dictionary",
	parseGlobal({ adminIds = { admin = 123 } }),
	".adminIds: expected array"
)
expectErrorWith("G11. adminIds contains 0", parseGlobal({ adminIds = { 0 } }), ".adminIds.1:", "got 0")
expectErrorWith("G12. adminIds contains 1.5", parseGlobal({ adminIds = { 1.5 } }), ".adminIds.1:", "got 1.5")
expectErrorWith("G13. adminIds contains string", parseGlobal({ adminIds = { "123" } }), ".adminIds.1:", "got 123")
expectErrorWith("G14. adminIds contains NaN", parseGlobal({ adminIds = { 0 / 0 } }), ".adminIds.1:", "got nan")

-- cacheRegions: контейнер
expectErrorWith(
	"G15. cacheRegions not table",
	parseGlobal({ cacheRegions = 5 }),
	".cacheRegions: expected table, got number"
)
expectErrorWith(
	"G16. empty region name",
	parseGlobal({ cacheRegions = { [""] = { scope = "global", ttlSeconds = 1, maxCountOfRecords = 1 } } }),
	".cacheRegions: expected string non-empty key"
)
expectErrorWith(
	"G17. region not table",
	parseGlobal({ cacheRegions = { inv = 5 } }),
	".cacheRegions.inv: expected table, got number"
)

-- cacheRegions: поля региона
expectErrorWith(
	"G18. all region fields required",
	parseGlobal({ cacheRegions = { inv = {} } }),
	".cacheRegions.inv.scope: required",
	".cacheRegions.inv.ttlSeconds: required",
	".cacheRegions.inv.maxCountOfRecords: required"
)
expectErrorWith(
	"G19. scope not in enum",
	parseGlobal({ cacheRegions = { inv = { scope = "server", ttlSeconds = 1, maxCountOfRecords = 1 } } }),
	".cacheRegions.inv.scope:",
	'"server"'
)
expectErrorWith(
	"G20. typo in region key",
	parseGlobal({ cacheRegions = { inv = { scop = "global", ttlSeconds = 1, maxCountOfRecords = 1 } } }),
	"unknown option 'scop'. Did you mean 'scope'?"
)

local badTtl: { { label: string, value: any } } = {
	{ label = "0", value = 0 },
	{ label = "-5", value = -5 },
	{ label = "NaN", value = 0 / 0 },
	{ label = "inf", value = math.huge },
	{ label = "string", value = "30" },
}
for _, case in badTtl do
	expectErrorWith(
		`G21. ttlSeconds {case.label}`,
		parseGlobal({ cacheRegions = { inv = { scope = "global", ttlSeconds = case.value, maxCountOfRecords = 1 } } }),
		".cacheRegions.inv.ttlSeconds: expected finite number > 0"
	)
end

local badMax: { { label: string, value: any } } = {
	{ label = "0", value = 0 },
	{ label = "2.5", value = 2.5 },
	{ label = "inf", value = math.huge },
	{ label = "string", value = "100" },
}
for _, case in badMax do
	expectErrorWith(
		`G22. maxCountOfRecords {case.label}`,
		parseGlobal({ cacheRegions = { inv = { scope = "global", ttlSeconds = 1, maxCountOfRecords = case.value } } }),
		".cacheRegions.inv.maxCountOfRecords: expected finite integer >= 1"
	)
end

-- Все ошибки собираются вместе
expectErrorWith(
	"G23. several errors reported together",
	parseGlobal({
		adminIds = { 0 },
		logLevel = "verbose",
		cacheRegions = { inv = { scope = "server", ttlSeconds = 1, maxCountOfRecords = 1 } },
	}),
	".adminIds.1:",
	'"verbose"',
	'"server"'
)

print(`Done: {passed} passed, {failed} failed`)
