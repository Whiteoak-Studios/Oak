--[[
    The loader: create and the names it keeps, the lazy proxies peers are
    reached through, the boot that starts a realm, and onStart
--]]

--!strict
local Promise: any = require(script.Parent.Parent.Promise)

local Binder = require(script.Parent.Binder)
local Failures = require(script.Parent.Failures)
local Policy = require(script.Parent.Policy)
local Property = require(script.Parent.Property)

local LINE: string = "^%d+%.%d+" -- A version's major.minor, the part two Volt lines differ in
local MARK: { [any]: any } = {} -- The metatable create sets on every table it makes, which collect tells Oak's tables by
local SERVER_FIELDS: { string } = { "Client", "Policy" } -- What only a server service holds, refused on the client

export type Promise<T...> = {
	andThen: (self: Promise<T...>, onResolve: (T...) -> ...any, onReject: ((...any) -> ...any)?) -> any,
	catch: (self: Promise<T...>, onReject: (...any) -> ...any) -> any,
	await: (self: Promise<T...>) -> (boolean, T...),
	expect: (self: Promise<T...>) -> T...,
}

local Loader = {}

local Names: { [any]: string | false } = {} -- The name each table was created with, false for one created with none
local Tables: { [string]: any } = {} -- Every collected table by its registry name, which a peer resolves through
local Wanted: { [string]: true } = {} -- Every name a peer was asked for before collect ended, checked at its end
local Waiting: { () -> () } = {} -- What onStart resolves once every Start is spawned

-- How far this realm's boot has got, which the peers and onStart read
local Boot = {
	collected = false, -- A peer asked for from now on resolves at once
	started = false, -- Every Start is spawned, so onStart resolves at once
}

--[[
    Marks a table as a service or controller and hands the same table back,
    keeping the name it was given, if any, for collect
--]]

function Loader.create(nameOrDef: any, def: any): any
	local name: string? = nil
	local created: any = nameOrDef

	if type(nameOrDef) == "string" then
		name = nameOrDef
		created = def
	end

	if type(created) ~= "table" then
		error(`Oak.create needs a table to make a service or controller of, not {created}`, 2)
	end

	if getmetatable(created) == MARK then
		error(`Oak.create was given a table it has already created`, 2)
	end

	Names[created] = name or false

	return setmetatable(created, MARK)
end

-- The collected table of that name, or an error naming it when there is none
local function lookup(name: string): any
	local found: any = Tables[name]
	if not found then
		error(`Oak has no table named {name}; a peer resolves once Oak.start has collected it`)
	end

	return found
end

--[[
    The real table once collect has ended; before that a proxy whose reads
    and writes both go to the table, so a write through self in a method
    called through it lands on the table rather than on the proxy
--]]

local function peer(name: string): any
	if Boot.collected then
		return lookup(name)
	end

	Wanted[name] = true

	return setmetatable({}, {
		__index = function (_: any, key: any): any
			return lookup(name)[key]
		end,

		__newindex = function (_: any, key: any, value: any)
			lookup(name)[key] = value
		end,
	})
end

--[[
    A peer service by its registry name, typed by the local it is put in;
    the server's alone, since a client reaches the server through Network
--]]

function Loader.getService(name: string): any
	if not game:GetService("RunService"):IsServer() then
		error(`Oak.getService("{name}") ran on the client, which reaches the server only through its Network`, 2)
	end

	return peer(name)
end

--[[
    A peer controller by its registry name, typed by the local it is put
    in; the client's alone, since a service has Oak.getService
--]]

function Loader.getController(name: string): any
	if game:GetService("RunService"):IsServer() then
		error(`Oak.getController("{name}") ran on the server, where a peer comes from Oak.getService`, 2)
	end

	return peer(name)
end

-- Stops the boot with every problem found, one per line
local function refuse(problems: { string })
	error(`Oak could not start:\n\t{table.concat(problems, "\n\t")}`, 0)
end

--[[
    Why the Network cannot boot over the Volt installed with Oak, or nil
    when it can: one from another Volt line by major.minor, one with no
    version field, or one compiled with option casing = pascal
--]]

local function checkLine(network: any): string?
	local installed: string = require(script.Parent.Parent.Volt).version
	local compiled: unknown = network.version

	-- Volt's casing renames the version field too, so a pascal module carries only Version
	if compiled == nil and type(network.Version) == "string" then
		return `the Network was compiled with option casing = pascal; Oak reads it by its camel names`
	end

	if type(compiled) ~= "string" then
		return `the Network has no version field, so the Volt that compiled it is unknown; Oak's is {installed}`
	end

	if compiled:match(LINE) ~= installed:match(LINE) then
		return `the Network was compiled by Volt {compiled}, and the Volt installed with Oak is {installed}`
	end

	return nil
end

--[[
    The ModuleScripts collect requires: every one under a root, deep, or
    each in a list in its order, with a problem for a list entry that is
    not a ModuleScript or is named twice
--]]

