--[[
    On the client, a controller that connects the handler of a function
    the server calls in its Init boots, and its Start runs after
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:network("Oak")

	local _, transport = server.mock:join("Player")
	local client = server:client(transport)
	local network: any = client:network("Oak")
	client:substitute("Failures", { bind = function () end })
	client:substitute("Property", {})
	client:substitute("ClientProperty", {})

	local Oak: any = client:load("init")
	local connected: boolean? = nil

	local module: any = Shop(client, false, function (shop: any)
		function shop:Start()
			connected = network.Shop.confirm.connected()
		end
	end)

	local booted: boolean, refusal: any = pcall(Oak.start, { module }, network)
	if not booted then
		return false, `A controller that connects confirm in Init failed the boot: {refusal}`
	end

	if connected ~= true then
		return false, `ShopController's Start found confirm connected as {connected}`
	end

	return true, nil
end
