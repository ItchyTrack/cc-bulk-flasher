package.path = package.path .. ";/flasher/?.lua;/flasher/?/init.lua"

local config = require("config")
local updater = require("updater")

local function runEntrypoint(spawn)
    local path = fs.combine(config.root, "main.lua")
    if not fs.exists(path) then
        print("ghu: no entrypoint at " .. path .. " yet -- waiting for first update")
        return
    end

    local ok, mod = pcall(dofile, path)
    if not ok then
        print("ghu: main.lua failed to load: " .. tostring(mod))
        return
    end

    if type(mod) == "table" and type(mod.main) == "function" then
        local ok2, err = pcall(mod.main, spawn)
        if not ok2 then
            print("ghu: main.lua crashed: " .. tostring(err))
        end
    end
end

parallel.waitForAll(
    function(spawn) runEntrypoint(spawn) end,
    function(spawn) updater.listen(config, spawn) end
)
