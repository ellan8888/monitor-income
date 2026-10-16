-- ═══════════════════════════════════════════════════════
-- MONITOR INCOME v4 — Multi-Akun, 1 Webhook
-- Fitur:
--   ✅ Format angka bersih ($ hilang)
--   ✅ Kirim cuma kalau berubah (anti-spam)
--   ✅ Support 4+ akun (copy paste yang sama)
--   ✅ Potassium-optimized
-- ═══════════════════════════════════════════════════════

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

-- ⭐ GANTI INI (sama buat semua akun) ⭐
local WEBHOOK_URL = "https://discord.com/api/webhooks/1560789097440616529/097v0ksImZfYm2g4zSQKbEvb-9ttIwSHah-v5nxavKklco3t5S71rMR9vySSjOwtMEEn"
local INTERVAL = 15

-- ⭐ Potassium: `request` paling stabil
local httpFn = request or http_request or (http and http.request)

if not httpFn then
    warn("❌ Nggak ada fungsi request!")
    return
end

print("✅ Pakai request function")
print("✅ Akun: @" .. player.Name)

-- ⭐ State — simpan nilai terakhir (buat cek perubahan)
local lastCash = nil
local lastSpeed = nil

-- ⭐ Kirim webhook dengan retry
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
            else
                warn("⚠️ Attempt " .. attempt .. ": status " .. tostring(status))
            end
        else
            warn("⚠️ Attempt " .. attempt .. ": " .. tostring(result))
        end
        
        task.wait(1)
    end
    
    warn("❌ Webhook gagal setelah 3x retry")
    return false
end

-- ⭐ Bersihin format angka
--   "$50T/s"  → "50T"
--   "$0/s"    → "0"
--   "115.5Qa" → "115.5Qa" (tetap)
local function cleanNumber(str)
    str = tostring(str)
    str = str:gsub("%$", "")       -- hilangin $
    str = str:gsub("/s", "")       -- hilangin /s
    str = str:gsub("%s+", "")      -- hilangin spasi
    return str
end

-- ⭐ Baca data dari leaderstats
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

-- ⭐ Kirim ke Discord
local function sendToDiscord(cash, speed)
    local embed = {
        title = "⚡ FARMING MONITOR ⚡",
        description = "```ini\n[ @" .. player.Name .. " ]```\n**━━━━━━━━━━━━━━━━━━━━━━━━**",
        color = 0x00FFAA,  -- neon green
        fields = {
            { 
                name = "💰 ▸ INCOME", 
                value = "```yaml\n" .. cash .. "```", 
                inline = true 
            },
            { 
                name = "⚡ ▸ SPEED", 
                value = "```yaml\n" .. speed .. "```", 
                inline = true 
            },
            {
                name = "🎯 ▸ STATUS",
                value = "```diff\n+ FARMING ACTIVE```",
                inline = false
            },
        },
        footer = { 
            text = "🎮 Roblox Farming Bot • " .. os.date("%H:%M:%S"),
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
    
    sendWebhook({
        username = "⚡ Farming Monitor",
        avatar_url = "https://cdn-icons-png.flaticon.com/512/1055/1055687.png",
        embeds = { embed },
    })
end

-- ⭐ Loop utama
print("✅ Monitor income aktif — kirim tiap " .. INTERVAL .. " detik")
print("   Cuma kirim kalau angka berubah")

task.spawn(function()
    while task.wait(INTERVAL) do
        local cash, speed = getMyData()
        
        -- ⭐ Kirim cuma kalau berubah
        if cash ~= lastCash or speed ~= lastSpeed then
            sendToDiscord(cash, speed)
            print("📤 Kirim: " .. cash .. " | " .. speed)
            lastCash, lastSpeed = cash, speed
        else
            print("⏸️ Skip (nggak berubah): " .. cash .. " | " .. speed)
        end
    end
end)
