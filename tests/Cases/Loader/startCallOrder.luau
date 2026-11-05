--[[
    The server boot calls into its siblings and the Network in the fixed
    order: prepare, collect, the rates, Failures, the handlers, the
    Property's bind, every Init, then every Start
--]]

--!strict
local Environment = require("../../Environment")
local Shop = require("../../Shop")

local ORDER: string = "prepare, collect, rate, failures, connect, property, init, start" -- Each step once, in turn

return function (): (boolean, string | nil)
	local steps: { string } = {}

	-- One entry per step, so a step that calls several times shows once
	local function step(name: string)
		if steps[#steps] ~= name then
			table.insert(steps, name)
		end
	end

	local server = Environment.new()
	local real: any = server:network("Oak")
	local failed: { any } = {}

	-- The Network as the boot sees it: rate and each Shop handle's on noted, everything else the real module's
	local network: any = setmetatable({
		rate = function (name: string, perSecond: number, burst: number?)
			step("rate")
			real.rate(name, perSecond, burst)
		end,

		Shop = setmetatable({}, {
			__index = function (_: any, message: string): any
				local handle: any = real.Shop[message]

				return setmetatable({
					on = function (listener: (...any) -> ...any): () -> ()
						step("connect")
						return handle.on(listener)
					end,
				}, { __index = handle })
			end,
		}),
	}, { __index = real })

	server:substitute("Failures", {
		bind = function (...: any)
			step("failures")
			failed = { ... }
		end,
	})
	server:substitute("Property", {
		prepare = function ()
			step("prepare")
		end,
		bind = function ()
			step("property")
		end,
	})
	server:substitute("ClientProperty", {})

	local Oak: any = server:load("init")
	local shop: any = nil

	local module: any = Shop(server, true, function (created: any)
		shop = created
		step("collect")

		function created:Init()
			step("init")
		end

		function created:Start()
			step("start")
		end
	end)

	local booted: boolean, refusal: any = pcall(Oak.start, { module }, network)
	if not booted then
		return false, `ShopService failed the boot: {refusal}`
	end

	local order: string = table.concat(steps, ", ")
	if order ~= ORDER then
		return false, `The boot ran {order} rather than {ORDER}`
	end

	if failed[1] ~= network or not rawequal(failed[2].Shop, shop) or failed[3] ~= true then
		return false, "Failures.bind was not given the Network, the owners by namespace and the server's realm"
	end

	return true, nil
end
