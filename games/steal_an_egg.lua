-- ═══════════════════════════════════════════════════════
-- 🥚 V-Ziir0 Hub: Steal An Egg Monitor + Sniper (v22 FINAL)
-- ═══════════════════════════════════════════════════════

local player = game.Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

-- ⭐ PENGAMAN
if not player.Character then
    player.CharacterAdded:Wait()
    task.wait(2)
end

local WEBHOOK_URL = "https://discord.com/api/webhooks/1560789097440616529/097v0ksImZfYm2g4zSQKbEvb-9ttIwSHah-v5nxavKklco3t5S71rMR9vySSjOwtMEEn"
local INTERVAL = 15
local SNIPER_INTERVAL = 5
local httpFn = request or http_request or (http and http.request)

if not httpFn then warn("❌ Nggak ada fungsi request!"); return end

-- ⭐ STATE GLOBAL
local is_monitoring = false
local TARGET_PLAYER = "chiogame36h"
local isHopping = false

local lastMoney, lastSpeed = nil, nil
local lastEggCount, lastMapName = nil, nil

-- ⭐ FUNGSI SAVE/LOAD STATE
local STATE_KEY = "VZiir0_EggState"

local function saveState(state)
    _G[STATE_KEY] = state
    if writefile then
        pcall(function() writefile("vziir0_egg_state.txt", state) end)
    end
end

local function loadState()
    if _G[STATE_KEY] then return _G[STATE_KEY] end
    if readfile and isfile and isfile("vziir0_egg_state.txt") then
        local ok, content = pcall(function() return readfile("vziir0_egg_state.txt") end)
        if ok and content then return content end
    end
    return "Off"
end

-- ═══════════ [ FITUR WEBHOOK & FORMAT ] ═══════════
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

-- ═══════════ [ FITUR MAP & EGG SCANNER ] ═══════════
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

-- ═══════════ [ FITUR SERVER HOP MANDIRI ] ═══════════
local function hopServer()
    if isHopping then return end
    isHopping = true
    print("🚀 [SNIPER] Target nggak ada, nge-hop server...")
    
    local PLACE_ID = game.PlaceId
    local url = "https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?sortOrder=Asc&limit=100"
    local success, response = pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end)
    
    if success and response and response.data then
        for _, server in ipairs(response.data) do
            if server.playing < server.maxPlayers and server.id ~= game.JobId then
                pcall(function() TeleportService:TeleportToPlaceInstance(PLACE_ID, server.id, player) end)
                return
            end
        end
    end
    warn("❌ Gagal nemu server kosong buat hop.")
    isHopping = false
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
}

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VZiir0HubGlass"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999 
ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 400, 0, 320) 
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.BackgroundColor3 = Colors.Background
MainFrame.BackgroundTransparency = 0.1
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

local MainBorder = Instance.new("UIStroke")
MainBorder.Color = Colors.Border
MainBorder.Transparency = 0.85
MainBorder.Thickness = 1.5
MainBorder.Parent = MainFrame

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 100, 1, 0) 
Sidebar.BackgroundColor3 = Colors.GlassPanel
Sidebar.BackgroundTransparency = 0.3
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local SidebarCorner = Instance.new("UICorner")
SidebarCorner.CornerRadius = UDim.new(0, 12)
SidebarCorner.Parent = Sidebar

local SidebarBorder = Instance.new("UIStroke")
SidebarBorder.Color = Colors.Border
SidebarBorder.Transparency = 0.9
SidebarBorder.Thickness = 1
SidebarBorder.Parent = Sidebar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -10, 0, 35)
Title.Position = UDim2.new(0, 5, 0, 5)
Title.BackgroundTransparency = 1
Title.Text = "V-Ziir0"
Title.TextColor3 = Colors.Accent
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Center
Title.Parent = Sidebar

