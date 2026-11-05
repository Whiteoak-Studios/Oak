--[[
    buy is declared unlimited in Oak.volt, yet its Policy row's rate holds:
    of five calls sent in one frame, the row's burst of three answers, and
    the rest reject with Volt's rate limited
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

local PER_SECOND: number = 3 -- The row's rate, and with no burst given its burst too
local CALLS: number = 5 -- Sent in one frame, more than the burst lets through
local ITEM: number = 1 -- What each call buys
local REJECTION: string = "rate limited" -- Volt's reason for a call past its rate

return function (): (boolean, string | nil)
	local server = Environment.new()
	local serverNetwork: any = server:network("Oak")
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", { prepare = function () end, bind = function () end })
	server:substitute("ClientProperty", {})

	local Oak: any = server:load("init")

	local module: any = Shop(server, true, function (shop: any)
		shop.Policy.buy = { rate = { perSecond = PER_SECOND } }
	end)

	local booted: boolean, refusal: any = pcall(Oak.start, { module }, serverNetwork)
	if not booted then
		return false, `ShopService failed the boot: {refusal}`
	end

	local _, transport = server.mock:join("Player")
	local clientNetwork: any = server:client(transport):network("Oak")
	server:step(Environment.HANDSHAKE)

	local answered: number = 0
	local rejected: { string } = {}

	for _ = 1, CALLS do
		clientNetwork.Shop.buy.invoke(ITEM):andThen(function ()
			answered += 1
		end, function (reason: string)
			table.insert(rejected, reason)
		end)
	end

	server:step(Environment.ROUND_TRIP)

	if answered ~= PER_SECOND or #rejected ~= CALLS - PER_SECOND then
		return false, `{answered} calls were answered and {#rejected} rejected, not {PER_SECOND} and the rest`
	end

	for _, reason: string in rejected do
		if reason ~= REJECTION then
			return false, `A call past the rate rejected with {reason} rather than {REJECTION}`
		end
	end

	return true, nil
end
