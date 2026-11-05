--[[
    A function the server calls has invoke and no on in the server's
    module, so the server boots with no handler and no Policy row for it
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", { prepare = function () end, bind = function () end })
	server:substitute("ClientProperty", {})

	local Oak: any = server:load("init")
	local network: any = server:network("Oak")
	local confirm: any = network.functions["Shop.confirm"]

	if confirm.on ~= nil or confirm.invoke == nil then
		return false, "Oak.volt's confirm is not a function the server calls, so this case proves nothing"
	end

	local shop: any = nil
	local module: any = Shop(server, true, function (created: any)
		shop = created
	end)

	local booted: boolean, refusal: any = pcall(Oak.start, { module }, network)
	if not booted then
		return false, `A server-to-client function failed the server's boot: {refusal}`
	end

	if shop.Client.confirm ~= nil or shop.Policy.confirm ~= nil then
		return false, "ShopService has a confirm handler or row, so this case proves nothing"
	end

	return true, nil
end
