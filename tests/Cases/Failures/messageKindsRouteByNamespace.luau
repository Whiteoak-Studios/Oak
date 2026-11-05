--[[
    Every message-scoped kind routes by the namespace its detail opens with,
    a decode that names a field after its message among them, while a name
    no started table owns, or one with no namespace, falls to the callback
--]]

--!strict
local Environment = require("../../Environment")

local KINDS: { string } = { "decode", "listener", "handler", "queue", "resolve", "rate" }
local FIELD: string = "Shop.buy: Shop.buy.reason: length out of range" -- A decode inside a field names its message first
local CATALOG: string = "Catalog.ping: The listener broke" -- A message in another started table's namespace
local UNOWNED: string = "Ghost.ping: over 60 a second" -- A namespace no started table owns
local BARE: string = "announce: The listener broke" -- A registry name with no namespace

type Call = { n: number, [number]: any }

-- A table whose onFailure keeps every call it gets
local function recorder(): ({ [string]: any }, { Call })
	local calls: { Call } = {}

	return {
		onFailure = function (...: any)
			table.insert(calls, table.pack(...))
		end,
	}, calls
end

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:substitute("Property", { forget = function () end })

	local serverNetwork: any = server:network("Oak")
	local Failures: any = server:load("Failures")

	local shop: { [string]: any }, shopCalls: { Call } = recorder()
	local catalog: { [string]: any }, catalogCalls: { Call } = recorder()
	local callback: { [string]: any }, fellThrough: { Call } = recorder()

	Failures.bind(serverNetwork, { Shop = shop, Catalog = catalog }, true)
	Failures.set(callback.onFailure)

	-- Volt hands back the handler it replaces, which is Oak's route, so it goes straight back
	local route: any = serverNetwork.onFailure(function () end)
	serverNetwork.onFailure(route)

	local player = server.mock:join("Player")

	for index: number, kind: string in KINDS do
		local detail: string = `Shop.buy: {kind} failed`
		route(player, kind, detail)

		local call: Call? = shopCalls[index]
		if not call or call[1] ~= player or call[2] ~= kind or call[3] ~= detail then
			return false, `A {kind} failure on Shop.buy reached Shop's onFailure as {call and call[3]}`
		end
	end

	route(player, "decode", FIELD)

	local field: Call? = shopCalls[#KINDS + 1]
	if not field or field[3] ~= FIELD then
		return false, `A decode naming a field reached Shop's onFailure as {field and field[3]}`
	end

	route(player, "listener", CATALOG)

	if #catalogCalls ~= 1 or catalogCalls[1][3] ~= CATALOG or #shopCalls ~= #KINDS + 1 then
		return false, `Catalog's onFailure heard {#catalogCalls} failures, and Shop's {#shopCalls}`
	end

	route(player, "rate", UNOWNED)
	route(player, "listener", BARE)

	if #fellThrough ~= 2 or fellThrough[1][3] ~= UNOWNED or fellThrough[2][3] ~= BARE then
		return false, `The callback heard {#fellThrough} failures rather than the unowned and the bare one`
	end

	if #shopCalls ~= #KINDS + 1 or #catalogCalls ~= 1 then
		return false, "A failure no table owns reached a table's onFailure"
	end

	return true, nil
end
