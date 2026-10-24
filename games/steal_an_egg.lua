-- ═══════════════════════════════════════════════════════
-- 🥚 V-Ziir0 Hub: Steal An Egg (v32 - Persistent State)
-- ═══════════════════════════════════════════════════════

-- ⭐ SISTEM ANTI-DOUBLE (Pake _G biar anti-reset)
if _G.StealEgg_Hub_Active then
    pcall(function()
        if _G.StealEgg_Hub_UI then _G.StealEgg_Hub_UI:Destroy() end
        if _G.StealEgg_LoopBroken then _G.StealEgg_LoopBroken = true end
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
    AutoPlaceEnabled = true,
    TargetPlayer = "chiogame36h"
}

local config = _G.StealEgg_Config
local is_monitoring = config.MonitorEnabled
local is_hopping = false
local speedThreshold = 15 * 1e6
local isHuntingMode = false
local lastMoney, lastSpeed = nil, nil
local lastEggCount, lastMapName = nil, nil

-- ═══════════ [ FUNGSI SAVE/LOAD CONFIG ] ═══════════
local function saveConfig()
    if writefile then
        pcall(function()
            local json = HttpService:JSONEncode(config)
            writefile("vziir0_config.json", json)
        end)
    end
end

local function loadConfig()
    if readfile and isfile and isfile("vziir0_config.json") then
        local ok, content = pcall(function() return readfile("vziir0_config.json") end)
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

-- Coba load config yang tersimpan
loadConfig()

-- ═══════════ [ FUNGSI BIGFROOT ] ═══════════
local function setBigFrootAutoPlace(state)
    local bigFrootSAE = getgenv().__BigFrootSAE
    if bigFrootSAE and bigFrootSAE.Flags then
        bigFrootSAE.Flags.AutoPlaceAll = state
        print("🔄 [BigFroot] AutoPlaceAll = " .. tostring(state))
        return true
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

local function sendMonitorWebhook(money, speed, mapName, eggCount)
    if not config.WebhookEnabled then return end
    local embed = {
        title = "🥚 STEAL AN EGG MONITOR 🥚",
        description = "```ini\n[ @" .. player.Name .. " ]```\n**━━━━━━━━━━━━━━━━━━━━━━━━**",
        color = 0xFFAA00,
        fields = {
            { name = "💰 ▸ INCOME", value = "```yaml\n" .. money .. "```", inline = true },
            { name = "⚡ ▸ SPEED", value = "```yaml\n" .. speed .. "```", inline = true },
            { name = "🗺️ ▸ LAST MAP", value = "```yaml\n" .. mapName .. "```", inline = true },
            { name = "🥚 ▸ EGG " .. mapName:upper(), value = "```yaml\n" .. eggCount .. " Egg```", inline = true },
        },
        footer = { text = "V-Ziir0 Hub • " .. os.date("%H:%M:%S") },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
    sendWebhook({ username = "🥚 Egg Monitor", avatar_url = "https://cdn-icons-png.flaticon.com/512/1055/1055687.png", embeds = { embed } })
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

-- ═══════════ [ SERVER HOP ] ═══════════
local function hopServer()
    if is_hopping then return end
    is_hopping = true
    print("🚀 [SNIPER] Nge-hop server...")
    
    -- ⭐ PENTING: Save config dulu sebelum hop
    saveConfig()
    
    local url = "https://raw.githubusercontent.com/ellan8888/monitor-income/refs/heads/main/steal_an_egg.lua" 
    local scriptToRun = "loadstring(game:HttpGet('" .. url .. "'))()"
    
    pcall(function()
        if syn and syn.queue_on_teleport then syn.queue_on_teleport(scriptToRun)
        elseif queue_on_teleport then queue_on_teleport(scriptToRun)
        elseif fluxus and fluxus.queue_on_teleport then fluxus.queue_on_teleport(scriptToRun) end
    end)
    
    task.wait(0.5)

    local PLACE_ID = game.PlaceId
    local url_api = "https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?sortOrder=Asc&limit=100"
    local success, response = pcall(function() return HttpService:JSONDecode(game:HttpGet(url_api)) end)
    
    if success and response and response.data then
        for _, server in ipairs(response.data) do
            if server.playing < server.maxPlayers and server.id ~= game.JobId then
                pcall(function() TeleportService:TeleportToPlaceInstance(PLACE_ID, server.id, player) end)
                return
            end
        end
    end
    warn("❌ Gagal nemu server kosong buat hop.")
    is_hopping = false
end

-- ═══════════════════════════════════════════════════════
-- ⭐ UI CUSTOM (GLASSMORPHISM)
-- ═══════════════════════════════════════════════════════
local Colors = { 
    Background = Color3.fromRGB(20, 20, 25), 
    GlassPanel = Color3.fromRGB(40, 40, 50), 
    Border = Color3.fromRGB(255, 255, 255), 
    Accent = Color3.fromRGB(120, 200, 255), 
    Text = Color3.fromRGB(255, 255, 255), 
    TextDim = Color3.fromRGB(180, 180, 190), 
    SwitchOff = Color3.fromRGB(60, 60, 70),
    Green = Color3.fromRGB(0, 255, 100)
}

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VZiir0HubGlass"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999 
ScreenGui.Parent = CoreGui
_G.StealEgg_Hub_UI = ScreenGui

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 400, 0, 400) 
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.BackgroundColor3 = Colors.Background
MainFrame.BackgroundTransparency = 0.1
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)
local MainBorder = Instance.new("UIStroke", MainFrame)
MainBorder.Color = Colors.Border
MainBorder.Transparency = 0.85

