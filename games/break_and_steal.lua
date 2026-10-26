-- ═══════════════════════════════════════════════════════
-- ✨ V-Ziir0 Hub: Break & Steal (v35 - Hardcode Master Config)
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

-- ⭐ STATE AUTO BUY
local autoBuyEnabled = false
local targetPickaxeName = "Kapak Ajaib" 
local targetPickaxeId = 7 
local targetBuyPrice = 2000 * 1e15 
local buyStatus = "None"
local hasCheckedOwnership = false
local hasCheckedTarget = false 
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
    -- 2. PROSES ANTREAN MAX ACC & CLONE-NYA
    local latestIndex = #PICKAXE_DB
    local GALAXY_ID = 17  -- ⭐ tambahkan ini

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
                -- ⭐ FIX: prereq selalu Galaxy
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
            -- ⭐ FIX: prereq selalu Galaxy, BUKAN pickaxe sebelumnya
            prereqId = PICKAXE_DB[GALAXY_ID].id, 
            prereqName = PICKAXE_DB[GALAXY_ID].name, 
            prereqPrice = PICKAXE_DB[GALAXY_ID].priceRaw
        })
    else
        local maxPk = PICKAXE_DB[targetIdx20]
        local cfgMax = MASTER_CONFIG[maxPk.name] or { income = DEFAULT_INCOME, speed = DEFAULT_SPEED }
        
        table.insert(CONFIG_DB, {
            name = "Max Account (Income " .. formatNumberAuto(cfgMax.income) .. ")", 
            amount = cfgMax.income, targetSpeed = cfgMax.speed,
            pickaxeId = maxPk.id, pickaxeName = maxPk.name, pickaxePrice = maxPk.priceRaw,
            -- ⭐ FIX juga di sini
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

local function checkOwnershipSilent(targetName, targetId)
    local char = player.Character
    if not char then return false end
    local currentlyHeld = char:FindFirstChildWhichIsA("Tool")
    local heldName = currentlyHeld and currentlyHeld.Name or nil
    local Event = ReplicatedStorage:FindFirstChild("PickaxeShopRequest")
    if not Event then return false end
    
    Event:FireServer("Equip", targetId)
    task.wait(0.5) 
    
    local hasTarget = false
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local tooltip = ""
            local success, res = pcall(function() return tool.ToolTip end)
            if success and res then tooltip = string.lower(res) end
            if string.find(string.lower(tool.Name), string.lower(targetName)) or string.find(tooltip, string.lower(targetName)) then
                hasTarget = true
                break
            end
        end
    end
    if not hasTarget and heldName then
        local oldId = nil
        for _, pk in ipairs(PICKAXE_DB) do
            if string.find(string.lower(pk.name), string.lower(heldName)) then oldId = pk.id; break end
        end
        if oldId then Event:FireServer("Equip", oldId) end
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
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return 0 end
    local mainGui = pg:FindFirstChild("MainGUI")
    if not mainGui then return 0 end
    local currencies = mainGui:FindFirstChild("Currencies")
    if not currencies then return 0 end
    local cashObj = currencies:FindFirstChild("Cash")
    if not cashObj then return 0 end
    local amountText = cashObj:FindFirstChild("Amount")
    if not amountText or not amountText:IsA("TextLabel") then return 0 end
    local rawText = amountText.Text
    local numberPart = rawText:match("%$(.*)")
    if numberPart then return parseNumber(numberPart:gsub("%s", "")) end
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
        if checkOwnershipSilent(targetPickaxeName, targetPickaxeId) then
            autoBuyEnabled = false
            buyStatus = "✅ " .. string.upper(targetPickaxeName) .. " SUDAH DIMILIKI!"
            hasCheckedTarget = true
            return
        end
        -- ⭐ FIX: Baris hasCheckedTarget dihapus dari sini biar re-cek
    end

    if currentMoney < targetBuyPrice then
        buyStatus = "⏳ NUNGGU UANG " .. targetPickaxeName .. ": (" .. money_str .. " / " .. formatNumber(targetBuyPrice) .. ")"
        return
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
-- ⭐ UI CUSTOM
-- ═══════════════════════════════════════════════════════
local Colors = {
    Background = Color3.fromRGB(15, 26, 34),
    GlassPanel = Color3.fromRGB(22, 38, 47),
    Border = Color3.fromRGB(39, 65, 80),
    Accent = Color3.fromRGB(25, 195, 217),
    Text = Color3.fromRGB(234, 246, 251),
    TextDim = Color3.fromRGB(111, 149, 168),
    SwitchOff = Color3.fromRGB(45, 70, 84),
    Green = Color3.fromRGB(79, 227, 168),
    Amber = Color3.fromRGB(245, 194, 107),
    Danger = Color3.fromRGB(229, 72, 77),
    Track = Color3.fromRGB(29, 51, 64),
    OnAccent = Color3.fromRGB(6, 40, 48),
    ChipOn = Color3.fromRGB(18, 48, 58),
}

local Icons = {
    pickaxe = "", monitor = "", shop = "", target = "", crown = "", jump = "", close = "", minus = "",
    check = "", hourglass = "", bolt = "", checkc = "", xc = "", coin = "",
}

local function getShortName(fullName)
    if fullName:find("Max Account %(Terbaru%)") then return "Max Acc" end
    if fullName:find("Max Account") then return "Max Acc" end
    if fullName:find("Income 1T") then return "Income 1T" end
    if fullName:find("Income") then 
        local incomeStr = fullName:match("Income (%S+)")
        if incomeStr then return "Inc " .. incomeStr end
    end
    return fullName
end

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
    local ok = pcall(buildNotif, title, text, duration)
    if not ok then
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = StripEmoji(title), Text = StripEmoji(text), Duration = duration or 5
            })
        end)
    end
