--[[
    The server half of Oak.Property: one event's top value and per-player
    overrides, each sent only when it changes, replayed to every joiner and
    resent after Volt reports a drop
--]]

--!strict
local Property = {}
Property.__index = Property

local Volt = require(script.Parent.Parent.Volt)

type Bot = Volt.Bot

export type ServerEvent<T> = {
	fire: (player: Player | Bot, value: T) -> (),
	fireAll: (value: T) -> (),
	fireList: (players: { Player | Bot }, value: T) -> (),
	fireExcept: (player: Player | Bot, value: T) -> (),
	fireSet: (players: { [Player | Bot]: true }, value: T) -> (),
}

type Override<T> = {
	value: T, -- What the player sees in place of the top value
	sent: T, -- Oak's copy of what the player last received
}

type Fields<T> = {
	_handle: ServerEvent<T>,
	_top: T, -- What every player without an override sees
	_sent: T, -- Oak's copy of the top value last sent, which every player without an override holds
	_overrides: { [Player | Bot]: Override<T> },
	_stale: { [Player | Bot]: true }, -- Players a drop left Oak unsure of, so their next set goes out whatever it equals
}

-- Where a player stands with the handshake, from Volt's joined callback until its left one
type Joiner = {
	handshaken: boolean, -- Set once Volt accepts their handshake, so a drop after it is told from one before
	waiting: boolean, -- A drop before the handshake left a resend of every value waiting on it
}

local Properties: { Self<any> } = {} -- Every server Property, made before or after bind
local Joined: { [Player | Bot]: Joiner } = {} -- Every player and bot Volt has set up and not yet let go
local Network: any = nil -- The game's Network, which prepare keeps

--[[
    A copy Oak owns of a value it sends: a buffer byte for byte, a table
    field by field at every depth, and anything else as it is
--]]

local function deepCopy(value: any): any
	if type(value) == "buffer" then
		local copied: buffer = buffer.create(buffer.len(value))
		buffer.copy(copied, 0, value)

		return copied
	end

	if type(value) ~= "table" then
		return value
	end

	local copied: { [any]: any } = {}
	for key: any, field: any in value do
		copied[key] = deepCopy(field)
	end

	return copied
end

--[[
    Whether two values send the same: buffers by their bytes, since == on
    a buffer compares identity, tables by every field at every depth, and
    anything else with ==
--]]

local function deepEqual(first: any, second: any): boolean
	if type(first) == "buffer" and type(second) == "buffer" then
		return buffer.tostring(first) == buffer.tostring(second)
	end

	if type(first) ~= "table" or type(second) ~= "table" then
		return first == second
	end

	for key: any, field: any in first do
		if not deepEqual(field, second[key]) then
			return false
		end
	end

	-- A key only the second holds
	for key: any in second do
		if first[key] == nil then
			return false
		end
	end

	return true
end

--[[
    Keeps the game's Network, read for the registry name a second Property
    on one event is named by, and to tell a bot from a player
--]]

function Property.prepare(network: any)
	Network = network
end

-- The registry name the Network gives a handle, or nil before prepare or for a handle it does not hold
local function nameOf(handle: any): string?
	if not Network then
		return nil
	end

	for name: string, event: any in Network.events do
		if event == handle then
			return name
		end
	end

	return nil
end

--- @class Property
--- The server half of `Oak.Property`, which a service's `Client` table
--- holds: the value every player sees, the override each player may have
--- in its place, and a copy of what each was last sent, so a value equal
--- to it is not sent again

--- Makes the server half of a Property over one event, its value starting
--- as `default` for every player. It sends nothing until a set or a join.
--- An event carries one server Property, so a second on the same event
--- errors at the line that made it, naming the event.
--- @function new
--- @within Property
--- @param handle ServerEvent<T> -- A `from: Server` event in the game's Network
--- @param default T -- The top value every player sees until a set changes it
--- @return Property<T>

