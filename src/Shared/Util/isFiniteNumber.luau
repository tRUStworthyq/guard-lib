--!strict
local function isFiniteNumber(x: unknown): boolean
	return type(x) == "number" and x == x and math.abs(x) ~= math.huge
end

return isFiniteNumber
