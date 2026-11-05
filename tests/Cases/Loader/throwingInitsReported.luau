--[[
    Two Inits that throw are both reported, each with its table's name and
    its error, and the boot then errors before any Start runs
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

local BROKEN: { string } = { "AService", "BService" } -- Each throws its own name from Init

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", { prepare = function () end, bind = function () end })
	server:substitute("ClientProperty", {})

	local Oak: any = server:load("init")
	local network: any = server:network("Oak")
	local started: boolean = false

	local list: { any } = {
		Shop(server, true, function (shop: any)
			function shop:Start()
				started = true
			end
		end),
	}

	for _, name: string in BROKEN do
		table.insert(
			list,
			server:module(name, function (): any
				local created: any = Oak.create(name, {})

				function created:Start() end
				function created:Init()
					error(`{name} could not load its config`)
				end

				return created
			end)
		)
	end

	local booted: boolean, refusal: any = pcall(Oak.start, list, network)
	local message: string = tostring(refusal)

	if booted then
		return false, "Two throwing Inits did not fail the boot"
	end

	for _, name: string in BROKEN do
		if not (message:find(`{name}'s Init threw`, 1, true) and message:find(`{name} could not load`, 1, true)) then
			return false, `The refusal did not report {name}'s Init with its error: {message}`
		end
	end

	if started then
		return false, "A Start ran after the Inits failed"
	end

	return true, nil
end
