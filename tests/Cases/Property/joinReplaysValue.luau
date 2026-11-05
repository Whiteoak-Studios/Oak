--[[
    Volt's joined callback sends a joiner each Property's value: a player
    set up before bind, one who joins after it and a bot alike, a Property
    made after bind included, and a value set before a join is the one sent
--]]

--!strict
local Environment = require("../../Environment")

local START: number = 250 -- The default, which Alice is sent when bind runs
local TOP: number = 300 -- The top value set before Bob and the bot join
local VERSION: number = 0 -- The version of the stock a Property made after bind starts with
local LABEL: string = "Front" -- Its shelf's label

type Stock = { version: number, shelf: { label: string, slots: { [number]: any } } }

return function (): (boolean, string | nil)
	local server = Environment.new()
	local network: any = server:network("Oak")
	local Property: any = server:load("Property")

	Property.prepare(network)
	local coins: any = Property.new(network.Shop.coins, START)

	-- Alice is set up before bind, so the joined callback runs for her as bind subscribes it
	local _, aliceTransport = server.mock:join("Alice")
	Property.bind(network)
	coins:SetTop(TOP)

	Property.new(network.Shop.stock, { version = VERSION, shelf = { label = LABEL, slots = {} } })

	local _, bobTransport = server.mock:join("Bob")
	local bot = server.mock:addBot("Bot")
	local botTransport = server.mock:connectBot(bot)

	local aliceHeard: { number } = {}
	local bobHeard: { number } = {}
	local botHeard: { number } = {}
	local bobStock: { Stock } = {}

	server:client(aliceTransport):network("Oak").Shop.coins.on(function (value: number)
		table.insert(aliceHeard, value)
	end)

	local bobNetwork: any = server:client(bobTransport):network("Oak")

	bobNetwork.Shop.coins.on(function (value: number)
		table.insert(bobHeard, value)
	end)

	bobNetwork.Shop.stock.on(function (value: Stock)
		table.insert(bobStock, value)
	end)

	server:client(botTransport):network("Oak").Shop.coins.on(function (value: number)
		table.insert(botHeard, value)
	end)

	server:step(Environment.HELD)

	if table.concat(aliceHeard, " ") ~= `{START} {TOP}` then
		return false, `Alice, set up before bind, heard {table.concat(aliceHeard, " ")} rather than {START} {TOP}`
	end

	if table.concat(bobHeard, " ") ~= `{TOP}` or table.concat(botHeard, " ") ~= `{TOP}` then
		return false, `Bob heard {table.concat(bobHeard, " ")} and the bot {table.concat(botHeard, " ")}, not {TOP}`
	end

	if #bobStock ~= 1 or bobStock[1].shelf.label ~= LABEL then
		return false, `Bob was sent {#bobStock} stock tables by the Property made after bind, rather than one`
	end

	return true, nil
end
