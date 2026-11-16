-- Webby Frames: player extras. Your weapons' enchants and imbues as icons just before your buffs, and
-- your buffs as timer bars in a block of their own. Loads after WebbyFrames.lua (see the .toc), which
-- shares its helpers through ns. (Weapon imbues on Forever: an imbue is its own enchant type there,
-- so C_Item.GetWeaponEnchantInfo, which
-- lists every enchant per weapon, is read rather than the older GetWeaponEnchantInfo.)
local _, ns = ...
local getSetting, unitData, defaultTip, isSecret, frames = ns.getSetting, ns.unitData, ns.defaultTip, ns.isSecret, ns.frames

local PX = { enchants = {}, bars = {} }
ns.PlayerExtras = PX
local WHITE = "Interface\\Buttons\\WHITE8X8"

-- a value when it's there and not hidden from addons, else nil
local function readable(v)
    if v ~= nil and not isSecret(v) then return v end
end

-- "1h", "12m", "45s"
local function shortTime(s)
    if s >= 3600 then return string.format("%dh", math.floor(s / 3600 + 0.5)) end
    if s >= 60 then return string.format("%dm", math.floor(s / 60 + 0.5)) end
    return string.format("%ds", math.max(0, math.floor(s + 0.5)))
end

---------------------------------------------------------------------------
-- Weapon enchants
---------------------------------------------------------------------------
-- Every weapon's enchants with time left: { inv, icon, ends, charges }.
function PX.scanEnchants()
    local out, now = {}, GetTime()
    local WS = Enum and Enum.WeaponSlot
    if C_Item and C_Item.GetWeaponEnchantInfo and WS then
        for _, w in ipairs({ { WS.MainHand, 16 }, { WS.OffHand, 17 }, { WS.Ranged, 18 } }) do
            if w[1] then
                local ok, list = pcall(C_Item.GetWeaponEnchantInfo, w[1])
                if ok and type(list) == "table" then
                    for _, e in ipairs(list) do
                        local left = readable(e.timeLeft)
                        if readable(e.hasEnchant) and left and left > 0 then
                            local icon = readable(e.enchantIconID)
                            if not icon or icon == 0 then icon = GetInventoryItemTexture("player", w[2]) end
                            out[#out + 1] = { inv = w[2], icon = icon or 134400, ends = now + left / 1000, charges = readable(e.charges) or 0 }
                        end
                    end
                end
            end
        end
        return out
    end
    -- older clients: one enchant per hand
    local ok, mh, mhT, mhC, _, oh, ohT, ohC = pcall(GetWeaponEnchantInfo)
    if ok then
        if readable(mh) then out[#out + 1] = { inv = 16, icon = GetInventoryItemTexture("player", 16) or 134400, ends = now + (readable(mhT) or 0) / 1000, charges = readable(mhC) or 0 } end
        if readable(oh) then out[#out + 1] = { inv = 17, icon = GetInventoryItemTexture("player", 17) or 134400, ends = now + (readable(ohT) or 0) / 1000, charges = readable(ohC) or 0 } end
    end
    return out
end

-- One enchant icon (made on first use): the 1px edge, the icon, time left under it, charges on it.
function PX.makeEnchant(i)
    local b = CreateFrame("Button", nil, UIParent)
    b:SetFrameStrata("LOW")
    local back = b:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0, 0, 0, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.time = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.time:SetPoint("TOP", b, "BOTTOM", 0, -1)
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", 1, 0)
    b:SetScript("OnEnter", function(self)
        defaultTip(self)
        pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", self.inv)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:Hide()
    PX.enchants[i] = b
    return b
end

-- The icons, just before your buffs (left of the player frame's buffs and debuffs).
function PX.updateEnchants()
    local f = frames.player
    local list = (f and getSetting("player", "weaponEnchants")) and PX.scanEnchants() or {}
    local size = getSetting("player", "auraSize") or 20
    local anchor = f and (f.auraBox or f)
    for i = 1, math.max(#list, #PX.enchants) do
        local e = list[i]
        local b = PX.enchants[i] or (e and PX.makeEnchant(i))
        if b then
            if e then
                b:SetSize(size, size)
                b:ClearAllPoints()
                if i == 1 then
                    if f.auraBox then b:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -3, 0)
                    else b:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 6, -4) end
                else
                    b:SetPoint("RIGHT", PX.enchants[i - 1], "LEFT", -2, 0)
                end
                b.inv, b.ends = e.inv, e.ends
                b.icon:SetTexture(e.icon)
                b.count:SetText(e.charges > 1 and tostring(e.charges) or "")
                b.time:SetText(shortTime(e.ends - GetTime()))
                b:Show()
            else
                b:Hide()
            end
        end
    end
end

---------------------------------------------------------------------------
-- Your buffs as timer bars
---------------------------------------------------------------------------
PX.POS = { point = "CENTER", x = 260, y = -120 }
PX.BAR_H = 18

-- One bar: the icon, then a bar that drains with the time left, the name on it and the time at its end.
function PX.makeBar(i)
    local bar = CreateFrame("Button", nil, PX.box)
    bar:SetHeight(PX.BAR_H)
    local back = bar:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0, 0, 0, 0.85)
    bar.icon = bar:CreateTexture(nil, "ARTWORK")
    bar.icon:SetPoint("TOPLEFT", 1, -1)
    bar.icon:SetSize(PX.BAR_H - 2, PX.BAR_H - 2)
    bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    bar.sb = CreateFrame("StatusBar", nil, bar)
    bar.sb:SetPoint("TOPLEFT", bar.icon, "TOPRIGHT", 1, 0)
    bar.sb:SetPoint("BOTTOMRIGHT", -1, 1)
    bar.sb:SetStatusBarTexture(WHITE)
    bar.sb:SetStatusBarColor(0.25, 0.55, 0.95, 0.85)
    bar.sb:SetMinMaxValues(0, 1)
    bar.name = bar.sb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.name:SetPoint("LEFT", 4, 0)
    bar.name:SetPoint("RIGHT", -36, 0)
    bar.name:SetJustifyH("LEFT")
    bar.name:SetWordWrap(false)
    bar.time = bar.sb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.time:SetPoint("RIGHT", -4, 0)
    bar:SetScript("OnEnter", function(self)
        if not self.index then return end
        defaultTip(self)
        pcall(GameTooltip.SetUnitAura, GameTooltip, "player", self.index, self.filter)
        GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bar:Hide()
    PX.bars[i] = bar
    return bar
end

-- A bar's timing: the game's own duration (works when the numbers are hidden in combat), else the
-- plain numbers, else a full bar with no time (a buff that doesn't run out).
function PX.timeBar(bar, a)
    bar.dur, bar.ends, bar.object = nil, nil, nil
    local id = a.auraInstanceID
    if C_UnitAuras.GetAuraDuration and bar.sb.SetTimerDuration and id ~= nil then
        local ok, d = pcall(C_UnitAuras.GetAuraDuration, "player", id)
        if ok and d then
            local dir = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime
            local interp = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate
            if pcall(bar.sb.SetTimerDuration, bar.sb, d, interp, dir) then bar.object = d; return end
        end
    end
    local dur, ends = readable(a.duration), readable(a.expirationTime)
    if dur and ends and dur > 0 then
        bar.dur, bar.ends = dur, ends
        bar.sb:SetMinMaxValues(0, dur)
    else
        bar.sb:SetMinMaxValues(0, 1)
        bar.sb:SetValue(1)
        bar.time:SetText("")
    end
end

-- Samples for Edit Mode (when you have no buffs to show).
PX.SAMPLES = { { 1243, 1800, 1500 }, { 1126, 1800, 640 }, { 1459, 1800, 95 } }

function PX.updateBars()
    local box = PX.box
    if not box then return end
    if not getSetting("player", "buffBars") then box:Hide(); PX.syncTick(); return end
    local filter = getSetting("player", "buffBarsWho") == "all" and "HELPFUL" or "HELPFUL|PLAYER"
    local max = getSetting("player", "buffBarsMax") or 8
    local w = getSetting("player", "buffBarsWidth") or 180
    local n = 0
    for i = 1, 40 do
        if n >= max then break end
        local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, filter)
        if not ok or not a then break end
        n = n + 1
        local bar = PX.bars[n] or PX.makeBar(n)
        bar.index, bar.filter = i, filter
        bar.icon:SetTexture(a.icon)
        bar.name:SetText(a.name)
        PX.timeBar(bar, a)
        bar:Show()
    end
    -- in Edit Mode with nothing to show: samples, to place the block
    if n == 0 and PX.editing then
        for i, s in ipairs(PX.SAMPLES) do
            local bar = PX.bars[i] or PX.makeBar(i)
            local tex
            pcall(function() tex = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(s[1])) or GetSpellTexture(s[1]) end)
            local name
            pcall(function() name = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(s[1])) or GetSpellInfo(s[1]) end)
            bar.index, bar.object = nil, nil
            bar.icon:SetTexture(tex)
            bar.name:SetText(name or "Sample buff")
            bar.dur, bar.ends = s[2], GetTime() + s[3]
            bar.sb:SetMinMaxValues(0, s[2])
            bar:Show()
            n = i
        end
    end
    for i = 1, #PX.bars do
        local bar = PX.bars[i]
        if i > n then bar:Hide() end
        bar:SetWidth(w)
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -(i - 1) * (PX.BAR_H + 2))
    end
    box:SetSize(w, math.max(PX.BAR_H, n * (PX.BAR_H + 2) - 2))
    box:Show()
    PX.syncTick()
end

-- Every frame while a bar is timed by plain numbers: its fill. Ten times a second: the time left.
-- A bar the game times itself needs no fill update, only that text, from a ticker.
local textWait = 0
function PX.tick(_, dt)
    local now = GetTime()
    textWait = textWait - (dt or 0)
    local text = textWait <= 0
    if text then textWait = 0.1 end
    for _, bar in ipairs(PX.bars) do
        if bar:IsShown() then
            if bar.ends then
                local left = bar.ends - now
                bar.sb:SetValue(math.max(0, left))
                if text then bar.time:SetText(shortTime(left)) end
            elseif bar.object and text then
                local ok, left = pcall(bar.object.GetRemainingDuration, bar.object)
                if not (ok and pcall(bar.time.SetFormattedText, bar.time, "%.0f", left)) then bar.time:SetText("") end
            end
        end
    end
end

function PX.tickText()
    for _, bar in ipairs(PX.bars) do
        if bar:IsShown() and bar.object then
            local ok, left = pcall(bar.object.GetRemainingDuration, bar.object)
            if not (ok and pcall(bar.time.SetFormattedText, bar.time, "%.0f", left)) then bar.time:SetText("") end
        end
    end
end

-- OnUpdate only while some shown bar has a plain end time. Otherwise a 0.1s ticker for the
-- duration-object text, or nothing.
function PX.syncTick()
    local box = PX.box
    if not box then return end
    local ends, object = false, false
    if getSetting("player", "buffBars") then
        for _, bar in ipairs(PX.bars) do
            if bar:IsShown() then
                if bar.ends then ends = true
                elseif bar.object then object = true end
            end
        end
    end
    if ends then
        if PX.barTicker then PX.barTicker:Cancel(); PX.barTicker = nil end
        if box:GetScript("OnUpdate") ~= PX.tick then box:SetScript("OnUpdate", PX.tick) end
    else
        box:SetScript("OnUpdate", nil)
        if object then
            if not PX.barTicker then PX.barTicker = C_Timer.NewTicker(0.1, PX.tickText) end
        elseif PX.barTicker then
            PX.barTicker:Cancel()
            PX.barTicker = nil
        end
    end
end

function PX.place()
    local u, d = unitData("player"), PX.POS
    PX.box:ClearAllPoints()
    if u and u.bbPoint then PX.box:SetPoint(u.bbPoint, UIParent, u.bbPoint, u.bbX or 0, u.bbY or 0)
    else PX.box:SetPoint(d.point, UIParent, d.point, d.x, d.y) end
end

---------------------------------------------------------------------------
-- Start (at login, from the main file)
---------------------------------------------------------------------------
function PX.init()
    if PX.box then return end
    local box = CreateFrame("Frame", "WebbyFrames_BuffBars", UIParent)
    box:SetFrameStrata("LOW")
    box:SetClampedToScreen(true)
    box:SetSize(180, PX.BAR_H)
    box:Hide()
    PX.box = box
    PX.place()
    local lib = LibStub and LibStub("LibEditMode", true)
    if lib then
        lib:AddFrame(box, function(_, layoutName, point, x, y)
            local active = layoutName == lib:GetActiveLayoutName()
            if active and ns.snapFrame then
                local sp, sx, sy = ns.snapFrame(box)     -- (lines up with the other frames, as they do)
                if sp then point, x, y = sp, sx, sy end
            end
            local u = unitData("player", true, layoutName)
            u.bbPoint, u.bbX, u.bbY = point, x, y
            if active then PX.place() end
        end, PX.POS, "Webby Buff Bars")
        lib:RegisterCallback("layout", function() C_Timer.After(0, function() PX.place(); PX.updateBars() end) end)
    end
    -- (for Edit Mode's toolbar, snapping and EllesmereUI's Unlock Mode; sample bars while either is open)
    if ns.addMover then
        ns.addMover({
            frame = box, label = "Buff Bars", page = "player",
            store = function(point, x, y) local u = unitData("player", true); u.bbPoint, u.bbX, u.bbY = point, x, y end,
            place = PX.place,
            reset = function() local u = unitData("player", true); u.bbPoint, u.bbX, u.bbY = nil, nil, nil; PX.place() end,
            enter = function() PX.editing = true; PX.updateBars() end,
            exit = function() PX.editing = nil; PX.updateBars() end,
        })
    end
    -- your auras (bars) and your weapons (enchants); a change waits for the next frame, so a burst of
    -- them is one update
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterUnitEvent, ev, "UNIT_AURA", "player")
    pcall(ev.RegisterUnitEvent, ev, "UNIT_INVENTORY_CHANGED", "player")
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED", "WEAPON_ENCHANT_CHANGED", "WEAPON_SLOT_CHANGED" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    local pending = false
    ev:SetScript("OnEvent", function(_, event)
        if event == "UNIT_AURA" then
            if not pending then
                pending = true
                C_Timer.After(0, function() pending = false; pcall(PX.updateBars) end)
            end
        else
            pcall(PX.updateEnchants)
        end
    end)
    -- (the enchants' time left, once a second; their end comes as an event)
    C_Timer.NewTicker(1, function()
        for _, b in ipairs(PX.enchants) do
            if b:IsShown() and b.ends then b.time:SetText(shortTime(b.ends - GetTime())) end
        end
    end)
    PX.apply()
end

-- An option changed.
function PX.apply()
    if not PX.box then return end
    pcall(PX.updateEnchants)
    pcall(PX.updateBars)
end
