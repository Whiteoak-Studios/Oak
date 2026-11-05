--[[
    A client whose Network loads after its player joined: the server holds
    what it fires at them, accepts their handshake HANDSHAKE steps after
    the load, and the held message reaches them HELD steps after it
--]]

--!strict
local Environment = require("../../Environment")

local COINS: number = 5 -- What the server fires before the client has a runtime

return function (): (boolean, string | nil)
	local server = Environment.new()
	local serverNetwork: any = server:network("Oak")

	local joined: any = nil
	local handshaken: any = nil

	serverNetwork.onJoin(function (player: any)
		joined = player
	end)

	serverNetwork.onHandshake(function (player: any)
		handshaken = player
	end)

	local player, transport = server.mock:join("Player")
	local client = server:client(transport)

	if joined ~= player then
		return false, `onJoin ran for {joined} rather than the player who joined`
	end

	serverNetwork.Shop.coins.fire(player, COINS)
	server:step(Environment.HELD)

	local clientNetwork: any = client:network("Oak")
	local heard: number? = nil

	clientNetwork.Shop.coins.on(function (coins: number)
		heard = coins
	end)

	server:step(Environment.HANDSHAKE - 1)

	if handshaken ~= nil then
		return false, `The handshake was accepted before {Environment.HANDSHAKE} steps`
	end

	server:step()

	if handshaken ~= player or heard ~= nil then
		return false, `onHandshake ran for {handshaken}, and the client had heard {heard}`
	end

	server:step(Environment.HELD - Environment.HANDSHAKE)

	if heard ~= COINS then
		return false, `The held message reached the client as {heard} rather than {COINS}`
	end

	return true, nil
end
