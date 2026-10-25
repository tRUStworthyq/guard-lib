--!strict
local Types = require(script.Parent.Config.Types)
local Validate = require(script.Parent.Config.Validate)
local Resolve = require(script.Parent.Config.Resolve)
local Pipeline = require(script.Parent.Pipeline)

local EndpointBuilder = {}
EndpointBuilder.__index = EndpointBuilder

type RegisterFn = (definition: Definition) -> ()

type BuilderData = {
	_name: string,
	_globalConfig: Types.GlobalConfig,
	_register: RegisterFn,
	_input: { [string]: unknown },
	_built: boolean,
}

export type EndpointBuilder = typeof(setmetatable({} :: BuilderData, EndpointBuilder))

export type Kind = "invoke" | "event"

export type Definition = {
	name: string,
	kind: Kind,
	config: Types.ResolvedEndpointConfig,
	handler: Pipeline.Handler,
}

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

local function finish(self: EndpointBuilder, kind: Kind, handler: unknown)
	if type(handler) ~= "function" then
		error(`GuardLib: endpoint '{self._name}': handler must be a function, got {typeof(handler)}`, 3)
	end

	local parsed = Validate.parseEndpointConfig(self._input, self._name)

	local resolved = Resolve.resolveEndpoint(self._globalConfig, parsed, self._name)

	self._register({ name = self._name, kind = kind, config = resolved, handler = handler :: Pipeline.Handler })

	self._built = true
end

function EndpointBuilder.onInvoke(self: EndpointBuilder, handler: Pipeline.Handler)
	assertNotBuilt(self)

	finish(self, "invoke", handler)
end

function EndpointBuilder.onEvent(self: EndpointBuilder, handler: Pipeline.Handler)
	assertNotBuilt(self)

	finish(self, "event", handler)
end

return EndpointBuilder
