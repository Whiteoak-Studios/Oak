--[[
    Two modules in one realm creating tables of one name fail the boot,
    and the error names the name and both modules
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", { prepare = function () end, bind = function () end })
	server:substitute("ClientProperty", {})

	local Oak: any = server:load("init")
	local network: any = server:network("Oak")

	local root: any = server:folder("Services")
	Shop(server, true).Parent = root

	for _, moduleName: string in { "DataService", "ProfileService" } do
		server:module(moduleName, function (): any
			return Oak.create("DataService", {})
		end, root)
	end

	local booted: boolean, refusal: any = pcall(Oak.start, root, network)
	local message: string = tostring(refusal)

	if booted or not message:find("both create DataService", 1, true) then
		return false, `Two tables named DataService gave {refusal} rather than a refusal naming the name`
	end

	if not (message:find("Services.DataService", 1, true) and message:find("Services.ProfileService", 1, true)) then
		return false, `The refusal did not name both modules: {message}`
	end

	return true, nil
end
