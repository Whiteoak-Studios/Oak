--[[
    Boots the dev place's client over the dev game's network module, or with
    the stale client toggle set, over Stale.volt's client module alone, whose
    handshake the server refuses with Volt's default kick
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local packages = ReplicatedStorage.Packages

local Oak = require(packages.Oak)

local STALE_TOGGLE: string = require(script.Config.Toggles).staleClient

-- No controller is collected here: one requiring the real module would start a second runtime on the scope,
-- whose handshake could reach the server first. So this boot refuses too, naming each namespace it leaves unowned
if Workspace:GetAttribute(STALE_TOGGLE) == true then
	return Oak.start({}, require(ReplicatedStorage.Shared.Network.Stale.Client))
end

local Network = require(ReplicatedStorage.Shared.Network.Client) -- Volt-generated, the dev game's module set

Oak.start(script.Services, Network)

Oak.onStart()
	:andThen(function ()
		print(`Client: Oak.onStart resolved, every Start is spawned`)
	end)
	:catch(error)
