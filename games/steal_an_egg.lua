-- ═══════════════════════════════════════════════════════
-- 🥚 V-Ziir0 Hub: Steal An Egg (v40 - Auto Resume After Hop)
-- v40: setelah server hop, script otomatis jalan lagi dan MELANJUTKAN monitor
--      beserta daftar target dari server sebelumnya (config dibaca dari file).
-- UI sama dengan v39. Logika sniper/auto place/webhook tidak diubah.
-- ═══════════════════════════════════════════════════════

-- ⭐ TUNGGU GAME SIAP (penting saat dijalankan otomatis setelah teleport)
if not game:IsLoaded() then game.Loaded:Wait() end

-- ⭐ SISTEM ANTI-DOUBLE
if _G.StealEgg_Hub_Active then
    pcall(function()
        if _G.StealEgg_Hub_UI then _G.StealEgg_Hub_UI:Destroy() end
        _G.StealEgg_LoopBroken = true
    end)
    print("♻️ [Anti-Double] Menghapus script lama...")
    task.wait(0.5)
end
_G.StealEgg_Hub_Active = true
_G.StealEgg_Hub_UI = nil
_G.StealEgg_LoopBroken = false
-- ID unik per eksekusi: loop dari eksekusi lama otomatis berhenti kalau ada eksekusi baru
local RUN_ID = tostring(os.clock()) .. "-" .. tostring(math.random(1, 1000000000))
_G.StealEgg_RunId = RUN_ID

local player = game.Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

-- ⭐ TUNGGU KARAKTER BENERAN ADA (setelah hop/teleport)
if not player.Character then
    print("⏳ [Wait] Nunggu karakter muncul...")
    player.CharacterAdded:Wait()
    print("✅ [Wait] Karakter muncul!")
end
task.wait(2) -- Extra wait biar leaderstats & GUI siap

local WEBHOOK_URL = "https://discord.com/api/webhooks/1560789097440616529/097v0ksImZfYm2g4zSQKbEvb-9ttIwSHah-v5nxavKklco3t5S71rMR9vySSjOwtMEEn"
local INTERVAL = 15
local SNIPER_INTERVAL = 5
local httpFn = request or http_request or (http and http.request)

if not httpFn then warn("❌ Nggak ada fungsi request!"); return end

-- ═══════════ [ STATE & CONFIG ] ═══════════
_G.StealEgg_Config = _G.StealEgg_Config or {
    MonitorEnabled = false,
    WebhookEnabled = false,
    DetectedTargets = {},
    LastHopJobId = nil,
    OriginalTargets = {},
    HopCount = 0
}

local config = _G.StealEgg_Config
config.DetectedTargets = config.DetectedTargets or {}
config.OriginalTargets = config.OriginalTargets or {}
config.HopCount = config.HopCount or 0

local is_monitoring = config.MonitorEnabled
local is_hopping = false
local speedThreshold = 15 * 1e6
local isHuntingMode = false
local lastMoney, lastSpeed, lastMapName, lastEggCount = nil, nil, nil, nil
local webhookStatusText = "+ FARMING ACTIVE"

-- ═══════════ [ FUNGSI SAVE/LOAD CONFIG ] ═══════════
local function saveConfig()
    _G.StealEgg_Config = config
    pcall(function() getgenv().__VZ_StealEgg_Config = config end)
    if writefile then
        pcall(function()
            local json = HttpService:JSONEncode(config)
            writefile("vziir0_egg_config.json", json)
        end)
    end
end

local function applyLoadedConfig(data)
    for k, v in pairs(data) do
        config[k] = v
    end
    is_monitoring = config.MonitorEnabled
end

local function loadConfig()
    -- 1) File di workspace executor = sumber utama (tetap ada setelah teleport / server hop)
    if readfile and isfile and isfile("vziir0_egg_config.json") then
        local ok, content = pcall(function() return readfile("vziir0_egg_config.json") end)
        if ok and content and content ~= "" then
            local ok2, data = pcall(function() return HttpService:JSONDecode(content) end)
            if ok2 and type(data) == "table" and data.MonitorEnabled ~= nil then
                applyLoadedConfig(data)
                return true
            end
        end
    end
    -- 2) Cadangan: getgenv (di sebagian executor tetap hidup setelah teleport)
    local okG, g = pcall(function() return getgenv().__VZ_StealEgg_Config end)
    if okG and type(g) == "table" and g.MonitorEnabled ~= nil then
        applyLoadedConfig(g)
        return true
    end
    -- 3) Sesi yang sama (script dijalankan ulang tanpa teleport)
    if _G.StealEgg_Config and _G.StealEgg_Config.MonitorEnabled ~= nil then
        applyLoadedConfig(_G.StealEgg_Config)
        return true
    end
    return false
end

loadConfig()
config.DetectedTargets = config.DetectedTargets or {}
config.OriginalTargets = config.OriginalTargets or {}

-- ═══════════ [ AUTO EXECUTE SETELAH TELEPORT ] ═══════════
-- Hanya mendaftar SATU kali per sesi supaya tidak jalan dobel setelah teleport.
local reExecQueued = false
local function queueReExecute()
    if reExecQueued then return true end
    local url = "https://raw.githubusercontent.com/ellan8888/monitor-income/refs/heads/main/steal_an_egg.lua"
    local scriptToRun = "loadstring(game:HttpGet('" .. url .. "'))()"
    local queued = false
    pcall(function()
        if syn and syn.queue_on_teleport then syn.queue_on_teleport(scriptToRun); queued = true
        elseif queue_on_teleport then queue_on_teleport(scriptToRun); queued = true
        elseif fluxus and fluxus.queue_on_teleport then fluxus.queue_on_teleport(scriptToRun); queued = true
        elseif getgenv().queue_on_teleport then getgenv().queue_on_teleport(scriptToRun); queued = true end
    end)
    if queued then reExecQueued = true end
    return queued
end

-- ═══════════ [ FUNGSI BIGFROOT ] ═══════════
local function setBigFrootAutoPlace(state)
    local bigFrootSAE = getgenv().__BigFrootSAE
    if bigFrootSAE and bigFrootSAE.Flags then
        bigFrootSAE.Flags.AutoPlaceAll = state
        print("🔄 [BigFroot] AutoPlaceAll = " .. tostring(state))
        return true
    end
    return false -- Skip warning biar ga spam
end

-- ═══════════ [ FUNGSI NASI RENDANG ] ═══════════
_G.setNasiRendangAutoPlace = function(state)
    local PlayerGui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
    if not PlayerGui then return false end

    local targetLabel = nil
    local targetBtn = nil

    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        if obj:IsA("TextLabel") and string.find(string.lower(obj.Text), "auto place all egg") then
            targetLabel = obj
            local parent = obj.Parent
            for _, sibling in ipairs(parent:GetChildren()) do
                if (sibling:IsA("TextButton") or sibling:IsA("ImageButton")) and sibling.AbsolutePosition.X > obj.AbsolutePosition.X then
                    targetBtn = sibling
                    break
                end
            end
        end
        if targetBtn then break end
    end

    if not targetBtn then return false end

    -- Cek Status Visual (Anti Double-Toggle)
    local isCurrentlyOn = false
    local success, bgColor = pcall(function() return targetBtn.BackgroundColor3 end)
    if success and bgColor then
        if bgColor.R > 0.5 or bgColor.G > 0.5 or bgColor.B > 0.5 then
            isCurrentlyOn = true
        end
    end

    if state == true and isCurrentlyOn then return true end
    if state == false and not isCurrentlyOn then return true end

    pcall(function() firesignal(targetBtn.MouseButton1Click) end)
    print("🔄 [Nasi Rendang] Auto Place All Egg -> " .. tostring(state))
    return true
