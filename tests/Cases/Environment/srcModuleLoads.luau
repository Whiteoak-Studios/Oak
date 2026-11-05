--[[
    A module mounted in src loads as Wally installs it, with or without a
    src/init.luau: its realm, task and debug, and Promise and Volt one
    level above its folder, loaded once in each environment and then kept
--]]

--!strict
local fs = require("@lune/fs")

local Environment = require("../../Environment")
local Volt = require("@volt")

local ROOT_FILE: string = "src/init.luau" -- Without it, src mounts as a Folder rather than a ModuleScript

local SOURCE: string = [[
local RunService = game:GetService("RunService")
local Promise: any = require(script.Parent.Parent.Promise)
local Volt = require(script.Parent.Parent.Volt)

local spawned: boolean = false
task.spawn(function ()
	spawned = true
end)

debug.setmemorycategory("Stub")
debug.resetmemorycategory()

return {
	server = RunService:IsServer(),
	client = RunService:IsClient(),
	studio = RunService:IsStudio(),
	spawned = spawned,
	resolved = Promise.resolve(true):expect(),
	version = Volt.version,
	parent = script.Parent,
	traceback = debug.traceback("Stub"),
}
]]

return function (): (boolean, string | nil)
	local folderClass: string = fs.isFile(ROOT_FILE) and "ModuleScript" or "Folder"

	local server = Environment.new()
	local _, transport = server.mock:join("Player")
	local client = server:client(transport)

	server:mount("Stub", SOURCE)
	client:mount("Stub", SOURCE)

	local onServer: any = server:load("Stub")
	local onClient: any = client:load("Stub")

	if not (onServer.server and not onServer.client and not onServer.studio) then
		return false, `The server's RunService answered IsServer {onServer.server}, IsClient {onServer.client}`
	end

	if not (onClient.client and not onClient.server and not onClient.studio) then
		return false, `The client's RunService answered IsServer {onClient.server}, IsClient {onClient.client}`
	end

	if not (onServer.spawned and onServer.resolved) then
		return false, `task.spawn ran {onServer.spawned}, and a resolved Promise gave {onServer.resolved}`
	end

	if onServer.version ~= Volt.version then
		return false, `script.Parent.Parent.Volt gave version {onServer.version}, not {Volt.version}`
	end

	if onServer.parent.Name ~= "oak" or onServer.parent.ClassName ~= folderClass then
		return false, `The stub sat in {onServer.parent.ClassName} {onServer.parent.Name}, not {folderClass} oak`
	end

	if type(onServer.traceback) ~= "string" then
		return false, `debug.traceback gave {onServer.traceback}, so the rest of Lune's debug is missing`
	end

	if not rawequal(server:load("Stub"), onServer) then
		return false, "A second load of one module ran it again rather than keeping its return"
	end

	return true, nil
end
