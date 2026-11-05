--[[
    The fake game answers RunService and ReplicatedStorage, and refuses
    any other service by name rather than handing back nil
--]]

--!strict
local Environment = require("../../Environment")

local SOURCE: string = [[
return function (name: string): any
	return game:GetService(name)
end
]]

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:mount("Services", SOURCE)

	local getService: (name: string) -> any = server:load("Services")

	if getService("ReplicatedStorage").Packages == nil then
		return false, "ReplicatedStorage holds no Packages"
	end

	local found: boolean, refusal: any = pcall(getService, "Players")

	if found or not tostring(refusal):find("Players", 1, true) then
		return false, `GetService("Players") gave {refusal} rather than an error naming the service`
	end

	return true, nil
end