end

-- ═══════════ [ LAYOUT CHIP DINAMIS ] ═══════════
local CHIP_W, CHIP_H, CHIP_GAP = 101, 32, 6
local CHIP_COLS = 3          -- chip per baris
local CHIP_MAX_ROWS = 2      -- baris maksimal sebelum area chip jadi scroll

local chipCount = #CONFIG_DB + 1                     -- +1 untuk tombol Auto Jump
local chipRows = math.ceil(chipCount / CHIP_COLS)
local chipVisibleRows = math.min(chipRows, CHIP_MAX_ROWS)
local chipsHeight = chipVisibleRows * CHIP_H + (chipVisibleRows - 1) * CHIP_GAP
local extraHeight = chipsHeight - CHIP_H

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 340, 0, 350 + extraHeight) 
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.BackgroundColor3 = Colors.Background
MainFrame.BackgroundTransparency = 0.05
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 16)
local MainBorder = Instance.new("UIStroke", MainFrame)
MainBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
MainBorder.Color = Colors.Border
MainBorder.Thickness = 1

-- ── Header ──────────────────────────────────────────────
local TopBar = Instance.new("Frame", MainFrame)
TopBar.Size = UDim2.new(1, 0, 0, 34)
TopBar.BackgroundTransparency = 1

local LogoIcon = MakeIcon(TopBar, "pickaxe", 18, Colors.Accent)
LogoIcon.Position = UDim2.new(0, 12, 0.5, -9)

local Title = NewLabel(TopBar, "V-Ziir0", 15, Enum.Font.GothamBold, Colors.Text)
Title.Size = UDim2.new(0, 56, 1, 0)
Title.Position = UDim2.new(0, 36, 0, 0)

local StatusPill = Instance.new("Frame", TopBar)
StatusPill.Size = UDim2.new(0, 84, 0, 20)
StatusPill.Position = UDim2.new(0, 98, 0.5, -10)
StatusPill.BackgroundColor3 = Colors.GlassPanel
Instance.new("UICorner", StatusPill).CornerRadius = UDim.new(1, 0)
local PillDot = Instance.new("Frame", StatusPill)
PillDot.Size = UDim2.new(0, 6, 0, 6)
PillDot.Position = UDim2.new(0, 9, 0.5, -3)
PillDot.BackgroundColor3 = Colors.TextDim
Instance.new("UICorner", PillDot).CornerRadius = UDim.new(1, 0)
local PillLbl = NewLabel(StatusPill, "Idle", 10, Enum.Font.GothamMedium, Colors.TextDim)
PillLbl.Size = UDim2.new(1, -22, 1, 0)
PillLbl.Position = UDim2.new(0, 20, 0, 0)