function Property.new<T>(handle: ServerEvent<T>, default: T): Self<T>
	local level: number = 3 -- The game's line, which called Oak.Property, which called this

	for _, property: Self<any> in Properties do
		if property._handle == handle then
			error(`Oak.Property was given {nameOf(handle) or "an event"}, which already has a server Property`, level)
		end
	end

	local self: Self<T> = setmetatable({
		_handle = handle,
		_top = default,
		_sent = deepCopy(default),
		_overrides = {} :: { [Player | Bot]: Override<T> },
		_stale = {} :: { [Player | Bot]: true },
	}, Property)

	table.insert(Properties, self)

	return self
end

--- Sets the top value, which every player without an override sees, and
--- sends it to them in one broadcast when it differs from what they were
--- last sent. A player with an override keeps it.
--- @method SetTop
--- @within Property
--- @param value T -- The new top value

function Property.SetTop<T>(self: Self<T>, value: T)
	self:_broadcast(value, self:_targets(value))
end

--- Sets the top value and drops every override, so every player sees it,
--- sending it in one broadcast to each player whose last value differs.
--- @method Set
--- @within Property
--- @param value T -- The new value for every player

function Property.Set<T>(self: Self<T>, value: T)
	local targets: { [Player | Bot]: true } = self:_targets(value)

	-- A player losing an override is sent the value unless what they hold already equals it
	for player: Player | Bot in self._overrides do
		if not self:_holds(player, value) then
			targets[player] = true
		end
	end

	table.clear(self._overrides)
	self:_broadcast(value, targets)
end

--- Overrides one player's value, sending it to them when it differs from
--- what they were last sent. A player who has left is ignored, so a call
--- that comes late leaves nothing behind.
--- @method SetFor
--- @within Property
--- @param player Player | Bot -- The player or test bot to override
--- @param value T -- What they see in place of the top value

function Property.SetFor<T>(self: Self<T>, player: Player | Bot, value: T)
	self:SetForList({ player }, value)
end

--- Overrides each listed player's value with one value, sent in one
--- broadcast to those whose last value differs. A player who has left is
--- ignored.
--- @method SetForList
--- @within Property
--- @param players { Player | Bot } -- The players or test bots to override
--- @param value T -- What they see in place of the top value

function Property.SetForList<T>(self: Self<T>, players: { Player | Bot }, value: T)
	local sent: T = deepCopy(value) -- One copy every listed player shares, since Oak never writes into one
	local targets: { Player | Bot } = {}

	for _, player: Player | Bot in players do
		-- A player who has left keeps no entry, however late the call
		if not Joined[player] then
			continue
		end

		if not self:_holds(player, value) then
			table.insert(targets, player)
			self._stale[player] = nil
		end

		self._overrides[player] = { value = value, sent = sent }
	end

	if #targets > 0 then
		self._handle.fireList(targets, value)
	end
end

--- Puts one player back on the top value, sending it to them when it
--- differs from what they were last sent.
--- @method ClearFor
--- @within Property
--- @param player Player | Bot -- The player or test bot whose override goes

function Property.ClearFor<T>(self: Self<T>, player: Player | Bot)
	self:ClearForList({ player })
end

--- Puts each listed player back on the top value, sent in one broadcast to
--- those whose last value differs. A player with no override is left as
--- they are.
--- @method ClearForList
--- @within Property
--- @param players { Player | Bot } -- The players or test bots whose overrides go

function Property.ClearForList<T>(self: Self<T>, players: { Player | Bot })
	local targets: { Player | Bot } = {}

	for _, player: Player | Bot in players do
		if not self._overrides[player] then
			continue
		end

		if not self:_holds(player, self._sent) then
			table.insert(targets, player)
			self._stale[player] = nil
		end

		self._overrides[player] = nil
	end

	if #targets > 0 then
		self._handle.fireList(targets, self._top)
	end
end

--- Sends the value a player sees again even when it is unchanged, to one
--- player or, given none, to every player: for a client that asks to
--- reload, or wherever the check that skips an unchanged value must be
--- overridden.
--- @method Refresh
--- @within Property
--- @param player (Player | Bot)? -- The one player or test bot to send to, or nil for every one

function Property.Refresh<T>(self: Self<T>, player: (Player | Bot)?)
	if player then
		if Joined[player] then
			self:_send(player)
		end

		return
	end

	-- Each player with an override on their own, and every other in one broadcast
	local targets: { [Player | Bot]: true } = {}

	for joiner: Player | Bot in Joined do
		if self._overrides[joiner] then
			self:_send(joiner)
		else
			targets[joiner] = true
		end
	end

	self:_broadcast(self._top, targets)
