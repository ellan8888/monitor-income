-- ═══════════════════════════════════════════════════════
-- 🥚 V-Ziir0 Hub: Steal An Egg Monitor (FULL V19)
-- ═══════════════════════════════════════════════════════

local player = game.Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local playerGui = player:WaitForChild("PlayerGui")
local Workspace = game:GetService("Workspace")

local WEBHOOK_URL = "https://discord.com/api/webhooks/1560789097440616529/097v0ksImZfYm2g4zSQKbEvb-9ttIwSHah-v5nxavKklco3t5S71rMR9vySSjOwtMEEn"
local INTERVAL = 15
local httpFn = request or http_request or (http and http.request)

if not httpFn then
    warn("❌ Nggak ada fungsi request!")
    return
end

local lastMoney = nil
local lastSpeed = nil
local lastEggCount = nil
local lastMapName = nil

-- ═══════════ [ FITUR WEBHOOK ] ═══════════
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

-- ═══════════ [ FITUR MAP & EGG SCANNER (V19 LOGIC) ] ═══════════
local function getFarthestMapAndEgg()
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return "Unknown", 0 end
    local hrp = char.HumanoidRootPart

    -- 1. Cari Map Terjauh
    local world = Workspace:FindFirstChild("World")
    local areas = world and world:FindFirstChild("Areas")
    local guardAreas = areas and areas:FindFirstChild("GuardAreas")
    
    local farthestMapName = "Unknown"
    local maxDist = 0

    if guardAreas then
        for _, area in ipairs(guardAreas:GetChildren()) do
            local part = area:FindFirstChildWhichIsA("BasePart", true)
            if part then
                local dist = (hrp.Position - part.Position).Magnitude
                if dist > maxDist then
                    maxDist = dist
                    farthestMapName = area.Name
                end
            end
        end
    end

    -- 2. Scan Isi Backpack + Hotbar + Nil + Dipegang untuk Map Terjauh
    local totalEggFisik = 0
    local backpackGui = playerGui:FindFirstChild("BackpackGui")

    local function checkSlot(slot)
        local toolNameLabel = slot:FindFirstChild("ToolName") or slot:FindFirstChild("Name")
        local itemName = nil
        
        if toolNameLabel and toolNameLabel:IsA("TextLabel") then
            itemName = toolNameLabel.Text
        elseif slot:IsA("ImageLabel") or slot:IsA("TextButton") then
            for _, desc in ipairs(slot:GetDescendants()) do
                if desc:IsA("TextLabel") and desc.Text ~= "" then
                    itemName = desc.Text
                    break
                end
            end
        end

        if itemName and itemName:lower():find("egg") and itemName:lower():find(farthestMapName:lower()) then
            local multiplier = 1
            for _, desc in ipairs(slot:GetDescendants()) do
                if desc:IsA("TextLabel") then
                    local matchMulti = string.match(desc.Text, "[xX](%d+)")
                    if matchMulti then multiplier = tonumber(matchMulti) or 1 end
                end
            end
            totalEggFisik = totalEggFisik + multiplier
        end
    end

    -- A. Scan Backpack
    if backpackGui then
        backpackGui.Enabled = true
        local invFrame = backpackGui:FindFirstChild("Backpack")
        if invFrame then invFrame = invFrame:FindFirstChild("Main") end
        if invFrame then invFrame = invFrame:FindFirstChild("Inventory") end
        if invFrame then invFrame = invFrame:FindFirstChild("ScrollingFrame") end

        if invFrame then
            for _, slot in ipairs(invFrame:GetChildren()) do
                if slot:IsA("Frame") or slot:IsA("ImageLabel") or slot:IsA("TextButton") then
                    checkSlot(slot)
                end
            end
        end
    end

    -- B. Scan Tool yang dipegang
    for _, obj in ipairs(char:GetChildren()) do
        if obj:IsA("Tool") and obj.Name:lower():find("egg") and obj.Name:lower():find(farthestMapName:lower()) then
            totalEggFisik = totalEggFisik + 1
        end
    end

    -- C. Scan Nil Instances (Hotbar)
    if getnilinstances then
        for _, obj in ipairs(getnilinstances()) do
            local success, isEggTool = pcall(function()
                return obj:IsA("Tool") and obj.Name:lower():find("egg") and obj.Name:lower():find(farthestMapName:lower())
            end)
            if success and isEggTool then
                totalEggFisik = totalEggFisik + 1
            end
        end
    end

    return farthestMapName, totalEggFisik
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
    -- (Fallback UI scraping tetap sama)
    return money, speed
