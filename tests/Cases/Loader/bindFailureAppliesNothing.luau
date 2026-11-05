--[[
    A boot whose binding check finds a problem fails whole: no rate is set,
    the failure slot is not taken, no handler or Property is bound and no
    Init runs
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

return function (): (boolean, string | nil)
	local applied: { string } = {}

	local server = Environment.new()
	local real: any = server:network("Oak")

	local network: any = setmetatable({
		rate = function (name: string, perSecond: number, burst: number?)
			table.insert(applied, `rate {name}`)
			real.rate(name, perSecond, burst)
		end,
	}, { __index = real })

	server:substitute("Failures", {
		bind = function ()
			table.insert(applied, "Failures.bind")
		end,
	})
	server:substitute("Property", {
		prepare = function () end,
		bind = function ()
			table.insert(applied, "Property.bind")
		end,
	})
	server:substitute("ClientProperty", {})

	local Oak: any = server:load("init")

	local module: any = Shop(server, true, function (shop: any)
		shop.Client.buy = nil

		function shop:Init()
			table.insert(applied, "Init")
		end
	end)

	local booted: boolean, refusal: any = pcall(Oak.start, { module }, network)

	if booted or not tostring(refusal):find("Shop.buy has no handler", 1, true) then
		return false, `A missing handler gave {refusal} rather than a refusal naming it`
	end

	if #applied > 0 then
		return false, `A refused boot still applied {table.concat(applied, ", ")}`
	end

	-- Shop.report is SingleSync, so a second on would error had the binder connected the first
	local connected: boolean, taken: any = pcall(real.Shop.report.on, function () end)
	if not connected then
		return false, `A refused boot left Shop.report's listener connected: {taken}`
	end

	return true, nil
end
