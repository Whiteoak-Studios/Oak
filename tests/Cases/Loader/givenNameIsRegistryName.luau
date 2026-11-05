--[[
    The name given to create is the table's registry name and namespace
    even when its ModuleScript is named otherwise: peers find it by that
    name alone, and nothing warns
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

local MODULE_NAME: string = "Store" -- What the ModuleScript is renamed to, which the table never answers to

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", { prepare = function () end, bind = function () end })
	server:substitute("ClientProperty", {})

	local Oak: any = server:load("init")
	local network: any = server:network("Oak")
	local shop: any = nil

	local module: any = Shop(server, true, function (created: any)
		shop = created
	end)
	module.Name = MODULE_NAME

	-- The boot passing means ShopService, not Store, owns the Shop namespace
	local booted: boolean, refusal: any = pcall(Oak.start, { module }, network)
	if not booted then
		return false, `A table named apart from its ModuleScript failed the boot: {refusal}`
	end

	if not rawequal(Oak.getService("ShopService"), shop) then
		return false, "getService by the created name did not give the created table"
	end

	if pcall(Oak.getService, MODULE_NAME) then
		return false, "getService by the ModuleScript's name found a table"
	end

	if #server.warnings ~= 0 then
		return false, `A named table warned: {server.warnings[1]}`
	end

	return true, nil
end
