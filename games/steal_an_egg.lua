-- ═══════════════════════════════════════════════════════
-- 🥚 V-Ziir0 Hub: Steal An Egg (v38 FINAL - Nasi Rendang + BigFroot)
-- ═══════════════════════════════════════════════════════

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

local player = game.Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

if not player.Character then
    player.CharacterAdded:Wait()
    task.wait(2)
end

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
    if writefile then
        pcall(function()
            local json = HttpService:JSONEncode(config)
            writefile("vziir0_egg_config.json", json)
        end)
    end
end

local function loadConfig()
    if _G.StealEgg_Config and _G.StealEgg_Config.MonitorEnabled ~= nil then
        for k, v in pairs(_G.StealEgg_Config) do
            config[k] = v
        end
        is_monitoring = config.MonitorEnabled
        return true
    end
    if readfile and isfile and isfile("vziir0_egg_config.json") then
        local ok, content = pcall(function() return readfile("vziir0_egg_config.json") end)
        if ok and content and content ~= "" then
            local ok2, data = pcall(function() return HttpService:JSONDecode(content) end)
            if ok2 and data then
                for k, v in pairs(data) do
                    config[k] = v
                end
                is_monitoring = config.MonitorEnabled
                return true
            end
        end
    end
    return false
end

loadConfig()
config.DetectedTargets = config.DetectedTargets or {}
config.OriginalTargets = config.OriginalTargets or {}

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
    saveConfig()

    local url = "https://raw.githubusercontent.com/ellan8888/monitor-income/refs/heads/main/steal_an_egg.lua"
    local scriptToRun = "loadstring(game:HttpGet('" .. url .. "'))()"

    pcall(function()
        if syn and syn.queue_on_teleport then syn.queue_on_teleport(scriptToRun)
        elseif queue_on_teleport then queue_on_teleport(scriptToRun)
        elseif fluxus and fluxus.queue_on_teleport then fluxus.queue_on_teleport(scriptToRun)
        elseif getgenv().queue_on_teleport then getgenv().queue_on_teleport(scriptToRun) end
    end)

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
                    return
                end
            end
        end
    end
    warn("❌ Gagal nemu server kosong buat hop.")
    is_hopping = false
end

-- ═══════════════════════════════════════════════════════
-- ⭐ UI CUSTOM (V38 - COMPACT RING + ICON PACK)
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
    egg = "", monitor = "", target = "", close = "", minus = "", check = "", checkc = "",
    hourglass = "", bolt = "", user = "", hop = "", send = "", scan = "",
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
MainFrame.Size = UDim2.new(0, 340, 0, 332)
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
local TargetBtn, SetTargetActive = CreateTabButton("Target", "target", 0.5, 2)

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

-- Ring progress (dua setengah lingkaran + UIGradient pada UIStroke)
local RING_SIZE, RING_T = 104, 9
local RingHolder = Instance.new("Frame", MonitorTab)
RingHolder.Size = UDim2.new(0, RING_SIZE, 0, RING_SIZE)
RingHolder.Position = UDim2.new(0.5, -RING_SIZE / 2, 0, 0)
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

local CaptionLbl = NewLabel(MonitorTab, "Aktifkan monitor di bawah", 12, Enum.Font.GothamMedium, Colors.TextDim, Enum.TextXAlignment.Center)
CaptionLbl.Size = UDim2.new(1, 0, 0, 18)
CaptionLbl.Position = UDim2.new(0, 0, 0, 108)
CaptionLbl.TextTruncate = Enum.TextTruncate.AtEnd

-- Kartu statistik: Target, Hop, Egg
local StatsRow = Instance.new("Frame", MonitorTab)
StatsRow.Size = UDim2.new(1, 0, 0, 40)
StatsRow.Position = UDim2.new(0, 0, 0, 132)
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
    Val.Position = UDim2.new(0, 32, 0, 5)
    local Cap = NewLabel(C, caption, 9, Enum.Font.Gotham, Colors.TextDim)
    Cap.Size = UDim2.new(1, -34, 0, 12)
    Cap.Position = UDim2.new(0, 32, 0, 23)
    Cap.TextTruncate = Enum.TextTruncate.AtEnd
    return { Val = Val, Cap = Cap }
end
local StatTarget = CreateStatCard("user", "Target", 1)
local StatHop = CreateStatCard("hop", "Hop", 2)
local StatEgg = CreateStatCard("egg", "Egg", 3)

-- Toggle: Monitor + Webhook manual
local ChipsRow = Instance.new("Frame", MonitorTab)
ChipsRow.Size = UDim2.new(1, 0, 0, 34)
ChipsRow.Position = UDim2.new(0, 0, 0, 180)
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

-- ── TAB TARGET ──────────────────────────────────────────
local TargetTab = Instance.new("Frame", ContentArea)
TargetTab.Size = UDim2.new(1, 0, 1, 0)
TargetTab.BackgroundTransparency = 1
TargetTab.Visible = false

