--[[
    Tuning for ScoreService: the points every player sees until their own
    are set, and what each player's own points start at as they join
--]]

--!strict
return {
	startingPoints = 10, -- The Property's top value
	joinPoints = 50, -- Each player's own value, set as they join in place of the top value
}
