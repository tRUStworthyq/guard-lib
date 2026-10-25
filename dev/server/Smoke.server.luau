--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GuardLib = require(ReplicatedStorage.GuardLib)

print(`[server] GuardLib {GuardLib.version}`)

local app = GuardLib.createApp({ adminIds = { 123 } })
app:endpoint("buyItem"):rateLimit({ bucketCapacity = 2 }):build()
local buyItem = app:getEndpoint("buyItem")
print(
	"[server] buyItem limit:",
	if buyItem and buyItem.rateLimit ~= "disabled" then buyItem.rateLimit.bucketCapacity else "none"
)
