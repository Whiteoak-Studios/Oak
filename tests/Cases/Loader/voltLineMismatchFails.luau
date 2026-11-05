--[[
    A Network compiled by another Volt line fails the boot before anything
    reads it, the error naming both versions
--]]

--!strict
local Environment = require("../../Environment")
local Volt = require("@volt")

local LINE: string = "^(%d+)%.(%d+)" -- The installed Volt's major and minor

return function (): (boolean, string | nil)
	local prepared: boolean = false

	local server = Environment.new()
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", {
		prepare = function ()
			prepared = true
		end,
		bind = function () end,
	})
	server:substitute("ClientProperty", {})

	local Oak: any = server:load("init")
	local major: string?, minor: string? = Volt.version:match(LINE)
	local nextLine: string = `{major}.{tonumber(minor) :: number + 1}.0`

	local network: { [string]: any } = {
		version = nextLine,
		onFailure = function () end,
		events = {},
		functions = {},
	}

	local booted: boolean, refusal: any = pcall(Oak.start, {}, network)
	local message: string = tostring(refusal)

	if booted or not (message:find(nextLine, 1, true) and message:find(Volt.version, 1, true)) then
		return false, `A Network from Volt {nextLine} gave {refusal} rather than a refusal naming both versions`
	end

	if prepared then
		return false, "The Property was prepared over a Network from another Volt line"
	end

	return true, nil
end