local MenuLayout = Instance.new("UIListLayout")
MenuLayout.Padding = UDim.new(0, 4)
MenuLayout.Parent = Sidebar
MenuLayout.SortOrder = Enum.SortOrder.LayoutOrder
MenuLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function CreateSidebarButton(name, layoutOrder)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, -10, 0, 30)
    Btn.BackgroundColor3 = Colors.GlassPanel
    Btn.BackgroundTransparency = 0.8
    Btn.Text = ""
    Btn.Parent = Sidebar
    Btn.LayoutOrder = layoutOrder
    
    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(0, 6)
    BtnCorner.Parent = Btn

    local Txt = Instance.new("TextLabel")
    Txt.Size = UDim2.new(1, -10, 1, 0)
    Txt.Position = UDim2.new(0, 10, 0, 0)
    Txt.BackgroundTransparency = 1
    Txt.Text = name
    Txt.TextColor3 = Colors.TextDim
    Txt.Font = Enum.Font.GothamMedium
    Txt.TextSize = 11
    Txt.TextXAlignment = Enum.TextXAlignment.Left
    Txt.Parent = Btn
    
    Btn.MouseEnter:Connect(function()
        if Txt.TextColor3 ~= Colors.Accent then
            TweenService:Create(Btn, TweenInfo.new(0.2), {BackgroundTransparency = 0.5, BackgroundColor3 = Colors.GlassPanel}):Play()
            TweenService:Create(Txt, TweenInfo.new(0.2), {TextColor3 = Colors.Text}):Play()
        end
    end)
    Btn.MouseLeave:Connect(function()
        if Txt.TextColor3 ~= Colors.Accent then
            TweenService:Create(Btn, TweenInfo.new(0.2), {BackgroundTransparency = 0.8}):Play()
            TweenService:Create(Txt, TweenInfo.new(0.2), {TextColor3 = Colors.TextDim}):Play()
        end
    end)
    
    local function SetActive(isActive)
        if isActive then
            TweenService:Create(Btn, TweenInfo.new(0.2), {BackgroundTransparency = 0.3, BackgroundColor3 = Colors.Accent}):Play()
            Txt.TextColor3 = Colors.Background
        else
            TweenService:Create(Btn, TweenInfo.new(0.2), {BackgroundTransparency = 0.8, BackgroundColor3 = Colors.GlassPanel}):Play()
            Txt.TextColor3 = Colors.TextDim
        end
    end
    return Btn, SetActive
end

local MainBtn, SetMainActive = CreateSidebarButton("Egg Monitor", 1)

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, -100, 0, 30)
TopBar.Position = UDim2.new(0, 100, 0, 0)
TopBar.BackgroundTransparency = 1
TopBar.Parent = MainFrame

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 25, 0, 25)
CloseBtn.Position = UDim2.new(1, -30, 0, 3)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "✖"
CloseBtn.TextColor3 = Colors.TextDim
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 12
CloseBtn.Parent = TopBar
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 25, 0, 25)
MinBtn.Position = UDim2.new(1, -55, 0, 3) 
MinBtn.BackgroundTransparency = 1
MinBtn.Text = "—" 
MinBtn.TextColor3 = Colors.TextDim
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 14
MinBtn.Parent = TopBar

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -110, 1, -40)
ContentArea.Position = UDim2.new(0, 105, 0, 35)
ContentArea.BackgroundColor3 = Colors.GlassPanel
ContentArea.BackgroundTransparency = 0.3
ContentArea.BorderSizePixel = 0
ContentArea.Parent = MainFrame

local ContentCorner = Instance.new("UICorner")
ContentCorner.CornerRadius = UDim.new(0, 10)
ContentCorner.Parent = ContentArea

local ContentBorder = Instance.new("UIStroke")
ContentBorder.Color = Colors.Border
ContentBorder.Transparency = 0.9
ContentBorder.Thickness = 1
ContentBorder.Parent = ContentArea

local function CreateSwitchToggle(parent, name, layoutOrder, defaultState)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, 0, 0, 35)
    Frame.BackgroundTransparency = 1
    Frame.LayoutOrder = layoutOrder
    Frame.Parent = parent

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -50, 1, 0)
    Label.BackgroundTransparency = 1
    Label.Text = name
    Label.TextColor3 = Colors.Text
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 12
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Frame

    local SwitchBg = Instance.new("Frame")
    SwitchBg.Size = UDim2.new(0, 36, 0, 18)
    SwitchBg.Position = UDim2.new(1, -36, 0.5, -9)
    SwitchBg.BackgroundColor3 = defaultState and Colors.Accent or Colors.SwitchOff
    SwitchBg.Parent = Frame
    Instance.new("UICorner", SwitchBg).CornerRadius = UDim.new(1, 0)

    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.new(0, 14, 0, 14)
    Knob.AnchorPoint = Vector2.new(0, 0) 
    Knob.Position = defaultState and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    Knob.BackgroundColor3 = Colors.Text
    Knob.Parent = SwitchBg
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
    return {
        SetState = function(state) updateVisual(state) end,
        GetState = function() return isOn end,
        SwitchBg = SwitchBg,
    }
end

-- ═══════════ [ TAB 1: EGG MONITOR & SNIPER ] ═══════════
local MonitorTab = Instance.new("ScrollingFrame")
MonitorTab.Size = UDim2.new(1, -10, 1, -10)
MonitorTab.Position = UDim2.new(0, 5, 0, 5)
MonitorTab.BackgroundTransparency = 1
MonitorTab.ScrollBarThickness = 2
MonitorTab.Parent = ContentArea
MonitorTab.Visible = true

local MonitorLayout = Instance.new("UIListLayout")
MonitorLayout.Padding = UDim.new(0, 6)
MonitorLayout.Parent = MonitorTab

