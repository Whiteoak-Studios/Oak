--[[
    The server module Volt 0.1.0 generated from Stale.volt: a writer per
    message this side sends, a reader per message it hears, the schema
    table the runtime starts from and the API a game calls. Generated code:
    change the schema and run volt again rather than editing this file
--]]

--!strict
--!native
--!optimize 2
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Volt = require(ReplicatedStorage.Packages.Volt)
local Promise: any = require(ReplicatedStorage.Packages.Promise)

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

type ServerInvoke<A..., R...> = {
	invoke: (player: Player | Bot, A...) -> (boolean, R...),
}

type ServerPromise<A...> = { invoke: (player: Player | Bot, A...) -> any }

type Exported<T> = {
	write: (value: T) -> (buffer, { any }?),
	read: (packet: buffer, side: { any }?) -> T,
}

local runtime: Volt.Runtime
local beginReliable: (number) -> (number, buffer)
local trimReliable: (number) -> ()
local refuseReliable: (string) -> never

local function readGreeter_greet(player: (Player | Bot)?, packet: buffer, cursor: number, _: { any }, sideCursor: number, length: number): (number, number)
	if cursor + 3 > length then
		error("Greeter.greet: truncated")
	end

	local slot: number = buffer.readu16(packet, cursor)
	local nameLength: number = 1 + buffer.readu8(packet, cursor + 2)

	if nameLength > 64 then
		error("Greeter.greet.name: length out of range")
	end

	cursor += 3

	if cursor + nameLength > length then
		error("Greeter.greet.name: truncated")
	end

	local name: string = buffer.readstring(packet, cursor, nameLength)
	cursor += nameLength

	return runtime:call(1, player, slot, cursor, sideCursor, name)
end

