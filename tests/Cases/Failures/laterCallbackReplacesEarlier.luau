--[[
    A game-wide callback set before the bind takes the failures after it,
    and a later Oak.onFailure replaces it, so the earlier one hears nothing
    more and each failure reaches only the callback set last
--]]

--!strict
local Environment = require("../../Environment")

local DETAIL: string = "unknown message 9" -- A packet failure, which no table's onFailure takes

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:substitute("Property", { forget = function () end })

	local serverNetwork: any = server:network("Oak")
	local Failures: any = server:load("Failures")

	local first: number = 0
	local second: number = 0

	Failures.set(function ()
		first += 1
	end)

	Failures.bind(serverNetwork, {}, true)

	-- Volt hands back the handler it replaces, which is Oak's route, so it goes straight back
	local route: any = serverNetwork.onFailure(function () end)
	serverNetwork.onFailure(route)

	local player = server.mock:join("Player")
	route(player, "packet", DETAIL)

	if first ~= 1 then
		return false, `The callback set before the bind heard {first} failures rather than one`
	end

	Failures.set(function ()
		second += 1
	end)

	route(player, "packet", DETAIL)

	if first ~= 1 or second ~= 1 then
		return false, `After the second callback, the first heard {first} failures and the second {second}`
	end

	if #server.warnings ~= 0 then
		return false, `Volt's default ran beside a callback: {server.warnings[1]}`
	end

	return true, nil
end
