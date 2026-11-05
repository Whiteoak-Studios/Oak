--[[
    A table named Service or Controller alone gives an empty namespace and
    fails the boot, naming it
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

local SUFFIXES: { string } = { "Service", "Controller" } -- Each a whole name with nothing before its suffix

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", { prepare = function () end, bind = function () end })
	server:substitute("ClientProperty", {})

	local Oak: any = server:load("init")
	local network: any = server:network("Oak")
	local list: { any } = { Shop(server, true) }

	for _, name: string in SUFFIXES do
		table.insert(
			list,
			server:module(name, function (): any
				return Oak.create(name, {})
			end)
		)
	end

	local booted: boolean, refusal: any = pcall(Oak.start, list, network)
	local message: string = tostring(refusal)

	for _, name: string in SUFFIXES do
		if booted or not message:find(`{name} gives an empty namespace`, 1, true) then
			return false, `A table named {name} gave {refusal} rather than a refusal naming it`
		end
	end

	return true, nil
end
