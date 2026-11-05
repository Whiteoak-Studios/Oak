--[[
    Checks a realm's whole Network against the tables Oak started before
    anything is applied, connects each service's Client handlers, and on the
    client checks every server-to-client function has its handler
--]]

--!strict
local Binder = {}

local SUFFIXES: { string } = { "Service", "Controller" } -- What a table's name drops to give its namespace
local REGISTRY_NAME: string = "^([^%.]+)%.([^%.]+)$" -- Namespace.message, exactly one dot between them

local Names: { [any]: string } = {} -- The name each owner was started under, which a missing client handler names

-- A table's namespace: its name less a trailing Service or Controller
local function namespaceOf(name: string): string
	for _, suffix: string in SUFFIXES do
		if name:sub(-#suffix) == suffix then
			return name:sub(1, -#suffix - 1)
		end
	end

	return name
end

-- Whether this side hears the endpoint: a handle with on, or a Polling event's iter
local function inbound(handle: any): boolean
	return handle.on ~= nil or handle.iter ~= nil
end

--[[
    Each owner's handlers and Policy rows against its namespace's inbound
    endpoints, one to one, on the server. A Polling event has no on, so
    it needs no handler, but it needs its row like any other
--]]

local function checkOwner(namespace: string, owner: any, messages: { [string]: any }, problems: { string })
	local name: string = Names[owner]
	local client: { [string]: any } = owner.Client or {}
	local policy: { [string]: any } = owner.Policy or {}

	for message: string, handle: any in messages do
		if not inbound(handle) then
			continue
		end

		if handle.on and type(client[message]) ~= "function" then
			table.insert(problems, `{namespace}.{message} has no handler in {name}.Client`)
		end

		local row: any = policy[message]
		local rate: any = type(row) == "table" and row.rate

		if row == nil then
			table.insert(problems, `{namespace}.{message} has no Policy row in {name}`)
		elseif type(rate) ~= "table" or type(rate.perSecond) ~= "number" then
			table.insert(problems, `{name}.Policy.{message} has no numeric rate.perSecond`)
		end
	end

	-- Only a function is a handler, so a Property beside them is left alone
	for key: string, value: any in client do
		local handle: any = messages[key]

		if type(value) == "function" and not (handle and handle.on) then
			table.insert(problems, `{name}.Client.{key} is a handler with no inbound declaration in {namespace}`)
		end
	end

	for key: string in policy do
		local handle: any = messages[key]

		if not handle or not inbound(handle) then
			table.insert(problems, `{name}.Policy.{key} names no inbound endpoint in {namespace}`)
		end
	end
end

--[[
    Every binding check, run over the whole Network before anything is
    applied: returns every problem found, each naming its endpoint, its
    namespace or its tables, and the owner of each namespace
--]]

function Binder.bind(network: any, tables: { [string]: any }, isServer: boolean): ({ string }, { [string]: any })
	local problems: { string } = {}
	local owners: { [string]: any } = {}

	-- Every check below reads the Network by its camel names, so a module compiled otherwise gets this alone
	if type(network.onFailure) ~= "function" then
		table.insert(problems, `the Network was compiled with an option casing other than camel, which Oak cannot read`)
		return problems, owners
	end

	-- 1) Each table owns the namespace its name gives, in name order so a clash always names the same owner
	local names: { string } = {}

	for name: string in tables do
		table.insert(names, name)
	end

	table.sort(names)

	for _, name: string in names do
		local namespace: string = namespaceOf(name)
		local owner: any = owners[namespace]

		if namespace == "" then
			table.insert(problems, `{name} gives an empty namespace; a table is named after its system, as ShopService`)
		elseif owner then
			table.insert(problems, `{Names[owner]} and {name} both give the namespace {namespace}`)
		else
			owners[namespace] = tables[name]
			Names[tables[name]] = name
		end
	end

	-- 2) Every endpoint sits directly in one namespace, and that namespace has an owner
	local endpoints: { [string]: { [string]: any } } = {}
	local unowned: { [string]: true } = {}
	local registries: { { [string]: any } } = { network.events, network.functions }

	for _, registry: { [string]: any } in registries do
		for fullName: string, handle: any in registry do
			local namespace: string?, message: string? = fullName:match(REGISTRY_NAME)

			if not namespace or not message then
				local nested: boolean = fullName:find(".", 1, true) ~= nil
				local where: string = nested and "in a nested namespace" or "outside any namespace"

				table.insert(problems, `{fullName} sits {where}; every endpoint is declared directly in one namespace`)
			elseif not owners[namespace] then
				unowned[namespace] = true
			else
				endpoints[namespace] = endpoints[namespace] or {}
				endpoints[namespace][message] = handle
			end
		end
	end

	local kind: string = isServer and "service" or "controller"

	for namespace: string in unowned do
		table.insert(problems, `the Network's namespace {namespace} has no started {kind}`)
	end

	-- 3) On the server, handlers and Policy rows; the client binds nothing
	if isServer then
		for namespace: string, owner: any in owners do
			checkOwner(namespace, owner, endpoints[namespace] or {}, problems)
		end
	end

	return problems, owners
end

--[[
    Connects each service's Client handlers on their endpoints' on, each
    called with the Client table as its self. Oak never unbinds an
    endpoint, so each lives as long as the server, and on's disconnect is
    not kept
--]]

function Binder.connect(network: any, owners: { [string]: any })
	for namespace: string, owner: any in owners do
		local client: { [string]: any } = owner.Client or {}

		for message: string, handler: (...any) -> ...any in client do
			if type(handler) ~= "function" then
				continue
			end

			network[namespace][message].on(function (...: any): ...any
				return handler(client, ...)
			end)
		end
	end
end

--[[
    On the client once every Init has run: each server-to-client function
    with no handler, naming it and the controller that owns its namespace
--]]

function Binder.checkHandlers(network: any, owners: { [string]: any }): { string }
	local missing: { string } = {}

	for fullName: string, handle: any in network.functions do
		-- On the client, a function the server calls is the entry with on, and connected reads its handler
		if not handle.on or handle.connected() then
			continue
		end

		local owner: string = Names[owners[fullName:split(".")[1]]]
		table.insert(missing, `{fullName} has no handler once every Init has run; {owner} connects it in its Init`)
	end

	return missing
end

return Binder
