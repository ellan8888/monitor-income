-- ═══════════════════════════════════════════════════════
-- 🥚 V-Ziir0 Hub: Steal An Egg (v49 - UI sidebar + kartu ala Break & Steal)
-- v41: Auto Place All di hub Ajjans ikut nyala (< 15M) / mati (>= 15M).
-- v42: Auto place di hub Venyx juga ikut nyala/mati (lewat objek library Venyx).
-- v43: Venyx: kalau :Set tidak mempan → klik toggle langsung; log status di F9.
-- v45: Egg di hotbar dibaca dari UI hotbar (BackpackGui), bukan cuma grid tas.
-- v46: Map terakhir & daftar egg otomatis dari ReplicatedStorage.Data.Areas.Configs;
--      egg dihitung dari Tool di Backpack + karakter (nama Tool = nama pet).
-- v47: fungsi Ajjans/Venyx/EggData dibungkus do...end (batas 200 local Luau).
-- v49: UI baru: sidebar (Monitor/Egg/Server), header, kartu 2 kolom, footer status.
-- v48: egg = grid tas ("<Map> Egg", UI) + hotbar (Tool "<Pet> Egg"); pet tidak dihitung.
-- v40: setelah server hop, script otomatis jalan lagi dan MELANJUTKAN monitor
--      beserta daftar target dari server sebelumnya (config dibaca dari file).
-- UI sama dengan v39. Logika sniper/auto place/webhook tidak diubah.
-- ═══════════════════════════════════════════════════════

-- ⭐ TUNGGU GAME SIAP (penting saat dijalankan otomatis setelah teleport)
if not game:IsLoaded() then game.Loaded:Wait() end
print("🥚 V-Ziir0 Steal An Egg v49 dimuat")

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

local setAjjansAutoPlace, getAjjansAutoPlaceState, setVenyxAutoPlace, getVenyxAutoPlaceState
do
-- ═══════════ [ FUNGSI AJJANS ] ═══════════
-- Cari toggle "Auto Place All" di UI Ajjans lalu hidup/matikan tanpa mouse
-- (tetap jalan walau UI Ajjans ditutup). Hasil scan di-cache; scan ulang
-- maksimal tiap 5 detik kalau toggle belum/tidak lagi ketemu.
local Ajjans = { label = nil, toggle = nil, row = nil, lastScan = 0, busy = false, lastClick = 0, warned = false }
local AJJANS_TEXT = "auto place all"   -- teks label persis (huruf kecil)

local function ajjansRoots()
    local roots = {}
    pcall(function() if gethui then table.insert(roots, gethui()) end end)
    pcall(function() table.insert(roots, game:GetService("CoreGui")) end)
    pcall(function()
        local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
        if pg then table.insert(roots, pg) end
    end)
    return roots
end

local function ajjansFindLabel()
    for _, root in ipairs(ajjansRoots()) do
        local ok, desc = pcall(function() return root:GetDescendants() end)
        if ok then
            for _, d in ipairs(desc) do
                if d:IsA("TextLabel") or d:IsA("TextButton") then
                    local okT, t = pcall(function() return (d.ContentText ~= "" and d.ContentText) or d.Text or "" end)
                    if okT then
                        t = string.lower(t):gsub("^%s+", ""):gsub("%s+$", "")
                        if t == AJJANS_TEXT then return d end
                    end
                end
            end
        end
    end
end

local function ajjansFindToggle(label)
    local row = label.Parent
    for _ = 1, 3 do
        if not row then break end
        local best
        for _, d in ipairs(row:GetDescendants()) do
            if d ~= label and d:IsA("GuiObject") then
                local isBtn = d:IsA("GuiButton")
                local sz = d.AbsoluteSize
                local pill = sz.X > 0 and sz.X <= 80 and sz.Y <= 40 and sz.X >= sz.Y
                if (isBtn or pill) and d.AbsolutePosition.X > label.AbsolutePosition.X then
                    if not best or (isBtn and not best:IsA("GuiButton")) then best = d end
                end
            end
        end
        if best then return best, row end
        if row:IsA("GuiButton") then return row, row end
        row = row.Parent
    end
end

local function ajjansIsRed(c) return c.R > 0.6 and c.G < 0.35 and c.B < 0.35 end

local function ajjansReadState(toggle)
    -- toggle Ajjans: merah = ON, gelap = OFF
    if ajjansIsRed(toggle.BackgroundColor3) and toggle.BackgroundTransparency < 0.9 then return true end
    for _, d in ipairs(toggle:GetDescendants()) do
        if d:IsA("GuiObject") and d.BackgroundTransparency < 0.9 and d.AbsoluteSize.X > toggle.AbsoluteSize.X * 0.6 then
            if ajjansIsRed(d.BackgroundColor3) then return true end
        end
        if d:IsA("ImageLabel") and ajjansIsRed(d.ImageColor3) and d.ImageTransparency < 0.9 then return true end
    end
    -- fallback: posisi knob (kanan = ON)
    for _, d in ipairs(toggle:GetDescendants()) do
        if d:IsA("Frame") and d.AbsoluteSize.X <= toggle.AbsoluteSize.X * 0.6 then
            local mid = toggle.AbsolutePosition.X + toggle.AbsoluteSize.X / 2
            return (d.AbsolutePosition.X + d.AbsoluteSize.X / 2) > mid
        end
    end
    return false
end

local ajjansFakeInput = {
    UserInputType = Enum.UserInputType.MouseButton1,
    UserInputState = Enum.UserInputState.Begin,
    Position = Vector3.zero, KeyCode = Enum.KeyCode.Unknown,
}

local function ajjansFire(sig, ...)
    local args = { ... }
    local fired = false
    if getconnections then
        local ok, conns = pcall(getconnections, sig)
        if ok then
            for _, c in ipairs(conns) do
                pcall(function()
                    if c.Function then c.Function(table.unpack(args)) else c:Fire(table.unpack(args)) end
                end)
                fired = true
            end
        end
    end
    if not fired and firesignal then
        fired = pcall(firesignal, sig, table.unpack(args))
    end
    return fired
end

local function ajjansClick(obj)
    local done = false
    if obj:IsA("GuiButton") then
        done = ajjansFire(obj.MouseButton1Click)
        if not done then done = ajjansFire(obj.Activated, ajjansFakeInput, 1) end
        if not done then done = ajjansFire(obj.MouseButton1Down, 0, 0) end
    end
    if not done then
        done = ajjansFire(obj.InputBegan, ajjansFakeInput)
        if done then
            local ended = table.clone(ajjansFakeInput); ended.UserInputState = Enum.UserInputState.End
            ajjansFire(obj.InputEnded, ended)
        end
    end
    return done
end

local function ajjansSetup(force)
    if Ajjans.toggle and Ajjans.toggle.Parent and not force then return true end
    if not force and (os.clock() - Ajjans.lastScan) < 5 then return false end
    Ajjans.lastScan = os.clock()
    Ajjans.label = ajjansFindLabel()
    if not Ajjans.label then Ajjans.toggle = nil; return false end
    Ajjans.toggle, Ajjans.row = ajjansFindToggle(Ajjans.label)
    if Ajjans.toggle then print("✅ [Ajjans] Toggle 'Auto Place All' ketemu: " .. Ajjans.toggle:GetFullName()) end
    return Ajjans.toggle ~= nil
end

function getAjjansAutoPlaceState()
    if not ajjansSetup(false) then return nil end
    local ok, v = pcall(ajjansReadState, Ajjans.toggle)
    if ok then return v end
    return nil
end

-- Non-blocking: aman dipanggil tiap detik dari loop monitor
function setAjjansAutoPlace(state)
    if Ajjans.busy then return true end
    if not ajjansSetup(false) then
        if not Ajjans.warned then
            Ajjans.warned = true
            warn("[Ajjans] Toggle 'Auto Place All' belum ketemu (abaikan kalau tidak pakai Ajjans; buka tab Automation Ajjans sekali kalau pakai).")
        end
        return false
    end
    local okS, cur = pcall(ajjansReadState, Ajjans.toggle)
    if okS and cur == state then return true end
    if (os.clock() - Ajjans.lastClick) < 1.5 then return true end  -- tunggu UI update dulu
    Ajjans.busy = true
    Ajjans.lastClick = os.clock()
    task.spawn(function()
        pcall(function()
            local t = Ajjans.toggle
            ajjansClick(t)
            task.wait(0.15)
            if ajjansReadState(t) ~= state then
                for _, d in ipairs(t:GetDescendants()) do
                    if d:IsA("GuiButton") then
                        ajjansClick(d); task.wait(0.15)
                        if ajjansReadState(t) == state then break end
                    end
                end
            end
            if ajjansReadState(t) ~= state and Ajjans.row then ajjansClick(Ajjans.row) end
            print("🔄 [Ajjans] Auto Place All -> " .. (ajjansReadState(t) and "ON" or "OFF"))
        end)
        Ajjans.busy = false
    end)
    return true
end
_G.setAjjansAutoPlace = setAjjansAutoPlace

-- ═══════════ [ FUNGSI VENYX ] ═══════════
-- Toggle "Auto place" Venyx diubah lewat objek library-nya (getgc -> :Set),
-- status dibaca dari knob toggle di UI (kanan = ON). Jalan walau UI Venyx
-- ditutup/minimize. Scan UI maks tiap 5 dtk, scan getgc maks tiap 15 dtk.
local Venyx = { toggle = nil, lastScan = 0, lib = nil, libFn = nil, lastGc = 0,
                busy = false, lastClick = 0, lastSent = nil, warned = false }
local VENYX_TEXT = "auto place"   -- teks label persis (huruf kecil)