local Sidebar = Instance.new("Frame", MainFrame)
Sidebar.Size = UDim2.new(0, 100, 1, 0) 
Sidebar.BackgroundColor3 = Colors.GlassPanel
Sidebar.BackgroundTransparency = 0.3
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 12)

local Title = Instance.new("TextLabel", Sidebar)
Title.Size = UDim2.new(1, -10, 0, 35)
Title.Position = UDim2.new(0, 5, 0, 5)
Title.BackgroundTransparency = 1
Title.Text = "V-Ziir0"
Title.TextColor3 = Colors.Accent
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14

local TopBar = Instance.new("Frame", MainFrame)
TopBar.Size = UDim2.new(1, -100, 0, 30)
TopBar.Position = UDim2.new(0, 100, 0, 0)
TopBar.BackgroundTransparency = 1

local CloseBtn = Instance.new("TextButton", TopBar)
CloseBtn.Size = UDim2.new(0, 25, 0, 25)
CloseBtn.Position = UDim2.new(1, -30, 0, 3)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "✖"
CloseBtn.TextColor3 = Colors.TextDim
CloseBtn.MouseButton1Click:Connect(function() 
    _G.StealEgg_Hub_Active = false
    ScreenGui:Destroy() 
end)

local MinBtn = Instance.new("TextButton", TopBar)
MinBtn.Size = UDim2.new(0, 25, 0, 25)
MinBtn.Position = UDim2.new(1, -55, 0, 3) 
MinBtn.BackgroundTransparency = 1
MinBtn.Text = "—" 
MinBtn.TextColor3 = Colors.TextDim

local ContentArea = Instance.new("Frame", MainFrame)
ContentArea.Size = UDim2.new(1, -110, 1, -40)
ContentArea.Position = UDim2.new(0, 105, 0, 35)
ContentArea.BackgroundColor3 = Colors.GlassPanel
ContentArea.BackgroundTransparency = 0.3
Instance.new("UICorner", ContentArea).CornerRadius = UDim.new(0, 10)

local MonitorTab = Instance.new("ScrollingFrame", ContentArea)
MonitorTab.Size = UDim2.new(1, -10, 1, -10)
MonitorTab.Position = UDim2.new(0, 5, 0, 5)
MonitorTab.BackgroundTransparency = 1
MonitorTab.ScrollBarThickness = 2

local MonitorLayout = Instance.new("UIListLayout", MonitorTab)
MonitorLayout.Padding = UDim.new(0, 6)

