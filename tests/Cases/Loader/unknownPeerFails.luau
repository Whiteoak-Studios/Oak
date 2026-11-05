--[[
    A peer asked for by a name no collected table has fails the boot at
    the end of collect, naming the name, before anything is bound
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

local TYPO: string = "DataServce" -- A misspelt peer, the mistake the check exists for

return function (): (boolean, string | nil)
	local bound: boolean = false

	local server = Environment.new()
	server:substitute("Failures", {
		bind = function ()
			bound = true
		end,
	})
	server:substitute("Property", { prepare = function () end, bind = function () end })
	server:substitute("ClientProperty", {})

	local Oak: any = server:load("init")
	local network: any = server:network("Oak")

	local trade: any = server:module("TradeService", function (): any
		local created: any = Oak.create("TradeService", {
			_data = Oak.getService(TYPO),
		})

		return created
	end)

	local booted: boolean, refusal: any = pcall(Oak.start, { Shop(server, true), trade }, network)

	if booted or not tostring(refusal):find(`asked for as {TYPO}`, 1, true) then
		return false, `An unknown peer gave {refusal} rather than a refusal naming it`
	end

	if bound then
		return false, "The boot went on to bind after collect found an unknown peer"
	end

	return true, nil
end
