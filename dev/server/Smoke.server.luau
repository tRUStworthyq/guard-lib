--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GuardLib = require(ReplicatedStorage.GuardLib)
local Defaults = require(ReplicatedStorage.GuardLib.Server.Config.Defaults)

local ok, err = pcall(function()
	table.insert(Defaults.adminIds, 123)
end)
print(ok, err)

print(`[server] GuardLib {GuardLib.version}`)
