--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local closestMatch = require(ReplicatedStorage.GuardLib.Shared.Util.closestMatch)

local passed, failed = 0, 0

local ENDPOINT_KEYS = { "adminOnly", "rateLimit", "logLevel" }
local RATE_LIMIT_KEYS = { "bucketCapacity", "refillPerSecond", "onExceed" }

local cases: { { input: string, candidates: { string }, expected: string? } } = {
	{ input = "adminsOnly", candidates = ENDPOINT_KEYS, expected = "adminOnly" },
	{ input = "AdminOnly", candidates = ENDPOINT_KEYS, expected = "adminOnly" },
	{ input = "ratelimit", candidates = ENDPOINT_KEYS, expected = "rateLimit" },
	{ input = "loglvl", candidates = ENDPOINT_KEYS, expected = "logLevel" },
	{ input = "bucketCapcity", candidates = RATE_LIMIT_KEYS, expected = "bucketCapacity" },
	{ input = "onExced", candidates = RATE_LIMIT_KEYS, expected = "onExceed" },
	{ input = "adminOnly", candidates = ENDPOINT_KEYS, expected = "adminOnly" },
	{ input = "xyz", candidates = ENDPOINT_KEYS, expected = nil },
	{ input = "", candidates = ENDPOINT_KEYS, expected = nil },
	{ input = "admin", candidates = ENDPOINT_KEYS, expected = nil },
	{ input = "adminOnly", candidates = {}, expected = nil },
}

for _, case in cases do
	local actual = closestMatch(case.input, case.candidates)
	local name = `closestMatch("{case.input}") → {tostring(case.expected)}`
	if actual == case.expected then
		passed += 1
		print("PASS", name)
	else
		failed += 1
		warn("FAIL", name, `— got {tostring(actual)}`)
	end
end

print(`Done: {passed} passed, {failed} failed`)
