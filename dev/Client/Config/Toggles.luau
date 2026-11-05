--[[
    The Workspace attributes the live check sets in Edit mode before Play,
    each turning one of the client bootstrap's failure modes on
--]]

--!strict
return {
	staleClient = "OakDevStaleClient", -- Boots on Stale.volt's client module, whose handshake the server refuses
}
