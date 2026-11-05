--[[
    The client module Volt 0.1.0 generated from Nested.volt: a writer per
    message this side sends, a reader per message it hears, the schema
    table the runtime starts from and the API a game calls. Generated code:
    change the schema and run volt again rather than editing this file
--]]

--!strict
--!native
--!optimize 2
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Volt = require(ReplicatedStorage.Packages.Volt)

type Bot = Volt.Bot

type ClientEvent<A...> = { fire: (A...) -> () }

type ClientListener<A...> = {
	on: (listener: (A...) -> ()) -> () -> (),
	iter: () -> () -> (number, A...),
}

type ClientPolling<A...> = { iter: () -> () -> (number, A...) }

type ClientFunction<A..., R...> = { invoke: (A...) -> (boolean, R...) }

type ClientPromise<A...> = { invoke: (A...) -> any }

type Exported<T> = {
	write: (value: T) -> (buffer, { any }?),
	read: (packet: buffer, side: { any }?) -> T,
}

local runtime: Volt.Runtime

local function readOuter_Inner_announce(player: (Player | Bot)?, packet: buffer, cursor: number, _: { any }, sideCursor: number, length: number): (number, number)
	if cursor + 1 > length then
		error("Outer.Inner.announce: truncated")
	end

	local value: number = buffer.readu8(packet, cursor)
	cursor += 1

	return runtime:deliver(1, player, cursor, sideCursor, value)
end

runtime = Volt.start({
	version = "0.1.0",
	hash = 0xE60CDDF4,
	scope = "Oak",
	side = "client",
	idBytes = 1,
	options = {
		flush = 1,
		manualReplication = false,
		maxOutgoing = 262144,
		maxPacket = 8192,
		maxPacketsPerSecond = 240,
		unreliableBudget = 900,
		writeValidation = true,
	},

	messages = {
		[1] = { name = "Outer.Inner.announce", kind = "event", mode = "SingleAsync", queue = 64, read = readOuter_Inner_announce },
	},

	outgoing = {},
})

local Network = {
	Outer = table.freeze({
		Inner = table.freeze({
			announce = table.freeze({
				on = function (listener: (value: number) -> ()): () -> ()
					return runtime:on(1, listener)
				end,

				iter = function (): () -> (number, number)
					return runtime:iter(1)
				end,
			}) :: ClientListener<(number)>,
		}),
	}),

	version = "0.1.0",

	hooks = table.freeze({
		beforeSend = runtime.beforeSend,
		afterReceive = runtime.afterReceive,
	}),

	rate = runtime.rate,

	flush = function ()
		runtime:flush()
	end,

	onFailure = function (handler: Volt.Failure): Volt.Failure
		return runtime:onFailure(handler)
	end,

	stats = function (player: (Player | Bot)?): Volt.Stats
		return runtime:stats(player)
	end,
}

Network.events = table.freeze({
	["Outer.Inner.announce"] = Network.Outer.Inner.announce,
}) :: { [string]: any }

Network.functions = table.freeze({}) :: { [string]: any }
Network.exports = table.freeze({}) :: { [string]: any }

return table.freeze(Network)
