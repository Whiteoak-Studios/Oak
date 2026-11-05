--[[
    On the client a collected table with a Client field or a Policy field
    fails the boot, naming the table and the field, since only a server
    service has either
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:network("Oak")

	local _, transport = server.mock:join("Player")
	local client = server:client(transport)
	client:substitute("Failures", { bind = function () end })
	client:substitute("Property", {})
	client:substitute("ClientProperty", {})

	local Oak: any = client:load("init")
	local network: any = client:network("Oak")

	local controller: any = Shop(client, false, function (shop: any)
		shop.Client = {}
	end)

	local hud: any = client:module("HudController", function (): any
		return Oak.create("HudController", { Policy = {} })
	end)

	local booted: boolean, refusal: any = pcall(Oak.start, { controller, hud }, network)
	local message: string = tostring(refusal)

	if booted or not message:find("ShopController has a Client field", 1, true) then
		return false, `A controller with Client gave {refusal} rather than a refusal naming it`
	end

	if not message:find("HudController has a Policy field", 1, true) then
		return false, `A controller with Policy was not named in the refusal: {message}`
	end

	return true, nil
end
