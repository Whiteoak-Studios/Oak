--[[
    A double stands in for a sibling src has no file for, reached through
    script.Parent as a src module reaches it, and a sibling nothing stands
    in for errors by its name, as the engine's does
--]]

--!strict
local Environment = require("../../Environment")

local SOURCE: string = [[
local Router = {}

function Router.bind(): any
	return require(script.Parent.Ghost)
end

return Router
]]

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:mount("Router", SOURCE)

	local Router: any = server:load("Router")
	local reached: boolean, missing: any = pcall(Router.bind)

	if reached or not tostring(missing):find("Ghost", 1, true) then
		return false, `A missing sibling gave {missing} rather than an error naming Ghost`
	end

	local loaded: boolean, refusal: any = pcall(server.load, server, "Ghost")

	if loaded or not tostring(refusal):find("Ghost", 1, true) then
		return false, `Loading a module src lacks gave {refusal} rather than an error naming Ghost`
	end

	local double: { [string]: any } = {}
	server:substitute("Ghost", double)

	if not rawequal(Router.bind(), double) then
		return false, "The sibling's require gave something other than its double"
	end

	if not rawequal(server:load("Ghost"), double) then
		return false, "Loading the substituted module gave something other than its double"
	end

	return true, nil
end
