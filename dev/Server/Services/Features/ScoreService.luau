--[[
    The dev game's points: a Property every player sees, an override set for
    each player as they join, and the points a greeting awards
--]]

--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Packages = ReplicatedStorage.Packages

local Oak = require(Packages.Oak)

local Network = require(ReplicatedStorage.Shared.Network.Server)

local JOIN_POINTS: number = require(ServerScriptService.Server.Config.Score).joinPoints
local STARTING_POINTS: number = require(ServerScriptService.Server.Config.Score).startingPoints

local Service = Oak.create("ScoreService", {
	Client = {
		points = Oak.Property(Network.Score.points, STARTING_POINTS), -- Each player's points, replayed on join
	},
})

--[[
    Adds points to what a player sees now and sends them the new total
--]]

function Service.award(self: Self, player: Player, points: number)
	local total: number = self.Client.points:GetFor(player) + points
	self.Client.points:SetFor(player, total)

	print(`ScoreService: awarded {player.Name} {points} points, {total} in all`)
end

--[[
    Sets a joining player's own points, then asks their client whether it
    holds the value GetFor reads, printing both
--]]

function Service._welcome(self: Self, player: Player)
	self.Client.points:SetFor(player, JOIN_POINTS)

	local held: number = self.Client.points:GetFor(player)
	print(`ScoreService: SetFor({player.Name}, {JOIN_POINTS}), and GetFor now reads {held}`)

	Network.Score.check
		.invoke(player, held)
		:andThen(function (holds: boolean)
			print(`ScoreService: {player.Name}'s client holds {held} points: {holds}`)
		end)
		:catch(function (reason: string)
			print(`ScoreService: {player.Name}'s client gave no answer to check: {reason}`)
		end)
end

function Service.Start(self: Self)
	print(`ScoreService: Start`)

	-- A player who joined before Init connected PlayerAdded is welcomed here instead
	for _, player: Player in Players:GetPlayers() do
		print(`ScoreService: {player.Name} joined before Init, so Start welcomes them`)
		self:_welcome(player)
	end
end

function Service.Init(self: Self)
	self.Client.points:SetTop(STARTING_POINTS)

	-- Lives as long as the server
	Players.PlayerAdded:Connect(function (player: Player)
		print(`ScoreService: PlayerAdded for {player.Name}`)
		self:_welcome(player)
	end)

	print(`ScoreService: Init, the top value is {self.Client.points:Get()}`)
end

type Self = typeof(Service)

return Service
