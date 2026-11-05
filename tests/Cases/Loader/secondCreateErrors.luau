--[[
    A table create has already made cannot be created again, with a name or
    without one, so one table is only ever one service or controller
--]]

--!strict
local Environment = require("../../Environment")

local REFUSAL: string = "already created" -- What the error says of a table created twice

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", { prepare = function () end, bind = function () end })
	server:substitute("ClientProperty", {})

	local Oak: any = server:load("init")
	local named: { [string]: any } = {}
	local unnamed: { [string]: any } = {}

	Oak.create("ShopService", named)
	Oak.create(unnamed)

	local renamed: boolean, renameRefusal: any = pcall(Oak.create, "OtherService", named)
	if renamed or not tostring(renameRefusal):find(REFUSAL, 1, true) then
		return false, `Creating a named table again under another name gave {renameRefusal} rather than an error`
	end

	local again: boolean, againRefusal: any = pcall(Oak.create, unnamed)
	if again or not tostring(againRefusal):find(REFUSAL, 1, true) then
		return false, `Creating an unnamed table again gave {againRefusal} rather than an error`
	end

	return true, nil
end
