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

local function limitOf(config: Types.ResolvedEndpointConfig?): Types.RateLimitConfig?
	if config == nil or config.rateLimit == "disabled" then
		return nil
	end
	return config.rateLimit
end

-- ===== EndpointBuilder напрямую =====

-- Билдер с «подсматривающей» функцией регистрации
local function newBuilder(name: string)
	local calls: { { name: string, config: Types.ResolvedEndpointConfig } } = {}
	local builder = EndpointBuilder.new(name, Defaults, function(n, c)
		table.insert(calls, { name = n, config = c })
	end)
	return builder, calls
end

do
	local b, calls = newBuilder("test")
	local result = b:build()
	check("B1. build calls register once", #calls == 1)
	check("B1. register gets the name", calls[1] ~= nil and calls[1].name == "test")
	check("B1. build returns the registered config", calls[1] ~= nil and calls[1].config == result)
	check("B1. defaults: adminOnly = false", result.adminOnly == false)
	check("B1. defaults: logLevel from global", result.logLevel == Defaults.logLevel)
end

do
	local b = newBuilder("test")
	check("B2. methods return the same builder", b:logLevel("debug") == b and b:adminOnly() == b)
end

do
	local b1 = newBuilder("a")
	check("B3. adminOnly() means true", b1:adminOnly():build().adminOnly == true)
	local b2 = newBuilder("b")
	check("B3. adminOnly(false) is kept", b2:adminOnly(false):build().adminOnly == false)
end

do
	local b = newBuilder("test")
	local limit = limitOf(b:rateLimit({ bucketCapacity = 2 }):build())
	check(
		"B4. partial rateLimit merged with global",
		limit ~= nil and limit.bucketCapacity == 2 and limit.refillPerSecond == 15 and limit.onExceed == "reject"
	)
end

do
	local b = newBuilder("test")
	check("B5. rateLimit disabled", b:rateLimit("disabled"):build().rateLimit == "disabled")
end

do
	local b = newBuilder("test")
	check("B6. last call wins", b:logLevel("debug"):logLevel("warn"):build().logLevel == "warn")
end

do
	local b, calls = newBuilder("test")
	b:logLevel("verbose" :: any)
	expectErrorWith("B7. invalid logLevel fails in build", function()
		b:build()
	end, "endpoint 'test'.logLevel", '"verbose"')
	check("B7. register not called on failure", #calls == 0)
	-- Билдер не помечен собранным: можно исправить и собрать
	local ok = pcall(function()
		b:logLevel("info"):build()
	end)
	check("B7. builder is usable after failed build", ok and #calls == 1)
end

do
	local b = newBuilder("test")
	expectErrorWith("B8. invalid number in rateLimit", function()
		b:rateLimit({ bucketCapacity = 0 }):build()
	end, "invalid rateLimit in endpoint 'test'", "bucketCapacity must be >= 1")
end

do
	local b = newBuilder("test")
	b:build()
	expectErrorWith("B9. second build fails", function()
		b:build()
	end, "endpoint 'test' is already built")
	expectErrorWith("B9. method after build fails", function()
		b:logLevel("debug")
	end, "endpoint 'test' is already built")
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
	check("A2. endpoint inherits global logLevel", app:endpoint("inherits"):build().logLevel == "warn")
end

expectErrorWith("A3. invalid global config", function()
	GuardLib.createApp({ adminsIds = { 1 } } :: any)
end, "global config: unknown option 'adminsIds'. Did you mean 'adminIds'?")

do
	local app = GuardLib.createApp()
	app:endpoint("buyItem"):adminOnly():build()
	local registered = app:getEndpoint("buyItem")
	check("A4. getEndpoint returns registered config", registered ~= nil and registered.adminOnly == true)
	check("A5. getEndpoint for unknown name is nil", app:getEndpoint("nope") == nil)

	expectErrorWith("A6. endpoint() with taken name", function()
		app:endpoint("buyItem")
	end, "endpoint 'buyItem' is already registered")
end

do
	local app = GuardLib.createApp()
	local first = app:endpoint("dup"):logLevel("debug")
	local second = app:endpoint("dup"):logLevel("error")
	first:build()
	expectErrorWith("A7. second builder with the same name fails on build", function()
		second:build()
	end, "endpoint 'dup' is already registered")
	local kept = app:getEndpoint("dup")
	check("A7. first registration is kept", kept ~= nil and kept.logLevel == "debug")
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
	app:endpoint("buyItem"):rateLimit({ bucketCapacity = 2 }):build()
end, "rateLimit in endpoint 'buyItem' is partial", "Missing: refillPerSecond, onExceed")

do
	local app1 = GuardLib.createApp()
	local app2 = GuardLib.createApp()
	app1:endpoint("shared"):build()
	local ok = pcall(function()
		app2:endpoint("shared"):build()
	end)
	check("A10. apps have independent registries", ok and app2:getEndpoint("shared") ~= nil)
end

print(`Done: {passed} passed, {failed} failed`)
