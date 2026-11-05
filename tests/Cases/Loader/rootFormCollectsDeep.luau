--[[
    The root form collects every ModuleScript under the root at any depth,
    a service three folders down among them, and boots each one
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
	local features: any = server:folder("Features", root)
	local profiles: any = server:folder("Profiles", server:folder("Player", root))
	local initialised: boolean = false
	local data: any = nil

	Shop(server, true).Parent = features
	server:module("DataService", function (): any
		data = Oak.create("DataService", {})

		function data:Start() end
		function data:Init()
			initialised = true
		end

		return data
	end, profiles)

	local booted: boolean, refusal: any = pcall(Oak.start, root, network)
	if not booted then
		return false, `A deep tree failed the boot: {refusal}`
	end

	if not initialised or not rawequal(Oak.getService("DataService"), data) then
		return false, "The service three folders down was not collected and initialised"
	end

	return true, nil
end
