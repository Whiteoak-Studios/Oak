--[[
    The dev game's points on the client: prints every value the server's
    Property sends, and answers the server when it checks what we hold
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages

local Oak = require(Packages.Oak)

local Network = require(ReplicatedStorage.Shared.Network.Client)

local Controller = Oak.create("ScoreController", {
	points = Oak.Property(Network.Score.points), -- This player's points, as the server last sent them
})

function Controller.Start(self: Self)
	print(`ScoreController: Start, a points value has arrived: {self.points:IsReady()}`)
end

function Controller.Init(self: Self)
	-- Both live for the whole client session, so neither keeps a disconnect
	self.points:Observe(function (points: number)
		print(`ScoreController: points are now {points}`)
	end)

	Network.Score.check.on(function (points: number): boolean
		return self.points:Get() == points
	end)

	print(`ScoreController: Init`)
end

type Self = typeof(Controller)

return Controller
