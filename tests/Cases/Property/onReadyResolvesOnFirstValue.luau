--[[
    Before the first value Get is nil, IsReady false and OnReady pending;
    the first value flips IsReady and resolves OnReady with it, a cancelled
    OnReady leaving the others, and OnReady after it resolves at once
--]]

--!strict
local Environment = require("../../Environment")

local FIRST: number = 5 -- The first value the server sends
local SECOND: number = 6 -- A later one, which OnReady never resolves with

return function (): (boolean, string | nil)
	local server = Environment.new()
	local serverNetwork: any = server:network("Oak")

	local player, transport = server.mock:join("Alice")
	local client = server:client(transport)
	local clientNetwork: any = client:network("Oak")
	local coins: any = client:load("ClientProperty").new(clientNetwork.Shop.coins)

	local resolved: number? = nil
	local pending: any = coins:OnReady():andThen(function (value: number)
		resolved = value
	end)

	local cancelled: any = coins:OnReady()
	cancelled:cancel()

	server:step(Environment.HANDSHAKE)

	if coins:IsReady() or coins:Get() ~= nil or resolved ~= nil then
		return false, `Before any value, IsReady gave {coins:IsReady()}, Get {coins:Get()} and OnReady {resolved}`
	end

	serverNetwork.Shop.coins.fire(player, FIRST)
	server:step(Environment.DELIVERY)

	if not coins:IsReady() or coins:Get() ~= FIRST then
		return false, `After the first value, IsReady gave {coins:IsReady()} and Get {coins:Get()}`
	end

	if resolved ~= FIRST or pending:getStatus() ~= "Resolved" then
		return false, `OnReady resolved with {resolved}, its Promise {pending:getStatus()}`
	end

	if cancelled:getStatus() ~= "Cancelled" then
		return false, `The cancelled OnReady became {cancelled:getStatus()}`
	end

	serverNetwork.Shop.coins.fire(player, SECOND)
	server:step(Environment.DELIVERY)

	-- Already ready, so it resolves at once, with the value present now
	local ready: boolean, value: any = coins:OnReady():await()

	if not ready or value ~= SECOND or resolved ~= FIRST then
		return false, `OnReady once ready gave {ready} and {value}, and the first resolved with {resolved}`
	end

	return true, nil
end
