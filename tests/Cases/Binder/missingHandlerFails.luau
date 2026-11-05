--[[
    An inbound function or event with no handler in its service's Client
    fails the boot, naming the endpoint and the Client it is missing from
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

	local module: any = Shop(server, true, function (shop: any)
		shop.Client.buy = nil
		shop.Client.report = nil
	end)

	local booted: boolean, refusal: any = pcall(Oak.start, { module }, network)
	local message: string = tostring(refusal)

	for _, endpoint: string in { "Shop.buy", "Shop.report" } do
		if booted or not message:find(`{endpoint} has no handler in ShopService.Client`, 1, true) then
			return false, `A missing {endpoint} handler gave {refusal} rather than a refusal naming it`
		end
	end

	return true, nil
end
