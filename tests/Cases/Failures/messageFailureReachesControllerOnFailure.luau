--[[
    On the client, a failure on a Shop message goes to the controller
    owning Shop with only its kind and detail, since the client has no
    player, and Volt's default and Property hear nothing of it
--]]

--!strict
local Environment = require("../../Environment")

local DETAIL: string = "Shop.chat: " -- How the detail of a failure in Shop.chat's listener opens

type Call = { n: number, [number]: any }

return function (): (boolean, string | nil)
	local server = Environment.new()
	local serverNetwork: any = server:network("Oak")

	local player, transport = server.mock:join("Player")
	local client = server:client(transport)
	local forgotten: number = 0

	client:substitute("Property", {
		forget = function ()
			forgotten += 1
		end,
	})

	local clientNetwork: any = client:network("Oak")
	local Failures: any = client:load("Failures")

	local claimed: { Call } = {}
	local shop: { [string]: any } = {
		onFailure = function (...: any)
			table.insert(claimed, table.pack(...))
		end,
	}

	Failures.bind(clientNetwork, { Shop = shop }, false)

	clientNetwork.Shop.chat.on(function ()
		error("The listener broke")
	end)

	server:step(Environment.HANDSHAKE)
	serverNetwork.Shop.chat.fire(player, "Chat")
	server:step(Environment.DELIVERY)

	local call: Call? = claimed[1]

	if #claimed ~= 1 or not call or call.n ~= 2 or call[1] ~= "listener" then
		return false, `Shop's onFailure was called {#claimed} times, first with {call and call.n} arguments`
	end

	if call[2]:sub(1, #DETAIL) ~= DETAIL then
		return false, `Shop's onFailure got the detail {call[2]}`
	end

	if #client.warnings ~= 0 or forgotten ~= 0 then
		return false, `The client warned {client.warnings[1]}, and Property forgot {forgotten} times`
	end

	return true, nil
end
