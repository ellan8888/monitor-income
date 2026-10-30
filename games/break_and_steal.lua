-- ═══════════════════════════════════════════════════════
-- ✨ V-Ziir0 Hub: Break & Steal (v37 - UI sidebar + kartu: Monitor / Auto Buy / Pengaturan)
-- ═══════════════════════════════════════════════════════

-- ⭐ SISTEM ANTI-DOUBLE
local CoreGui = game:GetService("CoreGui")
local genv = (getgenv and getgenv()) or _G
local MY_RUN_ID = tostring(os.clock()) .. "-" .. tostring(math.random(1, 1e9))

if genv.VZiir0_RunId and genv.VZiir0_LastStart and (os.time() - genv.VZiir0_LastStart) < 8 then
    print("⚠️ Instance lain baru jalan, skip yang ini.")
    return
end

genv.VZiir0_RunId = MY_RUN_ID
genv.VZiir0_LastStart = os.time()

local function isCurrent()
    return genv.VZiir0_RunId == MY_RUN_ID
end

local player = game.Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

if not player.Character then
    player.CharacterAdded:Wait()
    task.wait(2)
end
if not isCurrent() then return end

local WEBHOOK_URL = "https://discord.com/api/webhooks/1560789097440616529/097v0ksImZfYm2g4zSQKbEvb-9ttIwSHah-v5nxavKklco3t5S71rMR9vySSjOwtMEEn"
local INTERVAL = 2 
local httpFn = request or http_request or (http and http.request)

if not httpFn then warn("❌ Nggak ada fungsi request!"); return end

-- ═══════════════════════════════════════════════════════
-- ⭐ MASTER CONFIG (EDIT DI SINI KALAU MAU GANTI INCOME/SPEED)
-- ═══════════════════════════════════════════════════════
local MASTER_CONFIG = {
    -- Format: ["Nama Pickaxe"] = { income = Angka, speed = Angka }
    ["Haunted Pickaxe"] = { income = 5e12, speed = 2e12 },
    ["Enchanted Pickaxe"] = { income = 2e12, speed = 1e12 },  -- 2T Income, 1T Speed
    ["Celestial Pickaxe"] = { income = 1e12, speed = 500e9 }, -- 1T Income, 500B Speed
    
    -- Kalau ada pickaxe baru dari game, tambahin di sini (contoh):
    -- ["Haunted Pickaxe"] = { income = 3e12, speed = 1.5e12 },
}

local DEFAULT_INCOME = 2e12
local DEFAULT_SPEED = 1e12 

-- ⭐ STATE GLOBAL
local is_monitoring = false
local targetIncome = 0
local targetSpeedValue = 0
local is_speed_done = false 
local is_income_done = false 
local is_buying_pickaxe = false 
local activeProfileName = "None"
local is_farm_stopped = false
local lastMoney, lastSpeed = nil, nil
local lastWebhookTime = 0 
local lastSpeedCheck = 0
local stuckTimer = 0
local hasSpeedIncreased = false
local isAutoJumpEnabled = false
local lastKnownPickaxe = "None"
local isAutoRespawnIdle = true   -- ⭐ default ON saat monitor aktif
local IDLE_TIMEOUT     = 10      -- detik diam sebelum respawn (bisa diubah di Pengaturan)
local IDLE_MOVE_TH     = 2       -- stud, dianggap gerak kalau geser > ini
local idleLastPos      = nil
local idleTimeAccum    = 0
local isRespawningIdle = false
local isAutoRespawnLocked = false   -- ⭐ true saat monitor aktif

local lastSpeedSeen = 0
local lastSpeedIncreaseTime = 0
local TREADMILL_GRACE = 10   -- detik: speed naik dalam rentang ini = lagi treadmill

-- ⭐ PENGATURAN (bisa diubah dari tab Pengaturan)
local STUCK_TIMEOUT = 6        -- detik speed macet sebelum auto jump
local WEBHOOK_INTERVAL = 15    -- detik jeda kirim webhook
local notifEnabled = true      -- pop-up notifikasi di layar

-- ⭐ STATE AUTO BUY
local autoBuyEnabled = false
local targetPickaxeName = "Kapak Ajaib" 
local targetPickaxeId = 7 
local targetBuyPrice = 2000 * 1e15 
local buyStatus = "None"
local hasCheckedOwnership = false
local hasCheckedTarget = false 
local lastTargetProbe = 0
local prereqName = "Galaxy"
local prereqId = 17
local prereqPrice = 4 * 1e15

-- ⭐ FUNGSI SAVE/LOAD STATE
local STATE_KEY = "VZiir0_SavedProfile"
local function saveState(profileName)
    _G[STATE_KEY] = profileName
    if writefile then pcall(function() writefile("vziir0_state.txt", profileName) end) end
end
local function loadState()
    if _G[STATE_KEY] and _G[STATE_KEY] ~= "" and _G[STATE_KEY] ~= "None" then return _G[STATE_KEY] end
    if readfile and isfile and isfile("vziir0_state.txt") then
        local ok, content = pcall(function() return readfile("vziir0_state.txt") end)
        if ok and content and content ~= "" then return content end
    end
    return nil
end
local function clearState()
    _G[STATE_KEY] = nil
    if writefile then pcall(function() writefile("vziir0_state.txt", "") end) end
end

-- ⭐ AUTO-DETECT PICKAXE DARI GAME
local function formatNumberAuto(num)
    local n = tonumber(num)
    if not n then return "?" end
    local suffixes = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}
    local i = 1
    while n >= 1000 and i < #suffixes do n = n / 1000; i = i + 1 end
    if n % 1 == 0 then return string.format("%d%s", n, suffixes[i]) else return string.format("%.1f%s", n, suffixes[i]) end
end

local PICKAXE_DB = {}

