--[[
    A Polling event has iter and no on, since its owner drains it, so the
    boot needs no handler for it, while it still needs its Policy row
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
	local browse: any = network.events["Shop.browse"]

	if browse.on ~= nil or browse.iter == nil then
		return false, "Oak.volt's browse is not a Polling event, so this case proves nothing"
	end

	local shop: any = nil
	local module: any = Shop(server, true, function (created: any)
		shop = created
	end)

	local booted: boolean, refusal: any = pcall(Oak.start, { module }, network)
	if not booted then
		return false, `A Polling event with no handler failed the boot: {refusal}`
	end

	if shop.Client.browse ~= nil or shop.Policy.browse == nil then
		return false, "ShopService has a browse handler, or no browse row, so this case proves nothing"
	end

	return true, nil
end
