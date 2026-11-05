--[[
    A list that names one ModuleScript twice fails the boot, naming the
    module, rather than collecting it once and saying nothing
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
	local shop: any = Shop(server, true)

	local booted: boolean, refusal: any = pcall(Oak.start, { shop, shop }, network)

	if booted or not tostring(refusal):find("Oak.start's list names ShopService twice", 1, true) then
		return false, `A list naming ShopService twice gave {refusal} rather than a refusal naming it`
	end

	return true, nil
end
