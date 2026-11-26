
local ed25519 = require("ccryptolib.ed25519")

local M = {}

local function hexToBytes(hex)
    assert(#hex == 64, "pubkey must be 32 bytes hex-encoded (64 hex chars)")
    return (hex:gsub("..", function(b)
        return string.char(tonumber(b, 16))
    end))
end

local function findModemSide()
    local modem = peripheral.find("modem")
    if not modem then error("No modem attached to this computer") end
    return peripheral.getName(modem)
end

-- Verifies signed URL. Returns URL or nil.
local function verifyPayload(pubkeyBytes, payload)
    if type(payload) ~= "string" or #payload < 65 then return nil end
    local sig, url = payload:sub(1, 64), payload:sub(65)
    local ok, valid = pcall(ed25519.verify, pubkeyBytes, url, sig)
    if not ok or not valid then return nil end
    return url
end

local function applyFiles(files, root)
    local count = 0
    for _, file in ipairs(files) do
        local dest = fs.combine(root, file.path)
        local resp = http.get(file.url, nil, true)
        if resp then
            local dir = fs.getDir(dest)
            if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
            local f = fs.open(dest, "wb")
            f.write(resp.readAll())
            f.close()
            resp.close()
            count = count + 1
        else
            print("flasher: failed to download " .. file.url)
        end
    end
    return count
end

function M.listen(config)
    local pubkeyBytes = hexToBytes(config.pubkey)
    rednet.open(findModemSide())
    print("flasher: listening for updates (" .. config.subpath .. ")")

    while true do
        local _, payload = rednet.receive(config.protocol)
        local url = verifyPayload(pubkeyBytes, payload)
        if url then
            local resp = http.get(url, nil, true)
            if resp then
                local ok, manifest = pcall(textutils.unserialiseJSON, resp.readAll())
                resp.close()

                if ok and manifest and manifest.targets then
                    local files = manifest.targets[config.subpath]
                    if files then
                        print("flasher: applying update " .. tostring(manifest.tag))
                        local count = applyFiles(files, config.root)
                        print("flasher: wrote " .. count .. " file(s)")
                        if count > 0 then os.reboot() end
                    end
                end
            end
        else
            print("flasher: dropped broadcast with invalid/missing signature")
        end
    end
end

M.verifyPayload = verifyPayload
M.applyFiles = applyFiles

return M
