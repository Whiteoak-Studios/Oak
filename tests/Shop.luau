--[[
    The Shop namespace's owner a passing boot over Oak.volt needs, made as
    a ModuleScript in one realm: ShopService on the server, ShopController
    on a client, each built from the realm's own Oak when collect needs it
--]]

--!strict
local Environment = require("./Environment")

local RATE: number = 60 -- Messages a second each Policy row allows, more than any case sends in one

type Environment = Environment.Environment

--[[
    Makes the ModuleScript, named for its table. ShopService has a handler
    for buy, report and chat and a Policy row for those three and browse;
    ShopController connects confirm's handler in its Init. Either is made
    when collect first requires it, and edit, when given, changes the
    created table before it is returned

    @ env | the realm it is made in, whose init it loads; on a client, its Oak Network too
    @ server | true for ShopService, false for ShopController
    @ edit | runs on the created table, for a case that adds or takes away a member
    @ returns | the ModuleScript, unparented, for Oak.start's list or a parent the case sets
--]]

return function (env: Environment, server: boolean, edit: ((shop: any) -> ())?): any
	local name: string = server and "ShopService" or "ShopController"

	return env:module(name, function (): any
		local Oak: any = env:load("init")
		local shop: any

		if server then
			shop = Oak.create("ShopService", {
				Client = {},

				Policy = {
					buy = { rate = { perSecond = RATE } },
					report = { rate = { perSecond = RATE } },
					chat = { rate = { perSecond = RATE } },
					browse = { rate = { perSecond = RATE } },
				},
			})

			function shop.Client:buy(_: any, _: number): (boolean, string | nil)
				return true, nil
			end

			function shop.Client:report(_: any, _: string) end

			function shop.Client:chat(_: any, _: string) end

			function shop:Start() end
			function shop:Init() end
		else
			local Network: any = env:network("Oak")
			shop = Oak.create("ShopController", {})

			function shop:Start() end
			function shop.Init(_: any)
				Network.Shop.confirm.on(function (_: string): boolean
					return true
				end)
			end
		end

		if edit then
			edit(shop)
		end

		return shop
	end)
end