local SummaryCard = Instance.new("Frame", TargetTab)
SummaryCard.Size = UDim2.new(1, 0, 0, 38)
SummaryCard.BackgroundColor3 = Colors.GlassPanel
Instance.new("UICorner", SummaryCard).CornerRadius = UDim.new(0, 10)
local SumCap = NewLabel(SummaryCard, "Target dilacak", 10, Enum.Font.Gotham, Colors.TextDim)
SumCap.Size = UDim2.new(1, -20, 0, 14)
SumCap.Position = UDim2.new(0, 10, 0, 5)
local SumValue = NewLabel(SummaryCard, "0 player", 12, Enum.Font.GothamBold, Colors.Text)
SumValue.Size = UDim2.new(1, -20, 0, 16)
SumValue.Position = UDim2.new(0, 10, 0, 18)

local TargetList = Instance.new("ScrollingFrame", TargetTab)
TargetList.Size = UDim2.new(1, 0, 0, 124)
TargetList.Position = UDim2.new(0, 0, 0, 44)
TargetList.BackgroundTransparency = 1
TargetList.BorderSizePixel = 0
TargetList.ScrollBarThickness = 3
TargetList.ScrollBarImageColor3 = Colors.Accent
TargetList.CanvasSize = UDim2.new(0, 0, 0, 0)
TargetList.AutomaticCanvasSize = Enum.AutomaticSize.Y
local TargetLayout = Instance.new("UIListLayout", TargetList)
TargetLayout.Padding = UDim.new(0, 4)
TargetLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Tombol Reset Target
local ResetTargetBtn = Instance.new("TextButton", TargetTab)
ResetTargetBtn.Size = UDim2.new(1, 0, 0, 34)
ResetTargetBtn.Position = UDim2.new(0, 0, 1, -34)
ResetTargetBtn.BackgroundColor3 = Colors.Accent
ResetTargetBtn.AutoButtonColor = false
ResetTargetBtn.Text = ""
Instance.new("UICorner", ResetTargetBtn).CornerRadius = UDim.new(0, 10)
local ResetRow = Instance.new("Frame", ResetTargetBtn)
ResetRow.Size = UDim2.new(1, 0, 1, 0)
ResetRow.BackgroundTransparency = 1
local ResetLay = Instance.new("UIListLayout", ResetRow)
ResetLay.FillDirection = Enum.FillDirection.Horizontal
ResetLay.HorizontalAlignment = Enum.HorizontalAlignment.Center
ResetLay.VerticalAlignment = Enum.VerticalAlignment.Center
ResetLay.SortOrder = Enum.SortOrder.LayoutOrder
ResetLay.Padding = UDim.new(0, 8)
local ResetIcon = MakeIcon(ResetRow, "scan", 16, Colors.OnAccent)
ResetIcon.LayoutOrder = 1
local ResetLbl = NewLabel(ResetRow, "Reset & Scan Ulang Target", 12, Enum.Font.GothamBold, Colors.OnAccent)
ResetLbl.AutomaticSize = Enum.AutomaticSize.X
ResetLbl.Size = UDim2.new(0, 0, 1, 0)
ResetLbl.LayoutOrder = 2
ResetTargetBtn.MouseEnter:Connect(function() TweenService:Create(ResetTargetBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.15}):Play() end)
ResetTargetBtn.MouseLeave:Connect(function() TweenService:Create(ResetTargetBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play() end)
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
    SetMonitorActive(true); SetTargetActive(false)
    MonitorTab.Visible = true; TargetTab.Visible = false
end)
TargetBtn.MouseButton1Click:Connect(function()
    SetMonitorActive(false); SetTargetActive(true)
    MonitorTab.Visible = false; TargetTab.Visible = true
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
-- Ring: progres Speed menuju 15M, lalu fase Sniper (hunting / hop / aman).
-- Hanya MEMBACA variabel/fungsi yang sudah ada, tidak mengubah state apa pun.
local ProgressValue = Instance.new("NumberValue")
local idleMode = true
ProgressValue.Changed:Connect(function(p)
    SetRing(p)
    if not idleMode then PercentLbl.Text = math.floor(p * 100 + 0.0001) .. "%" end
end)
local function SetProgress(p)
    TweenService:Create(ProgressValue, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Value = p}):Play()
end

