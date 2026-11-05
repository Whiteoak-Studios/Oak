--[[
    Every packet-scoped kind goes to the game-wide callback with its player,
    kind and detail, never to a table's onFailure, even where the detail
    opens with a word or a registry name that a started table's namespace is
--]]

--!strict
local Environment = require("../../Environment")

type Call = { n: number, [number]: any }
type Failure = { kind: string, detail: string }

-- Volt's own detail texts for each packet-scoped kind, and two that open with a namespace
local PACKET_FAILURES: { Failure } = {
	{ kind = "packet", detail = "unknown message 9" },
	{ kind = "rate", detail = "over 240 packets a second" },
	{ kind = "handshake", detail = "Volt: schema mismatch (client 0x0EE67A62, server 0xBBFA23D4)" },
	{ kind = "outgoing", detail = "over maxOutgoing, a message was dropped" },
	{ kind = "departed", detail = "fired at a player who has left" },
	{ kind = "budget", detail = "over the budget, unreliable messages dropped: 3" },
	{ kind = "packet", detail = "Shop.buy: truncated" },
}

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:substitute("Property", { forget = function () end })

	local serverNetwork: any = server:network("Oak")
	local Failures: any = server:load("Failures")

	local claimed: number = 0
	local fellThrough: { Call } = {}

	local function claim()
		claimed += 1
	end

	-- Volt owns the namespace the handshake's detail opens with, as a VoltService would
	Failures.bind(serverNetwork, { Shop = { onFailure = claim }, Volt = { onFailure = claim } }, true)
	Failures.set(function (...: any)
		table.insert(fellThrough, table.pack(...))
	end)

	-- Volt hands back the handler it replaces, which is Oak's route, so it goes straight back
	local route: any = serverNetwork.onFailure(function () end)
	serverNetwork.onFailure(route)

	local player = server.mock:join("Player")

	for index: number, failure: Failure in PACKET_FAILURES do
		route(player, failure.kind, failure.detail)

		local call: Call? = fellThrough[index]
		if not call or call.n ~= 3 or call[1] ~= player or call[2] ~= failure.kind or call[3] ~= failure.detail then
			return false, `A {failure.kind} failure, {failure.detail}, reached the callback as {call and call[3]}`
		end
	end

	if claimed ~= 0 or #fellThrough ~= #PACKET_FAILURES then
		return false, `A table's onFailure took {claimed} packet failures, the callback {#fellThrough}`
	end

	return true, nil
end
