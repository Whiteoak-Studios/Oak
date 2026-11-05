--[[
    A namespace that holds only exported types, Catalog in Oak.volt, has
    no registry entry, so both realms boot with no table owning it
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

return function (): (boolean, string | nil)
	local server = Environment.new()
	local serverNetwork: any = server:network("Oak")
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", { prepare = function () end, bind = function () end })
	server:substitute("ClientProperty", {})

	local _, transport = server.mock:join("Player")
	local client = server:client(transport)
	local clientNetwork: any = client:network("Oak")
	client:substitute("Failures", { bind = function () end })
	client:substitute("Property", {})
	client:substitute("ClientProperty", {})

	if serverNetwork.exports["Catalog.Item"] == nil then
		return false, "Oak.volt's Catalog namespace exports no Item, so this case proves nothing"
	end

	local serverOak: any = server:load("init")
	local clientOak: any = client:load("init")

	local served: boolean, serverRefusal: any = pcall(serverOak.start, { Shop(server, true) }, serverNetwork)
	if not served then
		return false, `The server failed the boot with Catalog unowned: {serverRefusal}`
	end

	local reached: boolean, clientRefusal: any = pcall(clientOak.start, { Shop(client, false) }, clientNetwork)
	if not reached then
		return false, `The client failed the boot with Catalog unowned: {clientRefusal}`
	end

	return true, nil
end
