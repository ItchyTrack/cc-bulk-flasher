-- Minimal base64 encode/decode.
--
-- Only used for the human-pasted "update <payload>" command, since a game
-- terminal can't safely accept raw binary over the keyboard/clipboard.
-- Once decoded, everything else (rednet, AEAD) works on raw byte strings.

local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function encode(data)
    local out = {}
    for i = 1, #data, 3 do
        local b1, b2, b3 = data:byte(i, i + 2)
        b2 = b2 or 0
        b3 = b3 or 0
        local n = b1 * 65536 + b2 * 256 + b3
        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64
        local chunk = chars:sub(c1 + 1, c1 + 1) .. chars:sub(c2 + 1, c2 + 1)
        chunk = chunk .. (i + 1 <= #data and chars:sub(c3 + 1, c3 + 1) or "=")
        chunk = chunk .. (i + 2 <= #data and chars:sub(c4 + 1, c4 + 1) or "=")
        out[#out + 1] = chunk
    end
    return table.concat(out)
end

local reverse
local function decode(data)
    if not reverse then
        reverse = {}
        for i = 1, #chars do
            reverse[chars:sub(i, i)] = i - 1
        end
    end
    data = data:gsub("[^A-Za-z0-9+/=]", "")
    local out = {}
    for i = 1, #data, 4 do
        local s1, s2 = data:sub(i, i), data:sub(i + 1, i + 1)
        local s3, s4 = data:sub(i + 2, i + 2), data:sub(i + 3, i + 3)
        local c1, c2 = reverse[s1] or 0, reverse[s2] or 0
        local n = c1 * 262144 + c2 * 4096
        out[#out + 1] = string.char(math.floor(n / 65536) % 256)
        if s3 ~= "=" and s3 ~= "" then
            local c3 = reverse[s3] or 0
            n = n + c3 * 64
            out[#out + 1] = string.char(math.floor(n / 256) % 256)
            if s4 ~= "=" and s4 ~= "" then
                local c4 = reverse[s4] or 0
                n = n + c4
                out[#out + 1] = string.char(n % 256)
            end
        end
    end
    return table.concat(out)
end

return { encode = encode, decode = decode }
