--[[
    SetTop moves every player without an override to the new top value and
    leaves one with an override on theirs; Get reads the top value, GetFor
    what each player sees, and an equal SetTop sends nothing
--]]

--!strict
local Environment = require("../../Environment")

local START: number = 250 -- The top value both players are sent on joining
local ALICE: number = 900 -- Alice's own value
local TOP: number = 300 -- The top value SetTop moves everyone else to

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
	coins:SetTop(TOP)
	server:step(Environment.DELIVERY)

	local alicePath: string = table.concat(aliceHeard, " ")
	local bobPath: string = table.concat(bobHeard, " ")

	if alicePath ~= `{START} {ALICE}` or bobPath ~= `{START} {TOP}` then
		return false, `Alice heard {alicePath} and Bob {bobPath} rather than {START} {ALICE} and {START} {TOP}`
	end

	if coins:Get() ~= TOP or coins:GetFor(alice) ~= ALICE or coins:GetFor(bob) ~= TOP then
		return false, `Get gave {coins:Get()}, GetFor gave Alice {coins:GetFor(alice)} and Bob {coins:GetFor(bob)}`
	end

	-- The same top value again reaches no one, Bob holding it and Alice holding her own
	coins:SetTop(TOP)
	server:step(Environment.DELIVERY)

	if table.concat(aliceHeard, " ") ~= alicePath or table.concat(bobHeard, " ") ~= bobPath then
		return false,
			`An equal SetTop sent again: Alice heard {table.concat(aliceHeard, " ")}, Bob {table.concat(bobHeard, " ")}`
	end

	return true, nil
end
