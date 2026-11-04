-- ═══════════════════════════════════════════════════════
-- 🔎 V-Ziir0 Pet Scanner (Break & Steal) — v2
-- v2: pet SPAWN (ada countdown) ikut terbaca, filter Semua/Spawn/Base, tombol Debug.
-- v2.1: Debug menampilkan label value di luar BillboardGui (untuk lacak pet spawn).
-- v3: pakai struktur game: Workspace.AnimalPickups = pet SPAWN, Workspace.Plots.Base_N.PlacedAnimals = pet BASE.
--     Mode Semua: pet spawn selalu di atas, lalu pet base. Baris maks 150.
-- v4: mode "Base-ku" — hanya pet di plot milikmu (deteksi otomatis, cadangan: plot terdekat).
-- Script terpisah. Memindai semua pet di map dari label "$xx/s" yang
-- melayang di atasnya (BillboardGui), lalu menampilkan pet dengan
-- value >= batas (bisa diubah dari UI, mis. 1B / 10B / 1T). Semua rarity
-- ikut dipindai. Hanya MEMBACA tampilan, tidak mengubah apa pun di game.
-- ═══════════════════════════════════════════════════════

if not game:IsLoaded() then game.Loaded:Wait() end

-- ⭐ anti dobel: tutup scanner lama kalau dijalankan ulang
if _G.VZ_PetScan and _G.VZ_PetScan.Destroy then pcall(_G.VZ_PetScan.Destroy) end
local Scan = {}
_G.VZ_PetScan = Scan

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local player = Players.LocalPlayer

-- ═══════════ [ PENGATURAN ] ═══════════
local REFRESH_EVERY = 2          -- detik antar pembaruan daftar
local MAX_ROWS = 150             -- baris maksimal yang ditampilkan
local SAVE_FILE = "VZiir0Hub_PetScan.json"

local Colors = {
    Background = Color3.fromRGB(15, 13, 12),
    Panel      = Color3.fromRGB(22, 19, 18),
    Tile       = Color3.fromRGB(30, 26, 24),
    Border     = Color3.fromRGB(42, 37, 35),
    Accent     = Color3.fromRGB(240, 122, 43),
    Text       = Color3.fromRGB(241, 236, 232),
    TextDim    = Color3.fromRGB(141, 131, 125),
    Green      = Color3.fromRGB(79, 227, 168),
    Danger     = Color3.fromRGB(229, 72, 77),
}

-- warna per rarity (yang tidak dikenal pakai warna aksen)
local RarityColors = {
    common = Color3.fromRGB(170, 170, 170), uncommon = Color3.fromRGB(95, 210, 110),
    rare = Color3.fromRGB(80, 150, 255), epic = Color3.fromRGB(170, 95, 255),
    legendary = Color3.fromRGB(255, 170, 40), mythic = Color3.fromRGB(255, 80, 80),
    mythical = Color3.fromRGB(255, 80, 80), secret = Color3.fromRGB(235, 235, 235),
    celestial = Color3.fromRGB(120, 220, 255), inferno = Color3.fromRGB(255, 110, 40),
    void = Color3.fromRGB(150, 90, 220), omega = Color3.fromRGB(255, 215, 90),
    divine = Color3.fromRGB(255, 240, 160), heavenly = Color3.fromRGB(255, 230, 120),
}

-- ═══════════ [ ANGKA ] ═══════════
local SUFFIX = { [""] = 1, K = 1e3, M = 1e6, B = 1e9, T = 1e12, QA = 1e15, QI = 1e18,
    SX = 1e21, SP = 1e24, OC = 1e27, NO = 1e30, DC = 1e33 }

local function toNumber(numStr, suf)
    numStr = tostring(numStr or ""):gsub(",", "")
    local n = tonumber(numStr)
    local m = SUFFIX[tostring(suf or ""):upper()]
    if not n or not m then return nil end
    return n * m
end

-- "$41.2B/s" → 41.2e9 ; nil kalau bukan label value
local function parseValueLabel(text)
    local num, suf = text:match("%$%s*([%d%.,]+)%s*(%a*)%s*/%s*[sS]")
    if not num then return nil end
    return toNumber(num, suf)