local function venyxTextOf(d)
    local ok, t = pcall(function()
        return (d.ContentText ~= nil and d.ContentText ~= "" and d.ContentText) or d.Text or ""
    end)
    if not ok then return "" end
    return (string.lower(t):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function venyxFindKnob(pill)
    local ps = pill.AbsoluteSize
    for _, d in ipairs(pill:GetDescendants()) do
        if d:IsA("Frame") or d:IsA("ImageLabel") or d:IsA("ImageButton") or d:IsA("TextButton") then
            local sz = d.AbsoluteSize
            if sz.X > 4 and math.abs(sz.X - sz.Y) <= 4 and sz.Y <= ps.Y + 2 and sz.X < ps.X * 0.75 then
                return d
            end
        end
    end
end

local function venyxIsPill(d)
    if not d:IsA("GuiObject") then return false end
    local sz = d.AbsoluteSize
    return sz.X >= 28 and sz.X <= 100 and sz.Y >= 12 and sz.Y <= 44 and sz.X >= sz.Y * 1.4 and venyxFindKnob(d) ~= nil
end

local function venyxFindToggle(label)
    local lc = label.AbsolutePosition.Y + label.AbsoluteSize.Y / 2
    local row = label.Parent
    for _ = 1, 3 do
        if not row then break end
        for _, d in ipairs(row:GetDescendants()) do
            if d ~= label and venyxIsPill(d) and d.AbsolutePosition.X > label.AbsolutePosition.X then
                local dc = d.AbsolutePosition.Y + d.AbsoluteSize.Y / 2
                if math.abs(dc - lc) <= 24 then return d end
            end
        end
        row = row.Parent
    end
end

local function venyxSetupUI()
    if Venyx.toggle and Venyx.toggle.Parent then return true end
    if (os.clock() - Venyx.lastScan) < 5 then return false end
    Venyx.lastScan = os.clock()
    Venyx.toggle = nil
    local bestArea = -1
    for _, root in ipairs(ajjansRoots()) do
        local ok, desc = pcall(function() return root:GetDescendants() end)
        if ok then
            for _, l in ipairs(desc) do
                if (l:IsA("TextLabel") or l:IsA("TextButton")) and venyxTextOf(l) == VENYX_TEXT then
                    local okT, t = pcall(venyxFindToggle, l)
                    if okT and t then
                        local g = l:FindFirstAncestorWhichIsA("LayerCollector")
                        local w = l
                        while w.Parent and w.Parent ~= g do w = w.Parent end
                        local area = w:IsA("GuiObject") and (w.AbsoluteSize.X * w.AbsoluteSize.Y) or 0
                        if area > bestArea then   -- window utama, bukan Quick Bar
                            bestArea = area
                            Venyx.toggle = t
                        end
                    end
                end
            end
        end
    end
    if Venyx.toggle then print("✅ [Venyx] Toggle UI 'Auto place' ketemu: " .. Venyx.toggle:GetFullName()) end
    return Venyx.toggle ~= nil
end

-- true/false kalau toggle UI terbaca, nil kalau belum ketemu
local function venyxReadState()
    if not venyxSetupUI() then return nil end
    local ok, v = pcall(function()
        local t = Venyx.toggle
        local knob = venyxFindKnob(t)
        if not knob then return nil end
        local w = t.AbsoluteSize.X
        local x = knob.Position.X.Scale * w + knob.Position.X.Offset
        local center = x - knob.AnchorPoint.X * knob.AbsoluteSize.X + knob.AbsoluteSize.X / 2
        return center > w / 2
    end)
    if ok then return v end
    return nil
end

local function venyxFindLib(force)
    if Venyx.lib and not force then return true end
    if not getgc then return false end
    if not force and (os.clock() - Venyx.lastGc) < 15 then return false end
    -- 3x gagal & toggle UI Venyx juga tidak ada → anggap Venyx tidak dipakai, stop scan berat
    if not force and (Venyx.gcFails or 0) >= 3 and not (Venyx.toggle and Venyx.toggle.Parent) then return false end
    Venyx.lastGc = os.clock()
    Venyx.lib, Venyx.libFn = nil, nil
    local names = { "Set", "SetValue", "SetState", "Toggle", "set", "setValue", "SetToggle" }
    local ok, gc = pcall(getgc, true)
    if not ok then return false end
    for _, t in ipairs(gc) do
        if type(t) == "table" then
            local hit = false
            pcall(function()
                for _, v in pairs(t) do
                    if type(v) == "string" and string.lower(v) == VENYX_TEXT then hit = true; break end
                end
            end)
            if hit then
                for _, fn in ipairs(names) do
                    local f
                    pcall(function() f = t[fn] end)
                    if type(f) == "function" then
                        Venyx.lib, Venyx.libFn = t, fn
                        print("✅ [Venyx] Objek library 'Auto place' ketemu (fungsi: " .. fn .. ")")
                        return true
                    end
                end
            end
        end
    end
    Venyx.gcFails = (Venyx.gcFails or 0) + 1
    return false
end

function getVenyxAutoPlaceState()
    return venyxReadState()
end

-- Klik toggle UI Venyx langsung (fallback kalau :Set tidak mempan)
local function venyxClickToggle(state)
    local t = Venyx.toggle
    if not (t and t.Parent) then return false end
    local tries = { t }
    for _, d in ipairs(t:GetDescendants()) do
        if d:IsA("GuiButton") then table.insert(tries, d) end
    end
    local p = t.Parent
    for _ = 1, 3 do
        if p and p:IsA("GuiButton") then table.insert(tries, p) end
        p = p and p.Parent
    end
    for _, obj in ipairs(tries) do
        pcall(ajjansClick, obj)
        task.wait(0.35)
        if venyxReadState() == state then return true end
    end
    return false
end

local venyxLastDiag = ""
local function venyxDiag()
    local d = "UI toggle: " .. ((Venyx.toggle and Venyx.toggle.Parent) and "ketemu" or "TIDAK") ..
              " | library: " .. (Venyx.lib and ("ketemu (" .. tostring(Venyx.libFn) .. ")") or "TIDAK") ..
              " | getgc: " .. (getgc and "ada" or "TIDAK ADA")
    if d ~= venyxLastDiag then
        venyxLastDiag = d
        print("🔎 [Venyx] " .. d)
    end
end

-- Non-blocking: aman dipanggil tiap detik dari loop monitor
function setVenyxAutoPlace(state)
    if Venyx.busy then return true end
    local cur = venyxReadState()
    if cur == state then Venyx.lastSent = state; return true end
    -- UI tidak terbaca → hanya kirim saat target berubah (hindari spam)
    if cur == nil and Venyx.lastSent == state then return true end
    if (os.clock() - Venyx.lastClick) < 2 then return true end
    Venyx.busy = true
    Venyx.lastClick = os.clock()
    task.spawn(function()
        pcall(function()
            -- 1) lewat objek library Venyx
            if venyxFindLib(false) then
                pcall(function() Venyx.lib[Venyx.libFn](Venyx.lib, state) end)
                task.wait(0.35)
            end
            local after = venyxReadState()
            -- 2) UI terbaca tapi belum berubah → klik toggle langsung
            if after ~= nil and after ~= state then
                if venyxClickToggle(state) then
                    after = state
                    print("🖱️ [Venyx] Auto place diubah lewat klik toggle")
                elseif (os.clock() - (Venyx.lastForceGc or 0)) > 30 then
                    -- 3) objek library mungkin basi (UI di-reload) → cari ulang, maks 1x/30 dtk
                    Venyx.lastForceGc = os.clock()
                    if venyxFindLib(true) then
                        pcall(function() Venyx.lib[Venyx.libFn](Venyx.lib, state) end)
                        task.wait(0.35)
                        after = venyxReadState()
                    end
                end
            end
            venyxDiag()
            if after == nil and not Venyx.lib then
                if not Venyx.warned then
                    Venyx.warned = true
                    warn("[Venyx] Toggle 'Auto place' belum ketemu (abaikan kalau tidak pakai Venyx; kalau pakai, buka UI Venyx di tab Farm > Pen sekali).")
                end
                return
            end
            Venyx.lastSent = state
            local shown = (after == nil) and (state and "ON (terkirim)" or "OFF (terkirim)") or (after and "ON" or "OFF")
            if after ~= nil and after ~= state then shown = shown .. " ⚠️ GAGAL diubah" end
            print("🔄 [Venyx] Auto place -> " .. shown)
        end)
        Venyx.busy = false
    end)
    return true
end
_G.setVenyxAutoPlace = setVenyxAutoPlace

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

local EggData, loadEggData, forEachEggTool, forEachGridEgg, getHotbarSlots
do
-- ═══════════ [ DATA EGG OTOMATIS (dari config game) ] ═══════════
-- Sumber: ReplicatedStorage.Data.Areas.Configs (1 ModuleScript per map).
-- • Map terakhir = map dengan ProgressionOrder tertinggi yang ada di dunia
--   (Workspace.World.Areas.GuardAreas). Ada map baru dari update → otomatis pindah.
-- • Daftar egg map = DropTable map itu. ID di DropTable (mis. "Cosmic Fox")
--   diterjemahkan ke nama tampilan (mis. "Starry Fox") lewat ModuleScript
--   bernama sama di ReplicatedStorage.Data.
-- • Egg dihitung dari Tool di Backpack + karakter (nama Tool = nama pet).
-- Config dibaca ulang tiap 60 dtk. Kalau gagal → pakai cara lama (UI tas).
local RS_Egg = game:GetService("ReplicatedStorage")
EggData = { ok = false, lastLoad = -1000, areas = {}, byId = {}, lastArea = nil,
                  matchers = {}, diagDone = false }

local function eggNorm(str)
    str = string.lower(tostring(str or ""))
    str = str:gsub("%s*%[.-%]%s*$", "")      -- buang "[X1]"
    str = str:gsub("%s+egg$", "")            -- buang akhiran " egg"
    str = str:gsub("^%s+", ""):gsub("%s+$", "")
    return str
end

local displayCache = {}
local moduleIndex = nil
local function resolveDisplayName(id)
    if displayCache[id] ~= nil then return displayCache[id] or nil end
    if not moduleIndex then
        moduleIndex = {}
        local data = RS_Egg:FindFirstChild("Data")
        local areasFolder = data and data:FindFirstChild("Areas")
        if data then
            for _, m in ipairs(data:GetDescendants()) do
                if m:IsA("ModuleScript") and not (areasFolder and m:IsDescendantOf(areasFolder)) then
                    moduleIndex[m.Name] = moduleIndex[m.Name] or {}
                    table.insert(moduleIndex[m.Name], m)
                end
            end
        end
    end
    local found = false
    for _, m in ipairs(moduleIndex[id] or {}) do
        local ok, t = pcall(require, m)
        if ok and type(t) == "table" then
            local dn = rawget(t, "DisplayName") or rawget(t, "Name")
            if type(dn) == "string" and dn ~= "" then found = dn; break end
        end
    end
    displayCache[id] = found
    return found or nil
end

