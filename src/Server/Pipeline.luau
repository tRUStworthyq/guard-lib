--!strict
local Result = require(script.Parent.Parent.Shared.Result)
local Types = require(script.Parent.Config.Types)

local Pipeline = {}

export type Context = {
	player: Player,
	endpointName: string,
	config: Types.ResolvedEndpointConfig,
	globalConfig: Types.GlobalConfig,
	args: { n: number, [number]: any },
}

export type Next = () -> Result.Result
export type Middleware = (ctx: Context, nextFn: Next) -> Result.Result
export type Handler = (player: Player, ...any) -> ...any

function Pipeline.compose(middlewares: { Middleware }, handler: Handler): (ctx: Context) -> Result.Result
	local function dispatch(ctx: Context, index: number): Result.Result
		if index > #middlewares then
			return Result.ok(handler(ctx.player, table.unpack(ctx.args, 1, ctx.args.n)))
		end

		local middleware = middlewares[index]

		local function nextFn(): Result.Result
			return dispatch(ctx, index + 1)
		end

		return middleware(ctx, nextFn)
	end

	return function(ctx: Context): Result.Result
		return dispatch(ctx, 1)
	end
end

return Pipeline
