--[[
    Formats every .luau file under src, tests, dev and .lune with StyLua, then
    puts back the space StyLua strips after an anonymous function's keyword.
    A folder that does not exist yet and Volt's output are skipped
--]]

--!strict
local fs = require("@lune/fs")
local process = require("@lune/process")

local ROOTS: { string } = { "src", "tests", "dev", ".lune" } -- The folders formatted, each once it exists
local IGNORE_FILE: string = ".styluaignore" -- Volt's output, which StyLua and the restore both leave alone
local IGNORED_FOLDER: string = "^([%w_%-][%w_%-%./]*)/%*%*$" -- A folder/** line of the ignore file, folder captured
local LINE: string = "[^\r\n]+" -- One line of a text file
local LUAU_FILE: string = "%.luau$" -- The file names StyLua is handed
local ANONYMOUS: string = "%f[%w_]function%(" -- An anonymous function's keyword as StyLua leaves it
local SPACED: string = "function (" -- The same keyword as the house style writes it

local Skipped: { [string]: boolean } = {}
local Files: { string } = {}

-- Whiteoak TODO: only folder/** lines are read; read the rest of gitignore's patterns once the ignore file holds one
for line: string in fs.readFile(IGNORE_FILE):gmatch(LINE) do
	local folder: string? = line:match(IGNORED_FOLDER)
	assert(folder, `{IGNORE_FILE} holds "{line}", which is not a folder/** line`)

	Skipped[folder] = true
end

--[[
    Walks a folder for .luau files, handing each one to the visitor and
    skipping every folder the ignore file names
--]]

local function walk(directory: string, visit: (path: string) -> ())
	for _, name: string in fs.readDir(directory) do
		local path: string = `{directory}/{name}`

		if Skipped[path] then
			continue
		end

		if fs.isDir(path) then
			walk(path, visit)
		elseif name:match(LUAU_FILE) then
			visit(path)
		end
	end
end

for _, root: string in ROOTS do
	if fs.isDir(root) then
		walk(root, function (path: string)
			table.insert(Files, path)
		end)
	end
end

-- Whiteoak TODO: one command line carries every path and caps out near a thousand files on Windows; batch it then
local result: process.ExecResult = process.exec("stylua", Files, { stdio = "forward" })

if not result.ok then
	process.exit(result.code)
end

-- Only an anonymous function puts a parenthesis straight after the keyword, so the restore is safe
for _, path: string in Files do
	local source: string = fs.readFile(path)
	local restored: string = source:gsub(ANONYMOUS, SPACED)

	if restored ~= source then
		fs.writeFile(path, restored)
	end
end