function loadEggData(force)
    if not force and (os.clock() - EggData.lastLoad) < 60 then return EggData.ok end
    EggData.lastLoad = os.clock()
    local ok = pcall(function()
        local configs = RS_Egg:WaitForChild("Data", 5)
        configs = configs and configs:FindFirstChild("Areas")
        configs = configs and configs:FindFirstChild("Configs")
        if not configs then error("Areas.Configs tidak ada") end

        local areas, byId = {}, {}
        for _, mod in ipairs(configs:GetChildren()) do
            if mod:IsA("ModuleScript") then
                local okR, cfg = pcall(require, mod)
                if okR and type(cfg) == "table" and type(cfg.DropTable) == "table" then
                    local area = {
                        id = tostring(cfg._id or mod.Name),
                        name = tostring(cfg.DisplayName or cfg._id or mod.Name),
                        guardId = tostring(cfg.GuardId or cfg._id or mod.Name),
                        order = tonumber(cfg.ProgressionOrder) or -1,
                        pets = {},
                    }
                    for _, entry in ipairs(cfg.DropTable) do
                        local pid = type(entry) == "table" and entry[1] or nil
                        if type(pid) == "string" then
                            local dn = resolveDisplayName(pid) or pid
                            table.insert(area.pets, { id = pid, name = dn })
                        end
                    end
                    table.insert(areas, area)
                    byId[area.id] = area
                end
            end
        end
        if #areas == 0 then error("tidak ada config map") end

        -- map terakhir: ProgressionOrder tertinggi yang ada di dunia
        local guard = Workspace:FindFirstChild("World")
        guard = guard and guard:FindFirstChild("Areas")
        guard = guard and guard:FindFirstChild("GuardAreas")
        local best
        for _, a in ipairs(areas) do
            local inWorld = guard == nil or guard:FindFirstChild(a.guardId) or guard:FindFirstChild(a.id) or guard:FindFirstChild(a.name)
            if inWorld and (not best or a.order > best.order) then best = a end
        end
        if not best then
            for _, a in ipairs(areas) do if not best or a.order > best.order then best = a end end
        end

        -- pencocok nama Tool → map (nama terpanjang dicek dulu)
        local matchers = {}
        for _, a in ipairs(areas) do
            for _, pet in ipairs(a.pets) do
                table.insert(matchers, { key = eggNorm(pet.name), area = a, label = pet.name })
                if eggNorm(pet.id) ~= eggNorm(pet.name) then
                    table.insert(matchers, { key = eggNorm(pet.id), area = a, label = pet.name })
                end
            end
        end
        table.sort(matchers, function(x, y) return #x.key > #y.key end)

        local changed = EggData.lastArea and best and EggData.lastArea.id ~= best.id
        EggData.areas, EggData.byId, EggData.lastArea, EggData.matchers = areas, byId, best, matchers
        if changed then print("🆕 [EggData] Map terakhir berubah → " .. best.name) end
    end)
    EggData.ok = ok and EggData.lastArea ~= nil
    if EggData.ok and not EggData.diagDone then
        EggData.diagDone = true
        local names = {}
        for _, pet in ipairs(EggData.lastArea.pets) do
            table.insert(names, pet.name ~= pet.id and (pet.name .. " (" .. pet.id .. ")") or pet.name)
        end
        print("🥚 [EggData] Map terakhir: " .. EggData.lastArea.name .. " (order " .. EggData.lastArea.order .. ")")
        print("🥚 [EggData] Egg map ini: " .. table.concat(names, ", "))
    elseif not EggData.ok and not EggData.diagDone then
        EggData.diagDone = true
        warn("[EggData] Config map tidak terbaca → pakai deteksi lama (UI tas).")
    end
    return EggData.ok
end

-- map asal sebuah Tool egg (nil kalau bukan egg yang dikenal)
local function eggToolInfo(tool)
    local n = eggNorm(tool.Name)
    for _, m in ipairs(EggData.matchers) do
        if n == m.key or (#n > #m.key and n:sub(-(#m.key + 1)) == " " .. m.key) then
            return m.area, m.label
        end
    end
    -- cek atribut (beberapa game simpan ID pet di atribut)
    local okA, attrs = pcall(function() return tool:GetAttributes() end)
    if okA and attrs then
        for _, v in pairs(attrs) do
            if type(v) == "string" then
                local key = eggNorm(v)
                for _, m in ipairs(EggData.matchers) do
                    if key == m.key then return m.area, m.label end
                end
            end
        end
    end
    -- nama gaya lama: "<Map> Egg"
    local lower = string.lower(tool.Name)
    if lower:find("egg") then
        for _, a in ipairs(EggData.areas) do
            if lower:find(string.lower(a.name), 1, true) then return a, a.name end
        end
    end
    return nil
end

local function eggToolMult(tool)
    local m = string.match(tool.Name, "%[[xX](%d+)%]")
    return tonumber(m) or 1
end

-- egg di grid tas ("All Items" → Eggs): hanya ada di UI, bukan Tool.
-- fn(namaItem, jumlah) untuk tiap slot yang namanya mengandung "egg".
function forEachGridEgg(fn)
    local pg = player:FindFirstChild("PlayerGui")
    local inv = pg and pg:FindFirstChild("BackpackGui")
    if inv then pcall(function() inv.Enabled = true end) end
    for _, k in ipairs({ "Backpack", "Main", "Inventory", "ScrollingFrame" }) do
        inv = inv and inv:FindFirstChild(k)
    end
    if not inv then return false end
    for _, slot in ipairs(inv:GetChildren()) do
        if slot:IsA("Frame") or slot:IsA("ImageLabel") or slot:IsA("TextButton") then
            local lbl = slot:FindFirstChild("ToolName") or slot:FindFirstChild("Name")
            local itemName
            if lbl and lbl:IsA("TextLabel") then itemName = lbl.Text
            else
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
                fn(itemName, mult)
            end
        end
    end
    return true
end

-- egg di hotbar / yang dipegang: Tool bernama "<Pet> Egg" (Backpack + karakter)
function forEachEggTool(fn)
    local containers = { player:FindFirstChild("Backpack"), player.Character }
    for _, c in ipairs(containers) do
        if c then
            for _, obj in ipairs(c:GetChildren()) do
                if obj:IsA("Tool") then
                    -- hanya EGG (nama berakhiran "Egg"), bukan pet ("Astral Jackalope")
                    local raw = string.lower(obj.Name):gsub("%s*%[.-%]%s*$", ""):gsub("%s+$", "")
                    if raw:sub(-3) == "egg" then
                        local area, label = eggToolInfo(obj)
                        if area then fn(obj, area, label .. " Egg", eggToolMult(obj)) end
                    end
                end
            end
        end
    end
end

-- ═══════════ [ SLOT HOTBAR (UI) ] ═══════════
-- Ambil slot hotbar dari BackpackGui: semua label "ToolName" berisi teks
-- yang BUKAN bagian grid "Semua Barang" (Backpack.Main.Inventory).
local hotbarDiagDone = false
function getHotbarSlots()
    local slots, seen = {}, {}
    local pg = player:FindFirstChild("PlayerGui")
    local bg = pg and pg:FindFirstChild("BackpackGui")
    if not bg then return slots end
    local inv = bg:FindFirstChild("Backpack")
    inv = inv and inv:FindFirstChild("Main")
    inv = inv and inv:FindFirstChild("Inventory")
    for _, d in ipairs(bg:GetDescendants()) do
        if d:IsA("TextLabel") and (d.Name == "ToolName" or d.Name == "Name") and d.Text ~= "" then
            if not (inv and d:IsDescendantOf(inv)) then
                local slot = d.Parent
                if slot and not seen[slot] then
                    seen[slot] = true
                    table.insert(slots, slot)
                end
            end
        end
    end
    if not hotbarDiagDone then
        hotbarDiagDone = true
        print("🔎 [Hotbar] " .. #slots .. " slot terisi:")
        for _, sl in ipairs(slots) do
            local lbl = sl:FindFirstChild("ToolName") or sl:FindFirstChild("Name")
            print("   • " .. sl:GetFullName() .. " = " .. tostring(lbl and lbl.Text))
        end
        local bp = player:FindFirstChild("Backpack")
        if bp then
            local names = {}
            for _, o in ipairs(bp:GetChildren()) do table.insert(names, o.ClassName .. ":" .. o.Name) end
            print("🔎 [Backpack folder] " .. (#names > 0 and table.concat(names, ", ") or "(kosong)"))
        end
    end
    return slots
end

end

local function getFarthestMapAndEgg()
    -- ⭐ Cara baru: map terakhir + daftar egg dari config game
    if loadEggData(false) then
        local target = EggData.lastArea
        local mapLower = string.lower(target.name)
        local total = 0
        -- grid tas: "Enchanted Forest Egg"
        forEachGridEgg(function(name, mult)
            if string.lower(name):find(mapLower, 1, true) then total = total + mult end
        end)
        -- hotbar / dipegang: "Prism Gecko Egg" (pet dari map terakhir)
        forEachEggTool(function(_, area, _, mult)
            if area == target then total = total + mult end
        end)
        return target.name, total
    end

    -- Cara lama (fallback): map terjauh dari jarak + baca UI tas
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

    -- Hotbar (bar bawah) dibaca dari UI. Slot hotbar juga menampilkan item
    -- yang sedang dipegang, jadi kalau UI hotbar terbaca, Tool di karakter
    -- tidak dihitung lagi (anti dobel).
    local hotbarSlots = getHotbarSlots()
    for _, slot in ipairs(hotbarSlots) do checkSlot(slot) end
    if #hotbarSlots == 0 then
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("Tool") and obj.Name:lower():find("egg") and obj.Name:lower():find(farthestMapName:lower()) then
                totalEggFisik = totalEggFisik + 1
            end
        end
        local bpFolder = player:FindFirstChild("Backpack")
        if bpFolder then
            for _, obj in ipairs(bpFolder:GetChildren()) do
                if obj:IsA("Tool") and obj.Name:lower():find("egg") and obj.Name:lower():find(farthestMapName:lower()) then
                    totalEggFisik = totalEggFisik + 1
                end
            end
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
-- ⭐ UI CUSTOM (v49 - layout sidebar + kartu, gaya Break & Steal, tema teal)
-- Bagian ini murni tampilan. Variabel logika hanya DIBACA oleh UI,
-- kecuali handler klik yang isinya sama persis dengan versi sebelumnya.
-- Banyak blok dibungkus do...end supaya tidak melewati batas 200 local Luau.
-- ═══════════════════════════════════════════════════════
local Colors = {
    Background = Color3.fromRGB(12, 17, 20),
    Sidebar    = Color3.fromRGB(16, 22, 26),
    GlassPanel = Color3.fromRGB(19, 27, 32),   -- latar kartu
    Tile       = Color3.fromRGB(26, 36, 42),   -- latar tile / tombol kecil
    Border     = Color3.fromRGB(36, 49, 57),
    Accent     = Color3.fromRGB(25, 195, 217), -- ganti di sini kalau mau warna lain
    Text       = Color3.fromRGB(234, 246, 251),
    TextDim    = Color3.fromRGB(122, 147, 160),
    SwitchOff  = Color3.fromRGB(46, 61, 70),
    Green      = Color3.fromRGB(79, 227, 168),
    Amber      = Color3.fromRGB(245, 194, 107),
    Danger     = Color3.fromRGB(229, 72, 77),
    Track      = Color3.fromRGB(32, 44, 51),
    OnAccent   = Color3.fromRGB(6, 40, 48),
    ChipOn     = Color3.fromRGB(16, 44, 52),
    AmberBg    = Color3.fromRGB(43, 36, 23),
}

local EGG_GOAL = 100 -- target egg di tampilan (hanya UI, script tidak berhenti di angka ini)
local UI = {}   -- referensi elemen UI yang diperbarui dari luar
local W = {}    -- pabrik widget

-- ⭐ IKON: digambar langsung dari bentuk (Frame), tidak butuh asset ID.
-- Opsional: isi "rbxassetid://ID" di tabel Icons untuk mengganti ikon dengan gambar.
local MakeIcon, SetIconColor
do
    local Icons = {
        egg = "", monitor = "", target = "", close = "", minus = "", check = "", checkc = "",
        hourglass = "", bolt = "", user = "", hop = "", send = "", scan = "", backpack = "", refresh = "",
        server = "", copy = "", login = "", chevron = "", lock = "", clock = "",
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
        server = function(H)
            H.ring(2, 2.5, 12, 4.5, 1.4, 0.25); H.ring(2, 9, 12, 4.5, 1.4, 0.25)
            H.dot(5, 4.75, 1.6); H.dot(5, 11.25, 1.6)
        end,
        copy = function(H)
            H.ring(5.5, 5.5, 8.5, 8.5, 1.5, 0.15)
            H.line(2.5, 10.5, 2.5, 2.5, 1.5); H.line(2.5, 2.5, 10.5, 2.5, 1.5)
        end,
        login = function(H)
            H.line(2, 8, 10, 8, 1.8); H.line(10, 8, 6.5, 4.5, 1.8); H.line(10, 8, 6.5, 11.5, 1.8)
            H.line(13, 2.5, 13, 13.5, 1.8)
        end,
        chevron = function(H) H.line(4, 6, 8, 10, 1.6); H.line(8, 10, 12, 6, 1.6) end,
        lock = function(H) H.rect(3, 7.5, 10, 6.5, 0.2); H.ring(4.8, 1.8, 6.4, 7.4, 1.5) end,
        clock = function(H) H.ring(1.5, 1.5, 13, 13, 1.5); H.line(8, 4.4, 8, 8, 1.5); H.line(8, 8, 10.8, 9.6, 1.5) end,
    }

    MakeIcon = function(parent, key, size, color)
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

    SetIconColor = function(ic, color)
        local paint = IconPaint[ic]
        if paint then paint(color)
        elseif ic:IsA("ImageLabel") then ic.ImageColor3 = color end
    end
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

-- gaya scrollbar seragam (tipis, warna aksen)
local function StyleScrollbar(sf)
    sf.BorderSizePixel = 0
    sf.ScrollBarThickness = 4
    sf.ScrollBarImageColor3 = Colors.Accent
    sf.ScrollBarImageTransparency = 0
    sf.VerticalScrollBarInset = Enum.ScrollBarInset.Always
    sf.ScrollingDirection = Enum.ScrollingDirection.Y
    sf.CanvasSize = UDim2.new(0, 0, 0, 0)
    sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VZiir0HubGlass"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = CoreGui
_G.StealEgg_Hub_UI = ScreenGui

-- ═══════════ [ FRAME UTAMA ] ═══════════
local SIDEBAR_W = 150
local FRAME_W, FRAME_H = 580, 400

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, FRAME_W, 0, FRAME_H)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.BackgroundColor3 = Colors.Background
MainFrame.BackgroundTransparency = 0.02
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Active = true
MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 14)
do
    local MainBorder = Instance.new("UIStroke", MainFrame)
    MainBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    MainBorder.Color = Colors.Border
    MainBorder.Thickness = 1

    -- auto-scale untuk layar kecil (HP)
    local MainScale = Instance.new("UIScale", MainFrame)
    local function UpdateScale()
        local vp = ScreenGui.AbsoluteSize
        if vp.X < 50 or vp.Y < 50 then
            local cam = workspace.CurrentCamera
            vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
        end
        local sc = math.min(1, (vp.X - 16) / FRAME_W, (vp.Y - 16) / FRAME_H)
        MainScale.Scale = math.clamp(sc, 0.4, 1)
    end
    UpdateScale()
    ScreenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateScale)
end

-- ═══════════ [ WIDGET (kartu, tile, saklar, tombol) ] ═══════════
-- kartu dengan header (klik header = lipat/buka)
W.Card = function(parent, title, iconKey, bodyH, order)
    local full = 36 + bodyH + 6
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, full)
    card.BackgroundColor3 = Colors.GlassPanel
    card.BorderSizePixel = 0
    card.LayoutOrder = order or 0
    card.ClipsDescendants = true
    card.Parent = parent
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
    local st = Instance.new("UIStroke", card)
    st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    st.Thickness = 1
    st.Color = Colors.Border

    local ic = MakeIcon(card, iconKey, 15, Colors.Accent)
    ic.Position = UDim2.new(0, 12, 0, 8)
    local t = NewLabel(card, title, 12, Enum.Font.GothamBold, Colors.Text)
    t.Size = UDim2.new(0, 120, 0, 30)
    t.Position = UDim2.new(0, 34, 0, 0)

    local chev = MakeIcon(card, "chevron", 14, Colors.TextDim)
    chev.AnchorPoint = Vector2.new(0.5, 0.5)
    chev.Position = UDim2.new(1, -19, 0, 15)

    local div = Instance.new("Frame", card)
    div.Size = UDim2.new(1, -24, 0, 1)
    div.Position = UDim2.new(0, 12, 0, 30)
    div.BackgroundColor3 = Colors.Border
    div.BorderSizePixel = 0

    local body = Instance.new("Frame", card)
    body.Size = UDim2.new(1, -24, 0, bodyH)
    body.Position = UDim2.new(0, 12, 0, 36)
    body.BackgroundTransparency = 1

    local hdr = Instance.new("TextButton", card)
    hdr.Size = UDim2.new(1, 0, 0, 30)
    hdr.BackgroundTransparency = 1
    hdr.Text = ""
    hdr.ZIndex = 2
    local collapsed = false
    hdr.MouseButton1Click:Connect(function()
        collapsed = not collapsed
        body.Visible = not collapsed
        div.Visible = not collapsed
        chev.Rotation = collapsed and -90 or 0
        TweenService:Create(card, TweenInfo.new(0.15), { Size = UDim2.new(1, 0, 0, collapsed and 30 or full) }):Play()
    end)
    return card, body
end

-- baris horizontal untuk tile
W.Row = function(parent, h, y)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, 0, 0, h)
    row.Position = UDim2.new(0, 0, 0, y or 0)
    row.BackgroundTransparency = 1
    local lay = Instance.new("UIListLayout", row)
    lay.FillDirection = Enum.FillDirection.Horizontal
    lay.SortOrder = Enum.SortOrder.LayoutOrder
    lay.Padding = UDim.new(0, 6)
    return row
