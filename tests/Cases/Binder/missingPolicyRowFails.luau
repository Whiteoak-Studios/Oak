--[[
    An inbound endpoint with no Policy row fails the boot, naming it, a
    Polling event as well as a function, so no endpoint Oak binds is ever
    left unlimited
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

local UNROWED: { string } = { "buy", "browse" } -- A function and a Polling event

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", { prepare = function () end, bind = function () end })
	server:substitute("ClientProperty", {})

	local Oak: any = server:load("init")
	local network: any = server:network("Oak")

	local module: any = Shop(server, true, function (shop: any)
		for _, name: string in UNROWED do
			shop.Policy[name] = nil
		end
	end)

	local booted: boolean, refusal: any = pcall(Oak.start, { module }, network)
	local message: string = tostring(refusal)

	for _, name: string in UNROWED do
		if booted or not message:find(`Shop.{name} has no Policy row in ShopService`, 1, true) then
			return false, `Shop.{name} with no row gave {refusal} rather than a refusal naming it`
		end
	end

	return true, nil
end
