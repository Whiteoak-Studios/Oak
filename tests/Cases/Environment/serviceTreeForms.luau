--[[
    A service tree of real Folders and ModuleScripts, collected deep from
    its root and in order from a list, each body run once in its realm;
    a Folder and another realm's ModuleScript are refused by require
--]]

--!strict
local Environment = require("../../Environment")

local SOURCE: string = [[
local Collect = {}

function Collect.collect(rootOrList: any): { any }
	local list: { any } = typeof(rootOrList) == "Instance" and rootOrList:GetDescendants() or rootOrList
	local collected: { any } = {}

	for _, node: any in list do
		if typeof(node) == "Instance" and node:IsA("ModuleScript") then
			table.insert(collected, require(node))
		end
	end

	return collected
end

function Collect.require(node: any): any
	return require(node)
end

return Collect
]]

return function (): (boolean, string | nil)
	local server = Environment.new()
	local _, transport = server.mock:join("Player")
	local client = server:client(transport)

	local runs: { [string]: number } = {}

	local function body(name: string): () -> any
		return function (): any
			runs[name] = (runs[name] or 0) + 1

			return { name = name }
		end
	end

	local root: any = server:folder("Services")
	local features: any = server:folder("Features", root)
	local player: any = server:folder("Player", features)
	local shop: any = server:module("ShopService", body("ShopService"), features)
	local data: any = server:module("DataService", body("DataService"), player)
	local notModule: any = server:folder("Config", root)

	-- Through a local, since the new solver reads a typeof compared with a string as a type Lune lacks
	local kind: string = typeof(shop)

	if kind ~= "Instance" or shop.ClassName ~= "ModuleScript" or shop.Parent ~= features then
		return false, `A module made {kind} {shop.ClassName} under {shop.Parent}`
	end

	local children: number = #root:GetChildren()

	if children ~= 2 or root:FindFirstChild("Features") ~= features then
		return false, `The root holds {children} children, and Features is {root:FindFirstChild("Features")}`
	end

	server:mount("Collect", SOURCE)
	local Collect: any = server:load("Collect")

	local deep: { any } = Collect.collect(root)

	if #deep ~= 2 then
		return false, `The root form collected {#deep} modules rather than both, the nested one among them`
	end

	local listed: { any } = Collect.collect({ data, shop })

	if listed[1].name ~= "DataService" or listed[2].name ~= "ShopService" then
		return false, `The list form collected {listed[1].name}, then {listed[2].name}`
	end

	if runs.ShopService ~= 1 or runs.DataService ~= 1 then
		return false, `Bodies ran {runs.ShopService} and {runs.DataService} times rather than once each`
	end

	if notModule:IsA("ModuleScript") or pcall(Collect.require, notModule) then
		return false, "A Folder was taken for a ModuleScript"
	end

	local foreign: any = client:module("ShopController", body("ShopController"))

	if pcall(Collect.require, foreign) or runs.ShopController ~= nil then
		return false, "The server required a ModuleScript the client's environment made"
	end

	return true, nil
end
