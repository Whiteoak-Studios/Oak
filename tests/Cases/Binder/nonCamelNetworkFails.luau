--[[
    A Network compiled with a casing other than camel, so with no function
    at onFailure, fails the boot with that one error and no other, since
    every later check reads members by their camel names
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

	-- A snake module keeps version, events and on, and renames onFailure; its stray event would fail a later check
	local network: { [string]: any } = {
		version = Volt.version,
		on_failure = function () end,
		events = { announce = {} },
		functions = {},
	}

	local booted: boolean, refusal: any = pcall(Oak.start, {}, network)
	local message: string = tostring(refusal)

	if booted or not message:find("casing other than camel", 1, true) then
		return false, `A non-camel Network gave {refusal} rather than a refusal naming its casing`
	end

	if message:find("announce", 1, true) then
		return false, `A non-camel Network was checked past its casing: {message}`
	end

	return true, nil
end
