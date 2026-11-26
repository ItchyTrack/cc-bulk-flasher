-- Run on a fresh computer:
-- wget run https://raw.githubusercontent.com/ItchyTrack/cc-bulk-flasher/refs/heads/main/lua/install.lua <pubkey> <subpath> <protocol> <root>

local REF = "refs/heads/main"
local BASE_URL = "https://raw.githubusercontent.com/ItchyTrack/cc-bulk-flasher/" .. REF .. "/lua/"
local DEST = "/flasher/"

local FILES = {
    "startup.lua",
    "updater.lua",
    "base64.lua",
    "ccryptolib/ed25519.lua",
    "ccryptolib/random.lua",
    "ccryptolib/blake3.lua",
    "ccryptolib/chacha20.lua",
    "ccryptolib/config.lua",
    "ccryptolib/internal/util.lua",
    "ccryptolib/internal/packing.lua",
    "ccryptolib/internal/hw.lua",
    "ccryptolib/internal/mp.lua",
    "ccryptolib/internal/fp.lua",
    "ccryptolib/internal/fq.lua",
    "ccryptolib/internal/edwards25519.lua",
    "ccryptolib/internal/sha512.lua",
}

local function download(url, path)
    local resp = http.get(url .. "?ts=" .. os.time(os.date("!*t")))
    if not resp then
        error("Failed to download " .. url)
    end

    local dir = fs.getDir(path)
    if dir ~= "" and not fs.exists(dir) then
        fs.makeDir(dir)
    end
    local f = fs.open(path, "w")
    f.write(resp.readAll())
    f.close()
    resp.close()
end

for _, file in ipairs(FILES) do
    print("Fetching " .. file)
    download(BASE_URL .. file, DEST .. file)
end

local config = {
	pubkey = "0000000000000000000000000000000000000000000000000000000000000000",
	subpath = "example",
	protocol = "cc-bulk-flasher",
	root = "/app",
}
if fs.exists(DEST .. "config.lua") then
    local existing = dofile(DEST .. "config.lua")
	for k, v in pairs(existing) do
		config[k] = v
	end
end

local pubkeyArg, subpathArg, protocolArg, rootArg = ...

if pubkeyArg and pubkeyArg ~= "" then
    config.pubkey = pubkeyArg
end
if subpathArg and subpathArg ~= "" then
    config.subpath = subpathArg
end
if protocolArg and protocolArg ~= "" then
    config.protocol = protocolArg
end
if rootArg and rootArg ~= "" then
    config.root = rootArg
end

shell.run("set motd.enable false")

local configFile = fs.open(DEST .. "config.lua", "w+")

configFile.write("return " .. textutils.serialize(config) .. "\n")
configFile.close()

local startupFile = fs.open("/startup.lua", "w")
startupFile.write('shell.run("' .. DEST .. 'startup.lua")\n')
startupFile.close()

print("Install complete.")
print("  subpath:  " .. tostring(config.subpath))
print("  protocol: " .. tostring(config.protocol))
print("  root:     " .. tostring(config.root))
print("Config saved to " .. DEST .. "config.lua. Rebooting")
os.reboot()
