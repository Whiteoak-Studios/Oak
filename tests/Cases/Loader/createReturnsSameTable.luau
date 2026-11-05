--[[
    create hands back the very table it was given, named or not, with its
    fields untouched, so every file that requires a service keeps its type
--]]

--!strict
local Environment = require("../../Environment")

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", { prepare = function () end, bind = function () end })
	server:substitute("ClientProperty", {})

	local Oak: any = server:load("init")
	local named: { [string]: any } = { _count = 0 }
	local unnamed: { [string]: any } = { _count = 0 }

	if not rawequal(Oak.create("ShopService", named), named) then
		return false, "create with a name returned another table than the one it was given"
	end

	if not rawequal(Oak.create(unnamed), unnamed) then
		return false, "create with no name returned another table than the one it was given"
	end

	if named._count ~= 0 or unnamed._count ~= 0 or rawget(named, "ShopService") ~= nil then
		return false, "create changed a field of the table it was given, or wrote its name into it"
	end

	return true, nil
end
