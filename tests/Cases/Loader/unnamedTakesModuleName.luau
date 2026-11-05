--[[
    A table created with no name takes its ModuleScript's name as its
    registry name, and the boot warns once that it fell back to it
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

local FALLBACK: string = "created its table with no name" -- What the warning says of the table

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", { prepare = function () end, bind = function () end })
	server:substitute("ClientProperty", {})

	local Oak: any = server:load("init")
	local network: any = server:network("Oak")
	local data: any = nil

	local module: any = server:module("DataService", function (): any
		data = Oak.create({ _profiles = {} })
		return data
	end)

	local booted: boolean, refusal: any = pcall(Oak.start, { Shop(server, true), module }, network)
	if not booted then
		return false, `An unnamed table failed the boot: {refusal}`
	end

	if not rawequal(Oak.getService("DataService"), data) then
		return false, "getService by the ModuleScript's name did not give the unnamed table"
	end

	local fallbacks: number = 0
	local last: string = ""

	for _, warning: string in server.warnings do
		if warning:find(FALLBACK, 1, true) then
			fallbacks += 1
			last = warning
		end
	end

	if fallbacks ~= 1 or not last:find("DataService", 1, true) then
		return false, `The boot warned {fallbacks} times of the fallback, the last being {last}`
	end

	return true, nil
end
