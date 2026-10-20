-- ═══════════════════════════════════════════════════════
-- ✨ V-Ziir0 Hub: Break & Steal (Glassmorphism v93 - AutoExec Ready)
-- ═══════════════════════════════════════════════════════

local player = game.Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- ⭐ PENGAMAN: Tunggu karakter beneran ada (biar gak error pas autoexec)
if not player.Character then
    player.CharacterAdded:Wait()
    task.wait(2)
end

local WEBHOOK_URL = "https://discord.com/api/webhooks/1560789097440616529/097v0ksImZfYm2g4zSQKbEvb-9ttIwSHah-v5nxavKklco3t5S71rMR9vySSjOwtMEEn"
local INTERVAL = 2 
local httpFn = request or http_request or (http and http.request)

if not httpFn then warn("❌ Nggak ada fungsi request!"); return end

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

-- ⭐ STATE AUTO BUY
local autoBuyEnabled = false
local targetPickaxeName = "Kapak Ajaib" 
local targetPickaxeId = 7 
local targetBuyPrice = 2000 * 1e15 
local buyStatus = "None"
local hasCheckedOwnership = false

-- ⭐ DATABASE CONFIG
local CONFIG_DB = {
    { name = "Max Account (Income 2T)", amount = 2e12, targetSpeed = 1e12, pickaxeId = 20, pickaxeName = "Enchanted", pickaxePrice = 200 * 1e15 },
    { name = "Akun Income 1T", amount = 1e12, targetSpeed = 500e9, pickaxeId = 18, pickaxeName = "Celestial", pickaxePrice = 20 * 1e15 }
}

-- ⭐ DATABASE PICKAXE
local PICKAXE_DB = {
    { name = "Stone", id = 2, priceStr = "$80", priceRaw = 80 },
    { name = "Iron", id = 3, priceStr = "$800", priceRaw = 800 },
    { name = "Golden", id = 4, priceStr = "$20K", priceRaw = 20 * 1e3 },
    { name = "Diamond", id = 5, priceStr = "$160K", priceRaw = 160 * 1e3 },
    { name = "Strawberry", id = 6, priceStr = "$1.2M", priceRaw = 1.2 * 1e6 },
    { name = "Cactus", id = 7, priceStr = "$6M", priceRaw = 6 * 1e6 },
    { name = "Lightning", id = 8, priceStr = "$40M", priceRaw = 40 * 1e6 },
    { name = "Candy", id = 9, priceStr = "$400M", priceRaw = 400 * 1e6 },
    { name = "Rainbow", id = 10, priceStr = "$2.8B", priceRaw = 2.8 * 1e9 },
    { name = "Crystal", id = 11, priceStr = "$20B", priceRaw = 20 * 1e9 },
    { name = "Demon", id = 12, priceStr = "$120B", priceRaw = 120 * 1e9 },
    { name = "Hacker", id = 13, priceStr = "$1.2T", priceRaw = 1.2 * 1e12 },
    { name = "UFO", id = 14, priceStr = "$12T", priceRaw = 12 * 1e12 },
    { name = "Secret", id = 15, priceStr = "$80T", priceRaw = 80 * 1e12 },
    { name = "Cool", id = 16, priceStr = "$600T", priceRaw = 600 * 1e12 },
    { name = "Galaxy", id = 17, priceStr = "$4Qa", priceRaw = 4 * 1e15 },
    { name = "Celestial", id = 18, priceStr = "$20Qa", priceRaw = 20 * 1e15 }, 
    { name = "Sci Fi", id = 19, priceStr = "$75Qa", priceRaw = 75 * 1e15 },
    { name = "Enchanted", id = 20, priceStr = "$200Qa", priceRaw = 200 * 1e15 },
}

-- FUNGSI PENDUKUNG
local function showNotif(title, text, duration)
    pcall(function() StarterGui:SetCore("SendNotification", { Title = title, Text = text, Duration = duration or 5 }) end)
end

-- ⭐ FUNGSI BARU: CEK KAPAK YANG LAGI DIPEgang
local function getEquippedPickaxe()
    local char = player.Character
    if not char then return "None" end
    
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local tooltip = ""
            local success, res = pcall(function() return tool.ToolTip end)
            if success and res and res ~= "" then
                return res
            end
            if tool.Name ~= "" then
                return tool.Name
            end
        end
    end
    
    return "None"
end

-- ⭐ FUNGSI DETEKSI SILENT (V9.1)
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
            if string.find(string.lower(pk.name), string.lower(heldName)) then
                oldId = pk.id
                break
            end
        end
        if oldId then
            Event:FireServer("Equip", oldId)
        end
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

