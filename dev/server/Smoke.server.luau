--!strict
local LocalStorageService = game:GetService("LocalStorageService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GuardLib = require(ReplicatedStorage.GuardLib)
local Types = require(ReplicatedStorage.GuardLib.Server.Config.Types)
local deepFreeze = require(ReplicatedStorage.GuardLib.Shared.Util.deepFreeze)
local Defaults = require(ReplicatedStorage.GuardLib.Server.Config.Defaults)

local ok, err = pcall(function()
	table.insert(Defaults.adminIds, 123)
end)
print(ok, err)

print(`[server] GuardLib {GuardLib.version}`)
