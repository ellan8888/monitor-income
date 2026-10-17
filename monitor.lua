-- ═══════════════════════════════════════════════════════
-- 🚀 V-Ziir0 Hub Universal Monitor (Loader)
-- ═══════════════════════════════════════════════════════

local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- ⭐ FUNGSI NOTIFIKASI UI DI DALAM GAME
local function showNotification(title, text, duration)
    local StarterGui = game:GetService("StarterGui")
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title, Text = text, Duration = duration or 5
        })
    end)
end

print("🔍 V-Ziir0 Hub: Mendeteksi Game ID: " .. game.PlaceId)

-- ═══════════════════════════════════════════════════════
-- ⚙️ DAFTAR GAME & LINK SCRIPT NYA
-- ═══════════════════════════════════════════════════════
local GAME_SCRIPTS = {
    [114326934417838] = "https://raw.githubusercontent.com/ellan8888/monitor-income/main/games/break_and_steal.lua", -- Break & Steal An Egg
    [107778070777162] = "https://raw.githubusercontent.com/ellan8888/monitor-income/main/games/steal_an_egg.lua",    -- Steal An Egg
    
    -- 📌 CARA NAMBAH GAME BARU (Tinggal copy baris ini, hapus tanda --):
    -- [ID_GAME_BARU] = "https://raw.githubusercontent.com/ellan8888/monitor-income/main/games/NAMA_FILE.lua",
}

-- ═══════════════════════════════════════════════════════
-- ⚡ EKSEKUSI
-- ═══════════════════════════════════════════════════════
local scriptUrl = GAME_SCRIPTS[game.PlaceId]

if scriptUrl then
    showNotification("⚡ V-Ziir0 Hub Active", "Mempersiapkan Monitor...", 5)
    print("📥 Mengunduh script monitor khusus game ini...")
    
    local success, err = pcall(function()
        loadstring(game:HttpGet(scriptUrl))()
    end)
    
    if not success then
        warn("❌ Gagal download script: " .. tostring(err))
        showNotification("❌ V-Ziir0 Hub Error", "Gagal mengunduh script.", 5)
    end
else
    warn("❌ Game ID (" .. game.PlaceId .. ") tidak dikenali!")
    showNotification("❌ V-Ziir0 Hub Error", "Game ini belum di-support.", 8)
end