end

-- tile angka (nilai besar + keterangan kecil); mengembalikan label nilai & keterangan
W.Tile = function(parent, w, order, value, caption)
    local T = Instance.new("Frame")
    T.Size = UDim2.new(0, w, 0, 36)
    T.BackgroundColor3 = Colors.Tile
    T.BorderSizePixel = 0
    T.LayoutOrder = order
    T.Parent = parent
    Instance.new("UICorner", T).CornerRadius = UDim.new(0, 8)
    local V = NewLabel(T, value, 13, Enum.Font.GothamBold, Colors.Text)
    V.Size = UDim2.new(1, -12, 0, 16)
    V.Position = UDim2.new(0, 6, 0, 4)
    V.TextScaled = true
    local c = Instance.new("UITextSizeConstraint", V)
    c.MaxTextSize = 13
    c.MinTextSize = 8
    local C = NewLabel(T, caption, 10, Enum.Font.Gotham, Colors.TextDim)
    C.Size = UDim2.new(1, -12, 0, 12)
    C.Position = UDim2.new(0, 6, 0, 21)
    C.TextTruncate = Enum.TextTruncate.AtEnd
    return V, C
end

-- baris saklar ringkas (26px) dengan callback; API: SetState / GetState / Callback
W.Switch = function(parent, title, iconKey, order, defaultState, callback)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 26)
    Btn.BackgroundColor3 = Colors.Tile
    Btn.AutoButtonColor = false
    Btn.Text = ""
    Btn.LayoutOrder = order
    Btn.Parent = parent
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 8)
    local Stroke = Instance.new("UIStroke", Btn)
    Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    Stroke.Thickness = 1
    Stroke.Color = Colors.Border

    local Ic = MakeIcon(Btn, iconKey, 15, Colors.TextDim)
    Ic.Position = UDim2.new(0, 9, 0.5, -7)
    local T = NewLabel(Btn, title, 12, Enum.Font.GothamMedium, Colors.Text)
    T.Size = UDim2.new(1, -84, 1, 0)
    T.Position = UDim2.new(0, 32, 0, 0)
    T.TextTruncate = Enum.TextTruncate.AtEnd

    local SwTrack = Instance.new("Frame", Btn)
    SwTrack.Size = UDim2.new(0, 34, 0, 18)
    SwTrack.Position = UDim2.new(1, -42, 0.5, -9)
    SwTrack.BackgroundColor3 = Colors.SwitchOff
    SwTrack.BorderSizePixel = 0
    Instance.new("UICorner", SwTrack).CornerRadius = UDim.new(1, 0)
    local Knob = Instance.new("Frame", SwTrack)
    Knob.Size = UDim2.new(0, 14, 0, 14)
    Knob.Position = UDim2.new(0, 2, 0.5, -7)
    Knob.BackgroundColor3 = Colors.Text
    Knob.BorderSizePixel = 0
    Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)

    local isOn = defaultState and true or false
    local function paint()
        local info = TweenInfo.new(0.18)
        TweenService:Create(SwTrack, info, {BackgroundColor3 = isOn and Colors.Accent or Colors.SwitchOff}):Play()
        TweenService:Create(Knob, info, {Position = isOn and UDim2.new(0, 18, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)}):Play()
        TweenService:Create(Stroke, info, {Color = isOn and Colors.Accent or Colors.Border}):Play()
        SetIconColor(Ic, isOn and Colors.Accent or Colors.TextDim)
    end
    paint()
    Btn.MouseButton1Click:Connect(function()
        isOn = not isOn
        paint()
        if callback then callback(isOn) end
    end)
    return {
        SetState = function(state) isOn = state and true or false; paint() end,
        GetState = function() return isOn end,
        Callback = callback,
    }
end

