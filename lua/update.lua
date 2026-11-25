-- Self-contained Rednet update launcher.
-- Usage: update <protocol> <base64-payload>

local protocol, payloadB64 = ...
if not protocol or not payloadB64 then
    print("Usage: update <protocol> <base64-payload>")
    return
end

local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function base64Decode(data)
    data = data:gsub("[^" .. alphabet .. "=]", "")
    local out = {}
    local buffer, bits = 0, 0

    for i = 1, #data do
        local ch = data:sub(i, i)
        if ch == "=" then break end
        local value = alphabet:find(ch, 1, true)
        if value then
            buffer = buffer * 64 + value - 1
            bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                local byte = math.floor(buffer / (2 ^ bits)) % 256
                out[#out + 1] = string.char(byte)
                buffer = buffer % (2 ^ bits)
            end
        end
    end

    return table.concat(out)
end

local ok, payload = pcall(base64Decode, payloadB64)
if not ok then error("Invalid Base64 payload: " .. tostring(payload)) end

local modem = peripheral.find("modem")
if not modem then
    error("No modem attached to this computer")
end

rednet.open(peripheral.getName(modem))
rednet.broadcast(payload, protocol)
print("Broadcast update (" .. #payload .. " bytes) on protocol '" .. protocol .. "'")
