--[[
    Once collect has ended, getService gives the real table rather than a
    proxy, and a name no table has errors at once, naming it
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

local TYPO: string = "DataServce" -- A name no collected table has

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

	local booted: boolean, refusal: any = pcall(Oak.start, { module }, network)
	if not booted then
		return false, `ShopService failed the boot: {refusal}`
	end

	if not rawequal(Oak.getService("ShopService"), shop) then
		return false, "getService after collect gave something other than the real table"
	end

	local found: boolean, missing: any = pcall(Oak.getService, TYPO)

	if found or not tostring(missing):find(TYPO, 1, true) then
		return false, `getService after collect for a missing name gave {missing} rather than an error naming it`
	end

	return true, nil
end
