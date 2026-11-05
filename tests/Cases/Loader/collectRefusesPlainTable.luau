--[[
    A module under the root that returns a table create did not make fails
    the boot, naming the module, before anything is bound
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

return function (): (boolean, string | nil)
	local bound: boolean = false

	local server = Environment.new()
	server:substitute("Failures", {
		bind = function ()
			bound = true
		end,
	})
	server:substitute("Property", { prepare = function () end, bind = function () end })
	server:substitute("ClientProperty", {})

	local Oak: any = server:load("init")
	local network: any = server:network("Oak")

	local root: any = server:folder("Services")
	Shop(server, true).Parent = root
	server:module("DataService", function (): any
		return { _profiles = {} }
	end, root)

	local booted: boolean, refusal: any = pcall(Oak.start, root, network)
	local expected: string = "Services.DataService returned something Oak.create did not make"

	if booted or not tostring(refusal):find(expected, 1, true) then
		return false, `A plain table under the root gave {refusal} rather than a refusal naming its module`
	end

	if bound then
		return false, "The boot went on to bind after collect found a plain table"
	end

	return true, nil
end
