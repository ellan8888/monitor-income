-- ═══════════════════════════════════════════════════════
-- 🥚 V-Ziir0 Hub: Steal An Egg + Speed Sniper (v26 - Custom Target)
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
local isHopping = false
local speedThreshold = 15 * 1e6 -- 15 Juta (15M)
local isHuntingMode = false

-- ⭐ STATE TARGET & SAVE
local STATE_KEY = "VZiir0_EggState"
local TARGET_KEY = "VZiir0_TargetPlayer"
local TARGET_PLAYER = "chiogame36h" -- Default

local lastMoney, lastSpeed = nil, nil
local lastEggCount, lastMapName = nil, nil

-- ⭐ FUNGSI SAVE/LOAD STATE
local function saveState(state)
    _G[STATE_KEY] = state
    if writefile then pcall(function() writefile("vziir0_egg_state.txt", state) end) end
end

local function loadState()
    if _G[STATE_KEY] then return _G[STATE_KEY] end
    if readfile and isfile and isfile("vziir0_egg_state.txt") then
        local ok, content = pcall(function() return readfile("vziir0_egg_state.txt") end)
        if ok and content then return content end
    end
    return "Off"
end

local function saveTarget(targetName)
    _G[TARGET_KEY] = targetName
    if writefile then pcall(function() writefile("vziir0_target.txt", targetName) end) end
end

local function loadTarget()
    if _G[TARGET_KEY] and _G[TARGET_KEY] ~= "" then return _G[TARGET_KEY] end
    if readfile and isfile and isfile("vziir0_target.txt") then
        local ok, content = pcall(function() return readfile("vziir0_target.txt") end)
        if ok and content and content ~= "" then return content end
    end
    return "chiogame36h" -- Default
end

TARGET_PLAYER = loadTarget() -- Load target dari save terakhir

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

-- ═══════════ [ FITUR SERVER HOP ] ═══════════
local function hopServer()
    if isHopping then return end
    isHopping = true
    print("🚀 [SNIPER] Target DITEMUKAN & SPEED TINGGI, kabur nge-hop server...")
    
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
local Colors = { Background = Color3.fromRGB(20, 20, 25), GlassPanel = Color3.fromRGB(40, 40, 50), Border = Color3.fromRGB(255, 255, 255), Accent = Color3.fromRGB(120, 200, 255), Text = Color3.fromRGB(255, 255, 255), TextDim = Color3.fromRGB(180, 180, 190), SwitchOff = Color3.fromRGB(60, 60, 70), }

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VZiir0HubGlass"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999 
ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 400, 0, 320) 
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
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

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

local MonitorTitle = Instance.new("TextLabel", MonitorTab)
MonitorTitle.Size = UDim2.new(1, 0, 0, 20)
MonitorTitle.BackgroundTransparency = 1
MonitorTitle.Text = "Target: " .. TARGET_PLAYER .. " | Min Speed: 15M"
MonitorTitle.TextColor3 = Colors.Accent
MonitorTitle.Font = Enum.Font.GothamBold
MonitorTitle.TextSize = 12
MonitorTitle.TextXAlignment = Enum.TextXAlignment.Left

-- ═══════════ [ INPUT TARGET BARU ] ═══════════
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
TargetInput.Text = TARGET_PLAYER
TargetInput.PlaceholderText = "Ketik Username Target..."
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
    local newTarget = TargetInput.Text
    if newTarget and newTarget ~= "" then
        TARGET_PLAYER = newTarget
        saveTarget(newTarget)
        MonitorTitle.Text = "Target: " .. TARGET_PLAYER .. " | Min Speed: 15M"
        StarterGui:SetCore("SendNotification", {Title = "Target Diganti", Text = "Target baru: " .. TARGET_PLAYER, Duration = 3})
        print("🎯 Target diganti ke: " .. TARGET_PLAYER)
    end
end)

-- ═══════════ [ TOGGLE MONITOR ] ═══════════
local ToggleFrame = Instance.new("Frame", MonitorTab)
ToggleFrame.Size = UDim2.new(1, 0, 0, 35)
ToggleFrame.BackgroundTransparency = 1
ToggleFrame.LayoutOrder = 3

local ToggleLabel = Instance.new("TextLabel", ToggleFrame)
ToggleLabel.Size = UDim2.new(1, -50, 1, 0)
ToggleLabel.BackgroundTransparency = 1
ToggleLabel.Text = "Aktifkan Monitor & Speed Sniper"
ToggleLabel.TextColor3 = Colors.Text
ToggleLabel.TextSize = 12
ToggleLabel.TextXAlignment = Enum.TextXAlignment.Left

local SwitchBg = Instance.new("Frame", ToggleFrame)
SwitchBg.Size = UDim2.new(0, 36, 0, 18)
SwitchBg.Position = UDim2.new(1, -36, 0.5, -9)
SwitchBg.BackgroundColor3 = Colors.SwitchOff
Instance.new("UICorner", SwitchBg).CornerRadius = UDim.new(1, 0)

