--[[
    Every warn in a realm is kept in that realm's warnings, its arguments
    joined with spaces, Volt's own default failure handler's among them,
    and none reaches another realm
--]]

--!strict
local Environment = require("../../Environment")

local SOURCE: string = [[
return function ()
	warn("Oak:", 1, true)
end
]]

local WARNED: string = "Oak: 1 true" -- What the stub's warn reads as once its arguments are joined
local LISTENER_FAILURE: string = "Volt: listener failure from Player: Shop.report:" -- How Volt's default handler opens

return function (): (boolean, string | nil)
	local server = Environment.new()
	local serverNetwork: any = server:network("Oak")

	local _, transport = server.mock:join("Player")
	local client = server:client(transport)
	local clientNetwork: any = client:network("Oak")

	server:mount("Warns", SOURCE)
	server:load("Warns")()

	if server.warnings[1] ~= WARNED or #client.warnings ~= 0 then
		return false, `The server kept {server.warnings[1]}, and the client {#client.warnings} warnings`
	end

	server:step(Environment.HANDSHAKE)

	serverNetwork.Shop.report.on(function ()
		error("The listener broke")
	end)

	clientNetwork.Shop.report.fire("Report")
	server:step(Environment.DELIVERY)

	local defaulted: string = server.warnings[2] or ""

	if defaulted:sub(1, #LISTENER_FAILURE) ~= LISTENER_FAILURE then
		return false, `The server kept {defaulted} rather than Volt's listener failure warning`
	end

	return true, nil
end