end

-- ═══════════ [ FUNGSI SCAN PLAYER ] ═══════════
local function scanCurrentPlayers()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            table.insert(list, p.Name)
        end
    end
    return list
end

local function mergeTargets(newList)
    local existing = {}
    for _, name in ipairs(config.DetectedTargets) do
        existing[name:lower()] = true
    end
    local added = 0
    for _, name in ipairs(newList) do
        if not existing[name:lower()] then
            table.insert(config.DetectedTargets, name)
            existing[name:lower()] = true
            added = added + 1
        end
    end
    return added
end

local function checkTargetsInServer(targetList)
    for _, p in ipairs(Players:GetPlayers()) do
        for _, name in ipairs(targetList) do
            if p.Name:lower() == name:lower() then
                return true
            end
        end
    end
    return false
end

-- ═══════════ [ WEBHOOK ] ═══════════
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

local function sendMonitorWebhook(money, speed, mapName, eggCount, statusText)
    if not is_monitoring and not config.WebhookEnabled then return end
    
    local embed = {
        title = "🥚 STEAL AN EGG MONITOR 🥚",
        description = "```ini\n[ @" .. player.Name .. " ]```\n**━━━━━━━━━━━━━━━━━━━━━━━━**",
        color = 0xFFAA00,
        fields = {
            { name = "💰 ▸ INCOME", value = "```yaml\n" .. money .. "```", inline = true },
            { name = "⚡ ▸ SPEED", value = "```yaml\n" .. speed .. "```", inline = true },
            { name = "🗺️ ▸ LAST MAP", value = "```yaml\n" .. mapName .. "```", inline = true },
            { name = "🥚 ▸ EGG " .. mapName:upper(), value = "```yaml\n" .. eggCount .. " Egg```", inline = true },
            { name = "🎯 ▸ TARGETS", value = "```yaml\n" .. #config.DetectedTargets .. " players tracked\nHop: " .. config.HopCount .. "```", inline = true },
            { name = "📌 ▸ STATUS", value = "```diff\n" .. statusText .. "```", inline = false },
        },
        footer = { text = "V-Ziir0 Hub v38 • " .. os.date("%H:%M:%S") },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
    sendWebhook({ username = "🥚 Egg Monitor", avatar_url = "https://cdn.flaticon.com/512/1055/1055687.png", embeds = { embed } })
end

-- ═══════════ [ FORMAT & SCANNER ] ═══════════
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

local function getMyData()
    local money, speed = "0", "0"
    local speedNum = 0
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        for _, stat in ipairs(ls:GetChildren()) do
            local n = stat.Name:lower()
            if n:find("money") or n:find("cash") or n:find("income") then money = formatNumber(cleanNumber(stat.Value))
            elseif n:find("speed") or n:find("kecepatan") then
                speed = formatNumber(cleanNumber(stat.Value))
                speedNum = tonumber(cleanNumber(stat.Value)) or 0
            end
        end
    end
    return money, speed, speedNum
end

local function getFarthestMapAndEgg()
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return "Unknown", 0 end
    local hrp = char.HumanoidRootPart
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

    local totalEggFisik = 0
    local backpackGui = player:WaitForChild("PlayerGui"):FindFirstChild("BackpackGui")

    local function checkSlot(slot)
        local toolNameLabel = slot:FindFirstChild("ToolName") or slot:FindFirstChild("Name")
        local itemName = nil
        if toolNameLabel and toolNameLabel:IsA("TextLabel") then itemName = toolNameLabel.Text
        elseif slot:IsA("ImageLabel") or slot:IsA("TextButton") then
            for _, desc in ipairs(slot:GetDescendants()) do
                if desc:IsA("TextLabel") and desc.Text ~= "" then itemName = desc.Text; break end
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

    if backpackGui then
        backpackGui.Enabled = true
        local invFrame = backpackGui:FindFirstChild("Backpack")
        if invFrame then invFrame = invFrame:FindFirstChild("Main") end
        if invFrame then invFrame = invFrame:FindFirstChild("Inventory") end
        if invFrame then invFrame = invFrame:FindFirstChild("ScrollingFrame") end
        if invFrame then
            for _, slot in ipairs(invFrame:GetChildren()) do
                if slot:IsA("Frame") or slot:IsA("ImageLabel") or slot:IsA("TextButton") then checkSlot(slot) end
            end
        end
    end

    for _, obj in ipairs(char:GetChildren()) do
        if obj:IsA("Tool") and obj.Name:lower():find("egg") and obj.Name:lower():find(farthestMapName:lower()) then
            totalEggFisik = totalEggFisik + 1
        end
    end

    if getnilinstances then
        for _, obj in ipairs(getnilinstances()) do
            local success, isEggTool = pcall(function()
                return obj:IsA("Tool") and obj.Name:lower():find("egg") and obj.Name:lower():find(farthestMapName:lower())
            end)
            if success and isEggTool then totalEggFisik = totalEggFisik + 1 end
        end
    end
    return farthestMapName, totalEggFisik
end

-- ═══════════ [ SERVER HOP ] ═══════════
local function hopServer()
    if is_hopping then return end
    is_hopping = true
    config.HopCount = (config.HopCount or 0) + 1
    print("🚀 [SNIPER] Target Ditemukan! Nge-hop server... (Hop #" .. config.HopCount .. ")")

    config.LastHopJobId = game.JobId
    config.LastHopTime = os.time()
    saveConfig() -- simpan monitor ON + daftar target SEBELUM pindah server

    if not queueReExecute() then
        warn("⚠️ [SNIPER] queue_on_teleport nggak didukung executor. Taruh script di folder AutoExecute biar jalan lagi setelah hop.")
    end

    task.wait(0.5)

    local PLACE_ID = game.PlaceId
    local url_api = "https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?sortOrder=Asc&limit=100"

    local raw = nil
    local ok1, res1 = pcall(function() return game:HttpGet(url_api) end)
    if ok1 and res1 then raw = res1
    else
        local ok2, res2 = pcall(function() return httpFn({ Url = url_api, Method = "GET" }) end)
        if ok2 and type(res2) == "table" and res2.Body then raw = res2.Body end
    end

    local success, response = false, nil
    if raw then
        success, response = pcall(function() return HttpService:JSONDecode(raw) end)
    end

    if success and response and response.data then
        for _, server in ipairs(response.data) do
            local playing = tonumber(server.playing)
            local maxP = tonumber(server.maxPlayers)
            if playing and maxP then
                if playing < maxP and server.id ~= game.JobId and server.id ~= config.LastHopJobId then
                    pcall(function() TeleportService:TeleportToPlaceInstance(PLACE_ID, server.id, player) end)
                    -- kalau teleport gagal (server penuh dll), buka kunci hop supaya bisa coba lagi
                    task.delay(25, function() is_hopping = false end)
                    return
                end
            end
        end
    end
    warn("❌ Gagal nemu server kosong buat hop.")
    is_hopping = false
end

-- ═══════════════════════════════════════════════════════
-- ⭐ UI CUSTOM (V39 - PHASE RING + EGG BACKPACK)
-- Bagian ini murni tampilan. Variabel logika hanya DIBACA oleh UI,
-- kecuali handler klik yang isinya sama persis dengan versi sebelumnya.
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
    AmberBg = Color3.fromRGB(43, 36, 23),
}

local EGG_GOAL = 100 -- target egg di tampilan (hanya UI, script tidak berhenti di angka ini)

-- ⭐ IKON: digambar langsung dari bentuk (Frame), tidak butuh asset ID.
-- Opsional: isi "rbxassetid://ID" untuk mengganti ikon tertentu dengan gambar.
local Icons = {
    egg = "", monitor = "", target = "", close = "", minus = "", check = "", checkc = "",
    hourglass = "", bolt = "", user = "", hop = "", send = "", scan = "", backpack = "", refresh = "",
}
local IconPaint = setmetatable({}, { __mode = "k" })

local IconDefs = {
    close = function(H) H.line(3.2, 3.2, 12.8, 12.8, 1.8); H.line(12.8, 3.2, 3.2, 12.8, 1.8) end,
    minus = function(H) H.line(3, 8, 13, 8, 1.8) end,
    check = function(H) H.line(3, 8.5, 6.5, 12, 1.9); H.line(6.5, 12, 13, 4.5, 1.9) end,
    monitor = function(H) H.rect(2, 9, 3, 5, 0.15); H.rect(6.5, 5, 3, 9, 0.15); H.rect(11, 2, 3, 12, 0.15) end,
    target = function(H) H.ring(1.5, 1.5, 13, 13, 1.5); H.ring(4.5, 4.5, 7, 7, 1.5); H.dot(8, 8, 2.2) end,
    hourglass = function(H)
        H.line(4, 2.5, 12, 2.5, 1.6); H.line(4, 13.5, 12, 13.5, 1.6)
        H.line(4.8, 3.4, 11.2, 12.6, 1.5); H.line(11.2, 3.4, 4.8, 12.6, 1.5)
    end,
    bolt = function(H) H.line(9.8, 1.5, 4.5, 8.8, 1.8); H.line(4.5, 8.8, 11.5, 8.8, 1.8); H.line(11.5, 8.8, 6.2, 14.5, 1.8) end,
    checkc = function(H) H.ring(1.5, 1.5, 13, 13, 1.5); H.line(5, 8.2, 7.1, 10.3, 1.5); H.line(7.1, 10.3, 11, 5.8, 1.5) end,
    egg = function(H) H.ring(3, 1.5, 10, 13.5, 1.6, 0.5); H.dot(6.3, 6.2, 1.8) end,
    user = function(H) H.dot(8, 5, 5); H.rect(3.5, 10.5, 9, 4.5, 0.5) end,
    hop = function(H)
        H.line(2.5, 5, 13, 5, 1.6); H.line(10.2, 2.4, 13, 5, 1.6); H.line(10.2, 7.6, 13, 5, 1.6)
        H.line(13.5, 11, 3, 11, 1.6); H.line(5.8, 8.4, 3, 11, 1.6); H.line(5.8, 13.6, 3, 11, 1.6)
    end,
    send = function(H)
        H.line(2, 8, 14, 2, 1.6); H.line(14, 2, 10, 14, 1.6); H.line(10, 14, 7.5, 9.5, 1.6)
        H.line(7.5, 9.5, 2, 8, 1.6); H.line(14, 2, 7.5, 9.5, 1.6)
    end,
    scan = function(H) H.ring(2, 2, 9.5, 9.5, 1.6); H.line(10, 10, 14, 14, 1.9) end,
    backpack = function(H)
        H.ring(5, 1.2, 6, 6, 1.4, 0.5)
        H.ring(3, 5, 10, 10.5, 1.6, 0.22)
        H.line(5.6, 10.5, 10.4, 10.5, 1.5)
    end,
    refresh = function(H)
        local px, py
        for a = 20, 300, 35 do
            local x = 8 + 5 * math.cos(math.rad(a))
            local y = 8 + 5 * math.sin(math.rad(a))
            if px then H.line(px, py, x, y, 1.6) end
            px, py = x, y
        end
        H.line(px, py, px + 3, py + 0.3, 1.6)
        H.line(px, py, px + 0.2, py - 3, 1.6)
    end,
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

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VZiir0HubGlass"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = CoreGui
_G.StealEgg_Hub_UI = ScreenGui

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 340, 0, 374)
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

local LogoIcon = MakeIcon(TopBar, "egg", 18, Colors.Accent)
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
    _G.StealEgg_Hub_Active = false
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

local MonitorBtn, SetMonitorActive = CreateTabButton("Monitor", "monitor", 0, 2)
local EggBtn, SetEggActive = CreateTabButton("Egg", "backpack", 0.5, 2)

local ContentArea = Instance.new("Frame", MainFrame)
ContentArea.Size = UDim2.new(1, -24, 1, -118)
ContentArea.Position = UDim2.new(0, 12, 0, 74)
ContentArea.BackgroundTransparency = 1

-- ── Chip toggle (pengganti switch) ──────────────────────
local function CreateChipToggle(parent, text, iconKey, layoutOrder, defaultState, callback, width)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0, width or 101, 1, 0)
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
    Ic.Position = UDim2.new(0, 10, 0.5, -8)
    local Lbl = NewLabel(Btn, text, 11, Enum.Font.GothamMedium, Colors.TextDim)
    Lbl.Size = UDim2.new(1, -34, 1, 0)
    Lbl.Position = UDim2.new(0, 32, 0, 0)
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
    Btn.MouseButton1Click:Connect(function()
        local newState = not isOn
        isOn = newState
        paint()
        if callback then callback(newState) end
    end)
    return {
        SetState = function(state) isOn = state; paint() end,
        GetState = function() return isOn end,
        Callback = callback,
    }
