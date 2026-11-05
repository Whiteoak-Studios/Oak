--[[
    A Client handler with no inbound declaration to connect to fails the
    boot, naming it: one the schema lacks, one for a function the server
    calls, and one for a Polling event, which has no on
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

local UNDECLARED: { string } = { "refund", "confirm", "browse" } -- Missing, outbound and Polling, in that order

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", { prepare = function () end, bind = function () end })
	server:substitute("ClientProperty", {})

	local Oak: any = server:load("init")
	local network: any = server:network("Oak")

	local module: any = Shop(server, true, function (shop: any)
		for _, name: string in UNDECLARED do
			shop.Client[name] = function () end
		end
	end)

	local booted: boolean, refusal: any = pcall(Oak.start, { module }, network)
	local message: string = tostring(refusal)

	for _, name: string in UNDECLARED do
		local expected: string = `ShopService.Client.{name} is a handler with no inbound declaration in Shop`

		if booted or not message:find(expected, 1, true) then
			return false, `A {name} handler gave {refusal} rather than a refusal naming it`
		end
	end

	return true, nil
end
