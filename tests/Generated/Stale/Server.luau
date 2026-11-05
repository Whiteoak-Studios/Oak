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

export type Shop_Slot = { item: string, quantity: number }
export type Shop_Shelf = { label: string, slots: { [number]: Shop_Slot } }
export type Catalog_Item = { name: string, price: number }

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

local function readShop_buy(player: (Player | Bot)?, packet: buffer, cursor: number, _: { any }, sideCursor: number, length: number): (number, number)
	if cursor + 3 > length then
		error("Shop.buy: truncated")
	end

	local slot: number = buffer.readu16(packet, cursor)
	local value: number = buffer.readu8(packet, cursor + 2)
	cursor += 3

	return runtime:call(1, player, slot, cursor, sideCursor, value)
end

local function writeShop_buy(slot: number, status: number, ok: boolean, reason: string?)
	local offset: number, out: buffer = beginReliable(70)
	buffer.writeu8(out, offset, 1)
	buffer.writeu16(out, offset + 1, slot)
	buffer.writeu8(out, offset + 3, status)
	offset += 4

	if status == 0 then
		local flags: number = 0

		if type(ok) ~= "boolean" then
			refuseReliable("Shop.buy.ok: expected boolean")
		end

		flags += ok and 1 or 0
		flags += reason ~= nil and 2 or 0
		buffer.writeu8(out, offset, flags)
		offset += 1

		if reason ~= nil then
			if type(reason) ~= "string" then
				refuseReliable("Shop.buy.reason: expected string")
			end

			if #reason > 64 then
				refuseReliable("Shop.buy.reason: length out of range")
			end

			buffer.writeu8(out, offset, #reason)
			offset += 1
			buffer.writestring(out, offset, reason)
			offset += #reason
		end
	end

	trimReliable(offset)
end

local function readShop_report(player: (Player | Bot)?, packet: buffer, cursor: number, _: { any }, sideCursor: number, length: number): (number, number)
	if cursor + 1 > length then
		error("Shop.report: truncated")
	end

	local valueLength: number = buffer.readu8(packet, cursor)

	if valueLength > 64 then
		error("Shop.report: length out of range")
	end

	cursor += 1

	if cursor + valueLength > length then
		error("Shop.report: truncated")
	end

	local value: string = buffer.readstring(packet, cursor, valueLength)
	cursor += valueLength

	return runtime:deliver(2, player, cursor, sideCursor, value)
end

local function writeShop_chat(value: string)
	local offset: number, out: buffer = beginReliable(66)
	buffer.writeu8(out, offset, 2)

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

	return runtime:deliver(3, player, cursor, sideCursor, value)
end

local function readShop_browse(player: (Player | Bot)?, packet: buffer, cursor: number, _: { any }, sideCursor: number, length: number): (number, number)
	if cursor + 1 > length then
		error("Shop.browse: truncated")
	end

	local value: number = buffer.readu8(packet, cursor)
	cursor += 1

	return runtime:deliver(4, player, cursor, sideCursor, value)
end

local function writeShop_coins(value: number)
	local offset: number, out: buffer = beginReliable(5)
	buffer.writeu8(out, offset, 3)

	if type(value) ~= "number" or bit32.band(value, 4294967295) ~= value then
		refuseReliable("Shop.coins: expected u32")
	end

	buffer.writeu32(out, offset + 1, value)
end

local function writeShop_stock(value: { version: number, shelf: Shop_Shelf })
	local offset: number, out: buffer = beginReliable(647)
	buffer.writeu8(out, offset, 4)

	if type(value) ~= "table" then
		refuseReliable("Shop.stock: expected table")
	end

	local version = value.version

	if type(version) ~= "number" or bit32.band(version, 4294967295) ~= version then
		refuseReliable("Shop.stock.version: expected u32")
	end

	buffer.writeu32(out, offset + 1, version)
	local shelf = value.shelf

	if type(shelf) ~= "table" then
		refuseReliable("Shop.stock.shelf: expected table")
	end

	local label = shelf.label

	if type(label) ~= "string" then
		refuseReliable("Shop.stock.shelf.label: expected string")
	end

	if #label > 32 then
		refuseReliable("Shop.stock.shelf.label: length out of range")
	end

	buffer.writeu8(out, offset + 5, #label)
	local slots = shelf.slots

	if type(slots) ~= "table" then
		refuseReliable("Shop.stock.shelf.slots: expected table")
	end

	local slotsCount: number = 0

	for _ in slots do
		slotsCount += 1
	end

	if slotsCount > 16 then
		refuseReliable("Shop.stock.shelf.slots: length out of range")
	end

	buffer.writeu8(out, offset + 6, slotsCount)
	offset += 7
	buffer.writestring(out, offset, label)
	offset += #label

	for slotsKey, slotsValue in slots do
		if type(slotsKey) ~= "number" or bit32.band(slotsKey, 255) ~= slotsKey then
			refuseReliable("Shop.stock.shelf.slots[key]: expected u8")
		end

		buffer.writeu8(out, offset, slotsKey)

		if type(slotsValue) ~= "table" then
			refuseReliable("Shop.stock.shelf.slots[value]: expected table")
		end

		local item = slotsValue.item

		if type(item) ~= "string" then
			refuseReliable("Shop.stock.shelf.slots[value].item: expected string")
		end

		if #item < 1 or #item > 32 then
			refuseReliable("Shop.stock.shelf.slots[value].item: length out of range")
		end

		buffer.writeu8(out, offset + 1, #item - 1)
		local quantity = slotsValue.quantity

		if type(quantity) ~= "number" or bit32.band(quantity, 4294967295) ~= quantity then
			refuseReliable("Shop.stock.shelf.slots[value].quantity: expected u32")
		end

		buffer.writeu32(out, offset + 2, quantity)
		offset += 6
		buffer.writestring(out, offset, item)
		offset += #item
	end

	trimReliable(offset)
end

local function writeShop_confirm(slot: number, value: string)
	local offset: number, out: buffer = beginReliable(68)
	buffer.writeu8(out, offset, 5)
	buffer.writeu16(out, offset + 1, slot)

	if type(value) ~= "string" then
		refuseReliable("Shop.confirm: expected string")
	end

	if #value > 64 then
		refuseReliable("Shop.confirm: length out of range")
	end

	buffer.writeu8(out, offset + 3, #value)
	offset += 4
	buffer.writestring(out, offset, value)
	offset += #value
	trimReliable(offset)
end

local function readShop_confirm(player: (Player | Bot)?, packet: buffer, cursor: number, _: { any }, sideCursor: number, length: number): (number, number)
	if cursor + 3 > length then
		error("Shop.confirm: truncated")
	end

	local slot: number = buffer.readu16(packet, cursor)
	local status: number = buffer.readu8(packet, cursor + 2)
	cursor += 3

	if status == 0 then
		if cursor + 1 > length then
			error("Shop.confirm: truncated")
		end

		local flags: number = buffer.readu8(packet, cursor)
		cursor += 1

		return runtime:reply(5, player, slot, cursor, sideCursor, bit32.btest(flags, 1))
	end

	return runtime:refused(5, player, slot, status, packet, cursor, sideCursor, length)
end

runtime = Volt.start({
	version = "0.1.0",
	hash = 0x0EE67A62,
	scope = "Oak",
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
		[1] = { name = "Shop.buy", kind = "call", read = readShop_buy, reply = writeShop_buy },
		[2] = { name = "Shop.report", kind = "event", mode = "SingleSync", queue = 64, rate = 120, read = readShop_report },
		[3] = { name = "Shop.chat", kind = "event", mode = "ManySync", queue = 64, rate = 120, read = readShop_chat },
		[4] = { name = "Shop.browse", kind = "event", mode = "Polling", queue = 64, rate = 120, read = readShop_browse },
		[5] = { name = "Shop.confirm", kind = "reply", timeout = 10, promise = Promise, read = readShop_confirm },
	},

	outgoing = {
		[1] = { name = "Shop.buy", kind = "reply", reliable = true, minBytes = 5, maxBytes = 262 },
		[2] = { name = "Shop.chat", kind = "event", reliable = true, minBytes = 2, maxBytes = 66 },
		[3] = { name = "Shop.coins", kind = "event", reliable = true, minBytes = 5, maxBytes = 5 },
		[4] = { name = "Shop.stock", kind = "event", reliable = true, minBytes = 7, maxBytes = 647 },
		[5] = { name = "Shop.confirm", kind = "call", reliable = true, minBytes = 4, maxBytes = 68 },
	},
})

beginReliable = runtime.reliable.begin
trimReliable = runtime.reliable.trim
refuseReliable = runtime.reliable.refuse

local before: { [number]: Volt.Hook } = runtime.before

local Network = {
	Shop = table.freeze({
		buy = table.freeze({
			on = function (handler: (player: Player | Bot, value: number) -> (boolean, string?)): () -> ()
				return runtime:handle(1, handler)
			end,
		}) :: ServerFunction<(number), (boolean, string?)>,

		report = table.freeze({
			on = function (listener: (player: Player | Bot, value: string) -> ()): () -> ()
				return runtime:on(2, listener)
			end,

			iter = function (): () -> (number, Player | Bot, string)
				return runtime:iter(2)
			end,
		}) :: ServerListener<(string)>,

		chat = table.freeze({
			fire = function (player: Player | Bot, value: string)
				if (before[2] == nil or before[2](player, value)) and runtime:target(player) then
					writeShop_chat(value)
				end
			end,

			fireAll = function (value: string)
				runtime:broadcast(2, nil, nil, writeShop_chat, value)
			end,

			fireList = function (players: { Player | Bot }, value: string)
				runtime:broadcast(2, players, nil, writeShop_chat, value)
			end,

			fireExcept = function (player: Player | Bot, value: string)
				runtime:broadcast(2, nil, player, writeShop_chat, value)
			end,

			fireSet = function (players: { [Player | Bot]: true }, value: string)
				runtime:broadcast(2, players, nil, writeShop_chat, value)
			end,

			on = function (listener: (player: Player | Bot, value: string) -> ()): () -> ()
				return runtime:on(3, listener)
			end,

			iter = function (): () -> (number, Player | Bot, string)
				return runtime:iter(3)
			end,
		}) :: ServerEvent<(string)> & ServerListener<(string)>,

		browse = table.freeze({
			iter = function (): () -> (number, Player | Bot, number)
				return runtime:iter(4)
			end,
		}) :: ServerPolling<(number)>,

		coins = table.freeze({
			fire = function (player: Player | Bot, value: number)
				if (before[3] == nil or before[3](player, value)) and runtime:target(player) then
					writeShop_coins(value)
				end
			end,

			fireAll = function (value: number)
				runtime:broadcast(3, nil, nil, writeShop_coins, value)
			end,

			fireList = function (players: { Player | Bot }, value: number)
				runtime:broadcast(3, players, nil, writeShop_coins, value)
			end,

			fireExcept = function (player: Player | Bot, value: number)
				runtime:broadcast(3, nil, player, writeShop_coins, value)
			end,

			fireSet = function (players: { [Player | Bot]: true }, value: number)
				runtime:broadcast(3, players, nil, writeShop_coins, value)
			end,
		}) :: ServerEvent<(number)>,

		stock = table.freeze({
			fire = function (player: Player | Bot, value: { version: number, shelf: Shop_Shelf })
				if (before[4] == nil or before[4](player, value)) and runtime:target(player) then
					writeShop_stock(value)
				end
			end,

			fireAll = function (value: { version: number, shelf: Shop_Shelf })
				runtime:broadcast(4, nil, nil, writeShop_stock, value)
			end,

			fireList = function (players: { Player | Bot }, value: { version: number, shelf: Shop_Shelf })
				runtime:broadcast(4, players, nil, writeShop_stock, value)
			end,

			fireExcept = function (player: Player | Bot, value: { version: number, shelf: Shop_Shelf })
				runtime:broadcast(4, nil, player, writeShop_stock, value)
			end,

			fireSet = function (players: { [Player | Bot]: true }, value: { version: number, shelf: Shop_Shelf })
				runtime:broadcast(4, players, nil, writeShop_stock, value)
			end,
		}) :: ServerEvent<({ version: number, shelf: Shop_Shelf })>,

		confirm = table.freeze({
			invoke = function (player: Player | Bot, value: string)
				return runtime:invoke(5, writeShop_confirm, player, value)
			end,
		}) :: ServerPromise<(string)>,
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
