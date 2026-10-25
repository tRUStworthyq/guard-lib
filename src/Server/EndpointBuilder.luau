--!strict
local Types = require(script.Parent.Config.Types)
local Validate = require(script.Parent.Config.Validate)
local Resolve = require(script.Parent.Config.Resolve)

local EndpointBuilder = {}
EndpointBuilder.__index = EndpointBuilder

type RegisterFn = (name: string, config: Types.ResolvedEndpointConfig) -> ()

type BuilderData = {
	_name: string,
	_globalConfig: Types.GlobalConfig,
	_register: RegisterFn,
	_input: { [string]: unknown },
	_built: boolean,
}

export type EndpointBuilder = typeof(setmetatable({} :: BuilderData, EndpointBuilder))

function EndpointBuilder.new(name: string, globalConfig: Types.GlobalConfig, register: RegisterFn): EndpointBuilder
	local data: BuilderData = {
		_name = name,
		_globalConfig = globalConfig,
		_register = register,
		_input = {},
		_built = false,
	}
	return setmetatable(data, EndpointBuilder)
end

local function assertNotBuilt(self: EndpointBuilder)
	if self._built then
		error(`GuardLib: endpoint '{self._name}' is already built`, 3)
	end
end

function EndpointBuilder.adminOnly(self: EndpointBuilder, value: boolean?): EndpointBuilder
	assertNotBuilt(self)
	self._input.adminOnly = if value ~= nil then value else true
	return self
end

function EndpointBuilder.rateLimit(self: EndpointBuilder, value: Types.RateLimitOverride | "disabled"): EndpointBuilder
	assertNotBuilt(self)
	self._input.rateLimit = value
	return self
end

function EndpointBuilder.logLevel(self: EndpointBuilder, value: Types.LogLevel): EndpointBuilder
	assertNotBuilt(self)
	self._input.logLevel = value
	return self
end

function EndpointBuilder.build(self: EndpointBuilder): Types.ResolvedEndpointConfig
	assertNotBuilt(self)

	local parsed = Validate.parseEndpointConfig(self._input, self._name)

	local resolved = Resolve.resolveEndpoint(self._globalConfig, parsed, self._name)

	self._register(self._name, resolved)

	self._built = true

	return resolved
end

return EndpointBuilder
