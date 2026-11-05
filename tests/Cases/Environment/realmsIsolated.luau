--[[
    Every environment loads its own copy of each module, src's, Promise and
    Volt alike, so a server and a client in one case share no module
    state, as two VMs share none, and neither does one case with the next
--]]

--!strict
local Environment = require("../../Environment")

local SOURCE: string = [[
return {
	Promise = require(script.Parent.Parent.Promise),
	Volt = require(script.Parent.Parent.Volt),
}
]]

return function (): (boolean, string | nil)
	local server = Environment.new()
	local _, transport = server.mock:join("Player")
	local client = server:client(transport)
	local nextCase = Environment.new()

	server:mount("State", SOURCE)
	client:mount("State", SOURCE)
	nextCase:mount("State", SOURCE)

	local onServer: any = server:load("State")
	local onClient: any = client:load("State")
	local onNext: any = nextCase:load("State")

	if rawequal(onServer, onClient) or rawequal(onServer, onNext) then
		return false, "Two environments shared one copy of a src module"
	end

	if rawequal(onServer.Promise, onClient.Promise) or rawequal(onServer.Volt, onClient.Volt) then
		return false, "The server and the client shared one Promise or one Volt"
	end

	if not rawequal(server.mock, client.mock) or rawequal(server.mock, nextCase.mock) then
		return false, "A client ran on another mock than its server, or two cases on one mock"
	end

	return true, nil
end