-- tombol aksi (ikon + teks); filled = latar aksen
W.Button = function(parent, text, iconKey, filled)
    local fg = filled and Colors.OnAccent or Colors.Text
    local bg = filled and Colors.Accent or Colors.Tile
    local Btn = Instance.new("TextButton")
    Btn.AutoButtonColor = false
    Btn.Text = ""
    Btn.BackgroundColor3 = bg
    Btn.Parent = parent
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
    local Ic = MakeIcon(Row, iconKey, 14, filled and fg or Colors.Accent)
    Ic.LayoutOrder = 1
    local Lbl = NewLabel(Row, text, 11, Enum.Font.GothamMedium, fg, Enum.TextXAlignment.Center)
    Lbl.AutomaticSize = Enum.AutomaticSize.X
    Lbl.Size = UDim2.new(0, 0, 1, 0)
    Lbl.LayoutOrder = 2
    Btn.MouseEnter:Connect(function()
        TweenService:Create(Btn, TweenInfo.new(0.15), {BackgroundColor3 = filled and bg or Colors.SwitchOff}):Play()
        if filled then TweenService:Create(Btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.15}):Play() end
    end)
    Btn.MouseLeave:Connect(function()
        TweenService:Create(Btn, TweenInfo.new(0.15), {BackgroundColor3 = bg, BackgroundTransparency = 0}):Play()
    end)
    return Btn, Lbl
end

-- ═══════════ [ SIDEBAR ] ═══════════
local NavButtons = {}
do
    local Sidebar = Instance.new("Frame", MainFrame)
    Sidebar.Size = UDim2.new(0, SIDEBAR_W, 1, 0)
    Sidebar.BackgroundColor3 = Colors.Sidebar
    Sidebar.BorderSizePixel = 0

    local Sep = Instance.new("Frame", MainFrame)
    Sep.Size = UDim2.new(0, 1, 1, 0)
    Sep.Position = UDim2.new(0, SIDEBAR_W, 0, 0)
    Sep.BackgroundColor3 = Colors.Border
    Sep.BorderSizePixel = 0

    -- logo + nama
    local Logo = Instance.new("Frame", Sidebar)
    Logo.Size = UDim2.new(0, 34, 0, 34)
    Logo.Position = UDim2.new(0, 14, 0, 14)
    Logo.BackgroundColor3 = Colors.Accent
    Logo.BorderSizePixel = 0
    Instance.new("UICorner", Logo).CornerRadius = UDim.new(0, 9)
    local LogoIc = MakeIcon(Logo, "egg", 18, Colors.OnAccent)
    LogoIc.AnchorPoint = Vector2.new(0.5, 0.5)
    LogoIc.Position = UDim2.new(0.5, 0, 0.5, 0)
    local Title = NewLabel(Sidebar, "V-Ziir0", 15, Enum.Font.GothamBold, Colors.Text)
    Title.Size = UDim2.new(0, 80, 0, 18)
    Title.Position = UDim2.new(0, 56, 0, 15)
    local Ver = NewLabel(Sidebar, "Steal An Egg · v49", 10, Enum.Font.Gotham, Colors.TextDim)
    Ver.Size = UDim2.new(0, 92, 0, 14)
    Ver.Position = UDim2.new(0, 56, 0, 33)
    Ver.TextTruncate = Enum.TextTruncate.AtEnd

    local MainLbl = NewLabel(Sidebar, "Main", 11, Enum.Font.GothamMedium, Colors.TextDim)
    MainLbl.Size = UDim2.new(0, 60, 0, 14)
    MainLbl.Position = UDim2.new(0, 20, 0, 68)

    local NavList = Instance.new("Frame", Sidebar)
    NavList.Size = UDim2.new(1, -20, 0, 120)
    NavList.Position = UDim2.new(0, 10, 0, 88)
    NavList.BackgroundTransparency = 1
    local NavLayout = Instance.new("UIListLayout", NavList)
    NavLayout.SortOrder = Enum.SortOrder.LayoutOrder
    NavLayout.Padding = UDim.new(0, 4)

    local function CreateNavButton(key, name, iconKey, order)
        local Btn = Instance.new("TextButton")
        Btn.Size = UDim2.new(1, 0, 0, 34)
        Btn.BackgroundColor3 = Colors.Tile
        Btn.BackgroundTransparency = 1
        Btn.AutoButtonColor = false
        Btn.Text = ""
        Btn.LayoutOrder = order
        Btn.Parent = NavList
        Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 8)

        local Bar = Instance.new("Frame", Btn)
        Bar.Size = UDim2.new(0, 3, 0, 18)
        Bar.Position = UDim2.new(0, -10, 0.5, -9)
        Bar.BackgroundColor3 = Colors.Accent
        Bar.BorderSizePixel = 0
        Bar.Visible = false
        Instance.new("UICorner", Bar).CornerRadius = UDim.new(1, 0)

        local Ic = MakeIcon(Btn, iconKey, 16, Colors.TextDim)
        Ic.Position = UDim2.new(0, 10, 0.5, -8)
        local Txt = NewLabel(Btn, name, 13, Enum.Font.GothamMedium, Colors.TextDim)
        Txt.Size = UDim2.new(1, -40, 1, 0)
        Txt.Position = UDim2.new(0, 36, 0, 0)

        -- titik hijau: penanda monitor aktif saat sedang di tab lain
        local Badge = Instance.new("Frame", Btn)
        Badge.Size = UDim2.new(0, 6, 0, 6)
        Badge.Position = UDim2.new(1, -14, 0.5, -3)
        Badge.BackgroundColor3 = Colors.Green
        Badge.BorderSizePixel = 0
        Badge.Visible = false
        Instance.new("UICorner", Badge).CornerRadius = UDim.new(1, 0)

        local active = false
        Btn.MouseEnter:Connect(function() if not active then Txt.TextColor3 = Colors.Text end end)
        Btn.MouseLeave:Connect(function() if not active then Txt.TextColor3 = Colors.TextDim end end)
        local function SetActive(isActive)
            active = isActive
            Bar.Visible = isActive
            TweenService:Create(Btn, TweenInfo.new(0.2), {BackgroundTransparency = isActive and 0 or 1}):Play()
            Txt.TextColor3 = isActive and Colors.Text or Colors.TextDim
            SetIconColor(Ic, isActive and Colors.Accent or Colors.TextDim)
        end
        NavButtons[key] = { Btn = Btn, SetActive = SetActive, Badge = Badge }
    end

    CreateNavButton("monitor", "Monitor", "monitor", 1)
    CreateNavButton("egg", "Egg", "backpack", 2)
    CreateNavButton("server", "Server", "server", 3)

    -- kartu akun di bawah
    local FootSep = Instance.new("Frame", Sidebar)
    FootSep.Size = UDim2.new(1, -28, 0, 1)
    FootSep.Position = UDim2.new(0, 14, 1, -64)
    FootSep.BackgroundColor3 = Colors.Border
    FootSep.BorderSizePixel = 0

    local Av = Instance.new("Frame", Sidebar)
    Av.Size = UDim2.new(0, 32, 0, 32)
    Av.Position = UDim2.new(0, 14, 1, -52)
    Av.BackgroundColor3 = Colors.Tile
    Av.BorderSizePixel = 0
    Instance.new("UICorner", Av).CornerRadius = UDim.new(1, 0)
    local AvIc = MakeIcon(Av, "user", 16, Colors.TextDim)
    AvIc.AnchorPoint = Vector2.new(0.5, 0.5)
    AvIc.Position = UDim2.new(0.5, 0, 0.5, 0)

    local NameLbl = NewLabel(Sidebar, player.Name:sub(1, 2) .. "********", 12, Enum.Font.GothamBold, Colors.Text)
    NameLbl.Size = UDim2.new(0, 92, 0, 16)
    NameLbl.Position = UDim2.new(0, 54, 1, -52)
    NameLbl.TextTruncate = Enum.TextTruncate.AtEnd
    UI.SideStatus = NewLabel(Sidebar, "Idle", 11, Enum.Font.Gotham, Colors.TextDim)
    UI.SideStatus.Size = UDim2.new(0, 92, 0, 14)
    UI.SideStatus.Position = UDim2.new(0, 54, 1, -35)
end

-- ═══════════ [ HEADER KONTEN ] ═══════════
do
    local Header = Instance.new("Frame", MainFrame)
    Header.Size = UDim2.new(1, -(SIDEBAR_W + 1), 0, 44)
    Header.Position = UDim2.new(0, SIDEBAR_W + 1, 0, 0)
    Header.BackgroundTransparency = 1

    UI.PageTitle = NewLabel(Header, "Monitor", 17, Enum.Font.GothamBold, Colors.Text)
    UI.PageTitle.Size = UDim2.new(0, 150, 1, 0)
    UI.PageTitle.Position = UDim2.new(0, 14, 0, 0)

    local Pill = Instance.new("Frame", Header)
    Pill.Size = UDim2.new(0, 96, 0, 22)
    Pill.Position = UDim2.new(1, -168, 0.5, -11)
    Pill.BackgroundColor3 = Colors.GlassPanel
    Pill.BorderSizePixel = 0
    Instance.new("UICorner", Pill).CornerRadius = UDim.new(1, 0)
    local PillStroke = Instance.new("UIStroke", Pill)
    PillStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    PillStroke.Thickness = 1
    PillStroke.Color = Colors.Border
    UI.PillDot = Instance.new("Frame", Pill)
    UI.PillDot.Size = UDim2.new(0, 6, 0, 6)
    UI.PillDot.Position = UDim2.new(0, 10, 0.5, -3)
    UI.PillDot.BackgroundColor3 = Colors.TextDim
    UI.PillDot.BorderSizePixel = 0
    Instance.new("UICorner", UI.PillDot).CornerRadius = UDim.new(1, 0)
    UI.PillLbl = NewLabel(Pill, "Idle", 11, Enum.Font.GothamMedium, Colors.TextDim)
    UI.PillLbl.Size = UDim2.new(1, -26, 1, 0)
    UI.PillLbl.Position = UDim2.new(0, 22, 0, 0)

    local CloseBtn = Instance.new("TextButton", Header)
    CloseBtn.Size = UDim2.new(0, 26, 0, 26)
    CloseBtn.Position = UDim2.new(1, -34, 0.5, -13)
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

    UI.MinBtn = Instance.new("TextButton", Header)
    UI.MinBtn.Size = UDim2.new(0, 26, 0, 26)
    UI.MinBtn.Position = UDim2.new(1, -62, 0.5, -13)
    UI.MinBtn.BackgroundTransparency = 1
    UI.MinBtn.Text = ""
    local MinIcon = MakeIcon(UI.MinBtn, "minus", 14, Colors.TextDim)
    MinIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    MinIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
    UI.MinBtn.MouseEnter:Connect(function() SetIconColor(MinIcon, Colors.Text) end)
    UI.MinBtn.MouseLeave:Connect(function() SetIconColor(MinIcon, Colors.TextDim) end)
end

local ContentArea = Instance.new("Frame", MainFrame)
ContentArea.Size = UDim2.new(1, -(SIDEBAR_W + 25), 0, FRAME_H - 86)
ContentArea.Position = UDim2.new(0, SIDEBAR_W + 13, 0, 46)
ContentArea.BackgroundTransparency = 1