local function writeGreeter_greet(slot: number, status: number, ok: boolean, reply: string?)
	local offset: number, out: buffer = beginReliable(70)
	buffer.writeu8(out, offset, 1)
	buffer.writeu16(out, offset + 1, slot)
	buffer.writeu8(out, offset + 3, status)
	offset += 4

	if status == 0 then
		local flags: number = 0

		if type(ok) ~= "boolean" then
			refuseReliable("Greeter.greet.ok: expected boolean")
		end

		flags += ok and 1 or 0
		flags += reply ~= nil and 2 or 0
		buffer.writeu8(out, offset, flags)
		offset += 1

		if reply ~= nil then
			if type(reply) ~= "string" then
				refuseReliable("Greeter.greet.reply: expected string")
			end

			if #reply > 64 then
				refuseReliable("Greeter.greet.reply: length out of range")
			end

			buffer.writeu8(out, offset, #reply)
			offset += 1
			buffer.writestring(out, offset, reply)
			offset += #reply
		end
	end

	trimReliable(offset)
end

local function readGreeter_cheer(player: (Player | Bot)?, packet: buffer, cursor: number, _: { any }, sideCursor: number, length: number): (number, number)
	if cursor + 1 > length then
		error("Greeter.cheer: truncated")
	end

	local value: number = buffer.readu8(packet, cursor)
	cursor += 1

	return runtime:deliver(2, player, cursor, sideCursor, value)
end

local function writeGreeter_greeted(name: string, count: number)
	local offset: number, out: buffer = beginReliable(38)
	buffer.writeu8(out, offset, 2)

	if type(name) ~= "string" then
		refuseReliable("Greeter.greeted.name: expected string")
	end

	if #name < 1 or #name > 32 then
		refuseReliable("Greeter.greeted.name: length out of range")
	end

	buffer.writeu8(out, offset + 1, #name - 1)

	if type(count) ~= "number" or bit32.band(count, 4294967295) ~= count then
		refuseReliable("Greeter.greeted.count: expected u32")
	end

	buffer.writeu32(out, offset + 2, count)
	offset += 6
	buffer.writestring(out, offset, name)
	offset += #name
	trimReliable(offset)
end

local function writeScore_points(value: number)
	local offset: number, out: buffer = beginReliable(5)
	buffer.writeu8(out, offset, 3)

	if type(value) ~= "number" or bit32.band(value, 4294967295) ~= value then
		refuseReliable("Score.points: expected u32")
	end

	buffer.writeu32(out, offset + 1, value)
end

local function writeScore_check(slot: number, value: number)
	local offset: number, out: buffer = beginReliable(7)
	buffer.writeu8(out, offset, 4)
	buffer.writeu16(out, offset + 1, slot)

	if type(value) ~= "number" or bit32.band(value, 4294967295) ~= value then
		refuseReliable("Score.check: expected u32")
	end

	buffer.writeu32(out, offset + 3, value)
end

local function readScore_check(player: (Player | Bot)?, packet: buffer, cursor: number, _: { any }, sideCursor: number, length: number): (number, number)
	if cursor + 3 > length then
		error("Score.check: truncated")
	end

	local slot: number = buffer.readu16(packet, cursor)
	local status: number = buffer.readu8(packet, cursor + 2)
	cursor += 3

	if status == 0 then
		if cursor + 1 > length then
			error("Score.check: truncated")
		end

		local flags: number = buffer.readu8(packet, cursor)
		cursor += 1

		return runtime:reply(3, player, slot, cursor, sideCursor, bit32.btest(flags, 1))
	end

	return runtime:refused(3, player, slot, status, packet, cursor, sideCursor, length)
end

runtime = Volt.start({
	version = "0.1.0",
	hash = 0xC255DBC8,
	scope = "Dev",
	side = "server",
	idBytes = 1,
	promise = Promise,
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
		[1] = { name = "Greeter.greet", kind = "call", rate = 60, read = readGreeter_greet, reply = writeGreeter_greet },
		[2] = { name = "Greeter.cheer", kind = "event", mode = "SingleAsync", queue = 64, rate = 120, read = readGreeter_cheer },
		[3] = { name = "Score.check", kind = "reply", timeout = 10, promise = Promise, read = readScore_check },
	},

	outgoing = {
		[1] = { name = "Greeter.greet", kind = "reply", reliable = true, minBytes = 5, maxBytes = 262 },
		[2] = { name = "Greeter.greeted", kind = "event", reliable = true, minBytes = 7, maxBytes = 38 },
		[3] = { name = "Score.points", kind = "event", reliable = true, minBytes = 5, maxBytes = 5 },
		[4] = { name = "Score.check", kind = "call", reliable = true, minBytes = 7, maxBytes = 7 },
	},
})

beginReliable = runtime.reliable.begin
trimReliable = runtime.reliable.trim
refuseReliable = runtime.reliable.refuse

local before: { [number]: Volt.Hook } = runtime.before

local Network = {
	Greeter = table.freeze({
		greet = table.freeze({
			on = function (handler: (player: Player | Bot, name: string) -> (boolean, string?)): () -> ()
				return runtime:handle(1, handler)
			end,
		}) :: ServerFunction<(string), (boolean, string?)>,

		cheer = table.freeze({
			on = function (listener: (player: Player | Bot, value: number) -> ()): () -> ()
				return runtime:on(2, listener)
			end,

			iter = function (): () -> (number, Player | Bot, number)
				return runtime:iter(2)
			end,
		}) :: ServerListener<(number)>,

		greeted = table.freeze({
			fire = function (player: Player | Bot, name: string, count: number)
				if (before[2] == nil or before[2](player, name, count)) and runtime:target(player) then
					writeGreeter_greeted(name, count)
				end
			end,

			fireAll = function (name: string, count: number)
				runtime:broadcast(2, nil, nil, writeGreeter_greeted, name, count)
			end,

			fireList = function (players: { Player | Bot }, name: string, count: number)
				runtime:broadcast(2, players, nil, writeGreeter_greeted, name, count)
			end,

			fireExcept = function (player: Player | Bot, name: string, count: number)
				runtime:broadcast(2, nil, player, writeGreeter_greeted, name, count)
			end,

			fireSet = function (players: { [Player | Bot]: true }, name: string, count: number)
				runtime:broadcast(2, players, nil, writeGreeter_greeted, name, count)
			end,
		}) :: ServerEvent<(string, number)>,
	}),

	Score = table.freeze({
		points = table.freeze({
			fire = function (player: Player | Bot, value: number)
				if (before[3] == nil or before[3](player, value)) and runtime:target(player) then
					writeScore_points(value)
				end
			end,

			fireAll = function (value: number)
				runtime:broadcast(3, nil, nil, writeScore_points, value)
			end,

			fireList = function (players: { Player | Bot }, value: number)
				runtime:broadcast(3, players, nil, writeScore_points, value)
			end,

			fireExcept = function (player: Player | Bot, value: number)
				runtime:broadcast(3, nil, player, writeScore_points, value)
			end,

			fireSet = function (players: { [Player | Bot]: true }, value: number)
				runtime:broadcast(3, players, nil, writeScore_points, value)
			end,
		}) :: ServerEvent<(number)>,

		check = table.freeze({
			invoke = function (player: Player | Bot, value: number)
				return runtime:invoke(3, writeScore_check, player, value)
			end,
		}) :: ServerPromise<(number)>,
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
	["Greeter.cheer"] = Network.Greeter.cheer,
	["Greeter.greeted"] = Network.Greeter.greeted,
	["Score.points"] = Network.Score.points,
}) :: { [string]: any }

Network.functions = table.freeze({
	["Greeter.greet"] = Network.Greeter.greet,
	["Score.check"] = Network.Score.check,
}) :: { [string]: any }

Network.exports = table.freeze({}) :: { [string]: any }

return table.freeze(Network)
