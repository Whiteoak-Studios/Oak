--[[
    With no game-wide callback, a client built from Stale.volt meeting the
    Oak server is kicked by Volt's own default with both hashes, a bot on
    it is warned about instead, and Shop's onFailure hears neither
--]]

--!strict
local Environment = require("../../Environment")

local MISMATCH: string = "Volt: schema mismatch (client 0x0EE67A62, server 0xBBFA23D4)" -- Stale.volt's hash, then Oak.volt's
local BOT_WARNING: string = `Volt: handshake failure from a bot: {MISMATCH}` -- What the default says in place of kicking a bot

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:substitute("Property", { forget = function () end })

	local serverNetwork: any = server:network("Oak")
	local Failures: any = server:load("Failures")
	local claimed: number = 0

	Failures.bind(serverNetwork, {
		Shop = {
			onFailure = function ()
				claimed += 1
			end,
		},
	}, true)

	local player, transport = server.mock:join("Player")
	server:client(transport):network("Stale")
	server:step(Environment.HANDSHAKE)

	if player.kicked ~= MISMATCH then
		return false, `The stale client was kicked with {player.kicked} rather than both hashes`
	end

	if table.find(server.mock.players, player) then
		return false, "The kicked player is still listed"
	end

	local bot = server.mock:addBot("Bot")
	server:client(server.mock:connectBot(bot)):network("Stale")
	server:step(Environment.HANDSHAKE)

	if not table.find(server.warnings, BOT_WARNING) then
		return false, `The stale bot was not warned about; the server warned {server.warnings[1]}`
	end

	if claimed ~= 0 then
		return false, `Shop's onFailure heard {claimed} handshake failures`
	end

	return true, nil
end
