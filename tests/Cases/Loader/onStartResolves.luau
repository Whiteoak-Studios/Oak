--[[
    onStart asked for before the boot resolves once every Start has been
    spawned, not once each has finished, and asked for after the boot it
    resolves at once
--]]

--!strict
local task = require("@lune/task")

local Environment = require("../../Environment")
local Shop = require("../../Shop")

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", { prepare = function () end, bind = function () end })
	server:substitute("ClientProperty", {})

	local Oak: any = server:load("init")
	local network: any = server:network("Oak")
	local ran: { string } = {}

	local slow: any = server:module("SlowService", function (): any
		local created: any = Oak.create("SlowService", {})

		function created:Init() end
		function created:Start()
			table.insert(ran, "Slow begins")
			task.wait()
			table.insert(ran, "Slow ends")
		end

		return created
	end)

	local module: any = Shop(server, true, function (shop: any)
		function shop:Start()
			table.insert(ran, "Shop starts")
		end
	end)

	Oak.onStart():andThen(function ()
		table.insert(ran, "Resolved")
	end)

	local booted: boolean, refusal: any = pcall(Oak.start, { slow, module }, network)
	if not booted then
		return false, `The services failed the boot: {refusal}`
	end

	local order: string = table.concat(ran, ", ")

	if order ~= "Slow begins, Shop starts, Resolved" then
		return false, `The boot ran as {order}`
	end

	local late: boolean = false

	Oak.onStart():andThen(function ()
		late = true
	end)

	if not late then
		return false, "onStart asked for after the boot did not resolve at once"
	end

	return true, nil
end
