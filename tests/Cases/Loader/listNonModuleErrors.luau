--[[
    A list entry that is not a ModuleScript fails the boot, naming it,
    whether it is another kind of instance or a service's name by mistake
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
	local list: { any } = { Shop(server, true), server:folder("Config"), "DataService" }

	local booted: boolean, refusal: any = pcall(Oak.start, list, network)
	local message: string = tostring(refusal)

	if booted or not message:find("holds Config, which is not a ModuleScript", 1, true) then
		return false, `A Folder in the list gave {refusal} rather than a refusal naming it`
	end

	if not message:find("holds DataService, which is not a ModuleScript", 1, true) then
		return false, `A string in the list was not named in the refusal: {message}`
	end

	return true, nil
end
