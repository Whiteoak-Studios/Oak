--[[
    ShopService's buy handler, connected by the booted Binder, answers a
    client's invoke: its Promise resolves with the handler's tuple, for a
    refusal as for a sale, and rejects with the text of a throw
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

local STOCKED: number = 1 -- An item the handler sells
local SOLD_OUT: number = 2 -- One it refuses
local JAMMED: number = 3 -- One it throws on
local ITEMS: { number } = { STOCKED, SOLD_OUT, JAMMED } -- Each bought once, all in one frame
local REFUSAL: string = "Sold out" -- The reason the handler refuses with
local FAULT: string = "The till jammed" -- What it throws, at level 0 so no source position comes with it

type Answer = { n: number, [number]: any }

return function (): (boolean, string | nil)
	local server = Environment.new()
	local serverNetwork: any = server:network("Oak")
	local Oak: any = server:load("init")
	local callers: { any } = {}

	local module: any = Shop(server, true, function (shop: any)
		function shop.Client:buy(player: any, item: number): (boolean, string | nil)
			table.insert(callers, player)

			if item == JAMMED then
				error(FAULT, 0)
			end

			if item == SOLD_OUT then
				return false, REFUSAL
			end

			return true, nil
		end
	end)

	local booted: boolean, refusal: any = pcall(Oak.start, { module }, serverNetwork)
	if not booted then
		return false, `ShopService failed the boot: {refusal}`
	end

	local alice, transport = server.mock:join("Alice")
	local clientNetwork: any = server:client(transport):network("Oak")
	server:step(Environment.HANDSHAKE)

	local answers: { [number]: Answer } = {}
	local rejections: { [number]: string } = {}

	for _, item: number in ITEMS do
		clientNetwork.Shop.buy.invoke(item):andThen(function (...: any)
			answers[item] = table.pack(...)
		end, function (reason: string)
			rejections[item] = reason
		end)
	end

	server:step(Environment.ROUND_TRIP)

	local sold: Answer? = answers[STOCKED]
	local refused: Answer? = answers[SOLD_OUT]

	if not sold or sold[1] ~= true or sold[2] ~= nil then
		return false, `The sale settled with {sold and sold[1]} and {sold and sold[2]}, or was rejected`
	end

	if not refused or refused[1] ~= false or refused[2] ~= REFUSAL then
		return false, `The refusal settled with {refused and refused[1]} and {refused and refused[2]}`
	end

	if rejections[JAMMED] ~= FAULT or answers[JAMMED] ~= nil then
		return false, `The call the handler threw on rejected with {rejections[JAMMED]} rather than {FAULT}`
	end

	if #callers ~= #ITEMS then
		return false, `The handler heard {#callers} calls rather than {#ITEMS}`
	end

	for _, caller: any in callers do
		if caller ~= alice then
			return false, `The handler heard a call from {caller} rather than Alice`
		end
	end

	return true, nil
end