local Knob = Instance.new("Frame", SwitchBg)
Knob.Size = UDim2.new(0, 14, 0, 14)
Knob.Position = UDim2.new(0, 2, 0.5, -7)
Knob.BackgroundColor3 = Colors.Text
Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)

local isToggleOn = false
SwitchBg.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isToggleOn = not isToggleOn
        if isToggleOn then
            TweenService:Create(SwitchBg, TweenInfo.new(0.2), {BackgroundColor3 = Colors.Accent}):Play()
            TweenService:Create(Knob, TweenInfo.new(0.2), {Position = UDim2.new(1, -16, 0.5, -7)}):Play() 
        else
            TweenService:Create(SwitchBg, TweenInfo.new(0.2), {BackgroundColor3 = Colors.SwitchOff}):Play()
            TweenService:Create(Knob, TweenInfo.new(0.2), {Position = UDim2.new(0, 2, 0.5, -7)}):Play()
        end
        is_monitoring = isToggleOn
        saveState(isToggleOn and "On" or "Off")
    end
end)

local StatusLbl = Instance.new("TextLabel", MainFrame)
StatusLbl.Size = UDim2.new(1, 0, 0, 15)
StatusLbl.Position = UDim2.new(0, 0, 1, -15)
StatusLbl.BackgroundTransparency = 1
StatusLbl.Text = "Status: Idle"
StatusLbl.TextColor3 = Colors.TextDim
StatusLbl.TextSize = 10
StatusLbl.TextXAlignment = Enum.TextXAlignment.Left

local FloatingBtn = Instance.new("ImageButton", ScreenGui)
FloatingBtn.Size = UDim2.new(0, 50, 0, 50)
FloatingBtn.Position = UDim2.new(0, 20, 0, 20) 
FloatingBtn.BackgroundTransparency = 0
FloatingBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
FloatingBtn.Image = "rbxassetid://71161700474373" 
FloatingBtn.ZIndex = 100 
Instance.new("UICorner", FloatingBtn).CornerRadius = UDim.new(1, 0)

local draggingFloating = false
local isDragging = false 
FloatingBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingFloating = true; isDragging = false
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then draggingFloating = false end end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if draggingFloating and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then isDragging = true end
end)
FloatingBtn.MouseButton1Click:Connect(function()
    if isDragging then return end
    MainFrame.Visible = not MainFrame.Visible
end)
MinBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false end)

-- ═══════════ [ LOOP UTAMA ] ═══════════
task.spawn(function()
    print("✅ Monitor & Speed Sniper berjalan!")
    local sniperCounter = 0
    local monitorCounter = 0
    
    while task.wait(1) do
        if is_monitoring then
            sniperCounter = sniperCounter + 1
            monitorCounter = monitorCounter + 1

            if sniperCounter >= SNIPER_INTERVAL and not isHopping then
                sniperCounter = 0
                local _, _, currentSpeed = getMyData()
                
                if currentSpeed >= speedThreshold then
                    if not isHuntingMode then
                        isHuntingMode = true
                        print("🎯 [SNIPER] Speed > 15M! Mode Hunter aktif.")
                    end
                    
                    local targetFound = false
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p.Name:lower() == TARGET_PLAYER:lower() then targetFound = true; break end
                    end
                    
                    if targetFound then
                        StatusLbl.Text = "Status: Target " .. TARGET_PLAYER .. " ADA! Nge-hop..."
                        hopServer()
                    else
                        StatusLbl.Text = "Status: Target TIDAK ADA. Aman farming..."
                    end
                else
                    isHuntingMode = false
                    StatusLbl.Text = "Status: Nunggu Speed 15M (Sekarang: " .. formatNumber(currentSpeed) .. ")"
                end
            end
            
            if monitorCounter >= INTERVAL then
                monitorCounter = 0
                local money, speed, _ = getMyData()
                local mapName, eggCount = getFarthestMapAndEgg()
                if money ~= lastMoney or speed ~= lastSpeed or eggCount ~= lastEggCount or mapName ~= lastMapName then
                    sendToDiscord(money, speed, mapName, eggCount)
                    lastMoney, lastSpeed, lastEggCount, lastMapName = money, speed, eggCount, mapName
                end
            end
        end
    end
end)

local function autoReExecute()
    local url = "https://raw.githubusercontent.com/ellan8888/monitor-income/refs/heads/main/steal-an-egg-monitor.lua" 
    local scriptToRun = "loadstring(game:HttpGet('" .. url .. "'))()"
    pcall(function()
        if syn and syn.queue_on_teleport then syn.queue_on_teleport(scriptToRun)
        elseif queue_on_teleport then queue_on_teleport(scriptToRun) end
    end)
end

task.spawn(function()
    task.wait(3)
    if loadState() == "On" then
        print("🔄 [Auto-Load] Menyalakan Monitor & Sniper")
        isToggleOn = true
        is_monitoring = true
        SwitchBg.BackgroundColor3 = Colors.Accent
        Knob.Position = UDim2.new(1, -16, 0.5, -7)
    end
end)

autoReExecute()