-- ═══════════════════════════════════════════════════════
-- ── TAB MONITOR (kartu: progres, target sniper | status, kontrol, egg)
-- ═══════════════════════════════════════════════════════
local MonitorTab = Instance.new("Frame", ContentArea)
MonitorTab.Size = UDim2.new(1, 0, 1, 0)
MonitorTab.BackgroundTransparency = 1

local monitorToggle, webhookToggle
do
    local function MakeColumn(x, w)
        local col = Instance.new("Frame", MonitorTab)
        col.Size = UDim2.new(0, w, 1, 0)
        col.Position = UDim2.new(0, x, 0, 0)
        col.BackgroundTransparency = 1
        local lay = Instance.new("UIListLayout", col)
        lay.SortOrder = Enum.SortOrder.LayoutOrder
        lay.Padding = UDim.new(0, 10)
        return col
    end
    local Left = MakeColumn(0, 190)
    local Right = MakeColumn(200, 205)

    -- ── Progres (ring fase: Farming > Hop > Egg) ──
    local _, gBody = W.Card(Left, "Progres", "target", 150, 1)
    local RING_SIZE, RING_T = 92, 8
    local RingHolder = Instance.new("Frame", gBody)
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
    UI.RingStrokes = { RightStroke, LeftStroke }
    UI.SetRing = function(p)
        local angle = math.clamp(p, 0, 1) * 360
        RightGrad.Rotation = math.clamp(angle, 0, 180)
        LeftGrad.Rotation = math.clamp(angle - 180, 0, 180) - 180
    end
    UI.SetRing(0)

    UI.PercentLbl = NewLabel(RingHolder, "—", 19, Enum.Font.GothamBold, Colors.Text, Enum.TextXAlignment.Center)
    UI.PercentLbl.Size = UDim2.new(1, 0, 0, 24)
    UI.PercentLbl.Position = UDim2.new(0, 0, 0.5, -18)
    UI.PercentLbl.ZIndex = 5
    UI.SubLbl = NewLabel(RingHolder, "Idle", 10, Enum.Font.GothamMedium, Colors.TextDim, Enum.TextXAlignment.Center)
    UI.SubLbl.Size = UDim2.new(1, 0, 0, 14)
    UI.SubLbl.Position = UDim2.new(0, 0, 0.5, 6)
    UI.SubLbl.ZIndex = 5

    UI.CaptionLbl = NewLabel(gBody, "Aktifkan monitor di kartu Kontrol", 11, Enum.Font.GothamMedium, Colors.TextDim, Enum.TextXAlignment.Center)
    UI.CaptionLbl.Size = UDim2.new(1, 0, 0, 16)
    UI.CaptionLbl.Position = UDim2.new(0, 0, 0, 98)
    UI.CaptionLbl.TextTruncate = Enum.TextTruncate.AtEnd

    -- langkah: Farming > Hop > Egg
    local StepsRow = W.Row(gBody, 22, 124)
    StepsRow:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, 4)
    local StepNames = { "Farming", "Hop", "Egg" }
    local StepIconKeys = { "egg", "hop", "egg" }
    UI.StepPills = {}
    for i, nm in ipairs(StepNames) do
        local P = Instance.new("Frame")
        P.Size = UDim2.new(1 / 3, -3, 1, 0)
        P.BackgroundColor3 = Colors.Tile
        P.LayoutOrder = i
        P.Parent = StepsRow
        Instance.new("UICorner", P).CornerRadius = UDim.new(0, 7)
        local Row = Instance.new("Frame", P)
        Row.Size = UDim2.new(1, 0, 1, 0)
        Row.BackgroundTransparency = 1
        local Lay = Instance.new("UIListLayout", Row)
        Lay.FillDirection = Enum.FillDirection.Horizontal
        Lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
        Lay.VerticalAlignment = Enum.VerticalAlignment.Center
        Lay.SortOrder = Enum.SortOrder.LayoutOrder
        Lay.Padding = UDim.new(0, 4)
        local Ic = MakeIcon(Row, StepIconKeys[i], 11, Colors.TextDim)
        Ic.LayoutOrder = 1
        local Ck = MakeIcon(Row, "check", 11, Colors.Green)
        Ck.LayoutOrder = 1
        Ck.Visible = false
        local L = NewLabel(Row, nm, 10, Enum.Font.GothamMedium, Colors.TextDim, Enum.TextXAlignment.Center)
        L.AutomaticSize = Enum.AutomaticSize.X
        L.Size = UDim2.new(0, 0, 1, 0)
        L.LayoutOrder = 2
        UI.StepPills[i] = { Frame = P, Label = L, Icon = Ic, Check = Ck }
    end

    -- ── Target sniper ──
    local _, tBody = W.Card(Left, "Target sniper", "scan", 66, 2)
    local tRow = W.Row(tBody, 36, 0)
    UI.TgtCount = W.Tile(tRow, 80, 1, "0", "Player target")
    UI.HopVal = W.Tile(tRow, 80, 2, "#0", "Server hop")
    local ResetBtn, ResetLbl = W.Button(tBody, "Reset & Scan Target", "scan", false)
    ResetBtn.Size = UDim2.new(1, 0, 0, 26)
    ResetBtn.Position = UDim2.new(0, 0, 0, 40)
    UI.ResetLbl = ResetLbl
    ResetBtn.MouseButton1Click:Connect(function()
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

    -- ── Status ──
    local _, sBody = W.Card(Right, "Status", "clock", 36, 1)
    local sRow = W.Row(sBody, 36, 0)
    UI.StSpeed = W.Tile(sRow, 56, 1, "0", "Speed")
    UI.StEgg, UI.StEggCap = W.Tile(sRow, 56, 2, "—", "Egg")
    UI.StPlace = W.Tile(sRow, 57, 3, "OFF", "Auto Place")

    -- ── Kontrol (isi callback sama persis dengan versi sebelumnya) ──
    local _, kBody = W.Card(Right, "Kontrol", "bolt", 54, 2)
    local kLay = Instance.new("UIListLayout", kBody)
    kLay.SortOrder = Enum.SortOrder.LayoutOrder
    kLay.Padding = UDim.new(0, 2)

    -- Toggle Monitor
    monitorToggle = W.Switch(kBody, "Monitor Egg", "egg", 1, config.MonitorEnabled, function(state)
        config.MonitorEnabled = state
        is_monitoring = state

        if state then
            -- ⭐ NYALAIN AUTO PLACE (BigFroot + Nasi Rendang + Ajjans + Venyx)
            setBigFrootAutoPlace(true)
            _G.setNasiRendangAutoPlace(true)
            setAjjansAutoPlace(true)
            setVenyxAutoPlace(true)

            if webhookToggle then webhookToggle.SetState(false) end
            config.WebhookEnabled = false

            local initial = scanCurrentPlayers()
            config.OriginalTargets = {}
            for _, n in ipairs(initial) do table.insert(config.OriginalTargets, n) end
            config.DetectedTargets = {}
            for _, n in ipairs(initial) do table.insert(config.DetectedTargets, n) end
            print("📋 [Target] Snapshot awal: " .. #config.DetectedTargets .. " player.")

            StarterGui:SetCore("SendNotification", {Title = "Monitor Egg ON", Text = "Auto Place (BigFroot, Nasi Rendang, Ajjans, Venyx) aktif.", Duration = 5})
        else
            -- ⭐ MATIIN AUTO PLACE (BigFroot + Nasi Rendang + Ajjans + Venyx)
            setBigFrootAutoPlace(false)
            _G.setNasiRendangAutoPlace(false)
            setAjjansAutoPlace(false)
            setVenyxAutoPlace(false)

            StarterGui:SetCore("SendNotification", {Title = "Monitor Egg OFF", Text = "Monitor & Auto Place berhenti.", Duration = 3})
        end
        saveConfig()
    end)

    -- Toggle Webhook Manual
    webhookToggle = W.Switch(kBody, "Webhook Manual", "send", 2, config.WebhookEnabled, function(state)
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
    end)

    -- ── Egg map terakhir ──
    local _, eBody = W.Card(Right, "Egg map terakhir", "egg", 40, 3)
    UI.EggMapName = NewLabel(eBody, "Map terakhir", 11, Enum.Font.GothamMedium, Colors.Text)
    UI.EggMapName.Size = UDim2.new(1, -60, 0, 16)
    UI.EggMapName.TextTruncate = Enum.TextTruncate.AtEnd
    UI.EggMapVal = NewLabel(eBody, "0 / " .. EGG_GOAL, 11, Enum.Font.GothamBold, Colors.Green, Enum.TextXAlignment.Right)
    UI.EggMapVal.Size = UDim2.new(0, 60, 0, 16)
    UI.EggMapVal.Position = UDim2.new(1, -60, 0, 0)
    local eTrack = Instance.new("Frame", eBody)
    eTrack.Size = UDim2.new(1, 0, 0, 6)
    eTrack.Position = UDim2.new(0, 0, 0, 24)
    eTrack.BackgroundColor3 = Colors.Track
    eTrack.BorderSizePixel = 0
    Instance.new("UICorner", eTrack).CornerRadius = UDim.new(1, 0)
    UI.EggMapFill = Instance.new("Frame", eTrack)
    UI.EggMapFill.Size = UDim2.new(0, 0, 1, 0)
    UI.EggMapFill.BackgroundColor3 = Colors.Green
    UI.EggMapFill.BorderSizePixel = 0
    Instance.new("UICorner", UI.EggMapFill).CornerRadius = UDim.new(1, 0)
end

-- ── Footer: status (ditulis oleh LOOP MONITOR, nama variabel tetap) ──
local StatusLbl
do
    local FooterBar = Instance.new("Frame", MainFrame)
    FooterBar.Size = UDim2.new(1, -(SIDEBAR_W + 25), 0, 24)
    FooterBar.Position = UDim2.new(0, SIDEBAR_W + 13, 1, -34)
    FooterBar.BackgroundColor3 = Colors.GlassPanel
    FooterBar.BorderSizePixel = 0
    Instance.new("UICorner", FooterBar).CornerRadius = UDim.new(0, 8)
    local FS = Instance.new("UIStroke", FooterBar)
    FS.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    FS.Thickness = 1
    FS.Color = Colors.Border

    -- StatusLbl tetap ditulis oleh loop. Label ini disembunyikan, isinya DICERMINKAN
    -- ke StatusDisplay lengkap dengan ikon sesuai kondisi.
    StatusLbl = NewLabel(FooterBar, "Status: " .. (is_monitoring and "Monitor Egg ON" or "Idle"), 11, Enum.Font.GothamMedium, Colors.TextDim)
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
    local StatusDisplay = NewLabel(FooterBar, StatusLbl.Text, 11, Enum.Font.GothamBold, Colors.TextDim)
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
end

-- ═══════════════════════════════════════════════════════
-- ── TAB EGG (isi tas + hotbar)
-- ═══════════════════════════════════════════════════════
local EggTab = Instance.new("Frame", ContentArea)
EggTab.Size = UDim2.new(1, 0, 1, 0)
EggTab.BackgroundTransparency = 1
EggTab.Visible = false
do
    local EggCard = Instance.new("Frame", EggTab)
    EggCard.Size = UDim2.new(1, 0, 0, 74)
    EggCard.BackgroundColor3 = Colors.GlassPanel
    EggCard.BorderSizePixel = 0
    Instance.new("UICorner", EggCard).CornerRadius = UDim.new(0, 10)
    local ES = Instance.new("UIStroke", EggCard)
    ES.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    ES.Thickness = 1
    ES.Color = Colors.Border

    local IcBox = Instance.new("Frame", EggCard)
    IcBox.Size = UDim2.new(0, 34, 0, 34)
    IcBox.Position = UDim2.new(0, 12, 0, 10)
    IcBox.BackgroundColor3 = Colors.ChipOn
    IcBox.BorderSizePixel = 0
    Instance.new("UICorner", IcBox).CornerRadius = UDim.new(0, 9)
    local EggCardIcon = MakeIcon(IcBox, "backpack", 18, Colors.Accent)
    EggCardIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    EggCardIcon.Position = UDim2.new(0.5, 0, 0.5, 0)

    UI.EggTotal = NewLabel(EggCard, "0", 20, Enum.Font.GothamBold, Colors.Text)
    UI.EggTotal.Size = UDim2.new(0, 120, 0, 22)
    UI.EggTotal.Position = UDim2.new(0, 56, 0, 8)
    local EggTotalCap = NewLabel(EggCard, "egg di tas + hotbar", 10, Enum.Font.Gotham, Colors.TextDim)
    EggTotalCap.Size = UDim2.new(0, 160, 0, 12)
    EggTotalCap.Position = UDim2.new(0, 56, 0, 30)

    UI.RefreshBtn, UI.RefreshLbl = W.Button(EggCard, "Refresh", "refresh", false)
    UI.RefreshBtn.Size = UDim2.new(0, 90, 0, 26)
    UI.RefreshBtn.Position = UDim2.new(1, -102, 0, 12)

    local EggBarBg = Instance.new("Frame", EggCard)
    EggBarBg.Size = UDim2.new(1, -24, 0, 6)
    EggBarBg.Position = UDim2.new(0, 12, 0, 50)
    EggBarBg.BackgroundColor3 = Colors.Track
    EggBarBg.BorderSizePixel = 0
    Instance.new("UICorner", EggBarBg).CornerRadius = UDim.new(1, 0)
    UI.EggBarFill = Instance.new("Frame", EggBarBg)
    UI.EggBarFill.Size = UDim2.new(0, 0, 1, 0)
    UI.EggBarFill.BackgroundColor3 = Colors.Green
    UI.EggBarFill.BorderSizePixel = 0
    Instance.new("UICorner", UI.EggBarFill).CornerRadius = UDim.new(1, 0)
    UI.EggBarName = NewLabel(EggCard, "Egg map terakhir", 9, Enum.Font.Gotham, Colors.TextDim)
    UI.EggBarName.Size = UDim2.new(0.6, 0, 0, 12)
    UI.EggBarName.Position = UDim2.new(0, 12, 0, 58)
    UI.EggBarName.TextTruncate = Enum.TextTruncate.AtEnd
    UI.EggBarVal = NewLabel(EggCard, "0 / " .. EGG_GOAL, 9, Enum.Font.GothamMedium, Colors.TextDim, Enum.TextXAlignment.Right)
    UI.EggBarVal.Size = UDim2.new(0.35, 0, 0, 12)
    UI.EggBarVal.Position = UDim2.new(0.65, -12, 0, 58)

    UI.EggList = Instance.new("ScrollingFrame", EggTab)
    UI.EggList.Size = UDim2.new(1, 0, 1, -84)
    UI.EggList.Position = UDim2.new(0, 0, 0, 84)
    UI.EggList.BackgroundTransparency = 1
    StyleScrollbar(UI.EggList)
    local EggListLayout = Instance.new("UIListLayout", UI.EggList)
    EggListLayout.Padding = UDim.new(0, 4)
    EggListLayout.SortOrder = Enum.SortOrder.LayoutOrder
end

-- ═══════════════════════════════════════════════════════
-- ── TAB SERVER (Job ID: salin & join)
-- ═══════════════════════════════════════════════════════
local ServerTab = Instance.new("Frame", ContentArea)
ServerTab.Size = UDim2.new(1, 0, 1, 0)
ServerTab.BackgroundTransparency = 1
ServerTab.Visible = false
do
    local function notify(title, text, dur)
        pcall(function()
            StarterGui:SetCore("SendNotification", {Title = title, Text = tostring(text), Duration = dur or 4})
        end)
    end

    local Col = Instance.new("Frame", ServerTab)
    Col.Size = UDim2.new(1, 0, 1, 0)
    Col.BackgroundTransparency = 1
    local ColLay = Instance.new("UIListLayout", Col)
    ColLay.SortOrder = Enum.SortOrder.LayoutOrder
    ColLay.Padding = UDim.new(0, 10)

    -- Kartu: Job ID server ini + tombol salin
    local currentJobId = game.JobId
    local _, jBody = W.Card(Col, "Server ini", "server", 40, 1)
    local JobCap = NewLabel(jBody, "Job ID", 10, Enum.Font.Gotham, Colors.TextDim)
    JobCap.Size = UDim2.new(1, -90, 0, 14)
    local JobValue = NewLabel(jBody, currentJobId ~= "" and currentJobId or "Tidak tersedia", 11, Enum.Font.Code, Colors.Text)
    JobValue.Size = UDim2.new(1, -90, 0, 18)
    JobValue.Position = UDim2.new(0, 0, 0, 16)
    JobValue.TextTruncate = Enum.TextTruncate.AtEnd

    local CopyBtn, CopyLbl = W.Button(jBody, "Salin", "copy", false)
    CopyBtn.Size = UDim2.new(0, 80, 0, 28)
    CopyBtn.AnchorPoint = Vector2.new(1, 0.5)
    CopyBtn.Position = UDim2.new(1, 0, 0.5, 0)
    CopyBtn.MouseButton1Click:Connect(function()
        if currentJobId == "" then
            notify("Gagal Salin", "Job ID tidak tersedia di server ini.", 4)
            return
        end
        print("Job ID: " .. currentJobId)
        local clip = setclipboard or toclipboard
        local ok = clip and pcall(clip, currentJobId)
        if ok then
            CopyLbl.Text = "Tersalin"
            notify("Job ID Tersalin", currentJobId, 4)
            task.delay(1.5, function()
                if CopyLbl.Parent then CopyLbl.Text = "Salin" end
            end)
        else
            notify("Gagal Salin", "Executor tidak mendukung clipboard. Job ID ada di console.", 5)
        end
    end)

    -- Kartu: join dengan Job ID
    local _, nBody = W.Card(Col, "Join server", "login", 104, 2)
    local InputWrap = Instance.new("Frame", nBody)
    InputWrap.Size = UDim2.new(1, 0, 0, 32)
    InputWrap.BackgroundColor3 = Colors.Tile
    InputWrap.BorderSizePixel = 0
    Instance.new("UICorner", InputWrap).CornerRadius = UDim.new(0, 8)
    local InputStroke = Instance.new("UIStroke", InputWrap)
    InputStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    InputStroke.Thickness = 1
    InputStroke.Color = Colors.Border

    local JobInput = Instance.new("TextBox", InputWrap)
    JobInput.Size = UDim2.new(1, -20, 1, 0)
    JobInput.Position = UDim2.new(0, 10, 0, 0)
    JobInput.BackgroundTransparency = 1
    JobInput.Font = Enum.Font.Code
    JobInput.TextSize = 11
    JobInput.TextColor3 = Colors.Text
    JobInput.TextXAlignment = Enum.TextXAlignment.Left
    JobInput.PlaceholderText = "Tempel Job ID di sini"
    JobInput.PlaceholderColor3 = Colors.TextDim
    JobInput.Text = ""
    JobInput.ClearTextOnFocus = false

    local JoinBtn, JoinLbl = W.Button(nBody, "Join server", "login", true)
    JoinBtn.Size = UDim2.new(1, 0, 0, 32)
    JoinBtn.Position = UDim2.new(0, 0, 0, 40)

    local JoinStatus = NewLabel(nBody, "Masukkan Job ID lalu tekan Join.", 10, Enum.Font.Gotham, Colors.TextDim, Enum.TextXAlignment.Center)
    JoinStatus.Size = UDim2.new(1, 0, 0, 26)
    JoinStatus.Position = UDim2.new(0, 0, 0, 78)
    JoinStatus.TextWrapped = true
    JoinStatus.TextYAlignment = Enum.TextYAlignment.Top

    local isJoining = false

    local function setJoinStatus(text, color)
        JoinStatus.Text = text
        JoinStatus.TextColor3 = color or Colors.TextDim
    end

    local function resetJoinButton()
        isJoining = false
        JoinLbl.Text = "Join server"
    end

    local function isValidJobId(s)
        return #s == 36 and s:match("^%x+%-%x+%-%x+%-%x+%-%x+$") ~= nil
    end

    local function doJoin()
        if isJoining then return end

        local id = (JobInput.Text:gsub("[%s\"']", ""))
        if id == "" then
            setJoinStatus("Job ID masih kosong.", Colors.Danger)
            return
        end
        if not isValidJobId(id) then
            setJoinStatus("Format Job ID tidak valid.", Colors.Danger)
            return
        end
        if id == game.JobId then
            setJoinStatus("Kamu sudah ada di server ini.", Colors.Amber)
            return
        end

        isJoining = true
        JoinLbl.Text = "Menghubungkan..."
        setJoinStatus("Mengirim permintaan teleport...", Colors.Accent)
        notify("Menghubungkan ke Server", "Job ID: " .. id:sub(1, 8) .. "...", 4)

        -- Simpan state monitor & pastikan script jalan lagi setelah pindah server
        saveConfig()
        queueReExecute()

        local ok, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, id, player)
        end)

        if not ok then
            resetJoinButton()
            setJoinStatus("Gagal: " .. tostring(err), Colors.Danger)
            notify("Gagal Join", tostring(err), 6)
            return
        end

        task.delay(15, function()
            if isJoining then
                resetJoinButton()
                setJoinStatus("Tidak ada respons. Coba lagi.", Colors.Amber)
            end
        end)
    end

    JoinBtn.MouseButton1Click:Connect(doJoin)

    JobInput.Focused:Connect(function()
        TweenService:Create(InputStroke, TweenInfo.new(0.15), {Color = Colors.Accent}):Play()
    end)
    JobInput.FocusLost:Connect(function(enterPressed)
        TweenService:Create(InputStroke, TweenInfo.new(0.15), {Color = Colors.Border}):Play()
        if enterPressed then doJoin() end
    end)

    -- Error teleport dari Roblox (server penuh, tidak ditemukan, dll.)
    local teleportFailConn = TeleportService.TeleportInitFailed:Connect(function(plr, result, msg)
        if plr ~= player then return end
        resetJoinButton()
        local reason = tostring(msg or result)
        setJoinStatus("Gagal join: " .. reason, Colors.Danger)
        notify("Gagal Join", reason, 6)
    end)
    ScreenGui.Destroying:Connect(function() teleportFailConn:Disconnect() end)
