--[[
    A namespace in the Network that no started table owns fails the boot,
    naming it: on the server with no service, on the client with no
    controller
--]]

--!strict
local Environment = require("../../Environment")

return function (): (boolean, string | nil)
	local server = Environment.new()
	local serverNetwork: any = server:network("Orphan")
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", { prepare = function () end, bind = function () end })
	server:substitute("ClientProperty", {})

	local _, transport = server.mock:join("Player")
	local client = server:client(transport)
	local clientNetwork: any = client:network("Orphan")
	client:substitute("Failures", { bind = function () end })
	client:substitute("Property", {})
	client:substitute("ClientProperty", {})

	local served: boolean, serverRefusal: any = pcall(server:load("init").start, {}, serverNetwork)
	if served or not tostring(serverRefusal):find("namespace Orphan has no started service", 1, true) then
		return false, `An unowned namespace on the server gave {serverRefusal}`
	end

	local reached: boolean, clientRefusal: any = pcall(client:load("init").start, {}, clientNetwork)
	if reached or not tostring(clientRefusal):find("namespace Orphan has no started controller", 1, true) then
		return false, `An unowned namespace on the client gave {clientRefusal}`
	end

	return true, nil
end
