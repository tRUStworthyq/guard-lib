--!strict
local Types = require(script.Parent.Config.Types)
local Validate = require(script.Parent.Config.Validate)
local Resolve = require(script.Parent.Config.Resolve)
local Defaults = require(script.Parent.Config.Defaults)
local EndpointBuilder = require(script.Parent.EndpointBuilder)

local App = {}
App.__index = App

type AppData = {
	_config: Types.GlobalConfig,
	_endpoints: { [string]: Types.ResolvedEndpointConfig },
}

export type App = typeof(setmetatable({} :: AppData, App))

function App.new(input: unknown): App
	local raw = if input == nil then {} else input

	local parsed = Validate.parseGlobalConfigInput(raw)

	local config = Resolve.resolveGlobal(Defaults, parsed)

	local data: AppData = {
		_config = config,
		_endpoints = {},
	}

	return setmetatable(data, App)
end

function App.endpoint(self: App, name: string): EndpointBuilder.EndpointBuilder
	if type(name) ~= "string" or name == "" then
		error("GuardLib: endpoint name must be a non-empty string", 2)
	elseif self._endpoints[name] ~= nil then
		error(`GuardLib: endpoint '{name}' is already registered`, 2)
	end
	local function register(endpointName: string, config: Types.ResolvedEndpointConfig)
		if self._endpoints[endpointName] ~= nil then
			error(`GuardLib: endpoint '{endpointName}' is already registered`, 3)
		else
			self._endpoints[endpointName] = config
		end
	end

	return EndpointBuilder.new(name, self._config, register)
end

function App.getEndpoint(self: App, name: string): Types.ResolvedEndpointConfig?
	return self._endpoints[name]
end

function App.getConfig(self: App): Types.GlobalConfig
	return self._config
end

return App