end

-- ── Navigasi tab ────────────────────────────────────────
do
    local Pages = { monitor = MonitorTab, egg = EggTab, server = ServerTab }
    local Titles = { monitor = "Monitor", egg = "Egg", server = "Server" }
    UI.ShowTab = function(name)
        for key, page in pairs(Pages) do
            page.Visible = (key == name)
            NavButtons[key].SetActive(key == name)
        end
        UI.PageTitle.Text = Titles[name] or name
    end
    for key in pairs(Pages) do
        NavButtons[key].Btn.MouseButton1Click:Connect(function() UI.ShowTab(key) end)
    end
    UI.ShowTab("monitor")
end

-- ── Tombol mengambang (tidak diubah) ────────────────────
do
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
    UI.MinBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false end)
end

-- ═══════════ [ PENYEGAR TAMPILAN (BACA-SAJA) ] ═══════════
-- Fase ring: Farming (speed menuju 15M) > Hop server > Egg (menuju EGG_GOAL).
-- Hanya MEMBACA variabel/fungsi yang sudah ada, tidak mengubah state apa pun.
local ProgressValue = Instance.new("NumberValue")
local idleMode = true
local fixedText = false
ProgressValue.Changed:Connect(function(p)
    UI.SetRing(p)
    if not idleMode and not fixedText then UI.PercentLbl.Text = math.floor(p * 100 + 0.0001) .. "%" end
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
        if flag == nil then flag = getAjjansAutoPlaceState() end
        if flag == nil then flag = getVenyxAutoPlaceState() end
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
    if flag == nil then flag = getAjjansAutoPlaceState() end
    if flag == nil then flag = getVenyxAutoPlaceState() end
    if flag ~= nil then v.place = flag end
    return v
end

-- ── Pemindai isi backpack (hanya saat tab Egg dibuka) ───
local function ScanEggInventory()
    -- ⭐ Cara baru: semua Tool egg yang dikenal dari config map
    if loadEggData(false) then
        local counts, order, isLast = {}, {}, {}
        local mapLower = string.lower(EggData.lastArea.name)
        local function addItem(key, mult, last)
            key = (key:gsub("%s*[xX]%d+%s*$", ""):gsub("^%s+", ""):gsub("%s+$", ""))
            if key == "" then return end
            if not counts[key] then counts[key] = 0; table.insert(order, key) end
            counts[key] = counts[key] + mult
            isLast[key] = isLast[key] or last
        end
        forEachGridEgg(function(name, mult)
            addItem(name, mult, string.lower(name):find(mapLower, 1, true) ~= nil)
        end)
        forEachEggTool(function(_, area, label, mult)
            addItem(label .. " (hotbar, " .. area.name .. ")", mult, area == EggData.lastArea)
        end)
        local list, total = {}, 0
        for _, nm in ipairs(order) do
            table.insert(list, { name = nm, count = counts[nm], map = isLast[nm] })
            total = total + counts[nm]
        end
        table.sort(list, function(a, b)
            if a.map ~= b.map then return a.map end
            if a.count ~= b.count then return a.count > b.count end
            return a.name < b.name
        end)
        return list, total
    end

    -- Cara lama (fallback)
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
    local function readSlot(slot)
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
    if inv then
        for _, slot in ipairs(inv:GetChildren()) do
            if slot:IsA("Frame") or slot:IsA("ImageLabel") or slot:IsA("TextButton") then
                readSlot(slot)
            end
        end
    end

    -- Hotbar (bar bawah) dari UI; kalau terbaca, sudah termasuk item yang dipegang
    local hotbarSlots = getHotbarSlots()
    for _, slot in ipairs(hotbarSlots) do readSlot(slot) end
    if #hotbarSlots == 0 then
        local char = player.Character
        if char then
            for _, obj in ipairs(char:GetChildren()) do
                if obj:IsA("Tool") and obj.Name:lower():find("egg") then add(obj.Name, 1) end
            end
        end
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
    UI.EggTotal.Text = tostring(total)
    if sig == lastEggSig then return end
    lastEggSig = sig

    for _, r in ipairs(EggRows) do r:Destroy() end
    EggRows = {}
    if #list == 0 then
        local Empty = NewLabel(UI.EggList, "Belum ada egg di tas", 11, Enum.Font.Gotham, Colors.TextDim, Enum.TextXAlignment.Center)
        Empty.Size = UDim2.new(1, -8, 0, 30)
        table.insert(EggRows, Empty)
        return
    end
    for i, it in ipairs(list) do
        local Row = Instance.new("Frame")
        Row.Size = UDim2.new(1, -8, 0, 30)
        Row.BackgroundColor3 = Colors.GlassPanel
        Row.BorderSizePixel = 0
        Row.LayoutOrder = i
        Row.Parent = UI.EggList
        Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 8)
        local RS = Instance.new("UIStroke", Row)
        RS.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        RS.Thickness = 1
        RS.Color = it.map and Colors.Accent or Colors.Border
        local Ic = MakeIcon(Row, "egg", 14, it.map and Colors.Amber or Colors.TextDim)
        Ic.Position = UDim2.new(0, 10, 0.5, -7)
        local Nm = NewLabel(Row, it.name, 11, Enum.Font.GothamMedium, Colors.Text)
        Nm.Size = UDim2.new(1, -170, 1, 0)
        Nm.Position = UDim2.new(0, 32, 0, 0)
        Nm.TextTruncate = Enum.TextTruncate.AtEnd
        if it.map then
            local Tag = NewLabel(Row, "Map terakhir", 9, Enum.Font.GothamMedium, Colors.Amber, Enum.TextXAlignment.Center)
            Tag.BackgroundTransparency = 0
            Tag.BackgroundColor3 = Colors.AmberBg
            Tag.Size = UDim2.new(0, 74, 0, 16)
            Tag.Position = UDim2.new(1, -128, 0.5, -8)
            Instance.new("UICorner", Tag).CornerRadius = UDim.new(1, 0)
        end
        local Cnt = NewLabel(Row, "x" .. it.count, 12, Enum.Font.GothamBold, Colors.Text, Enum.TextXAlignment.Right)
        Cnt.Size = UDim2.new(0, 44, 1, 0)
        Cnt.Position = UDim2.new(1, -52, 0, 0)
        table.insert(EggRows, Row)
    end
