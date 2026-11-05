--[[
    The booted Failures routes by scope: a failure in ShopService's report
    handler goes to ShopService.onFailure alone, and a Stale client's
    handshake to the game's Oak.onFailure callback, so nobody is kicked
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

local TEXT: string = "Broken shelf" -- What Alice reports
local FAULT: string = "The report desk is closed" -- What ShopService's report handler throws
local DETAIL: string = "Shop.report: " -- How the report failure's detail opens, naming its message
local MISMATCH: string = "Volt: schema mismatch (client 0x0EE67A62, server 0xBBFA23D4)" -- Stale's hash, then Oak's

type Call = { n: number, [number]: any }

return function (): (boolean, string | nil)
	local server = Environment.new()
	local serverNetwork: any = server:network("Oak")
	local Oak: any = server:load("init")
	local owned: { Call } = {}
	local fellThrough: { Call } = {}

	local module: any = Shop(server, true, function (shop: any)
		function shop.Client:report(_: any, _: string)
			error(FAULT, 0)
		end

		function shop.onFailure(...: any)
			table.insert(owned, table.pack(...))
		end
	end)

	Oak.onFailure(function (...: any)
		table.insert(fellThrough, table.pack(...))
	end)

	local booted: boolean, refusal: any = pcall(Oak.start, { module }, serverNetwork)
	if not booted then
		return false, `ShopService failed the boot: {refusal}`
	end

	-- 1) A message failure on Shop goes to the service owning Shop
	local alice, aliceTransport = server.mock:join("Alice")
	local aliceNetwork: any = server:client(aliceTransport):network("Oak")

	server:step(Environment.HANDSHAKE)
	aliceNetwork.Shop.report.fire(TEXT)
	server:step(Environment.DELIVERY)

	local claim: Call? = owned[1]

	if #owned ~= 1 or not claim or claim.n ~= 3 or claim[1] ~= alice or claim[2] ~= "listener" then
		return false, `ShopService.onFailure heard {#owned} failures, the first for {claim and claim[1]}`
	end

	local detail: string = tostring(claim[3])

	if detail:sub(1, #DETAIL) ~= DETAIL then
		return false, `ShopService.onFailure got the detail {detail}`
	end

	if #fellThrough ~= 0 then
		return false, `The game's callback heard the failure ShopService owned: {fellThrough[1][2]}`
	end

	-- 2) A packet failure, the stale client's handshake, goes to the game's callback, which kicks nobody
	local bob, bobTransport = server.mock:join("Bob")
	server:client(bobTransport):network("Stale")
	server:step(Environment.HANDSHAKE)

	local fell: Call? = fellThrough[1]

	if #fellThrough ~= 1 or not fell or fell[1] ~= bob or fell[2] ~= "handshake" or fell[3] ~= MISMATCH then
		return false, `The callback heard {#fellThrough} failures, the first a {fell and fell[2]}: {fell and fell[3]}`
	end

	if bob.kicked ~= nil or not table.find(server.mock.players, bob) then
		return false, `The stale client was kicked with {bob.kicked}, though the game's callback took its handshake`
	end

	if #owned ~= 1 or #server.warnings ~= 0 then
		return false, `ShopService.onFailure heard {#owned} failures, and Volt's default warned {server.warnings[1]}`
	end

	return true, nil
end
