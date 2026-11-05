--[[
    A second server Property on an event that already has one errors where
    it is made, at the line that called Oak.Property, naming the event or,
    for a handle the Network does not hold, that line alone
--]]

--!strict
local Environment = require("../../Environment")

local START: number = 250 -- The first coins Property's default
local OTHER: number = 0 -- The second one's, which must never be sent
local CASE: string = "secondServerPropertyErrors" -- This file's name, which the error's position carries
local UNNAMED: string = "an event" -- What the error calls a handle with no registry name

-- Oak.Property as init.luau gives it, calling new straight from its own body, in a chunk apart from this file
local STAND_IN: string = [[
local Property = require(script.Parent.Property)

return function (handle, default)
	return Property.new(handle, default)
end
]]

return function (): (boolean, string | nil)
	local server = Environment.new()
	local network: any = server:network("Oak")
	local Property: any = server:load("Property")

	server:mount("OakProperty", STAND_IN)
	local oakProperty: (handle: any, default: any) -> any = server:load("OakProperty")

	Property.prepare(network)
	oakProperty(network.Shop.coins, START)

	local made: boolean, refusal: any =
		pcall(oakProperty, network.Shop.stock, { version = OTHER, shelf = { label = "", slots = {} } })
	if not made then
		return false, `A Property on a second event errored: {refusal}`
	end

	local doubled: boolean, message: any = pcall(function ()
		oakProperty(network.Shop.coins, OTHER)
	end)

	local text: string = tostring(message)

	if doubled or not text:find("Shop.coins", 1, true) then
		return false, `A second Property on Shop.coins gave {text} rather than an error naming the event`
	end

	if not text:find(CASE, 1, true) then
		return false, `The error points at {text} rather than the line in {CASE} that made the second Property`
	end

	-- A handle the Network's registry does not hold has no name to read; the join below sends to it
	local stray: { [string]: any } = { fire = function () end }
	oakProperty(stray, OTHER)

	local strayed: boolean, unnamed: any = pcall(function ()
		oakProperty(stray, OTHER)
	end)

	if strayed or not tostring(unnamed):find(UNNAMED, 1, true) then
		return false, `A second Property on an unnamed handle gave {unnamed}`
	end

	-- The refused Property was never kept, so a joiner is sent the first one's value alone
	Property.bind(network)

	local _, transport = server.mock:join("Alice")
	local heard: { number } = {}

	server:client(transport):network("Oak").Shop.coins.on(function (value: number)
		table.insert(heard, value)
	end)

	server:step(Environment.HELD + Environment.DELIVERY)

	if table.concat(heard, " ") ~= `{START}` then
		return false, `The joiner heard {table.concat(heard, " ")} on Shop.coins rather than {START} once`
	end

	return true, nil
end