local CloseBtn = Instance.new("TextButton", TopBar)
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.Position = UDim2.new(1, -32, 0, 4)
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

local MinBtn = Instance.new("TextButton", TopBar)
MinBtn.Size = UDim2.new(0, 26, 0, 26)
MinBtn.Position = UDim2.new(1, -60, 0, 4) 
MinBtn.BackgroundTransparency = 1
MinBtn.Text = ""
local MinIcon = MakeIcon(MinBtn, "minus", 14, Colors.TextDim)
MinIcon.AnchorPoint = Vector2.new(0.5, 0.5)
MinIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
MinBtn.MouseEnter:Connect(function() SetIconColor(MinIcon, Colors.Text) end)
MinBtn.MouseLeave:Connect(function() SetIconColor(MinIcon, Colors.TextDim) end)

-- ── Tab bar (segmented) ─────────────────────────────────
local TabBar = Instance.new("Frame", MainFrame)
TabBar.Size = UDim2.new(1, -24, 0, 30)
TabBar.Position = UDim2.new(0, 12, 0, 36)
TabBar.BackgroundColor3 = Colors.GlassPanel
Instance.new("UICorner", TabBar).CornerRadius = UDim.new(0, 10)

local function CreateTabButton(name, iconKey, xScale, xOffset)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0.5, -4, 1, -6)
    Btn.Position = UDim2.new(xScale, xOffset, 0, 3)
    Btn.BackgroundColor3 = Colors.Accent
    Btn.BackgroundTransparency = 1
    Btn.AutoButtonColor = false
    Btn.Text = ""
    Btn.Parent = TabBar
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 8)
    local Row = Instance.new("Frame", Btn)
    Row.Size = UDim2.new(1, 0, 1, 0)
    Row.BackgroundTransparency = 1
    local Lay = Instance.new("UIListLayout", Row)
    Lay.FillDirection = Enum.FillDirection.Horizontal
    Lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
    Lay.VerticalAlignment = Enum.VerticalAlignment.Center
    Lay.SortOrder = Enum.SortOrder.LayoutOrder
    Lay.Padding = UDim.new(0, 6)
    local Ic = MakeIcon(Row, iconKey, 14, Colors.TextDim)
    Ic.LayoutOrder = 1
    local Txt = NewLabel(Row, name, 12, Enum.Font.GothamMedium, Colors.TextDim)
    Txt.AutomaticSize = Enum.AutomaticSize.X
    Txt.Size = UDim2.new(0, 0, 1, 0)
    Txt.LayoutOrder = 2
    local active = false
    Btn.MouseEnter:Connect(function() if not active then Txt.TextColor3 = Colors.Text end end)
    Btn.MouseLeave:Connect(function() if not active then Txt.TextColor3 = Colors.TextDim end end)
    local function SetActive(isActive)
        active = isActive
        TweenService:Create(Btn, TweenInfo.new(0.2), {BackgroundTransparency = isActive and 0 or 1}):Play()
        Txt.TextColor3 = isActive and Colors.OnAccent or Colors.TextDim
        SetIconColor(Ic, isActive and Colors.OnAccent or Colors.TextDim)
    end
    return Btn, SetActive
end

local HomeBtn, SetHomeActive = CreateTabButton("Monitor", "monitor", 0, 2)
local AutoBuyBtn, SetAutoBuyActive = CreateTabButton("Auto Buy", "shop", 0.5, 2)

local ContentArea = Instance.new("Frame", MainFrame)
ContentArea.Size = UDim2.new(1, -24, 1, -118)
ContentArea.Position = UDim2.new(0, 12, 0, 74)
ContentArea.BackgroundTransparency = 1

