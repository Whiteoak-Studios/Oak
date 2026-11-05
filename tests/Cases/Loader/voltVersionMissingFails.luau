--[[
    A Network with no version field counts as one from another Volt line
    and fails the boot, the error saying the field is missing
--]]

--!strict
local Environment = require("../../Environment")

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", { prepare = function () end, bind = function () end })
	server:substitute("ClientProperty", {})

	local Oak: any = server:load("init")

	local network: { [string]: any } = {
		onFailure = function () end,
		events = {},
		functions = {},
	}

	local booted: boolean, refusal: any = pcall(Oak.start, {}, network)

	if booted or not tostring(refusal):find("no version field", 1, true) then
		return false, `A Network with no version gave {refusal} rather than a refusal saying so`
	end

	return true, nil
end
