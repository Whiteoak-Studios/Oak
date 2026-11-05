--[[
    The client module Volt 0.1.0 generated from Dev.volt: a writer per
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

type ClientEvent<A...> = { fire: (A...) -> () }

type ClientListener<A...> = {
	on: (listener: (A...) -> ()) -> () -> (),
	iter: () -> () -> (number, A...),
}

type ClientPolling<A...> = { iter: () -> () -> (number, A...) }

type ClientFunction<A..., R...> = { invoke: (A...) -> (boolean, R...) }

type ClientPromise<A...> = { invoke: (A...) -> any }

type ClientHandler<A..., R...> = {
	on: (handler: (A...) -> R...) -> () -> (),
	connected: () -> boolean,
}

type Exported<T> = {
	write: (value: T) -> (buffer, { any }?),
	read: (packet: buffer, side: { any }?) -> T,
}

local runtime: Volt.Runtime
local beginReliable: (number) -> (number, buffer)
local trimReliable: (number) -> ()
local allocateReliable: (number) -> (number, buffer)
local refuseReliable: (string) -> never

local function writeGreeter_greet(slot: number, name: string)
	local offset: number, out: buffer = beginReliable(36)
	buffer.writeu8(out, offset, 1)
	buffer.writeu16(out, offset + 1, slot)

	if type(name) ~= "string" then
		refuseReliable("Greeter.greet.name: expected string")
	end

	if #name < 1 or #name > 32 then
		refuseReliable("Greeter.greet.name: length out of range")
	end

	buffer.writeu8(out, offset + 3, #name - 1)
	offset += 4
	buffer.writestring(out, offset, name)
	offset += #name
	trimReliable(offset)
end

local function readGreeter_greet(player: (Player | Bot)?, packet: buffer, cursor: number, _: { any }, sideCursor: number, length: number): (number, number)
	if cursor + 3 > length then
		error("Greeter.greet: truncated")
	end

	local slot: number = buffer.readu16(packet, cursor)
	local status: number = buffer.readu8(packet, cursor + 2)
	cursor += 3

	if status == 0 then
		if cursor + 1 > length then
			error("Greeter.greet: truncated")
		end

		local flags: number = buffer.readu8(packet, cursor)
		local reply: string?
		cursor += 1

		if bit32.btest(flags, 2) then
			if cursor + 1 > length then
				error("Greeter.greet.reply: truncated")
			end

			local replyLength: number = buffer.readu8(packet, cursor)

			if replyLength > 64 then
				error("Greeter.greet.reply: length out of range")
			end

			cursor += 1

			if cursor + replyLength > length then
				error("Greeter.greet.reply: truncated")
			end

			local reply_2: string = buffer.readstring(packet, cursor, replyLength)
			cursor += replyLength
			reply = reply_2
		end

		return runtime:reply(1, player, slot, cursor, sideCursor, bit32.btest(flags, 1), reply)
	end

	return runtime:refused(1, player, slot, status, packet, cursor, sideCursor, length)
end

local function writeGreeter_cheer(value: number)
	local offset: number, out: buffer = beginReliable(2)
	buffer.writeu8(out, offset, 2)

	if type(value) ~= "number" or bit32.band(value, 255) ~= value then
		refuseReliable("Greeter.cheer: expected u8")
	end

	buffer.writeu8(out, offset + 1, value)
end

local function readGreeter_greeted(player: (Player | Bot)?, packet: buffer, cursor: number, _: { any }, sideCursor: number, length: number): (number, number)
	if cursor + 5 > length then
		error("Greeter.greeted: truncated")
	end

	local nameLength: number = 1 + buffer.readu8(packet, cursor)

	if nameLength > 32 then
		error("Greeter.greeted.name: length out of range")
	end

	local count: number = buffer.readu32(packet, cursor + 1)
	cursor += 5

	if cursor + nameLength > length then
		error("Greeter.greeted.name: truncated")
	end

	local name: string = buffer.readstring(packet, cursor, nameLength)
	cursor += nameLength

	return runtime:deliver(2, player, cursor, sideCursor, name, count)
end

local function readScore_points(player: (Player | Bot)?, packet: buffer, cursor: number, _: { any }, sideCursor: number, length: number): (number, number)
	if cursor + 4 > length then
		error("Score.points: truncated")
	end

	local value: number = buffer.readu32(packet, cursor)
	cursor += 4

	return runtime:deliver(3, player, cursor, sideCursor, value)
end

local function readScore_check(player: (Player | Bot)?, packet: buffer, cursor: number, _: { any }, sideCursor: number, length: number): (number, number)
	if cursor + 6 > length then
		error("Score.check: truncated")
	end

	local slot: number = buffer.readu16(packet, cursor)
	local value: number = buffer.readu32(packet, cursor + 2)
	cursor += 6

	return runtime:call(4, player, slot, cursor, sideCursor, value)
end

local function writeScore_check(slot: number, status: number, value: boolean)
	local offset: number, out: buffer = beginReliable(4)
	buffer.writeu8(out, offset, 3)
	buffer.writeu16(out, offset + 1, slot)
	buffer.writeu8(out, offset + 3, status)

	if status == 0 then
		local offset_2: number, out_2: buffer = allocateReliable(1)
		local flags: number = 0

		if type(value) ~= "boolean" then
			refuseReliable("Score.check: expected boolean")
		end

		flags += value and 1 or 0
		buffer.writeu8(out_2, offset_2, flags)
	end
end

runtime = Volt.start({
	version = "0.1.0",
	hash = 0xC98873D4,
	scope = "Dev",
	side = "client",
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
		[1] = { name = "Greeter.greet", kind = "reply", timeout = 10, promise = Promise, read = readGreeter_greet },
		[2] = { name = "Greeter.greeted", kind = "event", mode = "SingleAsync", queue = 64, read = readGreeter_greeted },
		[3] = { name = "Score.points", kind = "event", mode = "SingleAsync", queue = 64, read = readScore_points },
		[4] = { name = "Score.check", kind = "call", read = readScore_check, reply = writeScore_check },
	},

	outgoing = {
		[1] = { name = "Greeter.greet", kind = "call", reliable = true, minBytes = 5, maxBytes = 36 },
		[2] = { name = "Greeter.cheer", kind = "event", reliable = true, minBytes = 2, maxBytes = 2 },
		[3] = { name = "Score.check", kind = "reply", reliable = true, minBytes = 5, maxBytes = 262 },
	},
})

beginReliable = runtime.reliable.begin
trimReliable = runtime.reliable.trim
allocateReliable = runtime.reliable.allocate
refuseReliable = runtime.reliable.refuse

local before: { [number]: Volt.Hook } = runtime.before

local Network = {
	Greeter = table.freeze({
		greet = table.freeze({
			invoke = function (name: string)
				return runtime:invoke(1, writeGreeter_greet, name)
			end,
		}) :: ClientPromise<(string)>,

		cheer = table.freeze({
			fire = function (value: number)
				if before[2] == nil or before[2](nil, value) then
					writeGreeter_cheer(value)
				end
			end,
		}) :: ClientEvent<(number)>,

		greeted = table.freeze({
			on = function (listener: (name: string, count: number) -> ()): () -> ()
				return runtime:on(2, listener)
			end,

			iter = function (): () -> (number, string, number)
				return runtime:iter(2)
			end,
		}) :: ClientListener<(string, number)>,
	}),

	Score = table.freeze({
		points = table.freeze({
			on = function (listener: (value: number) -> ()): () -> ()
				return runtime:on(3, listener)
			end,

			iter = function (): () -> (number, number)
				return runtime:iter(3)
			end,
		}) :: ClientListener<(number)>,

		check = table.freeze({
			on = function (handler: (value: number) -> (boolean)): () -> ()
				return runtime:handle(4, handler)
			end,

			connected = function (): boolean
				return runtime:handled(4)
			end,
		}) :: ClientHandler<(number), (boolean)>,
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
