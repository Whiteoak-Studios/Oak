--[[
    getService errors on the client, which reaches the server only through
    its Network, and getController errors on the server
--]]

--!strict
local Environment = require("../../Environment")

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", { prepare = function () end, bind = function () end })
	server:substitute("ClientProperty", {})

	local _, transport = server.mock:join("Player")
	local client = server:client(transport)
	client:substitute("Failures", { bind = function () end })
	client:substitute("Property", {})
	client:substitute("ClientProperty", {})

	local onServer: any = server:load("init")
	local onClient: any = client:load("init")

	local served: boolean, serverRefusal: any = pcall(onServer.getController, "ShopController")
	if served or not tostring(serverRefusal):find("Oak.getController", 1, true) then
		return false, `getController on the server gave {serverRefusal} rather than an error`
	end

	local reached: boolean, clientRefusal: any = pcall(onClient.getService, "ShopService")
	if reached or not tostring(clientRefusal):find("Oak.getService", 1, true) then
		return false, `getService on the client gave {clientRefusal} rather than an error`
	end

	return true, nil
end
