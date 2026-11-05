--[[
    The client half of Oak.Property: one shared object per event, holding
    the last value the server sent and handing every new one to whatever
    observes it
--]]

--!strict
local ClientProperty = {}
ClientProperty.__index = ClientProperty

local Promise: any = require(script.Parent.Parent.Promise)

export type ClientListener<T> = {
	on: (listener: (value: T) -> ()) -> () -> (),
	iter: () -> () -> (number, T),
}

type Fields<T> = {
	_value: T?, -- The last value the server sent, nil until the first
	_ready: boolean, -- Set by the first value, which may itself be nil
	_observers: { [{ nil }]: (value: T) -> () }, -- Every connected Observe callback, by its token
	_waiting: { (value: T) -> () }, -- What resolves each OnReady Promise made before the first value
}

local Objects: { [ClientListener<any>]: Self<any> } = {} -- The one object per event, kept for the client session

--- @class ClientProperty
--- The client half of `Oak.Property`: the last value the server sent for
--- one event, which a controller, a React hook and a Component all read
--- through the same object

--- The client half of a Property over one event. Every call for one event
--- returns the same object: the first makes it and connects the event's
--- one listener, which lives for the client session, and every later call
--- connects nothing.
--- @function new
--- @within ClientProperty
--- @param handle ClientListener<T> -- A `from: Server` event in the client's Network
--- @return ClientProperty<T>

function ClientProperty.new<T>(handle: ClientListener<T>): Self<T>
	local existing: Self<T>? = Objects[handle]
	if existing then
		return existing
	end

	local self: Self<T> = setmetatable({
		_value = nil :: T?,
		_ready = false,
		_observers = {} :: { [{ nil }]: (value: T) -> () },
		_waiting = {} :: { (value: T) -> () },
	}, ClientProperty)

	Objects[handle] = self

	-- The client session owns the event's one listener, so it keeps no disconnect
	handle.on(function (value: T)
		self:_receive(value)
	end)

	return self
end

--- The last value the server sent, or nil until the first arrives, so a
--- caller narrows it before comparing.
--- @method Get
--- @within ClientProperty
--- @return T? -- The value, or nil before the first

function ClientProperty.Get<T>(self: Self<T>): T?
	return self._value
end

--- Calls `callback` with the value at once when one has arrived, then with
--- every value the server sends, until the function it returns is called.
--- @method Observe
--- @within ClientProperty
--- @param callback (value: T) -> () -- Called with each value
--- @return () -> () -- Disconnects the callback

function ClientProperty.Observe<T>(self: Self<T>, callback: (value: T) -> ()): () -> ()
	if self._ready then
		callback(self._value :: T)
	end

	local token: { nil } = {}
	self._observers[token] = callback

	-- Cleanup and disconnect from callback
	return function ()
		self._observers[token] = nil
	end
end

--- A Promise that resolves with the first value, at once when one has
--- already arrived.
--- @method OnReady
--- @within ClientProperty
--- @return Promise<T> -- Resolves with the first value

function ClientProperty.OnReady<T>(self: Self<T>): any
	if self._ready then
		return Promise.resolve(self._value)
	end

	return Promise.new(function (resolve: (value: T) -> ())
		table.insert(self._waiting, resolve)
	end)
end

--- Whether a value has arrived.
--- @method IsReady
--- @within ClientProperty
--- @return boolean -- True once the first value has arrived

function ClientProperty.IsReady<T>(self: Self<T>): boolean
	return self._ready
end

-- Keeps a value the server sent, resolves every OnReady waiting on the first and hands it to each observer
function ClientProperty._receive<T>(self: Self<T>, value: T)
	self._value = value
	self._ready = true

	for _, resolve: (value: T) -> () in self._waiting do
		resolve(value)
	end

	table.clear(self._waiting)

	-- A copy, so an observer that connects or disconnects another leaves this walk as it was
	for token: { nil }, observer: (value: T) -> () in table.clone(self._observers) do
		-- Each on a thread of its own, so one that errors or yields holds up no other
		if self._observers[token] then
			task.spawn(observer, value)
		end
	end
end

export type ClientProperty<T> = Self<T>
type Self<T> = typeof(setmetatable({} :: Fields<T>, ClientProperty))

return ClientProperty
