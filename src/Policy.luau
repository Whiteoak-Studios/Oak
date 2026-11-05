--[[
    Rates every inbound endpoint Oak binds: each owner's Policy rows pushed
    into the Network's rate once binding has checked them
--]]

--!strict
local Policy = {}

--[[
    Hands each Policy row to the Network's rate under its endpoint's
    registry name, its burst defaulting to its perSecond
--]]

function Policy.apply(network: any, owners: { [string]: any })
	for namespace: string, owner: any in owners do
		local rows: { [string]: any } = owner.Policy or {}

		for message: string, row: any in rows do
			local rate: { perSecond: number, burst: number? } = row.rate
			network.rate(`{namespace}.{message}`, rate.perSecond, rate.burst or rate.perSecond)
		end
	end
end

return Policy
