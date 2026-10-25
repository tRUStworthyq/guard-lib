--!strict
local Pipeline = require(script.Parent.Parent.Pipeline)
local Result = require(script.Parent.Parent.Parent.Shared.Result)

local function access(ctx: Pipeline.Context, nextFn: Pipeline.Next): Result.Result
	if not ctx.config.adminOnly then
		return nextFn()
	end
	if table.find(ctx.globalConfig.adminIds, ctx.player.UserId) ~= nil then
		return nextFn()
	end
	return Result.err("FORBIDDEN")
end

return access
