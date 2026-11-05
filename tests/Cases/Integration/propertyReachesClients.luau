--[[
    A Property in ShopService's Client reaches each client's Oak.Property
    through Observe, every value in order: the join replay, a SetTop, and a
    SetFor that one player alone hears and keeps over a later SetTop
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

local START: number = 250 -- The coin balance replayed on joining
local TOP: number = 300 -- Set for every player
local OWN: number = 900 -- Alice's own balance, set for her alone
local LATER: number = 400 -- Set for every player once Alice has her own, which she keeps

--[[
    Boots a client's ShopController with the client half of coins as a
    field, observed into heard from then on; returns whether it booted,
    then the controller, or the refusal when it did not
--]]

local function watch(client: any, heard: { number }): (boolean, any)
	local Oak: any = client:load("init")
	local network: any = client:network("Oak")
	local controller: any = nil

	local module: any = Shop(client, false, function (shop: any)
		shop.coins = Oak.Property(network.Shop.coins)
		controller = shop
	end)

	local booted: boolean, refusal: any = pcall(Oak.start, { module }, network)
	if not booted then
		return false, refusal
	end

	controller.coins:Observe(function (value: number)
		table.insert(heard, value)
	end)

	return true, controller
end

return function (): (boolean, string | nil)
	local server = Environment.new()
	local serverNetwork: any = server:network("Oak")
	local Oak: any = server:load("init")
	local coins: any = nil

	local module: any = Shop(server, true, function (shop: any)
		shop.Client.coins = Oak.Property(serverNetwork.Shop.coins, START)
		coins = shop.Client.coins
	end)

	local booted: boolean, refusal: any = pcall(Oak.start, { module }, serverNetwork)
	if not booted then
		return false, `ShopService failed the boot: {refusal}`
	end

	local alice, aliceTransport = server.mock:join("Alice")
	local _, bobTransport = server.mock:join("Bob")
	local aliceClient = server:client(aliceTransport)
	local aliceHeard: { number } = {}
	local bobHeard: { number } = {}

	local aliceBooted: boolean, aliceShop: any = watch(aliceClient, aliceHeard)
	local bobBooted: boolean, bobShop: any = watch(server:client(bobTransport), bobHeard)

	if not aliceBooted or not bobBooted then
		return false, `A ShopController failed the boot: Alice's with {aliceShop}, Bob's with {bobShop}`
	end

	server:step(Environment.HELD)
	coins:SetTop(TOP)
	server:step(Environment.DELIVERY)
	coins:SetFor(alice, OWN)
	server:step(Environment.DELIVERY)
	coins:SetTop(LATER)
	server:step(Environment.DELIVERY)

	local aliceOrder: string = table.concat(aliceHeard, " ")
	local bobOrder: string = table.concat(bobHeard, " ")

	if aliceOrder ~= `{START} {TOP} {OWN}` then
		return false, `Alice observed {aliceOrder} rather than {START} {TOP} {OWN}`
	end

	if bobOrder ~= `{START} {TOP} {LATER}` then
		return false, `Bob observed {bobOrder} rather than {START} {TOP} {LATER}`
	end

	-- Another Oak.Property call for the event gives the controller's field, holding Alice's own balance
	local again: any = aliceClient:load("init").Property(aliceClient:network("Oak").Shop.coins)

	if not rawequal(again, aliceShop.coins) or again:Get() ~= OWN then
		return false, `A second Oak.Property on Alice's client gave {again}, holding {again:Get()}`
	end

	return true, nil
end
