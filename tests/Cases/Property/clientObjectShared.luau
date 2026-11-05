--[[
    On the client a second Property for one event returns the same object
    and connects no second listener: a Single event refuses another on, a
    Many event delivers each value once, and another event gets its own
--]]

--!strict
local Environment = require("../../Environment")

local GREETING: string = "Hello" -- What the server sends on the Many event

return function (): (boolean, string | nil)
	local server = Environment.new()
	local serverNetwork: any = server:network("Oak")

	local player, transport = server.mock:join("Alice")
	local client = server:client(transport)
	local clientNetwork: any = client:network("Oak")
	local ClientProperty: any = client:load("ClientProperty")

	local first: any = ClientProperty.new(clientNetwork.Shop.coins)
	local again: boolean, second: any = pcall(ClientProperty.new, clientNetwork.Shop.coins)

	if not again or not rawequal(first, second) then
		return false, `A second Property for Shop.coins gave {second} rather than the first object`
	end

	-- Shop.coins takes one listener, the Property's, so another on is refused
	local connected: boolean = pcall(clientNetwork.Shop.coins.on, function () end)
	if connected then
		return false, "Shop.coins took a second listener, so the Property never connected the first"
	end

	if rawequal(ClientProperty.new(clientNetwork.Shop.stock), first) then
		return false, "Shop.stock got the object Shop.coins has"
	end

	local chat: any = ClientProperty.new(clientNetwork.Shop.chat)
	local calls: number = 0

	chat:Observe(function ()
		calls += 1
	end)

	if not rawequal(ClientProperty.new(clientNetwork.Shop.chat), chat) then
		return false, "A second Property for Shop.chat gave another object"
	end

	server:step(Environment.HANDSHAKE)
	serverNetwork.Shop.chat.fire(player, GREETING)
	server:step(Environment.DELIVERY)

	if calls ~= 1 or chat:Get() ~= GREETING then
		return false, `One chat line reached the observer {calls} times, and Get gave {chat:Get()}`
	end

	return true, nil
end
