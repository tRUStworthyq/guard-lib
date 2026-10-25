--!strict

local Result = {}

export type ErrorCode = "RATE_LIMITED" | "FORBIDDEN" | "INVALID_ARGS" | "INTERNAL"

export type Ok = { ok: true, values: { n: number, [number]: any } }
export type Err = { ok: false, code: ErrorCode }
export type Result = Ok | Err

function Result.ok(...: any): Ok
	local ok: Ok = {
		ok = true,
		values = table.pack(...),
	}
	return ok
end

function Result.err(code: ErrorCode): Err
	local err: Err = {
		ok = false,
		code = code,
	}
	return err
end

return Result
