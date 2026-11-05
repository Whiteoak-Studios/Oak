--[[
    Oak.Property calls the constructor straight from its own body, so an
    error the constructor raises at level 3, as a second server Property's
    does, points at the line that called Oak.Property
--]]

--!strict
local Environment = require("../../Environment")

local LEVEL: number = 3 -- The constructor, Oak.Property, then the caller
local CALLER_LINE: string = `Caller.luau"]:2:` -- Where the stub below calls Oak.Property

local CALLER: string = [[
return function (Oak: any, handle: any): any
	return Oak.Property(handle, 0)
end
]]

return function (): (boolean, string | nil)
	local server = Environment.new()
	local network: any = server:network("Oak")
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", {
		new = function ()
			error("a second Property on this event", LEVEL)
		end,
	})
	server:substitute("ClientProperty", {})
	server:mount("Caller", CALLER)

	local Oak: any = server:load("init")
	local call: (any, any) -> any = server:load("Caller")

	local made: boolean, refusal: any = pcall(call, Oak, network.Shop.coins)

	if made or not tostring(refusal):find(CALLER_LINE, 1, true) then
		return false, `The constructor's error read {refusal}, which does not point at the calling line`
	end

	return true, nil
end
