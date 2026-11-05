--[[
    A Property in a service's Client is not taken for a handler: only a
    function is one, so a Property beside the handlers boots and is never
    connected
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

local STARTING_COINS: number = 0 -- The Property's default

return function (): (boolean, string | nil)
	local server = Environment.new()
	local network: any = server:network("Oak")
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", {
		prepare = function () end,
		bind = function () end,

		-- The server half, as far as binding sees it: a table, never a function
		new = function (handle: any, default: any): any
			return { handle = handle, top = default }
		end,
	})
	server:substitute("ClientProperty", {})

	local Oak: any = server:load("init")

	local module: any = Shop(server, true, function (shop: any)
		shop.Client.coins = Oak.Property(network.Shop.coins, STARTING_COINS)
	end)

	local booted: boolean, refusal: any = pcall(Oak.start, { module }, network)
	if not booted then
		return false, `A Property in Client failed the boot: {refusal}`
	end

	return true, nil
end