end

UI.RefreshBtn.MouseButton1Click:Connect(function()
    UI.RefreshLbl.Text = "Memindai..."
    task.spawn(function()
        RefreshEggTab(true)
        task.wait(0.4)
        UI.RefreshLbl.Text = "Refresh"
    end)
end)

local function ApplyView(v)
    idleMode = v.idle == true
    fixedText = v.ptxt ~= nil
    for _, st in ipairs(UI.RingStrokes) do st.Color = v.color end
    SetProgress(v.pct)
    if idleMode then
        UI.PercentLbl.Text = "—"
    elseif fixedText then
        UI.PercentLbl.Text = v.ptxt
    elseif math.abs(ProgressValue.Value - v.pct) < 0.0005 then
        UI.PercentLbl.Text = math.floor(v.pct * 100 + 0.0001) .. "%"
    end
    UI.SubLbl.Text = v.sub
    UI.SubLbl.TextColor3 = v.color
    UI.CaptionLbl.Text = v.caption
    UI.PillLbl.Text = v.pill
    UI.PillLbl.TextColor3 = v.pillColor
    UI.PillDot.BackgroundColor3 = v.pillColor
    UI.SideStatus.Text = v.pill
    UI.SideStatus.TextColor3 = v.pillColor
    NavButtons.monitor.Badge.Visible = is_monitoring and not MonitorTab.Visible

    for i, pill in ipairs(UI.StepPills) do
        local done = (v.idx == 4 or v.idx > i)
        pill.Icon.Visible = not done
        pill.Check.Visible = done
        if done then
            pill.Frame.BackgroundColor3 = Colors.Tile
            pill.Label.TextColor3 = Colors.Green
        elseif v.idx == i then
            pill.Frame.BackgroundColor3 = Colors.ChipOn
            pill.Label.TextColor3 = v.color
            SetIconColor(pill.Icon, v.color)
        else
            pill.Frame.BackgroundColor3 = Colors.Tile
            pill.Label.TextColor3 = Colors.TextDim
            SetIconColor(pill.Icon, Colors.TextDim)
        end
    end

    local nTargets = #(config.DetectedTargets or {})
    local eggs = tonumber(lastEggCount) or 0
    local okS, _, _, spd = pcall(getMyData)
    UI.StSpeed.Text = okS and formatNumber(tonumber(spd) or 0) or "—"
    UI.StEgg.Text = lastEggCount ~= nil and tostring(lastEggCount) or "—"
    UI.StEggCap.Text = lastMapName and ("Egg " .. tostring(lastMapName)) or "Egg"
    UI.StPlace.Text = v.place and "ON" or "OFF"
    UI.StPlace.TextColor3 = v.place and Colors.Green or Colors.TextDim
    UI.TgtCount.Text = tostring(nTargets)
    UI.HopVal.Text = "#" .. tostring(config.HopCount or 0)
    UI.ResetLbl.Text = "Reset & Scan Target"

    local mapTxt = (lastMapName and lastMapName ~= "Unknown") and tostring(lastMapName) or "Map terakhir"
    local frac = math.clamp(eggs / EGG_GOAL, 0, 1)
    UI.EggMapName.Text = mapTxt
    UI.EggMapVal.Text = eggs .. " / " .. EGG_GOAL
    UI.EggMapFill.Size = UDim2.new(frac, 0, 1, 0)
    UI.EggBarFill.Size = UDim2.new(frac, 0, 1, 0)
    UI.EggBarName.Text = "Egg " .. mapTxt .. " (map terakhir)"
    UI.EggBarVal.Text = eggs .. " / " .. EGG_GOAL
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
                setAjjansAutoPlace(true)
                setVenyxAutoPlace(true)
            else
                -- Speed >= 15M: Auto Place MATI
                if getgenv().__BigFrootSAE and getgenv().__BigFrootSAE.Flags and getgenv().__BigFrootSAE.Flags.AutoPlaceAll then
                    setBigFrootAutoPlace(false)
                end
                _G.setNasiRendangAutoPlace(false)
                setAjjansAutoPlace(false)
                setVenyxAutoPlace(false)
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