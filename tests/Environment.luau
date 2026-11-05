--[[
    One realm of a case: Oak's src mounted as Wally installs it, its own
    Promise and Volt, the generated fixtures and a fake game, script, require,
    task, warn and debug, over one Volt mock every realm of the case shares
--]]

--!strict
local Environment = {}
Environment.__index = Environment

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox: any = require("@lune/roblox") -- Its typedefs leave out the members the instance trees use
local task = require("@lune/task")

local Volt = require("@volt") -- For its types; every realm runs a copy of its own

local SRC: string = "src" -- The package, mounted where Wally installs it
local VOLT: string = ".volt/src" -- The runtime lune run volt copies out of Packages/
local GENERATED: string = "tests/Generated" -- Volt's output, a folder per schema
local MANIFEST: string = "wally.toml"
local VERSION: string = `\nversion = "([^"]+)"` -- The package's version in the manifest
local PROMISE_LINK: string = "Packages/Promise.lua" -- The thunk Wally writes for the Promise alias
local LINK: string = `_Index%["([^"]+)"%]%["([^"]+)"%]` -- The installed folder and package name a thunk requires
local PROMISE_FILE: string = "lib/init.lua" -- Promise's module inside the folder Wally installs it in
local INIT: string = "init.luau"
local MODULE_FILE: string = "^(.+)%.luau$" -- A file's name without its extension
local ROOT: string = "init" -- The name a case loads src/init.luau by
local SELF: string = "@self" -- The first segment of a string require that starts at the module itself
local HERE: string = "." -- One that starts at its parent
local UP: string = ".." -- One that starts a level further up, and any later segment that climbs one

-- Mock steps a message takes, each counted from a call made outside a step, as the probes found them
local HANDSHAKE: number = 2 -- A client's Network loads, until the server has accepted it and run onHandshake
local HELD: number = 3 -- A client's Network loads, until what the server held for its player has reached it
local DELIVERY: number = 2 -- A fire, until the other side's listener has run
local ROUND_TRIP: number = 3 -- A client's invoke, until its Promise has settled

-- Lune's debug, but setting a memory category does nothing, as Lune has none
local QUIET_DEBUG: { [string]: any } = table.clone(debug) :: any
QUIET_DEBUG.setmemorycategory = function () end
QUIET_DEBUG.resetmemorycategory = function () end

type Mock = Volt.Mock
type Transport = Volt.Transport

-- A ModuleScript's file or mounted source, a case's body for it, or the value a double stands in with
type Module = {
	path: string,
	source: string?,
	body: (() -> any)?,
	loading: boolean,
	loaded: boolean,
	result: any,
}

-- What every environment over one mock shares, as one server's clients share it
type World = {
	mock: Mock,
	environments: { Self },
}

type Fields = {
	mock: Mock,
	warnings: { string },
	_world: World,
	_server: boolean,
	_transport: Transport?,
	_modules: { [any]: Module },
	_globals: { [string]: any },
	_heartbeats: { () -> () },
	_oak: any,
	_volt: any,
	_generated: any,
}

Environment.HANDSHAKE = HANDSHAKE
Environment.HELD = HELD
Environment.DELIVERY = DELIVERY
Environment.ROUND_TRIP = ROUND_TRIP

--[[
    Finds the ModuleScript a string require names, as Luau resolves one
    from a file: @self starts at the module itself, . at its parent and ..
    a level further up, and each later .. climbs one more
--]]

local function resolve(script: any, path: string): any
	local segments: { string } = path:split("/")
	local first: string = table.remove(segments, 1) :: string
	local current: any

	if first == SELF then
		current = script
	elseif first == HERE then
		current = script.Parent
	elseif first == UP then
		current = script.Parent and script.Parent.Parent
	else
		error(`{script:GetFullName()} required {path}, which starts with none of @self, ./ or ../`)
	end

	for _, segment: string in segments do
		assert(current, `{script:GetFullName()} required {path}, which climbs above the DataModel`)

		current = segment == UP and current.Parent or current:FindFirstChild(segment)
	end

	assert(current, `{script:GetFullName()} required {path}, which names no instance`)

	return current
end

-- A real instance of the class, named, and parented when a parent is given
local function instance(className: string, name: string, parent: any?): any
	local made: any = roblox.Instance.new(className)
	made.Name = name
	made.Parent = parent

	return made
end

--[[
    The server environment of a fresh case, on a mock its own Volt makes,
    so the server runtime and the mock's bots share one Volt; clients join
    it through client
--]]

function Environment.new(): Self
	local world: World = { mock = nil :: any, environments = {} }
	local server: Self = Environment._build(world, true, nil)
	local mock: Mock = server:_require(server._volt).mock(task.spawn)

	world.mock = mock
	server.mock = mock
	server._transport = mock.server

	return server
end

