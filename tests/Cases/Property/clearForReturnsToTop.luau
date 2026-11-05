--[[
    ClearFor and ClearForList put players back on the top value, sending it
    only to one who holds something else, so a later SetTop reaches them,
    and clearing a player with no override changes nothing
--]]

--!strict
local Environment = require("../../Environment")

local START: number = 250 -- The top value both players are sent on joining
local OWN: number = 900 -- The override Alice and Bob each get
local TOP: number = 300 -- A SetTop once both are back on the top value

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

	-- Alice's override equals the top value she holds, so neither it nor its clearing sends anything
	coins:SetFor(alice, START)
	coins:SetFor(bob, OWN)
	coins:ClearFor(alice)
	coins:ClearForList({ bob, alice })
	coins:ClearFor(alice)
	server:step(Environment.DELIVERY)

	local alicePath: string = table.concat(aliceHeard, " ")
	local bobPath: string = table.concat(bobHeard, " ")

	if alicePath ~= `{START}` or bobPath ~= `{START} {OWN} {START}` then
		return false, `Alice heard {alicePath} and Bob {bobPath} rather than {START} and {START} {OWN} {START}`
	end

	if coins:GetFor(alice) ~= START or coins:GetFor(bob) ~= START then
		return false, `After clearing, GetFor gave Alice {coins:GetFor(alice)} and Bob {coins:GetFor(bob)}`
	end

	coins:SetTop(TOP)
	server:step(Environment.DELIVERY)

	alicePath = table.concat(aliceHeard, " ")
	bobPath = table.concat(bobHeard, " ")

	if alicePath ~= `{START} {TOP}` or bobPath ~= `{START} {OWN} {START} {TOP}` then
		return false, `A cleared override held on: Alice heard {alicePath} and Bob {bobPath}`
	end

	return true, nil
end
