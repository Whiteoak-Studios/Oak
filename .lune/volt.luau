--[[
    Copies the Volt runtime that wally install put under Packages/ into the
    gitignored .volt/src, where the volt alias points and the suite loads it
--]]

--!strict
local fs = require("@lune/fs")

local PACKAGES: string = "Packages" -- The folder wally install fills
local LINK_FILE: string = `{PACKAGES}/Volt.lua` -- The thunk Wally writes for the Volt alias
local LINK: string = `_Index%["([^"]+)"%]%["([^"]+)"%]` -- The installed folder and package name a thunk requires
local FOLDER: string = ".volt" -- The gitignored folder the runtime is copied into
local TARGET: string = `{FOLDER}/src` -- Where the volt alias in .luaurc points

assert(fs.isFile(LINK_FILE), `{LINK_FILE} is missing, so {PACKAGES}/ holds no Volt; run wally install`)

local link: string = fs.readFile(LINK_FILE)
local installed: string?, name: string? = link:match(LINK)
assert(installed and name, `{LINK_FILE} names no installed folder; run wally install`)

local source: string = `{PACKAGES}/_Index/{installed}/{name}/src`

-- A copy over an older one would keep the files the newer version dropped
if fs.isDir(TARGET) then
	fs.removeDir(TARGET)
end

fs.writeDir(FOLDER)
fs.copy(source, TARGET)

print(`Copied {source} to {TARGET}`)
