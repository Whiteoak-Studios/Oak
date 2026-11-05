--[[
    The dev game's greeter on the client: asks the server for a greeting,
    sends more cheers in one frame than the server lets through, and prints
    each greeting the server announces
--]]

--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages
local Player = Players.LocalPlayer
local Client = Player.PlayerScripts.Client

local Oak = require(Packages.Oak)

local Network = require(ReplicatedStorage.Shared.Network.Client)

local ScoreController: typeof(require("@Controllers/Features/ScoreController")) = Oak.getController("ScoreController")

local CHEERS: number = require(Client.Config.Greeter).cheers

local Controller = Oak.create("GreeterController", {
	_cheered = 0, -- Cheers sent, each numbered by this count
	_heard = 0, -- Greetings the server has announced to us
})

--[[
    Sends every cheer in one frame, more than the server's Policy row lets
    through, so the rest are rate failures for GreeterService.onFailure
--]]

function Controller.cheer(self: Self)
	for _ = 1, CHEERS do
		self._cheered += 1
		Network.Greeter.cheer.fire(self._cheered)
	end
end

function Controller.Start(self: Self)
	print(`GreeterController: Start, asking for a greeting and sending {CHEERS} cheers`)

	Network.Greeter.greet
		.invoke(Player.Name)
		:andThen(function (ok: boolean, reply: string?)
			local points: number? = ScoreController.points:Get()
			print(`GreeterController: greet answered {ok}, "{reply}", and we hold {points} points`)
		end)
		:catch(function (reason: string)
			print(`GreeterController: greet failed: {reason}`)
		end)

	self:cheer()
end

function Controller.Init(self: Self)
	-- Lives for the whole client session, so it keeps no disconnect
	Network.Greeter.greeted.on(function (name: string, count: number)
		self._heard += 1
		print(`GreeterController: the server greeted {name}, its greeting {count}, and we have heard {self._heard}`)
	end)

	print(`GreeterController: Init`)
end

type Self = typeof(Controller)

return Controller