local function gather(rootOrList: Instance | { ModuleScript }, problems: { string }): { ModuleScript }
	local modules: { ModuleScript } = {}

	if typeof(rootOrList) == "Instance" then
		for _, descendant: Instance in rootOrList:GetDescendants() do
			if descendant:IsA("ModuleScript") then
				table.insert(modules, descendant)
			end
		end

		return modules
	end

	local listed: { [any]: true } = {}

	-- A game's list may hold anything, so each entry is checked rather than trusted to its type
	for _, entry: unknown in rootOrList do
		if typeof(entry) ~= "Instance" or not entry:IsA("ModuleScript") then
			table.insert(problems, `Oak.start's list holds {entry}, which is not a ModuleScript`)
		elseif listed[entry] then
			table.insert(problems, `Oak.start's list names {entry:GetFullName()} twice`)
		else
			listed[entry] = true
			table.insert(modules, entry :: ModuleScript)
		end
	end

	return modules
end

--[[
    Requires every module and fills Tables with what each created, then
    checks every peer name against them; returns the names in the order
    they were collected and every problem found
--]]

local function collect(rootOrList: Instance | { ModuleScript }, isServer: boolean): ({ string }, { string })
	local problems: { string } = {}
	local order: { string } = {}
	local sources: { [string]: ModuleScript } = {}

	for _, module: ModuleScript in gather(rootOrList, problems) do
		local created: any = require(module) :: any

		if getmetatable(created) ~= MARK then
			table.insert(problems, `{module:GetFullName()} returned something Oak.create did not make`)
			continue
		end

		local name: string = Names[created] or module.Name

		if not Names[created] then
			local path: string = module:GetFullName()
			warn(`Oak: {path} created its table with no name, so it is named {name} after its ModuleScript`)
		end

		local first: ModuleScript? = sources[name]
		if first then
			table.insert(problems, `{first:GetFullName()} and {module:GetFullName()} both create {name}`)
			continue
		end

		sources[name] = module
		Tables[name] = created
		table.insert(order, name)

		if isServer then
			continue
		end

		for _, field: string in SERVER_FIELDS do
			if created[field] ~= nil then
				table.insert(problems, `{name} has a {field} field, which only a server service has`)
			end
		end
	end

	Boot.collected = true

	for wanted: string in Wanted do
		if not Tables[wanted] then
			table.insert(problems, `a peer was asked for as {wanted}, and no collected table is named that`)
		end
	end

	return order, problems
end

--[[
    Boots the realm: the Volt line check, collect, bind, every Init, the
    client's handler check, then every Start. A problem at any step stops
    the boot with all of that step's problems, and nothing after it runs.
    The steps up to bind never yield, so no message is decoded before its
    rate and handler exist
--]]

function Loader.start(rootOrList: Instance | { ModuleScript }, network: any)
	assert(type(network) == "table", "Oak.start needs this realm's generated Network module after the services")

	local isServer: boolean = game:GetService("RunService"):IsServer()

	-- 1) The Network must come from the Volt line installed with Oak
	local mismatch: string? = checkLine(network)
	if mismatch then
		refuse({ mismatch })
	end

	if isServer then
		Property.prepare(network)
	end

	-- 2) Collect, and every peer name against what it found
	local order: { string }, problems: { string } = collect(rootOrList, isServer)
	if #problems > 0 then
		refuse(problems)
	end

	-- 3) Bind: every check first, and only a clean one applies anything
	local binding: { string }, owners: { [string]: any } = Binder.bind(network, Tables, isServer)
	if #binding > 0 then
		refuse(binding)
	end

	if isServer then
		Policy.apply(network, owners)
	end

	Failures.bind(network, owners, isServer)

	if isServer then
		Binder.connect(network, owners)
		Property.bind(network)
	end

	-- 4) Every Init in collect order, each failure kept so one report names them all
	local failed: { string } = {}

	for _, name: string in order do
		local created: any = Tables[name]
		local init: (any) -> () = created.Init

		if type(init) ~= "function" then
			continue
		end

		debug.setmemorycategory(name)
		local ran: boolean, reason: any = pcall(init, created)
		debug.resetmemorycategory()

		if not ran then
			table.insert(failed, `{name}'s Init threw: {reason}`)
		end
	end

	if #failed > 0 then
		refuse(failed)
	end

	-- 5) On the client, every server-to-client function has its handler once every Init has run
	if not isServer then
		local missing: { string } = Binder.checkHandlers(network, owners)
		if #missing > 0 then
			refuse(missing)
		end
	end

	-- 6) Every Start on a thread of its own, then onStart resolves
	for _, name: string in order do
		local created: any = Tables[name]
		local start: (any) -> () = created.Start

		if type(start) ~= "function" then
			continue
		end

		task.spawn(function ()
			debug.setmemorycategory(name)
			start(created)
		end)
	end

	Boot.started = true

	for _, resolve: () -> () in Waiting do
		resolve()
	end

	table.clear(Waiting)
end

--[[
    A Promise that resolves once every Start has been spawned, at once
    when they already have, for code outside the loader such as Components
--]]

function Loader.onStart(): Promise<()>
	if Boot.started then
		return Promise.resolve()
	end

	return Promise.new(function (resolve: () -> ())
		table.insert(Waiting, resolve)
	end)
end

return Loader
