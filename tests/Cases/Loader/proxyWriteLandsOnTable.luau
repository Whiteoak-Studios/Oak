--[[
    A method called through a peer's proxy that writes through self
    writes the real table, as does a write made through the proxy itself,
    and the proxy keeps no field of its own
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

local LABEL: string = "Written" -- What a write through the proxy itself sets

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", { prepare = function () end, bind = function () end })
	server:substitute("ClientProperty", {})

	local Oak: any = server:load("init")
	local network: any = server:network("Oak")
	local counter: any = nil

	local trade: any = server:module("TradeService", function (): any
		return Oak.create("TradeService", {
			_counter = Oak.getService("CounterService"),
		})
	end)

	local counted: any = server:module("CounterService", function (): any
		counter = Oak.create("CounterService", { _count = 0 })

		function counter.bump(self: any)
			self._count += 1
		end

		return counter
	end)

	local booted: boolean, refusal: any = pcall(Oak.start, { Shop(server, true), trade, counted }, network)
	if not booted then
		return false, `The services failed the boot: {refusal}`
	end

	local proxy: any = Oak.getService("TradeService")._counter

	proxy:bump()
	proxy._label = LABEL

	if counter._count ~= 1 or counter._label ~= LABEL then
		return false, `Through the proxy the real table's count became {counter._count} and its label {counter._label}`
	end

	if rawget(proxy, "_count") ~= nil or rawget(proxy, "_label") ~= nil then
		return false, "A write through the proxy left a field on the proxy"
	end

	return true, nil
end
