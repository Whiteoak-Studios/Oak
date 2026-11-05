--[[
    The list form requires each ModuleScript in the order the list gives,
    whatever their names, and runs their Inits in that same order
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

local ORDER: { string } = { "CService", "AService", "BService" } -- Out of name order, so sorting would show

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", { prepare = function () end, bind = function () end })
	server:substitute("ClientProperty", {})

	local Oak: any = server:load("init")
	local network: any = server:network("Oak")
	local required: { string } = {}
	local initialised: { string } = {}
	local list: { any } = { Shop(server, true) }

	for _, name: string in ORDER do
		table.insert(
			list,
			server:module(name, function (): any
				table.insert(required, name)

				local created: any = Oak.create(name, {})

				function created:Start() end
				function created:Init()
					table.insert(initialised, name)
				end

				return created
			end)
		)
	end

	local booted: boolean, refusal: any = pcall(Oak.start, list, network)
	if not booted then
		return false, `A list failed the boot: {refusal}`
	end

	local wanted: string = table.concat(ORDER, ", ")
	local collected: string = table.concat(required, ", ")
	local ran: string = table.concat(initialised, ", ")

	if collected ~= wanted or ran ~= wanted then
		return false, `The list was required as {collected} and initialised as {ran}, not {wanted}`
	end

	return true, nil
end
