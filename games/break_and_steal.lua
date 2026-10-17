-- ═══════════════════════════════════════════════════════
-- 🥚 V-Ziir0 Hub: Break & Steal An Egg Monitor
-- ═══════════════════════════════════════════════════════

local player = game.Players.LocalPlayer
local HttpService = game:GetService("HttpService")

local WEBHOOK_URL = "https://discord.com/api/webhooks/1560789097440616529/097v0ksImZfYm2g4zSQKbEvb-9ttIwSHah-v5nxavKklco3t5S71rMR9vySSjOwtMEEn"
local INTERVAL = 15
local httpFn = request or http_request or (http and http.request)

if not httpFn then
    warn("❌ Nggak ada fungsi request!")
    return
end

local lastCash = nil
local lastSpeed = nil

local function sendWebhook(payload)
    local body = HttpService:JSONEncode(payload)
    for attempt = 1, 3 do
        local ok, result = pcall(function()
            return httpFn({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = body,
            })
        end)
        if ok then
            local status = nil
            if type(result) == "table" then
                status = result.Status or result.StatusCode
            end
            if status == 200 or status == 204 then
                return true
            end
        end
        task.wait(1)
    end
    return false
end

local function cleanNumber(str)
    str = tostring(str)
    str = str:gsub("%$", "")
    str = str:gsub("/s", "")
    str = str:gsub("%s+", "")
    return str
end

local function getMyData()
    local ls = player:FindFirstChild("leaderstats")
    if not ls then return "?", "?" end
    
    local cash, speed = "?", "?"
    for _, stat in ipairs(ls:GetChildren()) do
        if stat.Name == "Cash/s" then
            cash = cleanNumber(stat.Value)
        elseif stat.Name == "Speed" then
            speed = cleanNumber(stat.Value)
        end
    end
    return cash, speed
end

local function sendToDiscord(cash, speed)
    local embed = {
        title = "⚡ FARMING MONITOR ⚡",
        description = "```ini\n[ @" .. player.Name .. " ]```\n**━━━━━━━━━━━━━━━━━━━━━━━━**",
        color = 0x00FFAA,
        fields = {
            { name = "💰 ▸ INCOME", value = "```yaml\n" .. cash .. "```", inline = true },
            { name = "⚡ ▸ SPEED", value = "```yaml\n" .. speed .. "```", inline = true },
            { name = "🎯 ▸ STATUS", value = "```diff\n+ FARMING ACTIVE```", inline = false },
        },
        footer = { text = "V-Ziir0 Hub • " .. os.date("%H:%M:%S") },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
    sendWebhook({ username = "⚡ Farming Monitor", avatar_url = "https://cdn-icons-png.flaticon.com/512/1055/1055687.png", embeds = { embed } })
end

task.spawn(function()
    print("✅ Monitor Break & Steal berjalan!")
    while task.wait(INTERVAL) do
        local cash, speed = getMyData()
        if cash ~= lastCash or speed ~= lastSpeed then
            sendToDiscord(cash, speed)
            lastCash, lastSpeed = cash, speed
        end
    end
end)