--[[
    Volt's left callback drops a leaver's override and copy, a player's and
    a bot's alike: GetFor reads the top value for them again, and a later
    SetFor, SetForList, Refresh or forget naming them sends and keeps nothing
--]]

--!strict
local Environment = require("../../Environment")

local START: number = 250 -- The top value
local OWN: number = 900 -- The override Alice and the bot each hold before leaving
local LATE: number = 50 -- What a set made after they left would give them

return function (): (boolean, string | nil)
	local server = Environment.new()
	local network: any = server:network("Oak")
	local Property: any = server:load("Property")

	Property.prepare(network)
	local coins: any = Property.new(network.Shop.coins, START)
	Property.bind(network)

	local departed: { any } = {}

	network.onFailure(function (player: any, kind: string)
		if kind == "departed" then
			table.insert(departed, player)
		end
	end)

	local alice = server.mock:join("Alice")
	local bot = server.mock:addBot("Bot")
	server.mock:connectBot(bot)

	coins:SetFor(alice, OWN)
	coins:SetForList({ bot }, OWN)

	if coins:GetFor(alice) ~= OWN or coins:GetFor(bot) ~= OWN then
		return false, `Before leaving, GetFor gave Alice {coins:GetFor(alice)} and the bot {coins:GetFor(bot)}`
	end

	server.mock:leave(alice)
	server.mock:removeBot(bot)

	if coins:GetFor(alice) ~= START or coins:GetFor(bot) ~= START then
		return false, `After leaving, GetFor gave Alice {coins:GetFor(alice)} and the bot {coins:GetFor(bot)}`
	end

	-- Each as a Promise resolving after the leave would make them
	coins:SetFor(alice, LATE)
	coins:SetForList({ bot, alice }, LATE)
	coins:Refresh(alice)
	coins:Refresh(bot)
	Property.forget(alice)
	Property.forget(bot)
	coins:Refresh()
	server:step(Environment.DELIVERY)

	if coins:GetFor(alice) ~= START or coins:GetFor(bot) ~= START then
		return false,
			`A set after leaving left an override: Alice reads {coins:GetFor(alice)}, the bot {coins:GetFor(bot)}`
	end

	coins:SetTop(OWN)
	server:step(Environment.DELIVERY)

	if #departed ~= 0 then
		return false, `{#departed} values were fired at a player or bot who had left`
	end

	return true, nil
end