local function LoadPickaxeDB()
    PICKAXE_DB = {} 
    local success, config = pcall(function()
        return require(ReplicatedStorage.Shared.PickaxeConfig)
    end)

    if success and config and config.Tiers then
        for id, data in ipairs(config.Tiers) do
            local rawPrice = data.Price or 0
            table.insert(PICKAXE_DB, {
                name = data.Name,
                id = id,
                priceRaw = rawPrice,
                priceStr = "$" .. formatNumberAuto(rawPrice)
            })
        end
        print("✅ [Auto-Detect] Berhasil load " .. #PICKAXE_DB .. " pickaxe dari game!")
    else
        warn("❌ Gagal load PickaxeConfig!")
    end
end
LoadPickaxeDB()

-- ⭐ SINKRONISASI PROFIL (AUTO-CLONE DENGAN MASTER CONFIG)
local CONFIG_DB = {}

local function SyncConfigDB()
    CONFIG_DB = {} 
    if #PICKAXE_DB == 0 then return end

    local targetIdx20, targetIdx18
    for i, pk in ipairs(PICKAXE_DB) do
        if pk.id == 20 then targetIdx20 = i end
        if pk.id == 18 then targetIdx18 = i end
    end

    -- 1. SETUP PROFIL STATIS (Income 1T tetap Celestial)
    local pk18 = PICKAXE_DB[targetIdx18] or PICKAXE_DB[18]
    local cfg18 = MASTER_CONFIG[pk18.name] or { income = 1e12, speed = 500e9 }
    
    table.insert(CONFIG_DB, {
        name = "Akun Income 1T", 
        amount = cfg18.income, targetSpeed = cfg18.speed,
        pickaxeId = pk18.id, pickaxeName = pk18.name, pickaxePrice = pk18.priceRaw,
        prereqId = PICKAXE_DB[17].id, prereqName = PICKAXE_DB[17].name, prereqPrice = PICKAXE_DB[17].priceRaw
    })

    -- 2. PROSES ANTREAN MAX ACC & CLONE-NYA
    local latestIndex = #PICKAXE_DB
    local GALAXY_ID = 17

    if latestIndex > 20 then
        local newPickaxesCount = latestIndex - 20
        
        for i = 1, newPickaxesCount do
            local cloneIdx = 20 + (i - 1) 
            local pkClone = PICKAXE_DB[cloneIdx]
            local cfgClone = MASTER_CONFIG[pkClone.name] or { income = DEFAULT_INCOME, speed = DEFAULT_SPEED }
            
            table.insert(CONFIG_DB, {
                name = "Income " .. formatNumberAuto(cfgClone.income), 
                amount = cfgClone.income, 
                targetSpeed = cfgClone.speed, 
                pickaxeId = pkClone.id, pickaxeName = pkClone.name, pickaxePrice = pkClone.priceRaw, 
                prereqId = PICKAXE_DB[GALAXY_ID].id, 
                prereqName = PICKAXE_DB[GALAXY_ID].name, 
                prereqPrice = PICKAXE_DB[GALAXY_ID].priceRaw
            })
        end

        local newPk = PICKAXE_DB[latestIndex]
        local cfgNew = MASTER_CONFIG[newPk.name] or { income = DEFAULT_INCOME, speed = DEFAULT_SPEED }
        
        table.insert(CONFIG_DB, {
            name = "Max Account (Terbaru)", 
            amount = cfgNew.income, 
            targetSpeed = cfgNew.speed, 
            pickaxeId = newPk.id, pickaxeName = newPk.name, pickaxePrice = newPk.priceRaw, 
            prereqId = PICKAXE_DB[GALAXY_ID].id, 
            prereqName = PICKAXE_DB[GALAXY_ID].name, 
            prereqPrice = PICKAXE_DB[GALAXY_ID].priceRaw
        })

        -- ⭐ tandai profil hasil deteksi pickaxe baru (untuk label "baru" & filter)
        for idx = 2, #CONFIG_DB do
            CONFIG_DB[idx].isNew = true
        end
    else
        local maxPk = PICKAXE_DB[targetIdx20]
        local cfgMax = MASTER_CONFIG[maxPk.name] or { income = DEFAULT_INCOME, speed = DEFAULT_SPEED }
        
        table.insert(CONFIG_DB, {
            name = "Max Account (Income " .. formatNumberAuto(cfgMax.income) .. ")", 
            amount = cfgMax.income, targetSpeed = cfgMax.speed,
            pickaxeId = maxPk.id, pickaxeName = maxPk.name, pickaxePrice = maxPk.priceRaw,
            prereqId = PICKAXE_DB[GALAXY_ID].id, 
            prereqName = PICKAXE_DB[GALAXY_ID].name, 
            prereqPrice = PICKAXE_DB[GALAXY_ID].priceRaw
        })
    end
end
SyncConfigDB()

-- ⭐ FUNGSI PENDUKUNG
local function StripEmoji(s)
    s = tostring(s)
    local ok, out = pcall(function()
        local buf = {}
        for _, cp in utf8.codes(s) do
            local isEmoji = cp >= 0x1F000 or (cp >= 0x2600 and cp <= 0x27BF) or (cp >= 0x2B00 and cp <= 0x2BFF) or (cp >= 0x23E9 and cp <= 0x23FF) or cp == 0xFE0F or cp == 0x200D
            if not isEmoji then table.insert(buf, utf8.char(cp)) end
        end
        return table.concat(buf)
    end)
    if not ok then return s end
    return (out:gsub("^%s+", ""))
end

local function showNotif(title, text, duration)
    pcall(function() StarterGui:SetCore("SendNotification", { Title = StripEmoji(title), Text = StripEmoji(text), Duration = duration or 5 }) end)
end

local function getPickaxeName()
    for _, item in ipairs(player:GetDescendants()) do
        if item:IsA("Tool") then
            local toolName = string.lower(item.Name)
            local tooltip = ""
            local success, res = pcall(function() return item.ToolTip end)
            if success and res then tooltip = string.lower(res) end
            if string.find(toolName, "pickaxe") or string.find(tooltip, "pickaxe") then
                if res and res ~= "" then lastKnownPickaxe = res; return res
                else lastKnownPickaxe = item.Name; return item.Name end
            end
        end
    end
    local char = player.Character
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") then
                local toolName = string.lower(item.Name)
                local tooltip = ""
                local success, res = pcall(function() return item.ToolTip end)
                if success and res then tooltip = string.lower(res) end
                if string.find(toolName, "pickaxe") or string.find(tooltip, "pickaxe") then
                    if res and res ~= "" then lastKnownPickaxe = res; return res
                    else lastKnownPickaxe = item.Name; return item.Name end
                end
            end
        end
    end
    return lastKnownPickaxe
end

-- ⭐ STATE EQUIP: kapak terbaik yang PASTI dimiliki
local ownedBestId = nil

local function norm(s) return string.lower(tostring(s or "")) end

local function equipPickaxe(id)
    local Event = ReplicatedStorage:FindFirstChild("PickaxeShopRequest")
    if Event and id then pcall(function() Event:FireServer("Equip", id) end) end
end

local function toolTip(tool)
    local tip = ""
    pcall(function() tip = tool.ToolTip end)
    return norm(tip)
end

-- cocokkan tool ke ID pickaxe: exact match dulu, lalu nama TERPANJANG yang
-- terkandung di tool (bukan sebaliknya, supaya "pickaxe" tidak match Wood)
local function resolvePickaxeId(tool)
    if not tool then return nil end
    local cands = { toolTip(tool), norm(tool.Name) }
    for _, c in ipairs(cands) do
        if c ~= "" then
            for _, pk in ipairs(PICKAXE_DB) do
                if norm(pk.name) == c then return pk.id end
            end
        end
    end
    local bestId, bestLen = nil, 0
    for _, c in ipairs(cands) do
        for _, pk in ipairs(PICKAXE_DB) do
            local n = norm(pk.name)
            if #n > bestLen and string.find(c, n, 1, true) then
                bestId, bestLen = pk.id, #n
            end
        end
    end
    return bestId
end

local function toolMatches(tool, targetName)
    local t = norm(targetName)
    return string.find(norm(tool.Name), t, 1, true) ~= nil
        or string.find(toolTip(tool), t, 1, true) ~= nil
end

local function checkOwnershipSilent(targetName, targetId)
    local char = player.Character
    if not char then return false end
    local Event = ReplicatedStorage:FindFirstChild("PickaxeShopRequest")
    if not Event then return false end

    -- sudah dipegang? tidak perlu probe sama sekali
    local currentTool = char:FindFirstChildWhichIsA("Tool")
    if currentTool and toolMatches(currentTool, targetName) then
        ownedBestId = math.max(ownedBestId or 0, targetId)
        return true
    end

    local previousId = resolvePickaxeId(currentTool)
    if previousId then ownedBestId = math.max(ownedBestId or 0, previousId) end

    Event:FireServer("Equip", targetId)
    task.wait(0.6)

    local hasTarget = false
    local c2 = player.Character
    if c2 then
        for _, tool in ipairs(c2:GetChildren()) do
            if tool:IsA("Tool") and toolMatches(tool, targetName) then
                hasTarget = true
                break
            end
        end
    end

    if hasTarget then ownedBestId = math.max(ownedBestId or 0, targetId) end

    -- selalu kembalikan ke kapak terbaik yang pasti dimiliki (bukan tebakan nama)
    local restoreId = ownedBestId or previousId
    if restoreId and not (hasTarget and restoreId == targetId) then
        equipPickaxe(restoreId)
    end
    return hasTarget
end

local function sendWebhook(payload)
    local body = HttpService:JSONEncode(payload)
    for attempt = 1, 3 do
        local ok, result = pcall(function() return httpFn({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body }) end)
        if ok then
            local status = nil
            if type(result) == "table" then status = result.Status or result.StatusCode end
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
    while n >= 1000 and i < #suffixes do n = n / 1000; i = i + 1 end
    if n % 1 == 0 then return string.format("%d%s", n, suffixes[i]) else return string.format("%.1f%s", n, suffixes[i]) end
end

local function cleanNumber(str)
    if not str then return "0" end
    str = tostring(str):gsub("[^%d%a%.%,]", ""):gsub("[sS]$", "")
    return str ~= "" and str or "0"
end

local function parseNumber(str)
    local s = tostring(str):upper():gsub("[$S/]", ""):gsub("%s", ""):gsub(",", ".")
    local mult = 1
    if s:find("K") then mult = 1e3; s = s:gsub("K","")
    elseif s:find("M") then mult = 1e6; s = s:gsub("M","")
    elseif s:find("B") then mult = 1e9; s = s:gsub("B","")
    elseif s:find("T") then mult = 1e12; s = s:gsub("T","")
    elseif s:find("QA") then mult = 1e15; s = s:gsub("QA","")
    end
    return (tonumber(s) or 0) * mult
end

local function getMyData()
    local money, speed = "0", "0"
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        for _, stat in ipairs(ls:GetChildren()) do
            local n = stat.Name:lower()
            if n:find("money") or n:find("cash") or n:find("income") then money = formatNumber(cleanNumber(stat.Value))
            elseif n:find("speed") or n:find("kecepatan") then speed = formatNumber(cleanNumber(stat.Value)) end
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
                            if (txt:IsA("TextLabel") or txt:IsA("TextBox")) and txt.Text ~= "" then table.insert(texts, txt.Text) end
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

local function getRealCash()
    -- sumber utama: attribute mentah (angka asli, tanpa parsing suffix)
    local c = player:GetAttribute("Cash")
    if type(c) == "number" then return c end

    -- fallback: parsing teks HUD
    local pg = player:FindFirstChild("PlayerGui")
    local mainGui = pg and pg:FindFirstChild("MainGUI")
    local currencies = mainGui and mainGui:FindFirstChild("Currencies")
    local cashObj = currencies and currencies:FindFirstChild("Cash")
    local amountText = cashObj and cashObj:FindFirstChild("Amount")
    if amountText and amountText:IsA("TextLabel") then
        local numberPart = amountText.Text:match("%$(.*)")
        if numberPart then return parseNumber(numberPart) end
    end
    return 0
end

local function sendToDiscord(money, speed, status_text)
    local pickaxeInfo = "None"
    local pickaxeProgress = "-"
    if autoBuyEnabled then
        pickaxeInfo = targetPickaxeName
        local currentCash = getRealCash()
        pickaxeProgress = formatNumber(currentCash) .. " / " .. formatNumber(targetBuyPrice)
    end
    local equippedInfo = getPickaxeName()

    local embed = {
        title = "🔒 BREAK & STEAL MONITOR 🔒",
        description = "```ini\n[ @" .. player.Name .. " ]```\n**━━━━━━━━━━━━━━━━━━━━━━━━**",
        color = is_farm_stopped and 0x2ECC71 or 0x00FFAA,
        fields = {
            { name = "💰 ▸ INCOME", value = "```yaml\n" .. tostring(money) .. "```", inline = true },
            { name = "⚡ ▸ SPEED", value = "```yaml\n" .. tostring(speed) .. "```", inline = true },
            { name = "🎯 ▸ PROFILE", value = "```yaml\n" .. tostring(activeProfileName or "None") .. "```", inline = true },
            { name = "⚔️ ▸ EQUIPPED", value = "```yaml\n" .. tostring(equippedInfo) .. "```", inline = true },
            { name = "🛒 ▸ TARGET", value = "```yaml\n" .. tostring(pickaxeInfo) .. "```", inline = true },
            { name = "⏳ ▸ PROGRESS", value = "```yaml\n" .. tostring(pickaxeProgress) .. "```", inline = true },
            { name = " ", value = " ", inline = true },
            { name = "📌 ▸ STATUS", value = "```diff\n" .. (status_text or "+ FARMING ACTIVE") .. "```", inline = false },
        },
        footer = { text = "V-Ziir0 Hub • " .. os.date("%H:%M:%S") },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
    sendWebhook({ username = "🔒 Break & Steal Monitor", avatar_url = "https://cdn-icons-png.flaticon.com/512/1055/1055687.png", embeds = { embed } })
end

local function stopAutoFarm()
    pcall(function()
        if getgenv().AutoFarm then getgenv().AutoFarm = false end
        if getgenv().Farm then getgenv().Farm = false end
        if _G.AutoFarm then _G.AutoFarm = false end
        if shared.AutoFarm then shared.AutoFarm = false end
        if getgenv().AutoFarmEgg then getgenv().AutoFarmEgg = false end
    end)
    local targetLabel = nil
    for _, gui in pairs(CoreGui:GetDescendants()) do
        if gui:IsA("TextLabel") and gui.Text:lower() == "auto farm eggs" then targetLabel = gui; break end
    end
    if targetLabel then
        local parent = targetLabel.Parent
        for _, sibling in pairs(parent:GetChildren()) do
            if (sibling:IsA("TextButton") or sibling:IsA("ImageButton")) and sibling.AbsolutePosition.X < targetLabel.AbsolutePosition.X then
                pcall(function() firesignal(sibling.MouseButton1Click) end)
                pcall(function() sibling:Activate() end)
                break
            end
        end
    end
end

local function startAutoFarm()
    pcall(function()
        if getgenv().AutoFarm then getgenv().AutoFarm = true end
        if getgenv().Farm then getgenv().Farm = true end
        if _G.AutoFarm then _G.AutoFarm = true end
        if shared.AutoFarm then shared.AutoFarm = true end
        if getgenv().AutoFarmEgg then getgenv().AutoFarmEgg = true end
    end)
    local targetLabel = nil
    for _, gui in pairs(CoreGui:GetDescendants()) do
        if gui:IsA("TextLabel") and gui.Text:lower() == "auto farm eggs" then targetLabel = gui; break end
    end
    if targetLabel then
        local parent = targetLabel.Parent
        for _, sibling in pairs(parent:GetChildren()) do
            if (sibling:IsA("TextButton") or sibling:IsA("ImageButton")) and sibling.AbsolutePosition.X < targetLabel.AbsolutePosition.X then
                pcall(function() firesignal(sibling.MouseButton1Click) end)
                pcall(function() sibling:Activate() end)
                break
            end
        end
    end
    showNotif("🚀 AUTO FARM", "Auto Farm dinyalakan lagi!", 5)
end

-- ⭐ DETEKSI TREADMILL: speed naik = karakter lagi aktif (jangan respawn)
local function getRawSpeed()
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        for _, stat in ipairs(ls:GetChildren()) do
            local n = stat.Name:lower()
            if n:find("speed") or n:find("kecepatan") then
                local v = tonumber(stat.Value)
                if v then return v end
            end
        end
    end
    return nil
end

local function updateSpeedActivity(speed_str)
    local cur = getRawSpeed() or parseNumber(speed_str)
    if cur > lastSpeedSeen and lastSpeedSeen > 0 then
        lastSpeedIncreaseTime = os.clock()
    end
    lastSpeedSeen = cur
end

-- ⭐ DETEKSI TREADMILL VIA REMOTE (akurat, tidak terpengaruh pembulatan)
local lastSpeedGainTime = 0
task.spawn(function()
    local remote = ReplicatedStorage:WaitForChild("SpeedGainRemote", 30)
    if not remote then
        warn("❌ SpeedGainRemote nggak ketemu, fallback ke deteksi lama")
        return
    end
    remote.OnClientEvent:Connect(function(gain, total)
        if not isCurrent() then return end
        lastSpeedGainTime = os.clock()
        lastSpeedIncreaseTime = os.clock()  -- ini yang dibaca tickIdleRespawn
    end)
end)

-- ⭐ AUTO RESPAWN IF IDLE (hanya jalan saat monitor / auto buy aktif)
local function tickIdleRespawn()
    if not isAutoRespawnIdle and not isAutoRespawnLocked then return end

    -- ⭐ toggle sendiri cukup untuk mengaktifkan auto respawn
    if not (is_monitoring or autoBuyEnabled or isAutoRespawnIdle) then
        idleLastPos = nil
        idleTimeAccum = 0
        isRespawningIdle = false
        return
    end

    local char = player.Character
    if not char then
        idleLastPos = nil
        idleTimeAccum = 0
        return
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then
        idleLastPos = nil
        idleTimeAccum = 0
        isRespawningIdle = false
        return
    end

    -- kalau sedang proses respawn, tunggu sampai hidup lagi
    if isRespawningIdle then
        return
    end

    -- ⭐ speed lagi naik (treadmill) → reset hitungan diam, jangan respawn
    if (os.clock() - lastSpeedIncreaseTime) < TREADMILL_GRACE then
        idleTimeAccum = 0
        idleLastPos = nil
        return
    end

    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local pos = root.Position

    -- kalau humanoid lagi gerak (misal lagi jalan ke target), reset
    if hum.MoveDirection.Magnitude > 0.1 then
        idleTimeAccum = 0
        idleLastPos = pos
        return
    end

    if idleLastPos == nil then
        idleLastPos = pos
        idleTimeAccum = 0
        return
    end

    local moved = (pos - idleLastPos).Magnitude
    if moved > IDLE_MOVE_TH then
        idleTimeAccum = 0
        idleLastPos = pos
    else
        idleTimeAccum = idleTimeAccum + INTERVAL
        if idleTimeAccum >= IDLE_TIMEOUT then
            idleTimeAccum = 0
            idleLastPos = nil
            isRespawningIdle = true
            pcall(function() hum.Health = 0 end)
            task.wait(0.3)
            if hum.Health > 0 then
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.Dead) end)
            end
            showNotif("♻️ AUTO RESPAWN", "Karakter diam " .. IDLE_TIMEOUT .. "s, respawn!", 4)
            task.wait(2)
        end
    end
end

-- reset idle state setiap kali karakter baru spawn
player.CharacterAdded:Connect(function()
    idleLastPos = nil
    idleTimeAccum = 0
    isRespawningIdle = false
end)

local function onTargetReached()
    is_farm_stopped = true
    stopAutoFarm()
    showNotif("🛑 TARGET TERCAPAI", "Auto Farm dimatikan untuk target " .. tostring(activeProfileName), 5)
end

