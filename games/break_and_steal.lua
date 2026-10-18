-- ═══════════════════════════════════════════════════════
-- 🔒 V-Ziir0 Hub: Break & Steal (Remote Auto Buy v55)
-- ═══════════════════════════════════════════════════════

local player = game.Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WEBHOOK_URL = "https://discord.com/api/webhooks/1560789097440616529/097v0ksImZfYm2g4zSQKbEvb-9ttIwSHah-v5nxavKklco3t5S71rMR9vySSjOwtMEEn"
local INTERVAL = 2 
local httpFn = request or http_request or (http and http.request)

if not httpFn then warn("❌ Nggak ada fungsi request!"); return end

-- ⭐ STATE GLOBAL
local is_monitoring = false
local targetIncome = 0
local activeProfileName = "None"
local is_farm_stopped = false
local lastMoney, lastSpeed = nil, nil
local lastWebhookTime = 0  -- ⭐ TAMBAHKAN INI
-- ⭐ TAMBAHKAN INI
local lastSpeedCheck = 0
local stuckTimer = 0
local hasSpeedIncreased = false
-- ⭐ STATE AUTO JUMP MANUAL
local isAutoJumpEnabled = false

-- ⭐ STATE AUTO BUY
local autoBuyEnabled = false
local targetPickaxeName = "Kapak Ajaib" 
local targetPickaxeId = 7 
local targetBuyPrice = 2000 * 1e15 
local buyStatus = "None"

-- ⭐ DATABASE CONFIG (SMART AUTO BUY)
local CONFIG_DB = {
    { 
        name = "Max Account (Income 2T)", 
        amount = 2e12, 
        pickaxeId = 20, -- Enchanted
        pickaxeName = "Enchanted ($200Qa)",
        pickaxePrice = 200 * 1e15 
    },
    { 
        name = "Akun Income 1T", 
        amount = 1e12, 
        pickaxeId = 18, -- Enchanted
        pickaxeName = "Celestial ($20Qa)",
        pickaxePrice = 20 * 1e15 
    }
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

-- ═══════════════════════════════════════════════════════
-- FUNGSI PENDUKUNG
-- ═══════════════════════════════════════════════════════
local function showNotif(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = title, Text = text, Duration = duration or 5 })
    end)
end