-- ── Chip toggle (pengganti switch) ──────────────────────
local function CreateChipToggle(parent, text, iconKey, layoutOrder, defaultState)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0, 101, 1, 0)
    Btn.BackgroundColor3 = Colors.GlassPanel
    Btn.AutoButtonColor = false
    Btn.Text = ""
    Btn.LayoutOrder = layoutOrder
    Btn.Parent = parent
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 10)
    local Stroke = Instance.new("UIStroke", Btn)
    Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    Stroke.Thickness = 1
    Stroke.Color = Colors.Border
    local Ic = MakeIcon(Btn, iconKey, 16, Colors.TextDim)
    Ic.Position = UDim2.new(0, 8, 0.5, -8)
    local Lbl = NewLabel(Btn, text, 11, Enum.Font.GothamMedium, Colors.TextDim)
    Lbl.Size = UDim2.new(1, -30, 1, 0)
    Lbl.Position = UDim2.new(0, 28, 0, 0)
    Lbl.TextTruncate = Enum.TextTruncate.AtEnd
    local isOn = defaultState
    local function paint()
        local info = TweenInfo.new(0.2)
        TweenService:Create(Btn, info, {BackgroundColor3 = isOn and Colors.ChipOn or Colors.GlassPanel}):Play()
        TweenService:Create(Stroke, info, {Color = isOn and Colors.Accent or Colors.Border}):Play()
        TweenService:Create(Lbl, info, {TextColor3 = isOn and Colors.Accent or Colors.TextDim}):Play()
        SetIconColor(Ic, isOn and Colors.Accent or Colors.TextDim)
    end
    paint()
    Btn.MouseEnter:Connect(function()
        if not isOn then TweenService:Create(Btn, TweenInfo.new(0.15), {BackgroundColor3 = Colors.SwitchOff}):Play() end
    end)
    Btn.MouseLeave:Connect(function()
        if not isOn then TweenService:Create(Btn, TweenInfo.new(0.15), {BackgroundColor3 = Colors.GlassPanel}):Play() end
    end)
    return {
        SetState = function(state) isOn = state; paint() end,
        GetState = function() return isOn end,
        SwitchBg = Btn,
    }
end

-- ── TAB MONITOR ─────────────────────────────────────────
local HomeTab = Instance.new("Frame", ContentArea)
HomeTab.Size = UDim2.new(1, 0, 1, 0)
HomeTab.BackgroundTransparency = 1

local StepsRow = Instance.new("Frame", HomeTab)
StepsRow.Size = UDim2.new(1, 0, 0, 24)
StepsRow.BackgroundTransparency = 1
local StepsLayout = Instance.new("UIListLayout", StepsRow)
StepsLayout.FillDirection = Enum.FillDirection.Horizontal
StepsLayout.SortOrder = Enum.SortOrder.LayoutOrder
StepsLayout.Padding = UDim.new(0, 6)
StepsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local StepPills = {}
local MaxSteps = 3
for i = 1, MaxSteps do
    local P = Instance.new("Frame")
    P.Size = UDim2.new(0, 101, 1, 0)
    P.BackgroundColor3 = Colors.GlassPanel
    P.LayoutOrder = i
    P.Visible = false
    P.Parent = StepsRow
    Instance.new("UICorner", P).CornerRadius = UDim.new(0, 8)
    
    local Row = Instance.new("Frame", P)
    Row.Size = UDim2.new(1, 0, 1, 0)
    Row.BackgroundTransparency = 1
    local Lay = Instance.new("UIListLayout", Row)
    Lay.FillDirection = Enum.FillDirection.Horizontal
    Lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
    Lay.VerticalAlignment = Enum.VerticalAlignment.Center
    Lay.SortOrder = Enum.SortOrder.LayoutOrder
    Lay.Padding = UDim.new(0, 5)
    
    local Ic = MakeIcon(Row, "coin", 12, Colors.TextDim)
    Ic.LayoutOrder = 1
    
    local Ck = MakeIcon(Row, "check", 12, Colors.Green)
    Ck.LayoutOrder = 1
    Ck.Visible = false
    
    local L = NewLabel(Row, "", 10, Enum.Font.GothamMedium, Colors.TextDim, Enum.TextXAlignment.Center)
    L.AutomaticSize = Enum.AutomaticSize.X
    L.Size = UDim2.new(0, 0, 1, 0)
    L.LayoutOrder = 2
    
    StepPills[i] = { Frame = P, Label = L, Icon = Ic, Check = Ck }