local function tryBuyPickaxe()
    if not autoBuyEnabled then return end
    local currentMoney = getRealCash()
    local money_str = formatNumber(currentMoney)

    if not hasCheckedOwnership then
        local hasGalaxy = checkOwnershipSilent(prereqName, prereqId)
        if not hasGalaxy then
            if currentMoney >= prereqPrice then
                buyStatus = "⚡ MEMBELI " .. string.upper(prereqName) .. "..."
                local Event = ReplicatedStorage:FindFirstChild("PickaxeShopRequest")
                if Event then
                    Event:FireServer("Buy", prereqId)
                    task.wait(1)
                    Event:FireServer("Equip", prereqId)
                    ownedBestId = math.max(ownedBestId or 0, prereqId)
                    showNotif("🛒 BELI PREREQ", "Berhasil beli " .. prereqName .. "!", 5)
                    hasCheckedOwnership = false 
                end
                return
            else
                buyStatus = "⏳ NUNGGU UANG " .. string.upper(prereqName) .. ": (" .. money_str .. " / " .. formatNumber(prereqPrice) .. ")"
                return
            end
        else
            hasCheckedOwnership = true
            buyStatus = "✅ " .. prereqName .. " punya! Lanjut farming target utama..."
        end
    end

    if not hasCheckedTarget then
        hasCheckedTarget = true  -- probe awal cukup sekali
        if checkOwnershipSilent(targetPickaxeName, targetPickaxeId) then
            autoBuyEnabled = false
            buyStatus = "✅ " .. string.upper(targetPickaxeName) .. " SUDAH DIMILIKI!"
            return
        end
    end

    if currentMoney < targetBuyPrice then
        buyStatus = "⏳ NUNGGU UANG " .. targetPickaxeName .. ": (" .. money_str .. " / " .. formatNumber(targetBuyPrice) .. ")"
        return
    end

    -- uang cukup: cek ulang kepemilikan, dibatasi 20 detik sekali
    if (os.time() - (lastTargetProbe or 0)) >= 20 then
        lastTargetProbe = os.time()
        if checkOwnershipSilent(targetPickaxeName, targetPickaxeId) then
            autoBuyEnabled = false
            buyStatus = "✅ " .. string.upper(targetPickaxeName) .. " SUDAH DIMILIKI!"
            return
        end
    end
    
    buyStatus = "⚡ MEMBELI " .. string.upper(targetPickaxeName) .. "..."
    local ok, err = pcall(function()
        local Event = ReplicatedStorage:FindFirstChild("PickaxeShopRequest")
        if Event then
            Event:FireServer("Buy", targetPickaxeId)
        else
            warn("❌ PickaxeShopRequest nggak ketemu!")
        end
    end)
    
    if ok then
        showNotif("🛒 AUTO BUY BERHASIL", "Kamu telah membeli " .. targetPickaxeName .. "!", 5)
        buyStatus = "✅ Beli Sukses!"
        autoBuyEnabled = false 
        hasCheckedOwnership = false
        hasCheckedTarget = false
        
        if is_monitoring then
            is_farm_stopped = true 
            is_speed_done = false 
            is_income_done = false 
            is_buying_pickaxe = false
        end

        ownedBestId = math.max(ownedBestId or 0, targetPickaxeId)
        
        task.wait(1)
        pcall(function()
            local Event = ReplicatedStorage:FindFirstChild("PickaxeShopRequest")
            if Event then Event:FireServer("Equip", targetPickaxeId) end
        end)
        
        task.wait(1)
        local money_str_new, speed_str_new = getMyData()
        sendToDiscord(money_str_new, speed_str_new, "+ AUTO BUY SUCCESS (" .. targetPickaxeName .. ")")
    else
        buyStatus = "❌ Gagal beli."
        autoBuyEnabled = false
    end
end

-- ═══════════════════════════════════════════════════════
-- ⭐ UI CUSTOM (layout sidebar + kartu, tema oranye)
-- (banyak blok dibungkus do...end supaya tidak melewati batas 200 local)
-- ═══════════════════════════════════════════════════════
local Colors = {
    Background = Color3.fromRGB(15, 13, 12),
    Sidebar    = Color3.fromRGB(20, 17, 16),
    GlassPanel = Color3.fromRGB(22, 19, 18),   -- latar kartu
    Tile       = Color3.fromRGB(30, 26, 24),   -- latar tile / tombol kecil
    Border     = Color3.fromRGB(42, 37, 35),
    Accent     = Color3.fromRGB(240, 122, 43), -- ganti di sini kalau mau warna lain
    Text       = Color3.fromRGB(241, 236, 232),
    TextDim    = Color3.fromRGB(141, 131, 125),
    SwitchOff  = Color3.fromRGB(58, 50, 47),
    Green      = Color3.fromRGB(79, 227, 168),
    Amber      = Color3.fromRGB(245, 194, 107),
    Danger     = Color3.fromRGB(229, 72, 77),
    Track      = Color3.fromRGB(38, 33, 31),
    OnAccent   = Color3.fromRGB(43, 18, 4),
    ChipOn     = Color3.fromRGB(44, 28, 18),
}

-- isi dengan rbxassetid kalau mau pakai gambar; kosong = digambar dari frame
local Icons = {
    pickaxe = "", monitor = "", shop = "", target = "", crown = "", jump = "", close = "", minus = "",
    check = "", hourglass = "", bolt = "", checkc = "", xc = "", coin = "",
    settings = "", lock = "", clock = "", bell = "", trash = "", chevron = "", user = "",
}

local IconPaint = setmetatable({}, { __mode = "k" })

local IconDefs = {
    close = function(H) H.line(3.2, 3.2, 12.8, 12.8, 1.8); H.line(12.8, 3.2, 3.2, 12.8, 1.8) end,
    minus = function(H) H.line(3, 8, 13, 8, 1.8) end,
    check = function(H) H.line(3, 8.5, 6.5, 12, 1.9); H.line(6.5, 12, 13, 4.5, 1.9) end,
    pickaxe = function(H) H.line(3, 13, 11.3, 4.7, 1.8); H.line(7.5, 1, 14, 7.5, 2.2) end,
    monitor = function(H) H.rect(2, 9, 3, 5, 0.15); H.rect(6.5, 5, 3, 9, 0.15); H.rect(11, 2, 3, 12, 0.15) end,
    shop = function(H)
        H.line(1.5, 2.5, 3.8, 2.5, 1.6)
        H.line(3.8, 2.5, 5.2, 10, 1.6)
        H.line(5.2, 10, 13.2, 10, 1.6)
        H.line(13.2, 10, 14.2, 4.2, 1.6)
        H.line(4.3, 4.2, 14.2, 4.2, 1.6)
        H.dot(6.2, 12.9, 2.6); H.dot(12, 12.9, 2.6)
    end,
    target = function(H) H.ring(1.5, 1.5, 13, 13, 1.5); H.ring(4.5, 4.5, 7, 7, 1.5); H.dot(8, 8, 2.2) end,
    crown = function(H)
        H.line(3, 11.2, 3.4, 4.8, 1.6); H.line(3.4, 4.8, 6.2, 8.2, 1.6); H.line(6.2, 8.2, 8, 3.6, 1.6)
        H.line(8, 3.6, 9.8, 8.2, 1.6); H.line(9.8, 8.2, 12.6, 4.8, 1.6); H.line(12.6, 4.8, 13, 11.2, 1.6)
        H.line(3, 11.2, 13, 11.2, 1.6); H.line(3.6, 13.4, 12.4, 13.4, 1.6)
    end,
    jump = function(H) H.line(8, 13.5, 8, 3, 1.8); H.line(8, 2.8, 3.6, 7.2, 1.8); H.line(8, 2.8, 12.4, 7.2, 1.8) end,
    hourglass = function(H)
        H.line(4, 2.5, 12, 2.5, 1.6); H.line(4, 13.5, 12, 13.5, 1.6)
        H.line(4.8, 3.4, 11.2, 12.6, 1.5); H.line(11.2, 3.4, 4.8, 12.6, 1.5)
    end,
    bolt = function(H) H.line(9.8, 1.5, 4.5, 8.8, 1.8); H.line(4.5, 8.8, 11.5, 8.8, 1.8); H.line(11.5, 8.8, 6.2, 14.5, 1.8) end,
    checkc = function(H) H.ring(1.5, 1.5, 13, 13, 1.5); H.line(5, 8.2, 7.1, 10.3, 1.5); H.line(7.1, 10.3, 11, 5.8, 1.5) end,
    xc = function(H) H.ring(1.5, 1.5, 13, 13, 1.5); H.line(5.6, 5.6, 10.4, 10.4, 1.5); H.line(10.4, 5.6, 5.6, 10.4, 1.5) end,
    coin = function(H) H.ring(1.5, 1.5, 13, 13, 1.5); H.line(8, 4.6, 8, 11.4, 1.6) end,
    settings = function(H)
        H.ring(3.5, 3.5, 9, 9, 1.6); H.dot(8, 8, 2.2)
        H.line(8, 0.8, 8, 3, 1.5); H.line(8, 13, 8, 15.2, 1.5)
        H.line(0.8, 8, 3, 8, 1.5); H.line(13, 8, 15.2, 8, 1.5)
    end,
    lock = function(H) H.rect(3, 7.5, 10, 6.5, 0.2); H.ring(4.8, 1.8, 6.4, 7.4, 1.5) end,
    clock = function(H) H.ring(1.5, 1.5, 13, 13, 1.5); H.line(8, 4.4, 8, 8, 1.5); H.line(8, 8, 10.8, 9.6, 1.5) end,
    bell = function(H) H.ring(3.5, 2, 9, 9, 1.5); H.line(2.5, 12, 13.5, 12, 1.6); H.dot(8, 14.2, 2) end,
    trash = function(H)
        H.line(2.5, 4, 13.5, 4, 1.6); H.line(6.3, 2, 9.7, 2, 1.5)
        H.line(4.5, 5.5, 5.1, 13.5, 1.5); H.line(5.1, 13.5, 10.9, 13.5, 1.5); H.line(10.9, 13.5, 11.5, 5.5, 1.5)
    end,
    -- ⭐ ikon baru untuk layout sidebar
    chevron = function(H) H.line(4, 6, 8, 10, 1.6); H.line(8, 10, 12, 6, 1.6) end,
    user = function(H) H.dot(8, 5, 5); H.rect(3.5, 9.5, 9, 5, 0.5) end,
}

local function MakeIcon(parent, key, size, color)
    if Icons[key] and Icons[key] ~= "" then
        local img = Instance.new("ImageLabel")
        img.Image = Icons[key]
        img.ImageColor3 = color
        img.BackgroundTransparency = 1
        img.Size = UDim2.new(0, size, 0, size)
        img.Parent = parent
        return img
    end

    local root = Instance.new("Frame")
    root.BackgroundTransparency = 1
    root.BorderSizePixel = 0
    root.Size = UDim2.new(0, size, 0, size)
    local s = size / 16
    local painters = {}

    local function fill(f)
        f.BorderSizePixel = 0
        f.BackgroundColor3 = color
        f.Parent = root
        table.insert(painters, function(c) f.BackgroundColor3 = c end)
    end

    local H = {}
    function H.line(x1, y1, x2, y2, th)
        local dx, dy = x2 - x1, y2 - y1
        local len = math.sqrt(dx * dx + dy * dy)
        local f = Instance.new("Frame")
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.Position = UDim2.new(0, (x1 + x2) / 2 * s, 0, (y1 + y2) / 2 * s)
        f.Size = UDim2.new(0, (len + th) * s, 0, th * s)
        f.Rotation = math.deg(math.atan2(dy, dx))
        Instance.new("UICorner", f).CornerRadius = UDim.new(0.5, 0)
        fill(f)
    end
    function H.rect(x, y, w, h, rnd)
        local f = Instance.new("Frame")
        f.Position = UDim2.new(0, x * s, 0, y * s)
        f.Size = UDim2.new(0, w * s, 0, h * s)
        Instance.new("UICorner", f).CornerRadius = UDim.new(rnd or 0, 0)
        fill(f)
    end
    function H.dot(cx, cy, d)
        local f = Instance.new("Frame")
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.Position = UDim2.new(0, cx * s, 0, cy * s)
        f.Size = UDim2.new(0, d * s, 0, d * s)
        Instance.new("UICorner", f).CornerRadius = UDim.new(0.5, 0)
        fill(f)
    end
    function H.ring(x, y, w, h, th, rnd)
        local f = Instance.new("Frame")
        f.BackgroundTransparency = 1
        f.BorderSizePixel = 0
        f.Position = UDim2.new(0, (x + th) * s, 0, (y + th) * s)
        f.Size = UDim2.new(0, (w - 2 * th) * s, 0, (h - 2 * th) * s)
        Instance.new("UICorner", f).CornerRadius = UDim.new(rnd or 0.5, 0)
        local st = Instance.new("UIStroke", f)
        st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        st.Thickness = math.max(1, th * s)
        st.Color = color
        f.Parent = root
        table.insert(painters, function(c) st.Color = c end)
    end

    local draw = IconDefs[key]
    if draw then draw(H) else H.dot(8, 8, 6) end
    IconPaint[root] = function(c)
        for _, p in ipairs(painters) do p(c) end
    end
    root.Parent = parent
    return root
end

local function SetIconColor(ic, color)
    local paint = IconPaint[ic]
    if paint then paint(color)
    elseif ic:IsA("ImageLabel") then ic.ImageColor3 = color end
end

local function NewLabel(parent, text, size, font, color, align)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextSize = size
    l.Font = font
    l.TextColor3 = color
    l.TextXAlignment = align or Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

-- ⭐ gaya scrollbar seragam (tipis rata, warna aksen tema)
local function StyleScrollbar(sf)
    sf.BorderSizePixel = 0
    sf.ScrollBarThickness = 4
    sf.ScrollBarImageColor3 = Colors.Accent
    sf.ScrollBarImageTransparency = 0
    sf.VerticalScrollBarInset = Enum.ScrollBarInset.Always
    sf.ScrollingDirection = Enum.ScrollingDirection.Y
    sf.CanvasSize = UDim2.new(0, 0, 0, 0)
    sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
end

for _, gui in ipairs(CoreGui:GetChildren()) do
    if gui:IsA("ScreenGui") and gui.Name == "VZiir0HubGlass" then
        gui:Destroy()
    end
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VZiir0HubGlass"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999 
ScreenGui.Parent = CoreGui
_G.BreakSteal_Hub_UI = ScreenGui

