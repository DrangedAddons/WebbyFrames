-- Webby Frames
-- Draws its own player / target / focus frames using Blizzard's built-in Retail
-- unit frame art (atlases), so the border and the pointed bars match Retail and
-- no other addon is needed. Layout numbers come from Blizzard's PlayerFrame.xml
-- and TargetFrame.xml. Position and options are editable in Edit Mode (bundled
-- LibEditMode) and in Esc > Options > AddOns > Webby Frames, saved per layout.

-- carry settings over from the old DFFramesForever name, once
WebbyFramesDB = WebbyFramesDB or DFFramesForeverDB or {}

local UNITS = { "player", "target", "targettarget", "focus", "focustarget", "pet" }
local UNIT_LABEL = { player = "Player", target = "Target", targettarget = "Target of Target", focus = "Focus", focustarget = "Focus Target", pet = "Pet" }
local function hasSideOption(unit) return unit == "target" or unit == "focus" or unit == "targettarget" or unit == "focustarget" or unit == "pet" end

local TOT_PREFIX = "UI-HUD-UnitFrame-TargetofTarget-PortraitOn"   -- small frame art (Retail target-of-target)
local SMALL_MASK_HEALTH = "UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health-Mask"
local SMALL_MASK_MANA   = "UI-HUD-UnitFrame-Party-PortraitOn-Bar-Mana-Mask"

local PLAYER_PREFIX = "UI-HUD-UnitFrame-Player-PortraitOn"   -- portrait on the left (Retail player frame)
local TARGET_PREFIX = "UI-HUD-UnitFrame-Target-PortraitOn"   -- portrait on the right (Retail target frame)

local DEFAULT_POS = {
    player = { point = "TOPLEFT", x = 20,  y = -40 },
    target = { point = "TOPLEFT", x = 270, y = -40 },
    focus  = { point = "TOPLEFT", x = 270, y = -170 },
    pet    = { point = "TOPLEFT", x = 20,  y = -170 },
    focustarget = { point = "TOPLEFT", x = 394, y = -260 },
    -- Retail puts target of target at the bottom right of the target frame
    targettarget = { point = "TOPLEFT", x = 394, y = -130 },
}

-- per-frame defaults that differ from DEFAULT_SETTINGS (the small frame is too narrow for long numbers)
local UNIT_DEFAULTS = {
    targettarget = { textMode = "off", textFormat = "percent" },
    pet = { textMode = "off", textFormat = "percent" },
    focustarget = { textMode = "off", textFormat = "percent" },
}

local DEFAULT_SETTINGS = {
    scale = 1, showName = true, portraitSide = "left", healthFade = "off", textMode = "always", textFormat = "value", barTexture = "default", font = "default", showCombat = true, showRest = true, showPvP = true, flashInterrupt = true, showThreat = true,
    smartColor = true,   -- class colour for players, reaction colour for NPCs
    classColor = false, reactionColor = false,
    cornerAccent = true,   -- the pointed accent on the ring (off = just the level circle)
}

-- fallback power bar art names if PowerBarColor doesn't supply one
local POWER_ATLAS = {
    MANA = "Mana", RAGE = "Rage", FOCUS = "Focus", ENERGY = "Energy", RUNIC_POWER = "RunicPower",
    LUNAR_POWER = "LunarPower", MAELSTROM = "Maelstrom", INSANITY = "Insanity", FURY = "Fury", PAIN = "Pain",
}

local DB, lib
local frames = {}
local activeLayout = "Default"
local pendingApply = false
local settingsCategory

---------------------------------------------------------------------------
-- Saved settings (per Edit Mode layout)
---------------------------------------------------------------------------
local function unitData(unit, create, layoutName)
    layoutName = layoutName or activeLayout
    DB.layouts = DB.layouts or {}
    local l = DB.layouts[layoutName]
    if not l then
        if not create then return nil end
        l = {}; DB.layouts[layoutName] = l
    end
    local u = l[unit]
    if not u and create then u = {}; l[unit] = u end
    return u
end

local function defaultFor(unit, key)
    local d = UNIT_DEFAULTS[unit]
    if d and d[key] ~= nil then return d[key] end
    return DEFAULT_SETTINGS[key]
end

local function getSetting(unit, key)
    local u = unitData(unit)
    local v = u and u[key]
    if v == nil and key == "textMode" and u and u.showText == false then return "off" end
    if v == nil then v = defaultFor(unit, key) end
    return v
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local atlasCache = {}
local atlasProbe
local function hasAtlas(name)
    if atlasCache[name] == nil then
        local ok, info = pcall(C_Texture.GetAtlasInfo, name)
        local found = (ok and info) and true or false
        if not found then
            -- second opinion: try to actually apply it to a throwaway texture
            pcall(function()
                atlasProbe = atlasProbe or UIParent:CreateTexture(nil, "BACKGROUND")
                atlasProbe:SetTexture(nil)
                atlasProbe:SetAtlas(name)
                if atlasProbe:GetAtlas() then found = true end
            end)
        end
        atlasCache[name] = found
    end
    return atlasCache[name]
end


-- WoW Forever swaps many retail atlas names for its own art, but the retail
-- unit frame sheets still ship with the client. For the frame art we draw the
-- retail sheet directly (file id + pixel box), as the Retail UI does.
-- Row: { 1x box l,r,t,b, 2x box l,r,t,b } on UIUnitFrame (1024x512) / 2x (2048x1024).
local SHEET1, SHEET2 = { id = 4631591, w = 1024, h = 512 }, { id = 4642466, w = 2048, h = 1024 }
local RETAIL_ART = {
    ["ui-hud-unitframe-player-portraiton"]         = { 1, 199, 87, 158,   1, 397, 171, 313 },
    ["ui-hud-unitframe-target-portraiton"]         = { 1, 193, 229, 296,  1, 385, 451, 585 },
    ["ui-hud-unitframe-targetoftarget-portraiton"] = { 330, 450, 160, 209, 1113, 1353, 315, 413 },
    ["ui-hud-unitframe-target-rare-portraiton"]    = { 1, 193, 298, 365,  1, 385, 587, 721 },
}
local drawnSheet = setmetatable({}, { __mode = "k" })
local function sheetPresent(sheet)
    if sheet.ok == nil then
        sheet.ok = true
        if GetFileIDFromPath then
            local path = sheet == SHEET1 and "Interface\\HUD\\UIUnitFrame" or "Interface\\HUD\\UIUnitFrame2x"
            local ok, id = pcall(GetFileIDFromPath, path)
            if ok and id then sheet.ok = (id == sheet.id) end
        end
    end
    return sheet.ok
end
-- Draws `name` on a plain texture: the retail sheet when the client has swapped the
-- atlas, otherwise the atlas itself.
local function stockAtlas(tex, name, useSize)
    local row = RETAIL_ART[strlower(name)]
    if row then
        local native
        pcall(function() native = C_Texture.GetAtlasInfo(name) end)
        local nf = native and native.file
        if nf ~= SHEET1.id and nf ~= SHEET2.id then
            local sheet, l, r, t, b = SHEET1, row[1], row[2], row[3], row[4]
            if sheetPresent(SHEET2) then sheet, l, r, t, b = SHEET2, row[5], row[6], row[7], row[8] end
            if sheetPresent(sheet) then
                tex:SetTexture(sheet.id)
                tex:SetTexCoord(l / sheet.w, r / sheet.w, t / sheet.h, b / sheet.h)
                if useSize then tex:SetSize(row[2] - row[1], row[4] - row[3]) end
                drawnSheet[tex] = true
                return true
            end
        end
    end
    if drawnSheet[tex] then drawnSheet[tex] = nil; tex:SetTexCoord(0, 1, 0, 1) end
    tex:SetAtlas(name, useSize and true or false)
    return false
end

-- Forever can hand back "secret" numbers, so every touch is wrapped.
local function setNumber(fs, v)
    if pcall(function() fs:SetText(AbbreviateLargeNumbers(v)) end) then return end
    if pcall(function() fs:SetFormattedText("%d", v) end) then return end
    fs:SetText("")
end

local function percentOf(kind, u, token)
    local pct
    pcall(function()
        local scale = CurveConstants and CurveConstants.ScaleTo100
        if kind == "hp" and UnitHealthPercent then pct = UnitHealthPercent(u, false, scale)
        elseif kind == "mp" and UnitPowerPercent then pct = UnitPowerPercent(u, token, false, scale) end
        if scale == nil and pct then pct = pct * 100 end
    end)
    if pct == nil then
        pcall(function()
            if kind == "hp" then pct = UnitHealth(u) / UnitHealthMax(u) * 100
            else pct = UnitPower(u) / UnitPowerMax(u) * 100 end
        end)
    end
    return pct
end

-- Writes "12.3K", "85%" or "12.3K - 85%" depending on the unit's text format.
-- Forever can hand back secret numbers, so every touch is wrapped.
local function setBarText(fs, f, kind)
    local u = f.unit
    local fmt = getSetting(f.baseUnit, "textFormat")
    local cur
    if kind == "hp" then cur = UnitHealth(u) else cur = UnitPower(u) end
    local token = select(2, UnitPowerType(u))
    local pct = (fmt ~= "value") and percentOf(kind, u, token) or nil
    local ok = pcall(function()
        local valueText = AbbreviateLargeNumbers(cur)
        if fmt == "value" then
            fs:SetText(valueText)
        elseif fmt == "percent" then
            fs:SetFormattedText("%d%%", pct)
        else
            fs:SetFormattedText("%s (%d%%)", valueText, pct)
        end
    end)
    if not ok then
        if not pcall(function() fs:SetFormattedText("%d", cur) end) then fs:SetText("") end
    end
end

local CIRCLE_FALLBACK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