end

local RING_SIZE, RING_T = 108, 9
local RingHolder = Instance.new("Frame", HomeTab)
RingHolder.Size = UDim2.new(0, RING_SIZE, 0, RING_SIZE)
RingHolder.Position = UDim2.new(0.5, -RING_SIZE / 2, 0, 30)
RingHolder.BackgroundTransparency = 1

local Track = Instance.new("Frame", RingHolder)
Track.Size = UDim2.new(1, -RING_T * 2, 1, -RING_T * 2)
Track.Position = UDim2.new(0, RING_T, 0, RING_T)
Track.BackgroundTransparency = 1
Instance.new("UICorner", Track).CornerRadius = UDim.new(1, 0)
local TrackStroke = Instance.new("UIStroke", Track)
TrackStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
TrackStroke.Thickness = RING_T
TrackStroke.Color = Colors.Track

local function MakeHalf(isRight)
    local Clip = Instance.new("Frame", RingHolder)
    Clip.Size = UDim2.new(0.5, 0, 1, 0)
    Clip.Position = isRight and UDim2.new(0.5, 0, 0, 0) or UDim2.new(0, 0, 0, 0)
    Clip.BackgroundTransparency = 1
    Clip.ClipsDescendants = true
    local Circ = Instance.new("Frame", Clip)
    Circ.Size = UDim2.new(2, -RING_T * 2, 1, -RING_T * 2)
    Circ.Position = isRight and UDim2.new(-1, RING_T, 0, RING_T) or UDim2.new(0, RING_T, 0, RING_T)
    Circ.BackgroundTransparency = 1
    Instance.new("UICorner", Circ).CornerRadius = UDim.new(1, 0)
    local St = Instance.new("UIStroke", Circ)
    St.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    St.Thickness = RING_T
    St.Color = Colors.Accent
    local Gr = Instance.new("UIGradient", St)
    Gr.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.5, 0),
        NumberSequenceKeypoint.new(0.501, 1),
        NumberSequenceKeypoint.new(1, 1),
    })
    return Gr, St
end
local RightGrad, RightStroke = MakeHalf(true)
local LeftGrad, LeftStroke = MakeHalf(false)

local function SetRing(p)
    local angle = math.clamp(p, 0, 1) * 360
    RightGrad.Rotation = math.clamp(angle, 0, 180)
    LeftGrad.Rotation = math.clamp(angle - 180, 0, 180) - 180
end
SetRing(0)

local PercentLbl = NewLabel(RingHolder, "—", 22, Enum.Font.GothamBold, Colors.Text, Enum.TextXAlignment.Center)
PercentLbl.Size = UDim2.new(1, 0, 0, 26)
PercentLbl.Position = UDim2.new(0, 0, 0.5, -20)
PercentLbl.ZIndex = 5
local SubLbl = NewLabel(RingHolder, "Idle", 11, Enum.Font.GothamMedium, Colors.TextDim, Enum.TextXAlignment.Center)
SubLbl.Size = UDim2.new(1, 0, 0, 14)
SubLbl.Position = UDim2.new(0, 0, 0.5, 6)
SubLbl.ZIndex = 5

local CaptionLbl = NewLabel(HomeTab, "Aktifkan target di bawah", 12, Enum.Font.GothamMedium, Colors.TextDim, Enum.TextXAlignment.Center)
CaptionLbl.Size = UDim2.new(1, 0, 0, 18)
CaptionLbl.Position = UDim2.new(0, 0, 0, 142)

local ChipsRow = Instance.new("ScrollingFrame", HomeTab)
ChipsRow.Size = UDim2.new(1, 0, 0, chipsHeight)
ChipsRow.Position = UDim2.new(0, 0, 0, 166)
ChipsRow.BackgroundTransparency = 1
ChipsRow.BorderSizePixel = 0
ChipsRow.ScrollBarThickness = (chipRows > CHIP_MAX_ROWS) and 3 or 0
ChipsRow.ScrollBarImageColor3 = Colors.Accent
ChipsRow.ScrollingDirection = Enum.ScrollingDirection.Y
ChipsRow.CanvasSize = UDim2.new(0, 0, 0, 0)
ChipsRow.AutomaticCanvasSize = Enum.AutomaticSize.Y