end

-- "1B", "10b", "2.5T", "500M" → angka (untuk batas)
local function parseThreshold(text)
    text = tostring(text or ""):gsub("[%s%$]", "")
    if text == "" then return nil end
    local num, suf = text:match("^([%d%.,]+)(%a*)$")
    if not num then return nil end
    return toNumber(num, suf)
end

local SUF_ORDER = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
local function fmt(n)
    n = tonumber(n) or 0
    local i = 1
    while n >= 1000 and i < #SUF_ORDER do n = n / 1000; i = i + 1 end
    if n >= 100 or n % 1 == 0 then return string.format("%d%s", math.floor(n), SUF_ORDER[i]) end
    return string.format("%.1f%s", n, SUF_ORDER[i])
end

-- ═══════════ [ SIMPAN BATAS ] ═══════════
local threshold = 1e9   -- default 1B
pcall(function()
    if isfile and readfile and isfile(SAVE_FILE) then
        local d = HttpService:JSONDecode(readfile(SAVE_FILE))
        if type(d) == "table" and tonumber(d.threshold) then threshold = tonumber(d.threshold) end
    end
end)
local function saveThreshold()
    pcall(function()
        if writefile then writefile(SAVE_FILE, HttpService:JSONEncode({ threshold = threshold })) end
    end)
end

-- ═══════════ [ PEMINDAI ] ═══════════
local tracked = {}      -- [BillboardGui] = true
local conns = {}