-- Points a mask texture at an atlas (or a plain circle if the atlas is missing).
local function setMask(m, atlas, relTo, x, y, useAtlasSize)
    if hasAtlas(atlas) then
        m:SetAtlas(atlas, useAtlasSize and true or false)
    else
        m:SetTexture(CIRCLE_FALLBACK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    end
    if relTo then
        m:ClearAllPoints()
        m:SetPoint("TOPLEFT", relTo, "TOPLEFT", x or 0, y or 0)
    end
end

-- Bar with its own mask. The mask is attached later, by the layout code, once its art is known.
local function newBar(f)
    local bar = CreateFrame("StatusBar", nil, f)
    bar:SetFrameLevel(f:GetFrameLevel() + 1)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    local mask = bar:CreateMaskTexture()
    return bar, mask
end

-- Sets bar size/anchor/mask. Masks are only attached if the mask art exists,
-- otherwise an empty mask would hide the whole bar.
local function layoutBar(bar, mask, w, h, point, relTo, relPoint, x, y, maskAtlas, mx, my)
    bar:SetSize(w, h)
    bar:ClearAllPoints()
    bar:SetPoint(point, relTo, relPoint, x, y)
    bar.geo = { w = w, h = h, x = x, y = y, rel = relTo }
    if hasAtlas(maskAtlas) then
        setMask(mask, maskAtlas, bar, mx, my, true)
        local mi
        pcall(function() mi = C_Texture.GetAtlasInfo(maskAtlas) end)
        bar.maskInfo = { mask = mask, mx = mx or 0, my = my or 0, w = mi and mi.width, h = mi and mi.height }
        bar:GetStatusBarTexture():AddMaskTexture(mask)
        return true
    end
    return false
end

---------------------------------------------------------------------------
-- Colours
---------------------------------------------------------------------------

local function classColorOf(u)
    local r, g, b
    pcall(function()
        if UnitIsPlayer(u) then
            local _, token = UnitClass(u)
            local c = token and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
            if c then r, g, b = c.r, c.g, c.b end
        end
    end)
    return r, g, b
end

local function reactionColorOf(u)
    local r, g, b
    pcall(function() r, g, b = UnitSelectionColor(u, true) end)
    if type(r) == "number" then return r, g, b end
end


local function healthColor(f)
    local u, base = f.unit, f.baseUnit
    local r, g, b

    local tapped
    pcall(function() tapped = (not UnitPlayerControlled(u)) and UnitIsTapDenied(u) end)
    if tapped then return 0.5, 0.5, 0.5 end

    -- the pet's selection colour flips around (neutral / friendly / controlled), so the pet bar is always green
    if base == "pet" then return 0.1, 0.8, 0.1 end

    if getSetting(base, "smartColor") then
        -- players: always their class colour; NPCs (no class): reaction colour
        r, g, b = classColorOf(u)
        if not r then r, g, b = reactionColorOf(u) end
        if r then return r, g, b end
    end
    if getSetting(base, "classColor") then
        r, g, b = classColorOf(u); if r then return r, g, b end
    end
    if getSetting(base, "reactionColor") then
        r, g, b = reactionColorOf(u); if r then return r, g, b end
    end
end

---------------------------------------------------------------------------
-- Bar textures
---------------------------------------------------------------------------

local triedLoadMedia
local function getLSM()
    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    if not lsm and not triedLoadMedia then
        triedLoadMedia = true
        pcall(function() (C_AddOns and C_AddOns.LoadAddOn or LoadAddOn)("SharedMedia") end)
        lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    end
    return lsm
end

-- Inline preview strip shown in the dropdown rows (file path or atlas name)
local function previewLabel(name, file, atlas)
    local strip = ""
    if file then strip = "|T" .. file .. ":10:70|t  "
    elseif atlas then strip = "|A:" .. atlas .. ":10:70|a  " end
    return strip .. name
end

-- All textures offered in the dropdowns: "default" first, then built-in files, atlases that exist
-- on this client, and anything registered with LibSharedMedia (from other addons).
local function textureChoices()
    local list = { { "default", previewLabel("Default (Retail art)", nil, hasAtlas("UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health") and "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health" or nil) } }
    local lsm = getLSM()
    if lsm then
        pcall(function()
            for _, name in ipairs(lsm:List("statusbar")) do
                local path = lsm:Fetch("statusbar", name, true)
                list[#list + 1] = { "lsm:" .. name, previewLabel(name, path) }
            end
        end)
    end
    return list
end

local function resolveTexture(key)
    if type(key) ~= "string" or key == "default" then return nil end
    local kind, v = key:match("^(%a+):(.+)$")
    if kind == "file" or kind == "atlas" then return v end
    if kind == "lsm" then
        local lsm = getLSM()
        local path
        if lsm then pcall(function() path = lsm:Fetch("statusbar", v, true) end) end
        return path
    end
end

---------------------------------------------------------------------------
-- Fonts
---------------------------------------------------------------------------

local function fontChoices()
    local list = { { "default", "Default", nil } }
    local lsm = getLSM()
    if lsm then
        pcall(function()
            for _, name in ipairs(lsm:List("font")) do
                list[#list + 1] = { "lsm:" .. name, name, lsm:Fetch("font", name, true) }
            end
        end)
    end
    return list
end

local function resolveFont(key)
    if type(key) ~= "string" or key == "default" then return nil end
    local kind, v = key:match("^(%a+):(.+)$")
    if kind == "file" then return v end
    if kind == "lsm" then
        local lsm = getLSM()
        local path
        if lsm then pcall(function() path = lsm:Fetch("font", v, true) end) end
        return path
    end
end

local function applyFont(f)
    local path = resolveFont(getSetting(f.baseUnit, "font"))
    f.fontDefaults = f.fontDefaults or {}
    for _, fs in ipairs({ f.name, f.hpText, f.mpText }) do
        if fs then
            if not f.fontDefaults[fs] then
                local fp, fz, ff = fs:GetFont()
                f.fontDefaults[fs] = { fp, fz, ff }
            end
            local d = f.fontDefaults[fs]
            local ok = false
            if path and d[2] then ok = fs:SetFont(path, d[2], d[3]) end
            if not ok and d[1] then fs:SetFont(d[1], d[2], d[3]) end
        end
    end
end

-- Health colour fade (like EllesmereUI): the colour is chosen by a curve the GAME evaluates from the
-- unit's health percent, so it works with protected values; the result is only ever passed to a setter.
local FADE_RED    = { 0.89, 0.19, 0.19 }
local FADE_YELLOW = { 0.93, 0.93, 0.20 }
local FADE_ORANGE = { 0.96, 0.55, 0.10 }
local fadeCurves = {}
local function getFadeCurve(mode, r, g, b)
    local key = mode
    if mode == "reactive" then key = string.format("reactive:%.2f:%.2f:%.2f", r, g, b) end
    local c = fadeCurves[key]
    if c ~= nil then return c or nil end
    fadeCurves[key] = false
    pcall(function()
        if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return end
        local curve = C_CurveUtil.CreateColorCurve()
        pcall(function() curve:SetType(Enum.LuaCurveType.Linear) end)
        local R, Y, O = FADE_RED, FADE_YELLOW, FADE_ORANGE
        local top = (mode == "classic") and { 0, 1, 0 } or { r, g, b }
        curve:AddPoint(0,    CreateColor(R[1], R[2], R[3], 1))
        curve:AddPoint(0.2,  CreateColor(R[1], R[2], R[3], 1))
        curve:AddPoint(0.45, CreateColor(O[1], O[2], O[3], 1))
        curve:AddPoint(0.7,  CreateColor(Y[1], Y[2], Y[3], 1))
        -- halfway between your colour and yellow, pulled toward grey so a blue class does not pass through green
        local mr, mg, mb = (Y[1] + top[1]) / 2, (Y[2] + top[2]) / 2, (Y[3] + top[3]) / 2
        if mode ~= "classic" then
            local lum = 0.3 * mr + 0.59 * mg + 0.11 * mb
            mr, mg, mb = mr + (lum - mr) * 0.8, mg + (lum - mg) * 0.8, mb + (lum - mb) * 0.8
        end
        curve:AddPoint(0.85, CreateColor(mr, mg, mb, 1))
        curve:AddPoint(1,    CreateColor(top[1], top[2], top[3], 1))
        fadeCurves[key] = curve
    end)
    return fadeCurves[key] or nil
end

-- Returns true when the fade painted the bar.
local function applyHealthFade(f, r, g, b)
    local mode = getSetting(f.baseUnit, "healthFade")
    if mode ~= "classic" and mode ~= "reactive" then return false end
    if not (UnitHealthPercent and UnitExists(f.unit)) then return false end
    local curve = getFadeCurve(mode, r or 0.1, g or 0.8, b or 0.1)
    if not curve then return false end
    local ok = pcall(function()
        local color = UnitHealthPercent(f.unit, true, curve)
        local cr, cg, cb = color:GetRGB()
        f.hp:SetStatusBarColor(cr, cg, cb, 1)
    end)
    if ok then
        pcall(function() f.hp:GetStatusBarTexture():SetDesaturated(f.customTex == nil and f.hpCurrent == f.hpAtlas or false) end)
    end
    return ok
end

local function updateHealthColor(f)
    local r, g, b
    pcall(function() r, g, b = healthColor(f) end)
    local tex = f.hp:GetStatusBarTexture()
    local want = (r and f.hpStatusAtlas) or f.hpAtlas
    if f.customTex then
        if f.hpCurrent ~= f.customTex then
            f.hpCurrent = f.customTex
            f.hp:SetStatusBarTexture(f.customTex)
            if f.hpMaskOn then f.hp:GetStatusBarTexture():AddMaskTexture(f.hpMask) end
        end
        pcall(function() f.hp:GetStatusBarTexture():SetDesaturated(false) end)
        if r then f.hp:SetStatusBarColor(r, g, b, 1) else f.hp:SetStatusBarColor(0.1, 0.8, 0.1, 1) end
        applyHealthFade(f, r, g, b)
        return
    end
    if f.hpCurrent ~= want and hasAtlas(want) then
        f.hpCurrent = want
        f.hp:SetStatusBarTexture(want)
        -- re-attach the mask: replacing the texture drops it
        if f.hpMaskOn then f.hp:GetStatusBarTexture():AddMaskTexture(f.hpMask) end
        tex = f.hp:GetStatusBarTexture()
    end
    if r then
        pcall(function() tex:SetDesaturated(want == f.hpAtlas) end)   -- plain art needs desaturating to tint cleanly
        f.hp:SetStatusBarColor(r, g, b, 1)
    else
        pcall(function() tex:SetDesaturated(false) end)
        f.hp:SetStatusBarColor(1, 1, 1, 1)
    end
    applyHealthFade(f, r, g, b)
end

local function updateHealth(f)
    local u = f.unit
    if not UnitExists(u) then return end
    updateHealthColor(f)
    f.hp:SetMinMaxValues(0, UnitHealthMax(u))
    f.hp:SetValue(UnitHealth(u))
    setBarText(f.hpText, f, "hp")
end

local function updatePower(f)
    local u = f.unit
    if not UnitExists(u) then return end
    local _, token = UnitPowerType(u)
    local prefix = f.prefix .. "-Bar-"
    local name = POWER_ATLAS[token]
    pcall(function()
        local info = PowerBarColor and PowerBarColor[token]
        if info and info.atlasElementName then name = info.atlasElementName end
    end)
    if f.customTex then
        if f.mpCurrent ~= f.customTex then
            f.mpCurrent = f.customTex
            f.mp:SetStatusBarTexture(f.customTex)
            if f.mpMaskOn then f.mp:GetStatusBarTexture():AddMaskTexture(f.mpMask) end
        end
        pcall(function() f.mp:GetStatusBarTexture():SetDesaturated(false) end)
        local pr, pg, pb = 0.1, 0.3, 0.9
        pcall(function()
            local c = PowerBarColor and (PowerBarColor[token] or PowerBarColor[0])
            if c and c.r then pr, pg, pb = c.r, c.g, c.b end
        end)
        f.mp:SetStatusBarColor(pr, pg, pb, 1)
        f.mp:SetMinMaxValues(0, UnitPowerMax(u))
        f.mp:SetValue(UnitPower(u))
        setBarText(f.mpText, f, "mp")
        return
    end
    local atlas = prefix .. (name or "Mana")
    if not hasAtlas(atlas) then atlas = prefix .. "Mana" end
    if f.mpCurrent ~= atlas and hasAtlas(atlas) then
        f.mpCurrent = atlas
        f.mp:SetStatusBarTexture(atlas)
        if f.mpMaskOn then f.mp:GetStatusBarTexture():AddMaskTexture(f.mpMask) end
    end
    f.mp:SetStatusBarColor(1, 1, 1, 1)
    f.mp:SetMinMaxValues(0, UnitPowerMax(u))
    f.mp:SetValue(UnitPower(u))
    setBarText(f.mpText, f, "mp")
end

local function updateInfo(f)
    local u = f.unit
    if not UnitExists(u) then return end
    -- Forever has surnames: show "First Last", cut off at the width of the name bar
    if not pcall(function()
        local n, sur = UnitName(u)
        if sur and sur ~= "" and not f.small then f.name:SetFormattedText("%s %s", n, sur) else f.name:SetText(n) end
    end) then
        if not pcall(function() f.name:SetText(UnitName(u)) end) then f.name:SetText("") end
    end
    local lvl = ""
    pcall(function()
        local l = UnitLevel(u)
        lvl = (l and l > 0) and tostring(l) or "??"
    end)
    f.level:SetText(lvl)
    if f.badge then
        if f.baseUnit == "player" then f.level:SetTextColor(1, 1, 1) else f.level:SetTextColor(1, 0.82, 0) end
    end
    SetPortraitTexture(f.portrait, u)
    if f.plate then
        local r, g, b = reactionColorOf(u)
        if r then f.plate:SetVertexColor(r, g, b) else f.plate:SetVertexColor(1, 1, 1) end
    end
end

---------------------------------------------------------------------------
-- Status indicators: combat + resting (player), PvP flag (all three frames)
---------------------------------------------------------------------------
local STATE_ICON = "Interface\\CharacterFrame\\UI-StateIcon"
local PVP_ICONS = {
    Horde    = { "UI-HUD-UnitFrame-Player-PVP-HordeIcon",    "Interface\\TargetingFrame\\UI-PVP-Horde" },
    Alliance = { "UI-HUD-UnitFrame-Player-PVP-AllianceIcon", "Interface\\TargetingFrame\\UI-PVP-Alliance" },
    FFA      = { "UI-HUD-UnitFrame-Player-PVP-FFAIcon",      "Interface\\TargetingFrame\\UI-PVP-FFA" },
}

local function setIcon(tex, atlas, file, l, r, t, b)
    if atlas and hasAtlas(atlas) then
        tex:SetTexCoord(0, 1, 0, 1)
        tex:SetAtlas(atlas, true)
    else
        tex:SetSize(34, 34)
        tex:SetTexture(file)
        tex:SetTexCoord(l, r, t, b)
    end
end

local function createIndicators(f)
    local ov = f.ov
    if not ov then return end
    -- a copy of just the portrait ring, drawn above the bars so the bar ends tuck under the circle
    f.ringTop = ov:CreateTexture(nil, "OVERLAY", nil, -6)
    -- ...limited to a circle around the portrait, so only the ring (not the dark bar trough beside it) is drawn on top
    f.ringMask = ov:CreateMaskTexture()
    if hasAtlas("CircleMask") then f.ringMask:SetAtlas("CircleMask") else
        f.ringMask:SetTexture(CIRCLE_FALLBACK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    end
    f.ringTop:AddMaskTexture(f.ringMask)
    if f.baseUnit == "player" then
        f.combatIcon = ov:CreateTexture(nil, "OVERLAY", nil, 5)
        f.combatIcon:SetSize(32, 32)
        setIcon(f.combatIcon, "UI-HUD-UnitFrame-Player-CombatIcon", STATE_ICON, 0.5, 1, 0, 0.49)
        if f.combatIcon:GetAtlas() then pcall(f.combatIcon.SetAtlas, f.combatIcon, "UI-HUD-UnitFrame-Player-CombatIcon", true) end
        f.combatIcon:Hide()
        -- Combat / resting glow: the frame's own portrait-ring art, tinted, with softer enlarged copies
        -- behind it for a halo, so it follows the art's shape.
        if hasAtlas(PLAYER_PREFIX) then
            local sf = CreateFrame("Frame", nil, f)
            sf:SetAllPoints(f)
            sf:SetFrameLevel(f:GetFrameLevel() + 4)
            local layers = {}
            local ok = false
            local specs = { { 1.10, 0.25, -7 }, { 1.05, 0.5, -6 }, { 1.0, 1.0, -5 } }
            for _, sp in ipairs(specs) do
                local t = sf:CreateTexture(nil, "OVERLAY", nil, sp[3])
                local sheet = stockAtlas(t, PLAYER_PREFIX, true)
                if not sheet then break end
                local good = pcall(function()
                    local ulx, uly, llx, lly, urx = t:GetTexCoord()
                    local w0, h0 = t:GetWidth(), t:GetHeight()
                    local x0 = (232 - w0) / 2
                    local frac = (92 - x0) / w0            -- keep only the portrait ring (and its corner)
                    t:SetTexCoord(ulx, ulx + (urx - ulx) * frac, uly, lly)
                    local w, h = w0 * frac, h0
                    local k = sp[1]
                    local cx = x0 + w / 2
                    t:SetSize(w * k, h * k)
                    t:SetPoint("CENTER", f, "TOPLEFT", 54 + (cx - 54) * k, -49 + (-50 + 49) * k)
                    t:SetBlendMode("ADD")
                    t:SetAlpha(sp[2])
                end)
                if not good then break end
                layers[#layers + 1] = t
                ok = true
            end
            if ok then
                sf:Hide()
                f.status = {
                    Show = function() sf:Show() end,
                    Hide = function() sf:Hide() end,
                    SetAlpha = function(_, a) sf:SetAlpha(a) end,
                    SetVertexColor = function(_, r, g, b) for _, t in ipairs(layers) do t:SetVertexColor(r, g, b) end end,
                }
                pcall(function()
                    local ag = sf:CreateAnimationGroup()
                    ag:SetLooping("BOUNCE")
                    local a = ag:CreateAnimation("Alpha")
                    a:SetFromAlpha(1); a:SetToAlpha(0.35); a:SetDuration(0.8)
                    f.statusAnim = ag
                end)
            end
        end
        if not f.updateRest then
            f.restIcon = ov:CreateTexture(nil, "OVERLAY", nil, 5)
            f.restIcon:SetSize(24, 24)
            setIcon(f.restIcon, nil, STATE_ICON, 0, 0.5, 0, 0.421875)
            f.restIcon:Hide()
        end
    end
    f.pvpIcon = ov:CreateTexture(nil, "OVERLAY", nil, 5)
    f.pvpIcon:SetSize(34, 34)
    f.pvpIcon:Hide()
    -- hover the badge for the PvP flag timer (player: time until the flag drops)
    local hit = CreateFrame("Frame", nil, f)
    hit:SetFrameLevel(f:GetFrameLevel() + 8)
    hit:SetAllPoints(f.pvpIcon)
    hit:EnableMouse(true)
    hit:Hide()
    local function tip(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("PvP flagged", 1, 1, 1)
        if f.baseUnit == "player" then
            local ms
            pcall(function() ms = GetPVPTimer() end)
            if type(ms) == "number" and ms > 0 and ms < 300000 then
                local sec = math.floor(ms / 1000)
                GameTooltip:AddLine(string.format("Flag drops in %d:%02d", math.floor(sec / 60), sec % 60), 1, 0.82, 0)
            else
                GameTooltip:AddLine("No timer running", 0.7, 0.7, 0.7)
            end
        end
        GameTooltip:Show()
    end
    hit:SetScript("OnEnter", function(self)
        tip(self)
        local acc = 0
        self:SetScript("OnUpdate", function(s2, dt)
            acc = acc + dt
            if acc >= 0.5 then acc = 0; tip(s2) end
        end)
    end)
    hit:SetScript("OnLeave", function(self)
        self:SetScript("OnUpdate", nil)
        GameTooltip:Hide()
    end)
    f.pvpHit = hit
    -- threat: coloured glow + percentage (target and focus)
    if f.baseUnit ~= "player" and not f.small then
        -- numeric threat box, like the default UI: coloured by threat status, shows your threat percent
        local box = CreateFrame("Frame", nil, ov)
        box:SetSize(46, 16)
        box:SetFrameLevel(ov:GetFrameLevel() + 2)
        local edge = box:CreateTexture(nil, "BACKGROUND", nil, 0)
        edge:SetAllPoints(); edge:SetColorTexture(0, 0, 0, 0.9)
        f.threat = box:CreateTexture(nil, "BACKGROUND", nil, 1)
        f.threat:SetPoint("TOPLEFT", 1, -1); f.threat:SetPoint("BOTTOMRIGHT", -1, 1)
        f.threat:SetColorTexture(1, 1, 1, 1)
        f.threatText = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.threatText:SetPoint("CENTER", 0, 0)
        f.threatBox = box
        box:Hide()
    end
end

local function placeIndicators(f)
    local left = f.layoutLeft
    if f.combatIcon then
        f.combatIcon:ClearAllPoints()
        f.combatIcon:SetPoint("CENTER", f, "TOPLEFT", 80, -75)   -- takes the corner accent's place, as on Retail
    end
    if f.restIcon then
        f.restIcon:ClearAllPoints()
        f.restIcon:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -8)
    end
    if f.pvpIcon then
        f.pvpIcon:ClearAllPoints()
        if left then f.pvpIcon:SetPoint("RIGHT", f, "TOPLEFT", 28, -49) else f.pvpIcon:SetPoint("LEFT", f, "TOPRIGHT", -28, -49) end
    end
    if f.threatBox then
        f.threatBox:ClearAllPoints()
        f.threatBox:SetPoint("BOTTOM", f, "TOPLEFT", left and 147 or 86, -17)
    end
end

local function updateIndicators(f)
    if f.small or not f.pvpIcon then return end
    local u, base = f.unit, f.baseUnit
    if f.combatIcon then
        local inCombat = f.combatFlag
        pcall(function() if UnitAffectingCombat("player") then inCombat = true end end)
        local showC = (inCombat and getSetting(base, "showCombat")) and true or false
        f.combatIcon:SetShown(showC)
        if f.corner then f.corner:SetShown((getSetting(base, "cornerAccent") and not showC) and true or false) end
        if f.status then
            local resting = false
            pcall(function() resting = IsResting() and true or false end)
            if showC then
                f.status:SetVertexColor(1, 0, 0)
                f.status:Show()
                if f.statusAnim and not f.statusAnim:IsPlaying() then f.statusAnim:Play() end
            elseif resting and getSetting(base, "showRest") then
                if f.statusAnim then f.statusAnim:Stop() end
                f.status:SetAlpha(1)
                f.status:SetVertexColor(1, 0.88, 0.25)
                f.status:Show()
            else
                if f.statusAnim then f.statusAnim:Stop() end
                f.status:Hide()
            end
        end
    end
    if f.restIcon then
        local resting = false
        pcall(function() resting = IsResting() and true or false end)
        f.restIcon:SetShown((resting and getSetting(base, "showRest")) and true or false)
    end
    local kind
    pcall(function()
        if not UnitExists(u) then return end
        if UnitIsPVPFreeForAll(u) then kind = "FFA"
        elseif UnitIsPVP(u) then
            local fac = UnitFactionGroup(u)
            kind = (fac == "Horde" or fac == "Alliance") and fac or nil
        end
    end)
    if kind and getSetting(base, "showPvP") then
        local ic = PVP_ICONS[kind]
        setIcon(f.pvpIcon, ic[1], ic[2], 0, 0.609375, 0, 0.640625)
        f.pvpIcon:Show()
        if f.pvpHit then f.pvpHit:Show() end
    else
        f.pvpIcon:Hide()
        if f.pvpHit then f.pvpHit:Hide() end
    end
end

-- Pulsing red glow while the unit is casting something you could interrupt
local function updateFlash(f)
    if not f.flash then return end
    local on = false
    pcall(function()
        if not getSetting(f.baseUnit, "flashInterrupt") then return end
        local u = f.unit
        if not UnitExists(u) or not UnitCanAttack("player", u) then return end
        local n, _, _, _, _, _, _, ni = UnitCastingInfo(u)
        if not n then
            local cn, _, _, _, _, _, ci = UnitChannelInfo(u)
            n, ni = cn, ci
        end
        if n and (ni == false or ni == nil) then on = true end
    end)
    if on then
        if not f.flash:IsShown() then f.flash:Show() end
        if f.flashAnim and not f.flashAnim:IsPlaying() then f.flashAnim:Play() end
    else
        if f.flashAnim then f.flashAnim:Stop() end
        f.flash:Hide()
    end
end

local function updateThreat(f)
    if not f.threatBox then return end
    local status, pct
    pcall(function()
        if not getSetting(f.baseUnit, "showThreat") then return end
        local u = f.unit
        if not UnitExists(u) or not UnitCanAttack("player", u) then return end
        status = UnitThreatSituation("player", u)
        local _, _, scaled = UnitDetailedThreatSituation("player", u)
        pct = scaled
    end)
    local shown = false
    if status ~= nil and pct ~= nil then
        local r, g, b = 0.5, 0.5, 0.5
        pcall(function() if GetThreatStatusColor then r, g, b = GetThreatStatusColor(status) end end)
        local ok = pcall(function() f.threatText:SetFormattedText("%d%%", pct) end)
        if ok then
            f.threat:SetVertexColor(r, g, b, 0.85)
            shown = true
        end
    end
    f.threatBox:SetShown(shown)
end

local function updateAll(f) updateInfo(f); updateHealth(f); updatePower(f); updateIndicators(f); updateFlash(f); updateThreat(f) end

---------------------------------------------------------------------------
-- Layout: Retail's left-portrait (player) art, or right-portrait (target) art
---------------------------------------------------------------------------
local function isLeft(f)
    return f.baseUnit == "player" or getSetting(f.baseUnit, "portraitSide") ~= "right"
end

-- Returns true if the layout changed.
local function applyLayout(f)
    if f.small then return false end      -- the small frame has a fixed layout
    local left = isLeft(f)
    if f.layoutLeft == left then return false end
    f.layoutLeft = left

    local prefix = left and PLAYER_PREFIX or TARGET_PREFIX
    f.prefix = prefix
    f.hpAtlas = prefix .. "-Bar-Health"
    f.hpStatusAtlas = prefix .. "-Bar-Health-Status"
    if not hasAtlas(f.hpStatusAtlas) then f.hpStatusAtlas = f.hpAtlas end
    f.hpCurrent, f.mpCurrent = nil, nil

    -- border / frame art
    f.border:ClearAllPoints()
    if f.ringTop then
        local t = f.ringTop
        t:ClearAllPoints()
        local shown = false
        if not left and hasAtlas(prefix) and stockAtlas(t, prefix, true) then
            f.ringMask:ClearAllPoints()
            f.ringMask:SetSize(66, 66)
            f.ringMask:SetPoint("CENTER", f, "TOPLEFT", 177, -48)
            pcall(function()
                local ulx, uly, llx, lly, urx = t:GetTexCoord()
                local w0, h0 = t:GetWidth(), t:GetHeight()
                local x0 = (232 - w0) / 2
                if left then
                    local frac = (86 - x0) / w0
                    t:SetTexCoord(ulx, ulx + (urx - ulx) * frac, uly, lly)
                    t:SetSize(w0 * frac, h0)
                    t:SetPoint("LEFT", f, "LEFT", x0, 0)
                else
                    local sx = 146 - x0
                    t:SetTexCoord(ulx + (urx - ulx) * (sx / w0), urx, uly, lly)
                    t:SetSize(w0 - sx, h0)
                    t:SetPoint("RIGHT", f, "RIGHT", -x0, 0)
                end
                shown = true
            end)
        end
        t:SetShown(shown)
    end
    for _, g in ipairs({ f.flash or false }) do
        if g then
            g:ClearAllPoints()
            if hasAtlas(prefix) then
                stockAtlas(g, prefix, true)
                g:SetPoint("CENTER", f, "CENTER", 0, 0)
            else
                g:SetColorTexture(1, 1, 1, 1)
                g:SetSize(150, 50)
                g:SetPoint("CENTER", f, "CENTER", left and 30 or -30, 0)
            end
            g:SetBlendMode("ADD")
        end
    end
    if f.flash then f.flash:SetVertexColor(1, 0.15, 0.1) end
    if hasAtlas(prefix) then
        stockAtlas(f.border, prefix, true)
        f.border:SetPoint("CENTER", f, "CENTER", 0, 0)
    else
        f.border:SetColorTexture(0, 0, 0, 0.5)
        f.border:SetSize(150, 50)
        f.border:SetPoint("CENTER", f, "CENTER", left and 30 or -30, 0)
    end

    -- portrait and its mask
    f.portrait:ClearAllPoints()
    f.pmask:ClearAllPoints()
    if left then
        f.portrait:SetSize(60, 60)
        f.portrait:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -19)
        setMask(f.pmask, "UI-HUD-UnitFrame-Player-Portrait-Mask", f, 24, -19, true)
        f.pmask:SetSize(60, 60)
    else
        f.portrait:SetSize(58, 58)
        f.portrait:SetPoint("TOPRIGHT", f, "TOPRIGHT", -26, -19)
        if hasAtlas("CircleMask") then f.pmask:SetAtlas("CircleMask") else
            f.pmask:SetTexture(CIRCLE_FALLBACK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        end
        f.pmask:SetPoint("TOPLEFT", f.portrait, "TOPLEFT", 0, -1)
        f.pmask:SetPoint("BOTTOMRIGHT", f.portrait, "BOTTOMRIGHT", -1, 0)
    end

    -- bars
    if left then
        f.hpMaskOn = layoutBar(f.hp, f.hpMask, 124, 20, "TOPLEFT", f, "TOPLEFT", 85, -40, prefix .. "-Bar-Health-Mask", -2, 6)
        f.mpMaskOn = layoutBar(f.mp, f.mpMask, 124, 10, "TOPLEFT", f, "TOPLEFT", 85, -61, prefix .. "-Bar-Mana-Mask", -2, 2)
    else
        f.hpMaskOn = layoutBar(f.hp, f.hpMask, 131, 20, "TOPLEFT", f, "TOPLEFT", 23, -40, prefix .. "-Bar-Health-Mask", -1, 6)
        -- full health reaches the portrait ring: the bar and its rounded mask are stretched 7px toward it
        if f.hpMaskOn then f.hpMask:SetSize(133, 32) end
        -- power bar: same rounded shape as the health bar, flush on the left, and stretched so its
        -- angled end follows the portrait ring and fills right into the corner at 100%
        f.mpMaskOn = layoutBar(f.mp, f.mpMask, 136, 10, "TOPLEFT", f, "TOPLEFT", 23, -61, prefix .. "-Bar-Mana-Mask", -70.3, 3)
        if f.mpMaskOn then f.mpMask:SetSize(274, 16) end
    end

    -- text
    f.mpText:ClearAllPoints()
    f.mpText:SetPoint("CENTER", f.mp, "CENTER", left and 0 or -4, 0)
    f.name:ClearAllPoints(); f.level:ClearAllPoints()
    -- Forever layout: the level sits in a round badge at the bottom corner of the art
    if f.badge then
        f.badge:ClearAllPoints()
        f.badge:SetSize(39, 39)
        f.badge:SetPoint(left and "BOTTOMLEFT" or "BOTTOMRIGHT", f, left and "BOTTOMLEFT" or "BOTTOMRIGHT", left and 13 or -13, 7)
        f.badge:Show()
        f.level:SetJustifyH("CENTER")
        f.level:SetPoint("CENTER", f.badge, "CENTER", 0, -0.5)
    end
    if left then
        f.name:SetSize(f.badge and 117 or 96, 12)
        f.name:SetPoint("TOPLEFT", f, "TOPLEFT", 88, -27)
        if not f.badge then f.level:SetPoint("TOPRIGHT", f, "TOPRIGHT", -24.5, -28) end
        f:SetHitRectInsets(20, 15, 15, 20)
    else
        f.name:SetSize(f.badge and 117 or 90, 12)
        f.name:SetPoint("TOPLEFT", f, "TOPLEFT", f.badge and 24 or 30, -26)
        if not f.badge then f.level:SetPoint("TOPRIGHT", f, "TOPRIGHT", -91, -27) end
        f:SetHitRectInsets(15, 20, 15, 20)
    end
    return true
end

---------------------------------------------------------------------------
-- Applying settings
---------------------------------------------------------------------------
local function refreshText(f)
    local mode = getSetting(f.baseUnit, "textMode")
    local always = (mode == "always")
    local over = (mode == "mouseover")
    f.hpText:SetShown((always or (over and f.hoverHP)) and true or false)
    f.mpText:SetShown((always or (over and f.hoverMP)) and true or false)
end

-- The pointed accent on the portrait ring: mirrored on right-portrait frames, scaled on the small frame.
local function applyCorner(f)
    local c = f.corner
    if not c then return end
    c:SetShown(getSetting(f.baseUnit, "cornerAccent") and true or false)
    if f.small then
        if f.layoutLeft == false then c:Hide() end
        return
    end
    c:ClearAllPoints()
    -- Draw from the atlas's own file + coordinates so the mirror is exact (SetTexCoord on a
    -- live atlas texture is not reliable); fall back to the plain atlas on the left.
    local info
    pcall(function() info = C_Texture.GetAtlasInfo(PLAYER_PREFIX .. "-CornerEmbellishment") end)
    local file = info and (info.file or info.filename)
    local l, r, t, b
    if file then l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord end
    if type(l) ~= "number" then file = nil end
    if file then
        c:SetTexture(file)
        c:SetSize(info.width, info.height)
        if f.layoutLeft then c:SetTexCoord(l, r, t, b) else c:SetTexCoord(r, t, r, b, l, t, l, b) end
    elseif f.layoutLeft then
        c:SetAtlas(PLAYER_PREFIX .. "-CornerEmbellishment", true)
    end
    if f.layoutLeft then
        c:SetPoint("TOPLEFT", f, "TOPLEFT", 58.5, -53.5)
    else
        c:SetPoint("TOPRIGHT", f, "TOPRIGHT", -58.5, -53.5)
    end
end

local function mirrorTexCoords(tex)
    local ulx, uly, llx, lly, urx, ury, lrx, lry = tex:GetTexCoord()
    if ulx then tex:SetTexCoord(urx, ury, lrx, lry, ulx, uly, llx, lly) end
end

-- Small frame (target of target): portrait on either side. The right layout mirrors the art and bar masks.
local function applySmallLayout(f)
    local left = isLeft(f)
    if f.layoutLeft == left then return false end
    f.layoutLeft = left
    f.portrait:ClearAllPoints()
    f.portrait:SetPoint(left and "TOPLEFT" or "TOPRIGHT", f, left and "TOPLEFT" or "TOPRIGHT", left and 5 or -5, -5)
    f.border:ClearAllPoints()
    if hasAtlas(TOT_PREFIX) then
        local sheet = stockAtlas(f.border, TOT_PREFIX, true)
        f.border:SetPoint("CENTER", f, "CENTER", 0, 0)
        if sheet and not left then mirrorTexCoords(f.border) end
    end
    f.hpMask:SetTexCoord(0, 1, 0, 1); f.mpMask:SetTexCoord(0, 1, 0, 1)
    f.hpMaskOn = layoutBar(f.hp, f.hpMask, 70, 10, "TOPLEFT", f, "TOPLEFT", left and 44 or 6, -17, SMALL_MASK_HEALTH, -29, 3)
    f.mpMaskOn = layoutBar(f.mp, f.mpMask, 74, 7, "TOPLEFT", f, "TOPLEFT", left and 40 or 6, -28, SMALL_MASK_MANA, -27, 4)
    if not left then
        if f.hpMaskOn then pcall(mirrorTexCoords, f.hpMask) end
        if f.mpMaskOn then pcall(mirrorTexCoords, f.mpMask) end
    end
    f.name:ClearAllPoints()
    if left then f.name:SetPoint("TOPLEFT", f.portrait, "TOPRIGHT", 2, 0) else f.name:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -5) end
    f:SetHitRectInsets(left and 0 or 6, left and 6 or 0, 4, 4)
    return true
end

local function applyUnit(f)
    local unit = f.baseUnit
    local u = unitData(unit)
    local d = DEFAULT_POS[unit]
    local changed = applyLayout(f)
    if f.small and applySmallLayout(f) then changed = true end
    f:ClearAllPoints()
    if u and u.point then
        f:SetPoint(u.point, UIParent, u.point, u.x, u.y)
    else
        f:SetPoint(d.point, UIParent, d.point, d.x, d.y)
    end
    f:SetScale(getSetting(unit, "scale"))
    local showName = getSetting(unit, "showName") and true or false
    f.name:SetShown(showName)
    if f.plate then f.plate:SetShown(showName and not f.layoutLeft) end
    applyCorner(f)
    placeIndicators(f)
    pcall(applyFont, f)
    pcall(updateFlash, f)
    pcall(updateThreat, f)
    pcall(updateIndicators, f)
    if f.updateRest then pcall(f.updateRest) end
    local tex = resolveTexture(getSetting(unit, "barTexture"))
    if tex ~= f.customTex then
        f.customTex = tex
        f.hpCurrent, f.mpCurrent = nil, nil
        changed = true
    end
    refreshText(f)
    if changed then pcall(updateAll, f) end
end

local function applyAll()
    if InCombatLockdown() then pendingApply = true; return end
    pendingApply = false
    for _, unit in ipairs(UNITS) do
        if frames[unit] then applyUnit(frames[unit]) end
    end
end

local function setSetting(unit, key, value)
    unitData(unit, true)[key] = value
    local f = frames[unit]
    if f then
        pcall(updateHealth, f)
        pcall(updatePower, f)
        if InCombatLockdown() then pendingApply = true else applyUnit(f) end
        if lib then lib:RefreshFrameSettings(f) end
    end
end

---------------------------------------------------------------------------
-- Frame creation (art and numbers from Blizzard's PlayerFrame.xml / TargetFrame.xml)
---------------------------------------------------------------------------
local function createFrame(unit)
    local isPlayer = (unit == "player")
    local f
    local name = "WebbyFrames_" .. unit
    if not pcall(function() f = CreateFrame("Button", name, UIParent, "SecureUnitButtonTemplate,PingableUnitFrameTemplate") end) or not f then
        f = CreateFrame("Button", name, UIParent, "SecureUnitButtonTemplate")
    end
    f.unit, f.baseUnit = unit, unit
    f:SetSize(232, 100)
    f:SetFrameStrata("LOW")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:RegisterForClicks("AnyUp")
    f:SetAttribute("unit", unit)
    f:SetAttribute("type1", "target")
    f:SetAttribute("type2", "togglemenu")
    f:SetPoint(DEFAULT_POS[unit].point, UIParent, DEFAULT_POS[unit].point, DEFAULT_POS[unit].x, DEFAULT_POS[unit].y)

    -- portrait (under the border) and its mask; sizes/anchors are set by applyLayout
    f.portrait = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    f.pmask = f:CreateMaskTexture()
    f.portrait:AddMaskTexture(f.pmask)

    -- reaction-coloured name plate, used by the right-portrait layout only
    if not isPlayer and hasAtlas(TARGET_PREFIX .. "-Type") then
        f.plate = f:CreateTexture(nil, "BACKGROUND", nil, 2)
        f.plate:SetAtlas(TARGET_PREFIX .. "-Type", true)
        f.plate:SetPoint("TOPRIGHT", f, "TOPRIGHT", -75, -25)
    end

    -- the border and pointed frame art
    f.border = f:CreateTexture(nil, "BACKGROUND", nil, 3)
    f.border:SetTexelSnappingBias(0)
    f.border:SetSnapToPixelGrid(false)

    -- bars
    f.hp, f.hpMask = newBar(f)
    f.mp, f.mpMask = newBar(f)

    -- text above everything
    local ov = CreateFrame("Frame", nil, f)
    ov:SetAllPoints()
    ov:SetFrameLevel(f:GetFrameLevel() + 5)
    f.hpText = ov:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
    f.hpText:SetPoint("CENTER", f.hp, "CENTER")
    f.mpText = ov:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
    f.name = ov:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.name:SetJustifyH("LEFT")
    f.name:SetWordWrap(false)
    f.name:SetMaxLines(1)
    f.level = ov:CreateFontString(nil, "OVERLAY", "GameNormalNumberFont")
    f.level:SetDrawLayer("OVERLAY", 3)
    if hasAtlas("UI-HUD-UnitFrame-SmallCircle") then
        f.badge = ov:CreateTexture(nil, "OVERLAY", nil, -1)
        f.badge:SetAtlas("UI-HUD-UnitFrame-SmallCircle")
    end

    -- corner decoration of the left-portrait art (only where the client has it)
    if hasAtlas(PLAYER_PREFIX .. "-CornerEmbellishment") then
        f.corner = ov:CreateTexture(nil, "OVERLAY", nil, 1)
        f.corner:SetAtlas(PLAYER_PREFIX .. "-CornerEmbellishment", true)
        f.corner:SetPoint("TOPLEFT", f, "TOPLEFT", 58.5, -53.5)
    end

    f.ov = ov
    if unit ~= "player" then
        f.flash = ov:CreateTexture(nil, "OVERLAY", nil, -3)
        f.flash:Hide()
        pcall(function()
            local ag = f.flash:CreateAnimationGroup()
            ag:SetLooping("BOUNCE")
            local a = ag:CreateAnimation("Alpha")
            a:SetFromAlpha(0.15); a:SetToAlpha(0.85); a:SetDuration(0.35)
            f.flashAnim = ag
        end)
    end
    -- resting "Z" on the player frame, only while you are resting
    if isPlayer and hasAtlas("UI-HUD-UnitFrame-Player-Rest-Flipbook") then
        local rest = CreateFrame("Frame", nil, f)
        rest:SetSize(20, 20)
        rest:SetPoint("TOPLEFT", f, "TOPLEFT", 64, -6)
        rest:SetFrameLevel(f:GetFrameLevel() + 6)
        local tex = rest:CreateTexture(nil, "ARTWORK")
        tex:SetAtlas("UI-HUD-UnitFrame-Player-Rest-Flipbook")
        tex:SetSize(30, 30)
        tex:SetPoint("CENTER")
        local anim
        pcall(function()
            local ag = tex:CreateAnimationGroup()
            ag:SetLooping("REPEAT")
            local a = ag:CreateAnimation("FlipBook")
            a:SetFlipBookRows(7); a:SetFlipBookColumns(6); a:SetFlipBookFrames(42)
            a:SetDuration(1.5)
            a:SetFlipBookFrameWidth(0); a:SetFlipBookFrameHeight(0)
            anim = ag
        end)
        f.updateRest = function()
            local resting = IsResting() and getSetting("player", "showRest")
            rest:SetShown(resting and true or false)
            if anim then if resting then anim:Play() else anim:Stop() end end
        end
        f:RegisterEvent("PLAYER_UPDATE_RESTING")
    end

    -- hover: used by the "show on mouseover" text mode
    f:HookScript("OnEnter", function(self) self.hover = true end)
    f:HookScript("OnLeave", function(self)
        self.hover = false; self.hoverHP = false; self.hoverMP = false; refreshText(self)
    end)
    -- "show on mouseover" works per bar: numbers appear only on the bar under the cursor
    f:HookScript("OnUpdate", function(self)
        if not self.hover then return end
        local hp, mp = false, false
        pcall(function()
            local cx, cy = GetCursorPosition()
            local function over(bar)
                local sc = bar:GetEffectiveScale()
                local l, b, w, h = bar:GetRect()
                if not (l and sc and sc > 0) then return false end
                local x, y = cx / sc, cy / sc
                return x >= l and x <= l + w and y >= b and y <= b + h
            end
            hp = over(self.hp)
            mp = over(self.mp)
            if not hp and not mp then
                hp = MouseIsOver(self.hp) and true or false
                mp = MouseIsOver(self.mp) and true or false
            end
        end)
        if hp ~= self.hoverHP or mp ~= self.hoverMP then
            self.hoverHP, self.hoverMP = hp, mp
            refreshText(self)
        end
    end)

    -- events
    f:SetScript("OnEvent", function(self, event)
        if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then updateHealth(self)
        elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then updatePower(self)
        elseif event == "PLAYER_UPDATE_RESTING" then
            if self.updateRest then self.updateRest() end
            updateIndicators(self)
        elseif event == "PLAYER_REGEN_DISABLED" then self.combatFlag = true; updateIndicators(self)
        elseif event == "PLAYER_REGEN_ENABLED" then self.combatFlag = false; updateIndicators(self)
        elseif event == "PLAYER_FLAGS_CHANGED" or event == "UNIT_FLAGS" then updateIndicators(self)
        elseif event:find("^UNIT_SPELLCAST") then updateFlash(self)
        elseif event:find("^UNIT_THREAT") then updateThreat(self)
        else updateAll(self) end
    end)
    for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
                         "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED", "UNIT_FACTION" }) do
        pcall(f.RegisterUnitEvent, f, e, unit)
    end
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    if unit == "target" then f:RegisterEvent("PLAYER_TARGET_CHANGED") end
    if unit == "focus" then f:RegisterEvent("PLAYER_FOCUS_CHANGED") end

    createIndicators(f)
    if isPlayer then
        for _, e in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_FLAGS_CHANGED" }) do f:RegisterEvent(e) end
    end
    pcall(f.RegisterUnitEvent, f, "UNIT_FLAGS", unit)
    if unit ~= "player" then
        pcall(f.RegisterUnitEvent, f, "UNIT_THREAT_SITUATION_UPDATE", unit)
        pcall(f.RegisterUnitEvent, f, "UNIT_THREAT_LIST_UPDATE", unit)
        for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
                             "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START",
                             "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" }) do
            pcall(f.RegisterUnitEvent, f, e, unit)
        end
    end

    if unit ~= "player" then RegisterUnitWatch(f) end
    frames[unit] = f
    applyLayout(f)
    if f.updateRest then f.updateRest() end
    updateAll(f)
