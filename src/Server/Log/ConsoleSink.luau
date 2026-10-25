--!strict
local Logger = require(script.Parent.Logger)

local function consoleSink(record: Logger.LogRecord)
	local fields = {}

	for key, field in record.fields do
		table.insert(fields, `{key}={tostring(field)}`)
	end
	table.sort(fields)
	local strFields = table.concat(fields, " ")

	local message = `[GuardLib] [{string.upper(record.level)}] {record.message} {strFields}`

	if record.level == "debug" or record.level == "info" then
		print(message)
	else
		warn(message)
	end
end

return consoleSink
