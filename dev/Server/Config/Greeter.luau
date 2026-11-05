--[[
    Tuning for GreeterService: the rates its Policy rows hand to Volt, and
    the points a greeting awards
--]]

--!strict
return {
	greetRate = 2, -- Greetings a second a player can keep up
	greetBurst = 2, -- Greetings a player can make back to back after a pause
	cheerRate = 1, -- Cheers a second a player can keep up
	cheerBurst = 2, -- Cheers a player can send back to back, fewer than the client sends at once
	greetPoints = 5, -- Points a greeting awards
}
