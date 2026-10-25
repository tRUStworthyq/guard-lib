--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GuardLib = require(ReplicatedStorage:WaitForChild("GuardLib"))

print(`[client] GuardLib {GuardLib.version}`)

local ok, err = pcall(GuardLib.createApp)
print("[client] createApp on client:", ok, err)