end

---------------------------------------------------------------------------
-- Small frame: target of target (art and numbers from Blizzard's TargetFrame.xml)
---------------------------------------------------------------------------
local function createSmallFrame(unit)
    local f
    local name = "WebbyFrames_" .. unit
    if not pcall(function() f = CreateFrame("Button", name, UIParent, "SecureUnitButtonTemplate,PingableUnitFrameTemplate") end) or not f then
        f = CreateFrame("Button", name, UIParent, "SecureUnitButtonTemplate")
    end
    f.unit, f.baseUnit, f.small = unit, unit, true
    f.prefix = TOT_PREFIX
    f.layoutLeft = true
    f.hpAtlas = TOT_PREFIX .. "-Bar-Health"
    f.hpStatusAtlas = TOT_PREFIX .. "-Bar-Health-Status"
    if not hasAtlas(f.hpStatusAtlas) then f.hpStatusAtlas = f.hpAtlas end
    f:SetSize(120, 49)
    f:SetFrameStrata("LOW")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:RegisterForClicks("AnyUp")
    f:SetAttribute("unit", unit)
    f:SetAttribute("type1", "target")
    f:SetAttribute("type2", "togglemenu")
    f:SetPoint(DEFAULT_POS[unit].point, UIParent, DEFAULT_POS[unit].point, DEFAULT_POS[unit].x, DEFAULT_POS[unit].y)
    f:SetHitRectInsets(0, 6, 4, 4)

    -- portrait, circle mask, border
    f.portrait = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    f.portrait:SetSize(37, 37)
    f.portrait:SetPoint("TOPLEFT", f, "TOPLEFT", 5, -5)
    f.pmask = f:CreateMaskTexture()
    if hasAtlas("CircleMask") then f.pmask:SetAtlas("CircleMask") else
        f.pmask:SetTexture(CIRCLE_FALLBACK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    end
    f.pmask:SetPoint("TOPLEFT", f.portrait, "TOPLEFT", 0, 0)
    f.pmask:SetPoint("BOTTOMRIGHT", f.portrait, "BOTTOMRIGHT", 0, 0)
    f.portrait:AddMaskTexture(f.pmask)

    f.border = f:CreateTexture(nil, "BACKGROUND", nil, 3)
    f.border:SetTexelSnappingBias(0)
    f.border:SetSnapToPixelGrid(false)
    if hasAtlas(TOT_PREFIX) then
        stockAtlas(f.border, TOT_PREFIX, true)
        f.border:SetPoint("CENTER", f, "CENTER", 0, 0)
    else
        f.border:SetColorTexture(0, 0, 0, 0.5)
        f.border:SetSize(110, 40)
        f.border:SetPoint("CENTER", f, "CENTER", 0, 0)
    end

    -- bars
    f.hp, f.hpMask = newBar(f)
    f.hpMaskOn = layoutBar(f.hp, f.hpMask, 70, 10, "TOPLEFT", f, "TOPLEFT", 44, -17, SMALL_MASK_HEALTH, -29, 3)
    f.mp, f.mpMask = newBar(f)
    f.mpMaskOn = layoutBar(f.mp, f.mpMask, 74, 7, "TOPLEFT", f, "TOPLEFT", 40, -28, SMALL_MASK_MANA, -27, 4)

    -- text
    local ov = CreateFrame("Frame", nil, f)
    ov:SetAllPoints()
    ov:SetFrameLevel(f:GetFrameLevel() + 5)
    f.hpText = ov:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
    f.hpText:SetPoint("CENTER", f.hp, "CENTER")
    f.mpText = ov:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
    f.mpText:SetPoint("CENTER", f.mp, "CENTER", 2, 0)
    f.name = ov:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.name:SetSize(68, 10)
    f.name:SetJustifyH("LEFT")
    f.name:SetPoint("TOPLEFT", f.portrait, "TOPRIGHT", 2, 0)
    f.level = ov:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")   -- not shown on this frame, kept so shared code works
    f.level:Hide()
    -- scaled-down corner accent on the small portrait ring (37px vs the player's 60px)
    if hasAtlas(PLAYER_PREFIX .. "-CornerEmbellishment") then
        f.corner = ov:CreateTexture(nil, "OVERLAY", nil, 1)
        f.corner:SetAtlas(PLAYER_PREFIX .. "-CornerEmbellishment", true)
        local w, h = f.corner:GetSize()
        if type(w) == "number" and type(h) == "number" and w > 0 then f.corner:SetSize(w * 0.62, h * 0.62) end
        f.corner:SetPoint("TOPLEFT", f, "TOPLEFT", 26.3, -26.3)
    end

    f:HookScript("OnEnter", function(self) self.hover = true end)
    f:HookScript("OnLeave", function(self)
        self.hover = false; self.hoverHP = false; self.hoverMP = false; refreshText(self)
    end)
    -- "show on mouseover" works per bar: numbers appear only on the bar under the cursor
    f:HookScript("OnUpdate", function(self)
        if not self.hover then return end
        local hp, mp = false, false
        pcall(function()
            local cx, cy = GetCursorPosition()
            local function over(bar)
                local sc = bar:GetEffectiveScale()
                local l, b, w, h = bar:GetRect()
                if not (l and sc and sc > 0) then return false end
                local x, y = cx / sc, cy / sc
                return x >= l and x <= l + w and y >= b and y <= b + h
            end
            hp = over(self.hp)
            mp = over(self.mp)
            if not hp and not mp then
                hp = MouseIsOver(self.hp) and true or false
                mp = MouseIsOver(self.mp) and true or false
            end
        end)
        if hp ~= self.hoverHP or mp ~= self.hoverMP then
            self.hoverHP, self.hoverMP = hp, mp
            refreshText(self)
        end
    end)

    f:SetScript("OnEvent", function(self, event)
        if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then updateHealth(self)
        elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then updatePower(self)
        else updateAll(self) end
    end)
    for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
                         "UNIT_NAME_UPDATE", "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED", "UNIT_FACTION" }) do
        pcall(f.RegisterUnitEvent, f, e, unit)
    end
    if unit == "pet" then
        pcall(f.RegisterUnitEvent, f, "UNIT_PET", "player")
    elseif unit == "focustarget" then
        pcall(f.RegisterUnitEvent, f, "UNIT_TARGET", "focus")
        f:RegisterEvent("PLAYER_FOCUS_CHANGED")
    else
        pcall(f.RegisterUnitEvent, f, "UNIT_TARGET", "target")   -- the target changed who it is targeting
    end
    f:RegisterEvent("PLAYER_TARGET_CHANGED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")

    RegisterUnitWatch(f)
    frames[unit] = f
    updateAll(f)
end

---------------------------------------------------------------------------
-- Edit Mode (LibEditMode)
---------------------------------------------------------------------------
-- Target and focus only exist while you have one, so while Edit Mode is open
-- they show the player's data as a stand-in, to give you something to move.
local function enterSample()
    if InCombatLockdown() then return end
    for _, unit in ipairs({ "target", "targettarget", "focus", "focustarget", "pet" }) do
        local f = frames[unit]
        if f then
            UnregisterUnitWatch(f)
            f.unit = "player"
            f:Show()
            updateAll(f)
        end
    end
end

local function exitSample()
    if InCombatLockdown() then return end
    for _, unit in ipairs({ "target", "targettarget", "focus", "focustarget", "pet" }) do
        local f = frames[unit]
        if f then
            f.unit = f.baseUnit
            RegisterUnitWatch(f)
            updateAll(f)
        end
    end
end

local function checkbox(unit, ST, label, key, desc)
    return {
        name = label, kind = ST.Checkbox, default = defaultFor(unit, key), desc = desc,
        get = function() return getSetting(unit, key) end,
        set = function(_, v) setSetting(unit, key, v and true or false) end,
    }
end

local function setupEditMode()
    local ok, l = pcall(LibStub, "LibEditMode")
    if not ok or not l then
        print("|cffff9900Webby Frames:|r Edit Mode library failed to load; use the AddOns settings page instead.")
        return
    end
    lib = l
    local ST = lib.SettingType

    for _, unit in ipairs(UNITS) do
        local f = frames[unit]
        local d = DEFAULT_POS[unit]
        lib:AddFrame(f, function(_, layoutName, point, x, y)
            local u = unitData(unit, true, layoutName)
            u.point, u.x, u.y = point, x, y
        end, { point = d.point, x = d.x, y = d.y }, "Webby " .. UNIT_LABEL[unit] .. " Frame")

        local list = {
            {
                name = "Scale", kind = ST.Slider, default = 1,
                minValue = 0.5, maxValue = 2, valueStep = 0.05,
                formatter = function(v) return math.floor(v * 100 + 0.5) / 100 end,
                get = function() return getSetting(unit, "scale") end,
                set = function(_, v) setSetting(unit, "scale", v) end,
            },
            checkbox(unit, ST, "Show name", "showName"),
            checkbox(unit, ST, "Corner accent", "cornerAccent"),
            checkbox(unit, ST, "PvP flag indicator", "showPvP"),
            unit ~= "player" and checkbox(unit, ST, "Flash on interruptible cast", "flashInterrupt", "Pulse the frame red while the unit casts a spell you can interrupt.") or false,
            unit ~= "player" and checkbox(unit, ST, "Threat indicator", "showThreat", "A small box with your threat percentage, coloured by threat status, on hostile units.") or false,
            unit == "player" and checkbox(unit, ST, "Combat indicator", "showCombat") or false,
            unit == "player" and checkbox(unit, ST, "Resting indicator", "showRest") or false,
            hasSideOption(unit) and {
                name = "Portrait side", kind = ST.Dropdown, default = "left",
                desc = "Which side of the frame the portrait sits on.",
                values = { { text = "Left", value = "left" }, { text = "Right", value = "right" } },
                get = function() return getSetting(unit, "portraitSide") end,
                set = function(_, v) setSetting(unit, "portraitSide", v) end,
            } or false,
            {
                name = "Bar text", kind = ST.Dropdown, default = defaultFor(unit, "textMode"),
                desc = "When the numbers on the bars are shown. Mouseover works per bar: only the bar under the cursor shows its number.",
                values = {
                    { text = "Always show", value = "always" },
                    { text = "Show on mouseover", value = "mouseover" },
                    { text = "Off", value = "off" },
                },
                get = function() return getSetting(unit, "textMode") end,
                set = function(_, v) setSetting(unit, "textMode", v) end,
            },
            {
                name = "Bar texture", kind = ST.Dropdown, default = "default",
                desc = "The fill texture of the health and power bars.",
                values = function()
                    local v = {}
                    for _, c in ipairs(textureChoices()) do v[#v + 1] = { text = c[2], value = c[1] } end
                    return v
                end,
                get = function() return getSetting(unit, "barTexture") end,
                set = function(_, v) setSetting(unit, "barTexture", v) end,
            },
            {
                name = "Font", kind = ST.Dropdown, default = "default",
                desc = "Font for the name and bar numbers. Each entry previews in its own font.",
                values = function()
                    local v = {}
                    for _, c in ipairs(fontChoices()) do v[#v + 1] = { text = c[2], value = c[1] } end
                    return v
                end,
                generator = function(_, root)
                    for _, c in ipairs(fontChoices()) do
                        local value, text, path = c[1], c[2], c[3]
                        local r = root:CreateRadio(text,
                            function() return getSetting(unit, "font") == value end,
                            function() setSetting(unit, "font", value) end)
                        pcall(function()
                            r:AddInitializer(function(button)
                                local fs = button.fontString or button.Text
                                if fs and path then pcall(fs.SetFont, fs, path, 12, "") end
                            end)
                        end)
                    end
                end,
                get = function() return getSetting(unit, "font") end,
                set = function(_, v) setSetting(unit, "font", v) end,
            },
            {
                name = "Bar text format", kind = ST.Dropdown, default = defaultFor(unit, "textFormat"),
                desc = "Totals (12.3K), percentages (85%), or both.",
                values = {
                    { text = "Total", value = "value" },
                    { text = "Percentage", value = "percent" },
                    { text = "Both", value = "both" },
                },
                get = function() return getSetting(unit, "textFormat") end,
                set = function(_, v) setSetting(unit, "textFormat", v) end,
            },
            checkbox(unit, ST, "Class colour for players, reaction colour for NPCs", "smartColor",
                "Players always use their class colour. NPCs use reaction colour (friend, neutral, hostile)."),
            checkbox(unit, ST, "Class colour", "classColor", "Colour the health bar by class (players only)."),
            checkbox(unit, ST, "Reaction colour", "reactionColor", "Colour the health bar by friend, neutral or hostile."),
            {
                name = "Health colour fade", kind = ST.Dropdown, default = "off",
                desc = "Change the health bar colour as health drops.",
                values = {
                    { text = "Off", value = "off" },
                    { text = "Green, yellow, orange, red", value = "classic" },
                    { text = "Your colour, yellow, orange, red", value = "reactive" },
                },
                get = function() return getSetting(unit, "healthFade") end,
                set = function(_, v) setSetting(unit, "healthFade", v) end,
            },
        }
        local compact = {}
        for i = 1, 12 do if list[i] then compact[#compact + 1] = list[i] end end
        lib:AddFrameSettings(f, compact)
    end

    lib:RegisterCallback("layout", function(layoutName)
        activeLayout = layoutName
        applyAll()
    end)
    lib:RegisterCallback("enter", enterSample)
    lib:RegisterCallback("exit", exitSample)
end

---------------------------------------------------------------------------
-- Actions used by the settings pages and slash commands
---------------------------------------------------------------------------
local COPY_KEYS = { "scale", "showName", "cornerAccent", "portraitSide", "textMode", "textFormat", "barTexture", "font",  "showCombat", "showRest", "showPvP", "flashInterrupt", "showThreat",
                    "smartColor", "classColor", "reactionColor", "healthFade" }

local function resetFrame(unit)
    if InCombatLockdown() then print("|cff33ccffWebby Frames:|r can't reset in combat."); return end
    local l = DB.layouts and DB.layouts[activeLayout]
    if l then l[unit] = nil end
    local f = frames[unit]
    if f then
        f.layoutLeft = nil            -- force the layout to be rebuilt
        applyUnit(f)
        pcall(updateAll, f)
        if lib then lib:RefreshFrameSettings(f) end
    end
end

local function copySettings(from, to)
    if InCombatLockdown() then print("|cff33ccffWebby Frames:|r can't copy in combat."); return end
    for _, key in ipairs(COPY_KEYS) do
        local v = getSetting(from, key)
        if from == "player" and key == "portraitSide" then v = nil end   -- the player frame has no side option
        if v ~= nil then unitData(to, true)[key] = v end
    end
    local f = frames[to]
    if f then
        f.layoutLeft = nil
        applyUnit(f)
        pcall(updateAll, f)
        if lib then lib:RefreshFrameSettings(f) end
    end
end

local function openEditMode()
    pcall(function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        if GameMenuFrame and GameMenuFrame:IsShown() then HideUIPanel(GameMenuFrame) end
        ShowUIPanel(EditModeManagerFrame)
    end)
end

---------------------------------------------------------------------------
-- Settings pages (Esc > Options > AddOns > Webby Frames)
--   General, Player, Target, Focus
---------------------------------------------------------------------------
local TEXT_MODES   = { { "always", "Always show" }, { "mouseover", "Show on mouseover" }, { "off", "Off" } }
local TEXT_FORMATS = { { "value", "Total  (12.3K)" }, { "percent", "Percentage  (85%)" }, { "both", "Both  (12.3K (85%))" } }
local SIDES        = { { "left", "Left" }, { "right", "Right" } }

local function unitProxy(unit)
    return setmetatable({}, {
        __index = function(_, k) return getSetting(unit, k) end,
        __newindex = function(_, k, v) setSetting(unit, k, v) end,
    })
end

local function addonVersion()
    local v
    pcall(function() v = C_AddOns.GetAddOnMetadata("WebbyFrames", "Version") end)
    return v or "?"
end

local function openSettings()
    if settingsCategory and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(settingsCategory:GetID())
    else
        print("|cff33ccffWebby Frames:|r settings page not available. Use Edit Mode to move and scale the frames.")
    end
end

local function buildSettings()
    local root, rootLayout = Settings.RegisterVerticalLayoutCategory("Webby Frames")
    settingsCategory = root

    -- small builders; every setting reads and writes through a proxy table
    local function builders(category, layout, proxy, prefix)
        local B = {}
        function B.header(text)
            if layout and CreateSettingsListSectionHeaderInitializer then
                layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
            end
        end
        function B.check(key, label, tip, default)
            local st = Settings.RegisterAddOnSetting(category, prefix .. key, key, proxy, Settings.VarType.Boolean, label, default)
            Settings.CreateCheckbox(category, st, tip)
        end
        function B.slider(key, label, tip, default, lo, hi, step)
            local st = Settings.RegisterAddOnSetting(category, prefix .. key, key, proxy, Settings.VarType.Number, label, default)
            local o = Settings.CreateSliderOptions(lo, hi, step)
            o:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v) return string.format(step >= 1 and "%d" or "%.2f", v) end)
            Settings.CreateSlider(category, st, o, tip)
        end
        function B.dropdown(key, label, tip, default, choices)
            local st = Settings.RegisterAddOnSetting(category, prefix .. key, key, proxy, Settings.VarType.String, label, default)
            Settings.CreateDropdown(category, st, function()
                local c = Settings.CreateControlTextContainer()
                local list = type(choices) == "function" and choices() or choices
                for _, ch in ipairs(list) do c:Add(ch[1], ch[2]) end
                return c:GetData()
            end, tip)
        end
        function B.button(label, text, onClick, tip)
            if layout and CreateSettingsButtonInitializer then
                layout:AddInitializer(CreateSettingsButtonInitializer(label, text, onClick, tip, true))
            end
        end
        return B
    end

    -- General -------------------------------------------------------------
    do
        local general = setmetatable({}, {
            __index = function(_, k) if k == "enabled" then return DB.enabled ~= false end end,
            __newindex = function(_, k, v) if k == "enabled" then DB.enabled = v and true or false end end,
        })
        local B = builders(root, rootLayout, general, "WEBBY_general_")
        B.header("Webby Frames  v" .. addonVersion())
        B.check("enabled", "Enable Webby Frames", "Replaces Blizzard's player, target and focus frames. Needs /reload to take effect.", true)
        B.header("Layouts and positions")
        B.button("Edit Mode", "Open Edit Mode", openEditMode,
            "Drag the frames where you want them. Scale, name, text and colour options are in each frame's Edit Mode dialog too.")
        B.button("Reset everything", "Reset all frames", function()
            for _, unit in ipairs(UNITS) do resetFrame(unit) end
        end, "Puts all three frames back to their defaults (settings and positions) for the current Edit Mode layout.")
        B.header("Settings are saved per Edit Mode layout, so each layout can have its own positions and options.")
        B.header("Commands:  /webby  opens this window    /webby edit  opens Edit Mode    /webby reset  resets all frames")
    end

    -- one page per frame ----------------------------------------------------
    local PAGE_TEXT = {
        player = "Your own frame.",
        target = "The unit you are targeting.",
        targettarget = "Who your target is targeting.",
        focus  = "Your focus target.",
        pet    = "Your pet.",
        focustarget = "Who your focus is targeting.",
    }
    for _, unit in ipairs(UNITS) do
        local sub, subLayout = Settings.RegisterVerticalLayoutSubcategory(root, UNIT_LABEL[unit])
        local B = builders(sub, subLayout, unitProxy(unit), "WEBBY_" .. unit .. "_")

        B.header(UNIT_LABEL[unit] .. " frame  -  " .. PAGE_TEXT[unit])

        B.header("Layout")
        B.slider("scale", "Scale", "Size of the " .. unit .. " frame.", 1, 0.5, 2, 0.05)
        if hasSideOption(unit) then
            B.dropdown("portraitSide", "Portrait side",
                "Left uses the player-frame art. Right uses Retail's target-frame art with the name plate.", "left", SIDES)
        end
        B.check("showName", "Show name", "Show the unit's name (and the name plate on the right-portrait layout).", true)
        B.check("cornerAccent", "Corner accent", "The small pointed accent on the portrait ring. Off leaves just the level circle.", true)
        B.check("showPvP", "PvP flag indicator", "Show the faction (or free-for-all) badge beside the portrait while the unit is PvP flagged.", true)
        if unit ~= "player" and unit ~= "targettarget" and unit ~= "focustarget" and unit ~= "pet" then
            B.check("flashInterrupt", "Flash on interruptible cast", "Pulse the frame red while the unit casts a spell you can interrupt.", true)
            B.check("showThreat", "Threat indicator", "A small box with your threat percentage, coloured by threat status, on hostile units.", true)
        end
        if unit == "player" then
            B.check("showCombat", "Combat indicator", "Show the crossed-swords icon on the portrait while you are in combat.", true)
            B.check("showRest", "Resting indicator", "Show the Zzz icon while you are resting.", true)
        end

        B.header("Bar text")
        B.dropdown("textMode", "Show numbers", "When the numbers on the bars are shown.", defaultFor(unit, "textMode"), TEXT_MODES)
        B.dropdown("barTexture", "Bar texture", "Fill texture for the health and power bars. Includes any textures registered with SharedMedia.", "default", textureChoices)
        B.dropdown("font", "Font", "Font for the name and bar numbers. Includes fonts registered with SharedMedia.", "default",
            function() local l = {}; for _, c in ipairs(fontChoices()) do l[#l + 1] = { c[1], c[2] } end; return l end)
        B.dropdown("textFormat", "Number format", "Totals, percentages, or both.", defaultFor(unit, "textFormat"), TEXT_FORMATS)

        B.header("Health bar colour")
        B.check("smartColor", "Class colour for players, reaction colour for NPCs",
            "Players always use their class colour. NPCs use reaction colour (friend, neutral, hostile).", true)
        B.check("classColor", "Always use class colour", "Colour players by class everywhere. Used if the option above is off.", false)
        B.check("reactionColor", "Always use reaction colour", "Colour by friend, neutral or hostile everywhere.", false)
        B.dropdown("healthFade", "Health colour fade", "Change the health bar colour as health drops. \"Green, yellow, red\" is the classic gradient; \"Your colour, yellow, orange, red\" starts from the class / reaction colour.", "off",
            { { "off", "Off" }, { "classic", "Green, yellow, orange, red" }, { "reactive", "Your colour, yellow, orange, red" } })

        B.header("Actions")
        if unit ~= "player" then
            B.button("Copy settings", "Copy from Player frame", function() copySettings("player", unit) end,
                "Copies scale, name, text and colour options from the player frame (not the position).")
        end
        B.button("Reset", "Reset this frame", function() resetFrame(unit) end,
            "Puts this frame back to its defaults, including its position, for the current Edit Mode layout.")
    end

    Settings.RegisterAddOnCategory(root)
end

-- Entry in the minimap addon compartment (needs the TOC fields below).
function WebbyFrames_OnCompartmentClick() openSettings() end

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------
local hider = CreateFrame("Frame"); hider:Hide()
local hiddenFrames = {}
local function hideBlizzard(frame)
    if not frame then return end
    pcall(function()
        frame:UnregisterAllEvents()
        frame:SetParent(hider)
        frame:SetAlpha(0)
        frame:Hide()
        if not hiddenFrames[frame] then
            hiddenFrames[frame] = true
            hooksecurefunc(frame, "Show", function(self)
                if not InCombatLockdown() then self:Hide() end
                self:SetAlpha(0)
            end)
        end
    end)
end
local function hideAllBlizzard()
    hideBlizzard(_G.PlayerFrame); hideBlizzard(_G.TargetFrame); hideBlizzard(_G.FocusFrame)
    hideBlizzard(_G.TargetFrameToT); hideBlizzard(_G.FocusFrameToT); hideBlizzard(_G.PetFrame)
end

local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:RegisterEvent("PLAYER_REGEN_ENABLED")
init:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingApply then applyAll() end
        return
    end

    DB = WebbyFramesDB
    if not pcall(buildSettings) then
        print("|cffff9900Webby Frames:|r couldn't build the settings page; Edit Mode still works.")
    end
    if DB.enabled == false then return end

    for _, unit in ipairs(UNITS) do
        if unit == "targettarget" or unit == "focustarget" or unit == "pet" then createSmallFrame(unit) else createFrame(unit) end
    end
    hideAllBlizzard()
    C_Timer.After(2, hideAllBlizzard)
    setupEditMode()
    applyAll()
    print("|cff33ccffWebby Frames|r v" .. addonVersion() .. " loaded. Type |cff33ccff/webby|r for settings.")
end)

SLASH_WEBBYFRAMES1 = "/webby"
SlashCmdList.WEBBYFRAMES = function(msg)
    msg = (msg or ""):lower():match("^%s*(%S*)") or ""
    if msg == "edit" then
        openEditMode()
    elseif msg == "reset" then
        for _, unit in ipairs(UNITS) do resetFrame(unit) end
        print("|cff33ccffWebby Frames:|r frames reset.")
    elseif msg == "debug" then
        for _, u in ipairs(UNITS) do
            local f = frames[u]
            if not f then print(u, "NO FRAME")
            else
                local p, _, rp, x, y = f:GetPoint()
                print(u, "shown", tostring(f:IsShown()), "visible", tostring(f:IsVisible()), "alpha", f:GetAlpha(),
                    "size", math.floor(f:GetWidth()), math.floor(f:GetHeight()), "pt", tostring(p), tostring(x), tostring(y),
                    "strata", f:GetFrameStrata(), "badge", tostring(f.badge and f.badge:IsShown()), "corner", tostring(f.corner and f.corner:IsShown()))
            end
        end
        for _, u in ipairs(UNITS) do
            local f = frames[u]
            local c = f and f.corner
            if c then
                local p, _, rp, x, y = c:GetPoint()
                local ok, l, t, _, _, r, b = pcall(c.GetTexCoord, c)
                print("corner", u, "shown", tostring(c:IsShown()), "w", c:GetWidth(), "h", c:GetHeight(), "pt", tostring(p), tostring(x), tostring(y),
                    "tex", tostring(c:GetTexture()), "atlas", tostring(c:GetAtlas()), "left", tostring(f.layoutLeft), "setting", tostring(getSetting(u, "cornerAccent")))
            end
        end
        local pf = _G.PlayerFrame
        if pf then print("Blizzard PlayerFrame shown", tostring(pf:IsShown()), "alpha", pf:GetAlpha(), "parent", tostring(pf:GetParent() and pf:GetParent():GetName())) end
        print("Version", addonVersion())
    elseif msg == "atlas" then
        local names = {
            PLAYER_PREFIX, PLAYER_PREFIX .. "-CornerEmbellishment", "UI-HUD-UnitFrame-SmallCircle", PLAYER_PREFIX .. "-Bar-Health",
            PLAYER_PREFIX .. "-Bar-Health-Mask", PLAYER_PREFIX .. "-Bar-Mana", PLAYER_PREFIX .. "-Bar-Mana-Mask",
            "UI-HUD-UnitFrame-Player-Portrait-Mask", TARGET_PREFIX, TARGET_PREFIX .. "-Bar-Health-Mask",
            TARGET_PREFIX .. "-Bar-Mana-Mask", TOT_PREFIX, SMALL_MASK_HEALTH, SMALL_MASK_MANA,
        }
        for _, n in ipairs(names) do
            local info; pcall(function() info = C_Texture.GetAtlasInfo(n) end)
            local extra = info and (" file=" .. tostring(info.file or info.filename) .. " " .. tostring(info.width) .. "x" .. tostring(info.height)) or ""
            print((hasAtlas(n) and "|cff00ff00OK|r  " or "|cffff0000MISSING|r  ") .. n .. extra)
        end
    elseif msg == "help" then
        print("|cff33ccffWebby Frames:|r /webby (settings)   /webby atlas (art check)   /webby edit (Edit Mode)   /webby reset (reset all frames)")
    else
        openSettings()
    end
end