local function sendWebhook(payload)
    local body = HttpService:JSONEncode(payload)
    for attempt = 1, 3 do
        local ok, result = pcall(function()
            return httpFn({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        end)
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
    str = tostring(str)
    str = str:gsub("[^%d%a%.%,]", "")
    str = str:gsub("[sS]$", "")
    return str ~= "" and str or "0"
end

local function parseNumber(str)
    local s = tostring(str):upper():gsub("[$S/]", ""):gsub("%s", "")
    s = s:gsub(",", ".")
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
            if n:find("money") or n:find("cash") or n:find("income") then
                money = formatNumber(cleanNumber(stat.Value))
            elseif n:find("speed") or n:find("kecepatan") then
                speed = formatNumber(cleanNumber(stat.Value))
            end
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
                            if (txt:IsA("TextLabel") or txt:IsA("TextBox")) and txt.Text ~= "" then
                                table.insert(texts, txt.Text)
                            end
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

-- ⭐ FUNGSI PEMBACA UANG (FINAL)
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
    if numberPart then
        return parseNumber(numberPart:gsub("%s", ""))
    end
    return 0
end

local function sendToDiscord(money, speed, status_text)
    -- ⭐ Siapin teks buat progress kapak
    local pickaxeInfo = "None"
    local pickaxeProgress = "-"
    
    if autoBuyEnabled then
        pickaxeInfo = targetPickaxeName
        -- Ambil sisa uang & target harga dari fungsi getRealCash
        local currentCash = getRealCash()
        pickaxeProgress = formatNumber(currentCash) .. " / " .. formatNumber(targetBuyPrice)
    end

    local embed = {
        title = "🔒 BREAK & STEAL MONITOR 🔒",
        description = "```ini\n[ @" .. player.Name .. " ]```\n**━━━━━━━━━━━━━━━━━━━━━━━━**",
        color = is_farm_stopped and 0x2ECC71 or 0x00FFAA,
        fields = {
            { name = "💰 ▸ INCOME", value = "```yaml\n" .. tostring(money) .. "```", inline = true },
            { name = "⚡ ▸ SPEED", value = "```yaml\n" .. tostring(speed) .. "```", inline = true },
            { name = "🎯 ▸ PROFILE", value = "```yaml\n" .. tostring(activeProfileName or "None") .. "```", inline = true },
            
            -- ⭐ FIELD BARU BUAT AUTO BUY
            { name = "🛒 ▸ TARGET PICKAXE", value = "```yaml\n" .. tostring(pickaxeInfo) .. "```", inline = true },
            { name = "⏳ ▸ PROGRESS BUY", value = "```yaml\n" .. tostring(pickaxeProgress) .. "```", inline = true },
            { name = " ", value = " ", inline = true }, -- Spacer kosong biar rapi
            
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
        if gui:IsA("TextLabel") and gui.Text:lower() == "auto farm eggs" then
            targetLabel = gui; break
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
end

local function onTargetReached()
    is_farm_stopped = true
    stopAutoFarm()
    showNotif("🛑 TARGET TERCAPAI", "Auto Farm dimatikan untuk target " .. tostring(activeProfileName), 5)
end



-- ═══════════════════════════════════════════════════════
-- ⭐ FUNGSI AUTO BUY
-- ═══════════════════════════════════════════════════════
local function tryBuyPickaxe()
    if not autoBuyEnabled then return end
    
    local currentMoney = getRealCash()
    local money_str = formatNumber(currentMoney)
    
    if currentMoney < targetBuyPrice then
        buyStatus = "⏳ PICKAXE " .. string.upper(targetPickaxeName) .. ": (" .. money_str .. " / " .. formatNumber(targetBuyPrice) .. ")"
        return
    end
    
    buyStatus = "⚡ MEMBELI..."
    
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
        task.wait(1)
        pcall(function()
            local Event = ReplicatedStorage:FindFirstChild("PickaxeShopRequest")
            if Event then Event:FireServer("Equip", targetPickaxeId) end
        end)
    else
        print("❌ Gagal nembak event: " .. tostring(err))
        buyStatus = "❌ Gagal beli."
        autoBuyEnabled = false
    end
end

-- ═══════════════════════════════════════════════════════
-- ⭐ UI CUSTOM
-- ═══════════════════════════════════════════════════════
local Colors = {
    Background = Color3.fromRGB(20, 20, 20),
    Secondary = Color3.fromRGB(30, 30, 30),
    Text = Color3.fromRGB(240, 240, 240),
    TextDim = Color3.fromRGB(150, 150, 150),
}

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VZiir0Hub"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 350, 0, 500) 
MainFrame.Position = UDim2.new(0.5, -175, 0.5, -250)
MainFrame.BackgroundColor3 = Colors.Background
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 40)
TopBar.BackgroundColor3 = Colors.Secondary
TopBar.Parent = MainFrame
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -50, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "V-Ziir0 Hub | Monitor"
Title.TextColor3 = Colors.Text
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -35, 0, 5)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "✖"
CloseBtn.TextColor3 = Colors.TextDim
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.Parent = TopBar
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

-- ⭐ TOMBOL MINIMIZE
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(1, -65, 0, 5) -- Posisinya di sebelah kiri tombol Close
MinBtn.BackgroundTransparency = 1
MinBtn.Text = "—" -- Simbol minus
MinBtn.TextColor3 = Colors.TextDim
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 18
MinBtn.Parent = TopBar


local ContentFrame = Instance.new("ScrollingFrame")
ContentFrame.Size = UDim2.new(1, -20, 1, -110) 
ContentFrame.Position = UDim2.new(0, 10, 0, 50)
ContentFrame.BackgroundTransparency = 1
ContentFrame.ScrollBarThickness = 5
ContentFrame.CanvasSize = UDim2.new(0, 0, 0, 1000) 
ContentFrame.Parent = MainFrame

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.Padding = UDim.new(0, 8)
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Parent = ContentFrame

-- ⭐ TOMBOL TARGET MONITOR (SMART AUTO BUY)
for i, cfg in ipairs(CONFIG_DB) do
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 35)
    Btn.BackgroundColor3 = Colors.Secondary
    Btn.LayoutOrder = i
    Btn.Text = cfg.name
    Btn.TextColor3 = Colors.Text
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 14
    Btn.Parent = ContentFrame
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)
    
    Btn.MouseButton1Click:Connect(function()
        targetIncome = cfg.amount
        activeProfileName = cfg.name
        is_farm_stopped = false
        is_monitoring = true
        
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
    end)