-- ⭐ FUNGSI DISCORD YANG UDAH DIUPDATE
local function sendToDiscord(money, speed, status_text)
    local pickaxeInfo = "None"
    local pickaxeProgress = "-"
    if autoBuyEnabled then
        pickaxeInfo = targetPickaxeName
        local currentCash = getRealCash()
        pickaxeProgress = formatNumber(currentCash) .. " / " .. formatNumber(targetBuyPrice)
    end

    local equippedInfo = getEquippedPickaxe()

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
    print("🛑 Mencoba matikan Auto Farm...")
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
    print("🚀 Mencoba nyalain Auto Farm...")
    pcall(function()
        if getgenv().AutoFarm then getgenv().AutoFarm = true end
        if getgenv().Farm then getgenv().Farm = true end
        if _G.AutoFarm then _G.AutoFarm = true end
        if shared.AutoFarm then shared.AutoFarm = true end
        if getgenv().AutoFarmEgg then getgenv().AutoFarmEgg = true end
    end)
    
    local targetLabel = nil
    for _, gui in pairs(CoreGui:GetDescendants()) do
        if gui:IsA("TextLabel") and gui.Text:lower() == "auto farm eggs" then 
            targetLabel = gui; 
            break 
        end
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
    
    if not hasCheckedOwnership then
        hasCheckedOwnership = true
        if checkOwnershipSilent(targetPickaxeName, targetPickaxeId) then
            autoBuyEnabled = false
            buyStatus = "✅ " .. string.upper(targetPickaxeName) .. " SUDAH DIMILIKI!"
            return
        end
    end

    local currentMoney = getRealCash()
    local money_str = formatNumber(currentMoney)
    
    if currentMoney < targetBuyPrice then
        buyStatus = "⏳ MENUNGGU UANG: (" .. money_str .. " / " .. formatNumber(targetBuyPrice) .. ")"
        return
    end
    
    buyStatus = "⚡ MEMBELI KAPAK..."
    local ok, err = pcall(function()
        local Event = ReplicatedStorage:FindFirstChild("PickaxeShopRequest")
        if Event then
            Event:FireServer("Buy", targetPickaxeId)
            print("✅ Event Buy terkirim! (ID: " .. tostring(targetPickaxeId) .. ")")
        else
            warn("❌ PickaxeShopRequest nggak ketemu!")
        end
    end)
    
    if ok then
        showNotif("🛒 AUTO BUY BERHASIL", "Kamu telah membeli " .. targetPickaxeName .. "!", 5)
        buyStatus = "✅ Beli Sukses!"
        autoBuyEnabled = false 
        hasCheckedOwnership = false
        
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
        print("❌ Gagal nembak event: " .. tostring(err))
        buyStatus = "❌ Gagal beli."
        autoBuyEnabled = false
    end
end
-- ═══════════════════════════════════════════════════════
-- ⭐ UI CUSTOM (GLASSMORPHISM v93)
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

-- MAIN FRAME
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

-- Sidebar Kiri
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

local HomeBtn, SetHomeActive = CreateSidebarButton("Home", 1)
local AutoBuyBtn, SetAutoBuyActive = CreateSidebarButton("Auto Buy", 2)

-- TopBar
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

-- Area Konten
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

-- FUNGSI SWITCH TOGGLE
local function CreateSwitchToggle(parent, name, layoutOrder, defaultState, callback)
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

    SwitchBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if not isOn then
                updateVisual(true)
                if callback then callback(true) end
            else
                updateVisual(false)
                if callback then callback(false) end
            end
        end
    end)

    return {
        SetState = function(state) updateVisual(state) end,
        GetState = function() return isOn end
    }
end

-- TAB 1: HOME
local HomeTab = Instance.new("ScrollingFrame")
HomeTab.Size = UDim2.new(1, -10, 1, -10)
HomeTab.Position = UDim2.new(0, 5, 0, 5)
HomeTab.BackgroundTransparency = 1
HomeTab.ScrollBarThickness = 2
HomeTab.Parent = ContentArea
HomeTab.Visible = true

local HomeLayout = Instance.new("UIListLayout")
HomeLayout.Padding = UDim.new(0, 6)
HomeLayout.Parent = HomeTab

