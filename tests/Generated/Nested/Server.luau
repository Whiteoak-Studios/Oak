--[[
    The server module Volt 0.1.0 generated from Nested.volt: a writer per
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

type ServerEvent<A...> = {
	fire: (player: Player | Bot, A...) -> (),
	fireAll: (A...) -> (),
	fireList: (players: { Player | Bot }, A...) -> (),
	fireExcept: (player: Player | Bot, A...) -> (),
	fireSet: (players: { [Player | Bot]: true }, A...) -> (),
}

type ServerListener<A...> = {
	on: (listener: (player: Player | Bot, A...) -> ()) -> () -> (),
	iter: () -> () -> (number, Player | Bot, A...),
}

type ServerPolling<A...> = { iter: () -> () -> (number, Player | Bot, A...) }

type ServerFunction<A..., R...> = {
	on: (handler: (player: Player | Bot, A...) -> R...) -> () -> (),
}

type Exported<T> = {
	write: (value: T) -> (buffer, { any }?),
	read: (packet: buffer, side: { any }?) -> T,
}

local runtime: Volt.Runtime
local beginReliable: (number) -> (number, buffer)
local refuseReliable: (string) -> never

local function writeOuter_Inner_announce(value: number)
	local offset: number, out: buffer = beginReliable(2)
	buffer.writeu8(out, offset, 1)

	if type(value) ~= "number" or bit32.band(value, 255) ~= value then
		refuseReliable("Outer.Inner.announce: expected u8")
	end

	buffer.writeu8(out, offset + 1, value)
end

runtime = Volt.start({
	version = "0.1.0",
	hash = 0xE60CDDF4,
	scope = "Oak",
	side = "server",
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

	messages = {},

	outgoing = {
		[1] = { name = "Outer.Inner.announce", kind = "event", reliable = true, minBytes = 2, maxBytes = 2 },
	},
})

beginReliable = runtime.reliable.begin
refuseReliable = runtime.reliable.refuse

local before: { [number]: Volt.Hook } = runtime.before

local Network = {
	Outer = table.freeze({
		Inner = table.freeze({
			announce = table.freeze({
				fire = function (player: Player | Bot, value: number)
					if (before[1] == nil or before[1](player, value)) and runtime:target(player) then
						writeOuter_Inner_announce(value)
					end
				end,

				fireAll = function (value: number)
					runtime:broadcast(1, nil, nil, writeOuter_Inner_announce, value)
				end,

				fireList = function (players: { Player | Bot }, value: number)
					runtime:broadcast(1, players, nil, writeOuter_Inner_announce, value)
				end,

				fireExcept = function (player: Player | Bot, value: number)
					runtime:broadcast(1, nil, player, writeOuter_Inner_announce, value)
				end,

				fireSet = function (players: { [Player | Bot]: true }, value: number)
					runtime:broadcast(1, players, nil, writeOuter_Inner_announce, value)
				end,
			}) :: ServerEvent<(number)>,
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

	onJoin = function (callback: (player: Player | Bot) -> ()): () -> ()
		return runtime:onJoin(callback)
	end,

	onLeave = function (callback: (player: Player | Bot) -> ()): () -> ()
		return runtime:onLeave(callback)
	end,

	onHandshake = function (callback: (player: Player | Bot) -> ()): () -> ()
		return runtime:onHandshake(callback)
	end,

	traffic = function (player: Player | Bot): (number, number)
		return runtime:traffic(player)
	end,

	budget = function (bytesPerSecond: number?)
		runtime:budget(bytesPerSecond)
	end,

	isBot = runtime.isBot,
}

Network.events = table.freeze({
	["Outer.Inner.announce"] = Network.Outer.Inner.announce,
}) :: { [string]: any }

Network.functions = table.freeze({}) :: { [string]: any }
Network.exports = table.freeze({}) :: { [string]: any }

return table.freeze(Network)
