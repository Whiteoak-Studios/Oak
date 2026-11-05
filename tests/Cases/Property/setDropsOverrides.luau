--[[
    Set moves every player to the value and drops every override, so a
    later SetTop reaches the player who held one, and a player whose
    override already equals the value is not sent it again
--]]

--!strict
local Environment = require("../../Environment")

local START: number = 250 -- The top value both players are sent on joining
local ALICE: number = 900 -- Alice's own value, which a Set to it leaves her holding
local EVERYONE: number = 300 -- What a Set moves both players to
local LATER: number = 400 -- A SetTop after the Set, which reaches Alice now her override is gone

return function (): (boolean, string | nil)
	local server = Environment.new()
	local network: any = server:network("Oak")
	local Property: any = server:load("Property")

	Property.prepare(network)
	local coins: any = Property.new(network.Shop.coins, START)
	Property.bind(network)

	local alice, aliceTransport = server.mock:join("Alice")
	local bob, bobTransport = server.mock:join("Bob")
	local aliceHeard: { number } = {}
	local bobHeard: { number } = {}

	server:client(aliceTransport):network("Oak").Shop.coins.on(function (value: number)
		table.insert(aliceHeard, value)
	end)

	server:client(bobTransport):network("Oak").Shop.coins.on(function (value: number)
		table.insert(bobHeard, value)
	end)

	server:step(Environment.HELD)
	coins:SetFor(alice, ALICE)
	server:step(Environment.DELIVERY)

	-- Alice already holds the value, so only Bob is sent it
	coins:Set(ALICE)
	server:step(Environment.DELIVERY)

	local alicePath: string = table.concat(aliceHeard, " ")
	local bobPath: string = table.concat(bobHeard, " ")

	if alicePath ~= `{START} {ALICE}` or bobPath ~= `{START} {ALICE}` then
		return false, `A Set equal to Alice's override sent Alice {alicePath} and Bob {bobPath}`
	end

	coins:SetFor(alice, START)
	coins:Set(EVERYONE)
	server:step(Environment.DELIVERY)

	if coins:GetFor(alice) ~= EVERYONE or coins:GetFor(bob) ~= EVERYONE or coins:Get() ~= EVERYONE then
		return false, `After Set, GetFor gave Alice {coins:GetFor(alice)} and Bob {coins:GetFor(bob)}`
	end

	coins:SetTop(LATER)
	server:step(Environment.DELIVERY)

	alicePath = table.concat(aliceHeard, " ")
	bobPath = table.concat(bobHeard, " ")

	if alicePath ~= `{START} {ALICE} {START} {EVERYONE} {LATER}` or bobPath ~= `{START} {ALICE} {EVERYONE} {LATER}` then
		return false, `Set left an override behind: Alice heard {alicePath} and Bob {bobPath}`
	end

	return true, nil
end
