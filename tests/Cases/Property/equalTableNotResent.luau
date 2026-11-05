--[[
    A fresh table equal field by field at every depth to what a player was
    last sent is not sent again, by SetTop or SetFor, while one with a map
    key more or a key fewer is
--]]

--!strict
local Environment = require("../../Environment")

local VERSION: number = 1 -- The stock's version
local LABEL: string = "Front" -- The shelf's label
local ITEM: string = "Apple" -- What the shelf's first slot holds
local QUANTITY: number = 4 -- How many of it
local EXTRA: number = 2 -- A second slot's key, added and then taken away

type Stock = { version: number, shelf: { label: string, slots: { [number]: { item: string, quantity: number } } } }

-- A new table each call, equal to every other it makes
local function stock(): Stock
	return { version = VERSION, shelf = { label = LABEL, slots = { [1] = { item = ITEM, quantity = QUANTITY } } } }
end

return function (): (boolean, string | nil)
	local server = Environment.new()
	local network: any = server:network("Oak")
	local Property: any = server:load("Property")

	Property.prepare(network)
	local shelf: any = Property.new(network.Shop.stock, stock())
	Property.bind(network)

	local alice, transport = server.mock:join("Alice")
	local heard: { Stock } = {}

	server:client(transport):network("Oak").Shop.stock.on(function (value: Stock)
		table.insert(heard, value)
	end)

	server:step(Environment.HELD)

	local replayed: number = #heard

	shelf:SetTop(stock())
	shelf:SetFor(alice, stock())
	shelf:SetTop(stock())
	server:step(Environment.DELIVERY)

	if #heard ~= replayed then
		return false, `An equal table was sent {#heard - replayed} times`
	end

	-- A key only the new table holds, then one only the old table held, each a change
	local changes: number = 2
	local wider: Stock = stock()
	wider.shelf.slots[EXTRA] = { item = ITEM, quantity = QUANTITY }

	shelf:SetFor(alice, wider)
	shelf:SetFor(alice, stock())
	server:step(Environment.DELIVERY)

	local last: Stock? = heard[#heard]

	if #heard ~= replayed + changes or not last or last.shelf.slots[EXTRA] ~= nil then
		return false, `A key added and taken away sent {#heard - replayed} tables rather than {changes}`
	end

	return true, nil
end
