--[[
    Observe calls back at once when a value is present and not before it,
    then with every value the server sends, until the function it returns
    is called, from outside or inside a callback; the others carry on
--]]

--!strict
local Environment = require("../../Environment")

local FIRST: number = 5 -- The first value the server sends
local SECOND: number = 6 -- The next, which both observers see
local THIRD: number = 7 -- Sent once the early observer has disconnected

return function (): (boolean, string | nil)
	local server = Environment.new()
	local serverNetwork: any = server:network("Oak")

	local player, transport = server.mock:join("Alice")
	local client = server:client(transport)
	local clientNetwork: any = client:network("Oak")
	local coins: any = client:load("ClientProperty").new(clientNetwork.Shop.coins)

	local early: { number } = {}
	local late: { number } = {}
	local once: { number } = {}

	local disconnectEarly: () -> () = coins:Observe(function (value: number)
		table.insert(early, value)
	end)

	if #early ~= 0 then
		return false, `Observe called back with {early[1]} before any value arrived`
	end

	server:step(Environment.HANDSHAKE)
	serverNetwork.Shop.coins.fire(player, FIRST)
	server:step(Environment.DELIVERY)

	coins:Observe(function (value: number)
		table.insert(late, value)
	end)

	local earlyPath: string = table.concat(early, " ")
	local latePath: string = table.concat(late, " ")

	if earlyPath ~= `{FIRST}` or latePath ~= `{FIRST}` then
		return false, `On the first value the early observer heard {earlyPath}, the late one {latePath}`
	end

	-- This one disconnects itself on the first value it hears after connecting; its call with the value
	-- present comes before Observe returns its disconnect, so until then disconnecting does nothing
	local disconnectOnce: () -> () = function () end
	disconnectOnce = coins:Observe(function (value: number)
		table.insert(once, value)
		disconnectOnce()
	end)

	serverNetwork.Shop.coins.fire(player, SECOND)
	server:step(Environment.DELIVERY)

	disconnectEarly()
	disconnectEarly()
	serverNetwork.Shop.coins.fire(player, THIRD)
	server:step(Environment.DELIVERY)

	if table.concat(early, " ") ~= `{FIRST} {SECOND}` then
		return false, `The disconnected observer heard {table.concat(early, " ")}`
	end

	if table.concat(late, " ") ~= `{FIRST} {SECOND} {THIRD}` then
		return false, `The observer still connected heard {table.concat(late, " ")}`
	end

	if table.concat(once, " ") ~= `{FIRST} {SECOND}` then
		return false, `The observer that disconnected itself heard {table.concat(once, " ")}`
	end

	return true, nil
end
