--[[
    Oak.volt's generated modules over one mock: a client's invoke answered
    by the server's handler settles at ROUND_TRIP steps, and a fire from
    the server reaches the client's listener at DELIVERY steps, not before
--]]

--!strict
local Environment = require("../../Environment")

local ITEM: number = 3 -- What the client buys, which the handler accepts
local COINS: number = 7 -- What the server fires at the client

return function (): (boolean, string | nil)
	local server = Environment.new()
	local serverNetwork: any = server:network("Oak")

	local player, transport = server.mock:join("Player")
	local client = server:client(transport)
	local clientNetwork: any = client:network("Oak")

	server:step(Environment.HANDSHAKE)

	local caller: any = nil

	serverNetwork.Shop.buy.on(function (from: any, item: number): (boolean, string?)
		caller = from

		return item == ITEM, nil
	end)

	local accepted: boolean? = nil

	clientNetwork.Shop.buy.invoke(ITEM):andThen(function (ok: boolean)
		accepted = ok
	end)

	server:step(Environment.ROUND_TRIP - 1)

	if accepted ~= nil then
		return false, `The invoke settled before {Environment.ROUND_TRIP} steps`
	end

	server:step()

	if accepted ~= true or caller ~= player then
		return false, `The invoke settled as {accepted}, its handler called for {caller}`
	end

	local heard: number? = nil

	clientNetwork.Shop.coins.on(function (coins: number)
		heard = coins
	end)

	serverNetwork.Shop.coins.fire(player, COINS)
	server:step(Environment.DELIVERY - 1)

	if heard ~= nil then
		return false, `The fire arrived before {Environment.DELIVERY} steps`
	end

	server:step()

	if heard ~= COINS then
		return false, `The client's listener heard {heard} rather than {COINS}`
	end

	return true, nil
end
