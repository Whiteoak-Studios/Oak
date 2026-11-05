--[[
    Boots the dev place's server over the dev game's network module: the
    whole Services tree, or with the unowned namespace toggle set, a list
    that leaves the Greeter namespace without its service, which Oak refuses
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local packages = ReplicatedStorage.Packages

local Oak = require(packages.Oak)

local Network = require(ReplicatedStorage.Shared.Network.Server) -- Volt-generated, the dev game's module set

local UNOWNED_TOGGLE: string = require(script.Config.Toggles).unownedNamespace

-- The list leaves out GreeterService, and no service names it as a peer, so only the binding check refuses it
if Workspace:GetAttribute(UNOWNED_TOGGLE) == true then
	Oak.start({ script.Services.Features.ScoreService }, Network)
else
	Oak.start(script.Services, Network)
end

Oak.onStart()
	:andThen(function ()
		print(`Server: Oak.onStart resolved, every Start is spawned`)
	end)
	:catch(error)
