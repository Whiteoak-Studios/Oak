--[[
    Oak.Property makes the server half on the server, with the handle and
    the default, and the client's shared object on a client, with the
    handle alone, each reading its realm when it is called
--]]

--!strict
local Environment = require("../../Environment")

local DEFAULT: number = 5 -- The server's starting top value

return function (): (boolean, string | nil)
	local made: { string } = {}

	local server = Environment.new()
	local serverNetwork: any = server:network("Oak")
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", {
		new = function (handle: any, default: any): any
			table.insert(made, "server")
			return { handle = handle, default = default }
		end,
	})
	server:substitute("ClientProperty", {
		new = function (): any
			table.insert(made, "client on the server")
			return {}
		end,
	})

	local _, transport = server.mock:join("Player")
	local client = server:client(transport)
	local clientNetwork: any = client:network("Oak")
	client:substitute("Failures", { bind = function () end })
	client:substitute("Property", {
		new = function (): any
			table.insert(made, "server on the client")
			return {}
		end,
	})
	client:substitute("ClientProperty", {
		new = function (handle: any, extra: any): any
			table.insert(made, extra == nil and "client" or "client given a default")
			return { handle = handle }
		end,
	})

	local onServer: any = server:load("init").Property(serverNetwork.Shop.coins, DEFAULT)
	local onClient: any = client:load("init").Property(clientNetwork.Shop.coins)

	if table.concat(made, ", ") ~= "server, client" then
		return false, `Oak.Property made {table.concat(made, ", ")}`
	end

	if onServer.handle ~= serverNetwork.Shop.coins or onServer.default ~= DEFAULT then
		return false, `The server half was made with {onServer.handle} and {onServer.default}`
	end

	if onClient.handle ~= clientNetwork.Shop.coins then
		return false, `The client's object was made with {onClient.handle}`
	end

	return true, nil
end