--[[
    A client environment on this environment's mock, over a transport the
    mock handed out: a player's from join or a bot's from connectBot
--]]

function Environment.client(self: Self, transport: Transport): Self
	return Environment._build(self._world, false, transport)
end

--[[
    Moves the mock forward, each step delivering every queued packet and
    firing a Heartbeat on every runtime, then firing every environment's
    own RunService.Heartbeat once
--]]

function Environment.step(self: Self, count: number?)
	local world: World = self._world

	for _ = 1, count or 1 do
		world.mock:step()

		for _, environment: Self in world.environments do
			environment:_beat()
		end
	end
end

--[[
    A src module's return, init for src/init.luau and otherwise the file's
    name, or what a double or a mount put in its place; loaded once in this
    environment, then cached
--]]

function Environment.load(self: Self, name: string): any
	local module: any = name == ROOT and self._oak or self._oak:FindFirstChild(name)
	assert(module and module:IsA("ModuleScript"), `src has no {name}.luau, and nothing stands in for it`)

	return self:_require(module)
end

--[[
    Puts source text in src as the file name.luau would be, in place of
    any file or double of that name, run under this environment's globals
    when it is first required
--]]

function Environment.mount(self: Self, name: string, source: string)
	self:_put(name, {
		path = `{SRC}/{name}.luau`,
		source = source,
		body = nil,
		loading = false,
		loaded = false,
		result = nil,
	})
end

--[[
    Makes the sibling name return the double, whether or not src holds a
    file of that name; a require made before this keeps what it got
--]]

function Environment.substitute(self: Self, name: string, double: any)
	self:_put(name, {
		path = `{SRC}/{name}.luau`,
		source = nil,
		body = nil,
		loading = false,
		loaded = true,
		result = double,
	})
end

--[[
    The Network a schema's generated module returns in this realm: the
    server module on the server and the client module on a client, its
    runtime started over this environment's side of the mock
--]]

function Environment.network(self: Self, schema: string): any
	local folder: any = self._generated:FindFirstChild(schema)

	if not folder then
		local directory: string = `{GENERATED}/{schema}`
		assert(fs.isDir(directory), `{directory} is missing; compile tests/Schemas/{schema}.volt`)

		folder = self:_mount(directory, schema, self._generated)
	end

	return self:_require(folder:FindFirstChild(self._server and "Server" or "Client"))
end

-- A Folder for a service tree, parented when a parent is given
function Environment.folder(_: Self, name: string, parent: any?): any
	return instance("Folder", name, parent)
end

--[[
    A ModuleScript for a service tree whose require, the first time in this
    environment, runs the body and keeps its return for every later one
--]]

function Environment.module(self: Self, name: string, body: () -> any, parent: any?): any
	local module: any = instance("ModuleScript", name, parent)

	self._modules[module] = {
		path = name,
		source = nil,
		body = body,
		loading = false,
		loaded = false,
		result = nil,
	}

	return module
end

--[[
    Builds one realm's DataModel: src as oak inside its Wally folder, with
    Promise and Volt beside it and the Packages aliases, the folder the
    fixtures mount in, and the globals every loaded file sees
--]]