local ChipsLayout = Instance.new("UIGridLayout", ChipsRow)
ChipsLayout.SortOrder = Enum.SortOrder.LayoutOrder
ChipsLayout.FillDirection = Enum.FillDirection.Horizontal
ChipsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
ChipsLayout.CellSize = UDim2.new(0, CHIP_W, 0, CHIP_H)
ChipsLayout.CellPadding = UDim2.new(0, CHIP_GAP, 0, CHIP_GAP)

local monitorToggles = {}
local toggleCallbacks = {}

for i, cfg in ipairs(CONFIG_DB) do
    local toggleObj = CreateChipToggle(ChipsRow, getShortName(cfg.name), (cfg.amount >= 2e12) and "crown" or "target", i, false)
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

local autoJumpToggle = CreateChipToggle(ChipsRow, "Auto Jump", "jump", 9999, false)
autoJumpToggle.SwitchBg.MouseButton1Click:Connect(function()
    local newState = not autoJumpToggle.GetState()
    autoJumpToggle.SetState(newState)
    isAutoJumpEnabled = newState
end)

local StatusLbl = NewLabel(HomeTab, "Status: Pilih target monitor.", 10, Enum.Font.Gotham, Colors.TextDim, Enum.TextXAlignment.Center)
StatusLbl.Size = UDim2.new(1, 0, 0, 16)
StatusLbl.Position = UDim2.new(0, 0, 0, 166 + chipsHeight + 6)
StatusLbl.TextTruncate = Enum.TextTruncate.AtEnd

local FooterBar = Instance.new("Frame", MainFrame)
FooterBar.Size = UDim2.new(1, -16, 0, 28)
FooterBar.Position = UDim2.new(0, 8, 1, -36)
FooterBar.BackgroundColor3 = Colors.GlassPanel
Instance.new("UICorner", FooterBar).CornerRadius = UDim.new(0, 8)

local BuyStatusLbl = NewLabel(FooterBar, "Status: Idle", 11, Enum.Font.GothamBold, Colors.TextDim)
BuyStatusLbl.Size = UDim2.new(1, -16, 1, 0)
BuyStatusLbl.Position = UDim2.new(0, 8, 0, 0)
BuyStatusLbl.TextTruncate = Enum.TextTruncate.AtEnd
BuyStatusLbl.Visible = false

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

-- ── TAB AUTO BUY ────────────────────────────────────────
local AutoBuyTab = Instance.new("Frame", ContentArea)
AutoBuyTab.Size = UDim2.new(1, 0, 1, 0)
AutoBuyTab.BackgroundTransparency = 1
AutoBuyTab.Visible = false

local SelectedCard = Instance.new("Frame", AutoBuyTab)
SelectedCard.Size = UDim2.new(1, 0, 0, 38)
SelectedCard.BackgroundColor3 = Colors.GlassPanel
Instance.new("UICorner", SelectedCard).CornerRadius = UDim.new(0, 10)
local SelCap = NewLabel(SelectedCard, "Kapak target", 10, Enum.Font.Gotham, Colors.TextDim)
SelCap.Size = UDim2.new(1, -20, 0, 14)
SelCap.Position = UDim2.new(0, 10, 0, 5)
local SelValue = NewLabel(SelectedCard, "Belum dipilih", 12, Enum.Font.GothamBold, Colors.Text)
SelValue.Size = UDim2.new(1, -20, 0, 16)
SelValue.Position = UDim2.new(0, 10, 0, 18)

