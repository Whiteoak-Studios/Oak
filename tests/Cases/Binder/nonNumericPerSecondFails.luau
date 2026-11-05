--[[
    A Policy row without a numeric perSecond fails the boot, naming it:
    one with only a burst, one whose perSecond is a string, and one with
    its numbers outside rate
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

local BURST: number = 4 -- A burst with no perSecond beside it
local PER_SECOND: number = 3 -- A perSecond set beside rate rather than inside it

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", { prepare = function () end, bind = function () end })
	server:substitute("ClientProperty", {})

	local Oak: any = server:load("init")
	local network: any = server:network("Oak")

	local module: any = Shop(server, true, function (shop: any)
		shop.Policy.chat = { rate = { burst = BURST } }
		shop.Policy.report = { rate = { perSecond = "fast" } }
		shop.Policy.buy = { perSecond = PER_SECOND }
	end)

	local booted: boolean, refusal: any = pcall(Oak.start, { module }, network)
	local message: string = tostring(refusal)

	for _, name: string in { "chat", "report", "buy" } do
		if booted or not message:find(`ShopService.Policy.{name} has no numeric rate.perSecond`, 1, true) then
			return false, `The {name} row gave {refusal} rather than a refusal naming it`
		end
	end

	return true, nil
end