local function computeView()
    local v = { idle = true, color = Colors.TextDim, sub = "Idle", pct = 0, caption = "Aktifkan monitor di bawah",
                pill = "Idle", pillColor = Colors.TextDim }
    if config.WebhookEnabled and not is_monitoring then
        v.pill, v.pillColor = "Webhook", Colors.Amber
    end
    if not is_monitoring then return v end

    local _, _, speedNum = getMyData()
    v.idle = false
    if speedNum < speedThreshold then
        v.color, v.sub = Colors.Accent, "Speed"
        v.pct = math.clamp(speedNum / speedThreshold, 0, 1)
        v.caption = formatNumber(speedNum) .. " / " .. formatNumber(speedThreshold)
        v.pill, v.pillColor = "Farming", Colors.Green
    else
        v.pct = 1
        v.pill, v.pillColor = "Sniper", Colors.Amber
        if is_hopping then
            v.color, v.sub, v.caption = Colors.Amber, "Hop", "Pindah server..."
        elseif webhookStatusText:find("HOP", 1, true) then
            v.color, v.sub, v.caption = Colors.Amber, "Hunting", "Target masih ada, hop"
        elseif webhookStatusText:find("STAY", 1, true) then
            v.color, v.sub, v.caption = Colors.Green, "Aman", "Target hilang, stay farming"
        else
            v.color, v.sub, v.caption = Colors.Amber, "Hunting", "Memindai target..."
        end
    end
    return v
end

local function inServer(name)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower() == name:lower() then return true end
    end
    return false
end

local TargetRows = {}
local lastSig = ""
local function RefreshTargetList()
    local names = config.DetectedTargets or {}
    local parts = {}
    for _, n in ipairs(names) do table.insert(parts, n .. (inServer(n) and "+" or "-")) end
    local sig = #names .. ":" .. table.concat(parts, ",")
    if sig == lastSig then return end
    lastSig = sig
    for _, r in ipairs(TargetRows) do r:Destroy() end
    TargetRows = {}
    for i, n in ipairs(names) do
        local here = inServer(n)
        local Row = Instance.new("Frame")
        Row.Size = UDim2.new(1, -8, 0, 26)
        Row.BackgroundColor3 = Colors.GlassPanel
        Row.LayoutOrder = i
        Row.Parent = TargetList
        Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 8)
        local Dot = Instance.new("Frame", Row)
        Dot.Size = UDim2.new(0, 6, 0, 6)
        Dot.Position = UDim2.new(0, 10, 0.5, -3)
        Dot.BackgroundColor3 = here and Colors.Amber or Colors.SwitchOff
        Instance.new("UICorner", Dot).CornerRadius = UDim.new(1, 0)
        local Nm = NewLabel(Row, n, 11, Enum.Font.GothamMedium, Colors.Text)
        Nm.Size = UDim2.new(0.62, 0, 1, 0)
        Nm.Position = UDim2.new(0, 24, 0, 0)
        Nm.TextTruncate = Enum.TextTruncate.AtEnd
        local St = NewLabel(Row, here and "di server" or "tidak ada", 10, Enum.Font.Gotham, here and Colors.Amber or Colors.TextDim, Enum.TextXAlignment.Right)
        St.Size = UDim2.new(0.3, 0, 1, 0)
        St.Position = UDim2.new(0.7, -10, 0, 0)
        table.insert(TargetRows, Row)
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
    PillLbl.Text = v.pill
    PillLbl.TextColor3 = v.pillColor
    PillDot.BackgroundColor3 = v.pillColor

    local nTargets = #(config.DetectedTargets or {})
    StatTarget.Val.Text = tostring(nTargets)
    StatHop.Val.Text = tostring(config.HopCount or 0)
    StatEgg.Val.Text = lastEggCount ~= nil and tostring(lastEggCount) or "—"
    StatEgg.Cap.Text = lastMapName and ("Egg " .. tostring(lastMapName)) or "Egg"
    SumValue.Text = nTargets .. " player  •  Hop #" .. tostring(config.HopCount or 0)
    RefreshTargetList()
end

task.spawn(function()
    while ScreenGui.Parent do
        local ok, v = pcall(computeView)
        if ok and v then pcall(ApplyView, v) end
        task.wait(1)
    end
end)

-- ═══════════ [ LOOP WEBHOOK (INDEPENDEN) ] ═══════════
task.spawn(function()
    print("✅ Loop Webhook berjalan!")
    while task.wait(INTERVAL) do
        if not _G.StealEgg_Hub_Active or _G.StealEgg_LoopBroken then
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
        if not _G.StealEgg_Hub_Active or _G.StealEgg_LoopBroken then
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
    local url = "https://raw.githubusercontent.com/ellan8888/monitor-income/refs/heads/main/steal_an_egg.lua"
    local scriptToRun = "loadstring(game:HttpGet('" .. url .. "'))()"
    pcall(function()
        if syn and syn.queue_on_teleport then syn.queue_on_teleport(scriptToRun)
        elseif queue_on_teleport then queue_on_teleport(scriptToRun)
        elseif fluxus and fluxus.queue_on_teleport then fluxus.queue_on_teleport(scriptToRun)
        elseif getgenv().queue_on_teleport then getgenv().queue_on_teleport(scriptToRun) end
    end)
end

task.spawn(function()
    task.wait(3)
    
    if config.MonitorEnabled then
        monitorToggle.SetState(true)
        if monitorToggle.Callback then monitorToggle.Callback(true) end
        webhookToggle.SetState(false)
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