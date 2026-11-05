--[[
    A table the service changes in place and sets again is sent, at depth
    two and deeper, through SetTop and through SetFor, since Oak compares
    against a copy of its own; set once more unchanged, it is not
--]]

--!strict
local Environment = require("../../Environment")

local VERSION: number = 1 -- The stock's version, raised by one in place for Alice's override
local LABEL: string = "Front" -- The shelf's label
local RENAMED: string = "Back" -- The label written in place, at depth two
local ITEM: string = "Apple" -- What the shelf's first slot holds
local QUANTITY: number = 4 -- How many of it, raised by one in place, at depth four

type Stock = { version: number, shelf: { label: string, slots: { [number]: { item: string, quantity: number } } } }

return function (): (boolean, string | nil)
	local server = Environment.new()
	local network: any = server:network("Oak")
	local Property: any = server:load("Property")

	local stock: Stock =
		{ version = VERSION, shelf = { label = LABEL, slots = { [1] = { item = ITEM, quantity = QUANTITY } } } }

	Property.prepare(network)
	local shelf: any = Property.new(network.Shop.stock, stock)
	Property.bind(network)

	local alice, transport = server.mock:join("Alice")
	local heard: { Stock } = {}

	server:client(transport):network("Oak").Shop.stock.on(function (value: Stock)
		table.insert(heard, value)
	end)

	server:step(Environment.HELD)

	local sent: number = #heard

	stock.shelf.label = RENAMED
	shelf:SetTop(stock)
	shelf:SetTop(stock)
	server:step(Environment.DELIVERY)

	if #heard ~= sent + 1 or heard[#heard].shelf.label ~= RENAMED then
		return false,
			`A label changed in place sent {#heard - sent} tables, the last labelled {heard[#heard].shelf.label}`
	end

	sent = #heard
	stock.shelf.slots[1].quantity += 1
	shelf:SetTop(stock)
	server:step(Environment.DELIVERY)

	if #heard ~= sent + 1 or heard[#heard].shelf.slots[1].quantity ~= QUANTITY + 1 then
		return false, `A quantity changed in place sent {#heard - sent} tables`
	end

	-- Alice's own copy is deep too, so her override changed in place goes out
	sent = #heard
	shelf:SetFor(alice, stock)
	stock.version += 1
	shelf:SetFor(alice, stock)
	shelf:SetFor(alice, stock)
	server:step(Environment.DELIVERY)

	if #heard ~= sent + 1 or heard[#heard].version ~= stock.version then
		return false, `An override changed in place sent {#heard - sent} tables`
	end

	return true, nil
end