end

local Divider = Instance.new("Frame")
Divider.Size = UDim2.new(1, 0, 0, 1)
Divider.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
Divider.LayoutOrder = 10
Divider.Parent = ContentFrame

local AutoBuyLabel = Instance.new("TextLabel")
AutoBuyLabel.Size = UDim2.new(1, 0, 0, 25)
AutoBuyLabel.BackgroundTransparency = 1
AutoBuyLabel.Text = "🛒 AUTO BUY PICKAXE"
AutoBuyLabel.TextColor3 = Colors.Text
AutoBuyLabel.Font = Enum.Font.GothamBold
AutoBuyLabel.TextSize = 14
AutoBuyLabel.TextXAlignment = Enum.TextXAlignment.Left
AutoBuyLabel.LayoutOrder = 11
AutoBuyLabel.Parent = ContentFrame

-- ⭐ UI TOMBOL AUTO JUMP MANUAL
local JumpBtn = Instance.new("TextButton")
JumpBtn.Size = UDim2.new(1, 0, 0, 35)
JumpBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50) -- Warna agak beda biar kerasa
JumpBtn.LayoutOrder = 11.5 -- Biar posisinya di bawah monitor, di atas dropdown
JumpBtn.Text = "🦘 Auto Jump: OFF"
JumpBtn.TextColor3 = Colors.TextDim
JumpBtn.Font = Enum.Font.GothamBold
JumpBtn.TextSize = 14
JumpBtn.Parent = ContentFrame
Instance.new("UICorner", JumpBtn).CornerRadius = UDim.new(0, 6)

JumpBtn.MouseButton1Click:Connect(function()
    isAutoJumpEnabled = not isAutoJumpEnabled
    if isAutoJumpEnabled then
        JumpBtn.Text = "🦘 Auto Jump: ON"
        JumpBtn.TextColor3 = Color3.fromRGB(0, 255, 0) -- Hijau
    else
        JumpBtn.Text = "🦘 Auto Jump: OFF"
        JumpBtn.TextColor3 = Colors.TextDim
    end
end)

-- ⭐ UI AUTO BUY (DROPDOWN)
local DropdownBtn = Instance.new("TextButton")
DropdownBtn.Size = UDim2.new(1, 0, 0, 40)
DropdownBtn.BackgroundColor3 = Colors.Secondary
DropdownBtn.LayoutOrder = 12
DropdownBtn.Text = "▼ Pilih Kapak untuk di Auto Buy"
DropdownBtn.TextColor3 = Colors.Text
DropdownBtn.Font = Enum.Font.GothamBold
DropdownBtn.TextSize = 14
DropdownBtn.Parent = ContentFrame
Instance.new("UICorner", DropdownBtn).CornerRadius = UDim.new(0, 6)

local DropdownList = Instance.new("Frame")
DropdownList.Size = UDim2.new(1, 0, 0, 0) 
DropdownList.BackgroundTransparency = 1
DropdownList.LayoutOrder = 13
DropdownList.ClipsDescendants = true
DropdownList.Parent = ContentFrame

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 4)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Parent = DropdownList

