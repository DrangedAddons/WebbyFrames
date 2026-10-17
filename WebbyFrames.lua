-- Webby Frames
-- Frame art, bar fills and masks are DragonflightUI's bundled copies of the Retail art (Media\).
-- Draws its own player / target / target of target / focus / focus target / pet frames using Blizzard's built-in Retail
-- unit frame art (atlases), so the border and the pointed bars match Retail and
-- no other addon is needed. Layout numbers come from Blizzard's PlayerFrame.xml
-- and TargetFrame.xml. Position and options are editable in Edit Mode (bundled
-- LibEditMode) and in Esc > Options > AddOns > Webby Frames, saved per layout.

-- carry settings over from the old DFFramesForever name, once
WebbyFramesDB = WebbyFramesDB or DFFramesForeverDB or {}

local UNITS = { "player", "target", "targettarget", "focus", "focustarget", "pet" }
local UNIT_LABEL = { player = "Player", target = "Target", targettarget = "Target of Target", focus = "Focus", focustarget = "Focus Target", pet = "Pet", party = "Party" }
-- Party: four small frames (party1-4) stacked in one container; they share the "party" options.
local PARTY = { "party1", "party2", "party3", "party4" }
local PARTY_GAP = 10
-- everything with its own options page and Edit Mode mover
local OPTION_UNITS = { "player", "target", "targettarget", "focus", "focustarget", "pet", "party" }
-- Portrait side is fixed per frame: target and focus have it on the right (Retail's target art),
-- the player and the small frames on the left.
local function portraitOnLeft(unit) return unit ~= "target" and unit ~= "focus" end
local function isSmall(unit) return unit == "targettarget" or unit == "focustarget" or unit == "pet" or unit == "party" end
-- only the full-size target and focus frames have the interrupt flash and the threat box
local function hasCastAndThreat(unit) return unit == "target" or unit == "focus" end
-- the pointed corner accent is only offered on the player and target frames; the rest keep a round ring
local function hasCorner(unit) return unit == "player" end

local COLOR_MODES = {
    { "smart",    "Class (players), reaction (NPCs)" },
    { "class",    "Class colour (players only)" },
    { "reaction", "Reaction colour" },
    { "plain",    "Plain green" },
}

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
    party  = { point = "TOPLEFT", x = 20,  y = -260 },     -- the party container
}
for _, u in ipairs(PARTY) do DEFAULT_POS[u] = DEFAULT_POS.party end

-- per-frame defaults that differ from DEFAULT_SETTINGS (the small frame is too narrow for long numbers)
local UNIT_DEFAULTS = {
    target = { auraBuffs = true, auraDebuffs = true },
    focus  = { auraBuffs = true, auraDebuffs = true },
    targettarget = { textMode = "off", textFormat = "percent" },
    pet = { textMode = "off", textFormat = "percent" },
    focustarget = { textMode = "off", textFormat = "percent" },
    -- party: just debuffs, a few small ones to the right of each frame
    party = { textMode = "off", textFormat = "percent", auraDebuffs = true, auraSize = 18, auraPerRow = 4, auraMax = 4, auraPos = "right" },
}

