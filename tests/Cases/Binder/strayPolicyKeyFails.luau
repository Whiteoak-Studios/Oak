--[[
    A Policy key that names no inbound endpoint in the service's namespace
    fails the boot, naming it: one the schema lacks, and one for an event
    only the server sends, which Volt could never rate
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

local PER_SECOND: number = 3 -- What each stray row would allow
local STRAY: { string } = { "refund", "coins" } -- Missing, and outbound

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", { prepare = function () end, bind = function () end })
	server:substitute("ClientProperty", {})

	local Oak: any = server:load("init")
	local network: any = server:network("Oak")

	local module: any = Shop(server, true, function (shop: any)
		for _, name: string in STRAY do
			shop.Policy[name] = { rate = { perSecond = PER_SECOND } }
		end
	end)

	local booted: boolean, refusal: any = pcall(Oak.start, { module }, network)
	local message: string = tostring(refusal)

	for _, name: string in STRAY do
		if booted or not message:find(`ShopService.Policy.{name} names no inbound endpoint in Shop`, 1, true) then
			return false, `A {name} row gave {refusal} rather than a refusal naming it`
		end
	end

	return true, nil
end
