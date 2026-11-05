--[[
    A server's outgoing drop for a player reaches Property's forget once,
    with that player and before the callback or Volt's default takes it;
    no other kind, and no drop on the client, is handed over
--]]

--!strict
local Environment = require("../../Environment")

local MOST_FIRES: number = 100000 -- More fires than one frame's cap holds, so each loop below ends in a drop
local COINS: number = 1
local REPORT: string = "Report"
local DEFAULT_WARNING: string = "Volt: outgoing failure from Player: " -- How Volt's default warns of a player's drop

-- Every kind but outgoing, each of which a server may report with a player
local OTHER_KINDS: { string } = {
	"packet",
	"rate",
	"handshake",
	"decode",
	"listener",
	"handler",
	"queue",
	"departed",
	"resolve",
	"budget",
}

--[[
    A realm whose Property double logs each player it is told to forget
    into the shared log, its Failures loaded but not yet bound
--]]

local function realm(environment: any, log: { any }): any
	environment:substitute("Property", {
		forget = function (player: any)
			table.insert(log, { "forget", player })
		end,
	})

	return environment:load("Failures")
end

--[[
    Fires coins at a player whose client never loads, so all of it waits
    held, until the cap drops one, and says whether exactly one was dropped
--]]

local function overflow(serverNetwork: any, player: any): boolean
	local failures: { [string]: number } = serverNetwork.stats(player).failures

	for _ = 1, MOST_FIRES do
		serverNetwork.Shop.coins.fire(player, COINS)

		if failures.outgoing then
			return failures.outgoing == 1
		end
	end

	return false
end

return function (): (boolean, string | nil)
	-- 1) The callback takes the drop, after Property has forgotten
	local server = Environment.new()
	local log: { any } = {}
	local Failures: any = realm(server, log)
	local serverNetwork: any = server:network("Oak")

	Failures.bind(serverNetwork, {}, true)
	Failures.set(function (player: any, kind: string)
		table.insert(log, { kind, player })
	end)

	local player = server.mock:join("Player")

	if not overflow(serverNetwork, player) then
		return false, "Firing at a held player never dropped exactly one message"
	end

	if #log ~= 2 or log[1][1] ~= "forget" or log[1][2] ~= player or log[2][1] ~= "outgoing" then
		return false, `The drop reached {log[1] and log[1][1]} first, then {log[2] and log[2][1]}, {#log} calls in all`
	end

	-- 2) A failure of any other kind for that player is not handed over
	local route: any = serverNetwork.onFailure(function () end)
	serverNetwork.onFailure(route)

	for _, kind: string in OTHER_KINDS do
		route(player, kind, `Shop.coins: {kind} failed`)
	end

	for _, entry: { any } in log do
		if entry[1] == "forget" and entry ~= log[1] then
			return false, "Property was told to forget a player after a failure that was not an outgoing drop"
		end
	end

	-- 3) Volt's default takes the drop, after Property has forgotten, and still warns
	local quiet = Environment.new()
	local quietLog: { any } = {}
	local quietFailures: any = realm(quiet, quietLog)
	local quietNetwork: any = quiet:network("Oak")

	quietFailures.bind(quietNetwork, {}, true)

	local held = quiet.mock:join("Player")

	if not overflow(quietNetwork, held) then
		return false, "Firing at a held player never dropped exactly one message with no callback set"
	end

	if #quietLog ~= 1 or quietLog[1][2] ~= held then
		return false, `With no callback, Property was told to forget {#quietLog} times`
	end

	local warned: string = quiet.warnings[1] or ""

	if #quiet.warnings ~= 1 or warned:sub(1, #DEFAULT_WARNING) ~= DEFAULT_WARNING then
		return false, `With no callback, the server warned {warned} rather than Volt's outgoing warning`
	end

	-- 4) A drop on the client names no player and is not handed over
	local _, transport = server.mock:join("Watcher")
	local client = server:client(transport)
	local clientLog: { any } = {}
	local clientFailures: any = realm(client, clientLog)
	local clientNetwork: any = client:network("Oak")

	clientFailures.bind(clientNetwork, {}, false)

	local totals: { [string]: number } = clientNetwork.stats().failures

	for _ = 1, MOST_FIRES do
		clientNetwork.Shop.report.fire(REPORT)

		if totals.outgoing then
			break
		end
	end

	if totals.outgoing ~= 1 or #clientLog ~= 0 then
		return false, `The client dropped {totals.outgoing} messages, and Property was told to forget {#clientLog}`
	end

	return true, nil
end