-- ═══════════ [ NOTIF CUSTOM ] ═══════════
do
    local NOTIF_W, NOTIF_H = 300, 64
    local MAX_NOTIFS = 4

    local NotifHolder = Instance.new("Frame")
    NotifHolder.Name = "NotifHolder"
    NotifHolder.AnchorPoint = Vector2.new(1, 1)
    NotifHolder.Position = UDim2.new(1, -16, 1, -16)
    NotifHolder.Size = UDim2.new(0, NOTIF_W, 0, 420)
    NotifHolder.BackgroundTransparency = 1
    NotifHolder.Parent = ScreenGui

    local NotifLayout = Instance.new("UIListLayout", NotifHolder)
    NotifLayout.SortOrder = Enum.SortOrder.LayoutOrder
    NotifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    NotifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    NotifLayout.Padding = UDim.new(0, 8)

    local NotifScale = Instance.new("UIScale", NotifHolder)
    local function UpdateNotifScale()
        local vp = ScreenGui.AbsoluteSize
        if vp.X < 50 then return end
        NotifScale.Scale = math.clamp(math.min(1, (vp.X - 32) / NOTIF_W, vp.Y / 500), 0.6, 1)
    end
    UpdateNotifScale()
    ScreenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateNotifScale)

    local notifOrder = 0
    local activeNotifs = {}

    local function notifStyle(title)
        local up = tostring(title):upper()
        if up:find("BERHASIL", 1, true) or up:find("TERCAPAI", 1, true) then
            return "checkc", Colors.Green
        elseif up:find("RE-FARM", 1, true) or up:find("AUTO FARM", 1, true) then
            return "bolt", Colors.Accent
        elseif up:find("TARGET", 1, true) then
            return "target", Colors.Accent
        end
        return "shop", Colors.Amber
    end

    local function dismissNotif(entry)
        if entry.closed then return end
        entry.closed = true
        for i, e in ipairs(activeNotifs) do
            if e == entry then table.remove(activeNotifs, i) break end
        end
        local out = TweenService:Create(entry.card, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0, NOTIF_W + 40, 0, 0)
        })
        out:Play()
        out.Completed:Connect(function()
            local collapse = TweenService:Create(entry.wrap, TweenInfo.new(0.15), { Size = UDim2.new(1, 0, 0, 0) })
            collapse:Play()
            collapse.Completed:Connect(function() entry.wrap:Destroy() end)
        end)
    end

    local function buildNotif(title, text, duration)
        duration = duration or 5
        local iconKey, color = notifStyle(title)

        local cleanTitle = StripEmoji(title):lower()
        cleanTitle = cleanTitle:sub(1, 1):upper() .. cleanTitle:sub(2)
        local cleanText = StripEmoji((tostring(text):gsub("\n", " · "):gsub("→", ">")))

        notifOrder = notifOrder + 1
        local wrap = Instance.new("Frame")
        wrap.BackgroundTransparency = 1
        wrap.Size = UDim2.new(1, 0, 0, NOTIF_H)
        wrap.LayoutOrder = notifOrder
        wrap.Parent = NotifHolder

        local card = Instance.new("TextButton")
        card.AutoButtonColor = false
        card.Text = ""
        card.Size = UDim2.new(1, 0, 1, 0)
        card.Position = UDim2.new(0, NOTIF_W + 40, 0, 0)
        card.BackgroundColor3 = Colors.Background
        card.BackgroundTransparency = 0.03
        card.BorderSizePixel = 0
        card.Parent = wrap
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
        local stroke = Instance.new("UIStroke", card)
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Color = Colors.Border
        stroke.Thickness = 1

        local bar = Instance.new("Frame", card)
        bar.Size = UDim2.new(0, 4, 1, -24)
        bar.Position = UDim2.new(0, 8, 0, 8)
        bar.BackgroundColor3 = color
        bar.BorderSizePixel = 0
        Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

        local iconBox = Instance.new("Frame", card)
        iconBox.Size = UDim2.new(0, 32, 0, 32)
        iconBox.Position = UDim2.new(0, 22, 0, 10)
        iconBox.BackgroundColor3 = Colors.ChipOn
        iconBox.BorderSizePixel = 0
        Instance.new("UICorner", iconBox).CornerRadius = UDim.new(0, 8)
        local ic = MakeIcon(iconBox, iconKey, 18, color)
        ic.AnchorPoint = Vector2.new(0.5, 0.5)
        ic.Position = UDim2.new(0.5, 0, 0.5, 0)

        local t = NewLabel(card, cleanTitle, 13, Enum.Font.GothamBold, Colors.Text)
        t.Size = UDim2.new(1, -74, 0, 16)
        t.Position = UDim2.new(0, 64, 0, 8)
        t.TextTruncate = Enum.TextTruncate.AtEnd

        local s = NewLabel(card, cleanText, 11, Enum.Font.Gotham, Colors.TextDim)
        s.Size = UDim2.new(1, -74, 0, 26)
        s.Position = UDim2.new(0, 64, 0, 25)
        s.TextWrapped = true
        s.TextYAlignment = Enum.TextYAlignment.Top
        s.TextTruncate = Enum.TextTruncate.AtEnd

        local track = Instance.new("Frame", card)
        track.Size = UDim2.new(1, -32, 0, 3)
        track.Position = UDim2.new(0, 16, 1, -7)
        track.BackgroundColor3 = Colors.Track
        track.BorderSizePixel = 0
        Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
        local fill = Instance.new("Frame", track)
        fill.Size = UDim2.new(1, 0, 1, 0)
        fill.BackgroundColor3 = color
        fill.BorderSizePixel = 0
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

        local entry = { wrap = wrap, card = card, closed = false }
        table.insert(activeNotifs, entry)
        if #activeNotifs > MAX_NOTIFS then dismissNotif(activeNotifs[1]) end

        TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 0, 0, 0)
        }):Play()
        TweenService:Create(fill, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
            Size = UDim2.new(0, 0, 1, 0)
        }):Play()

        card.MouseButton1Click:Connect(function() dismissNotif(entry) end)
        task.delay(duration, function() dismissNotif(entry) end)
    end

    showNotif = function(title, text, duration)
        if not notifEnabled then return end   -- ⭐ bisa dimatikan dari Pengaturan
        local ok = pcall(buildNotif, title, text, duration)
        if not ok then
            pcall(function()
                StarterGui:SetCore("SendNotification", {
                    Title = StripEmoji(title), Text = StripEmoji(text), Duration = duration or 5
                })
            end)
        end
    end
end

-- ═══════════ [ FRAME UTAMA ] ═══════════
local SIDEBAR_W = 150
local FRAME_W, FRAME_H = 580, 400

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, FRAME_W, 0, FRAME_H)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.BackgroundColor3 = Colors.Background
MainFrame.BackgroundTransparency = 0.02
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Active = true
MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 14)
do
    local MainBorder = Instance.new("UIStroke", MainFrame)
    MainBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    MainBorder.Color = Colors.Border
    MainBorder.Thickness = 1

    -- ── Auto-scale untuk layar kecil (HP) ───────────────────
    local MainScale = Instance.new("UIScale", MainFrame)
    local function UpdateScale()
        local vp = ScreenGui.AbsoluteSize
        if vp.X < 50 or vp.Y < 50 then
            local cam = workspace.CurrentCamera
            vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
        end
        local s = math.min(1, (vp.X - 16) / FRAME_W, (vp.Y - 16) / FRAME_H)
        MainScale.Scale = math.clamp(s, 0.4, 1)
    end
    UpdateScale()
    ScreenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateScale)
end

-- ═══════════ [ WIDGET KECIL (kartu, tile, saklar, stepper, profil) ] ═══════════
local UI = {}   -- referensi elemen yang diperbarui dari luar
local W = {}    -- pabrik widget

-- kartu dengan header (klik header = lipat/buka)
W.Card = function(parent, title, iconKey, bodyH, order)
    local full = 36 + bodyH + 6
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, full)
    card.BackgroundColor3 = Colors.GlassPanel
    card.BorderSizePixel = 0
    card.LayoutOrder = order
    card.ClipsDescendants = true
    card.Parent = parent
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
    local st = Instance.new("UIStroke", card)
    st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    st.Thickness = 1
    st.Color = Colors.Border

    local ic = MakeIcon(card, iconKey, 15, Colors.Accent)
    ic.Position = UDim2.new(0, 12, 0, 8)
    local t = NewLabel(card, title, 12, Enum.Font.GothamBold, Colors.Text)
    t.Size = UDim2.new(0, 110, 0, 30)
    t.Position = UDim2.new(0, 34, 0, 0)

    local chev = MakeIcon(card, "chevron", 14, Colors.TextDim)
    chev.AnchorPoint = Vector2.new(0.5, 0.5)
    chev.Position = UDim2.new(1, -19, 0, 15)

    local div = Instance.new("Frame", card)
    div.Size = UDim2.new(1, -24, 0, 1)
    div.Position = UDim2.new(0, 12, 0, 30)
    div.BackgroundColor3 = Colors.Border
    div.BorderSizePixel = 0

    local body = Instance.new("Frame", card)
    body.Size = UDim2.new(1, -24, 0, bodyH)
    body.Position = UDim2.new(0, 12, 0, 36)
    body.BackgroundTransparency = 1

    local hdr = Instance.new("TextButton", card)
    hdr.Size = UDim2.new(1, 0, 0, 30)
    hdr.BackgroundTransparency = 1
    hdr.Text = ""
    hdr.ZIndex = 2
    local collapsed = false
    hdr.MouseButton1Click:Connect(function()
        collapsed = not collapsed
        body.Visible = not collapsed
        div.Visible = not collapsed
        chev.Rotation = collapsed and -90 or 0
        TweenService:Create(card, TweenInfo.new(0.15), { Size = UDim2.new(1, 0, 0, collapsed and 30 or full) }):Play()
    end)
    return card, body
end

-- tile angka (nilai besar + keterangan kecil); mengembalikan label nilai
W.Tile = function(parent, w, order, value, caption)
    local T = Instance.new("Frame")
    T.Size = UDim2.new(0, w, 0, 36)
    T.BackgroundColor3 = Colors.Tile
    T.BorderSizePixel = 0
    T.LayoutOrder = order
    T.Parent = parent
    Instance.new("UICorner", T).CornerRadius = UDim.new(0, 8)
    local V = NewLabel(T, value, 13, Enum.Font.GothamBold, Colors.Text)
    V.Size = UDim2.new(1, -12, 0, 16)
    V.Position = UDim2.new(0, 6, 0, 4)
    V.TextScaled = true
    local c = Instance.new("UITextSizeConstraint", V)
    c.MaxTextSize = 13
    c.MinTextSize = 8
    local C = NewLabel(T, caption, 10, Enum.Font.Gotham, Colors.TextDim)
    C.Size = UDim2.new(1, -12, 0, 12)
    C.Position = UDim2.new(0, 6, 0, 21)
    C.TextTruncate = Enum.TextTruncate.AtEnd
    return V
end

-- baris saklar (desc = nil → mode ringkas 26px)
W.Switch = function(parent, title, desc, iconKey, order, defaultState, bg)
    local compact = (desc == nil)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, compact and 26 or 44)
    Btn.BackgroundColor3 = bg or Colors.GlassPanel
    Btn.AutoButtonColor = false
    Btn.Text = ""
    Btn.LayoutOrder = order
    Btn.Parent = parent
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, compact and 8 or 10)
    local Stroke = Instance.new("UIStroke", Btn)
    Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    Stroke.Thickness = 1
    Stroke.Color = Colors.Border

    local Ic = MakeIcon(Btn, iconKey, 16, Colors.TextDim)
    Ic.Position = UDim2.new(0, 10, 0.5, -8)
    local T = NewLabel(Btn, title, 12, Enum.Font.GothamMedium, Colors.Text)
    T.TextTruncate = Enum.TextTruncate.AtEnd
    local D
    if compact then
        T.Size = UDim2.new(1, -100, 1, 0)
        T.Position = UDim2.new(0, 34, 0, 0)
    else
        T.Size = UDim2.new(1, -100, 0, 16)
        T.Position = UDim2.new(0, 34, 0, 6)
        D = NewLabel(Btn, desc, 10, Enum.Font.Gotham, Colors.TextDim)
        D.Size = UDim2.new(1, -100, 0, 14)
        D.Position = UDim2.new(0, 34, 0, 23)
        D.TextTruncate = Enum.TextTruncate.AtEnd
    end

    local LockIc = MakeIcon(Btn, "lock", 12, Colors.Accent)
    LockIc.Position = UDim2.new(1, -66, 0.5, -6)
    LockIc.Visible = false

    local SwTrack = Instance.new("Frame", Btn)
    SwTrack.Size = UDim2.new(0, 34, 0, 18)
    SwTrack.Position = UDim2.new(1, -44, 0.5, -9)
    SwTrack.BackgroundColor3 = Colors.SwitchOff
    SwTrack.BorderSizePixel = 0
    Instance.new("UICorner", SwTrack).CornerRadius = UDim.new(1, 0)
    local Knob = Instance.new("Frame", SwTrack)
    Knob.Size = UDim2.new(0, 14, 0, 14)
    Knob.Position = UDim2.new(0, 2, 0.5, -7)
    Knob.BackgroundColor3 = Colors.Text
    Knob.BorderSizePixel = 0
    Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)

    local isOn = defaultState
    local function paint()
        local info = TweenInfo.new(0.18)
        TweenService:Create(SwTrack, info, {BackgroundColor3 = isOn and Colors.Accent or Colors.SwitchOff}):Play()
        TweenService:Create(Knob, info, {Position = isOn and UDim2.new(0, 18, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)}):Play()
        TweenService:Create(Stroke, info, {Color = isOn and Colors.Accent or Colors.Border}):Play()
        SetIconColor(Ic, isOn and Colors.Accent or Colors.TextDim)
    end
    paint()
    return {
        SetState = function(state) isOn = state; paint() end,
        GetState = function() return isOn end,
        SetLocked = function(locked, lockedDesc)
            LockIc.Visible = locked
            if D and lockedDesc then D.Text = locked and lockedDesc or desc end
        end,
        SwitchBg = Btn,
    }
end