function Environment._build(world: World, server: boolean, transport: Transport?): Self
	local warnings: { string } = {}
	local heartbeats: { () -> () } = {}

	local runService: { [string]: any } = {
		Heartbeat = {
			Connect = function (_: any, callback: () -> ()): any
				table.insert(heartbeats, callback)

				return {
					Disconnect = function (_: any)
						local index: number? = table.find(heartbeats, callback)
						if index then
							table.remove(heartbeats, index)
						end
					end,
				}
			end,

			-- Only Promise's report of an unhandled rejection waits on a frame, and a scheduler frame serves it
			Wait = function (_: any): number
				return task.wait()
			end,
		},

		IsServer = function (_: any): boolean
			return server
		end,

		IsClient = function (_: any): boolean
			return not server
		end,

		IsStudio = function (_: any): boolean
			return false
		end,
	}

	local replicatedStorage: any = roblox.Instance.new("DataModel"):GetService("ReplicatedStorage")
	local services: { [string]: any } = { RunService = runService, ReplicatedStorage = replicatedStorage }

	local self: Self = setmetatable({
		mock = world.mock,
		warnings = warnings,
		_world = world,
		_server = server,
		_transport = transport,
		_modules = {} :: { [any]: Module },
		_heartbeats = heartbeats,
		_oak = nil :: any,
		_volt = nil :: any,
		_generated = instance("Folder", "Generated", replicatedStorage),

		_globals = {
			task = task,
			debug = QUIET_DEBUG,

			game = {
				GetService = function (_: any, name: string): any
					local service: any = services[name]
					assert(service, `The harness's game has no {name}, only RunService and ReplicatedStorage`)

					return service
				end,
			},

			-- Kept for the case to read, joined with spaces as the engine prints them, and never printed
			warn = function (...: any)
				local given: { n: number, [number]: any } = table.pack(...)
				local parts: { string } = {}

				for index: number = 1, given.n do
					table.insert(parts, tostring(given[index]))
				end

				table.insert(warnings, table.concat(parts, " "))
			end,
		},
	}, Environment)

	local version: string? = fs.readFile(MANIFEST):match(VERSION)
	assert(version, `{MANIFEST} has no version line`)

	local packages: any = instance("Folder", "Packages", replicatedStorage)
	local installed: any = instance("Folder", `fadeluc-123_oak@{version}`, instance("Folder", "_Index", packages))

	-- A src with no init.luau, as a unit's worktree may have, mounts as a Folder holding the files
	self._oak = fs.isDir(SRC) and self:_mount(SRC, "oak", installed) or instance("Folder", "oak", installed)
	self._volt = self:_mount(VOLT, "Volt", installed)

	assert(fs.isFile(PROMISE_LINK), `{PROMISE_LINK} is missing; run wally install`)

	local folder: string?, alias: string? = fs.readFile(PROMISE_LINK):match(LINK)
	assert(folder and alias, `{PROMISE_LINK} names no installed folder; run wally install`)

	local promise: any = self:_file(`Packages/_Index/{folder}/{alias}/{PROMISE_FILE}`, "Promise", installed)

	-- The aliases a game's code requires through Packages, each the same module as the one beside oak
	self._modules[instance("ModuleScript", "Promise", packages)] = self._modules[promise]

	if self._oak:IsA("ModuleScript") then
		self._modules[instance("ModuleScript", "Oak", packages)] = self._modules[self._oak]
	end

	-- What the generated modules start their runtime through: this realm's Volt, over its side of the mock
	self._modules[instance("ModuleScript", "Volt", packages)] = {
		path = "ReplicatedStorage.Packages.Volt",
		source = nil,
		body = nil,
		loading = false,
		loaded = true,
		result = {
			start = function (schema: Volt.Schema): Volt.Runtime
				return self:_require(self._volt).start(schema, self._transport)
			end,
		},
	}

	table.insert(world.environments, self)

	return self
end

--[[
    Runs a ModuleScript once, a file or mounted source with script set to
    it and a require that takes a ModuleScript or a string path from it,
    and keeps its return for every later require
--]]

function Environment._require(self: Self, module: any): any
	local record: Module? = self._modules[module]
	assert(record, `require was given {module}, which is no ModuleScript this environment made`)

	if record.loaded then
		return record.result
	end

	assert(not record.loading, `{record.path} was required while it was loading, or after its first require errored`)
	record.loading = true

	local result: any

	if record.body then
		result = record.body()
	else
		local scope: { [string]: any } = table.clone(self._globals)
		scope.script = module
		scope.require = function (target: any): any
			return self:_require(type(target) == "string" and resolve(module, target) or target)
		end

		result = luau.load(record.source :: string, { debugName = record.path, environment = scope })()
	end

	record.loaded = true
	record.result = result

	return result
end

-- A child of oak by name, made when src has no such file, now loading the record given
function Environment._put(self: Self, name: string, record: Module)
	local module: any = self._oak:FindFirstChild(name) or instance("ModuleScript", name, self._oak)

	self._modules[module] = record
end

-- A ModuleScript for a file, read now so a require never waits on a read
function Environment._file(self: Self, path: string, name: string, parent: any): any
	local module: any = instance("ModuleScript", name, parent)

	self._modules[module] = {
		path = path,
		source = fs.readFile(path),
		body = nil,
		loading = false,
		loaded = false,
		result = nil,
	}

	return module
end

-- A folder as Rojo maps it: a ModuleScript when it holds an init.luau, else a Folder, each file a ModuleScript in it
function Environment._mount(self: Self, directory: string, name: string, parent: any): any
	local init: string = `{directory}/{INIT}`
	local mounted: any = fs.isFile(init) and self:_file(init, name, parent) or instance("Folder", name, parent)

	for _, entry: string in fs.readDir(directory) do
		local path: string = `{directory}/{entry}`
		local stem: string? = entry:match(MODULE_FILE)

		if fs.isDir(path) then
			self:_mount(path, entry, mounted)
		elseif stem and stem ~= ROOT then
			self:_file(path, stem, mounted)
		end
	end

	return mounted
end

-- Fires this realm's RunService.Heartbeat once, skipping a connection a callback before it disconnected
function Environment._beat(self: Self)
	local heartbeats: { () -> () } = self._heartbeats

	for _, callback: () -> () in table.clone(heartbeats) do
		if table.find(heartbeats, callback) then
			callback()
		end
	end
end

export type Environment = Self
type Self = typeof(setmetatable({} :: Fields, Environment))

return Environment
