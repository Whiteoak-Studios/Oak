--[[
    With neither a table's onFailure nor the game-wide callback to take it,
    a failure reaches the default Volt handed back once, with the player or
    bot, kind and detail it came with, and on the client with no player
--]]

--!strict
local Environment = require("../../Environment")

type Call = { n: number, [number]: any }

--[[
    Loads Failures in a realm and binds it to a stand-in Network that keeps
    Oak's route and hands back a default logging each call, with Shop owned
    by a table that defines no onFailure
--]]

local function bound(environment: any, isServer: boolean): (any, any, { Call })
	environment:substitute("Property", { forget = function () end })

	local Failures: any = environment:load("Failures")
	local route: any = nil
	local defaulted: { Call } = {}

	Failures.bind({
		onFailure = function (handler: any): (...any) -> ()
			route = handler

			return function (...: any)
				table.insert(defaulted, table.pack(...))
			end
		end,
	}, { Shop = {} }, isServer)

	return Failures, route, defaulted
end

return function (): (boolean, string | nil)
	local server = Environment.new()
	local Failures: any, route: any, defaulted: { Call } = bound(server, true)

	local player = server.mock:join("Player")
	local bot = server.mock:addBot("Bot")

	-- A message whose owner takes none, a packet failure from a bot, and a message no table owns
	local failures: { { any } } = {
		{ player, "listener", "Shop.report: The listener broke" },
		{ bot, "packet", "unknown message 9" },
		{ player, "decode", "Ghost.ping: out of range" },
	}

	for index: number, failure: { any } in failures do
		route(failure[1], failure[2], failure[3])

		local call: Call? = defaulted[index]
		if not call or call.n ~= 3 or call[1] ~= failure[1] or call[2] ~= failure[2] or call[3] ~= failure[3] then
			return false, `A {failure[2]} failure reached the default as {call and call[3]}`
		end
	end

	if #defaulted ~= #failures then
		return false, `The default was called {#defaulted} times for {#failures} failures`
	end

	Failures.set(function () end)
	route(player, "packet", "unknown message 9")

	if #defaulted ~= #failures then
		return false, "The default still ran once a game-wide callback was set"
	end

	local _, transport = server.mock:join("Watcher")
	local _, clientRoute: any, clientDefaulted: { Call } = bound(server:client(transport), false)
	local detail: string = "Shop.chat: The listener broke"

	clientRoute(nil, "listener", detail)

	local call: Call? = clientDefaulted[1]
	if #clientDefaulted ~= 1 or not call or call.n ~= 3 or call[1] ~= nil or call[3] ~= detail then
		return false, `The client's default was called {#clientDefaulted} times, first with {call and call[3]}`
	end

	return true, nil
end
