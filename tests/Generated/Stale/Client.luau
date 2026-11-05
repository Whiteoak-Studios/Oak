--[[
    The client module Volt 0.1.0 generated from Stale.volt: a writer per
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

export type Shop_Slot = { item: string, quantity: number }
export type Shop_Shelf = { label: string, slots: { [number]: Shop_Slot } }
export type Catalog_Item = { name: string, price: number }

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

local function writeCatalog_Item(allocate: (number) -> (number, buffer), _: (any) -> (), refuse: (string) -> never, value: any)
	local offset: number, out: buffer = allocate(5)

	if type(value) ~= "table" then
		refuse("Catalog.Item: expected table")
	end

	local name = value.name

	if type(name) ~= "string" then
		refuse("Catalog.Item.name: expected string")
	end

	if #name < 1 or #name > 32 then
		refuse("Catalog.Item.name: length out of range")
	end

	buffer.writeu8(out, offset, #name - 1)
	local price = value.price

	if type(price) ~= "number" or bit32.band(price, 4294967295) ~= price then
		refuse("Catalog.Item.price: expected u32")
	end

	buffer.writeu32(out, offset + 1, price)
	local nameOffset: number, nameOut: buffer = allocate(#name)
	buffer.writestring(nameOut, nameOffset, name)
end

local function readCatalog_Item(packet: buffer, cursor: number, _: { any }, sideCursor: number, length: number): (number, number, Catalog_Item)
	if cursor + 5 > length then
		error("Catalog.Item: truncated")
	end

	local nameLength: number = 1 + buffer.readu8(packet, cursor)

	if nameLength > 32 then
		error("Catalog.Item.name: length out of range")
	end

	local price: number = buffer.readu32(packet, cursor + 1)
	cursor += 5

	if cursor + nameLength > length then
		error("Catalog.Item.name: truncated")
	end

	local name: string = buffer.readstring(packet, cursor, nameLength)
	cursor += nameLength
	local value = { name = name, price = price }

	return cursor, sideCursor, value
end

local function writeShop_buy(slot: number, value: number)
	local offset: number, out: buffer = beginReliable(4)
	buffer.writeu8(out, offset, 1)
	buffer.writeu16(out, offset + 1, slot)

	if type(value) ~= "number" or bit32.band(value, 255) ~= value then
		refuseReliable("Shop.buy: expected u8")
	end

	buffer.writeu8(out, offset + 3, value)
end

local function readShop_buy(player: (Player | Bot)?, packet: buffer, cursor: number, _: { any }, sideCursor: number, length: number): (number, number)
	if cursor + 3 > length then
		error("Shop.buy: truncated")
	end

	local slot: number = buffer.readu16(packet, cursor)
	local status: number = buffer.readu8(packet, cursor + 2)
	cursor += 3

	if status == 0 then
		if cursor + 1 > length then
			error("Shop.buy: truncated")
		end

		local flags: number = buffer.readu8(packet, cursor)
		local reason: string?
		cursor += 1

		if bit32.btest(flags, 2) then
			if cursor + 1 > length then
				error("Shop.buy.reason: truncated")
			end

			local reasonLength: number = buffer.readu8(packet, cursor)

			if reasonLength > 64 then
				error("Shop.buy.reason: length out of range")
			end

			cursor += 1

			if cursor + reasonLength > length then
				error("Shop.buy.reason: truncated")
			end

			local reason_2: string = buffer.readstring(packet, cursor, reasonLength)
			cursor += reasonLength
			reason = reason_2
		end

		return runtime:reply(1, player, slot, cursor, sideCursor, bit32.btest(flags, 1), reason)
	end

	return runtime:refused(1, player, slot, status, packet, cursor, sideCursor, length)
end

local function writeShop_report(value: string)
	local offset: number, out: buffer = beginReliable(66)
	buffer.writeu8(out, offset, 2)

	if type(value) ~= "string" then
		refuseReliable("Shop.report: expected string")
	end

	if #value > 64 then
		refuseReliable("Shop.report: length out of range")
	end

	buffer.writeu8(out, offset + 1, #value)
	offset += 2
	buffer.writestring(out, offset, value)
	offset += #value
	trimReliable(offset)
end

local function writeShop_chat(value: string)
	local offset: number, out: buffer = beginReliable(66)
	buffer.writeu8(out, offset, 3)

	if type(value) ~= "string" then
		refuseReliable("Shop.chat: expected string")
	end

	if #value > 64 then
		refuseReliable("Shop.chat: length out of range")
	end

	buffer.writeu8(out, offset + 1, #value)
	offset += 2
	buffer.writestring(out, offset, value)
	offset += #value
	trimReliable(offset)
end

local function readShop_chat(player: (Player | Bot)?, packet: buffer, cursor: number, _: { any }, sideCursor: number, length: number): (number, number)
	if cursor + 1 > length then
		error("Shop.chat: truncated")
	end

	local valueLength: number = buffer.readu8(packet, cursor)

	if valueLength > 64 then
		error("Shop.chat: length out of range")
	end

	cursor += 1

	if cursor + valueLength > length then
		error("Shop.chat: truncated")
	end

	local value: string = buffer.readstring(packet, cursor, valueLength)
	cursor += valueLength

	return runtime:deliver(2, player, cursor, sideCursor, value)
end

local function writeShop_browse(value: number)
	local offset: number, out: buffer = beginReliable(2)
	buffer.writeu8(out, offset, 4)

	if type(value) ~= "number" or bit32.band(value, 255) ~= value then
		refuseReliable("Shop.browse: expected u8")
	end

	buffer.writeu8(out, offset + 1, value)
end

local function readShop_coins(player: (Player | Bot)?, packet: buffer, cursor: number, _: { any }, sideCursor: number, length: number): (number, number)
	if cursor + 4 > length then
		error("Shop.coins: truncated")
	end

	local value: number = buffer.readu32(packet, cursor)
	cursor += 4

	return runtime:deliver(3, player, cursor, sideCursor, value)
end

local function readShop_stock(player: (Player | Bot)?, packet: buffer, cursor: number, _: { any }, sideCursor: number, length: number): (number, number)
	if cursor + 6 > length then
		error("Shop.stock: truncated")
	end

	local version: number = buffer.readu32(packet, cursor)
	local labelLength: number = buffer.readu8(packet, cursor + 4)

	if labelLength > 32 then
		error("Shop.stock.shelf.label: length out of range")
	end

	local slotsLength: number = buffer.readu8(packet, cursor + 5)

	if slotsLength > 16 then
		error("Shop.stock.shelf.slots: length out of range")
	end

	cursor += 6

	if cursor + labelLength > length then
		error("Shop.stock.shelf.label: truncated")
	end

	local label: string = buffer.readstring(packet, cursor, labelLength)
	cursor += labelLength

	if cursor + 7 * slotsLength > length then
		error("Shop.stock.shelf.slots: truncated")
	end

	local slots: { [number]: Shop_Slot } = {}

	for _ = 1, slotsLength do
		if cursor + 6 > length then
			error("Shop.stock.shelf.slots: truncated")
		end

		local slotsKey: number = buffer.readu8(packet, cursor)
		local itemLength: number = 1 + buffer.readu8(packet, cursor + 1)

		if itemLength > 32 then
			error("Shop.stock.shelf.slots[value].item: length out of range")
		end

		local quantity: number = buffer.readu32(packet, cursor + 2)
		cursor += 6

		if cursor + itemLength > length then
			error("Shop.stock.shelf.slots[value].item: truncated")
		end

		local item: string = buffer.readstring(packet, cursor, itemLength)
		cursor += itemLength
		local slotsValue = { item = item, quantity = quantity }

		if slots[slotsKey] ~= nil then
			error("Shop.stock.shelf.slots: duplicate key")
		end

		slots[slotsKey] = slotsValue
	end

	local shelf = { label = label, slots = slots }
	local value = { version = version, shelf = shelf }

	return runtime:deliver(4, player, cursor, sideCursor, value)
end

local function readShop_confirm(player: (Player | Bot)?, packet: buffer, cursor: number, _: { any }, sideCursor: number, length: number): (number, number)
	if cursor + 3 > length then
		error("Shop.confirm: truncated")
	end

	local slot: number = buffer.readu16(packet, cursor)
	local valueLength: number = buffer.readu8(packet, cursor + 2)

	if valueLength > 64 then
		error("Shop.confirm: length out of range")
	end

	cursor += 3

	if cursor + valueLength > length then
		error("Shop.confirm: truncated")
	end

	local value: string = buffer.readstring(packet, cursor, valueLength)
	cursor += valueLength

	return runtime:call(5, player, slot, cursor, sideCursor, value)
end

local function writeShop_confirm(slot: number, status: number, value: boolean)
	local offset: number, out: buffer = beginReliable(4)
	buffer.writeu8(out, offset, 5)
	buffer.writeu16(out, offset + 1, slot)
	buffer.writeu8(out, offset + 3, status)

	if status == 0 then
		local offset_2: number, out_2: buffer = allocateReliable(1)
		local flags: number = 0

		if type(value) ~= "boolean" then
			refuseReliable("Shop.confirm: expected boolean")
		end

		flags += value and 1 or 0
		buffer.writeu8(out_2, offset_2, flags)
	end
end

runtime = Volt.start({
	version = "0.1.0",
	hash = 0x0EE67A62,
	scope = "Oak",
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
		[1] = { name = "Shop.buy", kind = "reply", timeout = 10, promise = Promise, read = readShop_buy },
		[2] = { name = "Shop.chat", kind = "event", mode = "ManySync", queue = 64, read = readShop_chat },
		[3] = { name = "Shop.coins", kind = "event", mode = "SingleAsync", queue = 64, read = readShop_coins },
		[4] = { name = "Shop.stock", kind = "event", mode = "SingleAsync", queue = 64, read = readShop_stock },
		[5] = { name = "Shop.confirm", kind = "call", read = readShop_confirm, reply = writeShop_confirm },
	},

	outgoing = {
		[1] = { name = "Shop.buy", kind = "call", reliable = true, minBytes = 4, maxBytes = 4 },
		[2] = { name = "Shop.report", kind = "event", reliable = true, minBytes = 2, maxBytes = 66 },
		[3] = { name = "Shop.chat", kind = "event", reliable = true, minBytes = 2, maxBytes = 66 },
		[4] = { name = "Shop.browse", kind = "event", reliable = true, minBytes = 2, maxBytes = 2 },
		[5] = { name = "Shop.confirm", kind = "reply", reliable = true, minBytes = 5, maxBytes = 262 },
	},
})

beginReliable = runtime.reliable.begin
trimReliable = runtime.reliable.trim
allocateReliable = runtime.reliable.allocate
refuseReliable = runtime.reliable.refuse

local before: { [number]: Volt.Hook } = runtime.before

local Network = {
	Shop = table.freeze({
		buy = table.freeze({
			invoke = function (value: number)
				return runtime:invoke(1, writeShop_buy, value)
			end,
		}) :: ClientPromise<(number)>,

		report = table.freeze({
			fire = function (value: string)
				if before[2] == nil or before[2](nil, value) then
					writeShop_report(value)
				end
			end,
		}) :: ClientEvent<(string)>,

		chat = table.freeze({
			fire = function (value: string)
				if before[3] == nil or before[3](nil, value) then
					writeShop_chat(value)
				end
			end,

			on = function (listener: (value: string) -> ()): () -> ()
				return runtime:on(2, listener)
			end,

			iter = function (): () -> (number, string)
				return runtime:iter(2)
			end,
		}) :: ClientEvent<(string)> & ClientListener<(string)>,

		browse = table.freeze({
			fire = function (value: number)
				if before[4] == nil or before[4](nil, value) then
					writeShop_browse(value)
				end
			end,
		}) :: ClientEvent<(number)>,

		coins = table.freeze({
			on = function (listener: (value: number) -> ()): () -> ()
				return runtime:on(3, listener)
			end,

			iter = function (): () -> (number, number)
				return runtime:iter(3)
			end,
		}) :: ClientListener<(number)>,

		stock = table.freeze({
			on = function (listener: (value: { version: number, shelf: Shop_Shelf }) -> ()): () -> ()
				return runtime:on(4, listener)
			end,

			iter = function (): () -> (number, { version: number, shelf: Shop_Shelf })
				return runtime:iter(4)
			end,
		}) :: ClientListener<({ version: number, shelf: Shop_Shelf })>,

		confirm = table.freeze({
			on = function (handler: (value: string) -> (boolean)): () -> ()
				return runtime:handle(5, handler)
			end,

			connected = function (): boolean
				return runtime:handled(5)
			end,
		}) :: ClientHandler<(string), (boolean)>,
	}),

	Catalog = table.freeze({
		Item = table.freeze({
			write = function (value: Catalog_Item): (buffer, { any }?)
				return runtime:encode("Catalog.Item", writeCatalog_Item, value)
			end,

			read = function (packet: buffer, side: { any }?): Catalog_Item
				return runtime:decode(readCatalog_Item, packet, side)
			end,
		}) :: Exported<Catalog_Item>,
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
	["Shop.report"] = Network.Shop.report,
	["Shop.chat"] = Network.Shop.chat,
	["Shop.browse"] = Network.Shop.browse,
	["Shop.coins"] = Network.Shop.coins,
	["Shop.stock"] = Network.Shop.stock,
}) :: { [string]: any }

Network.functions = table.freeze({
	["Shop.buy"] = Network.Shop.buy,
	["Shop.confirm"] = Network.Shop.confirm,
}) :: { [string]: any }

Network.exports = table.freeze({
	["Catalog.Item"] = Network.Catalog.Item,
}) :: { [string]: any }

return table.freeze(Network)
