--[[
    The binder calls each Client handler with a colon, so its self is the
    Client table and its first argument the player, for a function's
    handler answering an invoke and for an event's listener alike
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

local ITEM: number = 4 -- What the client buys
local REPORT: string = "Broken shelf" -- What the client reports

return function (): (boolean, string | nil)
	local server = Environment.new()
	local serverNetwork: any = server:network("Oak")
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", { prepare = function () end, bind = function () end })
	server:substitute("ClientProperty", {})

	local Oak: any = server:load("init")
	local shop: any = nil
	local calls: { [string]: { any } } = {}

	local module: any = Shop(server, true, function (created: any)
		shop = created

		function created.Client:buy(player: any, item: number): (boolean, string | nil)
			calls.buy = { self, player, item }
			return true, nil
		end

		function created.Client:report(player: any, text: string)
			calls.report = { self, player, text }
		end
	end)

	local booted: boolean, refusal: any = pcall(Oak.start, { module }, serverNetwork)
	if not booted then
		return false, `ShopService failed the boot: {refusal}`
	end

	local player, transport = server.mock:join("Player")
	local clientNetwork: any = server:client(transport):network("Oak")
	server:step(Environment.HANDSHAKE)

	local answered: boolean? = nil

	clientNetwork.Shop.buy.invoke(ITEM):andThen(function (ok: boolean)
		answered = ok
	end)
	clientNetwork.Shop.report.fire(REPORT)
	server:step(Environment.ROUND_TRIP)

	local buy: { any } = calls.buy or {}
	local report: { any } = calls.report or {}

	if answered ~= true or not rawequal(buy[1], shop.Client) or buy[2] ~= player or buy[3] ~= ITEM then
		return false, `The buy handler answered {answered} with self {buy[1]}, player {buy[2]} and item {buy[3]}`
	end

	if not rawequal(report[1], shop.Client) or report[2] ~= player or report[3] ~= REPORT then
		return false, `The report handler ran with self {report[1]}, player {report[2]} and text {report[3]}`
	end

	return true, nil
end
