--[[
    SetForList gives each listed player one value of their own and sends it
    only to those who hold something else, a SetTop then reaches only the
    rest, and a player in the list who has left gets no entry
--]]

--!strict
local Environment = require("../../Environment")

local START: number = 250 -- The top value every player is sent on joining
local SQUAD: number = 500 -- The value the squad's list gets
local TOP: number = 600 -- A SetTop after it, which only Carol sees
local LATER: number = 700 -- A SetTop once Carol has an override equal to the top value

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
	local carol, carolTransport = server.mock:join("Carol")
	local dave = server.mock:join("Dave")
	local heard: { [any]: { number } } = { [alice] = {}, [bob] = {}, [carol] = {} }

	for player: any, transport: any in { [alice] = aliceTransport, [bob] = bobTransport, [carol] = carolTransport } do
		server:client(transport):network("Oak").Shop.coins.on(function (value: number)
			table.insert(heard[player], value)
		end)
	end

	server:step(Environment.HELD)
	server.mock:leave(dave)

	coins:SetForList({ alice, bob, dave }, SQUAD)
	coins:SetTop(TOP)
	coins:SetForList({ alice, bob }, SQUAD)
	server:step(Environment.DELIVERY)

	local squadPath: string = `{START} {SQUAD}`

	if table.concat(heard[alice], " ") ~= squadPath or table.concat(heard[bob], " ") ~= squadPath then
		return false,
			`Alice heard {table.concat(heard[alice], " ")} and Bob {table.concat(heard[bob], " ")}, not {squadPath}`
	end

	if table.concat(heard[carol], " ") ~= `{START} {TOP}` then
		return false, `Carol heard {table.concat(heard[carol], " ")} rather than {START} {TOP}`
	end

	if coins:GetFor(alice) ~= SQUAD or coins:GetFor(carol) ~= TOP then
		return false, `GetFor gave Alice {coins:GetFor(alice)} and Carol {coins:GetFor(carol)}`
	end

	if coins:GetFor(dave) ~= TOP or #departed ~= 0 then
		return false, `Dave, who left, reads {coins:GetFor(dave)}, and {#departed} fires went to a leaver`
	end

	-- Carol's override equals what she holds, so it sends nothing, yet keeps her off the next top value
	coins:SetForList({ carol }, TOP)
	coins:SetTop(LATER)
	server:step(Environment.DELIVERY)

	if table.concat(heard[carol], " ") ~= `{START} {TOP}` or coins:GetFor(carol) ~= TOP then
		return false, `Carol's equal override heard {table.concat(heard[carol], " ")} and reads {coins:GetFor(carol)}`
	end

	return true, nil
end
