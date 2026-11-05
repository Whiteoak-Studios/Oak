--[[
    Several binding problems in one boot are reported in one error, so one
    review round fixes them all: a missing handler, a missing Policy row,
    a stray handler and two tables giving one namespace
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

local PROBLEMS: { string } = {
	"Shop.buy has no handler in ShopService.Client",
	"Shop.browse has no Policy row in ShopService",
	"ShopService.Client.refund is a handler with no inbound declaration in Shop",
	"InventoryController and InventoryService both give the namespace Inventory",
}

return function (): (boolean, string | nil)
	local server = Environment.new()
	server:substitute("Failures", { bind = function () end })
	server:substitute("Property", { prepare = function () end, bind = function () end })
	server:substitute("ClientProperty", {})

	local Oak: any = server:load("init")
	local network: any = server:network("Oak")

	local list: { any } = {
		Shop(server, true, function (shop: any)
			shop.Client.buy = nil
			shop.Policy.browse = nil

			function shop.Client:refund() end
		end),
	}

	for _, name: string in { "InventoryService", "InventoryController" } do
		table.insert(
			list,
			server:module(name, function (): any
				return Oak.create(name, {})
			end)
		)
	end

	local booted: boolean, refusal: any = pcall(Oak.start, list, network)
	local message: string = tostring(refusal)

	for _, problem: string in PROBLEMS do
		if booted or not message:find(problem, 1, true) then
			return false, `The boot's refusal left out "{problem}": {message}`
		end
	end

	return true, nil
end
