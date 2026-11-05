--[[
    A player whose client loads late and whose drop comes before their
    handshake is sent every Property's current value once when the
    handshake is accepted, and only once; a bot's early drop waits for none
--]]

--!strict
local Environment = require("../../Environment")

local START: number = 250 -- The coin balance sent on joining
local TOP: number = 300 -- A balance set after the drop, while the client has not loaded
local LABEL: string = "Front" -- The stock's shelf label
local VERSION: number = 1 -- The stock's version
local WAITED: number = 4 -- Steps that pass before Alice's client loads its Network

return function (): (boolean, string | nil)
	local server = Environment.new()
	local network: any = server:network("Oak")
	local Property: any = server:load("Property")

	Property.prepare(network)
	local coins: any = Property.new(network.Shop.coins, START)
	Property.new(network.Shop.stock, { version = VERSION, shelf = { label = LABEL, slots = {} } })
	Property.bind(network)

	local alice, transport = server.mock:join("Alice")
	local bot = server.mock:addBot("Bot")
	local botTransport = server.mock:connectBot(bot)

	-- Volt dropped a held value to each before any handshake, and Failures hands each drop on
	Property.forget(alice)
	Property.forget(bot)
	coins:SetTop(TOP)
	server:step(WAITED)

	local coinsHeard: { number } = {}
	local stockHeard: number = 0
	local botHeard: { number } = {}
	local clientNetwork: any = server:client(transport):network("Oak")

	clientNetwork.Shop.coins.on(function (value: number)
		table.insert(coinsHeard, value)
	end)

	clientNetwork.Shop.stock.on(function ()
		stockHeard += 1
	end)

	server:client(botTransport):network("Oak").Shop.coins.on(function (value: number)
		table.insert(botHeard, value)
	end)

	server:step(Environment.HELD)

	-- What was held arrives first, the join values and the later set, and only then the resend
	if table.concat(coinsHeard, " ") ~= `{START} {TOP}` or stockHeard ~= 1 then
		return false, `Before the resend Alice heard coins {table.concat(coinsHeard, " ")} and {stockHeard} stock`
	end

	server:step(Environment.HANDSHAKE + Environment.DELIVERY - Environment.HELD)

	if table.concat(coinsHeard, " ") ~= `{START} {TOP} {TOP}` or stockHeard ~= 2 then
		return false, `At her handshake Alice was resent coins {table.concat(coinsHeard, " ")} and {stockHeard} stock`
	end

	-- A later drop finds the handshake done, so it leaves nothing waiting
	Property.forget(alice)
	server:step(Environment.HELD)

	if #coinsHeard ~= 3 or stockHeard ~= 2 then
		return false, `The resend went more than once: Alice heard {#coinsHeard} coin values and {stockHeard} stock`
	end

	-- Volt holds nothing for a bot, so the bot hears its join value and the set, and no resend
	if table.concat(botHeard, " ") ~= `{START} {TOP}` then
		return false, `The bot heard {table.concat(botHeard, " ")} rather than {START} {TOP}`
	end

	return true, nil
end