-- ═══════════ [ HELPER FUNCTIONS UI ] ═══════════
local function createToggle(name, layoutOrder, defaultState, callback)
    local Frame = Instance.new("Frame", MonitorTab)
    Frame.Size = UDim2.new(1, 0, 0, 35)
    Frame.BackgroundTransparency = 1
    Frame.LayoutOrder = layoutOrder
    
    local Label = Instance.new("TextLabel", Frame)
    Label.Size = UDim2.new(1, -50, 1, 0)
    Label.BackgroundTransparency = 1
    Label.Text = name
    Label.TextColor3 = Colors.Text
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 12
    Label.TextXAlignment = Enum.TextXAlignment.Left
    
    local SwitchBg = Instance.new("Frame", Frame)
    SwitchBg.Size = UDim2.new(0, 36, 0, 18)
    SwitchBg.Position = UDim2.new(1, -36, 0.5, -9)
    SwitchBg.BackgroundColor3 = defaultState and Colors.Accent or Colors.SwitchOff
    Instance.new("UICorner", SwitchBg).CornerRadius = UDim.new(1, 0)
    
    local Knob = Instance.new("Frame", SwitchBg)
    Knob.Size = UDim2.new(0, 14, 0, 14)
    Knob.Position = defaultState and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    Knob.BackgroundColor3 = Colors.Text
    Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)
    
    local isOn = defaultState
    local function updateVisual(state)
        isOn = state
        if isOn then
            TweenService:Create(SwitchBg, TweenInfo.new(0.2), {BackgroundColor3 = Colors.Accent}):Play()
            TweenService:Create(Knob, TweenInfo.new(0.2), {Position = UDim2.new(1, -16, 0.5, -7)}):Play() 
        else
            TweenService:Create(SwitchBg, TweenInfo.new(0.2), {BackgroundColor3 = Colors.SwitchOff}):Play()
            TweenService:Create(Knob, TweenInfo.new(0.2), {Position = UDim2.new(0, 2, 0.5, -7)}):Play()
        end
    end
    
    SwitchBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local newState = not isOn
            updateVisual(newState)
            if callback then callback(newState) end
        end
    end)
    
    return { SetState = updateVisual, GetState = function() return isOn end }
end

-- ═══════════ [ UI ELEMENTS ] ═══════════
local MonitorTitle = Instance.new("TextLabel", MonitorTab)
MonitorTitle.Size = UDim2.new(1, 0, 0, 20)
MonitorTitle.BackgroundTransparency = 1
MonitorTitle.Text = "Target: " .. config.TargetPlayer
MonitorTitle.TextColor3 = Colors.Accent
MonitorTitle.Font = Enum.Font.GothamBold
MonitorTitle.TextSize = 12
MonitorTitle.TextXAlignment = Enum.TextXAlignment.Left
MonitorTitle.LayoutOrder = 1

-- Target Input
local InputFrame = Instance.new("Frame", MonitorTab)
InputFrame.Size = UDim2.new(1, 0, 0, 30)
InputFrame.BackgroundColor3 = Colors.GlassPanel
InputFrame.BackgroundTransparency = 0.5
InputFrame.LayoutOrder = 2
Instance.new("UICorner", InputFrame).CornerRadius = UDim.new(0, 6)

local TargetInput = Instance.new("TextBox", InputFrame)
TargetInput.Size = UDim2.new(1, -70, 1, 0)
TargetInput.Position = UDim2.new(0, 5, 0, 0)
TargetInput.BackgroundTransparency = 1
TargetInput.Text = config.TargetPlayer
TargetInput.PlaceholderText = "Username Target..."
TargetInput.TextColor3 = Colors.Text
TargetInput.Font = Enum.Font.Gotham
TargetInput.TextSize = 12
TargetInput.TextXAlignment = Enum.TextXAlignment.Left
TargetInput.ClearTextOnFocus = false

local SaveBtn = Instance.new("TextButton", InputFrame)
SaveBtn.Size = UDim2.new(0, 60, 1, 0)
SaveBtn.Position = UDim2.new(1, -65, 0, 0)
SaveBtn.BackgroundColor3 = Colors.Accent
SaveBtn.Text = "Simpan"
SaveBtn.TextColor3 = Colors.Background
SaveBtn.Font = Enum.Font.GothamBold
SaveBtn.TextSize = 12
Instance.new("UICorner", SaveBtn).CornerRadius = UDim.new(0, 6)

SaveBtn.MouseButton1Click:Connect(function()
    if TargetInput.Text ~= "" then
        config.TargetPlayer = TargetInput.Text
        MonitorTitle.Text = "Target: " .. config.TargetPlayer
        saveConfig()
        StarterGui:SetCore("SendNotification", {Title = "Target Diganti", Text = "Target: " .. config.TargetPlayer, Duration = 3})
    end
end)