end

-- ── TAB MONITOR ─────────────────────────────────────────
local MonitorTab = Instance.new("Frame", ContentArea)
MonitorTab.Size = UDim2.new(1, 0, 1, 0)
MonitorTab.BackgroundTransparency = 1

-- Langkah: Farming > Hop > Egg
local StepsRow = Instance.new("Frame", MonitorTab)
StepsRow.Size = UDim2.new(1, 0, 0, 22)
StepsRow.BackgroundTransparency = 1
local StepsLayout = Instance.new("UIListLayout", StepsRow)
StepsLayout.FillDirection = Enum.FillDirection.Horizontal
StepsLayout.SortOrder = Enum.SortOrder.LayoutOrder
StepsLayout.Padding = UDim.new(0, 6)

local StepNames = { "Farming", "Hop", "Egg" }
local StepIconKeys = { "egg", "hop", "egg" }
local StepPills = {}
for i, nm in ipairs(StepNames) do
    local P = Instance.new("Frame")
    P.Size = UDim2.new(0, 101, 1, 0)
    P.BackgroundColor3 = Colors.GlassPanel
    P.LayoutOrder = i
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
    local Ic = MakeIcon(Row, StepIconKeys[i], 12, Colors.TextDim)
    Ic.LayoutOrder = 1
    local Ck = MakeIcon(Row, "check", 12, Colors.Green)
    Ck.LayoutOrder = 1
    Ck.Visible = false
    local L = NewLabel(Row, nm, 10, Enum.Font.GothamMedium, Colors.TextDim, Enum.TextXAlignment.Center)
    L.AutomaticSize = Enum.AutomaticSize.X
    L.Size = UDim2.new(0, 0, 1, 0)
    L.LayoutOrder = 2
    StepPills[i] = { Frame = P, Label = L, Icon = Ic, Check = Ck }
