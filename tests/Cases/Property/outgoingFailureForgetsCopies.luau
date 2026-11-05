--[[
    After an outgoing failure for Alice, every server Property sends her its
    next set though it equals what she was last sent, by SetTop and by
    SetFor, while the same equal set to Bob, who had no failure, is not sent
--]]

--!strict
local Environment = require("../../Environment")

local START: number = 250 -- The coin balance both players are sent on joining
local OWN: number = 900 -- Alice's own balance, which a drop also makes Oak forget
local LABEL: string = "Front" -- The stock's shelf label
local VERSION: number = 1 -- The stock's version

type Stock = { version: number, shelf: { label: string, slots: { [number]: any } } }

-- A new table each call, equal to every other it makes
local function stock(): Stock
	return { version = VERSION, shelf = { label = LABEL, slots = {} } }
end

return function (): (boolean, string | nil)
	local server = Environment.new()
	local network: any = server:network("Oak")
	local Property: any = server:load("Property")

	Property.prepare(network)
	local coins: any = Property.new(network.Shop.coins, START)
	local shelf: any = Property.new(network.Shop.stock, stock())
	Property.bind(network)

	local alice, aliceTransport = server.mock:join("Alice")
	local bob, bobTransport = server.mock:join("Bob")
	local aliceNetwork: any = server:client(aliceTransport):network("Oak")
	local bobNetwork: any = server:client(bobTransport):network("Oak")
	local heard: { [string]: number } = { aliceCoins = 0, aliceStock = 0, bobCoins = 0, bobStock = 0 }

	aliceNetwork.Shop.coins.on(function ()
		heard.aliceCoins += 1
	end)

	aliceNetwork.Shop.stock.on(function ()
		heard.aliceStock += 1
	end)

	bobNetwork.Shop.coins.on(function ()
		heard.bobCoins += 1
	end)

	bobNetwork.Shop.stock.on(function ()
		heard.bobStock += 1
	end)

	server:step(Environment.HELD)

	-- Volt dropped a message to Alice after her handshake, and Failures hands the drop on
	Property.forget(alice)

	coins:SetTop(START)
	shelf:SetTop(stock())
	server:step(Environment.DELIVERY)

	if heard.aliceCoins ~= 2 or heard.aliceStock ~= 2 then
		return false, `After her drop Alice was sent {heard.aliceCoins - 1} coins and {heard.aliceStock - 1} stock sets`
	end

	if heard.bobCoins ~= 1 or heard.bobStock ~= 1 then
		return false, `Bob, with no drop, was sent the equal sets again: {heard.bobCoins} coins, {heard.bobStock} stock`
	end

	-- The forgetting goes once its set has gone out, so an equal set after it sends nothing
	coins:SetTop(START)
	coins:SetFor(alice, OWN)
	server:step(Environment.DELIVERY)

	if heard.aliceCoins ~= 3 then
		return false, `Alice's forgetting outlived her resend: she has heard {heard.aliceCoins} coin values`
	end

	-- A player with an override loses its copy too, and an equal SetFor to Bob still sends nothing
	Property.forget(alice)
	coins:SetFor(alice, OWN)
	coins:SetFor(bob, START)
	server:step(Environment.DELIVERY)

	if heard.aliceCoins ~= 4 or heard.bobCoins ~= 1 then
		return false, `An equal SetFor after a drop gave Alice {heard.aliceCoins} coin values and Bob {heard.bobCoins}`
	end

	return true, nil
end