-- baris stepper (- nilai +)
W.Stepper = function(parent, title, desc, iconKey, order, value, minV, maxV, step, unit, onChange)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 44)
    Row.BackgroundColor3 = Colors.GlassPanel
    Row.LayoutOrder = order
    Row.Parent = parent
    Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 10)
    local Stroke = Instance.new("UIStroke", Row)
    Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    Stroke.Thickness = 1
    Stroke.Color = Colors.Border

    local Ic = MakeIcon(Row, iconKey, 16, Colors.Accent)
    Ic.Position = UDim2.new(0, 10, 0.5, -8)
    local T = NewLabel(Row, title, 12, Enum.Font.GothamMedium, Colors.Text)
    T.Size = UDim2.new(1, -150, 0, 16)
    T.Position = UDim2.new(0, 34, 0, 6)
    T.TextTruncate = Enum.TextTruncate.AtEnd
    local D = NewLabel(Row, desc, 10, Enum.Font.Gotham, Colors.TextDim)
    D.Size = UDim2.new(1, -150, 0, 14)
    D.Position = UDim2.new(0, 34, 0, 23)
    D.TextTruncate = Enum.TextTruncate.AtEnd

    local function MakeBtn(txt, xOff)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 24, 0, 24)
        b.Position = UDim2.new(1, xOff, 0.5, -12)
        b.BackgroundColor3 = Colors.Tile
        b.AutoButtonColor = false
        b.Text = txt
        b.TextSize = 14
        b.Font = Enum.Font.GothamBold
        b.TextColor3 = Colors.Text
        b.Parent = Row
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        return b
    end
    local Minus = MakeBtn("-", -102)
    local Plus = MakeBtn("+", -34)
    local V = NewLabel(Row, "", 12, Enum.Font.GothamMedium, Colors.Accent, Enum.TextXAlignment.Center)
    V.Size = UDim2.new(0, 40, 0, 24)
    V.Position = UDim2.new(1, -74, 0.5, -12)

    local current = value
    local function setV(n)
        current = math.clamp(n, minV, maxV)
        V.Text = tostring(current) .. unit
        onChange(current)
    end
    Minus.MouseButton1Click:Connect(function() setV(current - step) end)
    Plus.MouseButton1Click:Connect(function() setV(current + step) end)
    V.Text = tostring(current) .. unit
    return Row
end

-- baris profil (radio)
W.Profile = function(parent, cfg, order)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 30)
    Btn.BackgroundColor3 = Colors.GlassPanel
    Btn.AutoButtonColor = false
    Btn.Text = ""
    Btn.LayoutOrder = order
    Btn.Parent = parent
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 8)
    local Stroke = Instance.new("UIStroke", Btn)
    Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    Stroke.Thickness = 1
    Stroke.Color = Colors.Border

    local Dot = Instance.new("Frame", Btn)
    Dot.Size = UDim2.new(0, 10, 0, 10)
    Dot.Position = UDim2.new(0, 10, 0.5, -5)
    Dot.BackgroundColor3 = Colors.Accent
    Dot.BackgroundTransparency = 1
    Dot.BorderSizePixel = 0
    Instance.new("UICorner", Dot).CornerRadius = UDim.new(1, 0)
    local DotStroke = Instance.new("UIStroke", Dot)
    DotStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    DotStroke.Thickness = 1.5
    DotStroke.Color = Colors.TextDim

    local Left = Instance.new("Frame", Btn)
    Left.Size = UDim2.new(0.62, -28, 1, 0)
    Left.Position = UDim2.new(0, 28, 0, 0)
    Left.BackgroundTransparency = 1
    local LL = Instance.new("UIListLayout", Left)
    LL.FillDirection = Enum.FillDirection.Horizontal
    LL.VerticalAlignment = Enum.VerticalAlignment.Center
    LL.SortOrder = Enum.SortOrder.LayoutOrder
    LL.Padding = UDim.new(0, 6)
    local NameLbl = NewLabel(Left, cfg.name, 12, Enum.Font.GothamMedium, Colors.Text)
    NameLbl.AutomaticSize = Enum.AutomaticSize.X
    NameLbl.Size = UDim2.new(0, 0, 1, 0)
    NameLbl.LayoutOrder = 1
    if cfg.isNew then
        local Badge = Instance.new("TextLabel")
        Badge.AutomaticSize = Enum.AutomaticSize.X
        Badge.Size = UDim2.new(0, 0, 0, 14)
        Badge.BackgroundColor3 = Colors.Green
        Badge.BorderSizePixel = 0
        Badge.Text = "baru"
        Badge.Font = Enum.Font.GothamBold
        Badge.TextSize = 10
        Badge.TextColor3 = Colors.OnAccent
        Badge.LayoutOrder = 2
        Badge.Parent = Left
        Instance.new("UICorner", Badge).CornerRadius = UDim.new(0, 6)
        local bp = Instance.new("UIPadding", Badge)
        bp.PaddingLeft = UDim.new(0, 5)
        bp.PaddingRight = UDim.new(0, 5)
    end

    local Right = NewLabel(Btn, formatNumber(cfg.amount) .. " · " .. formatNumber(cfg.targetSpeed), 11, Enum.Font.Gotham, Colors.TextDim, Enum.TextXAlignment.Right)
    Right.Size = UDim2.new(0.38, -10, 1, 0)
    Right.Position = UDim2.new(0.62, 0, 0, 0)

    local isOn = false
    local function paint()
        Btn.BackgroundColor3 = isOn and Colors.ChipOn or Colors.GlassPanel
        Stroke.Color = isOn and Colors.Accent or Colors.Border
        NameLbl.TextColor3 = isOn and Colors.Accent or Colors.Text
        Right.TextColor3 = isOn and Colors.Accent or Colors.TextDim
        Dot.BackgroundTransparency = isOn and 0 or 1
        DotStroke.Color = isOn and Colors.Accent or Colors.TextDim
    end
    Btn.MouseEnter:Connect(function() if not isOn then Btn.BackgroundColor3 = Colors.Tile end end)
    Btn.MouseLeave:Connect(function() if not isOn then Btn.BackgroundColor3 = Colors.GlassPanel end end)
    paint()
    return {
        SetState = function(state) isOn = state; paint() end,
        GetState = function() return isOn end,
        SwitchBg = Btn,
    }
end

-- ═══════════ [ SIDEBAR ] ═══════════
local HomeBtn, AutoBuyBtn, SettingsBtn
local SetHomeActive, SetAutoBuyActive, SetSettingsActive
local MonitorBadge
do
    local Sidebar = Instance.new("Frame", MainFrame)
    Sidebar.Size = UDim2.new(0, SIDEBAR_W, 1, 0)
    Sidebar.BackgroundColor3 = Colors.Sidebar
    Sidebar.BorderSizePixel = 0

    local Sep = Instance.new("Frame", MainFrame)
    Sep.Size = UDim2.new(0, 1, 1, 0)
    Sep.Position = UDim2.new(0, SIDEBAR_W, 0, 0)
    Sep.BackgroundColor3 = Colors.Border
    Sep.BorderSizePixel = 0

    -- logo + nama
    local Logo = Instance.new("Frame", Sidebar)
    Logo.Size = UDim2.new(0, 34, 0, 34)
    Logo.Position = UDim2.new(0, 14, 0, 14)
    Logo.BackgroundColor3 = Colors.Accent
    Logo.BorderSizePixel = 0
    Instance.new("UICorner", Logo).CornerRadius = UDim.new(0, 9)
    local LogoIc = MakeIcon(Logo, "pickaxe", 18, Colors.OnAccent)
    LogoIc.AnchorPoint = Vector2.new(0.5, 0.5)
    LogoIc.Position = UDim2.new(0.5, 0, 0.5, 0)
    local Title = NewLabel(Sidebar, "V-Ziir0", 15, Enum.Font.GothamBold, Colors.Text)
    Title.Size = UDim2.new(0, 80, 0, 18)
    Title.Position = UDim2.new(0, 56, 0, 15)
    local Ver = NewLabel(Sidebar, "v37", 11, Enum.Font.Gotham, Colors.TextDim)
    Ver.Size = UDim2.new(0, 80, 0, 14)
    Ver.Position = UDim2.new(0, 56, 0, 33)

    local MainLbl = NewLabel(Sidebar, "Main", 11, Enum.Font.GothamMedium, Colors.TextDim)
    MainLbl.Size = UDim2.new(0, 60, 0, 14)
    MainLbl.Position = UDim2.new(0, 20, 0, 68)

    local NavList = Instance.new("Frame", Sidebar)
    NavList.Size = UDim2.new(1, -20, 0, 120)
    NavList.Position = UDim2.new(0, 10, 0, 88)
    NavList.BackgroundTransparency = 1
    local NavLayout = Instance.new("UIListLayout", NavList)
    NavLayout.SortOrder = Enum.SortOrder.LayoutOrder
    NavLayout.Padding = UDim.new(0, 4)

    local function CreateNavButton(name, iconKey, order)
        local Btn = Instance.new("TextButton")
        Btn.Size = UDim2.new(1, 0, 0, 34)
        Btn.BackgroundColor3 = Colors.Tile
        Btn.BackgroundTransparency = 1
        Btn.AutoButtonColor = false
        Btn.Text = ""
        Btn.LayoutOrder = order
        Btn.Parent = NavList
        Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 8)

        local Bar = Instance.new("Frame", Btn)
        Bar.Size = UDim2.new(0, 3, 0, 18)
        Bar.Position = UDim2.new(0, -10, 0.5, -9)
        Bar.BackgroundColor3 = Colors.Accent
        Bar.BorderSizePixel = 0
        Bar.Visible = false
        Instance.new("UICorner", Bar).CornerRadius = UDim.new(1, 0)

        local Ic = MakeIcon(Btn, iconKey, 16, Colors.TextDim)
        Ic.Position = UDim2.new(0, 10, 0.5, -8)
        local Txt = NewLabel(Btn, name, 13, Enum.Font.GothamMedium, Colors.TextDim)
        Txt.Size = UDim2.new(1, -40, 1, 0)
        Txt.Position = UDim2.new(0, 36, 0, 0)

        -- titik hijau: penanda monitor aktif saat sedang di tab lain
        local Badge = Instance.new("Frame", Btn)
        Badge.Size = UDim2.new(0, 6, 0, 6)
        Badge.Position = UDim2.new(1, -14, 0.5, -3)
        Badge.BackgroundColor3 = Colors.Green
        Badge.BorderSizePixel = 0
        Badge.Visible = false
        Instance.new("UICorner", Badge).CornerRadius = UDim.new(1, 0)

        local active = false
        Btn.MouseEnter:Connect(function() if not active then Txt.TextColor3 = Colors.Text end end)
        Btn.MouseLeave:Connect(function() if not active then Txt.TextColor3 = Colors.TextDim end end)
        local function SetActive(isActive)
            active = isActive
            Bar.Visible = isActive
            TweenService:Create(Btn, TweenInfo.new(0.2), {BackgroundTransparency = isActive and 0 or 1}):Play()
            Txt.TextColor3 = isActive and Colors.Text or Colors.TextDim
            SetIconColor(Ic, isActive and Colors.Accent or Colors.TextDim)
        end
        return Btn, SetActive, Badge
    end

    HomeBtn, SetHomeActive, MonitorBadge = CreateNavButton("Monitor", "monitor", 1)
    AutoBuyBtn, SetAutoBuyActive = CreateNavButton("Auto Buy", "shop", 2)
    SettingsBtn, SetSettingsActive = CreateNavButton("Pengaturan", "settings", 3)

    -- kartu akun di bawah
    local FootSep = Instance.new("Frame", Sidebar)
    FootSep.Size = UDim2.new(1, -28, 0, 1)
    FootSep.Position = UDim2.new(0, 14, 1, -64)
    FootSep.BackgroundColor3 = Colors.Border
    FootSep.BorderSizePixel = 0

    local Av = Instance.new("Frame", Sidebar)
    Av.Size = UDim2.new(0, 32, 0, 32)
    Av.Position = UDim2.new(0, 14, 1, -52)
    Av.BackgroundColor3 = Colors.Tile
    Av.BorderSizePixel = 0
    Instance.new("UICorner", Av).CornerRadius = UDim.new(1, 0)
    local AvIc = MakeIcon(Av, "user", 16, Colors.TextDim)
    AvIc.AnchorPoint = Vector2.new(0.5, 0.5)
    AvIc.Position = UDim2.new(0.5, 0, 0.5, 0)

    local NameLbl = NewLabel(Sidebar, player.Name:sub(1, 2) .. "********", 12, Enum.Font.GothamBold, Colors.Text)
    NameLbl.Size = UDim2.new(0, 92, 0, 16)
    NameLbl.Position = UDim2.new(0, 54, 1, -52)
    NameLbl.TextTruncate = Enum.TextTruncate.AtEnd
    UI.SideStatus = NewLabel(Sidebar, "Idle", 11, Enum.Font.Gotham, Colors.TextDim)
    UI.SideStatus.Size = UDim2.new(0, 92, 0, 14)
    UI.SideStatus.Position = UDim2.new(0, 54, 1, -35)
end