end

-- Ring progress (dua setengah lingkaran + UIGradient pada UIStroke)
local RING_SIZE, RING_T = 96, 8
local RingHolder = Instance.new("Frame", MonitorTab)
RingHolder.Size = UDim2.new(0, RING_SIZE, 0, RING_SIZE)
RingHolder.Position = UDim2.new(0.5, -RING_SIZE / 2, 0, 28)
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

local PercentLbl = NewLabel(RingHolder, "—", 20, Enum.Font.GothamBold, Colors.Text, Enum.TextXAlignment.Center)
PercentLbl.Size = UDim2.new(1, 0, 0, 24)
PercentLbl.Position = UDim2.new(0, 0, 0.5, -18)
PercentLbl.ZIndex = 5
local SubLbl = NewLabel(RingHolder, "Idle", 10, Enum.Font.GothamMedium, Colors.TextDim, Enum.TextXAlignment.Center)
SubLbl.Size = UDim2.new(1, 0, 0, 14)
SubLbl.Position = UDim2.new(0, 0, 0.5, 6)
SubLbl.ZIndex = 5

local CaptionLbl = NewLabel(MonitorTab, "Aktifkan monitor di bawah", 12, Enum.Font.GothamMedium, Colors.TextDim, Enum.TextXAlignment.Center)
CaptionLbl.Size = UDim2.new(1, 0, 0, 16)
CaptionLbl.Position = UDim2.new(0, 0, 0, 126)
CaptionLbl.TextTruncate = Enum.TextTruncate.AtEnd

-- Kartu statistik: Egg, Hop, Auto Place
local StatsRow = Instance.new("Frame", MonitorTab)
StatsRow.Size = UDim2.new(1, 0, 0, 38)
StatsRow.Position = UDim2.new(0, 0, 0, 148)
StatsRow.BackgroundTransparency = 1
local StatsLayout = Instance.new("UIListLayout", StatsRow)
StatsLayout.FillDirection = Enum.FillDirection.Horizontal
StatsLayout.SortOrder = Enum.SortOrder.LayoutOrder
StatsLayout.Padding = UDim.new(0, 6)

local function CreateStatCard(iconKey, caption, order)
    local C = Instance.new("Frame")
    C.Size = UDim2.new(0, 101, 1, 0)
    C.BackgroundColor3 = Colors.GlassPanel
    C.LayoutOrder = order
    C.Parent = StatsRow
    Instance.new("UICorner", C).CornerRadius = UDim.new(0, 10)
    local Ic = MakeIcon(C, iconKey, 16, Colors.Accent)
    Ic.Position = UDim2.new(0, 9, 0.5, -8)
    local Val = NewLabel(C, "—", 14, Enum.Font.GothamBold, Colors.Text)
    Val.Size = UDim2.new(1, -34, 0, 18)
    Val.Position = UDim2.new(0, 32, 0, 4)
    local Cap = NewLabel(C, caption, 9, Enum.Font.Gotham, Colors.TextDim)
    Cap.Size = UDim2.new(1, -34, 0, 12)
    Cap.Position = UDim2.new(0, 32, 0, 22)
    Cap.TextTruncate = Enum.TextTruncate.AtEnd
    return { Val = Val, Cap = Cap }
end
local StatEgg = CreateStatCard("egg", "Egg", 1)
local StatHop = CreateStatCard("hop", "Hop", 2)
local StatPlace = CreateStatCard("bolt", "Auto Place", 3)

-- Toggle: Monitor + Webhook manual
local ChipsRow = Instance.new("Frame", MonitorTab)
ChipsRow.Size = UDim2.new(1, 0, 0, 30)
ChipsRow.Position = UDim2.new(0, 0, 0, 192)
ChipsRow.BackgroundTransparency = 1
local ChipsLayout = Instance.new("UIListLayout", ChipsRow)
ChipsLayout.FillDirection = Enum.FillDirection.Horizontal
ChipsLayout.SortOrder = Enum.SortOrder.LayoutOrder
ChipsLayout.Padding = UDim.new(0, 6)

local webhookToggle -- Deklarasi awal