local DEFAULT_SETTINGS = {
    scale = 1, showName = true, healthFade = "off", textMode = "always", textFormat = "value", barTexture = "default", font = "default", flashInterrupt = true, showThreat = true,
    -- health bar colour: "smart" (class colour for players, reaction colour for NPCs), "class", "reaction" or "plain"
    colorMode = "smart",
    cornerAccent = true,   -- the pointed accent on the ring (off = just the level circle)
    -- buffs and debuffs (off unless a frame's defaults turn them on)
    auraBuffs = false, auraDebuffs = false, auraMine = false,
    auraSize = 18, auraPerRow = 8, auraMax = 16, auraPos = "below", auraTimers = true,
    -- cast bar (target and focus): Blizzard's own bar, moved under our frame
    castShow = true, castText = true, castIcon = true, castBorder = "bars",
}

-- fallback power bar art names if PowerBarColor doesn't supply one
-- Bundled frame art (from DragonflightUI, MIT, see Media\LICENSE-DragonflightUI.txt). Forever has
-- replaced many Retail unit frame atlases with its own art, so the frames draw these files instead.
local MEDIA = "Interface\\AddOns\\WebbyFrames\\Media\\"
local POWER_FILE = { MANA = "Mana", RAGE = "Rage", ENERGY = "Energy", FOCUS = "Focus", RUNIC_POWER = "RunicPower" }
local BAR_FILE = {   -- fill file prefixes; append Health, Health-Status or a POWER_FILE name
    player = MEDIA .. "UI-HUD-UnitFrame-Player-PortraitOn-Bar-",
    target = MEDIA .. "UI-HUD-UnitFrame-Target-PortraitOn-Bar-",
    small  = MEDIA .. "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-",
}
-- { file, width, height, right tex coord, bottom tex coord } (each image starts at its top left corner)
local ART = {
    playerBorder = { "ui-hud-unitframe-player-portraiton-2x", 198, 71, 396 / 512, 142 / 256 },
    targetBorder = { "ui-hud-unitframe-target-portraiton-2x", 192, 67, 384 / 512, 134 / 256 },
    playerStatus = { "ui-hud-unitframe-player-portraiton-status-2x", 196, 71, 392 / 512, 142 / 256 },
    targetFlash  = { "ui-hud-unitframe-target-portraiton-incombat-2x", 188, 67, 376 / 512, 134 / 256 },
    plate        = { "ui-hud-unitframe-target-portraiton-type-2x", 135, 17.5, 270 / 512, 35 / 64 },
    corner       = { "ui-hud-unitframe-player-portraiton-cornerembellishment-2x", 22, 22, 44 / 64, 44 / 64 },
    smallBorder  = { "ui-hud-unitframe-targetoftarget-portraiton-2x", 120, 49, 240 / 256, 98 / 128 },
}
-- elite / rare / boss dragon around the portrait: tex coords on uiunitframeboss2x, size, x offset from the portrait
local DRAGON = {
    elite     = { 0.001953125, 0.314453125, 0.322265625, 0.630859375, 80, 79, 4 },
    rare      = { 0.00390625, 0.31640625, 0.64453125, 0.953125, 80, 79, 4 },
    worldboss = { 0.001953125, 0.388671875, 0.001953125, 0.31835937, 99, 81, 13 },
}
DRAGON.rareelite = DRAGON.rare

-- Draws an ART entry on a texture, optionally mirrored left to right and scaled.
local function setArt(tex, a, mirror, scale)
    scale = scale or 1
    tex:SetTexture(MEDIA .. a[1])
    if mirror then tex:SetTexCoord(a[4], 0, 0, a[5]) else tex:SetTexCoord(0, a[4], 0, a[5]) end
    tex:SetSize(a[2] * scale, a[3] * scale)
end

-- The corner accent (DragonflightUI's art): its centre relative to the frame's centre, 15.5px in from
-- the portrait centre and 16px below it.
local CORNER_POS = { -46.5, -15 }

-- Points a bar's mask at a bundled mask file and attaches it to the bar's fill.
local function setFileMask(bar, mask, file, w, h, mx, my, mirror)
    mask:SetTexture(MEDIA .. file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    if mirror then mask:SetTexCoord(1, 0, 0, 1) else mask:SetTexCoord(0, 1, 0, 1) end
    mask:SetSize(w, h)
    mask:ClearAllPoints()
    mask:SetPoint("TOPLEFT", bar, "TOPLEFT", mx, my)
    bar:GetStatusBarTexture():AddMaskTexture(mask)
    return true
end

-- The default fills shade their top and bottom rows dark, so they look inset in the bar's slot;
-- a flat custom texture would run up over the frame border. Custom textures therefore get a
-- second, rectangular mask that trims `inset` px off the top and bottom (masks intersect, so the
-- shape mask still gives the ends; the clip reaches past the ends so it never cuts them).
local function setClip(bar, inset)
    bar.clipInset = inset
    bar.clip:ClearAllPoints()
    bar.clip:SetPoint("TOPLEFT", bar, "TOPLEFT", -40, -inset)
    bar.clip:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 40, inset)
end

-- Adds or removes the clip on the bar's current fill.
local function useClip(bar, on)
    local tex = bar:GetStatusBarTexture()
    pcall(tex.RemoveMaskTexture, tex, bar.clip)
    if on and bar.clipInset then tex:AddMaskTexture(bar.clip) end
end
local POWER_ATLAS = {
    MANA = "Mana", RAGE = "Rage", FOCUS = "Focus", ENERGY = "Energy", RUNIC_POWER = "RunicPower",
    LUNAR_POWER = "LunarPower", MAELSTROM = "Maelstrom", INSANITY = "Insanity", FURY = "Fury", PAIN = "Pain",
}

local DB, lib
local frames = {}            -- unit -> frame (frames.party is the party container)
local partyFrames = {}       -- the four party frames, in order
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
    -- 0.56 and older saved three colour checkboxes; read them as the matching colour mode
    if v == nil and key == "colorMode" and u and (u.smartColor ~= nil or u.classColor ~= nil or u.reactionColor ~= nil) then
        if u.smartColor ~= false or (u.classColor and u.reactionColor) then return "smart" end
        if u.classColor then return "class" end
        if u.reactionColor then return "reaction" end
        return "plain"
    end
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

-- Writes "12.3K", "85%" or "12.3K (85%)" depending on the unit's text format.
-- Forever can hand back secret numbers, so every touch is wrapped.
local function setBarText(fs, f, kind)
    local u = f.wfUnit
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


-- Bar with its own mask. The mask is attached later, by the layout code, once its art is known.
local function newBar(f)
    local bar = CreateFrame("StatusBar", nil, f)
    bar:SetFrameLevel(f:GetFrameLevel() + 1)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    local mask = bar:CreateMaskTexture()
    bar.clip = bar:CreateMaskTexture()
    bar.clip:SetTexture("Interface\\Buttons\\WHITE8X8", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    return bar, mask
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
    local u, base = f.wfUnit, f.baseUnit
    local r, g, b

    local tapped
    pcall(function() tapped = (not UnitPlayerControlled(u)) and UnitIsTapDenied(u) end)
    if tapped then return 0.5, 0.5, 0.5 end

    -- the pet's selection colour flips around (neutral / friendly / controlled), so the pet bar is always green
    if base == "pet" then return 0.1, 0.8, 0.1 end

    local mode = getSetting(base, "colorMode")
    -- friendly pets and guardians (on any frame, e.g. targeting your pet): their selection colour
    -- flips between friendly, neutral and "controlled" blue, so they are always green
    if mode ~= "plain" and mode ~= "class" then
        local friendlyPet
        pcall(function() friendlyPet = UnitPlayerControlled(u) and not UnitIsPlayer(u) and not UnitCanAttack("player", u) end)
        if friendlyPet then return 0.1, 0.8, 0.1 end
    end
    if mode == "smart" or mode == "class" then r, g, b = classColorOf(u) end
    -- smart: NPCs (no class) fall back to their reaction colour
    if not r and (mode == "smart" or mode == "reaction") then r, g, b = reactionColorOf(u) end
    return r, g, b
end

-- Dead / ghost / offline, or nil. Status flags are plain booleans, but are still only read inside pcall.
local function unitStatus(u)
    local s
    pcall(function()
        if UnitIsPlayer(u) and UnitIsConnected(u) == false then s = "Offline"
        elseif UnitIsGhost(u) then s = "Ghost"
        elseif UnitIsDead(u) then s = "Dead" end
    end)
    return s
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
    if not (UnitHealthPercent and UnitExists(f.wfUnit)) then return false end
    local curve = getFadeCurve(mode, r or 0.1, g or 0.8, b or 0.1)
    if not curve then return false end
    local ok = pcall(function()
        local color = UnitHealthPercent(f.wfUnit, true, curve)
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
            useClip(f.hp, true)
        end
        pcall(function() f.hp:GetStatusBarTexture():SetDesaturated(false) end)
        if r then f.hp:SetStatusBarColor(r, g, b, 1) else f.hp:SetStatusBarColor(0.1, 0.8, 0.1, 1) end
        applyHealthFade(f, r, g, b)
        return
    end
    if f.hpCurrent ~= want and (f.hpFiles or hasAtlas(want)) then
        f.hpCurrent = want
        f.hp:SetStatusBarTexture(want)
        -- re-attach the mask: replacing the texture drops it
        if f.hpMaskOn then f.hp:GetStatusBarTexture():AddMaskTexture(f.hpMask) end
        useClip(f.hp, false)
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

local refreshText   -- defined with the settings code below

local function updateHealth(f)
    local u = f.wfUnit
    if not UnitExists(u) then return end
    local status = unitStatus(u)
    updateHealthColor(f)
    f.hp:SetMinMaxValues(0, UnitHealthMax(u))
    if status == "Offline" then
        -- offline: a full grey bar, as the default UI does
        f.hp:SetValue(UnitHealthMax(u))
        f.hp:SetStatusBarColor(0.5, 0.5, 0.5, 1)
        pcall(function() f.hp:GetStatusBarTexture():SetDesaturated(true) end)
    else
        f.hp:SetValue(UnitHealth(u))
    end
    if status then f.hpText:SetText(status) else setBarText(f.hpText, f, "hp") end
    if status ~= f.statusText then
        f.statusText = status
        if refreshText then refreshText(f) end
    end
end

local function updatePower(f)
    local u = f.wfUnit
    if not UnitExists(u) then return end
    local _, token = UnitPowerType(u)
    local fill, tinted = f.customTex, true
    if not fill then
        -- the bundled pre-shaped fill for this power type and frame, drawn untinted
        local kind
        pcall(function() kind = POWER_FILE[token] end)
        local base = f.small and BAR_FILE.small or (f.layoutLeft and BAR_FILE.player or BAR_FILE.target)
        fill, tinted = base .. (kind or "Mana"), false
    end
    if f.mpCurrent ~= fill then
        f.mpCurrent = fill
        f.mp:SetStatusBarTexture(fill)
        -- re-attach the mask: replacing the texture drops it
        if f.mpMaskOn then f.mp:GetStatusBarTexture():AddMaskTexture(f.mpMask) end
        useClip(f.mp, tinted)   -- custom textures get trimmed to the slot
    end
    local pr, pg, pb = 1, 1, 1
    if tinted then
        -- a custom texture is plain, so colour it by power type
        pr, pg, pb = 0.1, 0.3, 0.9
        pcall(function()
            local c = PowerBarColor and (PowerBarColor[token] or PowerBarColor[0])
            if c and c.r then pr, pg, pb = c.r, c.g, c.b end
        end)
    end
    pcall(function() f.mp:GetStatusBarTexture():SetDesaturated(false) end)
    f.mp:SetStatusBarColor(pr, pg, pb, 1)
    f.mp:SetMinMaxValues(0, UnitPowerMax(u))
    f.mp:SetValue(UnitPower(u))
    setBarText(f.mpText, f, "mp")
end

local function updateInfo(f)
    local u = f.wfUnit
    if not UnitExists(u) then return end
    -- Forever has surnames: show "First Last", cut off at the width of the name bar
    if not pcall(function()
        local n, sur = UnitName(u)
        if sur and sur ~= "" and not f.small then f.name:SetFormattedText("%s %s", n, sur) else f.name:SetText(n) end
    end) then
        if not pcall(function() f.name:SetText(UnitName(u)) end) then f.name:SetText("") end
    end
    -- level: coloured by difficulty on units you can attack (like the default UI), gold otherwise,
    -- white on the player. A secret level can't be compared, so it is shown as it is, uncoloured.
    local lr, lg, lb = 1, 0.82, 0
    if f.baseUnit == "player" then lr, lg, lb = 1, 1, 1 end
    local shown = pcall(function()
        local l = UnitLevel(u)
        if l and l > 0 then
            f.level:SetText(tostring(l))
            if f.baseUnit ~= "player" and UnitCanAttack("player", u) and GetCreatureDifficultyColor then
                local c = GetCreatureDifficultyColor(l)
                if c then lr, lg, lb = c.r, c.g, c.b end
            end
        else
            f.level:SetText("??")
            if f.baseUnit ~= "player" then lr, lg, lb = 1, 0.1, 0.1 end
        end
    end)
    if not shown and not pcall(function() f.level:SetFormattedText("%d", UnitLevel(u)) end) then f.level:SetText("") end
    f.level:SetTextColor(lr, lg, lb)
    SetPortraitTexture(f.portrait, u)
    if f.leaderIcon then
        local lead = false
        pcall(function() lead = UnitIsGroupLeader(u) and true or false end)
        f.leaderIcon:SetShown(lead)
    end
    -- offline players: greyed-out portrait with the red lightning bolt, as on the party frames
    local offline = false
    pcall(function() offline = UnitIsPlayer(u) and UnitIsConnected(u) == false end)
    pcall(function() f.portrait:SetDesaturated(offline) end)
    f.portrait:SetVertexColor(offline and 0.6 or 1, offline and 0.6 or 1, offline and 0.6 or 1)
    if offline and not f.offlineIcon then
        f.offlineIcon = (f.portraitHolder or f):CreateTexture(nil, "ARTWORK", nil, 2)
        f.offlineIcon:SetTexture("Interface\\CharacterFrame\\Disconnect-Icon")
        f.offlineIcon:SetPoint("CENTER", f.portrait, "CENTER", 0, 0)
    end
    if f.offlineIcon then
        -- the party frame draws this 64px texture (mostly empty margin) over a 37px portrait: same ratio here
        local w = (f.portrait:GetWidth() or 40) * 64 / 37
        f.offlineIcon:SetSize(w, w)
        f.offlineIcon:SetShown(offline)
    end
    if f.plate then
        local r, g, b = reactionColorOf(u)
        if r then f.plate:SetVertexColor(r, g, b) else f.plate:SetVertexColor(1, 1, 1) end
    end
    -- gold dragon around elite portraits, silver for rares, the big one for world bosses
    if f.dragon then
        local d
        pcall(function() d = DRAGON[UnitClassification(u)] end)
        if d then
            local left = f.layoutLeft
            if left then f.dragon:SetTexCoord(d[2], d[1], d[3], d[4]) else f.dragon:SetTexCoord(d[1], d[2], d[3], d[4]) end
            f.dragon:SetSize(d[5], d[6])
            f.dragon:ClearAllPoints()
            f.dragon:SetPoint("CENTER", f.portrait, "CENTER", left and -d[7] or d[7], 1)
            f.dragon:Show()
        else
            f.dragon:Hide()
        end
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
    -- (Blizzard's plain portrait circle: Forever's CircleMask atlas isn't a tight circle, so the art's
    -- trough beside the ring showed through over the health bar)
    f.ringMask = ov:CreateMaskTexture()
    f.ringMask:SetTexture(CIRCLE_FALLBACK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    f.ringTop:AddMaskTexture(f.ringMask)
    if f.baseUnit == "player" then
        f.combatIcon = ov:CreateTexture(nil, "OVERLAY", nil, 5)
        f.combatIcon:SetSize(32, 32)
        setIcon(f.combatIcon, "UI-HUD-UnitFrame-Player-CombatIcon", STATE_ICON, 0.5, 1, 0, 0.49)
        if f.combatIcon:GetAtlas() then pcall(f.combatIcon.SetAtlas, f.combatIcon, "UI-HUD-UnitFrame-Player-CombatIcon", true) end
        f.combatIcon:Hide()
        -- black outline so the swords stand out over the corner accent: a solid black copy of the
        -- icon, a little larger, behind it
        f.combatBack = ov:CreateTexture(nil, "OVERLAY", nil, 4)
        f.combatBack:SetTexture(f.combatIcon:GetTexture())
        pcall(function()
            local atlas = f.combatIcon:GetAtlas()
            if atlas then f.combatBack:SetAtlas(atlas) else f.combatBack:SetTexCoord(f.combatIcon:GetTexCoord()) end
        end)
        f.combatBack:SetVertexColor(0, 0, 0, 1)
        f.combatBack:Hide()
        -- Combat / resting glow around the frame: Retail's status texture (gold while resting,
        -- tinted red and pulsing in combat), from the bundled art.
        local sf = CreateFrame("Frame", nil, f)
        sf:SetAllPoints(f)
        sf:SetFrameLevel(f:GetFrameLevel() + 4)
        local glow = sf:CreateTexture(nil, "OVERLAY")
        setArt(glow, ART.playerStatus)
        glow:SetPoint("CENTER", f, "CENTER", -1, 1.55)
        glow:SetBlendMode("ADD")
        -- The outline glow doesn't cover the corner accent, so it gets its own: a larger additive halo
        -- behind it, and an additive copy on top of it (the accent itself is opaque and drawn above
        -- the halo), in a frame above the accent. Shown only while the accent is (updateIndicators).
        local cf = CreateFrame("Frame", nil, f)
        cf:SetAllPoints(f)
        cf:SetFrameLevel(f:GetFrameLevel() + 6)
        local halo = sf:CreateTexture(nil, "OVERLAY")
        setArt(halo, ART.corner, false, 1.35)
        halo:SetPoint("CENTER", f, "CENTER", CORNER_POS[1], CORNER_POS[2])
        halo:SetBlendMode("ADD")
        local lit = cf:CreateTexture(nil, "OVERLAY")
        setArt(lit, ART.corner)
        lit:SetPoint("CENTER", f, "CENTER", CORNER_POS[1], CORNER_POS[2])
        lit:SetBlendMode("ADD")
        lit:SetAlpha(0.8)
        f.cornerGlow = {
            SetShown = function(_, on) halo:SetShown(on); lit:SetShown(on) end,
        }
        sf:Hide(); cf:Hide()
        f.status = {
            Show = function() sf:Show(); cf:Show() end,
            Hide = function() sf:Hide(); cf:Hide() end,
            SetAlpha = function(_, a) sf:SetAlpha(a); cf:SetAlpha(a) end,
            SetVertexColor = function(_, r, g, b)
                glow:SetVertexColor(r, g, b); halo:SetVertexColor(r, g, b); lit:SetVertexColor(r, g, b)
            end,
        }
        -- one pulse animation per frame, started and stopped together
        local anims = {}
        pcall(function()
            for _, fr in ipairs({ sf, cf }) do
                local ag = fr:CreateAnimationGroup()
                ag:SetLooping("BOUNCE")
                local a = ag:CreateAnimation("Alpha")
                a:SetFromAlpha(1); a:SetToAlpha(0.35); a:SetDuration(0.8)
                anims[#anims + 1] = ag
            end
        end)
        if #anims > 0 then
            f.statusAnim = {
                IsPlaying = function() return anims[1]:IsPlaying() end,
                Play = function() for _, ag in ipairs(anims) do ag:Play() end end,
                Stop = function() for _, ag in ipairs(anims) do ag:Stop() end end,
            }
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
    -- threat (target and focus), the Retail way: the frame's in-combat glow tinted by your threat
    -- status (yellow, orange, red), and your threat % in small coloured text at the end of the name row
    if hasCastAndThreat(f.baseUnit) then
        local tf = CreateFrame("Frame", nil, f)
        tf:SetAllPoints(f)
        tf:SetFrameLevel(f:GetFrameLevel() + 4)
        f.threatGlow = tf:CreateTexture(nil, "OVERLAY")
        f.threatGlow:SetBlendMode("ADD")
        f.threatGlow:SetAlpha(0.9)
        f.threatGlow:Hide()
        f.threatText = ov:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.threatText:SetJustifyH("RIGHT")
        f.threatText:Hide()
    end
end

local function placeIndicators(f)
    -- positions from DragonflightUI, relative to the portrait (and the name for the threat box)
    local left = f.layoutLeft
    local p = f.portrait
    if f.combatIcon then
        -- bottom corner of the portrait (DragonflightUI's spot), with its black outline behind
        f.combatIcon:ClearAllPoints()
        f.combatIcon:SetSize(18, 18)
        f.combatIcon:SetPoint("CENTER", p, "BOTTOMRIGHT", -10, 7)
        if f.combatBack then
            f.combatBack:ClearAllPoints()
            f.combatBack:SetSize(22, 22)
            f.combatBack:SetPoint("CENTER", f.combatIcon, "CENTER", 0, 0)
        end
    end
    if f.restIcon then
        f.restIcon:ClearAllPoints()
        f.restIcon:SetPoint("CENTER", p, "TOPRIGHT", -4, 4)
    end
    if f.pvpIcon then
        -- just outside the portrait on the frame's outer edge (DragonflightUI's spot), but raised above
        -- its middle: Forever's level circle sits where DragonflightUI puts the badge, below the middle
        f.pvpIcon:ClearAllPoints()
        if left then f.pvpIcon:SetPoint("LEFT", p, "LEFT", -22, 14) else f.pvpIcon:SetPoint("RIGHT", p, "RIGHT", 22, 14) end
    end
    if f.threatGlow then
        -- the same glow art and spot as the interrupt flash (see applyLayout)
        f.threatGlow:ClearAllPoints()
        if left then
            setArt(f.threatGlow, ART.playerStatus)
            f.threatGlow:SetPoint("CENTER", f, "CENTER", -1, 1.55)
        else
            setArt(f.threatGlow, ART.targetFlash)
            f.threatGlow:SetPoint("CENTER", f, "CENTER", 0, 1.5)
        end
        -- right end of the name row, just above the health bar
        f.threatText:ClearAllPoints()
        f.threatText:SetPoint("BOTTOMRIGHT", f.hp, "TOPRIGHT", -2, 2)
    end
end

local function updateIndicators(f)
    if f.small or not f.pvpIcon then return end
    local u, base = f.wfUnit, f.baseUnit
    if f.combatIcon then
        local inCombat = f.combatFlag
        pcall(function() if UnitAffectingCombat("player") then inCombat = true end end)
        local showC = inCombat and true or false
        f.combatIcon:SetShown(showC)
        if f.combatBack then f.combatBack:SetShown(showC) end
        -- in combat the crossed swords take the accent's place, as on Retail; its glow follows it
        if f.corner and hasCorner(base) and f.layoutLeft then
            local cornerOn = (getSetting(base, "cornerAccent") and not showC) and true or false
            f.corner:SetShown(cornerOn)
            if f.cornerBack then f.cornerBack:SetShown(cornerOn) end
        end
        if f.cornerGlow then f.cornerGlow:SetShown(f.corner and f.corner:IsShown() or false) end
        if f.status then
            local resting = false
            pcall(function() resting = IsResting() and true or false end)
            if showC then
                f.status:SetVertexColor(1, 0, 0)
                f.status:Show()
                if f.statusAnim and not f.statusAnim:IsPlaying() then f.statusAnim:Play() end
            elseif resting then
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
        f.restIcon:SetShown(resting)
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
    if kind then
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
        local u = f.wfUnit
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
    if not f.threatText then return end
    local status, pct
    pcall(function()
        if not getSetting(f.baseUnit, "showThreat") then return end
        local u = f.wfUnit
        if not UnitExists(u) or not UnitCanAttack("player", u) then return end
        status = UnitThreatSituation("player", u)
        local _, _, scaled = UnitDetailedThreatSituation("player", u)
        pct = scaled
    end)
    -- The percent may be a secret number: it only ever goes to SetFormattedText. The glow shows from
    -- status 1 up (about to pull, tanking insecurely, tanking); a status that can't be compared shows none.
    local shown, glowOn, has = false, false, false
    pcall(function() has = (status ~= nil and pct ~= nil) end)
    if has then
        local r, g, b = 0.7, 0.7, 0.7
        pcall(function() if GetThreatStatusColor then r, g, b = GetThreatStatusColor(status) end end)
        shown = pcall(function() f.threatText:SetFormattedText("%d%%", pct) end)
        if shown then f.threatText:SetTextColor(r, g, b) end
        pcall(function() glowOn = status >= 1 end)
        if glowOn then f.threatGlow:SetVertexColor(r, g, b) end
    end
    f.threatText:SetShown(shown)
    f.threatGlow:SetShown(glowOn)
    -- make room for the number at the end of the name row
    if f.nameBaseW then f.name:SetWidth(shown and f.nameBaseW - 30 or f.nameBaseW) end
end

---------------------------------------------------------------------------
-- Cast bars (target and focus): a box bolted on under the health and mana bars, bordered with slices
-- of the frame art's own border round those bars (minus the line between health and mana), with the
-- spell icon at its left end and the bar filling the rest. It runs on under the portrait ring, where
-- Media\castbox-mask-target.tga (made for exactly this box) cuts its end along the ring, halfway through
-- the ring's gold band, which is drawn on top: so it ends in the ring like the other bars.
-- Hiding Blizzard's target / focus frames also hid their cast bars. Ours is driven by Blizzard's: it
-- keeps running (it handles the protected cast data) but is parked off-screen, and every frame ours
-- copies its progress, fade, cast type, spell name and icon. Values only ever go to setters.
---------------------------------------------------------------------------
local castHider = CreateFrame("Frame")
castHider:Hide()
local CAST_SLOT = 4      -- extra gap under the frame for the cast box's lower edge, above the auras
-- The box, in the frame's TOPLEFT coordinates. Its top border line is the frame art's bottom border line
-- (at y -71, under the mana bar): the cast bar shares that line with the mana bar.
-- On the target layout it runs on to the level badge, which is drawn on top and hides its end.
local CAST_BOX = { top = -71, right = { 20.5, 200 }, left = { 77.5, 210 } }
-- Where the border slices come from in the frame art, in the same coordinates (measured from the decoded
-- art): the art's left cap (its 1px side line at x 22 and the shadow inside it) and a plain stretch of
-- its lines; the top rows are the line between the health and mana bars (at y -60) and the 4px shadow under
-- it, where it meets the left line in a T (the cast bar continues the block, so no rounded corner), the middle
-- is plain trough (40% black), the bottom rows are the mana bar's bottom line (at y -71) and the 4px soft
-- shadow below it. No separator line between them.
local CAST_ART = {
    capX = { 20.5, 27 }, midX = { 40, 130 },
    rows = { { -60, -65 }, { -46, -52 }, { -71, -76 } },   -- top, middle, bottom
    rowH = { 5, 6, 5 },                                      -- their heights in the cast box
    -- the fill sits right inside the lines, like the bars: under the top line, above the bottom line,
    -- right of the side line (10px tall, like the mana bar)
    inset = { left = 2.5, top = 1, bottom = 5 },
}
local CAST_EDGE = { 0.75, 0.75, 0.72 }  -- the light line colour (outline style, icon divider)

-- fill colour by Blizzard's cast type
local CAST_COLORS = {
    standard        = { 1.0, 0.70, 0.0 },   -- casting: yellow
    empowered       = { 1.0, 0.70, 0.0 },
    channel         = { 0.0, 0.85, 0.2 },   -- channelling: green
    uninterruptable = { 0.6, 0.6, 0.6 },    -- can't be interrupted: grey
    interrupted     = { 0.9, 0.1, 0.1 },    -- interrupted / failed: red
}

local function castBoxHeight() local h = 0; for _, v in ipairs(CAST_ART.rowH) do h = h + v end; return h end

-- Points a texture at a rectangle of the target frame art, given in frame coordinates (y1 above y2).
local function artSlice(tex, x1, x2, y1, y2, flip)
    local a = ART.targetBorder
    local left, top = 116 + 0.5 - a[2] / 2, -50 + a[3] / 2      -- the art's top left corner in the frame
    if flip then y1, y2 = y2, y1 end                              -- upside down
    tex:SetTexture(MEDIA .. a[1])
    tex:SetTexCoord((x1 - left) / a[2] * a[4], (x2 - left) / a[2] * a[4],
                    (top - y1) / a[3] * a[5], (top - y2) / a[3] * a[5])
end

local function newCastBar(f)
    local box = CreateFrame("Frame", nil, f)
    box:SetFrameLevel(f:GetFrameLevel() + 1)
    local cb = CreateFrame("StatusBar", nil, box)
    cb.box = box
    -- dark trough for the Outline / None styles (the frame-art border has its own trough)
    cb.inside = box:CreateTexture(nil, "BACKGROUND", nil, 0)
    cb.inside:SetColorTexture(0, 0, 0, 0.4)
    -- "Like the bars" border: 3 rows x 2 columns of frame-art slices (left cap, stretched middle)
    cb.slices = {}
    for r = 1, 3 do
        for c = 1, 2 do
            local t = box:CreateTexture(nil, "BACKGROUND", nil, 2)
            local xs = (c == 1) and CAST_ART.capX or CAST_ART.midX
            artSlice(t, xs[1], xs[2], CAST_ART.rows[r][1], CAST_ART.rows[r][2], CAST_ART.rows[r][3])
            t.row, t.col = r, c
            cb.slices[#cb.slices + 1] = t
        end
    end
    -- "Outline" border: a 1px light line round the box
    cb.edge = box:CreateTexture(nil, "BACKGROUND", nil, 1)
    cb.edge:SetAllPoints()
    cb.edge:SetColorTexture(CAST_EDGE[1], CAST_EDGE[2], CAST_EDGE[3], 1)
    cb.edgeInside = box:CreateTexture(nil, "BACKGROUND", nil, 1)
    cb.edgeInside:SetPoint("TOPLEFT", 1, -1)
    cb.edgeInside:SetPoint("BOTTOMRIGHT", -1, 1)
    cb.edgeInside:SetColorTexture(0.05, 0.05, 0.05, 1)
    cb.boxMask = box:CreateMaskTexture()
    cb.boxMask:SetAllPoints(box)
    cb:SetFrameLevel(box:GetFrameLevel() + 1)
    cb:SetMinMaxValues(0, 1)
    cb:SetValue(0)
    -- spell icon in the box's left end, with a 1px divider after it
    cb.icon = box:CreateTexture(nil, "ARTWORK")
    cb.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)      -- cropped past Blizzard's own icon border, like the auras
    -- the line between icon and bar, in the frame art's own line style: a 1px mid-grey line (the art's
    -- measured colour) joining the top and bottom border lines, with a thin dark shadow on the bar side
    cb.divider = box:CreateTexture(nil, "ARTWORK", nil, 1)
    cb.divider:SetColorTexture(0.55, 0.55, 0.55, 1)
    cb.dividerShadow = box:CreateTexture(nil, "ARTWORK")
    cb.dividerShadow:SetColorTexture(0, 0, 0, 0.5)
    local top = CreateFrame("Frame", nil, cb)
    top:SetAllPoints()
    top:SetFrameLevel(f.ov:GetFrameLevel() + 1)
    cb.text = top:CreateFontString(nil, "OVERLAY", "TextStatusBarText")   -- same style as the bar numbers
    cb.text:SetPoint("CENTER", cb, "CENTER", 0, 0)
    cb.text:SetWidth(110)
    cb.text:SetWordWrap(false)
    box:Hide()
    return cb
end

local function placeCastbar(f)
    local bar, cb = f.castbar, f.cb
    if not (bar and cb) then return end
    if not getSetting(f.baseUnit, "castShow") then
        if bar:GetParent() ~= castHider then bar:SetParent(castHider) end
        cb.box:Hide()
        return
    end
    -- Blizzard's bar keeps running (and updating) off-screen; ours shows its progress
    if bar:GetParent() ~= f then bar:SetParent(f) end
    bar:ClearAllPoints()
    bar:SetPoint("TOPRIGHT", UIParent, "TOPLEFT", -1000, 1000)
    local x = f.layoutLeft and CAST_BOX.left or CAST_BOX.right
    local h = castBoxHeight()
    local box = cb.box
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", f, "TOPLEFT", x[1], CAST_BOX.top)
    box:SetPoint("BOTTOMRIGHT", f, "TOPLEFT", x[2], CAST_BOX.top - h)
    -- the border slices: rows stacked down the box, the cap at the left, the middle stretched to the end
    local capW = CAST_ART.capX[2] - CAST_ART.capX[1]
    for _, t in ipairs(cb.slices) do
        local y = 0
        for r = 1, t.row - 1 do y = y + CAST_ART.rowH[r] end
        t:ClearAllPoints()
        if t.col == 1 then
            t:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -y)
            t:SetSize(capW, CAST_ART.rowH[t.row])
        else
            t:SetPoint("TOPLEFT", box, "TOPLEFT", capW, -y)
            t:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", 0, -(y + CAST_ART.rowH[t.row]))
        end
    end
    -- the frame's own bar texture (a chosen SharedMedia one, or the default tintable fill) ...
    local fill = f.customTex or ((f.layoutLeft and BAR_FILE.player or BAR_FILE.target) .. "Health-Status")
    if cb.fill ~= fill then
        cb.fill = fill
        cb:SetStatusBarTexture(fill)
        cb.fillMasked = nil
    end
    -- target layout: cut the box's end along the portrait ring (once per texture)
    if not f.layoutLeft then
        if not cb.boxMaskSet then
            cb.boxMaskSet = true
            cb.boxMask:SetTexture(MEDIA .. "castbox-mask-target", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            for _, t in ipairs(cb.slices) do t:AddMaskTexture(cb.boxMask) end
            for _, t in ipairs({ cb.inside, cb.edge, cb.edgeInside }) do t:AddMaskTexture(cb.boxMask) end
        end
        if not cb.fillMasked then
            cb.fillMasked = true
            local tex = cb:GetStatusBarTexture()
            pcall(tex.AddMaskTexture, tex, cb.boxMask)   -- may already have it if the texture object was reused
        end
    end
    -- ... and its font, at the size and style of the health bar numbers
    pcall(function() cb.text:SetFont(f.hpText:GetFont()) end)
    -- border style: "bars" = the frame art's border, "outline" = a 1px light line, "none" = no border
    local style = getSetting(f.baseUnit, "castBorder")
    for _, t in ipairs(cb.slices) do t:SetShown(style == "bars") end
    cb.edge:SetShown(style == "outline")
    cb.edgeInside:SetShown(style == "outline")
    cb.inside:SetShown(style ~= "bars")
    local inL, inT, inB = CAST_ART.inset.left, CAST_ART.inset.top, CAST_ART.inset.bottom
    cb.inside:ClearAllPoints()
    cb.inside:SetPoint("TOPLEFT", box, "TOPLEFT", inL, -inT)
    cb.inside:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, inB)
    local showIcon = getSetting(f.baseUnit, "castIcon") and true or false
    local inner = h - inT - inB
    cb.icon:ClearAllPoints()
    cb.icon:SetPoint("TOPLEFT", box, "TOPLEFT", inL, -inT)
    cb.icon:SetSize(inner, inner)
    cb.icon:SetShown(showIcon)
    local dx = inL + inner       -- where the divider line goes, right after the icon
    cb.divider:ClearAllPoints()
    cb.divider:SetPoint("TOPLEFT", box, "TOPLEFT", dx, 0)
    cb.divider:SetPoint("BOTTOMRIGHT", box, "TOPLEFT", dx + 1, -(h - inB + 1))
    cb.dividerShadow:ClearAllPoints()
    cb.dividerShadow:SetPoint("TOPLEFT", box, "TOPLEFT", dx + 1, -inT)
    cb.dividerShadow:SetPoint("BOTTOMRIGHT", box, "TOPLEFT", dx + 2, -(h - inB))
    cb.divider:SetShown(showIcon)
    cb.dividerShadow:SetShown(showIcon)
    cb:ClearAllPoints()
    cb:SetPoint("TOPLEFT", box, "TOPLEFT", inL + (showIcon and (inner + 1) or 0), -inT)
    cb:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, inB)
    -- the spell name is centred under the health bar (the bar itself runs on to the level badge)
    local fillLeft = x[1] + inL + (showIcon and (inner + 1) or 0)   -- (the shadow sits over the fill's first px)
    local hpMid = f.layoutLeft and (85 + 124 / 2) or (23 + 126 / 2)
    cb.text:ClearAllPoints()
    -- (1px up: the font string's box includes room for descenders, so it sits low when centred)
    cb.text:SetPoint("CENTER", cb, "CENTER", hpMid - (fillLeft + x[2]) / 2, 1)
    cb.text:SetShown(getSetting(f.baseUnit, "castText") and true or false)
end

-- Copies Blizzard's bar onto ours, every frame while the unit exists.
local function mirrorCastbar(f)
    local bar, cb = f.castbar, f.cb
    local box = cb.box
    if not getSetting(f.baseUnit, "castShow") or not bar:IsShown() then
        if box:IsShown() then box:Hide() end
        return
    end
    pcall(function() cb:SetMinMaxValues(bar:GetMinMaxValues()) end)
    pcall(function() cb:SetValue(bar:GetValue()) end)
    box:SetAlpha(bar:GetAlpha())
    -- Retail bars name their cast type in barType; older ones have channeling / notInterruptible flags
    local c = CAST_COLORS.standard
    pcall(function()
        if CAST_COLORS[bar.barType] then c = CAST_COLORS[bar.barType]
        elseif bar.notInterruptible then c = CAST_COLORS.uninterruptable
        elseif bar.channeling then c = CAST_COLORS.channel end
    end)
    cb:SetStatusBarColor(c[1], c[2], c[3], 1)
    -- the default fill is grey art made for tinting; a chosen texture keeps its own look, like the health bar
    local plain = not f.customTex
    pcall(function() cb:GetStatusBarTexture():SetDesaturated(plain) end)
    if bar.Text then pcall(function() cb.text:SetText(bar.Text:GetText()) end) end
    if bar.Icon then pcall(function() cb.icon:SetTexture(bar.Icon:GetTexture()) end) end
    if not box:IsShown() then box:Show() end
end

local function adoptCastbar(f, barName)
    local bar = _G[barName]
    if not bar then return end
    f.castbar = bar
    f.cb = newCastBar(f)
    -- The cast box runs on under the portrait ring, so the portrait (with its backing, elite dragon and
    -- offline bolt) moves into its own layer above the bars and the cast box, but below the ring overlay,
    -- level badge and text (on f.ov): the cast bar then slides behind the portrait.
    local holder = CreateFrame("Frame", nil, f)
    holder:SetAllPoints(f)
    holder:SetFrameLevel(f:GetFrameLevel() + 3)
    for _, r in ipairs({ f.portrait, f.portraitBg, f.pmask, f.dragon, f.offlineIcon }) do
        if r then r:SetParent(holder) end
    end
    f.portraitHolder = holder
    -- Blizzard's AdjustPosition reads these from the bar's parent (comparing auraRows to numbers), so
    -- give our frame safe values; after every adjustment the bar is parked off-screen again.
    f.buffsOnTop, f.auraRows, f.haveToT, f.haveElite = true, 0, false, false
    local function replace() pcall(placeCastbar, f) end
    if bar.AdjustPosition then hooksecurefunc(bar, "AdjustPosition", replace) end
    if _G.Target_Spellbar_AdjustPosition then
        hooksecurefunc("Target_Spellbar_AdjustPosition", function(self) if self == bar then replace() end end)
    end
    bar:HookScript("OnShow", replace)
    f:HookScript("OnUpdate", function() mirrorCastbar(f) end)
    placeCastbar(f)
end

---------------------------------------------------------------------------
-- Buffs and debuffs. Secret-safe: aura fields only ever go to setters, timers go through duration
-- objects (SetCooldownFromDurationObject) and stack counts through the display-count API.
---------------------------------------------------------------------------
local DEBUFF_BORDER = "Interface\\Buttons\\UI-Debuff-Overlays"
local AURA_GAP = 2

local function auraTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    local ok = self.auraID ~= nil and pcall(GameTooltip.SetUnitAuraByAuraInstanceID, GameTooltip, self.unit, self.auraID)
    if not ok then pcall(GameTooltip.SetUnitAura, GameTooltip, self.unit, self.index, self.filter) end
    GameTooltip:Show()
end

local function newAuraButton(parent)
    local b = CreateFrame("Frame", nil, parent)
    -- a crisp 1px edge (black on buffs, the dispel colour on debuffs) with the icon inside it, cropped
    -- past Blizzard's own icon border
    b.edge = b:CreateTexture(nil, "BACKGROUND")
    b.edge:SetAllPoints()
    b.edge:SetColorTexture(0, 0, 0, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    -- a soft dark swipe; the countdown numbers are Blizzard's own (safe with protected durations)
    b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cd:SetAllPoints(b.icon)
    b.cd:SetReverse(true)
    b.cd:SetDrawEdge(false)
    pcall(b.cd.SetSwipeColor, b.cd, 0, 0, 0, 0.6)
    -- stack count above the cooldown swipe
    local top = CreateFrame("Frame", nil, b)
    top:SetAllPoints()
    top:SetFrameLevel(b.cd:GetFrameLevel() + 1)
    b.count = top:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", 1, 0)
    b.count:SetJustifyH("RIGHT")
    b:EnableMouse(true)
    b:SetScript("OnEnter", auraTooltip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

-- Where the aura block starts: below the frame art (default), above it, or to its right.
local function auraAnchor(f, pos)
    if f.small then
        if pos == "above" then return "BOTTOMLEFT", "TOPLEFT", 4, 2 end
        if pos == "right" then return "TOPLEFT", "TOPRIGHT", 2, -4 end
        return "TOPLEFT", "BOTTOMLEFT", 4, 0
    end
    -- tucked under the frame art's bottom edge, from its left edge (on the player frame, just right of the level circle)
    local x = f.layoutLeft and 55 or 22
    if pos == "above" then return "BOTTOMLEFT", "TOPLEFT", f.layoutLeft and 85 or 22, -14 end
    if pos == "right" then return "TOPLEFT", "TOPRIGHT", -18, -20 end
    -- With a cast bar they lock onto its bottom (always, cast or not, so the icons don't jump about),
    -- lined up with its left line.
    if f.castbar and getSetting(f.baseUnit, "castShow") then
        local cx = (f.layoutLeft and CAST_BOX.left or CAST_BOX.right)[1]
        -- just below the cast box (its bottom line's soft shadow included)
        return "TOPLEFT", "TOPLEFT", cx + 1.5, CAST_BOX.top - castBoxHeight() - 1
    end
    return "TOPLEFT", "TOPLEFT", x, -87
end

local function updateAuras(f)
    local base = f.baseUnit
    local showB, showD = getSetting(base, "auraBuffs"), getSetting(base, "auraDebuffs")
    if not (showB or showD) or not C_UnitAuras then
        if f.auraButtons then for _, b in ipairs(f.auraButtons) do b:Hide() end end
        f.auraHeight = 0
        placeCastbar(f)
        return
    end
    if not f.auraBox then
        f.auraBox = CreateFrame("Frame", nil, f.ov or f)
        f.auraBox:SetSize(1, 1)
        f.auraButtons = {}
    end
    local size, perRow, max = getSetting(base, "auraSize"), getSetting(base, "auraPerRow"), getSetting(base, "auraMax")
    local pos = getSetting(base, "auraPos")
    local point, relPoint, x, y = auraAnchor(f, pos)
    f.auraBox:ClearAllPoints()
    f.auraBox:SetPoint(point, f, relPoint, x, y)
    local up = (pos == "above")
    local timers = getSetting(base, "auraTimers") and true or false
    local u = f.wfUnit
    local n, col, row = 0, 0, 0

    local function place(b)
        b:SetSize(size, size)
        b:ClearAllPoints()
        local bx, by = col * (size + AURA_GAP), row * (size + AURA_GAP)
        if up then b:SetPoint("BOTTOMLEFT", f.auraBox, "BOTTOMLEFT", bx, by)
        else b:SetPoint("TOPLEFT", f.auraBox, "TOPLEFT", bx, -by) end
        col = col + 1
        if col >= perRow then col, row = 0, row + 1 end
    end

    local function group(filter, isDebuff)
        local count = 0
        for i = 1, 40 do
            if count >= max then break end
            local aura
            pcall(function() aura = C_UnitAuras.GetAuraDataByIndex(u, i, filter) end)
            if not aura then break end
            n, count = n + 1, count + 1
            local b = f.auraButtons[n] or newAuraButton(f.auraBox)
            f.auraButtons[n] = b
            b.unit, b.index, b.filter, b.auraID = u, i, filter, aura.auraInstanceID
            pcall(b.icon.SetTexture, b.icon, aura.icon)
            if not pcall(function() b.count:SetText(C_UnitAuras.GetAuraApplicationDisplayCount(u, aura.auraInstanceID, 2, 99)) end) then
                b.count:SetText("")
            end
            if not pcall(function() b.cd:SetCooldownFromDurationObject(C_UnitAuras.GetAuraDuration(u, aura.auraInstanceID)) end) then
                -- older clients: plain numbers, when they are readable
                if not pcall(function()
                    if aura.duration and aura.duration > 0 then b.cd:SetCooldown(aura.expirationTime - aura.duration, aura.duration)
                    else b.cd:Clear() end
                end) then b.cd:Clear() end
            end
            if isDebuff then
                -- coloured by dispel type (magic blue, curse purple, ...); red when unknown or protected
                local r, g, bl = 0.8, 0, 0
                pcall(function()
                    local c = DebuffTypeColor and DebuffTypeColor[aura.dispelName]
                    if c then r, g, bl = c.r, c.g, c.b end
                end)
                b.edge:SetColorTexture(r, g, bl, 1)
            else
                b.edge:SetColorTexture(0, 0, 0, 1)
            end
            -- countdown numbers and stack count sized to the icon
            pcall(b.cd.SetHideCountdownNumbers, b.cd, not timers)
            if timers then
                pcall(function()
                    local fs = b.cd:GetCountdownFontString()
                    local fp = fs:GetFont()
                    fs:SetFont(fp or STANDARD_TEXT_FONT, math.max(8, math.floor(size * 0.45)), "OUTLINE")
                end)
            end
            pcall(function()
                local fp = b.count:GetFont()
                b.count:SetFont(fp or STANDARD_TEXT_FONT, math.max(8, math.floor(size * 0.5)), "OUTLINE")
            end)
            place(b)
            b:Show()
        end
        if count > 0 and col > 0 then col, row = 0, row + 1 end   -- the next group starts a new row
    end

    if showB then group("HELPFUL", false) end
    if showD then group(getSetting(base, "auraMine") and "HARMFUL|PLAYER" or "HARMFUL", true) end
    for i = n + 1, #f.auraButtons do f.auraButtons[i]:Hide() end
    -- how tall the aura block is, so the cast bar can sit under it
    local rows = (col > 0) and (row + 1) or row
    f.auraHeight = rows * (size + AURA_GAP)
    placeCastbar(f)
end

local function updateAll(f) updateInfo(f); updateHealth(f); updatePower(f); updateIndicators(f); updateFlash(f); updateThreat(f); pcall(updateAuras, f) end

---------------------------------------------------------------------------
-- Layout: Retail's left-portrait (player) art, or right-portrait (target) art
---------------------------------------------------------------------------
local function isLeft(f)
    return portraitOnLeft(f.baseUnit)
end

-- Returns true if the layout changed.
local function applyLayout(f)
    if f.small then return false end      -- the small frame has a fixed layout
    local left = isLeft(f)
    if f.layoutLeft == left then return false end
    f.layoutLeft = left

    local prefix = left and PLAYER_PREFIX or TARGET_PREFIX
    f.prefix = prefix
    -- Positions below are DragonflightUI's, moved into this frame's coordinates: its player art sits
    -- (16, 5.5) further right / up and its target art (20.5, -6) further left / down than ours.
    local barFile = left and BAR_FILE.player or BAR_FILE.target
    f.hpFiles = true
    f.hpAtlas = barFile .. "Health"
    f.hpStatusAtlas = barFile .. "Health-Status"
    f.hpCurrent, f.mpCurrent = nil, nil

    -- border / frame art (left: the player frame's art, right: the target frame's)
    f.border:ClearAllPoints()
    if left then
        setArt(f.border, ART.playerBorder)
        f.border:SetPoint("CENTER", f, "CENTER", 0, 0.55)
    else
        setArt(f.border, ART.targetBorder)
        f.border:SetPoint("CENTER", f, "CENTER", 0.5, 0)
    end
    -- right layout: a copy of just the portrait ring, drawn above the bars so their ends tuck under it
    if f.ringTop then
        local t = f.ringTop
        t:ClearAllPoints()
        if left then
            t:Hide()
        else
            local a = ART.targetBorder
            -- From 122px into the 192px art: the ring's outer edge reaches about 124px in at the health
            -- bar's height (starting at 126 left a sliver of it under the health bar's end). The circle
            -- mask below keeps the copy to the ring itself.
            local from = 122
            t:SetTexture(MEDIA .. a[1])
            t:SetTexCoord(a[4] * from / a[2], a[4], 0, a[5])
            t:SetSize(a[2] - from, a[3])
            t:SetPoint("RIGHT", f, "RIGHT", -19.5, 0)
            f.ringMask:ClearAllPoints()
            -- just the gold ring: its outer edge is ~29.5px from the portrait's centre (measured from the art);
            -- a bigger circle took in the dark trough beside it, which then darkened the bars' ends
            f.ringMask:SetSize(61, 61)
            f.ringMask:SetPoint("CENTER", f, "TOPLEFT", 177, -48)
            t:Show()
        end
    end
    -- interrupt flash: the in-combat glow of the matching art, tinted red
    if f.flash then
        f.flash:ClearAllPoints()
        if left then
            setArt(f.flash, ART.playerStatus)
            f.flash:SetPoint("CENTER", f, "CENTER", -1, 1.55)
        else
            setArt(f.flash, ART.targetFlash)
            f.flash:SetPoint("CENTER", f, "CENTER", 0, 1.5)
        end
        f.flash:SetBlendMode("ADD")
        f.flash:SetVertexColor(1, 0, 0)
    end
    -- reaction-coloured name plate above the health bar (right layout only)
    if f.plate then
        setArt(f.plate, ART.plate)
        f.plate:ClearAllPoints()
        f.plate:SetPoint("BOTTOMLEFT", f.hp, "TOPLEFT", -0.5, -3)
    end

    -- portrait and its mask
    f.portrait:ClearAllPoints()
    f.pmask:ClearAllPoints()
    if left then
        f.portrait:SetSize(60, 60)
        f.portrait:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -19)
        -- the mask's art (round, or squared behind the corner accent) is chosen by applyCorner
        f.pmask:SetSize(60, 60)
        f.pmask:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -19)
    else
        f.portrait:SetSize(58, 58)
        f.portrait:SetPoint("TOPRIGHT", f, "TOPRIGHT", -26, -19)
        if hasAtlas("CircleMask") then f.pmask:SetAtlas("CircleMask") else
            f.pmask:SetTexture(CIRCLE_FALLBACK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        end
        f.pmask:SetPoint("TOPLEFT", f.portrait, "TOPLEFT", 0, -1)
        f.pmask:SetPoint("BOTTOMRIGHT", f.portrait, "BOTTOMRIGHT", -1, 0)
    end

    -- bars, with DragonflightUI's bundled masks (fills: see updateHealthColor / updatePower)
    f.hp:ClearAllPoints(); f.mp:ClearAllPoints()
    if left then
        f.hp:SetSize(124, 20)
        f.hp:SetPoint("TOPLEFT", f, "TOPLEFT", 85, -40)
        f.mp:SetSize(124, 10.5)
        f.mp:SetPoint("TOPLEFT", f, "TOPLEFT", 85, -60.25)
        f.hpMaskOn = setFileMask(f.hp, f.hpMask, "uiunitframeplayerhealthmask2x", 128, 32, -2, 6)
        f.mpMaskOn = setFileMask(f.mp, f.mpMask, "uiunitframeplayermanamask2x", 128, 16, -2, 2)
    else
        f.hp:SetSize(126, 20)
        f.hp:SetPoint("TOPLEFT", f, "TOPLEFT", 23, -40)
        f.mp:SetSize(134, 10)
        f.mp:SetPoint("TOPLEFT", f.hp, "BOTTOMLEFT", 0, -1)
        f.hpMaskOn = setFileMask(f.hp, f.hpMask, "uiunitframetargethealthmask2x", 129, 32, -1, 6)
        f.mpMaskOn = setFileMask(f.mp, f.mpMask, "uiunitframetargetmanamask2x", 259, 16, -62, 3)
    end
    -- No trim: with the bundled art the bars sit exactly between its lines (measured), so a custom
    -- texture fills its section just like the default fill.
    setClip(f.hp, 0); setClip(f.mp, 0)

    -- text
    f.mpText:ClearAllPoints()
    f.mpText:SetPoint("CENTER", f.mp, "CENTER", 0, 0)
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
    f.nameBaseW = f.name:GetWidth()   -- updateThreat narrows the name to fit the threat %
    return true
end

---------------------------------------------------------------------------
-- Applying settings
---------------------------------------------------------------------------
function refreshText(f)
    local mode = getSetting(f.baseUnit, "textMode")
    local always = (mode == "always")
    local over = (mode == "mouseover")
    -- Dead / Ghost / Offline always shows, whatever the text mode
    f.hpText:SetShown((always or f.statusText or (over and f.hoverHP)) and true or false)
    f.mpText:SetShown((always or (over and f.hoverMP)) and true or false)
end

-- The squared corner (the "Corner accent" setting): player and target frames, left-hand portrait only.
local function applyCorner(f)
    local c = f.corner
    if not c then return end
    local on = (hasCorner(f.baseUnit) and f.layoutLeft and not f.small and getSetting(f.baseUnit, "cornerAccent")) and true or false
    -- Left-hand large portraits: with the accent, Retail's mask (a circle with the bottom right corner
    -- squared off, bundled from DragonflightUI) so the portrait fills the space behind the accent;
    -- without it, a plain circle.
    if f.layoutLeft and not f.small then
        if on then
            f.pmask:SetTexture(MEDIA .. "uiunitframeplayerportraitmask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            f.pmask:SetTexCoord(0, 1, 0, 1)
        elseif hasAtlas("CircleMask") then
            f.pmask:SetAtlas("CircleMask")
        else
            f.pmask:SetTexture(CIRCLE_FALLBACK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        end
    end
    c:SetShown(on)
    if f.cornerBack then f.cornerBack:SetShown(on) end
end


-- Small frame (target of target): portrait on either side. The right layout mirrors the art and bar masks.
local function applySmallLayout(f)
    local left = isLeft(f)
    if f.layoutLeft == left then return false end
    f.layoutLeft = left
    f.portrait:ClearAllPoints()
    f.portrait:SetPoint(left and "TOPLEFT" or "TOPRIGHT", f, left and "TOPLEFT" or "TOPRIGHT", left and 5 or -5, -5)
    -- DragonflightUI's target-of-target art and bar masks, mirrored for the right-hand portrait
    -- (the masks are symmetric about their bars, so their offsets stay the same when mirrored)
    f.border:ClearAllPoints()
    setArt(f.border, ART.smallBorder, not left)
    f.border:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.hp:ClearAllPoints(); f.mp:ClearAllPoints()
    f.hp:SetSize(70, 10.5)
    f.hp:SetPoint("TOPLEFT", f, "TOPLEFT", left and 44 or 6, -16.5)
    f.mp:SetSize(74, 7.5)
    f.mp:SetPoint("TOPLEFT", f, "TOPLEFT", left and 40 or 6, -27.5)
    f.hpMaskOn = setFileMask(f.hp, f.hpMask, "uipartyframeportraitonhealthmask", 128, 16.5, -29, 3, not left)
    f.mpMaskOn = setFileMask(f.mp, f.mpMask, "uipartyframeportraitonmanamask", 128, 16.5, -27, 4, not left)
    setClip(f.hp, 0); setClip(f.mp, 0)    -- no trim, see applyLayout
    f.hpCurrent, f.mpCurrent = nil, nil
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
    if f.partyIndex then
        -- stacked in the party container, each below the one before
        local i = f.partyIndex
        if i == 1 then f:SetPoint("TOPLEFT", frames.party, "TOPLEFT", 0, 0)
        else f:SetPoint("TOPLEFT", partyFrames[i - 1], "BOTTOMLEFT", 0, -PARTY_GAP) end
    elseif u and u.point then
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
    pcall(updateAuras, f)
    pcall(placeCastbar, f)
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

-- The party container (its position, and its size so the Edit Mode box fits) and its frames.
local function applyParty()
    local box = frames.party
    if not box then return end
    local u, d = unitData("party"), DEFAULT_POS.party
    box:ClearAllPoints()
    if u and u.point then box:SetPoint(u.point, UIParent, u.point, u.x, u.y)
    else box:SetPoint(d.point, UIParent, d.point, d.x, d.y) end
    local s = getSetting("party", "scale")
    box:SetSize(120 * s, (49 * #PARTY + PARTY_GAP * (#PARTY - 1)) * s)
    for _, f in ipairs(partyFrames) do applyUnit(f) end
end

local function applyAll()
    if InCombatLockdown() then pendingApply = true; return end
    pendingApply = false
    for _, unit in ipairs(UNITS) do
        if frames[unit] then applyUnit(frames[unit]) end
    end
    applyParty()
end

local function setSetting(unit, key, value)
    unitData(unit, true)[key] = value
    if unit == "party" then
        for _, pf in ipairs(partyFrames) do
            pcall(updateHealth, pf)
            pcall(updatePower, pf)
        end
        if InCombatLockdown() then pendingApply = true else applyParty() end
        return
    end
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
-- The clickable secure button both frame sizes are built on. The live unit lives in f.wfUnit, not
-- f.unit: an addon-written .unit field stops pings from reading the unit's (secret) GUID.
local function newUnitButton(unit, w, h)
    local f
    local name = "WebbyFrames_" .. unit
    if not pcall(function() f = CreateFrame("Button", name, UIParent, "SecureUnitButtonTemplate,PingableUnitFrameTemplate") end) or not f then
        f = CreateFrame("Button", name, UIParent, "SecureUnitButtonTemplate")
    end
    f.wfUnit, f.baseUnit = unit, unit
    f:SetSize(w, h)
    f:SetFrameStrata("LOW")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:RegisterForClicks("AnyUp")
    f:SetAttribute("unit", unit)
    f:SetAttribute("type1", "target")
    f:SetAttribute("type2", "togglemenu")
    f:SetPoint(DEFAULT_POS[unit].point, UIParent, DEFAULT_POS[unit].point, DEFAULT_POS[unit].x, DEFAULT_POS[unit].y)
    return f
end

-- Unit tooltip on hover, and the per-bar "show on mouseover" numbers.
local function addHover(f)
    f:HookScript("OnEnter", function(self)
        self.hover = true
        pcall(function()
            GameTooltip_SetDefaultAnchor(GameTooltip, self)
            if GameTooltip:SetUnit(self.wfUnit) ~= false then GameTooltip:Show() end
        end)
    end)
    f:HookScript("OnLeave", function(self)
        self.hover = false; self.hoverHP = false; self.hoverMP = false; refreshText(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    -- numbers appear only on the bar under the cursor
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
end

local function createFrame(unit)
    local isPlayer = (unit == "player")
    local f = newUnitButton(unit, 232, 100)

    -- portrait (under the border) and its mask; sizes/anchors are set by applyLayout
    f.portrait = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    f.pmask = f:CreateMaskTexture()
    f.portrait:AddMaskTexture(f.pmask)
    -- solid backing under the portrait, cut by the same mask: portrait images can have transparent
    -- areas (around the model), which would otherwise show the game world through the ring
    f.portraitBg = f:CreateTexture(nil, "BACKGROUND", nil, 0)
    f.portraitBg:SetColorTexture(0.05, 0.05, 0.05, 1)
    f.portraitBg:SetAllPoints(f.portrait)
    f.portraitBg:AddMaskTexture(f.pmask)

    -- reaction-coloured name plate, used by the right-portrait layout only (art set by applyLayout)
    if not isPlayer then
        f.plate = f:CreateTexture(nil, "BACKGROUND", nil, 2)
        -- elite / rare / boss dragon around the portrait (see updateInfo)
        f.dragon = f:CreateTexture(nil, "ARTWORK", nil, 3)
        f.dragon:SetTexture(MEDIA .. "uiunitframeboss2x")
        f.dragon:Hide()
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

    -- Corner accent (DragonflightUI's art; shown by applyCorner), with a solid black silhouette of
    -- itself, a little larger, behind it so nothing behind the accent can show through.
    f.cornerBack = ov:CreateTexture(nil, "OVERLAY", nil, 0)
    setArt(f.cornerBack, ART.corner, false, 1.15)
    f.cornerBack:SetVertexColor(0, 0, 0, 1)
    f.cornerBack:SetPoint("CENTER", f, "CENTER", CORNER_POS[1], CORNER_POS[2])
    f.corner = ov:CreateTexture(nil, "OVERLAY", nil, 1)
    setArt(f.corner, ART.corner)
    f.corner:SetPoint("CENTER", f, "CENTER", CORNER_POS[1], CORNER_POS[2])

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
    -- (DragonflightUI's flipbook sheet: 7 x 6 frames of 60px, at the top right of the portrait)
    if isPlayer then
        local rest = CreateFrame("Frame", nil, f)
        rest:SetSize(24, 24)
        rest:SetPoint("CENTER", f, "TOPLEFT", 80, -15)
        rest:SetFrameLevel(f:GetFrameLevel() + 6)
        local tex = rest:CreateTexture(nil, "ARTWORK")
        tex:SetTexture(MEDIA .. "uiunitframerestingflipbook")
        tex:SetTexCoord(0, 7 / 8, 0, 7 / 8)
        tex:SetAllPoints()
        local anim
        pcall(function()
            local ag = tex:CreateAnimationGroup()
            ag:SetLooping("REPEAT")
            local a = ag:CreateAnimation("FlipBook")
            a:SetFlipBookRows(7); a:SetFlipBookColumns(6); a:SetFlipBookFrames(42)
            a:SetDuration(1.5)
            a:SetFlipBookFrameWidth(60); a:SetFlipBookFrameHeight(60)
            anim = ag
        end)
        f.updateRest = function()
            local resting = IsResting()
            rest:SetShown(resting and true or false)
            if anim then if resting then anim:Play() else anim:Stop() end end
        end
        f:RegisterEvent("PLAYER_UPDATE_RESTING")
    end

    addHover(f)

    -- events
    f:SetScript("OnEvent", function(self, event)
        if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then updateHealth(self)
        elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then updatePower(self)
        elseif event == "PLAYER_UPDATE_RESTING" then
            if self.updateRest then self.updateRest() end
            updateIndicators(self)
        elseif event == "PLAYER_REGEN_DISABLED" then self.combatFlag = true; updateIndicators(self)
        elseif event == "PLAYER_REGEN_ENABLED" then self.combatFlag = false; updateIndicators(self)
        elseif event == "PLAYER_FLAGS_CHANGED" or event == "UNIT_FLAGS" then updateIndicators(self)
        elseif event:find("^UNIT_SPELLCAST") then updateFlash(self)
        elseif event:find("^UNIT_THREAT") then updateThreat(self)
        elseif event == "UNIT_AURA" then updateAuras(self)
        else updateAll(self) end
    end)
    for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
                         "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED", "UNIT_FACTION", "UNIT_CONNECTION", "UNIT_AURA" }) do
        pcall(f.RegisterUnitEvent, f, e, unit)
    end
    -- smooth energy / rage / focus ticks on your own frame
    if isPlayer then pcall(f.RegisterUnitEvent, f, "UNIT_POWER_FREQUENT", unit) end
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
        -- the situation event fires for the unit whose threat changed (you), the list event for the mob
        pcall(f.RegisterUnitEvent, f, "UNIT_THREAT_SITUATION_UPDATE", unit, "player")
        pcall(f.RegisterUnitEvent, f, "UNIT_THREAT_LIST_UPDATE", unit)
        for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
                             "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START",
                             "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" }) do
            pcall(f.RegisterUnitEvent, f, e, unit)
        end
    end

    if unit ~= "player" then RegisterUnitWatch(f) end
    if unit == "target" then adoptCastbar(f, "TargetFrameSpellBar") end
    if unit == "focus" then adoptCastbar(f, "FocusFrameSpellBar") end
    frames[unit] = f
    applyLayout(f)
    if f.updateRest then f.updateRest() end
    updateAll(f)
end

---------------------------------------------------------------------------
-- Small frames: target of target, focus target, pet (art and numbers from Blizzard's TargetFrame.xml)
---------------------------------------------------------------------------
local POLL_INTERVAL = 0.25

local function createSmallFrame(unit)
    local f = newUnitButton(unit, 120, 49)
    f.small = true
    f.prefix = TOT_PREFIX
    f.layoutLeft = nil        -- applySmallLayout builds the art, bars and masks for the chosen side
    f.hpFiles = true
    f.hpAtlas = BAR_FILE.small .. "Health"
    f.hpStatusAtlas = BAR_FILE.small .. "Health-Status"
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
    -- solid backing under the portrait (see createFrame)
    f.portraitBg = f:CreateTexture(nil, "BACKGROUND", nil, 0)
    f.portraitBg:SetColorTexture(0.05, 0.05, 0.05, 1)
    f.portraitBg:SetAllPoints(f.portrait)
    f.portraitBg:AddMaskTexture(f.pmask)

    f.border = f:CreateTexture(nil, "BACKGROUND", nil, 3)
    f.border:SetTexelSnappingBias(0)
    f.border:SetSnapToPixelGrid(false)

    -- bars (sized, placed and masked by applySmallLayout)
    f.hp, f.hpMask = newBar(f)
    f.mp, f.mpMask = newBar(f)

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
    f.ov = ov

    addHover(f)

    -- Compound units (targettarget, focustarget) get no unit events, so while shown they are polled:
    -- bars every tick, name / portrait only when the unit changes. A secret GUID can't be compared,
    -- so that case counts as changed (repaint rather than show stale info).
    if unit == "targettarget" or unit == "focustarget" then
        local acc = 0
        f:HookScript("OnUpdate", function(self, dt)
            acc = acc + dt
            if acc < POLL_INTERVAL then return end
            acc = 0
            local u = self.wfUnit
            if not UnitExists(u) then return end
            local guid = UnitGUID(u)
            local ok, same = pcall(function() return guid == self.lastGUID end)
            if not (ok and same) then
                self.lastGUID = guid
                pcall(updateAll, self)
            else
                pcall(updateHealth, self)
                pcall(updatePower, self)
            end
        end)
    end

    f:SetScript("OnEvent", function(self, event)
        if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then updateHealth(self)
        elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then updatePower(self)
        elseif event == "UNIT_AURA" then updateAuras(self)
        else updateAll(self) end
    end)
    for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
                         "UNIT_NAME_UPDATE", "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED", "UNIT_FACTION", "UNIT_CONNECTION", "UNIT_AURA" }) do
        pcall(f.RegisterUnitEvent, f, e, unit)
    end
    if unit == "pet" then
        pcall(f.RegisterUnitEvent, f, "UNIT_PET", "player")
    elseif unit == "focustarget" then
        pcall(f.RegisterUnitEvent, f, "UNIT_TARGET", "focus")
        f:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif unit:match("^party") then
        -- who is in the group, and who leads it
        f:RegisterEvent("GROUP_ROSTER_UPDATE")
        f:RegisterEvent("PARTY_LEADER_CHANGED")
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
-- Party frames: the small frame four times (party1-4), stacked in one movable container. Like
-- Blizzard's, they show in a party and hide in a raid; each frame shows only while its member exists.
---------------------------------------------------------------------------
local PARTY_VISIBILITY = "[group:raid] hide; [group:party] show; hide"

local function createParty()
    local box = CreateFrame("Frame", "WebbyFrames_Party", UIParent, "SecureHandlerStateTemplate")
    box:SetSize(120, 49 * #PARTY + PARTY_GAP * (#PARTY - 1))
    box:SetFrameStrata("LOW")
    box:SetClampedToScreen(true)
    box:SetMovable(true)
    frames.party = box
    for i, unit in ipairs(PARTY) do
        createSmallFrame(unit)
        local f = frames[unit]
        frames[unit] = nil          -- reached through partyFrames; their options are under "party"
        f.baseUnit = "party"
        f.partyIndex = i
        f:SetParent(box)
        -- party leader crown, at the top left of the portrait
        f.leaderIcon = f.ov:CreateTexture(nil, "OVERLAY", nil, 6)
        f.leaderIcon:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
        f.leaderIcon:SetSize(16, 16)
        f.leaderIcon:SetPoint("CENTER", f.portrait, "TOPLEFT", 4, -2)
        f.leaderIcon:Hide()
        partyFrames[i] = f
    end
    RegisterAttributeDriver(box, "state-visibility", PARTY_VISIBILITY)
end

---------------------------------------------------------------------------
-- Edit Mode (LibEditMode)
---------------------------------------------------------------------------
-- Target and focus only exist while you have one, so while Edit Mode is open
-- they show the player's data as a stand-in, to give you something to move.
local function sampleFrames()
    local list = {}
    for _, unit in ipairs({ "target", "targettarget", "focus", "focustarget", "pet" }) do
        if frames[unit] then list[#list + 1] = frames[unit] end
    end
    for _, f in ipairs(partyFrames) do list[#list + 1] = f end
    return list
end

local function enterSample()
    if InCombatLockdown() then return end
    -- the party container is shown whatever the group, so it can be moved
    if frames.party then UnregisterAttributeDriver(frames.party, "state-visibility"); frames.party:Show() end
    for _, f in ipairs(sampleFrames()) do
        UnregisterUnitWatch(f)
        f.wfUnit = "player"
        f:Show()
        updateAll(f)
    end
end

local function exitSample()
    if InCombatLockdown() then return end
    for _, f in ipairs(sampleFrames()) do
        f.wfUnit = f.partyIndex and PARTY[f.partyIndex] or f.baseUnit
        RegisterUnitWatch(f)
        updateAll(f)
    end
    if frames.party then RegisterAttributeDriver(frames.party, "state-visibility", PARTY_VISIBILITY) end
end

-- defined with the actions and settings below; used by the dialog buttons
local resetFrame, copySettings, openSettings

-- Snapping in Edit Mode: when a frame is dropped within SNAP_DIST of another Webby frame, one of
-- Blizzard's Edit Mode frames, or the screen's centre lines, its edges (or centre) line up with them.
-- A frame's visible box is its border art, not the larger clickable button.
local SNAP_DIST = 10

local function boxOf(fr)
    local r = fr.border or fr
    local l, b, w, h = r:GetRect()
    if not l then return end
    local s = r:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return l * s, b * s, (l + w) * s, (b + h) * s
end

local function snapTargets(self)
    local list = {}
    for _, unit in ipairs(OPTION_UNITS) do
        local o = frames[unit]
        if o and o ~= self and o:IsVisible() then list[#list + 1] = o end
    end
    pcall(function()
        for _, o in ipairs(EditModeManagerFrame.registeredSystemFrames or {}) do
            if o:IsVisible() then list[#list + 1] = o end
        end
    end)
    return list
end

-- Returns the snapped TOPLEFT offsets (in the frame's own scale), or nil if nothing was in reach.
local function snapFrame(f)
    local snapOn = true
    pcall(function() if EditModeManagerFrame.IsSnapEnabled then snapOn = EditModeManagerFrame:IsSnapEnabled() end end)
    if not snapOn then return end
    local l, b, r, t = boxOf(f)
    if not l then return end
    local dx, dy
    local function try(best, from, to)
        local d = to - from
        if math.abs(d) <= SNAP_DIST and (not best or math.abs(d) < math.abs(best)) then return d end
        return best
    end
    for _, o in ipairs(snapTargets(f)) do
        local ol, ob, orr, ot = boxOf(o)
        if ol then
            for _, x in ipairs({ ol, orr }) do dx = try(dx, l, x); dx = try(dx, r, x) end
            dx = try(dx, (l + r) / 2, (ol + orr) / 2)
            for _, y in ipairs({ ob, ot }) do dy = try(dy, b, y); dy = try(dy, t, y) end
            dy = try(dy, (b + t) / 2, (ob + ot) / 2)
        end
    end
    local W, H = UIParent:GetSize()
    dx = try(dx, (l + r) / 2, W / 2)
    dy = try(dy, (b + t) / 2, H / 2)
    if not (dx or dy) then return end
    -- move the whole frame by the same amount its box moved
    local fs = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local fl, _, _, fh = f:GetRect()
    if not fl then return end
    local left = fl * fs + (dx or 0)
    local top = (f:GetTop() * fs) + (dy or 0)
    local x, y = left / fs, (top - H) / fs
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
    return "TOPLEFT", x, y
end

-- Edit Mode is only for moving the frames: each frame's dialog has buttons for its options page
-- (Esc > Options > AddOns > Webby Frames) and for a reset.
local function setupEditMode()
    local ok, l = pcall(LibStub, "LibEditMode")
    if not ok or not l then
        print("|cffff9900Webby Frames:|r Edit Mode library failed to load.")
        return
    end
    lib = l

    for _, unit in ipairs(OPTION_UNITS) do
        local f = frames[unit]
        local d = DEFAULT_POS[unit]
        lib:AddFrame(f, function(_, layoutName, point, x, y)
            local sp, sx, sy = snapFrame(f)
            if sp then point, x, y = sp, sx, sy end
            local u = unitData(unit, true, layoutName)
            u.point, u.x, u.y = point, x, y
        end, { point = d.point, x = d.x, y = d.y }, "Webby " .. UNIT_LABEL[unit] .. " Frame")
        pcall(lib.AddFrameSettingsButtons, lib, f, {
            { text = "Options", click = function() openSettings(unit) end },
            { text = "Reset frame", click = function() resetFrame(unit) end },
        })
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
local COPY_KEYS = { "scale", "showName", "cornerAccent", "textMode", "textFormat", "barTexture", "font", "flashInterrupt", "showThreat",
                    "auraBuffs", "auraDebuffs", "auraMine", "auraSize", "auraPerRow", "auraMax", "auraPos", "auraTimers",
                    "castShow", "castText", "castIcon", "castBorder",
                    "colorMode", "healthFade" }

function resetFrame(unit)
    if InCombatLockdown() then print("|cff33ccffWebby Frames:|r can't reset in combat."); return end
    local l = DB.layouts and DB.layouts[activeLayout]
    if l then l[unit] = nil end
    if unit == "party" then
        for _, pf in ipairs(partyFrames) do pf.layoutLeft = nil end
        applyParty()
        return
    end
    local f = frames[unit]
    if f then
        f.layoutLeft = nil            -- force the layout to be rebuilt
        applyUnit(f)
        pcall(updateAll, f)
        if lib then lib:RefreshFrameSettings(f) end
    end
end

function copySettings(from, to)
    if InCombatLockdown() then print("|cff33ccffWebby Frames:|r can't copy in combat."); return end
    for _, key in ipairs(COPY_KEYS) do
        local v = getSetting(from, key)
        if v ~= nil then unitData(to, true)[key] = v end
    end
    if to == "party" then applyParty(); return end
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
-- Settings (Esc > Options > AddOns > Webby Frames): a General page, plus one page per frame with
-- its options in four sections. Edit Mode is only for moving the frames.
---------------------------------------------------------------------------
local unitPages = {}    -- unit -> settings subcategory

local function addonVersion()
    local v
    pcall(function() v = C_AddOns.GetAddOnMetadata("WebbyFrames", "Version") end)
    return v or "?"
end

function openSettings(unit)
    local cat = (unit and unitPages[unit]) or settingsCategory
    if cat and Settings and Settings.OpenToCategory then
        pcall(function()
            if EditModeManagerFrame and EditModeManagerFrame:IsShown() then HideUIPanel(EditModeManagerFrame) end
        end)
        Settings.OpenToCategory(cat:GetID())
    else
        print("|cff33ccffWebby Frames:|r the settings page isn't available.")
    end
end

-- Collapsible sections: Blizzard's header flips its `expanded` flag when clicked, but on this client the
-- list doesn't re-filter its rows until the page is shown again. So while the options are open, a
-- watcher checks every section's flag and, when one changes, shows the page again (the same thing a
-- page switch does) and puts the scroll position back.
local sections = {}          -- every section initializer
local function sectionData(sec) return sec.data or (sec.GetData and sec:GetData()) end

local function repaintSettings()
    pcall(function()
        local list = SettingsPanel:GetSettingsList()
        local box = list and list.ScrollBox
        local pct = box and box.GetScrollPercentage and box:GetScrollPercentage()
        SettingsPanel:SelectCategory(SettingsPanel:GetCurrentCategory(), true)
        if pct and box.SetScrollPercentage then box:SetScrollPercentage(pct) end
    end)
end

-- Makes each visible section header show + when closed and - when open (the header doesn't redraw its
-- own icon on this client either).
local isSection = {}
local function refreshSectionIcons()
    pcall(function()
        local box = SettingsPanel:GetSettingsList().ScrollBox
        box:ForEachFrame(function(frame, elementData)
            if not isSection[elementData] then return end
            local data = sectionData(elementData)
            local open = type(data) == "table" and data.expanded and true or false
            -- frames are recycled between rows, so set the icon every time rather than remembering it
            if frame.webbyOpen ~= open and frame.OnExpandedChanged then pcall(frame.OnExpandedChanged, frame, open) end
            frame.webbyOpen = open
            local icon = frame.Button and frame.Button.Right
            if icon and icon.SetAtlas then
                pcall(icon.SetAtlas, icon, open and "Options_ListExpand_Right_Expanded" or "Options_ListExpand_Right", true)
            end
        end)
    end)
end

local sectionWatch = CreateFrame("Frame")
local watchElapsed = 0
sectionWatch:SetScript("OnUpdate", function(_, dt)
    watchElapsed = watchElapsed + dt
    if watchElapsed < 0.1 then return end
    watchElapsed = 0
    if not (SettingsPanel and SettingsPanel:IsShown()) then return end
    local changed = false
    for _, sec in ipairs(sections) do
        local data = sectionData(sec)
        local now = type(data) == "table" and data.expanded and true or false
        if sec.webbyWas ~= now then sec.webbyWas = now; changed = true end
    end
    if changed then repaintSettings() end
    refreshSectionIcons()
end)

local function buildSettings()
    local root, rootLayout = Settings.RegisterVerticalLayoutCategory("Webby Frames")
    settingsCategory = root

    -- Small builders; every setting reads and writes through a proxy table. B.section starts a
    -- collapsible section (Blizzard's expandable header); the controls added after it only show while
    -- it is expanded. Without that API the section is a plain header and everything shows.
    local function builders(category, layout, proxy, prefix)
        local B = {}
        local current
        local function attach(init)
            local sec = current
            if sec and init and init.AddShownPredicate then
                init:AddShownPredicate(function()
                    local data = sec.data or (sec.GetData and sec:GetData())
                    if type(data) ~= "table" then return true end
                    return data.expanded and true or false
                end)
            end
            return init
        end
        function B.header(text)
            current = nil
            if CreateSettingsListSectionHeaderInitializer then
                layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
            end
        end
        function B.section(text, open)
            if not CreateSettingsExpandableSectionInitializer then B.header(text); return end
            local sec = CreateSettingsExpandableSectionInitializer(text)
            local data = sectionData(sec)
            if type(data) == "table" then data.expanded = open and true or false end
            sec.webbyWas = open and true or false
            sections[#sections + 1] = sec      -- watched, see sectionWatch
            isSection[sec] = true
            layout:AddInitializer(sec)
            current = sec
        end
        function B.check(key, label, tip, default)
            local st = Settings.RegisterAddOnSetting(category, prefix .. key, key, proxy, Settings.VarType.Boolean, label, default)
            attach(Settings.CreateCheckbox(category, st, tip))
        end
        function B.slider(key, label, tip, default, lo, hi, step, fmt)
            local st = Settings.RegisterAddOnSetting(category, prefix .. key, key, proxy, Settings.VarType.Number, label, default)
            local o = Settings.CreateSliderOptions(lo, hi, step)
            o:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, fmt or function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end)
            attach(Settings.CreateSlider(category, st, o, tip))
        end
        function B.dropdown(key, label, tip, default, choices)
            local st = Settings.RegisterAddOnSetting(category, prefix .. key, key, proxy, Settings.VarType.String, label, default)
            attach(Settings.CreateDropdown(category, st, function()
                local c = Settings.CreateControlTextContainer()
                local list = type(choices) == "function" and choices() or choices
                for _, ch in ipairs(list) do c:Add(ch[1], ch[2]) end
                return c:GetData()
            end, tip))
        end
        function B.button(label, text, onClick, tip)
            if CreateSettingsButtonInitializer then
                local init = CreateSettingsButtonInitializer(label, text, onClick, tip, true)
                layout:AddInitializer(init)
                attach(init)
            end
        end
        return B
    end

    -- General ------------------------------------------------------------------
    do
        local general = setmetatable({}, {
            __index = function(_, k) if k == "enabled" then return DB.enabled ~= false end end,
            __newindex = function(_, k, v) if k == "enabled" then DB.enabled = v and true or false end end,
        })
        local B = builders(root, rootLayout, general, "WEBBY_general_")
        B.header("Webby Frames  v" .. addonVersion())
        B.check("enabled", "Enable Webby Frames", "Replaces Blizzard's player, target, target of target, focus, focus target and pet frames. Needs /reload to take effect.", true)
        B.button("Move frames", "Open Edit Mode", openEditMode, "Drag the frames where you want them.")
        B.button("Reset", "Reset all frames", function()
            for _, unit in ipairs(OPTION_UNITS) do resetFrame(unit) end
        end, "Puts every frame back to its defaults (options and position) for the current Edit Mode layout.")
        B.header("Each frame has its own page below. Options are saved per Edit Mode layout.")
    end

    -- one page per frame ---------------------------------------------------------
    local fontList = function() local l = {}; for _, c in ipairs(fontChoices()) do l[#l + 1] = { c[1], c[2] } end; return l end
    for _, unit in ipairs(OPTION_UNITS) do
        local sub, subLayout = Settings.RegisterVerticalLayoutSubcategory(root, UNIT_LABEL[unit])
        unitPages[unit] = sub
        local proxy = setmetatable({}, {
            __index = function(_, k) return getSetting(unit, k) end,
            __newindex = function(_, k, v) setSetting(unit, k, v) end,
        })
        local B = builders(sub, subLayout, proxy, "WEBBY_" .. unit .. "_")

        B.section("Layout", true)
        B.slider("scale", "Scale", "Size of the frame.", 1, 0.5, 2, 0.05)
        B.check("showName", "Show name", nil, true)
        if hasCorner(unit) then
            B.check("cornerAccent", "Corner accent", "The pointed accent at the bottom of the portrait ring.", true)
        end

        B.section("Bars", false)
        B.dropdown("barTexture", "Texture", "Fill texture for the health and power bars, including SharedMedia ones.", "default", textureChoices)
        B.dropdown("textMode", "Numbers", "When the numbers on the bars show. On mouseover, only the bar under the cursor shows its number.",
            defaultFor(unit, "textMode"), { { "always", "Always" }, { "mouseover", "On mouseover" }, { "off", "Off" } })
        B.dropdown("textFormat", "Number style", "Totals, percentages, or both.",
            defaultFor(unit, "textFormat"), { { "value", "12.3K" }, { "percent", "85%" }, { "both", "12.3K (85%)" } })
        B.dropdown("font", "Font", "Font for the name and bar numbers, including SharedMedia ones.", "default", fontList)

        B.section("Colours", false)
        if unit ~= "pet" then   -- the pet bar is always green
            B.dropdown("colorMode", "Health colour", "How the health bar is coloured.", "smart", COLOR_MODES)
        end
        B.dropdown("healthFade", "Low health fade", "Shift the health bar colour as health drops.", "off",
            { { "off", "Off" }, { "classic", "Green to red" }, { "reactive", "Health colour to red" } })

        B.section("Buffs and debuffs", false)
        local whole = function(v) return string.format("%d", math.floor(v + 0.5)) end
        B.check("auraBuffs", "Show buffs", nil, defaultFor(unit, "auraBuffs"))
        B.check("auraDebuffs", "Show debuffs", nil, defaultFor(unit, "auraDebuffs"))
        B.check("auraMine", "Only my debuffs", "Show only the debuffs you applied.", false)
        B.check("auraTimers", "Countdown numbers", "Time left on each buff and debuff.", true)
        B.dropdown("auraPos", "Position", "Where the icons sit.", defaultFor(unit, "auraPos"),
            { { "below", "Below the frame" }, { "above", "Above the frame" }, { "right", "Right of the frame" } })
        B.slider("auraSize", "Icon size", nil, defaultFor(unit, "auraSize"), 12, 40, 1, whole)
        B.slider("auraPerRow", "Icons per row", nil, defaultFor(unit, "auraPerRow"), 1, 16, 1, whole)
        B.slider("auraMax", "Most of each", "How many buffs, and how many debuffs, can show.", defaultFor(unit, "auraMax"), 1, 32, 1, whole)

        if hasCastAndThreat(unit) then
            B.section("Cast bar", false)
            B.check("castShow", "Show cast bar", "A bar under the mana bar showing what the unit is casting: yellow for a cast, green for a channel, grey when you can't interrupt it, red when interrupted.", true)
            B.check("castText", "Spell name", "The spell's name on the cast bar.", true)
            B.check("castIcon", "Spell icon", "The spell's icon, at the cast bar's left end.", true)
            B.dropdown("castBorder", "Border", "How the cast bar is edged.", "bars",
                { { "bars", "Like the bars" }, { "outline", "Outline" }, { "none", "None" } })

            B.section("Combat", false)
            B.check("flashInterrupt", "Interrupt flash", "Pulse the frame red while the unit casts a spell you can interrupt.", true)
            B.check("showThreat", "Threat", "Your threat on hostile units: the frame glows yellow, orange or red, and your threat % shows by the name.", true)
        end

        B.section("Reset and copy", false)
        if unit ~= "player" then
            B.button("Copy", "Copy from player", function() copySettings("player", unit) end,
                "Copies the player frame's options to this frame (not its position).")
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
    -- Blizzard's party frames (not the raid-style ones, if you use those)
    hideBlizzard(_G.PartyFrame)
    for i = 1, 4 do hideBlizzard(_G["PartyMemberFrame" .. i]) end
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
    createParty()
    hideAllBlizzard()
    C_Timer.After(2, hideAllBlizzard)
    setupEditMode()
    applyAll()
    print("|cff33ccffWebby Frames|r v" .. addonVersion() .. " loaded. Type |cff33ccff/webby|r for options.")
end)

SLASH_WEBBYFRAMES1 = "/webby"
SlashCmdList.WEBBYFRAMES = function(msg)
    msg = (msg or ""):lower():match("^%s*(%S*)") or ""
    if msg == "" or msg == "options" then
        openSettings()
    elseif msg == "edit" then
        openEditMode()
    elseif msg == "reset" then
        for _, unit in ipairs(OPTION_UNITS) do resetFrame(unit) end
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
                print("corner", u, "shown", tostring(c:IsShown()), "visible", tostring(c:IsVisible()),
                    "left", tostring(f.layoutLeft), "setting", tostring(getSetting(u, "cornerAccent")),
                    "back", tostring(f.cornerBack and f.cornerBack:IsShown()))
            end
        end
        -- mana bar: mask on/off, fill art, value, and the mask's size and tex coords
        for _, u in ipairs(UNITS) do
            local f = frames[u]
            if f and f.mp then
                local okv, lo, hi = pcall(f.mp.GetMinMaxValues, f.mp)
                local okc, a, b, _, _, c = pcall(f.mpMask.GetTexCoord, f.mpMask)
                print("mana", u, "maskOn", tostring(f.mpMaskOn), "art", tostring(f.mpCurrent),
                    "shown", tostring(f.mp:IsShown()), "w", math.floor(f.mp:GetWidth()), "max", okv and tostring(hi) or "?",
                    "mask", math.floor(f.mpMask:GetWidth()) .. "x" .. math.floor(f.mpMask:GetHeight()),
                    "tc", okc and string.format("%.3f %.3f %.3f", a or -1, b or -1, c or -1) or "?", "maskAtlas", tostring(f.mpMask:GetAtlas()))
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
        print("|cff33ccffWebby Frames:|r /webby (options)   /webby edit (move the frames)   /webby reset (reset all frames)   /webby debug")
    else
        print("|cff33ccffWebby Frames:|r unknown command. Type |cff33ccff/webby help|r.")
    end
end
