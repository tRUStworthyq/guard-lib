--!strict
local RunService = game:GetService("RunService")

local App = require(script.Server.App)
local EndpointBuilder = require(script.Server.EndpointBuilder)
local Types = require(script.Server.Config.Types)

export type App = App.App
export type EndpointBuilder = EndpointBuilder.EndpointBuilder
export type GlobalConfigInput = Types.GlobalConfigInput
export type ResolvedEndpointConfig = Types.ResolvedEndpointConfig
export type LogLevel = Types.LogLevel
export type OnExceed = Types.OnExceed
export type RateLimitOverride = Types.RateLimitOverride

export type GuardLib = {
	version: string,
	createApp: (input: GlobalConfigInput?) -> App,
}

local function createApp(input: GlobalConfigInput?): App
	if not RunService:IsServer() then
		error("GuardLib.createApp can only be called on the server", 2)
	end
	return App.new(input)
end

local GuardLib: GuardLib = table.freeze({
	version = "0.1.0",
	createApp = createApp,
})

return GuardLib
