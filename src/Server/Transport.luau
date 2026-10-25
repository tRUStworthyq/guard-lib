--!strict
local Types = require(script.Parent.Config.Types)
local Result = require(script.Parent.Parent.Shared.Result)
local Pipeline = require(script.Parent.Pipeline)
local EndpointBuilder = require(script.Parent.EndpointBuilder)
local Logger = require(script.Parent.Log.Logger)

local Transport = {}

type RunPipeline = (ctx: Pipeline.Context) -> Result.Result

function Transport.handle(
	definition: EndpointBuilder.Definition,
	globalConfig: Types.GlobalConfig,
	run: RunPipeline,
	logger: Logger.Logger,
	player: Player,
	...: any
): Result.Result
	local ctx: Pipeline.Context = {
		player = player,
		endpointName = definition.name,
		config = definition.config,
		globalConfig = globalConfig,
		args = table.pack(...),
	}

	local ok, resultOrError = pcall(run, ctx)

	if ok then
		return resultOrError
	else
		logger:log("error", "handler error", {
			endpoint = definition.name,
			player = player.Name,
			userId = player.UserId,
			error = tostring(resultOrError),
		})
		return Result.err("INTERNAL")
	end
end

function Transport.toWire(result: Result.Result, config: Types.ResolvedEndpointConfig): (boolean, ...any)
	if result.ok then
		return true, table.unpack(result.values, 1, result.values.n)
	end
	if result.code == "RATE_LIMITED" and config.rateLimit ~= "disabled" and config.rateLimit.onExceed == "ignore" then
		return true
	else
		return false, result.code
	end
end

function Transport.bind(
	folder: Instance,
	definition: EndpointBuilder.Definition,
	globalConfig: Types.GlobalConfig,
	run: RunPipeline,
	logger: Logger.Logger
): Instance
	if definition.kind == "invoke" then
		local remote = Instance.new("RemoteFunction")
		remote.Name = definition.name
		remote.OnServerInvoke = function(player: Player, ...: any)
			return Transport.toWire(
				Transport.handle(definition, globalConfig, run, logger, player, ...),
				definition.config
			)
		end
		remote.Parent = folder
		return remote
	else
		local remote = Instance.new("RemoteEvent")
		remote.Name = definition.name
		remote.OnServerEvent:Connect(function(player: Player, ...: any)
			Transport.handle(definition, globalConfig, run, logger, player, ...)
		end)
		remote.Parent = folder
		return remote
	end
end

return Transport