local PickList = Instance.new("ScrollingFrame", AutoBuyTab)
PickList.Size = UDim2.new(1, 0, 1, -44)
PickList.Position = UDim2.new(0, 0, 0, 44)
PickList.BackgroundTransparency = 1
PickList.BorderSizePixel = 0
PickList.ScrollBarThickness = 3
PickList.ScrollBarImageColor3 = Colors.Accent
PickList.CanvasSize = UDim2.new(0, 0, 0, 0)
PickList.AutomaticCanvasSize = Enum.AutomaticSize.Y
local PickLayout = Instance.new("UIListLayout", PickList)
PickLayout.Padding = UDim.new(0, 4)
PickLayout.SortOrder = Enum.SortOrder.LayoutOrder

local PickRows = {}
local function PaintPickaxeRows()
    for _, r in ipairs(PickRows) do
        local sel = autoBuyEnabled and targetPickaxeName == r.name
        r.Btn.BackgroundColor3 = sel and Colors.ChipOn or Colors.GlassPanel
        r.Stroke.Color = sel and Colors.Accent or Colors.Border
        r.NameLbl.TextColor3 = sel and Colors.Accent or Colors.Text
    end
end

for i, pk in ipairs(PICKAXE_DB) do
    local OptionBtn = Instance.new("TextButton")
    OptionBtn.Size = UDim2.new(1, -8, 0, 30)
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
        if not (autoBuyEnabled and targetPickaxeName == pk.name) then OptionBtn.BackgroundColor3 = Colors.SwitchOff end
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
        buyStatus = "Siap beli (ID: "..pk.id..")"
        showNotif("🛒 AUTO BUY AKTIF", "Menunggu uang cukup untuk " .. pk.name, 5)
        PaintPickaxeRows()
    end)
end

-- ── Navigasi tab ────────────────────────────────────────
HomeBtn.MouseButton1Click:Connect(function() 
    SetHomeActive(true); SetAutoBuyActive(false)
    HomeTab.Visible = true; AutoBuyTab.Visible = false
end)
AutoBuyBtn.MouseButton1Click:Connect(function() 
    SetHomeActive(false); SetAutoBuyActive(true)
    HomeTab.Visible = false; AutoBuyTab.Visible = true
end)
SetHomeActive(true)

-- ── Tombol mengambang ────────────────────
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
MinBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false end)

-- ═══════════ [ PENYEGAR TAMPILAN (BACA-SAJA) ] ═══════════
local ProgressValue = Instance.new("NumberValue")
local idleMode = true
ProgressValue.Changed:Connect(function(p)
    SetRing(p)
    if not idleMode then PercentLbl.Text = math.floor(p * 100 + 0.0001) .. "%" end
end)
local function SetProgress(p)
    TweenService:Create(ProgressValue, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Value = p}):Play()
end

local function pctOf(cur, tgt)
    if tgt and tgt > 0 then return math.clamp(cur / tgt, 0, 1) end
    return 0
end

local function computeView()
    local idle = { idx = 0, idle = true, color = Colors.TextDim, sub = "Idle", pct = 0, caption = "Aktifkan target di bawah" }
    if not is_monitoring and not autoBuyEnabled then return idle end

    local function pickaxeView(idx)
        local cash = getRealCash()
        local name, price
        if not hasCheckedOwnership then name, price = prereqName, prereqPrice else name, price = targetPickaxeName, targetBuyPrice end
        return { idx = idx, color = Colors.Amber, sub = name, pct = pctOf(cash, price), caption = formatNumber(cash) .. " / " .. formatNumber(price) }
    end

    if not is_monitoring then return pickaxeView(0) end

    local money_str, speed_str = getMyData()
    local money_num, speed_num = parseNumber(money_str), parseNumber(speed_str)
    local incomeOK = is_income_done or (targetIncome > 0 and money_num >= targetIncome)
    local speedOK = is_speed_done or (targetSpeedValue > 0 and speed_num >= targetSpeedValue)

    if not incomeOK then
        return { idx = 1, color = Colors.Accent, sub = "Income", pct = pctOf(money_num, targetIncome), caption = formatNumber(money_num) .. " / " .. formatNumber(targetIncome) }
    elseif not speedOK then
        return { idx = 2, color = Colors.Green, sub = "Speed", pct = pctOf(speed_num, targetSpeedValue), caption = formatNumber(speed_num) .. " / " .. formatNumber(targetSpeedValue) }
    elseif autoBuyEnabled then
        return pickaxeView(3)
    else
        local owned = buyStatus:find("DIMILIKI") or buyStatus:find("Beli Sukses")
        return { idx = 4, color = Colors.Green, sub = "Selesai", pct = 1, caption = owned and ("Kapak " .. tostring(targetPickaxeName) .. " dimiliki") or "Target tercapai" }
    end