local HomeTitle = Instance.new("TextLabel")
HomeTitle.Size = UDim2.new(1, 0, 0, 20)
HomeTitle.BackgroundTransparency = 1
HomeTitle.Text = "Target Monitor & Auto Jump"
HomeTitle.TextColor3 = Colors.Text
HomeTitle.Font = Enum.Font.GothamBold
HomeTitle.TextSize = 12
HomeTitle.TextXAlignment = Enum.TextXAlignment.Left
HomeTitle.Parent = HomeTab

-- Bikin Toggle Monitor
local monitorToggles = {}
for i, cfg in ipairs(CONFIG_DB) do
    local toggleObj 

    toggleObj = CreateSwitchToggle(HomeTab, cfg.name, i, false, function(state)
        if state then
            for _, other in pairs(monitorToggles) do
                if other ~= toggleObj then other.SetState(false) end
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
            
            if cfg.pickaxeId then
                targetPickaxeName = cfg.pickaxeName
                targetPickaxeId = cfg.pickaxeId
                targetBuyPrice = cfg.pickaxePrice
                autoBuyEnabled = true
                buyStatus = "Siap beli (ID: "..cfg.pickaxeId..")"
                showNotif("🎯 TARGET & AUTO BUY", "Monitor: " .. cfg.name .. "\nTarget Kapak: " .. cfg.pickaxeName, 5)
            else
                showNotif("🎯 TARGET DIPILIH", "Target: " .. cfg.name, 5)
            end
        else
            is_monitoring = false
            is_farm_stopped = false
            activeProfileName = "None"
        end
    end)
    
    table.insert(monitorToggles, toggleObj)
end

-- Toggle Auto Jump
CreateSwitchToggle(HomeTab, "Auto Jump (Anti Stuck)", 10, false, function(state)
    isAutoJumpEnabled = state
end)

-- Status Label di Home
local StatusLbl = Instance.new("TextLabel")
StatusLbl.Size = UDim2.new(1, 0, 0, 15)
StatusLbl.Position = UDim2.new(0, 0, 1, -30)
StatusLbl.BackgroundTransparency = 1
StatusLbl.Text = "Status: Pilih target monitor."
StatusLbl.TextColor3 = Colors.TextDim
StatusLbl.Font = Enum.Font.Gotham
StatusLbl.TextSize = 10
StatusLbl.TextXAlignment = Enum.TextXAlignment.Left
StatusLbl.Parent = MainFrame

local BuyStatusLbl = Instance.new("TextLabel")
BuyStatusLbl.Size = UDim2.new(1, 0, 0, 15)
BuyStatusLbl.Position = UDim2.new(0, 0, 1, -15)
BuyStatusLbl.BackgroundTransparency = 1
BuyStatusLbl.Text = "Status: Idle"
BuyStatusLbl.TextColor3 = Colors.TextDim
BuyStatusLbl.Font = Enum.Font.GothamBold
BuyStatusLbl.TextSize = 10
BuyStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
BuyStatusLbl.Parent = MainFrame

-- TAB 2: AUTO BUY
local AutoBuyTab = Instance.new("ScrollingFrame")
AutoBuyTab.Size = UDim2.new(1, -10, 1, -10)
AutoBuyTab.Position = UDim2.new(0, 5, 0, 5)
AutoBuyTab.BackgroundTransparency = 1
AutoBuyTab.ScrollBarThickness = 2
AutoBuyTab.Parent = ContentArea
AutoBuyTab.Visible = false

local AutoBuyLayout = Instance.new("UIListLayout")
AutoBuyLayout.Padding = UDim.new(0, 6)
AutoBuyLayout.Parent = AutoBuyTab

local DropdownBtn = Instance.new("TextButton")
DropdownBtn.Size = UDim2.new(1, 0, 0, 30)
DropdownBtn.BackgroundColor3 = Colors.GlassPanel
DropdownBtn.BackgroundTransparency = 0.5
DropdownBtn.LayoutOrder = 2
DropdownBtn.Text = "▼ Pilih Kapak"
DropdownBtn.TextColor3 = Colors.Text
DropdownBtn.Font = Enum.Font.GothamBold
DropdownBtn.TextSize = 12
DropdownBtn.Parent = AutoBuyTab
Instance.new("UICorner", DropdownBtn).CornerRadius = UDim.new(0, 6)

local DropdownList = Instance.new("Frame")
DropdownList.Size = UDim2.new(1, 0, 0, 0) 
DropdownList.BackgroundTransparency = 1
DropdownList.LayoutOrder = 3
DropdownList.ClipsDescendants = true
DropdownList.Parent = AutoBuyTab

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 2)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Parent = DropdownList

local isDropdownOpen = false