-- ═══════════ [ HEADER KONTEN ] ═══════════
do
    local Header = Instance.new("Frame", MainFrame)
    Header.Size = UDim2.new(1, -(SIDEBAR_W + 1), 0, 44)
    Header.Position = UDim2.new(0, SIDEBAR_W + 1, 0, 0)
    Header.BackgroundTransparency = 1

    UI.PageTitle = NewLabel(Header, "Monitor", 17, Enum.Font.GothamBold, Colors.Text)
    UI.PageTitle.Size = UDim2.new(0, 150, 1, 0)
    UI.PageTitle.Position = UDim2.new(0, 14, 0, 0)

    local Pill = Instance.new("Frame", Header)
    Pill.Size = UDim2.new(0, 96, 0, 22)
    Pill.Position = UDim2.new(1, -168, 0.5, -11)
    Pill.BackgroundColor3 = Colors.GlassPanel
    Pill.BorderSizePixel = 0
    Instance.new("UICorner", Pill).CornerRadius = UDim.new(1, 0)
    local PillStroke = Instance.new("UIStroke", Pill)
    PillStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    PillStroke.Thickness = 1
    PillStroke.Color = Colors.Border
    UI.PillDot = Instance.new("Frame", Pill)
    UI.PillDot.Size = UDim2.new(0, 6, 0, 6)
    UI.PillDot.Position = UDim2.new(0, 10, 0.5, -3)
    UI.PillDot.BackgroundColor3 = Colors.TextDim
    UI.PillDot.BorderSizePixel = 0
    Instance.new("UICorner", UI.PillDot).CornerRadius = UDim.new(1, 0)
    UI.PillLbl = NewLabel(Pill, "Idle", 11, Enum.Font.GothamMedium, Colors.TextDim)
    UI.PillLbl.Size = UDim2.new(1, -26, 1, 0)
    UI.PillLbl.Position = UDim2.new(0, 22, 0, 0)

    local CloseBtn = Instance.new("TextButton", Header)
    CloseBtn.Size = UDim2.new(0, 26, 0, 26)
    CloseBtn.Position = UDim2.new(1, -34, 0.5, -13)
    CloseBtn.BackgroundTransparency = 1
    CloseBtn.Text = ""
    local CloseIcon = MakeIcon(CloseBtn, "close", 14, Colors.TextDim)
    CloseIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    CloseIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
    CloseBtn.MouseEnter:Connect(function() SetIconColor(CloseIcon, Colors.Danger) end)
    CloseBtn.MouseLeave:Connect(function() SetIconColor(CloseIcon, Colors.TextDim) end)
    CloseBtn.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
    end)

    UI.MinBtn = Instance.new("TextButton", Header)
    UI.MinBtn.Size = UDim2.new(0, 26, 0, 26)
    UI.MinBtn.Position = UDim2.new(1, -62, 0.5, -13)
    UI.MinBtn.BackgroundTransparency = 1
    UI.MinBtn.Text = ""
    local MinIcon = MakeIcon(UI.MinBtn, "minus", 14, Colors.TextDim)
    MinIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    MinIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
    UI.MinBtn.MouseEnter:Connect(function() SetIconColor(MinIcon, Colors.Text) end)
    UI.MinBtn.MouseLeave:Connect(function() SetIconColor(MinIcon, Colors.TextDim) end)
end

local ContentArea = Instance.new("Frame", MainFrame)
ContentArea.Size = UDim2.new(1, -(SIDEBAR_W + 25), 0, FRAME_H - 86)
ContentArea.Position = UDim2.new(0, SIDEBAR_W + 13, 0, 46)
ContentArea.BackgroundTransparency = 1

local ShowTab   -- diisi setelah semua tab dibuat
local monitorToggles = {}
local toggleCallbacks = {}

-- ═══════════════════════════════════════════════════════
-- ── TAB MONITOR (kartu: profil, quick actions, status, progres, otomasi)
-- ═══════════════════════════════════════════════════════
local HomeTab = Instance.new("Frame", ContentArea)
HomeTab.Size = UDim2.new(1, 0, 1, 0)
HomeTab.BackgroundTransparency = 1

do
    local function MakeColumn(x, w)
        local col = Instance.new("Frame", HomeTab)
        col.Size = UDim2.new(0, w, 1, 0)
        col.Position = UDim2.new(0, x, 0, 0)
        col.BackgroundTransparency = 1
        local lay = Instance.new("UIListLayout", col)
        lay.SortOrder = Enum.SortOrder.LayoutOrder
        lay.Padding = UDim.new(0, 10)
        return col
    end
    local function MakeRow(parent, h)
        local row = Instance.new("Frame", parent)
        row.Size = UDim2.new(1, 0, 0, h)
        row.BackgroundTransparency = 1
        local lay = Instance.new("UIListLayout", row)
        lay.FillDirection = Enum.FillDirection.Horizontal
        lay.SortOrder = Enum.SortOrder.LayoutOrder
        lay.Padding = UDim.new(0, 6)
        return row
    end

    local Left = MakeColumn(0, 180)
    local Right = MakeColumn(190, 215)

    -- ── Profil aktif ──
    local _, pBody = W.Card(Left, "Profil aktif", "crown", 70, 1)
    UI.CardName = NewLabel(pBody, "Belum ada profil", 12, Enum.Font.GothamBold, Colors.Text)
    UI.CardName.Size = UDim2.new(1, 0, 0, 16)
    UI.CardName.TextTruncate = Enum.TextTruncate.AtEnd
    UI.CardSub = NewLabel(pBody, "Pilih di tab Pengaturan", 10, Enum.Font.Gotham, Colors.TextDim)
    UI.CardSub.Size = UDim2.new(1, 0, 0, 14)
    UI.CardSub.Position = UDim2.new(0, 0, 0, 17)
    UI.CardSub.TextTruncate = Enum.TextTruncate.AtEnd
    local pRow = MakeRow(pBody, 36)
    pRow.Position = UDim2.new(0, 0, 0, 34)
    UI.TgtInc = W.Tile(pRow, 75, 1, "—", "Target income")
    UI.TgtSpd = W.Tile(pRow, 75, 2, "—", "Target speed")

    -- ── Quick actions ──
    local _, qBody = W.Card(Left, "Quick actions", "bolt", 56, 2)
    local function QBtn(text, pos, size, color)
        local b = Instance.new("TextButton")
        b.Size = size
        b.Position = pos
        b.BackgroundColor3 = Colors.Tile
        b.AutoButtonColor = false
        b.Text = text
        b.Font = Enum.Font.GothamMedium
        b.TextSize = 11
        b.TextColor3 = color or Colors.Text
        b.Parent = qBody
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
        b.MouseEnter:Connect(function() b.BackgroundColor3 = Colors.SwitchOff end)
        b.MouseLeave:Connect(function() b.BackgroundColor3 = Colors.Tile end)
        return b
    end
    local bProfile = QBtn("Profil", UDim2.new(0, 0, 0, 0), UDim2.new(0.5, -3, 0, 26))
    local bHook = QBtn("Webhook", UDim2.new(0.5, 3, 0, 0), UDim2.new(0.5, -3, 0, 26))
    local bStop = QBtn("Hentikan semua", UDim2.new(0, 0, 0, 30), UDim2.new(1, 0, 0, 26), Colors.Danger)

    bProfile.MouseButton1Click:Connect(function() if ShowTab then ShowTab("settings") end end)
    bHook.MouseButton1Click:Connect(function()
        task.spawn(function()
            local m, s = getMyData()
            sendToDiscord(m, s, "+ LAPORAN MANUAL")
            showNotif("✅ WEBHOOK BERHASIL", "Laporan dikirim ke Discord", 3)
        end)
    end)
    bStop.MouseButton1Click:Connect(function()
        local any = false
        for i, tog in ipairs(monitorToggles) do
            if tog.GetState() then
                any = true
                tog.SetState(false)
                if toggleCallbacks[i] then toggleCallbacks[i](false) end
            end
        end
        if autoBuyEnabled then
            any = true
            autoBuyEnabled = false
            hasCheckedOwnership = false
            hasCheckedTarget = false
            buyStatus = "None"
        end
        if any then
            showNotif("🛑 DIHENTIKAN", "Monitor dan Auto Buy dimatikan", 3)
        else
            showNotif("ℹ️ INFO", "Tidak ada yang sedang aktif", 3)
        end
    end)

    -- ── Status ──
    local _, sBody = W.Card(Right, "Status", "clock", 36, 1)
    local sRow = MakeRow(sBody, 36)
    UI.StCash = W.Tile(sRow, 59, 1, "0", "Cash")
    UI.StInc = W.Tile(sRow, 59, 2, "0", "Income")
    UI.StSpd = W.Tile(sRow, 59, 3, "0", "Speed")

    -- ── Progres ──
    local gCard, gBody = W.Card(Right, "Progres", "target", 60, 2)
    UI.ProgCap = NewLabel(gCard, "Idle", 10, Enum.Font.Gotham, Colors.TextDim, Enum.TextXAlignment.Right)
    UI.ProgCap.Size = UDim2.new(1, -120, 0, 30)
    UI.ProgCap.Position = UDim2.new(0, 90, 0, 0)
    UI.ProgCap.TextTruncate = Enum.TextTruncate.AtEnd

    UI.BarDefs = {
        { key = "inc", name = "Income", color = Colors.Accent },
        { key = "spd", name = "Speed", color = Colors.Green },
        { key = "pick", name = "Kapak", color = Colors.Amber },
    }
    UI.Bars = {}
    for i, def in ipairs(UI.BarDefs) do
        local Row = Instance.new("Frame", gBody)
        Row.Size = UDim2.new(1, 0, 0, 20)
        Row.Position = UDim2.new(0, 0, 0, (i - 1) * 20)
        Row.BackgroundTransparency = 1
        local L = NewLabel(Row, def.name, 11, Enum.Font.GothamMedium, Colors.TextDim)
        L.Size = UDim2.new(0, 44, 1, 0)
        local Tr = Instance.new("Frame", Row)
        Tr.Size = UDim2.new(1, -92, 0, 6)
        Tr.Position = UDim2.new(0, 48, 0.5, -3)
        Tr.BackgroundColor3 = Colors.Track
        Tr.BorderSizePixel = 0
        Instance.new("UICorner", Tr).CornerRadius = UDim.new(1, 0)
        local Fl = Instance.new("Frame", Tr)
        Fl.Size = UDim2.new(0, 0, 1, 0)
        Fl.BackgroundColor3 = def.color
        Fl.BorderSizePixel = 0
        Instance.new("UICorner", Fl).CornerRadius = UDim.new(1, 0)
        local V = NewLabel(Row, "—", 11, Enum.Font.Gotham, Colors.Text, Enum.TextXAlignment.Right)
        V.Size = UDim2.new(0, 40, 1, 0)
        V.Position = UDim2.new(1, -40, 0, 0)
        UI.Bars[def.key] = { Row = Row, Fill = Fl, Val = V }
    end

    -- ── Otomasi ──
    local _, oBody = W.Card(Right, "Otomasi", "settings", 54, 3)
    local oLay = Instance.new("UIListLayout", oBody)
    oLay.SortOrder = Enum.SortOrder.LayoutOrder
    oLay.Padding = UDim.new(0, 2)
    UI.AutoJump = W.Switch(oBody, "Auto jump", nil, "jump", 1, false, Colors.Tile)
    UI.AutoRespawn = W.Switch(oBody, "Auto respawn", nil, "hourglass", 2, true, Colors.Tile)

    UI.AutoJump.SwitchBg.MouseButton1Click:Connect(function()
        local newState = not UI.AutoJump.GetState()
        UI.AutoJump.SetState(newState)
        isAutoJumpEnabled = newState
    end)
    UI.AutoRespawn.SwitchBg.MouseButton1Click:Connect(function()
        -- kalau monitor aktif, saklar dikunci → tidak bisa dimatikan
        if isAutoRespawnLocked then
            showNotif("🔒 TERKUNCI", "Auto Respawn dikunci saat Monitor aktif", 3)
            return
        end
        local newState = not UI.AutoRespawn.GetState()
        UI.AutoRespawn.SetState(newState)
        isAutoRespawnIdle = newState
    end)
end

-- ── Footer status (status auto buy) ─────────────────────
local FooterBar = Instance.new("Frame", MainFrame)
FooterBar.Size = UDim2.new(1, -(SIDEBAR_W + 25), 0, 24)
FooterBar.Position = UDim2.new(0, SIDEBAR_W + 13, 1, -34)
FooterBar.BackgroundColor3 = Colors.GlassPanel
FooterBar.BorderSizePixel = 0
Instance.new("UICorner", FooterBar).CornerRadius = UDim.new(0, 8)
do
    local FS = Instance.new("UIStroke", FooterBar)
    FS.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    FS.Thickness = 1
    FS.Color = Colors.Border
end

local BuyStatusLbl = NewLabel(FooterBar, "Status: Idle", 11, Enum.Font.GothamBold, Colors.TextDim)
BuyStatusLbl.Size = UDim2.new(1, -16, 1, 0)
BuyStatusLbl.Position = UDim2.new(0, 8, 0, 0)
BuyStatusLbl.TextTruncate = Enum.TextTruncate.AtEnd
BuyStatusLbl.Visible = false

do
    local BuyIcons = {}
    for _, k in ipairs({ "shop", "hourglass", "bolt", "checkc", "xc" }) do
        local ic = MakeIcon(FooterBar, k, 14, Colors.TextDim)
        ic.Position = UDim2.new(0, 9, 0.5, -7)
        ic.Visible = false
        BuyIcons[k] = ic
    end
    local BuyDisplayLbl = NewLabel(FooterBar, "Status: Idle", 11, Enum.Font.GothamBold, Colors.TextDim)
    BuyDisplayLbl.Size = UDim2.new(1, -34, 1, 0)
    BuyDisplayLbl.Position = UDim2.new(0, 28, 0, 0)
    BuyDisplayLbl.TextTruncate = Enum.TextTruncate.AtEnd

    local function SyncBuyStatus()
        local raw = BuyStatusLbl.Text
        local key = "shop"
        if raw:find("⏳", 1, true) then key = "hourglass"
        elseif raw:find("⚡", 1, true) then key = "bolt"
        elseif raw:find("✅", 1, true) then key = "checkc"
        elseif raw:find("❌", 1, true) then key = "xc" end
        for k, ic in pairs(BuyIcons) do ic.Visible = (k == key) end
        SetIconColor(BuyIcons[key], BuyStatusLbl.TextColor3)
        BuyDisplayLbl.Text = StripEmoji(raw)
        BuyDisplayLbl.TextColor3 = BuyStatusLbl.TextColor3
    end
    BuyStatusLbl:GetPropertyChangedSignal("Text"):Connect(SyncBuyStatus)
    BuyStatusLbl:GetPropertyChangedSignal("TextColor3"):Connect(SyncBuyStatus)
    SyncBuyStatus()
