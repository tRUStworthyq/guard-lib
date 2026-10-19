--!strict

--[[ Функция для глубокой рекурсивной заморозки таблиц.
Функция не опускается ниже заранее замороженных таблиц через table.freeze]]
local function deepFreeze<T>(t: T): T
	if type(t) == "table" then
		local tbl = t :: { [any]: any }
		if table.isfrozen(tbl) then
			return t
		end
		table.freeze(tbl)
		for k, v in tbl do
			deepFreeze(k)
			deepFreeze(v)
		end
	end
	return t
end

return deepFreeze
