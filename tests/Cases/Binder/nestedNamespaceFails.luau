--[[
    An endpoint declared in a namespace inside a namespace fails the boot,
    naming it, since every registry name must be exactly Namespace.message
--]]

--!strict
local Environment = require("../../Environment")

return function (): (boolean, string | nil)
	local server = Environment.new()
	local network: any = server:network("Nested")
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", { prepare = function () end, bind = function () end })
	server:substitute("ClientProperty", {})

	local booted: boolean, refusal: any = pcall(server:load("init").start, {}, network)

	if booted or not tostring(refusal):find("Outer.Inner.announce sits in a nested namespace", 1, true) then
		return false, `A nested endpoint gave {refusal} rather than a refusal naming it`
	end

	return true, nil
end
