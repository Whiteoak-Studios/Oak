--[[
    A drop from a full hold reaches Property's forget through the booted
    Failures, so the coin set the hold had no room for reaches the late
    client at its handshake, while a player whose hold had room gets none
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

local START: number = 250 -- The coin balance replayed on joining, first into each hold
local TOP: number = 300 -- A balance set once Alice's hold is full
local LINE: string = "abc" -- A chat line as long on the wire as a coin value, five bytes, so the set fits no better
local MOST_FIRES: number = 100000 -- More lines than a hold has room for, so the fill ends in a drop

type Watched = {
	coins: { number }, -- Every coin value observed, in order
	lines: number, -- How many chat lines arrived
}

--[[
    Loads a late client's Network, observes the client half of coins that
    its Oak.Property gives, and counts the chat lines it hears, so none of
    them waits in the event's queue
--]]

local function watch(client: any): Watched
	local network: any = client:network("Oak")
	local watched: Watched = { coins = {}, lines = 0 }

	client:load("init").Property(network.Shop.coins):Observe(function (value: number)
		table.insert(watched.coins, value)
	end)

	network.Shop.chat.on(function ()
		watched.lines += 1
	end)

	return watched
end

return function (): (boolean, string | nil)
	local server = Environment.new()
	local serverNetwork: any = server:network("Oak")
	local Oak: any = server:load("init")
	local coins: any = nil
	local failures: { { any } } = {}

	local module: any = Shop(server, true, function (shop: any)
		shop.Client.coins = Oak.Property(serverNetwork.Shop.coins, START)
		coins = shop.Client.coins
	end)

	-- The game's callback takes each drop once Property has heard of it, so Volt's default stays quiet
	Oak.onFailure(function (player: any, kind: string)
		table.insert(failures, { player, kind })
	end)

	local booted: boolean, refusal: any = pcall(Oak.start, { module }, serverNetwork)
	if not booted then
		return false, `ShopService failed the boot: {refusal}`
	end

	local alice, aliceTransport = server.mock:join("Alice")
	local _, bobTransport = server.mock:join("Bob")
	local drops: { [string]: number } = serverNetwork.stats(alice).failures

	-- 1) Fill Alice's hold with chat lines until one is dropped, then set a balance it has no room for
	for _ = 1, MOST_FIRES do
		serverNetwork.Shop.chat.fire(alice, LINE)

		if drops.outgoing then
			break
		end
	end

	if not drops.outgoing then
		return false, `{MOST_FIRES} chat lines never filled Alice's hold`
	end

	coins:SetTop(TOP)

	-- 2) Both clients load late, and what each hold kept arrives: for Alice, nothing of the set
	local aliceSeen: Watched = watch(server:client(aliceTransport))
	local bobSeen: Watched = watch(server:client(bobTransport))
	server:step(Environment.HELD)

	local aliceHeld: string = table.concat(aliceSeen.coins, " ")

	if aliceHeld ~= `{START}` or aliceSeen.lines == 0 then
		return false, `Alice's hold gave her the coins {aliceHeld} and {aliceSeen.lines} chat lines`
	end

	-- 3) The set reaches Alice once her handshake is accepted, and Bob, whose hold had room, is resent nothing
	server:step(Environment.HANDSHAKE + Environment.DELIVERY - Environment.HELD)

	local aliceOrder: string = table.concat(aliceSeen.coins, " ")
	local bobOrder: string = table.concat(bobSeen.coins, " ")

	if aliceOrder ~= `{START} {TOP}` then
		return false, `Alice observed {aliceOrder} rather than {START} {TOP} once her handshake was accepted`
	end

	if bobOrder ~= `{START} {TOP}` then
		return false, `Bob observed {bobOrder} rather than {START} {TOP}`
	end

	-- 4) Every drop went to the game's callback as Alice's outgoing failure
	if #failures == 0 or #server.warnings > 0 then
		return false, `The callback heard {#failures} failures, and the server warned {server.warnings[1]}`
	end

	for _, failure: { any } in failures do
		if failure[1] ~= alice or failure[2] ~= "outgoing" then
			return false, `The callback heard a {failure[2]} failure for {failure[1]}`
		end
	end

	return true, nil
end