-- Toggle Monitor
local monitorToggle = CreateChipToggle(ChipsRow, "Monitor Egg", "egg", 1, config.MonitorEnabled, function(state)
    config.MonitorEnabled = state
    is_monitoring = state
    
    if state then
        -- ⭐ NYALAIN AUTO PLACE (DUA-DUANYA)
        setBigFrootAutoPlace(true) 
        _G.setNasiRendangAutoPlace(true) 
        
        if webhookToggle then webhookToggle.SetState(false) end 
        config.WebhookEnabled = false 
        
        local initial = scanCurrentPlayers()
        config.OriginalTargets = {}
        for _, n in ipairs(initial) do table.insert(config.OriginalTargets, n) end
        config.DetectedTargets = {}
        for _, n in ipairs(initial) do table.insert(config.DetectedTargets, n) end
        print("📋 [Target] Snapshot awal: " .. #config.DetectedTargets .. " player.")
        
        StarterGui:SetCore("SendNotification", {Title = "Monitor Egg ON", Text = "Auto Place (BigFroot + Nasi Rendang) aktif.", Duration = 5})
    else
        -- ⭐ MATIIN AUTO PLACE (DUA-DUANYA)
        setBigFrootAutoPlace(false) 
        _G.setNasiRendangAutoPlace(false)
        
        StarterGui:SetCore("SendNotification", {Title = "Monitor Egg OFF", Text = "Monitor & Auto Place berhenti.", Duration = 3})
    end
    saveConfig()
end, 155)

-- Toggle Webhook Manual
webhookToggle = CreateChipToggle(ChipsRow, "Webhook Manual", "send", 2, config.WebhookEnabled, function(state)
    if is_monitoring then
        webhookToggle.SetState(false)
        StarterGui:SetCore("SendNotification", {Title = "Webhook Terkunci", Text = "Matikan Monitor dulu kalau mau pake webhook manual.", Duration = 4})
        return
    end
    
    config.WebhookEnabled = state
    saveConfig()
    if state then
        StarterGui:SetCore("SendNotification", {Title = "Webhook Manual Aktif", Text = "Monitor akan dikirim ke Discord.", Duration = 3})
    end
end, 155)

-- Tombol Reset Target (pindah ke tab Monitor, isi handler sama persis)
local ResetTargetBtn = Instance.new("TextButton", MonitorTab)
ResetTargetBtn.Size = UDim2.new(1, 0, 0, 28)
ResetTargetBtn.Position = UDim2.new(0, 0, 0, 228)
ResetTargetBtn.BackgroundColor3 = Colors.GlassPanel
ResetTargetBtn.AutoButtonColor = false
ResetTargetBtn.Text = ""
Instance.new("UICorner", ResetTargetBtn).CornerRadius = UDim.new(0, 10)
local ResetStroke = Instance.new("UIStroke", ResetTargetBtn)
ResetStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
ResetStroke.Thickness = 1
ResetStroke.Color = Colors.Border
local ResetRow = Instance.new("Frame", ResetTargetBtn)
ResetRow.Size = UDim2.new(1, 0, 1, 0)
ResetRow.BackgroundTransparency = 1
local ResetLay = Instance.new("UIListLayout", ResetRow)
ResetLay.FillDirection = Enum.FillDirection.Horizontal
ResetLay.HorizontalAlignment = Enum.HorizontalAlignment.Center
ResetLay.VerticalAlignment = Enum.VerticalAlignment.Center
ResetLay.SortOrder = Enum.SortOrder.LayoutOrder
ResetLay.Padding = UDim.new(0, 7)
local ResetIcon = MakeIcon(ResetRow, "scan", 14, Colors.TextDim)
ResetIcon.LayoutOrder = 1
local ResetLbl = NewLabel(ResetRow, "Reset & Scan Target", 11, Enum.Font.GothamMedium, Colors.TextDim)
ResetLbl.AutomaticSize = Enum.AutomaticSize.X
ResetLbl.Size = UDim2.new(0, 0, 1, 0)
ResetLbl.LayoutOrder = 2
ResetTargetBtn.MouseEnter:Connect(function() TweenService:Create(ResetTargetBtn, TweenInfo.new(0.15), {BackgroundColor3 = Colors.SwitchOff}):Play() end)
ResetTargetBtn.MouseLeave:Connect(function() TweenService:Create(ResetTargetBtn, TweenInfo.new(0.15), {BackgroundColor3 = Colors.GlassPanel}):Play() end)
ResetTargetBtn.MouseButton1Click:Connect(function()
    local fresh = scanCurrentPlayers()
    config.DetectedTargets = {}
    config.OriginalTargets = {}
    for _, n in ipairs(fresh) do
        table.insert(config.DetectedTargets, n)
        table.insert(config.OriginalTargets, n)
    end
    saveConfig()
    print("🔄 [Target] Reset. Sekarang: " .. #config.DetectedTargets .. " player.")
    StarterGui:SetCore("SendNotification", {Title = "Target Reset", Text = #config.DetectedTargets .. " player terscan ulang.", Duration = 3})
end)

-- ── TAB EGG (isi backpack) ──────────────────────────────
local EggTab = Instance.new("Frame", ContentArea)
EggTab.Size = UDim2.new(1, 0, 1, 0)
EggTab.BackgroundTransparency = 1
EggTab.Visible = false

local EggCard = Instance.new("Frame", EggTab)
EggCard.Size = UDim2.new(1, 0, 0, 70)
EggCard.BackgroundColor3 = Colors.GlassPanel
Instance.new("UICorner", EggCard).CornerRadius = UDim.new(0, 12)

local EggCardIcon = MakeIcon(EggCard, "backpack", 22, Colors.Accent)
EggCardIcon.Position = UDim2.new(0, 12, 0, 9)
local EggTotal = NewLabel(EggCard, "0", 20, Enum.Font.GothamBold, Colors.Text)
EggTotal.Size = UDim2.new(0, 80, 0, 22)
EggTotal.Position = UDim2.new(0, 42, 0, 6)
local EggTotalCap = NewLabel(EggCard, "egg di backpack", 10, Enum.Font.Gotham, Colors.TextDim)
EggTotalCap.Size = UDim2.new(0, 110, 0, 12)
EggTotalCap.Position = UDim2.new(0, 42, 0, 28)

local RefreshBtn = Instance.new("TextButton", EggCard)
RefreshBtn.Size = UDim2.new(0, 86, 0, 26)
RefreshBtn.Position = UDim2.new(1, -98, 0, 10)
RefreshBtn.BackgroundTransparency = 1
RefreshBtn.AutoButtonColor = false
RefreshBtn.Text = ""
Instance.new("UICorner", RefreshBtn).CornerRadius = UDim.new(0, 8)
local RefreshStroke = Instance.new("UIStroke", RefreshBtn)
RefreshStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
RefreshStroke.Thickness = 1
RefreshStroke.Color = Colors.Accent
local RefreshRow = Instance.new("Frame", RefreshBtn)
RefreshRow.Size = UDim2.new(1, 0, 1, 0)
RefreshRow.BackgroundTransparency = 1
local RefreshLay = Instance.new("UIListLayout", RefreshRow)
RefreshLay.FillDirection = Enum.FillDirection.Horizontal
RefreshLay.HorizontalAlignment = Enum.HorizontalAlignment.Center
RefreshLay.VerticalAlignment = Enum.VerticalAlignment.Center
RefreshLay.SortOrder = Enum.SortOrder.LayoutOrder
RefreshLay.Padding = UDim.new(0, 6)
local RefreshIcon = MakeIcon(RefreshRow, "refresh", 14, Colors.Accent)
RefreshIcon.LayoutOrder = 1
local RefreshLbl = NewLabel(RefreshRow, "Refresh", 11, Enum.Font.GothamMedium, Colors.Accent)
RefreshLbl.AutomaticSize = Enum.AutomaticSize.X
RefreshLbl.Size = UDim2.new(0, 0, 1, 0)
RefreshLbl.LayoutOrder = 2
RefreshBtn.MouseEnter:Connect(function() TweenService:Create(RefreshBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.85}):Play() end)
RefreshBtn.MouseLeave:Connect(function() TweenService:Create(RefreshBtn, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play() end)

local EggBarBg = Instance.new("Frame", EggCard)
EggBarBg.Size = UDim2.new(1, -24, 0, 6)
EggBarBg.Position = UDim2.new(0, 12, 0, 48)
EggBarBg.BackgroundColor3 = Colors.Track
Instance.new("UICorner", EggBarBg).CornerRadius = UDim.new(1, 0)
local EggBarFill = Instance.new("Frame", EggBarBg)
EggBarFill.Size = UDim2.new(0, 0, 1, 0)
EggBarFill.BackgroundColor3 = Colors.Green
Instance.new("UICorner", EggBarFill).CornerRadius = UDim.new(1, 0)
local EggBarName = NewLabel(EggCard, "Egg map terjauh", 9, Enum.Font.Gotham, Colors.TextDim)
EggBarName.Size = UDim2.new(0.6, 0, 0, 12)
EggBarName.Position = UDim2.new(0, 12, 0, 56)
EggBarName.TextTruncate = Enum.TextTruncate.AtEnd
local EggBarVal = NewLabel(EggCard, "0 / " .. EGG_GOAL, 9, Enum.Font.GothamMedium, Colors.TextDim, Enum.TextXAlignment.Right)
EggBarVal.Size = UDim2.new(0.35, 0, 0, 12)
EggBarVal.Position = UDim2.new(0.65, -12, 0, 56)

local EggList = Instance.new("ScrollingFrame", EggTab)
EggList.Size = UDim2.new(1, 0, 1, -76)
EggList.Position = UDim2.new(0, 0, 0, 76)
EggList.BackgroundTransparency = 1
EggList.BorderSizePixel = 0
EggList.ScrollBarThickness = 3
EggList.ScrollBarImageColor3 = Colors.Accent
EggList.CanvasSize = UDim2.new(0, 0, 0, 0)
EggList.AutomaticCanvasSize = Enum.AutomaticSize.Y
local EggListLayout = Instance.new("UIListLayout", EggList)
EggListLayout.Padding = UDim.new(0, 4)
EggListLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- ── Footer: status (ditulis oleh LOOP MONITOR, nama variabel tetap) ──
local FooterBar = Instance.new("Frame", MainFrame)
FooterBar.Size = UDim2.new(1, -16, 0, 28)
FooterBar.Position = UDim2.new(0, 8, 1, -36)
FooterBar.BackgroundColor3 = Colors.GlassPanel
Instance.new("UICorner", FooterBar).CornerRadius = UDim.new(0, 8)

-- StatusLbl tetap ditulis oleh loop. Label ini disembunyikan, isinya DICERMINKAN
-- ke StatusDisplay lengkap dengan ikon sesuai kondisi.
local StatusLbl = NewLabel(FooterBar, "Status: " .. (is_monitoring and "Monitor Egg ON" or "Idle"), 11, Enum.Font.GothamMedium, Colors.TextDim)
StatusLbl.Size = UDim2.new(1, -16, 1, 0)
StatusLbl.Position = UDim2.new(0, 8, 0, 0)
StatusLbl.Visible = false

local StatusIcons = {}
for _, k in ipairs({ "egg", "hourglass", "hop", "checkc" }) do
    local ic = MakeIcon(FooterBar, k, 14, Colors.TextDim)
    ic.Position = UDim2.new(0, 9, 0.5, -7)
    ic.Visible = false
    StatusIcons[k] = ic
end
local StatusDisplay = NewLabel(FooterBar, StatusLbl.Text, 11, Enum.Font.GothamMedium, Colors.TextDim)
StatusDisplay.Size = UDim2.new(1, -34, 1, 0)
StatusDisplay.Position = UDim2.new(0, 28, 0, 0)
StatusDisplay.TextTruncate = Enum.TextTruncate.AtEnd

local function SyncStatus()
    local raw = StatusLbl.Text
    local key, col = "egg", Colors.TextDim
    if raw:find("MASIH ADA", 1, true) then key, col = "hop", Colors.Amber
    elseif raw:find("HILANG", 1, true) then key, col = "checkc", Colors.Green
    elseif raw:find("Nunggu", 1, true) then key, col = "hourglass", Colors.Accent
    elseif raw:find("Egg ON", 1, true) then key, col = "egg", Colors.Green end
    for k, ic in pairs(StatusIcons) do ic.Visible = (k == key) end
    SetIconColor(StatusIcons[key], col)
    StatusDisplay.Text = raw
    StatusDisplay.TextColor3 = col
end
StatusLbl:GetPropertyChangedSignal("Text"):Connect(SyncStatus)
SyncStatus()

-- ── Navigasi tab ────────────────────────────────────────
MonitorBtn.MouseButton1Click:Connect(function()
    SetMonitorActive(true); SetEggActive(false)
    MonitorTab.Visible = true; EggTab.Visible = false
end)
EggBtn.MouseButton1Click:Connect(function()
    SetMonitorActive(false); SetEggActive(true)
    MonitorTab.Visible = false; EggTab.Visible = true
end)
SetMonitorActive(true)

-- ── Tombol mengambang (tidak diubah) ────────────────────
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
        draggingFloating = true; isDragging = false
        dragStartPos = input.Position
        startPos = FloatingBtn.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then draggingFloating = false end end)
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
-- Fase ring: Farming (speed menuju 15M) > Hop server > Egg (menuju EGG_GOAL).
-- Hanya MEMBACA variabel/fungsi yang sudah ada, tidak mengubah state apa pun.
local ProgressValue = Instance.new("NumberValue")
local idleMode = true
local fixedText = false
ProgressValue.Changed:Connect(function(p)
    SetRing(p)
    if not idleMode and not fixedText then PercentLbl.Text = math.floor(p * 100 + 0.0001) .. "%" end
end)
local function SetProgress(p)
    TweenService:Create(ProgressValue, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Value = p}):Play()
end

local function bigFrootPlaceState()
    local ok, v = pcall(function()
        local b = getgenv().__BigFrootSAE
        if b and b.Flags then return b.Flags.AutoPlaceAll end
        return nil
    end)
    if ok and v ~= nil then return v and true or false end
    return nil
end

local function computeView()
    local v = {
        idx = 0, idle = true, color = Colors.TextDim, sub = "Idle", pct = 0,
        caption = "Aktifkan monitor di bawah", pill = "Idle", pillColor = Colors.TextDim, place = false,
    }
    if config.WebhookEnabled and not is_monitoring then
        v.pill, v.pillColor = "Webhook", Colors.Amber
    end
    if not is_monitoring then
        local flag = bigFrootPlaceState()
        v.place = flag == true
        return v
    end

    local _, _, speedNum = getMyData()
    local eggs = tonumber(lastEggCount) or 0
    v.idle = false

    if speedNum < speedThreshold then
        v.idx = 1
        v.color, v.sub = Colors.Accent, "Speed"
        v.pct = math.clamp(speedNum / speedThreshold, 0, 1)
        v.caption = formatNumber(speedNum) .. " / " .. formatNumber(speedThreshold)
        v.pill, v.pillColor = "Farming", Colors.Green
        v.place = true
    else
        v.place = false
        local stayed = webhookStatusText:find("STAY", 1, true) ~= nil
        if stayed and not is_hopping then
            v.pct = math.clamp(eggs / EGG_GOAL, 0, 1)
            v.caption = eggs .. " / " .. EGG_GOAL .. " Egg"
            if eggs >= EGG_GOAL then
                v.idx = 4
                v.color, v.sub = Colors.Green, "Selesai"
                v.pill, v.pillColor = "Selesai", Colors.Green
            else
                v.idx = 3
                v.color, v.sub = Colors.Green, "Egg"
                v.pill, v.pillColor = "Egg", Colors.Green
            end
        else
            v.idx = 2
            v.pct = 1
            v.color, v.sub = Colors.Amber, "Cari server"
            v.ptxt = "Hop #" .. tostring(config.HopCount or 0)
            v.pill, v.pillColor = "Hop", Colors.Amber
            if is_hopping then
                v.caption = "Pindah server..."
            elseif webhookStatusText:find("HOP", 1, true) then
                v.caption = "Target masih ada, nge-hop"
            else
                v.caption = "Memindai target..."
            end
        end
    end
    local flag = bigFrootPlaceState()
    if flag ~= nil then v.place = flag end
    return v
end

-- ── Pemindai isi backpack (hanya saat tab Egg dibuka) ───
local function ScanEggInventory()
    local counts, order = {}, {}
    local function add(name, n)
        name = tostring(name or "")
        name = (name:gsub("%s*[xX]%d+%s*$", ""))
        name = (name:gsub("^%s+", ""):gsub("%s+$", ""))
        if name == "" then return end
        if not counts[name] then counts[name] = 0; table.insert(order, name) end
        counts[name] = counts[name] + n
    end

    local gotGui = false
    local pg = player:FindFirstChild("PlayerGui")
    local inv = pg and pg:FindFirstChild("BackpackGui")
    for _, k in ipairs({ "Backpack", "Main", "Inventory", "ScrollingFrame" }) do
        inv = inv and inv:FindFirstChild(k)
    end
    if inv then
        for _, slot in ipairs(inv:GetChildren()) do
            if slot:IsA("Frame") or slot:IsA("ImageLabel") or slot:IsA("TextButton") then
                local lbl = slot:FindFirstChild("ToolName") or slot:FindFirstChild("Name")
                local itemName = nil
                if lbl and lbl:IsA("TextLabel") then itemName = lbl.Text
                elseif slot:IsA("ImageLabel") or slot:IsA("TextButton") then
                    for _, d in ipairs(slot:GetDescendants()) do
                        if d:IsA("TextLabel") and d.Text ~= "" then itemName = d.Text; break end
                    end
                end
                if itemName and itemName:lower():find("egg") then
                    local mult = 1
                    for _, d in ipairs(slot:GetDescendants()) do
                        if d:IsA("TextLabel") then
                            local m = string.match(d.Text, "[xX](%d+)")
                            if m then mult = tonumber(m) or 1 end
                        end
                    end
                    add(itemName, mult)
                    gotGui = true
                end
            end
        end
    end

    local char = player.Character
    if char then
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("Tool") and obj.Name:lower():find("egg") then add(obj.Name, 1) end
        end
    end
    if not gotGui then
        local bp = player:FindFirstChild("Backpack")
        if bp then
            for _, obj in ipairs(bp:GetChildren()) do
                if obj:IsA("Tool") and obj.Name:lower():find("egg") then add(obj.Name, 1) end
            end
        end
    end
    if getnilinstances then
        local okNil, nilList = pcall(getnilinstances)
        if okNil and type(nilList) == "table" then
            for _, obj in ipairs(nilList) do
                local ok, isEgg = pcall(function() return obj:IsA("Tool") and obj.Name:lower():find("egg") end)
                if ok and isEgg then add(obj.Name, 1) end
            end
        end
    end

    local function isMap(name)
        return lastMapName ~= nil and lastMapName ~= "Unknown" and name:lower():find(tostring(lastMapName):lower(), 1, true) ~= nil
    end
    local list, total = {}, 0
    for _, nm in ipairs(order) do
        table.insert(list, { name = nm, count = counts[nm], map = isMap(nm) })
        total = total + counts[nm]
    end
    table.sort(list, function(a, b)
        if a.map ~= b.map then return a.map end
        if a.count ~= b.count then return a.count > b.count end
        return a.name < b.name
    end)
    return list, total
end

local EggRows = {}
local lastEggScan = -100
local lastEggSig = ""
local function RefreshEggTab(force)
    if not EggTab.Visible then return end
    if not force and (os.clock() - lastEggScan) < 8 then return end
    lastEggScan = os.clock()
    local ok, list, total = pcall(ScanEggInventory)
    if not ok or not list then return end

    local parts = {}
    for _, it in ipairs(list) do table.insert(parts, it.name .. ":" .. it.count .. (it.map and "m" or "")) end
    local sig = total .. "|" .. table.concat(parts, ",")
    EggTotal.Text = tostring(total)
    if sig == lastEggSig then return end
    lastEggSig = sig

    for _, r in ipairs(EggRows) do r:Destroy() end
    EggRows = {}
    if #list == 0 then
        local Empty = NewLabel(EggList, "Belum ada egg di backpack", 11, Enum.Font.Gotham, Colors.TextDim, Enum.TextXAlignment.Center)
        Empty.Size = UDim2.new(1, -8, 0, 30)
        table.insert(EggRows, Empty)
        return
    end
    for i, it in ipairs(list) do
        local Row = Instance.new("Frame")
        Row.Size = UDim2.new(1, -8, 0, 28)
        Row.BackgroundColor3 = Colors.GlassPanel
        Row.LayoutOrder = i
        Row.Parent = EggList
        Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 8)
        local Ic = MakeIcon(Row, "egg", 14, it.map and Colors.Amber or Colors.TextDim)
        Ic.Position = UDim2.new(0, 10, 0.5, -7)
        local Nm = NewLabel(Row, it.name, 11, Enum.Font.GothamMedium, Colors.Text)
        Nm.Size = UDim2.new(1, -170, 1, 0)
        Nm.Position = UDim2.new(0, 32, 0, 0)
        Nm.TextTruncate = Enum.TextTruncate.AtEnd
        if it.map then
            local Tag = NewLabel(Row, "Map terjauh", 9, Enum.Font.GothamMedium, Colors.Amber, Enum.TextXAlignment.Center)
            Tag.BackgroundTransparency = 0
            Tag.BackgroundColor3 = Colors.AmberBg
            Tag.Size = UDim2.new(0, 70, 0, 16)
            Tag.Position = UDim2.new(1, -124, 0.5, -8)
            Instance.new("UICorner", Tag).CornerRadius = UDim.new(1, 0)
        end
        local Cnt = NewLabel(Row, "x" .. it.count, 12, Enum.Font.GothamBold, Colors.Text, Enum.TextXAlignment.Right)
        Cnt.Size = UDim2.new(0, 44, 1, 0)
        Cnt.Position = UDim2.new(1, -52, 0, 0)
        table.insert(EggRows, Row)
    end
end

RefreshBtn.MouseButton1Click:Connect(function()
    RefreshLbl.Text = "Memindai..."
    task.spawn(function()
        RefreshEggTab(true)
        task.wait(0.4)
        RefreshLbl.Text = "Refresh"
    end)
end)

local function ApplyView(v)
    idleMode = v.idle == true
    fixedText = v.ptxt ~= nil
    RightStroke.Color = v.color
    LeftStroke.Color = v.color
    SetProgress(v.pct)
    if idleMode then
        PercentLbl.Text = "—"
    elseif fixedText then
        PercentLbl.Text = v.ptxt
    elseif math.abs(ProgressValue.Value - v.pct) < 0.0005 then
        PercentLbl.Text = math.floor(v.pct * 100 + 0.0001) .. "%"
    end
    SubLbl.Text = v.sub
    SubLbl.TextColor3 = v.color
    CaptionLbl.Text = v.caption
    PillLbl.Text = v.pill
    PillLbl.TextColor3 = v.pillColor
    PillDot.BackgroundColor3 = v.pillColor

    for i, pill in ipairs(StepPills) do
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
    end

    local nTargets = #(config.DetectedTargets or {})
    local eggs = tonumber(lastEggCount) or 0
    StatEgg.Val.Text = lastEggCount ~= nil and tostring(lastEggCount) or "—"
    StatEgg.Cap.Text = lastMapName and ("Egg " .. tostring(lastMapName)) or "Egg"
    StatHop.Val.Text = "#" .. tostring(config.HopCount or 0)
    StatPlace.Val.Text = v.place and "ON" or "OFF"
    StatPlace.Val.TextColor3 = v.place and Colors.Green or Colors.TextDim
    ResetLbl.Text = "Reset & Scan Target  •  " .. nTargets .. " player"

    EggBarFill.Size = UDim2.new(math.clamp(eggs / EGG_GOAL, 0, 1), 0, 1, 0)
    EggBarName.Text = lastMapName and lastMapName ~= "Unknown" and ("Egg " .. tostring(lastMapName) .. " (map terjauh)") or "Egg map terjauh"
    EggBarVal.Text = eggs .. " / " .. EGG_GOAL
end

task.spawn(function()
    while ScreenGui.Parent do
        local ok, v = pcall(computeView)
        if ok and v then pcall(ApplyView, v) end
        pcall(RefreshEggTab, false)
        task.wait(1)
    end
end)

-- ═══════════ [ LOOP WEBHOOK (INDEPENDEN) ] ═══════════
task.spawn(function()
    print("✅ Loop Webhook berjalan!")
    while task.wait(INTERVAL) do
        if not _G.StealEgg_Hub_Active or _G.StealEgg_LoopBroken or _G.StealEgg_RunId ~= RUN_ID then
            print("🛑 [Webhook Loop] Berhenti.")
            break
        end

        if is_monitoring or config.WebhookEnabled then
            local money, speed, _ = getMyData()
            local mapName, eggCount = getFarthestMapAndEgg()

            if money ~= lastMoney or speed ~= lastSpeed or mapName ~= lastMapName or eggCount ~= lastEggCount then
                sendMonitorWebhook(money, speed, mapName, eggCount, webhookStatusText)
                print("📤 [Webhook] Terkirim! Map: " .. mapName .. " | Egg: " .. eggCount)
                lastMoney, lastSpeed, lastMapName, lastEggCount = money, speed, mapName, eggCount
            end
        end
    end
end)

-- ═══════════ [ LOOP MONITOR & SNIPER ] ═══════════
task.spawn(function()
    print("✅ Loop Monitor & Sniper berjalan!")
    local sniperCounter = 0

    while task.wait(1) do
        if not _G.StealEgg_Hub_Active or _G.StealEgg_LoopBroken or _G.StealEgg_RunId ~= RUN_ID then
            print("🛑 [Monitor Loop] Berhenti.")
            break
        end

        if is_monitoring then
            sniperCounter = sniperCounter + 1
            local _, _, currentSpeed = getMyData()

            -- ⭐ LOGIKA AUTO PLACE DI DALAM MONITOR (DUA-DUANYA)
            if currentSpeed < speedThreshold then
                -- Speed < 15M: Auto Place NYALA
                if getgenv().__BigFrootSAE and getgenv().__BigFrootSAE.Flags and not getgenv().__BigFrootSAE.Flags.AutoPlaceAll then
                    setBigFrootAutoPlace(true)
                end
                _G.setNasiRendangAutoPlace(true)
            else
                -- Speed >= 15M: Auto Place MATI
                if getgenv().__BigFrootSAE and getgenv().__BigFrootSAE.Flags and getgenv().__BigFrootSAE.Flags.AutoPlaceAll then
                    setBigFrootAutoPlace(false)
                end
                _G.setNasiRendangAutoPlace(false)
            end

            if sniperCounter % 10 == 0 then
                if currentSpeed < speedThreshold then
                    local added = mergeTargets(scanCurrentPlayers())
                    if added > 0 then
                        print("📋 [Target] +" .. added .. " target baru. Total: " .. #config.DetectedTargets)
                        saveConfig()
                    end
                end
            end

            if sniperCounter >= SNIPER_INTERVAL and not is_hopping then
                sniperCounter = 0

                if currentSpeed >= speedThreshold then
                    isHuntingMode = true
                    local targetFound = checkTargetsInServer(config.DetectedTargets)

                    if targetFound then
                        StatusLbl.Text = "Status: Target MASIH ADA! Nge-hop... (Hop #" .. (config.HopCount or 0) .. ")"
                        webhookStatusText = "+ SNIPER: HOP (target found)"
                        hopServer()
                    else
                        StatusLbl.Text = "Status: Target UDAH HILANG. Stay farming..."
                        webhookStatusText = "+ SNIPER: STAY (target gone)"
                    end
                else
                    isHuntingMode = false
                    StatusLbl.Text = "Status: Nunggu Speed 15M (" .. formatNumber(currentSpeed) .. ")"
                    webhookStatusText = "+ FARMING ACTIVE"
                end
            end
        end
    end
end)

-- ═══════════ [ AUTO EXECUTE & AUTO LOAD ] ═══════════
local function autoReExecute()
    if not queueReExecute() then
        warn("⚠️ [Auto-Execute] queue_on_teleport nggak didukung executor. Taruh script di folder AutoExecute biar jalan lagi setelah hop.")
    end
end

task.spawn(function()
    task.wait(3)
    
    -- Habis server hop? (hop terakhir < 3 menit lalu dari server yang berbeda)
    local recentHop = config.LastHopJobId ~= nil and config.LastHopJobId ~= game.JobId
        and config.LastHopTime ~= nil and (os.time() - config.LastHopTime) < 180

    if config.MonitorEnabled then
        monitorToggle.SetState(true)
        if recentHop then
            -- PULIHKAN setelah hop: JANGAN panggil callback toggle, karena callback
            -- menimpa daftar target dengan player server baru.
            webhookToggle.SetState(false)
            config.WebhookEnabled = false
            is_monitoring = true
            StatusLbl.Text = "Status: Monitor Egg ON (dipulihkan, " .. #config.DetectedTargets .. " target lama)"
            pcall(function()
                StarterGui:SetCore("SendNotification", {Title = "Monitor Dipulihkan", Text = "Lanjut setelah hop. " .. #config.DetectedTargets .. " target dari server sebelumnya.", Duration = 5})
            end)
        else
            if monitorToggle.Callback then monitorToggle.Callback(true) end
            webhookToggle.SetState(false)
        end
    else
        monitorToggle.SetState(false)
        webhookToggle.SetState(config.WebhookEnabled)
    end

    if config.MonitorEnabled then
        print("🔄 [Auto-Load] Monitor ON (Webhook Manual OFF)")
        if #config.DetectedTargets == 0 then
            local fresh = scanCurrentPlayers()
            for _, n in ipairs(fresh) do
                table.insert(config.DetectedTargets, n)
            end
            print("📋 [Target] Auto-Load: list kosong, scan awal " .. #config.DetectedTargets .. " player.")
        else
            print("📋 [Target] Auto-Load: restored " .. #config.DetectedTargets .. " target dari server sebelumnya.")
        end
        if config.LastHopJobId and config.LastHopJobId ~= game.JobId then
            if checkTargetsInServer(config.DetectedTargets) then
                print("⚠️ [SNIPER] Target dari server lama masih ada di server baru! Bakal hop lagi pas speed 15M.")
            else
                print("✅ [SNIPER] Target dari server lama UDAH HILANG di server baru. Stay farming.")
            end
        end
    end
    if config.WebhookEnabled and not config.MonitorEnabled then
        print("🔄 [Auto-Load] Webhook Manual ON")
    end
end)

autoReExecute()
