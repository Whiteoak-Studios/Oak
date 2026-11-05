--[[
    After a drop that comes once Alice's handshake is accepted nothing is
    resent, however many frames pass: the next message she gets is the
    next set, sent even though it equals the value she was last sent
--]]

--!strict
local Environment = require("../../Environment")

local START: number = 250 -- The value Alice is sent when she joins
local WAITED: number = 6 -- Frames that pass after the drop with no set

return function (): (boolean, string | nil)
	local server = Environment.new()
	local network: any = server:network("Oak")
	local Property: any = server:load("Property")

	Property.prepare(network)
	local coins: any = Property.new(network.Shop.coins, START)
	Property.bind(network)

	local alice, transport = server.mock:join("Alice")
	local heard: { number } = {}

	server:client(transport):network("Oak").Shop.coins.on(function (value: number)
		table.insert(heard, value)
	end)

	server:step(Environment.HELD)

	-- Volt dropped a message to Alice after her handshake, and Failures hands the drop on
	Property.forget(alice)
	server:step(WAITED)

	if table.concat(heard, " ") ~= `{START}` then
		return false, `A drop after the handshake was resent unasked: Alice heard {table.concat(heard, " ")}`
	end

	coins:SetTop(START)
	server:step(Environment.DELIVERY)

	if table.concat(heard, " ") ~= `{START} {START}` then
		return false, `The next set after the drop sent Alice {table.concat(heard, " ")} rather than {START} {START}`
	end

	return true, nil
end