local isDropdownOpen = false

for i, pk in ipairs(PICKAXE_DB) do
    local OptionBtn = Instance.new("TextButton")
    OptionBtn.Size = UDim2.new(1, -10, 0, 30)
    OptionBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    OptionBtn.LayoutOrder = i
    OptionBtn.Text = pk.name .. " (" .. pk.priceStr .. ")"
    OptionBtn.TextColor3 = Colors.Text
    OptionBtn.Font = Enum.Font.Gotham
    OptionBtn.TextSize = 12
    OptionBtn.Parent = DropdownList
    Instance.new("UICorner", OptionBtn).CornerRadius = UDim.new(0, 4)
    
    OptionBtn.MouseButton1Click:Connect(function()
        targetPickaxeName = pk.name
        targetPickaxeId = pk.id
        targetBuyPrice = pk.priceRaw
        autoBuyEnabled = true
        buyStatus = "Siap beli (ID: "..pk.id..")"
        
        DropdownList.Size = UDim2.new(1, 0, 0, 0)
        isDropdownOpen = false
        DropdownBtn.Text = "▼ Pilih Kapak untuk di Auto Buy"
        
        showNotif("🛒 AUTO BUY AKTIF", "Menunggu uang cukup untuk " .. pk.name, 5)
    end)
end