local function cleanText(t)
    return (tostring(t or ""):gsub("<[^>]->", ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function isRarityText(t)
    -- satu-dua kata huruf saja (mis. "Celestial", "Secret"), bukan angka / timer
    return #t >= 3 and #t <= 20 and t:match("^%a[%a ]*%a$") ~= nil
end

local function track(obj)
    if obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then tracked[obj] = true end
end

-- baca satu BillboardGui → entri pet (atau nil)
local function readGui(gui)
    if not gui.Parent then return nil end
    local value, rarity, timer
    for _, d in ipairs(gui:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
            local okT, raw = pcall(function() return (d.ContentText ~= "" and d.ContentText) or d.Text end)
            local t = okT and cleanText(raw) or ""
            if t ~= "" then
                if not value then
                    local v = parseValueLabel(t)
                    if v then value = v end
                end
                if not rarity and not t:find("%$") and isRarityText(t) then rarity = t end
                -- countdown pet spawn: "9s", "1m 20s", "01:20"
                if not timer then
                    local tm = t:match("^(%d+%s*[smh])$") or t:match("^(%d+m%s*%d+s)$") or t:match("^(%d+:%d+)$")
                    if tm then timer = tm end
                end
            end
        end
    end
    if not value then return nil end

    -- bagian yang ditempeli label (untuk nama, pemilik, jarak)
    local part = gui.Adornee
    if not part then
        part = gui.Parent:IsA("BasePart") and gui.Parent or gui:FindFirstAncestorWhichIsA("BasePart")
    end
    local holder = part or gui.Parent
    local model = holder and holder:FindFirstAncestorWhichIsA("Model")
    if holder and holder:IsA("Model") then model = holder end

    -- ── kategori dari struktur game ──
    --   Workspace.AnimalPickups.<Pet>...           → pet SPAWN (di jalan, bisa diambil)
    --   Workspace.Plots.Base_N.PlacedAnimals.<Pet> → pet BASE (punya pemain)
    local category, petName, owner, plotRef = "other", nil, nil, nil
    local pickups = workspace:FindFirstChild("AnimalPickups")
    local plots = workspace:FindFirstChild("Plots")
    local function childOf(container)
        local a = gui
        while a and a.Parent ~= container do a = a.Parent end
        return a
    end
    if pickups and gui:IsDescendantOf(pickups) then
        category = "spawn"
        local c = childOf(pickups)
        petName = c and c.Name
    elseif plots and gui:IsDescendantOf(plots) then
        category = "base"
        local plot = childOf(plots)
        plotRef = plot
        local placed = plot and plot:FindFirstChild("PlacedAnimals")
        if placed and gui:IsDescendantOf(placed) then
            local c = childOf(placed)
            petName = c and c.Name
        end
        if plot then
            -- pemilik plot: atribut / Value bernama owner, kalau game menyediakannya
            for _, key in ipairs({ "Owner", "OwnerName", "Player", "PlayerName", "OwnerId", "UserId" }) do
                local v = plot:GetAttribute(key)
                local child = plot:FindFirstChild(key)
                if v == nil and child and child:IsA("ValueBase") then v = child.Value end
                if v ~= nil then
                    if typeof(v) == "Instance" then v = v.Name end
                    if tonumber(v) then
                        local pl = Players:GetPlayerByUserId(tonumber(v))
                        v = pl and pl.Name or tostring(v)
                    end
                    owner = tostring(v)
                    break
                end
            end
            owner = owner or plot.Name
        end
    else
        -- cadangan lama: ancestor yang namanya sama dengan nama pemain
        local anc = holder
        while anc and anc ~= workspace do
            if Players:FindFirstChild(anc.Name) then owner = anc.Name break end
            anc = anc.Parent
        end
    end

    local pos
    pcall(function()
        if part and part:IsA("BasePart") then pos = part.Position
        elseif model then pos = model:GetPivot().Position end
    end)

    return {
        -- kunci = bagian yang ditempeli label (bukan Model besar), supaya
        -- pet spawn yang satu folder/Model tidak tergabung jadi satu
        key = part or holder or gui,
        timer = timer,
        category = category,
        plot = plotRef,
        spawn = (category == "spawn"),
        name = petName or (model and model ~= workspace and model.Name) or (holder and holder.Name) or "?",
        rarity = rarity or "-",
        value = value,
        owner = owner,
        pos = pos,
    }
end

-- ═══════════ [ BASE MILIKKU ] ═══════════
-- Cari plot yang menyimpan nama / UserId / DisplayName kita (atribut, Value,
-- atau papan nama). Kalau tidak ketemu, pakai plot terdekat (set manual).
local myPlot, myPlotSource, lastPlotSearch = nil, nil, -100
local function matchesMe(v)
    if v == nil then return false end
    if typeof(v) == "Instance" then return v == player end
    local sv = tostring(v)
    return sv == player.Name or sv == tostring(player.UserId) or sv == player.DisplayName
end
local function findMyPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _, plot in ipairs(plots:GetChildren()) do
        for _, v in pairs(plot:GetAttributes()) do
            if matchesMe(v) then return plot, "atribut" end
        end
        for _, d in ipairs(plot:GetChildren()) do
            if d:IsA("ValueBase") and matchesMe(d.Value) then return plot, "value" end
        end
    end
    -- papan nama / label di dalam plot (di luar PlacedAnimals supaya cepat)
    for _, plot in ipairs(plots:GetChildren()) do
        for _, child in ipairs(plot:GetChildren()) do
            if child.Name ~= "PlacedAnimals" then
                for _, d in ipairs(child:GetDescendants()) do
                    if d:IsA("TextLabel") then
                        local t = d.Text
                        if t:find(player.Name, 1, true) or (player.DisplayName ~= "" and t:find(player.DisplayName, 1, true)) then
                            return plot, "papan nama"
                        end
                    elseif d:IsA("ValueBase") and matchesMe(d.Value) then
                        return plot, "value"
                    end
                end
            end
        end
    end
    return nil
end
local function nearestPlot()
    local plots = workspace:FindFirstChild("Plots")
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not plots or not root then return nil end
    local best, bestD
    for _, plot in ipairs(plots:GetChildren()) do
        local ok, pos = pcall(function() return plot:GetPivot().Position end)
        if ok then
            local d = (pos - root.Position).Magnitude
            if not bestD or d < bestD then best, bestD = plot, d end
        end
    end
    return best
end
local function ensureMyPlot()
    if myPlot and myPlot.Parent then return myPlot end
    if os.clock() - lastPlotSearch < 15 then return nil end
    lastPlotSearch = os.clock()
    local ok, plot, src = pcall(findMyPlot)
    if ok and plot then
        myPlot, myPlotSource = plot, src
        print("🏠 [Pet Scanner] Base kamu: " .. plot.Name .. " (terdeteksi dari " .. src .. ")")
    end
    return myPlot
end

local function collect()
    local byKey, all = {}, {}
    for gui in pairs(tracked) do
        if not gui.Parent then
            tracked[gui] = nil
        else
            local ok, e = pcall(readGui, gui)
            if ok and e then
                local prev = byKey[e.key]
                if not prev or e.value > prev.value then byKey[e.key] = e end
            end
        end
    end
    for _, e in pairs(byKey) do table.insert(all, e) end
    return all
end

-- ═══════════ [ UI ] ═══════════
local function NewLabel(parent, text, size, font, color, align)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextSize = size
    l.Font = font
    l.TextColor3 = color
    l.TextXAlignment = align or Enum.TextXAlignment.Left
    l.TextTruncate = Enum.TextTruncate.AtEnd
    l.Parent = parent
    return l
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VZiir0PetScan"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 1000
pcall(function() ScreenGui.Parent = (gethui and gethui()) or CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = player:WaitForChild("PlayerGui") end

local W, H = 330, 430
local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, W, 0, H)
Main.Position = UDim2.new(1, -W - 20, 0.5, -H / 2)
Main.BackgroundColor3 = Colors.Background
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)
do
    local st = Instance.new("UIStroke", Main)
    st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    st.Color = Colors.Border
    st.Thickness = 1
    -- kecilkan otomatis di layar kecil
    local sc = Instance.new("UIScale", Main)
    local function upd()
        local vp = ScreenGui.AbsoluteSize
        if vp.X < 50 then return end
        sc.Scale = math.clamp(math.min(1, (vp.Y - 20) / H, (vp.X - 20) / W), 0.5, 1)
    end
    upd()
    ScreenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(upd)
end

-- header
local Logo = Instance.new("Frame", Main)
Logo.Size = UDim2.new(0, 26, 0, 26)
Logo.Position = UDim2.new(0, 12, 0, 10)
Logo.BackgroundColor3 = Colors.Accent
Logo.BorderSizePixel = 0
Instance.new("UICorner", Logo).CornerRadius = UDim.new(0, 7)
do -- ikon kaca pembesar sederhana
    local ring = Instance.new("Frame", Logo)
    ring.Size = UDim2.new(0, 11, 0, 11)
    ring.Position = UDim2.new(0, 5, 0, 5)
    ring.BackgroundTransparency = 1
    Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
    local rs = Instance.new("UIStroke", ring)
    rs.Thickness = 2
    rs.Color = Color3.fromRGB(43, 18, 4)
    local h = Instance.new("Frame", Logo)
    h.Size = UDim2.new(0, 7, 0, 2)
    h.Position = UDim2.new(0, 15, 0, 17)
    h.Rotation = 45
    h.BorderSizePixel = 0
    h.BackgroundColor3 = Color3.fromRGB(43, 18, 4)
end
local Title = NewLabel(Main, "Pet Scanner", 14, Enum.Font.GothamBold, Colors.Text)
Title.Size = UDim2.new(0, 160, 0, 16)
Title.Position = UDim2.new(0, 46, 0, 9)
local Sub = NewLabel(Main, "V-Ziir0 · Break & Steal", 10, Enum.Font.Gotham, Colors.TextDim)
Sub.Size = UDim2.new(0, 160, 0, 12)
Sub.Position = UDim2.new(0, 46, 0, 25)

local function HeaderBtn(text, xOff, color)
    local b = Instance.new("TextButton", Main)
    b.Size = UDim2.new(0, 24, 0, 24)
    b.Position = UDim2.new(1, xOff, 0, 11)
    b.BackgroundColor3 = Colors.Tile
    b.AutoButtonColor = false
    b.Text = text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.TextColor3 = color or Colors.TextDim
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end
local CloseBtn = HeaderBtn("×", -34, Colors.TextDim)
local MinBtn = HeaderBtn("–", -62, Colors.TextDim)

-- batas value
local Bar = Instance.new("Frame", Main)
Bar.Size = UDim2.new(1, -24, 0, 34)
Bar.Position = UDim2.new(0, 12, 0, 46)
Bar.BackgroundColor3 = Colors.Panel
Bar.BorderSizePixel = 0
Instance.new("UICorner", Bar).CornerRadius = UDim.new(0, 8)
do
    local st = Instance.new("UIStroke", Bar)
    st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    st.Color = Colors.Border
end
local BarLbl = NewLabel(Bar, "Batas value  ≥", 11, Enum.Font.GothamMedium, Colors.TextDim)
BarLbl.Size = UDim2.new(0, 100, 1, 0)
BarLbl.Position = UDim2.new(0, 10, 0, 0)

local BoxWrap = Instance.new("Frame", Bar)
BoxWrap.Size = UDim2.new(0, 70, 0, 24)
BoxWrap.Position = UDim2.new(0, 104, 0.5, -12)
BoxWrap.BackgroundColor3 = Colors.Tile
BoxWrap.BorderSizePixel = 0
Instance.new("UICorner", BoxWrap).CornerRadius = UDim.new(0, 6)
local BoxStroke = Instance.new("UIStroke", BoxWrap)
BoxStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
BoxStroke.Color = Colors.Border
local Box = Instance.new("TextBox", BoxWrap)
Box.Size = UDim2.new(1, -10, 1, 0)
Box.Position = UDim2.new(0, 5, 0, 0)
Box.BackgroundTransparency = 1
Box.Font = Enum.Font.GothamBold
Box.TextSize = 12
Box.TextColor3 = Colors.Accent
Box.ClearTextOnFocus = false
Box.PlaceholderText = "1B"
Box.PlaceholderColor3 = Colors.TextDim
Box.Text = fmt(threshold)

-- tombol cepat 1B / 10B / 1T
local quick = { { "1B", 1e9 }, { "10B", 1e10 }, { "1T", 1e12 } }
local QuickBtns = {}
for i, q in ipairs(quick) do
    local b = Instance.new("TextButton", Bar)
    b.Size = UDim2.new(0, 36, 0, 22)
    b.Position = UDim2.new(1, -8 - (#quick - i + 1) * 40, 0.5, -11)
    b.BackgroundColor3 = Colors.Tile
    b.AutoButtonColor = false
    b.Text = q[1]
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 10
    b.TextColor3 = Colors.TextDim
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    QuickBtns[i] = { btn = b, value = q[2] }
end

-- ringkasan
-- filter sumber pet: Semua / Spawn (ada countdown) / Base (punya pemain) + Debug
local mode = "all"
local ModeBar = Instance.new("Frame", Main)
ModeBar.Size = UDim2.new(1, -24, 0, 24)
ModeBar.Position = UDim2.new(0, 12, 0, 86)
ModeBar.BackgroundTransparency = 1
local ModeBtns = {}
local function ModeBtn(text, key, x, w)
    local b = Instance.new("TextButton", ModeBar)
    b.Size = UDim2.new(0, w, 1, 0)
    b.Position = UDim2.new(0, x, 0, 0)
    b.BackgroundColor3 = Colors.Tile
    b.AutoButtonColor = false
    b.Text = text
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 11
    b.TextColor3 = Colors.TextDim
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    if key then ModeBtns[key] = b end
    return b
end
ModeBtn("Semua", "all", 0, 56)
ModeBtn("Spawn", "spawn", 60, 56)
ModeBtn("Base", "base", 120, 56)
ModeBtn("Base-ku", "mine", 180, 62)
local DebugBtn = ModeBtn("Debug", nil, 250, 56)
DebugBtn.TextColor3 = Colors.Accent

local Summary = NewLabel(Main, "Memindai...", 11, Enum.Font.GothamMedium, Colors.Text)
Summary.Size = UDim2.new(1, -24, 0, 14)
Summary.Position = UDim2.new(0, 12, 0, 116)
local RarityLine = NewLabel(Main, "", 10, Enum.Font.Gotham, Colors.TextDim)
RarityLine.Size = UDim2.new(1, -24, 0, 12)
RarityLine.Position = UDim2.new(0, 12, 0, 132)

-- daftar
local List = Instance.new("ScrollingFrame", Main)
List.Size = UDim2.new(1, -16, 1, -156)
List.Position = UDim2.new(0, 8, 0, 150)
List.BackgroundTransparency = 1
List.BorderSizePixel = 0
List.ScrollBarThickness = 4
List.ScrollBarImageColor3 = Colors.Accent
List.CanvasSize = UDim2.new(0, 0, 0, 0)
List.AutomaticCanvasSize = Enum.AutomaticSize.Y
List.ScrollingDirection = Enum.ScrollingDirection.Y
local LL = Instance.new("UIListLayout", List)
LL.Padding = UDim.new(0, 4)
LL.SortOrder = Enum.SortOrder.LayoutOrder
local LP = Instance.new("UIPadding", List)
LP.PaddingLeft = UDim.new(0, 4)
LP.PaddingRight = UDim.new(0, 8)

-- pool baris (dipakai ulang supaya ringan)
local rows = {}
local function getRow(i)
    if rows[i] then return rows[i] end
    local R = Instance.new("Frame")
    R.Size = UDim2.new(1, 0, 0, 38)
    R.BackgroundColor3 = Colors.Panel
    R.BorderSizePixel = 0
    R.LayoutOrder = i
    R.Parent = List
    Instance.new("UICorner", R).CornerRadius = UDim.new(0, 8)
    local st = Instance.new("UIStroke", R)
    st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    st.Color = Colors.Border
    local Dot = Instance.new("Frame", R)
    Dot.Size = UDim2.new(0, 4, 1, -14)
    Dot.Position = UDim2.new(0, 7, 0, 7)
    Dot.BorderSizePixel = 0
    Instance.new("UICorner", Dot).CornerRadius = UDim.new(1, 0)
    local Name = NewLabel(R, "", 12, Enum.Font.GothamMedium, Colors.Text)
    Name.Size = UDim2.new(1, -110, 0, 15)
    Name.Position = UDim2.new(0, 18, 0, 4)
    local Info = NewLabel(R, "", 10, Enum.Font.Gotham, Colors.TextDim)
    Info.Size = UDim2.new(1, -110, 0, 13)
    Info.Position = UDim2.new(0, 18, 0, 20)
    local Val = NewLabel(R, "", 13, Enum.Font.GothamBold, Colors.Green, Enum.TextXAlignment.Right)
    Val.Size = UDim2.new(0, 90, 0, 16)
    Val.Position = UDim2.new(1, -98, 0, 4)
    local Dist = NewLabel(R, "", 10, Enum.Font.Gotham, Colors.TextDim, Enum.TextXAlignment.Right)
    Dist.Size = UDim2.new(0, 90, 0, 13)
    Dist.Position = UDim2.new(1, -98, 0, 20)
    rows[i] = { frame = R, dot = Dot, name = Name, info = Info, val = Val, dist = Dist }
    return rows[i]
end

local Empty = NewLabel(List, "Belum ada pet di atas batas", 11, Enum.Font.Gotham, Colors.TextDim, Enum.TextXAlignment.Center)
Empty.Size = UDim2.new(1, 0, 0, 30)
Empty.LayoutOrder = 0
Empty.Visible = false

-- ═══════════ [ PEMBARUAN ] ═══════════
local function paintQuick()
    for _, q in ipairs(QuickBtns) do
        local on = math.abs(q.value - threshold) < 1
        q.btn.BackgroundColor3 = on and Colors.Accent or Colors.Tile
        q.btn.TextColor3 = on and Color3.fromRGB(43, 18, 4) or Colors.TextDim
    end
end

local function render()
    local all = collect()
    local shown, perRarity, rarOrder = {}, {}, {}
    for _, e in ipairs(all) do
        local okMode = (mode == "all") or (mode == "spawn" and e.category == "spawn") or (mode == "base" and e.category == "base")
            or (mode == "mine" and myPlot ~= nil and e.plot == myPlot)
        if okMode and e.value >= threshold then
            table.insert(shown, e)
            if not perRarity[e.rarity] then perRarity[e.rarity] = 0; table.insert(rarOrder, e.rarity) end
            perRarity[e.rarity] = perRarity[e.rarity] + 1
        end
    end
    -- pet spawn selalu di atas (supaya tidak tenggelam di bawah pet base bernilai T)
    table.sort(shown, function(a, b)
        if a.spawn ~= b.spawn then return a.spawn end
        return a.value > b.value
    end)
    table.sort(rarOrder, function(a, b) return perRarity[a] > perRarity[b] end)

    local nSpawn = 0
    for _, e in ipairs(all) do if e.spawn then nSpawn = nSpawn + 1 end end
    Summary.Text = #shown .. " pet ≥ " .. fmt(threshold) .. "/s  ·  " .. #all .. " terpindai (" .. nSpawn .. " spawn)"
        .. (shown[1] and ("  ·  tertinggi " .. fmt(shown[1].value)) or "")
    if mode == "mine" then
        if myPlot then
            local total = 0
            for _, e in ipairs(all) do if e.plot == myPlot then total = total + e.value end end
            Summary.Text = #shown .. " pet ≥ " .. fmt(threshold) .. "/s di " .. myPlot.Name .. "  ·  total $" .. fmt(total) .. "/s"
        else
            Summary.Text = "Base kamu belum terdeteksi — berdiri di base, lalu klik Base-ku lagi"
        end
    end
    local parts = {}
    for _, r in ipairs(rarOrder) do table.insert(parts, r .. " " .. perRarity[r]) end
    RarityLine.Text = #parts > 0 and table.concat(parts, "  ·  ") or "Semua rarity dipindai"

    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local n = math.min(#shown, MAX_ROWS)
    for i = 1, n do
        local e, r = shown[i], getRow(i)
        local col = RarityColors[string.lower(e.rarity)] or Colors.Accent
        r.frame.Visible = true
        r.dot.BackgroundColor3 = col
        r.name.Text = e.name
        r.info.Text = e.rarity .. (e.spawn and ("  ·  SPAWN" .. (e.timer and (" " .. e.timer) or ""))
            or (e.owner and ("  ·  " .. e.owner) or ""))
        r.info.TextColor3 = col
        r.val.Text = "$" .. fmt(e.value) .. "/s"
        r.frame.BackgroundColor3 = e.spawn and Color3.fromRGB(28, 34, 26) or Colors.Panel
        local d = (root and e.pos) and math.floor((root.Position - e.pos).Magnitude) or nil
        r.dist.Text = d and (d .. " stud") or ""
    end
    for i = n + 1, #rows do rows[i].frame.Visible = false end
    Empty.Visible = (n == 0)
end

local function setThreshold(v, fromBox)
    if not v or v <= 0 then
        Box.Text = fmt(threshold)
        return
    end
    threshold = v
    Box.Text = fmt(threshold)
    saveThreshold()
    paintQuick()
    render()
end

Box.Focused:Connect(function() BoxStroke.Color = Colors.Accent end)
Box.FocusLost:Connect(function()
    BoxStroke.Color = Colors.Border
    setThreshold(parseThreshold(Box.Text), true)
end)
for _, q in ipairs(QuickBtns) do
    q.btn.MouseButton1Click:Connect(function() setThreshold(q.value) end)
end
paintQuick()

local function paintMode()
    for key, b in pairs(ModeBtns) do
        local on = key == mode
        b.BackgroundColor3 = on and Colors.Accent or Colors.Tile
        b.TextColor3 = on and Color3.fromRGB(43, 18, 4) or Colors.TextDim
    end
end
for key, b in pairs(ModeBtns) do
    b.MouseButton1Click:Connect(function()
        if key == "mine" then
            ensureMyPlot()
            -- sudah di mode Base-ku tapi belum terdeteksi → pakai plot terdekat
            if mode == "mine" and not myPlot then
                local p = nearestPlot()
                if p then
                    myPlot, myPlotSource = p, "plot terdekat"
                    print("🏠 [Pet Scanner] Base kamu di-set manual: " .. p.Name)
                end
            end
        end
        mode = key
        paintMode()
        pcall(render)
    end)
end
paintMode()

-- Debug: tulis ke console (F9) label yang mengandung "$" atau "/s" tapi
-- TIDAK terbaca sebagai value, plus lokasinya — untuk menyesuaikan scanner
DebugBtn.MouseButton1Click:Connect(function()
    -- Debug: tulis ke console (F9) SEMUA label value ($xx/s) yang TIDAK ada di
    -- BillboardGui/SurfaceGui yang dilacak (mis. label 2D di ScreenGui yang
    -- mengikuti pet), plus label "$" yang gagal dibaca — lengkap dengan lokasinya.
    local nTracked = 0
    for _ in pairs(tracked) do nTracked = nTracked + 1 end
    print("──── [Pet Scanner] DEBUG ────  gui dilacak: " .. nTracked)
    local roots = { workspace }
    local pg = player:FindFirstChildOfClass("PlayerGui")
    if pg then table.insert(roots, pg) end
    pcall(function() table.insert(roots, game:GetService("CoreGui")) end)
    pcall(function() if gethui then table.insert(roots, gethui()) end end)
    local outside, failed = 0, 0
    for _, root in ipairs(roots) do
        local okD, desc = pcall(function() return root:GetDescendants() end)
        if okD then
            for _, d in ipairs(desc) do
                if outside >= 25 and failed >= 10 then break end
                if (d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")) and not d:IsDescendantOf(ScreenGui) then
                    local okT, raw = pcall(function() return (d.ContentText ~= "" and d.ContentText) or d.Text end)
                    local t = okT and cleanText(raw) or ""
                    local gui = d:FindFirstAncestorWhichIsA("LayerCollector")
                    local v = parseValueLabel(t)
                    if v and not (gui and tracked[gui]) and outside < 25 then
                        outside = outside + 1
                        print(string.format("  ◆ di luar billboard: \"%s\" | %s | gui=%s", t:sub(1, 30), d:GetFullName(), gui and gui.ClassName or "-"))
                    elseif not v and t:find("%$") and failed < 10 then
                        failed = failed + 1
                        print(string.format("  ✗ gagal dibaca: \"%s\" | %s", t:sub(1, 30), d:GetFullName()))
                    end
                end
            end
        end
    end
    -- jarak terdekat pet yang terbaca
    local okC, all = pcall(collect)
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local nearest
    if okC and root then
        for _, e in ipairs(all) do
            if e.pos then
                local d = (root.Position - e.pos).Magnitude
                if not nearest or d < nearest then nearest = d end
            end
        end
    end
    print("──── " .. outside .. " value di luar billboard, " .. failed .. " gagal dibaca, pet terbaca terdekat: "
        .. (nearest and (math.floor(nearest) .. " stud") or "-") .. " ────")
    DebugBtn.Text = "Cek F9"
    task.delay(2, function() if DebugBtn.Parent then DebugBtn.Text = "Debug" end end)
end)

-- minimize → hanya header
local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    for _, c in ipairs({ Bar, ModeBar, Summary, RarityLine, List }) do c.Visible = not minimized end
    TweenService:Create(Main, TweenInfo.new(0.15), { Size = UDim2.new(0, W, 0, minimized and 46 or H) }):Play()
end)

local alive = true
Scan.Destroy = function()
    alive = false
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    pcall(function() ScreenGui:Destroy() end)
end
CloseBtn.MouseButton1Click:Connect(Scan.Destroy)

-- daftarkan label yang sudah ada + yang muncul kemudian
task.spawn(function()
    -- label pet bisa ada di workspace atau di PlayerGui (ditempel ke pet lewat Adornee)
    local roots = { workspace }
    local pg = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 10)
    if pg then table.insert(roots, pg) end
    for _, root in ipairs(roots) do
        local ok, desc = pcall(function() return root:GetDescendants() end)
        if ok then
            for i, d in ipairs(desc) do
                if d ~= ScreenGui and not d:IsDescendantOf(ScreenGui) then track(d) end
                if i % 3000 == 0 then task.wait() end   -- jangan bikin lag saat map besar
            end
        end
        table.insert(conns, root.DescendantAdded:Connect(track))
        table.insert(conns, root.DescendantRemoving:Connect(function(d) tracked[d] = nil end))
    end
    print("🔎 [Pet Scanner] Siap. Batas: " .. fmt(threshold) .. "/s")
    while alive and ScreenGui.Parent do
        if mode == "mine" then pcall(ensureMyPlot) end
        pcall(render)
        task.wait(REFRESH_EVERY)
    end
end)