end

--- The top value, which every player without an override sees.
--- @method Get
--- @within Property
--- @return T -- The top value

function Property.Get<T>(self: Self<T>): T
	return self._top
end

--- The value one player sees now: their override, or the top value.
--- @method GetFor
--- @within Property
--- @param player Player | Bot -- The player or test bot to read for
--- @return T -- Their override, or the top value when they have none

function Property.GetFor<T>(self: Self<T>, player: Player | Bot): T
	local override: Override<T>? = self._overrides[player]
	if override then
		return override.value
	end

	return self._top
end

-- Whether a player holds a value equal to this one, by Oak's copy of what they were last sent
function Property._holds<T>(self: Self<T>, player: Player | Bot, value: T): boolean
	if self._stale[player] then
		return false
	end

	local override: Override<T>? = self._overrides[player]
	if override then
		return deepEqual(override.sent, value)
	end

	return deepEqual(self._sent, value)
end

--[[
    Every player without an override who may not hold the value: all of
    them when it differs from the top copy, otherwise only those a drop
    left Oak unsure of
--]]

function Property._targets<T>(self: Self<T>, value: T): { [Player | Bot]: true }
	local changed: boolean = not deepEqual(self._sent, value)
	local targets: { [Player | Bot]: true } = {}

	for player: Player | Bot in Joined do
		if not self._overrides[player] and (changed or self._stale[player]) then
			targets[player] = true
		end
	end

	return targets
end

--[[
    Makes value the top value, sent in one broadcast to the players given,
    and keeps a copy of it as what every player without an override holds
--]]

function Property._broadcast<T>(self: Self<T>, value: T, targets: { [Player | Bot]: true })
	if next(targets) then
		self._handle.fireSet(targets, value)
	end

	for player: Player | Bot in targets do
		self._stale[player] = nil
	end

	self._top = value
	self._sent = deepCopy(value)
end

-- Sends a player the value they see, whatever they were last sent, and records it as what they hold
function Property._send<T>(self: Self<T>, player: Player | Bot)
	local override: Override<T>? = self._overrides[player]
	self._stale[player] = nil

	if not override then
		self._handle.fire(player, self._top)
		return
	end

	override.sent = deepCopy(override.value)
	self._handle.fire(player, override.value)
end

--[[
    Subscribes every Property, made before or after this, to the Network's
    player callbacks: a joiner is sent each value, a leaver's entries go,
    and an accepted handshake sends what a drop left waiting on it. The
    three live as long as the server, so their disconnects are dropped
--]]

function Property.bind(network: any)
	network.onJoin(function (player: Player | Bot)
		Joined[player] = { handshaken = false, waiting = false }

		for _, property: Self<any> in Properties do
			property:Refresh(player)
		end
	end)

	network.onLeave(function (player: Player | Bot)
		Joined[player] = nil

		for _, property: Self<any> in Properties do
			property._overrides[player] = nil
			property._stale[player] = nil
		end
	end)

	network.onHandshake(function (player: Player | Bot)
		local joiner: Joiner? = Joined[player]
		if not joiner then
			return
		end

		joiner.handshaken = true

		if not joiner.waiting then
			return
		end

		joiner.waiting = false

		for _, property: Self<any> in Properties do
			property:Refresh(player)
		end
	end)
end

--[[
    Forgets what every Property last sent a player once Volt drops a
    message to them, so the next set to reach them goes out whatever it
    equals, and a drop before their handshake leaves a resend waiting on
    it. Volt calls this inside its own sends, so it only writes tables
--]]

function Property.forget(player: Player | Bot)
	local joiner: Joiner? = Joined[player]
	if not joiner then
		return
	end

	for _, property: Self<any> in Properties do
		property._stale[player] = true
	end

	-- Volt holds nothing for a bot, so only a player's drop before the handshake can have taken a held value
	if not joiner.handshaken and not Network.isBot(player) then
		joiner.waiting = true
	end
end

export type Property<T> = Self<T>
type Self<T> = typeof(setmetatable({} :: Fields<T>, Property))

return Property
