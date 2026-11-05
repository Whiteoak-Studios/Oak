--[[
    A player dropped before their handshake who leaves before it is
    accepted keeps no resend waiting once the left callback runs, while a
    player dropped the same way who stays is resent at their handshake
--]]

--!strict
local Environment = require("../../Environment")

local START: number = 250 -- The value each player is sent when they join

return function (): (boolean, string | nil)
	local server = Environment.new()
	local network: any = server:network("Oak")
	local Property: any = server:load("Property")

	-- The Network as bind sees it, keeping the handshake callback bind subscribes so the case can run it
	local handshakes: { (player: any) -> () } = {}
	local watched: any = setmetatable({
		onHandshake = function (callback: (player: any) -> ()): () -> ()
			table.insert(handshakes, callback)

			return network.onHandshake(callback)
		end,
	}, { __index = network })

	Property.prepare(network)
	Property.new(network.Shop.coins, START)
	Property.bind(watched)

	local departed: { any } = {}

	network.onFailure(function (player: any, kind: string)
		if kind == "departed" then
			table.insert(departed, player)
		end
	end)

	local alice = server.mock:join("Alice")
	local bob, bobTransport = server.mock:join("Bob")

	-- Volt dropped a held value to each before their handshake, and Failures hands each drop on
	Property.forget(alice)
	Property.forget(bob)
	server.mock:leave(alice)

	local bobHeard: { number } = {}

	server:client(bobTransport):network("Oak").Shop.coins.on(function (value: number)
		table.insert(bobHeard, value)
	end)

	server:step(Environment.HANDSHAKE + Environment.DELIVERY)

	if table.concat(bobHeard, " ") ~= `{START} {START}` then
		return false, `Bob, who stayed, heard {table.concat(bobHeard, " ")} rather than his join value and its resend`
	end

	-- Volt never runs it for a player who left, so running it anyway shows nothing waits for Alice
	for _, callback: (player: any) -> () in handshakes do
		callback(alice)
	end

	server:step(Environment.DELIVERY)

	if #departed ~= 0 then
		return false, `A resend waiting for Alice outlived her leave and was fired {#departed} times`
	end

	return true, nil
end
