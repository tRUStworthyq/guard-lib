--!strict
local MAX_DISTANCE = 2

local function levenshtein(a: string, b: string): number
	local dp = {}

	for i = 1, #a + 1 do
		dp[i] = {}
	end

	for i = 1, #a + 1 do
		dp[i][1] = i - 1
	end

	for j = 1, #b + 1 do
		dp[1][j] = j - 1
	end

	for i = 2, #a + 1 do
		for j = 2, #b + 1 do
			local cost = if string.byte(a, i - 1) == string.byte(b, j - 1) then 0 else 1

			dp[i][j] = math.min(dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost)
		end
	end

	return dp[#a + 1][#b + 1]
end

local function closestMatch(input: string, candidates: { string }): string?
	input = string.lower(input)
	-- Кандидаты выше порога никогда не победят и вернется nil
	local minCost = MAX_DISTANCE + 1
	local minCostCandidate = nil
	for _, candidate in candidates do
		local cost = levenshtein(input, string.lower(candidate))
		if cost < minCost then
			minCost = cost
			minCostCandidate = candidate
		end
	end

	return minCostCandidate
end

return closestMatch
