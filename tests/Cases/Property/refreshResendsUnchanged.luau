--[[
    Refresh sends what a player sees again though it is unchanged, to one
    player or to all, each player with an override getting theirs; an
    equal set after it still sends nothing, and a leaver is never sent one
--]]

--!strict
local Environment = require("../../Environment")

local START: number = 250 -- The top value both players are sent on joining
local BOB: number = 900 -- Bob's own value

return function (): (boolean, string | nil)
	local server = Environment.new()
	local network: any = server:network("Oak")
	local Property: any = server:load("Property")

	Property.prepare(network)
	local coins: any = Property.new(network.Shop.coins, START)
	Property.bind(network)

	local departed: { any } = {}

	network.onFailure(function (player: any, kind: string)
		if kind == "departed" then
			table.insert(departed, player)
		end
	end)

	local alice, aliceTransport = server.mock:join("Alice")
	local bob, bobTransport = server.mock:join("Bob")
	local carol = server.mock:join("Carol")
	local aliceHeard: { number } = {}
	local bobHeard: { number } = {}

	server:client(aliceTransport):network("Oak").Shop.coins.on(function (value: number)
		table.insert(aliceHeard, value)
	end)

	server:client(bobTransport):network("Oak").Shop.coins.on(function (value: number)
		table.insert(bobHeard, value)
	end)

	server:step(Environment.HELD)
	coins:SetFor(bob, BOB)
	server:step(Environment.DELIVERY)

	coins:Refresh(alice)
	server:step(Environment.DELIVERY)

	if table.concat(aliceHeard, " ") ~= `{START} {START}` or table.concat(bobHeard, " ") ~= `{START} {BOB}` then
		return false, `Refresh(Alice) gave Alice {table.concat(aliceHeard, " ")} and Bob {table.concat(bobHeard, " ")}`
	end

	server.mock:leave(carol)
	coins:Refresh(carol)
	coins:Refresh()
	server:step(Environment.DELIVERY)

	local alicePath: string = table.concat(aliceHeard, " ")
	local bobPath: string = table.concat(bobHeard, " ")

	if alicePath ~= `{START} {START} {START}` or bobPath ~= `{START} {BOB} {BOB}` then
		return false, `Refresh() gave Alice {alicePath} and Bob {bobPath}`
	end

	if #departed ~= 0 then
		return false, `Refresh sent {#departed} values to a player who had left`
	end

	-- What Refresh sent is what each holds now, so equal sets still send nothing
	coins:SetTop(START)
	coins:SetFor(bob, BOB)
	server:step(Environment.DELIVERY)

	if table.concat(aliceHeard, " ") ~= alicePath or table.concat(bobHeard, " ") ~= bobPath then
		return false, `An equal set after Refresh sent again: Alice heard {table.concat(aliceHeard, " ")}`
	end

	return true, nil
end
