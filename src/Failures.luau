--[[
    Takes the one failure slot of the Network Oak starts with, and hands
    each failure Volt reports to the table owning its message, the realm's
    Oak.onFailure callback or Volt's own default handler
--]]

--!strict
local Failures = {}

local Volt = require(script.Parent.Parent.Volt)

local OWNER: string = "^([^%.:]+)%.[^:]*: " -- The namespace of the registry name a message's detail opens with

-- The kinds that concern one message, whose detail opens with its registry name; a packet's rate names none
local MESSAGE_KINDS: { [string]: true } = {
	decode = true,
	listener = true,
	handler = true,
	queue = true,
	resolve = true,
	rate = true,
}

type Bot = Volt.Bot
type Handler = (...any) -> ()

local Callback: Handler? = nil -- The realm's game-wide handler, which Oak.onFailure sets

-- Runs one of the game's handlers under pcall, so one that throws is warned and the rest of its packet still arrives
local function protect(handler: Handler, ...: any)
	local ok: boolean, raised: any = pcall(handler, ...)
	if not ok then
		warn(`Oak: a failure handler raised: {raised}`)
	end
end

--[[
    Takes the Network's failure slot, keeping the default handler Volt
    hands back for a failure nothing else takes. A table's onFailure is
    read as each failure arrives, so one defined after the boot counts
--]]

function Failures.bind(network: any, owners: { [string]: any }, isServer: boolean)
	local Property = require(script.Parent.Property)
	local default: Handler

	local function route(player: (Player | Bot)?, kind: string, detail: string)
		-- What that player holds no longer matches any Property's copy, whoever takes the failure
		if isServer and player and kind == "outgoing" then
			Property.forget(player)
		end

		local namespace: string? = MESSAGE_KINDS[kind] and detail:match(OWNER)
		local owner: any = namespace and owners[namespace]
		local handler: Handler? = owner and owner.onFailure

		if handler then
			if isServer then
				return protect(handler, player, kind, detail)
			end

			-- The client has no player, so a controller's handler takes none
			return protect(handler, kind, detail)
		end

		if Callback then
			return protect(Callback, player, kind, detail)
		end

		default(player, kind, detail)
	end

	default = network.onFailure(route)
end

--[[
    Sets the realm's game-wide failure handler, replacing any set before,
    for every failure no table's onFailure takes
--]]

function Failures.set(callback: Handler)
	Callback = callback
end

return Failures
