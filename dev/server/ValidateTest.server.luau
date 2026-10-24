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
expectErrorWith("8. typo in top-level key", parse({ adminsOnly = true }), "unknown option 'adminsOnly'")
expectErrorWith("9. non-string key", parse({ true }), "unknown option '1'")
expectErrorWith(
	"10. typo inside rateLimit",
	parse({ rateLimit = { bucketCapcity = 5 } }),
	"endpoint 'buyItem'.rateLimit: unknown option 'bucketCapcity'"
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

print(`Done: {passed} passed, {failed} failed`)