for i, pk in ipairs(PICKAXE_DB) do
    local OptionBtn = Instance.new("TextButton")
    OptionBtn.Size = UDim2.new(1, -5, 0, 25)
    OptionBtn.BackgroundColor3 = Colors.GlassPanel
    OptionBtn.BackgroundTransparency = 0.7
    OptionBtn.LayoutOrder = i
    OptionBtn.Text = pk.name .. " (" .. pk.priceStr .. ")"
    OptionBtn.TextColor3 = Colors.Text
    OptionBtn.Font = Enum.Font.Gotham
    OptionBtn.TextSize = 10
    OptionBtn.Parent = DropdownList
    Instance.new("UICorner", OptionBtn).CornerRadius = UDim.new(0, 4)
    
    OptionBtn.MouseButton1Click:Connect(function()
        targetPickaxeName = pk.name
        targetPickaxeId = pk.id
        targetBuyPrice = pk.priceRaw
        autoBuyEnabled = true
        hasCheckedOwnership = false
        buyStatus = "Siap beli (ID: "..pk.id..")"
        
        DropdownList.Size = UDim2.new(1, 0, 0, 0)
        isDropdownOpen = false
        DropdownBtn.Text = "▼ Pilih Kapak"
        
        showNotif("🛒 AUTO BUY AKTIF", "Menunggu uang cukup untuk " .. pk.name, 5)
    end)
end

DropdownBtn.MouseButton1Click:Connect(function()
    isDropdownOpen = not isDropdownOpen
    if isDropdownOpen then
        local totalHeight = (#PICKAXE_DB * 27) 
        DropdownList.Size = UDim2.new(1, 0, 0, totalHeight)
        DropdownBtn.Text = "▲ Tutup Pilihan"
    else
        DropdownList.Size = UDim2.new(1, 0, 0, 0)
        DropdownBtn.Text = "▼ Pilih Kapak"
    end
end)

-- LOGIKA PINDAH TAB
HomeBtn.MouseButton1Click:Connect(function() 
    SetHomeActive(true); SetAutoBuyActive(false)
    HomeTab.Visible = true; AutoBuyTab.Visible = false
end)

AutoBuyBtn.MouseButton1Click:Connect(function() 
    SetHomeActive(false); SetAutoBuyActive(true)
    HomeTab.Visible = false; AutoBuyTab.Visible = true
end)

SetHomeActive(true)

-- ⭐ TOMBOL FLOATING (LOGO)
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

-- Sistem Drag & Klik
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
            if input.UserInputState == Enum.UserInputState.End then
                draggingFloating = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if draggingFloating and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStartPos
        if delta.Magnitude > 5 then
            isDragging = true
        end
        
        FloatingBtn.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

FloatingBtn.MouseButton1Click:Connect(function()
    if isDragging then return end
    
    if MainFrame.Visible then
        MainFrame.Visible = false
    else
        MainFrame.Visible = true
        MainFrame.Size = UDim2.new(0, 400, 0, 320)
    end
end)

-- LOGIKA MINIMIZE
local isMinimized = false
MinBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

-- LOOP UTAMA
task.spawn(function()
    print("✅ Monitor Break & Steal berjalan!")

    while task.wait(INTERVAL) do
        local money_str, speed_str = getMyData()
        local money_num = parseNumber(money_str)
        
        if is_monitoring then
            StatusLbl.Text = "Memantau: " .. tostring(activeProfileName) .. " (" .. tostring(money_str) .. " / " .. tostring(formatNumber(targetIncome)) .. ")"
        else
            StatusLbl.Text = "Status: Pilih target monitor di atas."
        end
        
        -- LOGIKA AUTO RE-FARM & TARGET SPEED
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
                    print("⚡ Speed target tercapai! Cek apakah kapak udah dibeli...")
                    
                    if autoBuyEnabled then
                        local currentCash = getRealCash()
                        if currentCash < targetBuyPrice then
                            print("💰 Uang belum cukup buat kapak! Auto Farm nyala lagi...")
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
                        print("✅ Speed terdeteksi naik! Auto Jump aktif.")
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
                        print("🦘 Speed stuck di Treadmill! Loncat 1x...")
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
        else
            BuyStatusLbl.Text = "Status: Idle (Pilih Kapak)"
            BuyStatusLbl.TextColor3 = Colors.TextDim
        end
    end
end)

-- ⭐ AUTO REEXECUTE (FIXED)
local function autoReExecute()
    local url = "https://raw.githubusercontent.com/ellan8888/monitor-income/refs/heads/main/monitor.lua"
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

-- Panggil fungsi ini sekali saat script pertama kali jalan
autoReExecute()