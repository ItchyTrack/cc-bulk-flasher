package.path = package.path .. ";/flasher/?.lua;/flasher/?/init.lua"

local config = require("config")
local updater = require("updater")
local cc_require = require("cc.require")

local function runEntrypoint(spawn)
    local path = fs.combine(config.root, "main.lua")
    if not fs.exists(path) then
        print("ghu: no entrypoint at " .. path .. " yet -- waiting for first update")
        return
    end

    local env = setmetatable({}, { __index = _ENV })
    env.require, env.package = cc_require.make(env, config.root)

    local chunk, err = loadfile(path, "t", env)
    if not chunk then
        print("ghu: main.lua failed to load: " .. tostring(err))
        return
    end

    local ok, mod = pcall(chunk)
    if not ok then
        print("ghu: main.lua crashed: " .. tostring(mod))
        return
    end

    if type(mod) == "table" and type(mod.main) == "function" then
        local ok2, err2 = pcall(mod.main, spawn)
        if not ok2 then
            print("ghu: main.lua crashed: " .. tostring(err2))
        end
    end
end

parallel.waitForAll(runEntrypoint, function(spawn) updater.listen(config, spawn) end)