end

local function ApplyView(v)
    idleMode = v.idle == true
    RightStroke.Color = v.color
    LeftStroke.Color = v.color
    SetProgress(v.pct)
    if idleMode then PercentLbl.Text = "—" end
    SubLbl.Text = v.sub
    SubLbl.TextColor3 = v.color
    CaptionLbl.Text = v.caption

    local currentSteps = {}
    if is_monitoring then
        currentSteps = {
            { name = "Income", icon = "coin" },
            { name = "Speed", icon = "bolt" },
            { name = "Kapak", icon = "pickaxe" }
        }
    elseif autoBuyEnabled then
        currentSteps = {
            { name = "Pickaxe", icon = "pickaxe" }
        }
    end

    for i, pill in ipairs(StepPills) do
        local stepData = currentSteps[i]
        if stepData then
            pill.Frame.Visible = true
            pill.Label.Text = stepData.name
            
            if pill.Icon and pill.Icon.Parent then pill.Icon:Destroy() end
            local newIcon = MakeIcon(pill.Label.Parent, stepData.icon, 12, Colors.TextDim)
            newIcon.LayoutOrder = 1
            pill.Icon = newIcon
            
            local done = (v.idx == 4 or v.idx > i)
            pill.Icon.Visible = not done
            pill.Check.Visible = done
            
            if done then
                pill.Frame.BackgroundColor3 = Colors.GlassPanel
                pill.Label.TextColor3 = Colors.Green
            elseif v.idx == i then
                pill.Frame.BackgroundColor3 = Colors.ChipOn
                pill.Label.TextColor3 = v.color
                SetIconColor(pill.Icon, v.color)
            else
                pill.Frame.BackgroundColor3 = Colors.GlassPanel
                pill.Label.TextColor3 = Colors.TextDim
                SetIconColor(pill.Icon, Colors.TextDim)
            end
        else
            pill.Frame.Visible = false
        end
    end

    if is_monitoring then
        PillLbl.Text = "Memantau"
        PillLbl.TextColor3 = Colors.Green
        PillDot.BackgroundColor3 = Colors.Green
    elseif autoBuyEnabled then
        PillLbl.Text = "Auto Buy"
        PillLbl.TextColor3 = Colors.Amber
        PillDot.BackgroundColor3 = Colors.Amber
    else
        PillLbl.Text = "Idle"
        PillLbl.TextColor3 = Colors.TextDim
        PillDot.BackgroundColor3 = Colors.TextDim
    end

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
        
        if is_monitoring then
            StatusLbl.Text = "Memantau: " .. tostring(activeProfileName) .. " (" .. tostring(money_str) .. " / " .. tostring(formatNumber(targetIncome)) .. ")"
        else
            StatusLbl.Text = "Status: Pilih target monitor di atas."
        end
        
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
            if (os.time() - lastWebhookTime) >= 15 then
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
                local currentSpeedNum = parseNumber(speed_str) 
                if currentSpeedNum > lastSpeedCheck then
                    if not hasSpeedIncreased then
                        hasSpeedIncreased = true
                    end
                    stuckTimer = 0
                    lastSpeedCheck = currentSpeedNum
                else
                    if hasSpeedIncreased then stuckTimer = stuckTimer + INTERVAL end
                end
                if hasSpeedIncreased and stuckTimer >= 6 then
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
            
            if not is_monitoring and (os.time() - lastWebhookTime) >= 15 then
                local m_str, s_str = getMyData()
                sendToDiscord(m_str, s_str, "🛒 AUTO BUY PROGRESS")
                lastWebhookTime = os.time()
            end
        else
            BuyStatusLbl.Text = "Status: Idle (Pilih Kapak)"
            BuyStatusLbl.TextColor3 = Colors.TextDim
        end
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