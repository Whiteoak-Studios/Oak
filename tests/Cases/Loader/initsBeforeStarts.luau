--[[
    Every collected table's Init runs before any table's Start, so a Start
    may call a peer whose Init has already set it up
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

local NAMES: { string } = { "AService", "BService" } -- Started beside ShopService
local METHODS: number = 2 -- Init and Start, each run once per table

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", { prepare = function () end, bind = function () end })
	server:substitute("ClientProperty", {})

	local Oak: any = server:load("init")
	local network: any = server:network("Oak")
	local ran: { string } = {}

	local function lifecycle(name: string, created: any)
		function created:Init()
			table.insert(ran, `Init {name}`)
		end

		function created:Start()
			table.insert(ran, `Start {name}`)
		end
	end

	local list: { any } = {
		Shop(server, true, function (shop: any)
			lifecycle("ShopService", shop)
		end),
	}

	for _, name: string in NAMES do
		table.insert(
			list,
			server:module(name, function (): any
				local created: any = Oak.create(name, {})
				lifecycle(name, created)

				return created
			end)
		)
	end

	local booted: boolean, refusal: any = pcall(Oak.start, list, network)
	if not booted then
		return false, `The services failed the boot: {refusal}`
	end

	local inits: number = #NAMES + 1

	for index: number, entry: string in ran do
		local isInit: boolean = entry:sub(1, #"Init") == "Init"

		if isInit ~= (index <= inits) then
			return false, `The lifecycle ran as {table.concat(ran, ", ")}`
		end
	end

	if #ran ~= inits * METHODS then
		return false, `{#ran} lifecycle methods ran rather than {inits * METHODS}`
	end

	return true, nil
end
