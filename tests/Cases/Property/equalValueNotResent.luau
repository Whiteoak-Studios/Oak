--[[
    An equal number, string or boolean is not sent again, false and nil
    kept apart; a buffer is compared by its bytes against Oak's own copy,
    so one changed in place and set again is sent
--]]

--!strict
local Environment = require("../../Environment")

local START: number = 250 -- The coin balance Alice is sent on joining
local COINS: number = 400 -- A new balance, then set again
local GREETING: string = "Hello" -- A chat line, then set again
local BYTES: string = "ab" -- The bytes the buffer Property starts with
local CHANGED: number = 7 -- The byte written into the buffer in place

return function (): (boolean, string | nil)
	local server = Environment.new()
	local network: any = server:network("Oak")
	local Property: any = server:load("Property")

	Property.prepare(network)
	local coins: any = Property.new(network.Shop.coins, START)
	local chat: any = Property.new(network.Shop.chat, "")
	Property.bind(network)

	local alice, transport = server.mock:join("Alice")
	local clientNetwork: any = server:client(transport):network("Oak")
	local coinsHeard: { number } = {}
	local chatHeard: { string } = {}

	clientNetwork.Shop.coins.on(function (value: number)
		table.insert(coinsHeard, value)
	end)

	clientNetwork.Shop.chat.on(function (value: string)
		table.insert(chatHeard, value)
	end)

	server:step(Environment.HELD)

	local replayed: number = #chatHeard -- The join replay of the empty default line

	coins:SetTop(START)
	coins:SetTop(COINS)
	coins:SetTop(COINS)
	coins:SetFor(alice, COINS)
	chat:SetTop(GREETING)
	chat:SetTop(GREETING)
	chat:SetFor(alice, GREETING)
	server:step(Environment.DELIVERY)

	if table.concat(coinsHeard, " ") ~= `{START} {COINS}` then
		return false, `Equal numbers were sent again: Alice heard {table.concat(coinsHeard, " ")}`
	end

	if #chatHeard ~= replayed + 1 or chatHeard[#chatHeard] ~= GREETING then
		return false, `Equal strings were sent again: Alice heard {#chatHeard - replayed} lines after joining`
	end

	-- No event in the schema carries a boolean or a buffer, so these count what reaches handles of the case's own
	local sends: number = 0
	local function count()
		sends += 1
	end

	local flag: any = Property.new({ fire = count, fireList = count, fireSet = count }, false)

	flag:SetTop(false)

	if sends ~= 0 then
		return false, `An equal false was sent {sends} times`
	end

	local changes: number = 3 -- false to nil, nil to false and false to true, each set twice
	flag:SetTop(nil)
	flag:SetTop(nil)
	flag:SetTop(false)
	flag:SetTop(false)
	flag:SetTop(true)
	flag:SetTop(true)

	if sends ~= changes then
		return false, `Moving between false, nil and true sent {sends} times rather than {changes}`
	end

	sends = 0

	local bytes: buffer = buffer.fromstring(BYTES)
	local packet: any = Property.new({ fire = count, fireList = count, fireSet = count }, bytes)

	packet:SetTop(buffer.fromstring(BYTES))

	if sends ~= 0 then
		return false, "A buffer with the same bytes was sent as though changed"
	end

	buffer.writeu8(bytes, 0, CHANGED)
	packet:SetTop(bytes)
	packet:SetTop(bytes)

	if sends ~= 1 then
		return false, `A buffer changed in place and set twice was sent {sends} times rather than once`
	end

	return true, nil
end
