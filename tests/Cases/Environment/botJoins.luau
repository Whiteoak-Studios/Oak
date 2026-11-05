--[[
    A bot added on the mock joins the server's runtime as a player does,
    and once connected runs a client of its own, whose fires and the
    server's settle within the steps a player's take; removing it leaves
--]]

--!strict
local Environment = require("../../Environment")

local GREETING: string = "Hello" -- What the server fires at the bot

return function (): (boolean, string | nil)
	local server = Environment.new()
	local serverNetwork: any = server:network("Oak")

	local joined: any = nil
	local handshaken: any = nil
	local left: any = nil

	serverNetwork.onJoin(function (player: any)
		joined = player
	end)

	serverNetwork.onHandshake(function (player: any)
		handshaken = player
	end)

	serverNetwork.onLeave(function (player: any)
		left = player
	end)

	local bot = server.mock:addBot("Bot")

	if joined ~= bot or not serverNetwork.isBot(bot) then
		return false, `onJoin ran for {joined}, and isBot answered {serverNetwork.isBot(bot)}`
	end

	local client = server:client(server.mock:connectBot(bot))
	local clientNetwork: any = client:network("Oak")
	local heard: string? = nil

	clientNetwork.Shop.chat.on(function (text: string)
		heard = text
	end)

	server:step(Environment.HANDSHAKE)

	if handshaken ~= bot then
		return false, `onHandshake ran for {handshaken} rather than the bot`
	end

	serverNetwork.Shop.chat.fire(bot, GREETING)
	server:step(Environment.DELIVERY)

	if heard ~= GREETING then
		return false, `The bot's client heard {heard} rather than {GREETING}`
	end

	server.mock:removeBot(bot)

	if left ~= bot then
		return false, `onLeave ran for {left} rather than the bot`
	end

	return true, nil
end
