--[[
    Two started tables whose names give one namespace, ShopService and a
    table named Shop, fail the boot, and the error names both tables
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

	local bare: any = server:module("Shop", function (): any
		return Oak.create("Shop", {})
	end)

	local booted: boolean, refusal: any = pcall(Oak.start, { Shop(server, true), bare }, network)

	if booted or not tostring(refusal):find("Shop and ShopService both give the namespace Shop", 1, true) then
		return false, `Two tables giving Shop gave {refusal} rather than a refusal naming both`
	end

	return true, nil
end
