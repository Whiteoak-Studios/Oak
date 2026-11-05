--[[
    A player whose client loads its Network long after they joined gets
    their join value once their handshake completes, followed in order by
    a set made while it was held, and nothing before the handshake
--]]

--!strict
local Environment = require("../../Environment")

local START: number = 250 -- The value Alice is sent when she joins
local TOP: number = 300 -- A set made while her client has not loaded
local WAITED: number = 5 -- Steps that pass before her client loads its Network

return function (): (boolean, string | nil)
	local server = Environment.new()
	local network: any = server:network("Oak")
	local Property: any = server:load("Property")

	Property.prepare(network)
	local coins: any = Property.new(network.Shop.coins, START)
	Property.bind(network)

	local _, transport = server.mock:join("Alice")
	server:step(WAITED)
	coins:SetTop(TOP)
	server:step(WAITED)

	local heard: { number } = {}

	server:client(transport):network("Oak").Shop.coins.on(function (value: number)
		table.insert(heard, value)
	end)

	server:step(Environment.HANDSHAKE)

	if #heard ~= 0 then
		return false, `Alice heard {table.concat(heard, " ")} before her handshake's held messages reached her`
	end

	server:step(Environment.HELD - Environment.HANDSHAKE)

	if table.concat(heard, " ") ~= `{START} {TOP}` then
		return false, `Alice's late client heard {table.concat(heard, " ")} rather than {START} {TOP}`
	end

	return true, nil
end
