--[[
    Oak, Whiteoak's service and controller framework over Volt: the public
    API a game calls, and every type a game writes through Oak
--]]

--!strict
local Volt = require(script.Parent.Volt)

local ClientProperty = require(script.ClientProperty)
local Failures = require(script.Failures)
local Loader = require(script.Loader)
local Property = require(script.Property)

export type Bot = Volt.Bot
export type ClientProperty<T> = ClientProperty.ClientProperty<T>
export type Promise<T...> = Loader.Promise<T...>
export type Property<T> = Property.Property<T>

-- Oak.Property's two halves: the server's takes a default, and the client's takes none
type MakeProperty =
	(<T>(handle: Property.ServerEvent<T>, default: T) -> Property<T>)
	& (<T>(handle: ClientProperty.ClientListener<T>) -> ClientProperty<T>)

--- @class Oak
--- Services on the server and controllers on the client: tables made with
--- create, reached by name through getService and getController, and
--- started by start over the realm's generated Network

local Oak = {}

--- Makes a service or controller of a table and returns that same table,
--- its type unchanged, so methods and Client handlers are added after the
--- call. The name is the table's registry name, which peers resolve by, and
--- its Volt namespace is the name less a trailing Service or Controller. A
--- table created with no name takes its ModuleScript's name, with a warning
--- at boot, and creating one table twice errors.
--- @function create
--- @within Oak
--- @param name string -- The registry name, as ShopService owns the Shop namespace
--- @param def T -- The table: a service's Client and Policy, and any state it keeps
--- @return T -- The same table, its type unchanged

Oak.create = (Loader.create :: any) :: (<T>(name: string, def: T) -> T) & (<T>(def: T) -> T)

--- A peer service by its registry name, typed by annotating the local it
--- goes in. Asked for before boot, it is a proxy whose reads and writes
--- reach the table once collect has found it, and the boot fails on a name
--- no collected table has; asked for after, it is the table itself. The
--- server's alone.
--- @function getService
--- @within Oak
--- @param name string -- The name the peer was created with
--- @return any -- The peer, or the proxy that resolves to it

Oak.getService = Loader.getService

--- A peer controller by its registry name, as getService gives a peer
--- service. The client's alone.
--- @function getController
--- @within Oak
--- @param name string -- The name the peer was created with
--- @return any -- The peer, or the proxy that resolves to it

Oak.getController = Loader.getController

--- Boots the realm over its generated Network: checks the Volt line,
--- requires every ModuleScript under the root or each in the list, binds
--- every endpoint, runs every Init, checks the client's handlers and
--- spawns every Start. Any problem stops the boot with an error naming it.
--- @function start
--- @within Oak
--- @param rootOrList Instance | { ModuleScript } -- A root collected deep, or a list collected in its order
--- @param network any -- This realm's module Volt generated, Network.Server or Network.Client

Oak.start = Loader.start

--- A Promise that resolves once every Start has been spawned, for code
--- outside the loader, such as a Component, that calls a service.
--- @function onStart
--- @within Oak
--- @return Promise<()> -- Resolves once the boot has spawned every Start

Oak.onStart = Loader.onStart

--- Sets this realm's game-wide failure handler, which takes every Volt
--- failure no table's own onFailure took. A later call replaces it.
--- @function onFailure
--- @within Oak
--- @param callback (...any) -> () -- Called with the player on the server, then the kind and the detail

Oak.onFailure = Failures.set

--- The replication primitive over one Volt event. On the server it makes
--- the half a service's Client holds, its top value starting at default;
--- on the client it returns the event's one shared object, which takes no
--- default.
--- @function Property
--- @within Oak
--- @param handle ServerEvent<T> | ClientListener<T> -- The event's handle in this realm's Network
--- @param default T? -- The server's starting top value
--- @return Property<T> | ClientProperty<T> -- The server half, or the client's shared object

local function makeProperty(handle: any, default: any): any
	-- Each constructor is called straight from here, so an error it raises at level 3 names the game's line
	if game:GetService("RunService"):IsServer() then
		return Property.new(handle, default)
	end

	return ClientProperty.new(handle)
end

Oak.Property = (makeProperty :: any) :: MakeProperty

return Oak
