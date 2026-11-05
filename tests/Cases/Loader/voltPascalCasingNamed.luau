--[[
    A Network compiled with option casing = pascal carries Version rather
    than version, and the line check's error names the casing rather than
    a missing field
--]]

--!strict
local Environment = require("../../Environment")
local Volt = require("@volt")

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", { prepare = function () end, bind = function () end })
	server:substitute("ClientProperty", {})

	local Oak: any = server:load("init")

	local network: { [string]: any } = {
		Version = Volt.version,
		OnFailure = function () end,
		Events = {},
		Functions = {},
	}

	local booted: boolean, refusal: any = pcall(Oak.start, {}, network)
	local message: string = tostring(refusal)

	if booted or not message:find("casing = pascal", 1, true) or message:find("no version field", 1, true) then
		return false, `A pascal Network gave {refusal} rather than a refusal naming its casing`
	end

	return true, nil
end