end

-- ═══════════════════════════════════════════════════════
-- ── TAB PENGATURAN (profil monitor, timer, notifikasi, data)
-- ═══════════════════════════════════════════════════════
local SettingsTab = Instance.new("Frame", ContentArea)
SettingsTab.Size = UDim2.new(1, 0, 1, 0)
SettingsTab.BackgroundTransparency = 1
SettingsTab.Visible = false

do
    local Scroll = Instance.new("ScrollingFrame", SettingsTab)
    Scroll.Size = UDim2.new(1, 0, 1, 0)
    Scroll.BackgroundTransparency = 1
    StyleScrollbar(Scroll)
    local Layout = Instance.new("UIListLayout", Scroll)
    Layout.Padding = UDim.new(0, 6)
    Layout.SortOrder = Enum.SortOrder.LayoutOrder

    local function Section(text, order)
        local l = NewLabel(Scroll, text, 11, Enum.Font.GothamBold, Colors.Accent)
        l.Size = UDim2.new(1, 0, 0, 16)
        l.LayoutOrder = order
        return l
    end

    local function Hint(text, order)
        local l = NewLabel(Scroll, text, 10, Enum.Font.Gotham, Colors.TextDim)
        l.Size = UDim2.new(1, 0, 0, 14)
        l.LayoutOrder = order
        l.TextTruncate = Enum.TextTruncate.AtEnd
        return l
    end

    -- ═════ SUSUNAN PENGATURAN ═════
    Section("Profil monitor", 1)

    -- filter Semua / Baru (hanya muncul kalau ada profil baru)
    local hasNew = false
    for _, cfg in ipairs(CONFIG_DB) do if cfg.isNew then hasNew = true break end end

    local FilterBar = Instance.new("Frame", Scroll)
    FilterBar.Size = UDim2.new(1, 0, 0, 26)
    FilterBar.BackgroundColor3 = Colors.GlassPanel
    FilterBar.LayoutOrder = 2
    FilterBar.Visible = hasNew
    Instance.new("UICorner", FilterBar).CornerRadius = UDim.new(0, 8)

    local filterBtns = {}
    local function MakeFilterBtn(text, mode, xScale)
        local b = Instance.new("TextButton", FilterBar)
        b.Size = UDim2.new(0.5, -4, 1, -6)
        b.Position = UDim2.new(xScale, 2, 0, 3)
        b.BackgroundColor3 = Colors.SwitchOff
        b.BackgroundTransparency = 1
        b.AutoButtonColor = false
        b.Text = text
        b.Font = Enum.Font.GothamMedium
        b.TextSize = 11
        b.TextColor3 = Colors.TextDim
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        filterBtns[mode] = b
        return b
    end
    MakeFilterBtn("Semua profil", "all", 0)
    MakeFilterBtn("Baru", "new", 0.5)

    local rowsVisible = math.max(1, math.min(#CONFIG_DB, 3))
    local ProfileList = Instance.new("ScrollingFrame", Scroll)
    ProfileList.Size = UDim2.new(1, 0, 0, rowsVisible * 30 + (rowsVisible - 1) * 4)
    ProfileList.BackgroundTransparency = 1
    ProfileList.LayoutOrder = 3
    StyleScrollbar(ProfileList)
    local PLLayout = Instance.new("UIListLayout", ProfileList)
    PLLayout.Padding = UDim.new(0, 4)
    PLLayout.SortOrder = Enum.SortOrder.LayoutOrder

    Hint("Ketuk profil aktif lagi untuk mematikan monitor", 4)

    Section("Timer", 5)
    W.Stepper(Scroll, "Batas diam", "Detik sebelum respawn", "clock", 6, IDLE_TIMEOUT, 5, 120, 1, "s", function(v) IDLE_TIMEOUT = v end)
    W.Stepper(Scroll, "Batas macet", "Detik sebelum lompat", "clock", 7, STUCK_TIMEOUT, 3, 60, 1, "s", function(v) STUCK_TIMEOUT = v end)

    Section("Notifikasi", 8)
    local notifToggle = W.Switch(Scroll, "Notifikasi di layar", "Pop-up status", "bell", 9, true)
    W.Stepper(Scroll, "Interval webhook", "Jeda kirim ke Discord", "bolt", 10, WEBHOOK_INTERVAL, 5, 300, 5, "s", function(v) WEBHOOK_INTERVAL = v end)

    Section("Data", 11)
    local ResetBtn = Instance.new("TextButton", Scroll)
    ResetBtn.Size = UDim2.new(1, 0, 0, 32)
    ResetBtn.BackgroundColor3 = Colors.GlassPanel
    ResetBtn.AutoButtonColor = false
    ResetBtn.Text = "Reset profil tersimpan"
    ResetBtn.Font = Enum.Font.GothamMedium
    ResetBtn.TextSize = 12
    ResetBtn.TextColor3 = Colors.Danger
    ResetBtn.LayoutOrder = 12
    Instance.new("UICorner", ResetBtn).CornerRadius = UDim.new(0, 10)
    local RS = Instance.new("UIStroke", ResetBtn)
    RS.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    RS.Thickness = 1
    RS.Color = Colors.Danger

    local Spacer = Instance.new("Frame", Scroll)
    Spacer.Size = UDim2.new(1, 0, 0, 4)
    Spacer.BackgroundTransparency = 1
    Spacer.LayoutOrder = 13

    notifToggle.SwitchBg.MouseButton1Click:Connect(function()
        local newState = not notifToggle.GetState()
        notifToggle.SetState(newState)
        notifEnabled = newState
    end)

    -- ═════ BARIS PROFIL (terbaru di atas) ═════
    for i, cfg in ipairs(CONFIG_DB) do
        local toggleObj = W.Profile(ProfileList, cfg, #CONFIG_DB - i)
        local function callbackFn(state)
            if state then
                for _, other in pairs(monitorToggles) do
                    if other ~= toggleObj and other.SetState then other.SetState(false) end
                end
                targetIncome = cfg.amount
                targetSpeedValue = cfg.targetSpeed
                is_speed_done = false
                is_income_done = false
                is_buying_pickaxe = false
                activeProfileName = cfg.name
                is_farm_stopped = false
                is_monitoring = true
                hasCheckedOwnership = false
                hasCheckedTarget = false 
                prereqName = cfg.prereqName or "Galaxy"
                prereqId = cfg.prereqId or 17
                prereqPrice = cfg.prereqPrice or 4e15
                isAutoRespawnLocked = true
                isAutoRespawnIdle = true        -- paksa ON
                UI.AutoRespawn.SetState(true)
                UI.AutoRespawn.SetLocked(true)
                if cfg.pickaxeId then
                    targetPickaxeName = cfg.pickaxeName
                    targetPickaxeId = cfg.pickaxeId
                    targetBuyPrice = cfg.pickaxePrice
                    autoBuyEnabled = true
                    buyStatus = "Siap beli Galaxy dulu (ID: "..prereqId..")"
                    showNotif("🎯 TARGET & AUTO BUY", "Monitor: " .. cfg.name .. "\nTarget: Galaxy dulu → " .. cfg.pickaxeName, 5)
                else
                    showNotif("🎯 TARGET DIPILIH", "Target: " .. cfg.name, 5)
                end
                saveState(cfg.name)
            else
                is_monitoring = false
                is_farm_stopped = false
                activeProfileName = "None"
                clearState()
                -- ⭐ reset idle state biar tidak respawn saat OFF
                idleLastPos = nil
                idleTimeAccum = 0
                isRespawningIdle = false
                isAutoRespawnLocked = false
                UI.AutoRespawn.SetLocked(false)
            end
        end
        toggleCallbacks[i] = callbackFn
        table.insert(monitorToggles, toggleObj)
        toggleObj.SwitchBg.MouseButton1Click:Connect(function()
            if toggleObj.GetState() then
                toggleObj.SetState(false)
                callbackFn(false)
            else
                toggleObj.SetState(true)
                callbackFn(true)
            end
        end)
    end

    -- ═════ FILTER ═════
    local function ApplyFilter(mode)
        for m, b in pairs(filterBtns) do
            local on = (m == mode)
            b.BackgroundTransparency = on and 0 or 1
            b.BackgroundColor3 = Colors.SwitchOff
            b.TextColor3 = on and Colors.Text or Colors.TextDim
        end
        for i, tog in ipairs(monitorToggles) do
            tog.SwitchBg.Visible = (mode == "all") or (CONFIG_DB[i].isNew == true)
        end
    end
    for m, b in pairs(filterBtns) do
        b.MouseButton1Click:Connect(function() ApplyFilter(m) end)
    end
    ApplyFilter("all")

    -- ═════ RESET ═════
    ResetBtn.MouseButton1Click:Connect(function()
        for i, tog in ipairs(monitorToggles) do
            if tog.GetState() then
                tog.SetState(false)
                toggleCallbacks[i](false)
            end
        end
        clearState()
        showNotif("🗑️ RESET", "Profil tersimpan dihapus", 3)
    end)
end

-- ═══════════════════════════════════════════════════════
-- ── TAB AUTO BUY ────────────────────────────────────────
-- ═══════════════════════════════════════════════════════
local AutoBuyTab = Instance.new("Frame", ContentArea)
AutoBuyTab.Size = UDim2.new(1, 0, 1, 0)
AutoBuyTab.BackgroundTransparency = 1
AutoBuyTab.Visible = false

local SelValue
local PickRows = {}
do
    local SelectedCard = Instance.new("Frame", AutoBuyTab)
    SelectedCard.Size = UDim2.new(1, 0, 0, 40)
    SelectedCard.BackgroundColor3 = Colors.GlassPanel
    SelectedCard.BorderSizePixel = 0
    Instance.new("UICorner", SelectedCard).CornerRadius = UDim.new(0, 10)
    local SelStroke = Instance.new("UIStroke", SelectedCard)
    SelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    SelStroke.Thickness = 1
    SelStroke.Color = Colors.Border
    local SelIc = MakeIcon(SelectedCard, "shop", 16, Colors.Accent)
    SelIc.Position = UDim2.new(0, 12, 0.5, -8)
    local SelCap = NewLabel(SelectedCard, "Kapak target", 10, Enum.Font.Gotham, Colors.TextDim)
    SelCap.Size = UDim2.new(1, -44, 0, 14)
    SelCap.Position = UDim2.new(0, 36, 0, 5)
    SelValue = NewLabel(SelectedCard, "Belum dipilih", 12, Enum.Font.GothamBold, Colors.Text)
    SelValue.Size = UDim2.new(1, -44, 0, 16)
    SelValue.Position = UDim2.new(0, 36, 0, 19)
    SelValue.TextTruncate = Enum.TextTruncate.AtEnd

    local PickList = Instance.new("ScrollingFrame", AutoBuyTab)
    PickList.Size = UDim2.new(1, 0, 1, -48)
    PickList.Position = UDim2.new(0, 0, 0, 48)
    PickList.BackgroundTransparency = 1
    StyleScrollbar(PickList)
    local PickLayout = Instance.new("UIListLayout", PickList)
    PickLayout.Padding = UDim.new(0, 4)
    PickLayout.SortOrder = Enum.SortOrder.LayoutOrder

    for i, pk in ipairs(PICKAXE_DB) do
        local OptionBtn = Instance.new("TextButton")
        OptionBtn.Size = UDim2.new(1, 0, 0, 30)
        OptionBtn.BackgroundColor3 = Colors.GlassPanel
        OptionBtn.AutoButtonColor = false
        OptionBtn.LayoutOrder = i
        OptionBtn.Text = ""
        OptionBtn.Parent = PickList
        Instance.new("UICorner", OptionBtn).CornerRadius = UDim.new(0, 8)
        local RowStroke = Instance.new("UIStroke", OptionBtn)
        RowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        RowStroke.Thickness = 1
        RowStroke.Color = Colors.Border
        local NameLbl = NewLabel(OptionBtn, pk.name, 12, Enum.Font.GothamMedium, Colors.Text)
        NameLbl.Size = UDim2.new(0.55, 0, 1, 0)
        NameLbl.Position = UDim2.new(0, 10, 0, 0)
        local PriceLbl = NewLabel(OptionBtn, pk.priceStr, 11, Enum.Font.Gotham, Colors.Amber, Enum.TextXAlignment.Right)
        PriceLbl.Size = UDim2.new(0.4, 0, 1, 0)
        PriceLbl.Position = UDim2.new(0.6, -10, 0, 0)
        table.insert(PickRows, { name = pk.name, Btn = OptionBtn, Stroke = RowStroke, NameLbl = NameLbl })
        OptionBtn.MouseEnter:Connect(function()
            if not (autoBuyEnabled and targetPickaxeName == pk.name) then OptionBtn.BackgroundColor3 = Colors.Tile end
        end)
        OptionBtn.MouseLeave:Connect(function()
            if not (autoBuyEnabled and targetPickaxeName == pk.name) then OptionBtn.BackgroundColor3 = Colors.GlassPanel end
        end)
        OptionBtn.MouseButton1Click:Connect(function()
            targetPickaxeName = pk.name
            targetPickaxeId = pk.id
            targetBuyPrice = pk.priceRaw
            autoBuyEnabled = true
            hasCheckedOwnership = false
            hasCheckedTarget = false
            lastTargetProbe = 0
            buyStatus = "Siap beli (ID: "..pk.id..")"
            showNotif("🛒 AUTO BUY AKTIF", "Menunggu uang cukup untuk " .. pk.name, 5)
        end)
    end
end

local function PaintPickaxeRows()
    for _, r in ipairs(PickRows) do
        local sel = autoBuyEnabled and targetPickaxeName == r.name
        r.Btn.BackgroundColor3 = sel and Colors.ChipOn or Colors.GlassPanel
        r.Stroke.Color = sel and Colors.Accent or Colors.Border
        r.NameLbl.TextColor3 = sel and Colors.Accent or Colors.Text
    end
end

-- ── Navigasi tab ────────────────────────────────────────
ShowTab = function(name)
    HomeTab.Visible = (name == "home")
    AutoBuyTab.Visible = (name == "buy")
    SettingsTab.Visible = (name == "settings")
    SetHomeActive(name == "home")
    SetAutoBuyActive(name == "buy")
    SetSettingsActive(name == "settings")
    local titles = { home = "Monitor", buy = "Auto Buy", settings = "Pengaturan" }
    UI.PageTitle.Text = titles[name] or ""
end
HomeBtn.MouseButton1Click:Connect(function() ShowTab("home") end)
AutoBuyBtn.MouseButton1Click:Connect(function() ShowTab("buy") end)
SettingsBtn.MouseButton1Click:Connect(function() ShowTab("settings") end)
ShowTab("home")

-- ── Tombol mengambang ────────────────────
do
    local FloatingBtn = Instance.new("ImageButton", ScreenGui)
    FloatingBtn.Size = UDim2.new(0, 50, 0, 50)
    FloatingBtn.Position = UDim2.new(0, 20, 0, 20) 
    FloatingBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    FloatingBtn.Image = "rbxassetid://71161700474373" 
    FloatingBtn.ZIndex = 100 
    Instance.new("UICorner", FloatingBtn).CornerRadius = UDim.new(1, 0)

    local draggingFloating = false
    local dragStartPos = nil
    local startPos = nil
    local isDragging = false 

    FloatingBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingFloating = true
            isDragging = false
            dragStartPos = input.Position
            startPos = FloatingBtn.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then draggingFloating = false end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if draggingFloating and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStartPos
            if delta.Magnitude > 5 then isDragging = true end
            FloatingBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    FloatingBtn.MouseButton1Click:Connect(function()
        if isDragging then return end
        MainFrame.Visible = not MainFrame.Visible
    end)
    UI.MinBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false end)
end

-- ═══════════ [ PENYEGAR TAMPILAN (BACA-SAJA) ] ═══════════
local function pctOf(cur, tgt)
    if tgt and tgt > 0 then return math.clamp(cur / tgt, 0, 1) end
    return 0
end

local function barText(pct, target)
    return string.format("%d%% · %s", math.floor(pct * 100 + 0.0001), formatNumber(target))
end

local function computeView()
    local idle = { idx = 0, idle = true, color = Colors.TextDim, sub = "Idle", pct = 0, caption = "Pilih profil di tab Pengaturan" }
    if not is_monitoring and not autoBuyEnabled then return idle end

    local cash = getRealCash()
    local pkName, pkPrice
    if not hasCheckedOwnership then pkName, pkPrice = prereqName, prereqPrice else pkName, pkPrice = targetPickaxeName, targetBuyPrice end
    local pkPct = pctOf(cash, pkPrice)

    local function pickaxeView(idx, bars)
        return { idx = idx, color = Colors.Amber, sub = pkName, pct = pkPct, caption = formatNumber(cash) .. " / " .. formatNumber(pkPrice), bars = bars }
    end

    if not is_monitoring then
        return pickaxeView(0, { pick = { pct = pkPct, text = barText(pkPct, pkPrice) } })
    end

    local money_str, speed_str = getMyData()
    local money_num, speed_num = parseNumber(money_str), parseNumber(speed_str)
    local incomeOK = is_income_done or (targetIncome > 0 and money_num >= targetIncome)
    local speedOK = is_speed_done or (targetSpeedValue > 0 and speed_num >= targetSpeedValue)

    local incPct = incomeOK and 1 or pctOf(money_num, targetIncome)
    local spdPct = speedOK and 1 or pctOf(speed_num, targetSpeedValue)
    local bars = {
        inc = { pct = incPct, text = barText(incPct, targetIncome) },
        spd = { pct = spdPct, text = barText(spdPct, targetSpeedValue) },
    }
    if autoBuyEnabled then
        bars.pick = { pct = pkPct, text = barText(pkPct, pkPrice) }
    else
        bars.pick = { pct = 1, text = "Selesai" }
    end

    if not incomeOK then
        return { idx = 1, color = Colors.Accent, sub = "Income", pct = incPct, caption = formatNumber(money_num) .. " / " .. formatNumber(targetIncome), bars = bars }
    elseif not speedOK then
        return { idx = 2, color = Colors.Green, sub = "Speed", pct = spdPct, caption = formatNumber(speed_num) .. " / " .. formatNumber(targetSpeedValue), bars = bars }
    elseif autoBuyEnabled then
        return pickaxeView(3, bars)
    else
        local owned = buyStatus:find("DIMILIKI") or buyStatus:find("Beli Sukses")
        return { idx = 4, color = Colors.Green, sub = "Selesai", pct = 1, caption = owned and ("Kapak " .. tostring(targetPickaxeName) .. " dimiliki") or "Target tercapai", bars = bars }
    end
end

local function ApplyView(v)
    -- kartu profil aktif
    if is_monitoring then
        UI.CardName.Text = tostring(activeProfileName)
        UI.CardSub.Text = "Kapak target: " .. tostring(targetPickaxeName)
        UI.TgtInc.Text = formatNumber(targetIncome)
        UI.TgtSpd.Text = formatNumber(targetSpeedValue)
    elseif autoBuyEnabled then
        UI.CardName.Text = "Auto Buy"
        UI.CardSub.Text = tostring(targetPickaxeName)
        UI.TgtInc.Text = "—"
        UI.TgtSpd.Text = "—"
    else
        UI.CardName.Text = "Belum ada profil"
        UI.CardSub.Text = "Pilih di tab Pengaturan"
        UI.TgtInc.Text = "—"
        UI.TgtSpd.Text = "—"
    end

    -- kartu status (angka langsung)
    local money_str, speed_str = getMyData()
    UI.StCash.Text = formatNumber(getRealCash())
    UI.StInc.Text = tostring(money_str)
    UI.StSpd.Text = tostring(speed_str)

    -- kartu progres
    UI.ProgCap.Text = v.idle and "Idle" or tostring(v.caption)
    UI.ProgCap.TextColor3 = v.color
    for _, def in ipairs(UI.BarDefs) do
        local b = v.bars and v.bars[def.key]
        local r = UI.Bars[def.key]
        local pct = b and math.clamp(b.pct, 0, 1) or 0
        if b then
            r.Val.Text = (b.text == "Selesai") and "Selesai" or (math.floor(pct * 100 + 0.0001) .. "%")
        else
            r.Val.Text = "—"
        end
        TweenService:Create(r.Fill, TweenInfo.new(0.4), { Size = UDim2.new(pct, 0, 1, 0) }):Play()
    end

    -- titik hijau di tab Monitor saat sedang di tab lain
    MonitorBadge.Visible = is_monitoring and not HomeTab.Visible

    -- pill header + status di sidebar
    local label, color
    if is_monitoring then
        label, color = "Memantau", Colors.Green
    elseif autoBuyEnabled then
        label, color = "Auto Buy", Colors.Amber
    else
        label, color = "Idle", Colors.TextDim
    end
    UI.PillLbl.Text = label
    UI.PillLbl.TextColor3 = color
    UI.PillDot.BackgroundColor3 = color
    UI.SideStatus.Text = label
    UI.SideStatus.TextColor3 = is_monitoring and Colors.Accent or color

    SelValue.Text = autoBuyEnabled and (tostring(targetPickaxeName) .. "  •  " .. formatNumber(targetBuyPrice)) or "Belum dipilih"
    PaintPickaxeRows()
end

task.spawn(function()
    while ScreenGui.Parent and isCurrent() do
        local ok, v = pcall(computeView)
        if ok and v then pcall(ApplyView, v) end
        task.wait(INTERVAL)
    end
end)

-- ═══════════ [ LOOP UTAMA ] ═══════════
task.spawn(function()
    print("✅ Monitor Break & Steal berjalan!")
    while task.wait(INTERVAL) do
        if not isCurrent() or not ScreenGui.Parent then
            pcall(function() ScreenGui:Destroy() end)
            break
        end

        local money_str, speed_str = getMyData()
        local money_num = parseNumber(money_str)
        updateSpeedActivity(speed_str)
        
        if is_monitoring then
            local speed_num = parseNumber(speed_str)
            if not is_buying_pickaxe and not is_income_done and (money_num >= targetIncome) then
                is_income_done = true 
                onTargetReached()
                sendToDiscord(money_str, speed_str, "+ AUTO FARM STOPPED (" .. tostring(activeProfileName) .. ")")
                is_speed_done = false 
            end
            if is_farm_stopped and not is_speed_done and targetSpeedValue > 0 then
                if speed_num >= targetSpeedValue then
                    is_speed_done = true
                    if autoBuyEnabled then
                        local currentCash = getRealCash()
                        if currentCash < targetBuyPrice then
                            is_farm_stopped = false 
                            is_income_done = true 
                            is_buying_pickaxe = true 
                            startAutoFarm() 
                            showNotif("🔄 AUTO RE-FARM", "Speed tercapai, tapi uang belum cukup. Lanjut farming!", 5)
                        end
                    end
                end
            end
        end

        if money_str ~= lastMoney or speed_str ~= lastSpeed then
            if (os.time() - lastWebhookTime) >= WEBHOOK_INTERVAL then
                local status = is_farm_stopped and "✅ TARGET TERCAPAI" or "🟢 FARMING ACTIVE"
                sendToDiscord(money_str, speed_str, status)
                lastMoney, lastSpeed = money_str, speed_str
                lastWebhookTime = os.time()
            end
        end

        if (isAutoJumpEnabled) or (is_farm_stopped) then
            local isAllowedToJump = false
            if isAutoJumpEnabled then
                isAllowedToJump = true
            elseif is_farm_stopped then
                if is_monitoring then isAllowedToJump = true end
            end
            if isAllowedToJump then
                local gainedNow = lastSpeedGainTime > lastSpeedCheck
                    and (os.clock() - lastSpeedGainTime) <= (INTERVAL + 1)
                if gainedNow then
                    hasSpeedIncreased = true
                    stuckTimer = 0
                    lastSpeedCheck = lastSpeedGainTime
                else
                    if hasSpeedIncreased then stuckTimer = stuckTimer + INTERVAL end
                end
                if hasSpeedIncreased and stuckTimer >= STUCK_TIMEOUT then
                    local char = player.Character
                    local humanoid = char and char:FindFirstChild("Humanoid")
                    if humanoid then
                        humanoid.Sit = false
                        humanoid.PlatformStand = false
                        task.wait(0.1) 
                        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                    end
                    stuckTimer = 0
                end
            else
                stuckTimer = 0
                hasSpeedIncreased = false
                lastSpeedCheck = 0
            end
        else
            stuckTimer = 0
            hasSpeedIncreased = false
            lastSpeedCheck = 0
        end

        if autoBuyEnabled then
            tryBuyPickaxe()
            BuyStatusLbl.Text = buyStatus
            if buyStatus:find("MENUNGGU") then
                local tick = math.floor(tick() * 2) % 2 
                if tick == 0 then BuyStatusLbl.TextColor3 = Color3.fromRGB(255, 255, 0) 
                else BuyStatusLbl.TextColor3 = Color3.fromRGB(200, 150, 0) end
            elseif buyStatus:find("MEMBELI") then
                BuyStatusLbl.TextColor3 = Color3.fromRGB(0, 255, 0) 
            elseif buyStatus:find("DIMILIKI") then
                BuyStatusLbl.TextColor3 = Color3.fromRGB(0, 255, 100)
            else
                BuyStatusLbl.TextColor3 = Colors.Text
            end
            
            if not is_monitoring and (os.time() - lastWebhookTime) >= WEBHOOK_INTERVAL then
                local m_str, s_str = getMyData()
                sendToDiscord(m_str, s_str, "🛒 AUTO BUY PROGRESS")
                lastWebhookTime = os.time()
            end
        else
            BuyStatusLbl.Text = "Status: Idle (Pilih Kapak)"
            BuyStatusLbl.TextColor3 = Colors.TextDim
        end

        -- ⭐ cek idle respawn tiap tick
        tickIdleRespawn()
    end
end)

local function autoReExecute()
    if _G.VZiir0_AutoExec_Active then
        return
    end
    _G.VZiir0_AutoExec_Active = true

    local url = "https://raw.githubusercontent.com/ellan8888/monitor-income/refs/heads/main/monitor.lua"
    local scriptToRun = "loadstring(game:HttpGet('" .. url .. "'))()"
    local success = pcall(function()
        if syn and syn.queue_on_teleport then syn.queue_on_teleport(scriptToRun); return "Synapse"
        elseif queue_on_teleport then queue_on_teleport(scriptToRun); return "Universal"
        elseif fluxus and fluxus.queue_on_teleport then fluxus.queue_on_teleport(scriptToRun); return "Fluxus"
        elseif getgenv().queue_on_teleport then getgenv().queue_on_teleport(scriptToRun); return "Genv" end
        return nil
    end)
    
    task.delay(5, function() _G.VZiir0_AutoExec_Active = nil end)
end

-- ⭐ AUTO-LOAD STATE
task.spawn(function()
    task.wait(3)
    if not isCurrent() then return end
    local savedProfile = loadState()
    if savedProfile and savedProfile ~= "None" then
        for i, cfg in ipairs(CONFIG_DB) do
            if cfg.name == savedProfile and monitorToggles[i] then
                monitorToggles[i].SetState(true)
                if toggleCallbacks[i] then toggleCallbacks[i](true) end
                break
            end
        end
    end
end)

autoReExecute()