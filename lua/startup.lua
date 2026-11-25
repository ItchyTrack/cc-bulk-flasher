package.path = package.path .. ";/flasher/?.lua;/flasher/?/init.lua"

local config = require("config")
local updater = require("updater")

local function runEntrypoint(spawn)
    local path = fs.combine(config.root, "main.lua")
    if not fs.exists(path) then
        print("ghu: no entrypoint at " .. path .. " yet -- waiting for first update")
        return
    end

    local mod = dofile(path)
    if type(mod) == "table" and type(mod.main) == "function" then
        mod.main(spawn)
    end
end

parallel.waitForAll(
    function(spawn) runEntrypoint(spawn) end,
    function(spawn) updater.listen(config, spawn) end
)
