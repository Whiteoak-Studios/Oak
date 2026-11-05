--[[
    On the client, a function the server calls that still has no handler
    once every Init has run fails the boot before any Start, naming the
    function and the controller that owns its namespace
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:network("Oak")

	local _, transport = server.mock:join("Player")
	local client = server:client(transport)
	local network: any = client:network("Oak")
	client:substitute("Failures", { bind = function () end })
	client:substitute("Property", {})
	client:substitute("ClientProperty", {})

	local Oak: any = client:load("init")
	local initialised: boolean = false
	local started: boolean = false

	local module: any = Shop(client, false, function (shop: any)
		function shop:Init()
			initialised = true
		end

		function shop:Start()
			started = true
		end
	end)

	local booted: boolean, refusal: any = pcall(Oak.start, { module }, network)
	local message: string = tostring(refusal)

	if
		booted or not (message:find("Shop.confirm has no handler", 1, true) and message:find("ShopController", 1, true))
	then
		return false, `A missing confirm handler gave {refusal} rather than a refusal naming it and its controller`
	end

	if not initialised or started then
		return false, `The check ran with Init run {initialised} and Start run {started}`
	end

	return true, nil
end
