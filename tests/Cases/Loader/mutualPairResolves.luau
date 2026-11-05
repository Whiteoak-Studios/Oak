--[[
    Two services that name each other through getService both collect,
    with no require cycle, and each reaches the other's table through its
    proxy, in Start and after the boot alike
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", { prepare = function () end, bind = function () end })
	server:substitute("ClientProperty", {})

	local Oak: any = server:load("init")
	local network: any = server:network("Oak")
	local heard: { [string]: string } = {}

	-- Each body names the other, which collect has not required yet when the first body runs
	local function pair(name: string, other: string, label: string): any
		return server:module(name, function (): any
			local Other: any = Oak.getService(other)
			local created: any = Oak.create(name, { label = label })

			function created.partner(_: any): string
				return Other.label
			end

			function created:Init() end
			function created.Start(self: any)
				heard[name] = self:partner()
			end

			return created
		end)
	end

	local list: { any } = { Shop(server, true), pair("AService", "BService", "a"), pair("BService", "AService", "b") }

	local booted: boolean, refusal: any = pcall(Oak.start, list, network)
	if not booted then
		return false, `A mutual pair failed the boot: {refusal}`
	end

	if heard.AService ~= "b" or heard.BService ~= "a" then
		return false, `In Start, AService heard {heard.AService} and BService {heard.BService}`
	end

	if Oak.getService("AService"):partner() ~= "b" or Oak.getService("BService"):partner() ~= "a" then
		return false, "After the boot a peer's proxy did not reach the other table"
	end

	return true, nil
end
