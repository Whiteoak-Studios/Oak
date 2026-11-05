--[[
    The dev game's greeter: answers a client's greeting with points from
    ScoreService and an announcement to everyone, counts the cheers its
    Policy row lets through and prints every Volt failure on Greeter
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Packages = ReplicatedStorage.Packages

local Oak = require(Packages.Oak)
local Volt = require(Packages.Volt)

local Network = require(ReplicatedStorage.Shared.Network.Server)

local ScoreService: typeof(require("@Services/Features/ScoreService")) = Oak.getService("ScoreService")

local CHEER_BURST: number = require(ServerScriptService.Server.Config.Greeter).cheerBurst
local CHEER_RATE: number = require(ServerScriptService.Server.Config.Greeter).cheerRate
local GREET_BURST: number = require(ServerScriptService.Server.Config.Greeter).greetBurst
local GREET_POINTS: number = require(ServerScriptService.Server.Config.Greeter).greetPoints
local GREET_RATE: number = require(ServerScriptService.Server.Config.Greeter).greetRate

type Bot = Volt.Bot

local Service = Oak.create("GreeterService", {
	Client = {},

	Policy = {
		greet = { rate = { perSecond = GREET_RATE, burst = GREET_BURST } },
		cheer = { rate = { perSecond = CHEER_RATE, burst = CHEER_BURST } },
	},

	_greeted = 0, -- Greetings answered on this server
	_cheers = 0, -- Cheers the Policy row let through on this server
})

--[[
    Greets a player by the name their client sent, awards them points for
    it and tells every player who was greeted
--]]

function Service.greet(self: Self, player: Player, name: string): (boolean, string | nil)
	self._greeted += 1
	ScoreService:award(player, GREET_POINTS)
	Network.Greeter.greeted.fireAll(name, self._greeted)

	return true, `Hello, {name}! That's greeting {self._greeted} on this server`
end

function Service.Client:greet(player: Player, name: string): (boolean, string | nil)
	return (Service :: Self):greet(player, name)
end

--[[
    Counts a cheer the Policy row let through
--]]

function Service.cheer(self: Self, player: Player, cheer: number)
	self._cheers += 1
	print(`GreeterService: cheer {cheer} from {player.Name} got through, {self._cheers} so far`)
end

function Service.Client:cheer(player: Player, cheer: number)
	return (Service :: Self):cheer(player, cheer)
end

--[[
    Every Volt failure on a Greeter message lands here instead of Volt's
    default, the cheers past the Policy row's burst among them
--]]

function Service.onFailure(player: Player | Bot, kind: string, detail: string)
	print(`GreeterService.onFailure: {kind} failure from {player.Name}: {detail}`)
end

function Service.Start(self: Self)
	print(`GreeterService: Start, {self._greeted} greetings answered so far`)
end

function Service.Init(self: Self)
	local burst: number = self.Policy.cheer.rate.burst
	local perSecond: number = self.Policy.cheer.rate.perSecond

	print(`GreeterService: Init, cheer lets {burst} through at once and {perSecond} a second after`)
end

type Self = typeof(Service)

return Service