local MonitorTitle = Instance.new("TextLabel")
MonitorTitle.Size = UDim2.new(1, 0, 0, 20)
MonitorTitle.BackgroundTransparency = 1
MonitorTitle.Text = "Sniper Target: " .. TARGET_PLAYER
MonitorTitle.TextColor3 = Colors.Accent
MonitorTitle.Font = Enum.Font.GothamBold
MonitorTitle.TextSize = 13
MonitorTitle.TextXAlignment = Enum.TextXAlignment.Left
MonitorTitle.Parent = MonitorTab

local monitorToggle = CreateSwitchToggle(MonitorTab, "Aktifkan Monitor & Sniper", 1, false)
monitorToggle.SwitchBg.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local newState = not monitorToggle.GetState()
        monitorToggle.SetState(newState)
        is_monitoring = newState
        saveState(newState and "On" or "Off")
        
        if newState then
            StarterGui:SetCore("SendNotification", {Title = "Monitor & Sniper", Text = "Mencari target: " .. TARGET_PLAYER, Duration = 3})
        end
    end
end)

local StatusLbl = Instance.new("TextLabel")
StatusLbl.Size = UDim2.new(1, 0, 0, 15)
StatusLbl.Position = UDim2.new(0, 0, 1, -15)
StatusLbl.BackgroundTransparency = 1
StatusLbl.Text = "Status: Idle"
StatusLbl.TextColor3 = Colors.TextDim
StatusLbl.Font = Enum.Font.Gotham
StatusLbl.TextSize = 10
StatusLbl.TextXAlignment = Enum.TextXAlignment.Left
StatusLbl.Parent = MainFrame

MainBtn.MouseButton1Click:Connect(function() 
    SetMainActive(true)
end)
SetMainActive(true)

-- ═══════════ [ FLOATING LOGO ] ═══════════
local FloatingBtn = Instance.new("ImageButton")
FloatingBtn.Size = UDim2.new(0, 50, 0, 50)
FloatingBtn.Position = UDim2.new(0, 20, 0, 20) 
FloatingBtn.BackgroundTransparency = 0
FloatingBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
FloatingBtn.Image = "rbxassetid://71161700474373" 
FloatingBtn.Visible = true 
FloatingBtn.ZIndex = 100 
FloatingBtn.Parent = ScreenGui
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
    if MainFrame.Visible then MainFrame.Visible = false
    else MainFrame.Visible = true; MainFrame.Size = UDim2.new(0, 400, 0, 320) end
end)

MinBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false end)

-- ═══════════ [ LOOP UTAMA MONITOR + SNIPER ] ═══════════
task.spawn(function()
    print("✅ Monitor Steal An Egg & Sniper berjalan!")
    while task.wait(1) do
        if is_monitoring then
            -- 1. Sniper Check (Tiap 5 detik)
            if not isHopping then
                if os.time() % SNIPER_INTERVAL == 0 then
                    local targetFound = false
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p.Name:lower() == TARGET_PLAYER:lower() then targetFound = true; break end
                    end
                    
                    if targetFound then
                        StatusLbl.Text = "Status: Target KETEMU! Bertahan..."
                    else
                        StatusLbl.Text = "Status: Target hilang, hopping..."
                        hopServer()
                    end
                end
            end
            
            -- 2. Monitor Webhook (Tiap 15 detik)
            if os.time() % INTERVAL == 0 then
                local money, speed = getMyData()
                local mapName, eggCount = getFarthestMapAndEgg()
                if money ~= lastMoney or speed ~= lastSpeed or eggCount ~= lastEggCount or mapName ~= lastMapName then
                    sendToDiscord(money, speed, mapName, eggCount)
                    lastMoney, lastSpeed, lastEggCount, lastMapName = money, speed, eggCount, mapName
                end
            end
        end
    end
end)

-- ═══════════ [ AUTO-EXECUTE ] ═══════════
local function autoReExecute()
    local url = "https://raw.githubusercontent.com/ellan8888/monitor-income/refs/heads/main/steal-an-egg-monitor.lua" 
    local scriptToRun = "loadstring(game:HttpGet('" .. url .. "'))()"
    local success = pcall(function()
        if syn and syn.queue_on_teleport then syn.queue_on_teleport(scriptToRun)
        elseif queue_on_teleport then queue_on_teleport(scriptToRun)
        elseif fluxus and fluxus.queue_on_teleport then fluxus.queue_on_teleport(scriptToRun)
        elseif getgenv().queue_on_teleport then getgenv().queue_on_teleport(scriptToRun) end
    end)
    if not success then warn("⚠️ Executor kamu nggak support queue_on_teleport.") end
end

-- ═══════════ [ AUTO-LOAD STATE ] ═══════════
task.spawn(function()
    task.wait(3)
    local savedProfile = loadState()
    if savedProfile == "On" then
        print("🔄 [Auto-Load] Menyalakan Monitor & Sniper")
        monitorToggle.SetState(true)
        is_monitoring = true
    end
end)

autoReExecute()