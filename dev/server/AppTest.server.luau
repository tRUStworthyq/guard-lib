--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GuardLib = require(ReplicatedStorage.GuardLib)
local EndpointBuilder = require(ReplicatedStorage.GuardLib.Server.EndpointBuilder)
local Types = require(ReplicatedStorage.GuardLib.Server.Config.Types)
local Defaults = require(ReplicatedStorage.GuardLib.Server.Config.Defaults)

local passed, failed = 0, 0

local function check(name: string, condition: boolean)
	if condition then
		passed += 1
		print("PASS", name)
	else
		failed += 1
		warn("FAIL", name)
	end
end

local function expectErrorWith(name: string, fn: () -> (), ...: string)
	local ok, err = pcall(fn :: any)
	if ok then
		failed += 1
		warn("FAIL", name, "— expected an error, got none")
		return
	end
	local message = tostring(err)
	for _, part in { ... } do
		if not string.find(message, part, 1, true) then
			failed += 1
			warn("FAIL", name, `— message does not contain [{part}]:\n{message}`)
			return
		end
	end
	passed += 1
	print("PASS", name)
end

local function noop() end

local function limitOf(config: Types.ResolvedEndpointConfig?): Types.RateLimitConfig?
	if config == nil or config.rateLimit == "disabled" then
		return nil
	end
	return config.rateLimit
end

-- ===== EndpointBuilder напрямую =====

-- Билдер со «шпионом»: все зарегистрированные определения складываются в defs
local function newBuilder(name: string)
	local defs: { EndpointBuilder.Definition } = {}
	local builder = EndpointBuilder.new(name, Defaults, function(definition)
		table.insert(defs, definition)
	end)
	return builder, defs
end

