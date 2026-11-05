--[[
    A service's onFailure that throws, and then a game-wide callback that
    throws, are each warned about by Oak, and the messages after the failed
    one in the same packet still reach their listener
--]]

--!strict
local Environment = require("../../Environment")

local RAISED: string = "Oak: a failure handler raised: " -- How Oak's warning about a throwing handler opens
local SHOP_ERROR: string = "Shop's handler broke"
local CALLBACK_ERROR: string = "The callback broke"
local LATER: string = "After" -- What the client sends after the message that fails, in the same packet

-- Whether exactly one warning is Oak's about a handler that raised the error given
local function warnedOnce(warnings: { string }, raised: string): boolean
	local found: number = 0

	for _, warning: string in warnings do
		if warning:sub(1, #RAISED) == RAISED and warning:find(raised, 1, true) ~= nil then
			found += 1
		end
	end

	return found == 1
end

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:substitute("Property", { forget = function () end })

	local serverNetwork: any = server:network("Oak")
	local Failures: any = server:load("Failures")

	local shop: { [string]: any } = {
		onFailure = function ()
			error(SHOP_ERROR)
		end,
	}

	Failures.bind(serverNetwork, { Shop = shop }, true)

	serverNetwork.Shop.report.on(function ()
		error("The listener broke")
	end)

	local heard: { string } = {}

	serverNetwork.Shop.chat.on(function (_: any, text: string)
		table.insert(heard, text)
	end)

	local _, transport = server.mock:join("Player")
	local clientNetwork: any = server:client(transport):network("Oak")

	server:step(Environment.HANDSHAKE)
	clientNetwork.Shop.report.fire("Report")
	clientNetwork.Shop.chat.fire(LATER)
	server:step(Environment.DELIVERY)

	if heard[1] ~= LATER or not warnedOnce(server.warnings, SHOP_ERROR) then
		return false, `After Shop's onFailure threw, the chat listener heard {heard[1]}; warned {server.warnings[1]}`
	end

	shop.onFailure = nil
	Failures.set(function ()
		error(CALLBACK_ERROR)
	end)

	clientNetwork.Shop.report.fire("Report")
	clientNetwork.Shop.chat.fire(LATER)
	server:step(Environment.DELIVERY)

	if heard[2] ~= LATER or not warnedOnce(server.warnings, CALLBACK_ERROR) then
		return false, `After the callback threw, the chat listener heard {heard[2]}; warned {server.warnings[2]}`
	end

	-- Oak caught both, so Volt never saw its handler raise, and its default never ran
	if #server.warnings ~= 2 then
		return false, `The server warned {#server.warnings} times rather than once per throw: {server.warnings[3]}`
	end

	return true, nil
end