end

-- ═══════════ [ KIRIM KE DISCORD ] ═══════════
local function sendToDiscord(money, speed, mapName, eggCount)
    local embed = {
        title = "🥚 STEAL AN EGG MONITOR 🥚",
        description = "```ini\n[ @" .. player.Name .. " ]```\n**━━━━━━━━━━━━━━━━━━━━━━━━**",
        color = 0xFFAA00,
        fields = {
            { name = "💰 ▸ INCOME", value = "```yaml\n" .. money .. "```", inline = true },
            { name = "⚡ ▸ SPEED", value = "```yaml\n" .. speed .. "```", inline = true },
            { name = "🗺️ ▸ LAST MAP", value = "```yaml\n" .. mapName .. "```", inline = true },
            { name = "🥚 ▸ EGG " .. mapName:upper(), value = "```yaml\n" .. eggCount .. " Egg```", inline = true },
            { name = "🎯 ▸ STATUS", value = "```diff\n+ FARMING ACTIVE```", inline = false },
        },
        footer = { text = "V-Ziir0 Hub • " .. os.date("%H:%M:%S") },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
    sendWebhook({ username = "🥚 Egg Monitor", avatar_url = "https://cdn-icons-png.flaticon.com/512/1055/1055687.png", embeds = { embed } })
end

-- ═══════════ [ LOOP UTAMA ] ═══════════
task.spawn(function()
    print("✅ Monitor Steal An Egg (Last Map Egg) berjalan!")
    while task.wait(INTERVAL) do
        local money, speed = getMyData()
        local mapName, eggCount = getFarthestMapAndEgg()
        
        -- Kirim jika ada perubahan data
        if money ~= lastMoney or speed ~= lastSpeed or eggCount ~= lastEggCount or mapName ~= lastMapName then
            sendToDiscord(money, speed, mapName, eggCount)
            lastMoney, lastSpeed = money, speed
            lastEggCount, lastMapName = eggCount, mapName
            print("📤 Webhook terkirim! Map: " .. mapName .. " | Egg: " .. eggCount)
        end
    end
end)

-- ═══════════════════════════════════════════════════════
-- ⭐ AUTO-EXECUTE SAAT REJOIN / HOP SERVER
-- ═══════════════════════════════════════════════════════
local function autoReExecute()
    -- ⚠️ GANTI URL INI DENGAN LINK RAW GITHUB SCRIPT EGG KAMU
    local url = "https://raw.githubusercontent.com/ellan8888/monitor-income/refs/heads/main/steal-an-egg-monitor.lua" 
    
    local scriptToRun = "loadstring(game:HttpGet('" .. url .. "'))()"
    
    local success = pcall(function()
        if syn and syn.queue_on_teleport then
            syn.queue_on_teleport(scriptToRun)
        elseif queue_on_teleport then
            queue_on_teleport(scriptToRun)
        elseif fluxus and fluxus.queue_on_teleport then
            fluxus.queue_on_teleport(scriptToRun)
        elseif getgenv().queue_on_teleport then
            getgenv().queue_on_teleport(scriptToRun)
        end
    end)
    
    if not success then
        warn("⚠️ Executor kamu nggak support queue_on_teleport. Pakai folder autoexec aja.")
    end
end

autoReExecute()