do
	local b, defs = newBuilder("test")
	b:onInvoke(noop)
	local d = defs[1]
	check("B1. onInvoke registers once", #defs == 1)
	check("B1. definition has the name", d ~= nil and d.name == "test")
	check("B1. onInvoke gives kind 'invoke'", d ~= nil and d.kind == "invoke")
	check("B1. definition keeps the handler", d ~= nil and d.handler == noop)
	check("B1. defaults: adminOnly = false", d ~= nil and d.config.adminOnly == false)
	check("B1. defaults: logLevel from global", d ~= nil and d.config.logLevel == Defaults.logLevel)
end

do
	local b, defs = newBuilder("test")
	b:onEvent(noop)
	check("B2. onEvent gives kind 'event'", defs[1] ~= nil and defs[1].kind == "event")
end

do
	local b = newBuilder("test")
	check("B3. methods return the same builder", b:logLevel("debug") == b and b:adminOnly() == b)
end

do
	local b1, defs1 = newBuilder("a")
	b1:adminOnly():onInvoke(noop)
	check("B4. adminOnly() means true", defs1[1] ~= nil and defs1[1].config.adminOnly == true)

	local b2, defs2 = newBuilder("b")
	b2:adminOnly(false):onInvoke(noop)
	check("B4. adminOnly(false) is kept", defs2[1] ~= nil and defs2[1].config.adminOnly == false)
end

do
	local b, defs = newBuilder("test")
	b:rateLimit({ bucketCapacity = 2 }):onInvoke(noop)
	local limit = limitOf(defs[1] and defs[1].config)
	check(
		"B5. partial rateLimit merged with global",
		limit ~= nil and limit.bucketCapacity == 2 and limit.refillPerSecond == 15 and limit.onExceed == "reject"
	)
end

do
	local b, defs = newBuilder("test")
	b:rateLimit("disabled"):onInvoke(noop)
	check("B6. rateLimit disabled", defs[1] ~= nil and defs[1].config.rateLimit == "disabled")
end

do
	local b, defs = newBuilder("test")
	b:logLevel("debug"):logLevel("warn"):onInvoke(noop)
	check("B7. last call wins", defs[1] ~= nil and defs[1].config.logLevel == "warn")
end

do
	local b, defs = newBuilder("test")
	b:logLevel("verbose" :: any)
	expectErrorWith("B8. invalid logLevel fails on onInvoke", function()
		b:onInvoke(noop)
	end, "endpoint 'test'.logLevel", '"verbose"')
	check("B8. register not called on failure", #defs == 0)
	local ok = pcall(function()
		b:logLevel("info"):onInvoke(noop)
	end)
	check("B8. builder is usable after a failed finish", ok and #defs == 1)
end

do
	local b = newBuilder("test")
	expectErrorWith("B9. invalid number in rateLimit", function()
		b:rateLimit({ bucketCapacity = 0 }):onInvoke(noop)
	end, "invalid rateLimit in endpoint 'test'", "bucketCapacity must be >= 1")
end

do
	local b, defs = newBuilder("test")
	expectErrorWith("B10. handler must be a function", function()
		b:onInvoke(nil :: any)
	end, "endpoint 'test': handler must be a function, got nil")
	check("B10. register not called for a bad handler", #defs == 0)
end

do
	local b = newBuilder("test")
	b:onInvoke(noop)
	expectErrorWith("B11. second onInvoke fails", function()
		b:onInvoke(noop)
	end, "endpoint 'test' is already built")
	expectErrorWith("B11. onEvent after onInvoke fails", function()
		b:onEvent(noop)
	end, "endpoint 'test' is already built")
	expectErrorWith("B11. method after finish fails", function()
		b:logLevel("debug")
	end, "endpoint 'test' is already built")
end

do
	local b = newBuilder("test")
	check("B12. build() no longer exists", (b :: any).build == nil)
end

-- ===== App через публичный API =====

do
	local app = GuardLib.createApp()
	check("A1. createApp() without args uses defaults", app:getConfig().logLevel == Defaults.logLevel)
	check("A1. global config is frozen", table.isfrozen(app:getConfig() :: any))
end

do
	local app = GuardLib.createApp({ adminIds = { 123 }, logLevel = "warn" })
	check("A2. adminIds applied", app:getConfig().adminIds[1] == 123)
	check("A2. logLevel applied", app:getConfig().logLevel == "warn")
	app:endpoint("inherits"):onInvoke(noop)
	local def = app:getEndpoint("inherits")
	check("A2. endpoint inherits global logLevel", def ~= nil and def.config.logLevel == "warn")
end

expectErrorWith("A3. invalid global config", function()
	GuardLib.createApp({ adminsIds = { 1 } } :: any)
end, "global config: unknown option 'adminsIds'. Did you mean 'adminIds'?")

do
	local app = GuardLib.createApp()
	app:endpoint("buyItem"):adminOnly():onInvoke(noop)
	local def = app:getEndpoint("buyItem")
	check("A4. getEndpoint returns the definition", def ~= nil and def.config.adminOnly == true)
	check("A4. definition keeps kind and handler", def ~= nil and def.kind == "invoke" and def.handler == noop)
	check("A5. getEndpoint for unknown name is nil", app:getEndpoint("nope") == nil)

	expectErrorWith("A6. endpoint() with taken name", function()
		app:endpoint("buyItem")
	end, "endpoint 'buyItem' is already registered")
end

do
	local app = GuardLib.createApp()
	local first = app:endpoint("dup"):logLevel("debug")
	local second = app:endpoint("dup"):logLevel("error")
	first:onInvoke(noop)
	expectErrorWith("A7. second builder with the same name fails", function()
		second:onEvent(noop)
	end, "endpoint 'dup' is already registered")
	local kept = app:getEndpoint("dup")
	check("A7. first registration is kept", kept ~= nil and kept.kind == "invoke" and kept.config.logLevel == "debug")
end

do
	local app = GuardLib.createApp()
	expectErrorWith("A8. empty endpoint name", function()
		app:endpoint("")
	end, "endpoint name must be a non-empty string")
	expectErrorWith("A8. non-string endpoint name", function()
		app:endpoint(5 :: any)
	end, "endpoint name must be a non-empty string")
end

expectErrorWith("A9. partial endpoint limit over disabled global", function()
	local app = GuardLib.createApp({ defaultRateLimit = "disabled" })
	app:endpoint("buyItem"):rateLimit({ bucketCapacity = 2 }):onInvoke(noop)
end, "rateLimit in endpoint 'buyItem' is partial", "Missing: refillPerSecond, onExceed")

do
	local app1 = GuardLib.createApp()
	local app2 = GuardLib.createApp()
	app1:endpoint("shared"):onInvoke(noop)
	local ok = pcall(function()
		app2:endpoint("shared"):onEvent(noop)
	end)
	local def = app2:getEndpoint("shared")
	check("A10. apps have independent registries", ok and def ~= nil and def.kind == "event")
end

print(`Done: {passed} passed, {failed} failed`)
