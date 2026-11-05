--[[
    A failure on a Shop message, from a player or a bot, goes to the service
    owning Shop with its player, kind and detail, and nowhere else: Volt's
    default stays silent and a game-wide callback set beside it hears none
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

	local claimed: { Call } = {}
	local shop: { [string]: any } = {
		onFailure = function (...: any)
			table.insert(claimed, table.pack(...))
		end,
	}

	Failures.bind(serverNetwork, { Shop = shop }, true)

	serverNetwork.Shop.report.on(function ()
		error("The listener broke")
	end)

	local player, transport = server.mock:join("Player")
	local clientNetwork: any = server:client(transport):network("Oak")

	server:step(Environment.HANDSHAKE)
	clientNetwork.Shop.report.fire("Report")
	server:step(Environment.DELIVERY)

	local first: Call? = claimed[1]

	if #claimed ~= 1 or not first or first.n ~= 3 or first[1] ~= player or first[2] ~= "listener" then
		return false, `Shop's onFailure was called {#claimed} times, first for {first and first[1]}`
	end

	if first[3]:sub(1, #DETAIL) ~= DETAIL then
		return false, `Shop's onFailure got the detail {first[3]}`
	end

	if #server.warnings ~= 0 then
		return false, `Volt's default ran beside Shop's onFailure: {server.warnings[1]}`
	end

	local called: number = 0

	Failures.set(function ()
		called += 1
	end)

	local bot = server.mock:addBot("Bot")
	local botNetwork: any = server:client(server.mock:connectBot(bot)):network("Oak")

	server:step(Environment.HANDSHAKE)
	botNetwork.Shop.report.fire("Report")
	server:step(Environment.DELIVERY)

	local second: Call? = claimed[2]

	if #claimed ~= 2 or not second or second[1] ~= bot or second[2] ~= "listener" then
		return false, `The bot's failure reached Shop's onFailure as {second and second[1]}, {#claimed} calls in all`
	end

	if called ~= 0 then
		return false, `The game-wide callback heard {called} failures Shop's onFailure owned`
	end

	return true, nil
end
