--!strict
export type GuardLib = {
	version: string,
}

local GuardLib: GuardLib = table.freeze({
	version = "0.1.0",
})

return GuardLib
