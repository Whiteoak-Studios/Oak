--[[
    A Network compiled by a Volt on the same major.minor as the one
    installed with Oak boots, though its patch differs, since the line
    check compares the major.minor alone
--]]

--!strict
local Environment = require("../../Environment")
local Volt = require("@volt")

local LINE: string = "^%d+%.%d+" -- The installed Volt's major.minor
local OTHER_PATCH: string = "99" -- A patch on the installed line that no Volt has shipped

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", { prepare = function () end, bind = function () end })
	server:substitute("ClientProperty", {})

	local Oak: any = server:load("init")
	local line: string = Volt.version:match(LINE) :: string

	-- The checks after the line check read these, and an empty registry binds nothing
	local network: { [string]: any } = {
		version = `{line}.{OTHER_PATCH}`,
		onFailure = function () end,
		events = {},
		functions = {},
	}

	local booted: boolean, refusal: any = pcall(Oak.start, {}, network)
	if not booted then
		return false, `A Network compiled by Volt {network.version} failed the boot: {refusal}`
	end

	return true, nil
end