DropdownBtn.MouseButton1Click:Connect(function()
    isDropdownOpen = not isDropdownOpen
    if isDropdownOpen then
        local totalHeight = (#PICKAXE_DB * 34) 
        DropdownList.Size = UDim2.new(1, 0, 0, totalHeight)
        DropdownBtn.Text = "▲ Tutup Pilihan Kapak"
    else
        DropdownList.Size = UDim2.new(1, 0, 0, 0)
        DropdownBtn.Text = "▼ Pilih Kapak untuk di Auto Buy"
    end
end)

-- ⭐ STATUS DI BAGIAN BAWAH
local StatusLbl = Instance.new("TextLabel")
StatusLbl.Size = UDim2.new(1, -20, 0, 20)
StatusLbl.Position = UDim2.new(0, 10, 1, -50)
StatusLbl.BackgroundTransparency = 1
StatusLbl.Text = "Status: Pilih target monitor."
StatusLbl.TextColor3 = Colors.TextDim
StatusLbl.Font = Enum.Font.Gotham
StatusLbl.TextSize = 12
StatusLbl.TextXAlignment = Enum.TextXAlignment.Left
StatusLbl.Parent = MainFrame

local BuyStatusLbl = Instance.new("TextLabel")
BuyStatusLbl.Size = UDim2.new(1, -20, 0, 20)
BuyStatusLbl.Position = UDim2.new(0, 10, 1, -25)
BuyStatusLbl.BackgroundTransparency = 1
BuyStatusLbl.Text = "Status: Idle"
BuyStatusLbl.TextColor3 = Colors.TextDim
BuyStatusLbl.Font = Enum.Font.GothamBold
BuyStatusLbl.TextSize = 12
BuyStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
BuyStatusLbl.Parent = MainFrame

-- ⭐ LOGIKA BUKA/TUTUP (MINIMIZE)
local isMinimized = false
MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        -- Sembunyikan semua isi dan kecilkan ukuran frame
        ContentFrame.Visible = false
        StatusLbl.Visible = false
        BuyStatusLbl.Visible = false
        MainFrame.Size = UDim2.new(0, 350, 0, 40) -- Tinggalin TopBar aja
        MinBtn.Text = "▢" -- Ganti ikon jadi kotak (tanda buka)
    else
        -- Tampilkan lagi isinya dan besarkan frame
        ContentFrame.Visible = true
        StatusLbl.Visible = true
        BuyStatusLbl.Visible = true
        MainFrame.Size = UDim2.new(0, 350, 0, 500) -- Balikin ke ukuran semula
        MinBtn.Text = "—" -- Balikin ikon jadi minus
    end
end)
-- ═══════════════════════════════════════════════════════
-- LOOP UTAMA
-- ═══════════════════════════════════════════════════════
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
        
        if is_monitoring and not is_farm_stopped and (money_num >= targetIncome) then
            onTargetReached()
            sendToDiscord(money_str, speed_str, "+ AUTO FARM STOPPED (" .. tostring(activeProfileName) .. ")")
        end

        if money_str ~= lastMoney or speed_str ~= lastSpeed then
            -- ⭐ COOLDOWN WEBHOOK 15 DETIK (Anti Rate Limit)
            if (os.time() - lastWebhookTime) >= 15 then
                local status = is_farm_stopped and "✅ TARGET TERCAPAI" or "🟢 FARMING ACTIVE"
                sendToDiscord(money_str, speed_str, status)
                lastMoney, lastSpeed = money_str, speed_str
                lastWebhookTime = os.time()
            end
        end

                -- ⭐ LOGIKA AUTO JUMP (TREADMILL STUCK)
        -- Jalan HANYA kalau Auto Farm udah mati & lagi monitoring
                -- ⭐ LOGIKA AUTO JUMP (TREADMILL STUCK)
        -- 1. Tombol manual ON, ATAU
        -- 2. Auto Farm sudah mati (target tercapai)
        if (isAutoJumpEnabled) or (is_farm_stopped) then
            -- Cek apakah kita lagi dalam mode monitor ATAU manual
            local isAllowedToJump = false
            
            if isAutoJumpEnabled then
                -- Kalau manual ON, boleh loncat kapan aja
                isAllowedToJump = true
            elseif is_farm_stopped then
                -- Kalau mode monitor, hanya boleh loncat kalau sedang monitoring
                if is_monitoring then
                    isAllowedToJump = true
                end
            end

            if isAllowedToJump then
                local currentSpeedNum = parseNumber(speed_str) 
                
                -- 1. Deteksi apakah speed pernah naik
                if currentSpeedNum > lastSpeedCheck then
                    if not hasSpeedIncreased then
                        print("✅ Speed terdeteksi naik! Auto Jump aktif.")
                        hasSpeedIncreased = true
                    end
                    stuckTimer = 0
                    lastSpeedCheck = currentSpeedNum
                else
                    if hasSpeedIncreased then
                        stuckTimer = stuckTimer + INTERVAL
                    end
                end

                -- 2. Kalau stuck lebih dari 6 detik, paksa loncat!
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
            -- Kalau Auto Farm masih nyala (ngejar target), jangan loncat
            stuckTimer = 0
            hasSpeedIncreased = false
            lastSpeedCheck = 0
        end

        -- ⭐ LOGIKA AUTO BUY (DENGAN EFEK KEDIP)
        if autoBuyEnabled then
            tryBuyPickaxe()
            BuyStatusLbl.Text = buyStatus
            
            if buyStatus:find("PICKAXE") then
                -- Efek Berkedip (Ganti warna antara Kuning Terang dan Kuning Redup)
                local tick = math.floor(tick() * 2) % 2 
                if tick == 0 then
                    BuyStatusLbl.TextColor3 = Color3.fromRGB(255, 255, 0) -- Kuning Terang
                else
                    BuyStatusLbl.TextColor3 = Color3.fromRGB(200, 150, 0) -- Kuning Redup
                end
            elseif buyStatus:find("MEMBELI") then
                BuyStatusLbl.TextColor3 = Color3.fromRGB(0, 255, 0) -- Hijau
            else
                BuyStatusLbl.TextColor3 = Colors.Text
            end
        else
            BuyStatusLbl.Text = "Status: Idle (Pilih Kapak)"
            BuyStatusLbl.TextColor3 = Colors.TextDim
        end
    end
end)