-- Toggle Monitor
local monitorToggle = createToggle("Aktifkan Monitor & Speed Sniper", 3, config.MonitorEnabled, function(state)
    config.MonitorEnabled = state
    is_monitoring = state
    saveConfig()
    if state then
        setBigFrootAutoPlace(true)
    end
end)

-- Toggle Webhook
local webhookToggle = createToggle("Aktifkan Kirim Webhook", 4, config.WebhookEnabled, function(state)
    config.WebhookEnabled = state
    saveConfig()
    if state then
        StarterGui:SetCore("SendNotification", {Title = "Webhook Aktif", Text = "Monitor akan dikirim ke Discord.", Duration = 3})
    end
end)

-- Toggle Auto Place
local autoPlaceToggle = createToggle("Aktifkan Auto Place (BigFroot)", 5, config.AutoPlaceEnabled, function(state)
    config.AutoPlaceEnabled = state
    saveConfig()
    setBigFrootAutoPlace(state)
end)

local StatusLbl = Instance.new("TextLabel", MainFrame)
StatusLbl.Size = UDim2.new(1, 0, 0, 15)
StatusLbl.Position = UDim2.new(0, 0, 1, -15)
StatusLbl.BackgroundTransparency = 1
StatusLbl.Text = "Status: " .. (is_monitoring and "Monitor ON" or "Idle")
StatusLbl.TextColor3 = Colors.TextDim
StatusLbl.TextSize = 10
StatusLbl.TextXAlignment = Enum.TextXAlignment.Left

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

-- ═══════════ [ LOOP UTAMA ] ═══════════
task.spawn(function()
    print("✅ Loop berjalan!")
    local sniperCounter = 0
    local monitorCounter = 0
    
    while task.wait(1) do
        if not _G.StealEgg_Hub_Active or _G.StealEgg_LoopBroken then
            print("🛑 [Loop] Berhenti.")
            break
        end
        
        if is_monitoring then
            sniperCounter = sniperCounter + 1
            monitorCounter = monitorCounter + 1

            if sniperCounter >= SNIPER_INTERVAL and not is_hopping then
                sniperCounter = 0
                local _, _, currentSpeed = getMyData()
                
                local bigFrootSAE = getgenv().__BigFrootSAE
                local realAutoPlaceStatus = false
                if bigFrootSAE and bigFrootSAE.Flags then
                    realAutoPlaceStatus = bigFrootSAE.Flags.AutoPlaceAll
                end
                
                if currentSpeed >= speedThreshold then
                    if realAutoPlaceStatus then
                        setBigFrootAutoPlace(false)
                        print("🛑 Speed 15M+, Auto Place MATI.")
                    end
                    isHuntingMode = true
                    
                    local targetFound = false
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p.Name:lower() == config.TargetPlayer:lower() then targetFound = true; break end
                    end
                    
                    if targetFound then
                        StatusLbl.Text = "Status: Target KETEMU! Hop..."
                        hopServer()
                    else
                        StatusLbl.Text = "Status: Target nggak ada. Aman..."
                    end
                else
                    if not realAutoPlaceStatus then
                        setBigFrootAutoPlace(true)
                        print("✅ Speed < 15M, Auto Place NYALA.")
                    end
                    isHuntingMode = false
                    StatusLbl.Text = "Status: Nunggu Speed 15M (" .. formatNumber(currentSpeed) .. ")"
                end
            end
            
            if monitorCounter >= INTERVAL then
                monitorCounter = 0
                local money, speed, _ = getMyData()
                local mapName, eggCount = "Unknown", 0
                sendMonitorWebhook(money, speed, mapName, eggCount)
                lastMoney, lastSpeed = money, speed
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
        elseif fluxus and fluxus.queue_on_teleport then fluxus.queue_on_teleport(scriptToRun) end
    end)
end

task.spawn(function()
    task.wait(3)
    -- Update UI based on config
    monitorToggle.SetState(config.MonitorEnabled)
    webhookToggle.SetState(config.WebhookEnabled)
    autoPlaceToggle.SetState(config.AutoPlaceEnabled)
    
    if config.MonitorEnabled then
        print("🔄 [Auto-Load] Monitor ON")
        if config.AutoPlaceEnabled then
            setBigFrootAutoPlace(true)
        end
    end
end)

autoReExecute()