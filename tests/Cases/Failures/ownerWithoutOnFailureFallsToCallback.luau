--[[
    A failure on a Shop message whose service defines no onFailure goes to
    the game-wide callback with its player, kind and detail, and once the
    service defines one, read as each failure arrives, the next goes there
--]]

--!strict
local Environment = require("../../Environment")

local DETAIL: string = "Shop.report: " -- How the detail of a failure in Shop.report's listener opens

type Call = { n: number, [number]: any }

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:substitute("Property", { forget = function () end })

	local serverNetwork: any = server:network("Oak")
	local Failures: any = server:load("Failures")

	local shop: { [string]: any } = {}
	local fellThrough: { Call } = {}

	Failures.bind(serverNetwork, { Shop = shop }, true)
	Failures.set(function (...: any)
		table.insert(fellThrough, table.pack(...))
	end)

	serverNetwork.Shop.report.on(function ()
		error("The listener broke")
	end)

	local player, transport = server.mock:join("Player")
	local clientNetwork: any = server:client(transport):network("Oak")

	server:step(Environment.HANDSHAKE)
	clientNetwork.Shop.report.fire("Report")
	server:step(Environment.DELIVERY)

	local call: Call? = fellThrough[1]

	if #fellThrough ~= 1 or not call or call.n ~= 3 or call[1] ~= player or call[2] ~= "listener" then
		return false, `The callback was called {#fellThrough} times, first for {call and call[1]}`
	end

	if call[3]:sub(1, #DETAIL) ~= DETAIL then
		return false, `The callback got the detail {call[3]}`
	end

	if #server.warnings ~= 0 then
		return false, `Volt's default ran beside the callback: {server.warnings[1]}`
	end

	local claimed: number = 0

	shop.onFailure = function ()
		claimed += 1
	end

	clientNetwork.Shop.report.fire("Report")
	server:step(Environment.DELIVERY)

	if claimed ~= 1 or #fellThrough ~= 1 then
		return false, `An onFailure defined after the bind took {claimed} failures, the callback {#fellThrough}`
	end

	return true, nil
end
