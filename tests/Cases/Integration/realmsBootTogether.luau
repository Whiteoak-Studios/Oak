--[[
    A server and a client boot over Oak.volt with every module real: each
    runs every Init before any Start and resolves Oak.onStart, while a
    client whose controller leaves confirm unconnected starts nothing
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

local SERVICE: string = "ShopService" -- The table tests/Shop.luau makes on the server
local CONTROLLER: string = "ShopController" -- The one it makes on a client, which owns Shop.confirm there
local SERVER_LEDGER: string = "LedgerService" -- A second service, whose namespace Oak.volt leaves empty
local CLIENT_LEDGER: string = "LedgerController" -- The client's twin of it
local CONFIRM: string = "Shop.confirm" -- The function a client with no handler for it is refused over

type Boot = {
	booted: boolean, -- Whether Oak.start returned
	refusal: any, -- What it raised when it did not
	resolved: boolean, -- Whether the onStart asked for before the boot has resolved
	ran: { string }, -- Each Init and Start, in the order they ran
}

-- Wraps a table's Init and Start so each logs that it ran, the Init still doing what the table's own did
local function lifecycle(name: string, created: any, ran: { string })
	local init: ((any) -> ())? = created.Init

	function created.Init(self: any)
		if init then
			init(self)
		end

		table.insert(ran, `Init {name}`)
	end

	function created.Start(_: any)
		table.insert(ran, `Start {name}`)
	end
end

--[[
    Boots one realm over its Network with its Shop table and a Ledger
    beside it, in that order, onStart asked for first; edit, when given,
    changes the Shop table before its lifecycle is logged
--]]

local function boot(env: any, network: any, server: boolean, edit: ((shop: any) -> ())?): Boot
	local Oak: any = env:load("init")
	local shopName: string = server and SERVICE or CONTROLLER
	local ledgerName: string = server and SERVER_LEDGER or CLIENT_LEDGER
	local result: Boot = { booted = false, refusal = nil, resolved = false, ran = {} }

	local shop: any = Shop(env, server, function (created: any)
		if edit then
			edit(created)
		end

		lifecycle(shopName, created, result.ran)
	end)

	local ledger: any = env:module(ledgerName, function (): any
		local created: any = Oak.create(ledgerName, {})
		lifecycle(ledgerName, created, result.ran)

		return created
	end)

	Oak.onStart():andThen(function ()
		result.resolved = true
	end)

	result.booted, result.refusal = pcall(Oak.start, { shop, ledger }, network)

	return result
end

-- The order a clean boot of the two tables runs their lifecycles in
local function cleanOrder(shop: string, ledger: string): string
	return `Init {shop}, Init {ledger}, Start {shop}, Start {ledger}`
end

return function (): (boolean, string | nil)
	local server = Environment.new()
	local serverNetwork: any = server:network("Oak")

	local _, aliceTransport = server.mock:join("Alice")
	local _, bobTransport = server.mock:join("Bob")
	local client = server:client(aliceTransport)
	local stalled = server:client(bobTransport)

	local served: Boot = boot(server, serverNetwork, true, nil)
	local started: Boot = boot(client, client:network("Oak"), false, nil)

	if not served.booted or not started.booted then
		return false, `A clean boot failed: the server's with {served.refusal}, the client's with {started.refusal}`
	end

	local serverOrder: string = table.concat(served.ran, ", ")
	local clientOrder: string = table.concat(started.ran, ", ")

	if serverOrder ~= cleanOrder(SERVICE, SERVER_LEDGER) then
		return false, `The server's lifecycle ran as {serverOrder}`
	end

	if clientOrder ~= cleanOrder(CONTROLLER, CLIENT_LEDGER) then
		return false, `The client's lifecycle ran as {clientOrder}`
	end

	if not served.resolved or not started.resolved then
		return false, `Oak.onStart resolved as {served.resolved} on the server and {started.resolved} on the client`
	end

	if #server.warnings + #client.warnings > 0 then
		return false, `A clean boot warned: {server.warnings[1] or client.warnings[1]}`
	end

	-- Bob's controller has an Init that leaves confirm unconnected, so his boot stops before any Start
	local refused: Boot = boot(stalled, stalled:network("Oak"), false, function (shop: any)
		function shop:Init() end
	end)

	local refusal: string = tostring(refused.refusal)
	local named: boolean = refusal:find(CONFIRM, 1, true) ~= nil and refusal:find(CONTROLLER, 1, true) ~= nil

	if refused.booted or not named then
		return false, `A client with confirm unconnected booted as {refused.booted}, refused with {refusal}`
	end

	local stalledOrder: string = table.concat(refused.ran, ", ")

	if stalledOrder ~= `Init {CONTROLLER}, Init {CLIENT_LEDGER}` or refused.resolved then
		return false, `The refused client ran {stalledOrder}, and its onStart resolved as {refused.resolved}`
	end

	return true, nil
end
