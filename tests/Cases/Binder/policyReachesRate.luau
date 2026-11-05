--[[
    Each Policy row reaches the Network's rate under its endpoint's name,
    a row with no burst given its perSecond as the burst, and no endpoint
    without a row is rated
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

local BUY_RATE: number = 3 -- A row with no burst
local CHAT_RATE: number = 4 -- A row with its own burst
local CHAT_BURST: number = 9
local ROWS: number = 4 -- buy, report, chat and browse

return function (): (boolean, string | nil)
	local server = Environment.new()
	local real: any = server:network("Oak")
	local rated: { [string]: { number? } } = {}
	local count: number = 0

	local network: any = setmetatable({
		rate = function (name: string, perSecond: number, burst: number?)
			rated[name] = { perSecond, burst }
			count += 1
			real.rate(name, perSecond, burst)
		end,
	}, { __index = real })

	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", { prepare = function () end, bind = function () end })
	server:substitute("ClientProperty", {})

	local Oak: any = server:load("init")

	local module: any = Shop(server, true, function (shop: any)
		shop.Policy.buy = { rate = { perSecond = BUY_RATE } }
		shop.Policy.chat = { rate = { perSecond = CHAT_RATE, burst = CHAT_BURST } }
	end)

	local booted: boolean, refusal: any = pcall(Oak.start, { module }, network)
	if not booted then
		return false, `ShopService failed the boot: {refusal}`
	end

	local buy: { number? } = rated["Shop.buy"] or {}
	local chat: { number? } = rated["Shop.chat"] or {}

	if buy[1] ~= BUY_RATE or buy[2] ~= BUY_RATE then
		return false, `Shop.buy was rated {buy[1]} with burst {buy[2]}, not {BUY_RATE} with the same burst`
	end

	if chat[1] ~= CHAT_RATE or chat[2] ~= CHAT_BURST then
		return false, `Shop.chat was rated {chat[1]} with burst {chat[2]}, not {CHAT_RATE} with {CHAT_BURST}`
	end

	if count ~= ROWS or rated["Shop.report"] == nil or rated["Shop.browse"] == nil then
		return false, `Rate was called {count} times rather than once for each of the {ROWS} rows`
	end

	return true, nil
end
