-- ═══════════════════════════════════════════════════════
-- 🚀 V-Ziir0 Hub Universal Monitor (Multi-Game)
-- Auto-detect game & load script yang sesuai
-- ═══════════════════════════════════════════════════════

local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- ⭐ FUNGSI NOTIFIKASI UI DI DALAM GAME
local function showNotification(title, text, duration)
    local StarterGui = game:GetService("StarterGui")
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 5
        })
    end)
end

print("🔍 Mendeteksi Game ID...")
print("Game ID (PlaceId): " .. game.PlaceId)

-- ⭐ Ambil nama game
local gameName = "Unknown Game"
pcall(function()
    gameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
end)
print("Game Name: " .. gameName)

-- ═══════════════════════════════════════════════════════
-- ⚙️ DAFTAR GAME ID (PlaceId) DISINI
-- ═══════════════════════════════════════════════════════
local GAME_IDS = {
    ["BREAK_STEAL_EGG"] = 114326934417838, -- Break & Steal An Egg
    ["STEAL_AN_EGG"] = 107778070777162,    -- Steal An Egg
}

-- ═══════════════════════════════════════════════════════
-- 🧠 SCRIPT 1: KHUSUS BREAK AND STEAL AN EGG
-- ═══════════════════════════════════════════════════════
local function runBreakAndStealScript()
    print("🚀 Menjalankan Script: Break & Steal An Egg (Leaderstats)")
    
    -- ⭐ Notifikasi V-Ziir0 Hub Active
    showNotification("⚡ V-Ziir0 Hub Active", "Monitor Break & Steal Berhasil Dijalankan!", 5)
    
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
        while task.wait(INTERVAL) do
            local cash, speed = getMyData()
            if cash ~= lastCash or speed ~= lastSpeed then
                sendToDiscord(cash, speed)
                lastCash, lastSpeed = cash, speed
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════
-- 🧠 SCRIPT 2: KHUSUS STEAL AN EGG
-- ═══════════════════════════════════════════════════════
local function runStealAnEggScript()
    print("🚀 Menjalankan Script: Steal An Egg (UI Scraper)")
    
    -- ⭐ Notifikasi V-Ziir0 Hub Active
    showNotification("⚡ V-Ziir0 Hub Active", "Monitor Steal An Egg Berhasil Dijalankan!", 5)
    
    local HttpService = game:GetService("HttpService")
    local WEBHOOK_URL = "https://discord.com/api/webhooks/1560789097440616529/097v0ksImZfYm2g4zSQKbEvb-9ttIwSHah-v5nxavKklco3t5S71rMR9vySSjOwtMEEn"
    local INTERVAL = 15
    local httpFn = request or http_request or (http and http.request)

    local lastMoney = nil
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
                if status == 200 or status == 204 then return true end
            end
            task.wait(1)
        end
        return false
    end

    local function formatNumber(num)
        local n = tonumber(num)
        if not n then return tostring(num) end
        local suffixes = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}
        local i = 1
        while n >= 1000 and i < #suffixes do
            n = n / 1000
            i = i + 1
        end
        if n % 1 == 0 then return string.format("%d%s", n, suffixes[i]) else return string.format("%.1f%s", n, suffixes[i]) end
    end

    local function cleanNumber(str)
        if not str then return "0" end
        str = tostring(str)
        str = str:gsub("[^%d%a%.%,]", "")
        str = str:gsub("[sS]$", "")
        return str ~= "" and str or "0"
    end

    local function getMyData()
        local money, speed = "0", "0"
        local ls = player:FindFirstChild("leaderstats")
        if ls then
            for _, stat in ipairs(ls:GetChildren()) do
                local n = stat.Name:lower()
                if n:find("money") or n:find("cash") or n:find("income") then
                    money = formatNumber(cleanNumber(stat.Value))
                elseif n:find("speed") or n:find("kecepatan") then
                    speed = formatNumber(cleanNumber(stat.Value))
                end
            end
            if money ~= "0" and speed ~= "0" then return money, speed end
        end

        local pg = player:FindFirstChild("PlayerGui")
        if pg then
            for _, gui in ipairs(pg:GetChildren()) do
                if gui:IsA("ScreenGui") then
                    for _, frame in ipairs(gui:GetDescendants()) do
                        if frame:IsA("Frame") and (frame.Name:lower():find("leader") or frame.Name:lower():find("board") or frame.Name:lower():find("player")) then
                            local texts = {}
                            for _, txt in ipairs(frame:GetDescendants()) do
                                if (txt:IsA("TextLabel") or txt:IsA("TextBox")) and txt.Text ~= "" then
                                    table.insert(texts, txt.Text)
                                end
                            end
                            
                            for i, t in ipairs(texts) do
                                local lowerT = t:lower()
                                if lowerT:find("money") or lowerT:find("income") or lowerT:find("uang") then
                                    local num = t:match("([%d%.%,]+[KMBTQa]?)")
                                    if num then money = formatNumber(cleanNumber(num)) else money = formatNumber(cleanNumber(texts[i+1] or "0")) end
                                end
                                if lowerT:find("speed") or lowerT:find("kecepatan") then
                                    local num = t:match("([%d%.%,]+[KMBTQa]?)")
                                    if num then speed = formatNumber(cleanNumber(num)) else speed = formatNumber(cleanNumber(texts[i+1] or "0")) end
                                end
                            end
                            if money ~= "0" and speed ~= "0" then return money, speed end
                        end
                    end
                end
            end
        end
        return money, speed
    end

    local function sendToDiscord(money, speed)
        local embed = {
            title = "🥚 STEAL AN EGG MONITOR 🥚",
            description = "```ini\n[ @" .. player.Name .. " ]```\n**━━━━━━━━━━━━━━━━━━━━━━━━**",
            color = 0xFFAA00,
            fields = {
                { name = "💰 ▸ INCOME", value = "```yaml\n" .. money .. "```", inline = true },
                { name = "⚡ ▸ SPEED", value = "```yaml\n" .. speed .. "```", inline = true },
                { name = "🎯 ▸ STATUS", value = "```diff\n+ FARMING ACTIVE```", inline = false },
            },
            footer = { text = "V-Ziir0 Hub • " .. os.date("%H:%M:%S") },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }
        sendWebhook({ username = "🥚 Egg Monitor", avatar_url = "https://cdn-icons-png.flaticon.com/512/1055/1055687.png", embeds = { embed } })
    end

    task.spawn(function()
        while task.wait(INTERVAL) do
            local money, speed = getMyData()
            if money ~= lastMoney or speed ~= lastSpeed then
                sendToDiscord(money, speed)
                lastMoney, lastSpeed = money, speed
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════
-- ⚡ EKSEKUSI BERDASARKAN GAME ID
-- ═══════════════════════════════════════════════════════

if game.PlaceId == GAME_IDS["BREAK_STEAL_EGG"] then
    runBreakAndStealScript()
elseif game.PlaceId == GAME_IDS["STEAL_AN_EGG"] then
    runStealAnEggScript()
else
    warn("❌ Game ID (" .. game.PlaceId .. ") tidak dikenali!")
    showNotification("❌ V-Ziir0 Hub Error", "Game ini belum di-support.", 8)
end