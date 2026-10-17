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
local UNIT_LABEL = { player = "Player", target = "Target", targettarget = "Target of Target", focus = "Focus", focustarget = "Focus Target", pet = "Pet" }
-- (party frames are shelved for now: .github/shelved/party-skin.lua)
-- Portrait side is fixed per frame: target and focus have it on the right (Retail's target art),
-- the player and the small frames on the left.
local function portraitOnLeft(unit) return unit ~= "target" and unit ~= "focus" end
-- only the full-size target and focus frames have the cast bar, interrupt flash and threat
local function hasCastAndThreat(unit) return unit == "target" or unit == "focus" end
-- the pointed corner accent is only offered on the player frame; the rest keep a round ring
local function hasCorner(unit) return unit == "player" end

local COLOR_MODES = {
    { "smart",    "Class (players), reaction (NPCs)" },
    { "class",    "Class colour (players only)" },
    { "reaction", "Reaction colour" },
    { "plain",    "Plain green" },
}

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
    player = { combatNumbers = true },
    target = { auraBuffs = true, auraDebuffs = true, combatNumbers = true },
    focus  = { auraBuffs = true, auraDebuffs = true, combatNumbers = true },
    targettarget = { textMode = "off", textFormat = "percent" },
    pet = { textMode = "off", textFormat = "percent" },
    focustarget = { textMode = "off", textFormat = "percent" },
}

local DEFAULT_SETTINGS = {
    scale = 1, showName = true, healthFade = false, textMode = "always", textFormat = "value", barTexture = "default", font = "default", showThreat = true,
    -- health bar colour: "smart" (class colour for players, reaction colour for NPCs), "class", "reaction" or "plain"
    colorMode = "smart",
    npcColor = "reaction",   -- hostile NPCs: "reaction" (red), "green" or "custom" (npcColorRGB = { r, g, b })
    -- buffs and debuffs (off unless a frame's defaults turn them on)
    auraBuffs = false, auraDebuffs = false, auraMine = false,
    auraSize = 18, auraPerRow = 8, auraMax = 16, auraPos = "below", auraTimer = "both",   -- auraDebuffSize follows auraSize until set
    -- cast bar (target and focus): Blizzard's own bar drives one built into our frame
    castShow = true, castText = true, castIcon = true,
    -- frame art colour: "default" (as drawn), "dark", "silver", "class" or "custom" (frameColor = { r, g, b })
    frameTint = "default",
    -- health bar extras
    smoothBars = true, healPrediction = true, absorbs = true,
    combatNumbers = false,   -- damage / heal numbers over the portrait: fixed per frame (player, target, focus), one General switch
    -- icons and extras
    comboPoints = true,
    petColor = "player",     -- pet health bar: "player" (the player frame's colour) or "plain" (green)
    petHappy = "corner",     -- hunter pet happiness: "corner" (over the corner accent), "badge" (in the level circle) or "off"
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

local DB, lib
local frames = {}            -- unit -> frame
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
    -- 0.57 test builds had one icon size and a countdown-numbers checkbox
    if v == nil and key == "auraDebuffSize" then return getSetting(unit, "auraSize") end
    -- the power bar's texture follows the health bar's until it's set (there used to be one for both)
    if v == nil and key == "powerTexture" then return getSetting(unit, "barTexture") end
    -- older builds: the low health fade had styles, aura position had "right of the frame"
    if key == "healthFade" and type(v) == "string" then return v ~= "off" end
    if key == "auraPos" and v == "right" then v = "custom" end
    if v == nil and key == "petHappy" and u and u.petHappiness == false then return "off" end
    if v == nil and key == "auraTimer" and u and u.auraTimers == false then return "swipe" end
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

-- Writes "12.3K", "85%" or "12.3K (85%)" depending on the unit's text format. Power other than mana
-- (rage, energy, focus, runic power, ...) is a small fixed pool, so it always shows its plain value.
-- Forever can hand back secret numbers, so every touch is wrapped.
local function setBarText(fs, f, kind)
    local u = f.wfUnit
    local fmt = getSetting(f.baseUnit, "textFormat")
    local cur
    if kind == "hp" then cur = UnitHealth(u) else cur = UnitPower(u) end
    local token = select(2, UnitPowerType(u))
    if kind == "mp" then
        local mana = false
        pcall(function() mana = (token == "MANA") end)
        if not mana then fmt = "value" end
    end
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


local PLAYER_AS_FRAME = { wfUnit = "player", baseUnit = "player" }

local function healthColor(f)
    local u, base = f.wfUnit, f.baseUnit
    local r, g, b

    local tapped
    pcall(function() tapped = (not UnitPlayerControlled(u)) and UnitIsTapDenied(u) end)
    if tapped then return 0.5, 0.5, 0.5 end

    -- the pet's own selection colour flips around (neutral / friendly / controlled), so its bar is either
    -- the player frame's colour (as set on the player page: your class colour, say) or plain green
    if base == "pet" then
        if getSetting("pet", "petColor") == "player" then
            r, g, b = healthColor(PLAYER_AS_FRAME)
            if r then return r, g, b end
        end
        return 0.1, 0.8, 0.1
    end

    local mode = getSetting(base, "colorMode")
    -- friendly pets and guardians (on any frame, e.g. targeting your pet): their selection colour
    -- flips between friendly, neutral and "controlled" blue, so they are always green
    if mode ~= "plain" and mode ~= "class" then
        local friendlyPet
        pcall(function() friendlyPet = UnitPlayerControlled(u) and not UnitIsPlayer(u) and not UnitCanAttack("player", u) end)
        if friendlyPet then return 0.1, 0.8, 0.1 end
        -- hostile NPCs can have their own colour instead of reaction red (green, say, so the fade to red
        -- has somewhere to go); neutral ones keep their yellow
        local npc = getSetting(base, "npcColor")
        if npc == "green" or npc == "custom" then
            local hostileNPC
            pcall(function() hostileNPC = (not UnitIsPlayer(u)) and UnitReaction(u, "player") <= 3 end)
            if hostileNPC then
                local c = npc == "custom" and getSetting(base, "npcColorRGB")
                if type(c) == "table" then return c[1] or 0.1, c[2] or 0.8, c[3] or 0.1 end
                return 0.1, 0.8, 0.1
            end
        end
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
    local list = { { "default", previewLabel("Default", BAR_FILE.player .. "Health") } }
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
    -- on: the health colour chosen above (class, reaction or plain green) fades to red as health drops
    if not getSetting(f.baseUnit, "healthFade") then return false end
    if not (UnitHealthPercent and UnitExists(f.wfUnit)) then return false end
    local curve = getFadeCurve("reactive", r or 0.1, g or 0.8, b or 0.1)
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

-- Sets a bar's value, sliding to it (Blizzard's own interpolation, so protected values are fine) when
-- the frame's "Smooth bars" option is on and the client supports it.
local SMOOTH = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
local function setBarValue(f, bar, value)
    if SMOOTH and getSetting(f.baseUnit, "smoothBars") then
        if pcall(bar.SetValue, bar, value, SMOOTH) then return end
    end
    bar:SetValue(value)
end

---------------------------------------------------------------------------
-- Health bar extras: incoming heals and absorb shields past the end of the health fill, and healing
-- absorbs eating back into it. Secret-safe: each is a bar as long as the health bar, anchored to the
-- health fill's moving end (no maths on the values), with the same min / max; the values only ever go
-- to setters. They're clipped to the health bar, so nothing spills past its end.
---------------------------------------------------------------------------
local PLAIN_FILL = "Interface\\TargetingFrame\\UI-StatusBar"

local function newOverlay(f, r, g, b, a, reverse)
    local bar = CreateFrame("StatusBar", nil, f.predClip)
    bar:SetFrameLevel(f.predClip:GetFrameLevel())
    bar:SetStatusBarTexture(PLAIN_FILL)
    bar.color = { r, g, b, a }
    if reverse then bar:SetReverseFill(true) end
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    return bar
end

-- The overlays wear the frame's own bar texture (a chosen SharedMedia one, or the frame's tintable
-- default fill), tinted, with the health bar's shape mask.
local function styleOverlay(f, bar)
    local tex = f.customTex or f.hpStatusAtlas or PLAIN_FILL
    if bar.tex ~= tex then
        bar.tex = tex
        if not pcall(bar.SetStatusBarTexture, bar, tex) or not bar:GetStatusBarTexture() then bar:SetStatusBarTexture(PLAIN_FILL) end
        bar.masked = nil
    end
    local c = bar.color
    bar:SetStatusBarColor(c[1], c[2], c[3], c[4])
    pcall(function() bar:GetStatusBarTexture():SetDesaturated(not f.customTex) end)
    if f.hpMaskOn and not bar.masked then
        bar.masked = true
        pcall(function() bar:GetStatusBarTexture():AddMaskTexture(f.hpMask) end)
    end
end

local function value(fn, u)
    local v
    pcall(function() v = fn(u) end)
    return v
end

-- Blizzard's heal prediction calculator (12.x, as EllesmereUI uses it): splits incoming heals into
-- yours and everyone else's, clamped to the unit's missing health. nil on clients without it.
local function healCalculator(f)
    if f.healCalc == nil then
        f.healCalc = false
        if CreateUnitHealPredictionCalculator and UnitGetDetailedHealPrediction then
            pcall(function()
                local calc = CreateUnitHealPredictionCalculator()
                local E = Enum or {}
                if calc.SetIncomingHealClampMode and E.UnitIncomingHealClampMode then
                    calc:SetIncomingHealClampMode(E.UnitIncomingHealClampMode.MaximumHealth)
                end
                if calc.SetHealAbsorbClampMode and E.UnitHealAbsorbClampMode then
                    calc:SetHealAbsorbClampMode(E.UnitHealAbsorbClampMode.MaximumHealth)
                end
                if calc.SetHealAbsorbMode and E.UnitHealAbsorbMode then
                    calc:SetHealAbsorbMode(E.UnitHealAbsorbMode.ReducedByIncomingHeals)
                end
                f.healCalc = calc
            end)
        end
    end
    return f.healCalc or nil
end

local function updatePrediction(f)
    if f.previewing then return end            -- /webby test is showing made-up values
    local wantHeals = getSetting(f.baseUnit, "healPrediction")
    local wantAbsorbs = getSetting(f.baseUnit, "absorbs")
    if not (wantHeals or wantAbsorbs) and not f.predClip then return end
    if not f.predClip then
        -- clipped to the health bar, just above its fill
        f.predClip = CreateFrame("Frame", nil, f.hp)
        f.predClip:SetAllPoints(f.hp)
        f.predClip:SetClipsChildren(true)
        f.predClip:SetFrameLevel(f.hp:GetFrameLevel() + 1)
        f.healBar = newOverlay(f, 0.1, 0.9, 0.3, 0.6)          -- your incoming heals: green
        f.otherHealBar = newOverlay(f, 0.05, 0.6, 0.2, 0.5)    -- everyone else's: darker green
        f.absorbBar = newOverlay(f, 0.7, 0.9, 1, 0.7)          -- shields: pale blue
        f.healAbsorbBar = newOverlay(f, 0.9, 0.1, 0.1, 0.6, true)   -- heal absorbs: red, eating back in
    end
    for _, bar in ipairs({ f.healBar, f.otherHealBar, f.absorbBar, f.healAbsorbBar }) do styleOverlay(f, bar) end
    local u = f.wfUnit
    local fill = f.hp:GetStatusBarTexture()
    local w = f.hp:GetWidth()
    -- your heals start at the end of the health fill, then everyone else's, then the shield
    f.healBar:ClearAllPoints()
    f.healBar:SetPoint("TOPLEFT", fill, "TOPRIGHT")
    f.healBar:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT")
    f.healBar:SetWidth(w)
    local myFill = f.healBar:GetStatusBarTexture()
    f.otherHealBar:ClearAllPoints()
    f.otherHealBar:SetPoint("TOPLEFT", myFill, "TOPRIGHT")
    f.otherHealBar:SetPoint("BOTTOMLEFT", myFill, "BOTTOMRIGHT")
    f.otherHealBar:SetWidth(w)
    local healFill = f.otherHealBar:GetStatusBarTexture()
    f.absorbBar:ClearAllPoints()
    f.absorbBar:SetPoint("TOPLEFT", healFill, "TOPRIGHT")
    f.absorbBar:SetPoint("BOTTOMLEFT", healFill, "BOTTOMRIGHT")
    f.absorbBar:SetWidth(w)
    -- healing absorbs run backwards from the end of the health fill
    f.healAbsorbBar:ClearAllPoints()
    f.healAbsorbBar:SetPoint("TOPRIGHT", fill, "TOPRIGHT")
    f.healAbsorbBar:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
    f.healAbsorbBar:SetWidth(w)

    local max = value(UnitHealthMax, u)
    local dead = unitStatus(u) ~= nil
    for _, bar in ipairs({ f.healBar, f.otherHealBar, f.absorbBar, f.healAbsorbBar }) do
        if max then pcall(bar.SetMinMaxValues, bar, 0, max) end
    end
    -- incoming heals: through the calculator when the client has it (yours and others' apart), else
    -- the older all-in-one total on the first bar
    local mine, others
    if wantHeals and not dead then
        local calc = healCalculator(f)
        local ok = calc and pcall(function()
            UnitGetDetailedHealPrediction(u, "player", calc)
            local _, m, o = calc:GetIncomingHeals()
            mine, others = m, o
        end)
        if not ok then mine, others = value(UnitGetIncomingHeals, u), nil end
    end
    local absorb = (wantAbsorbs and not dead) and value(UnitGetTotalAbsorbs, u) or nil
    local healAbsorb = (wantAbsorbs and not dead) and value(UnitGetTotalHealAbsorbs, u) or nil
    -- (a missing value counts as none; the heal bars stay at 0 so the shield still starts at the health end)
    if not pcall(setBarValue, f, f.healBar, mine) then f.healBar:SetValue(0) end
    if not pcall(setBarValue, f, f.otherHealBar, others) then f.otherHealBar:SetValue(0) end
    if not pcall(setBarValue, f, f.absorbBar, absorb) then f.absorbBar:SetValue(0) end
    if not pcall(setBarValue, f, f.healAbsorbBar, healAbsorb) then f.healAbsorbBar:SetValue(0) end
end


local function updateHealth(f)
    if f.previewing then return end            -- /webby test is showing made-up values
    local u = f.wfUnit
    if not UnitExists(u) then return end
    local status = unitStatus(u)
    updateHealthColor(f)
    f.hp:SetMinMaxValues(0, UnitHealthMax(u))
    if status == "Offline" then
        -- offline: a full grey bar, as the default UI does
        setBarValue(f, f.hp, UnitHealthMax(u))
        f.hp:SetStatusBarColor(0.5, 0.5, 0.5, 1)
        pcall(function() f.hp:GetStatusBarTexture():SetDesaturated(true) end)
    else
        setBarValue(f, f.hp, UnitHealth(u))
    end
    pcall(updatePrediction, f)
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
    local fill, tinted = f.powerTex, true
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
    setBarValue(f, f.mp, UnitPower(u))
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
-- Forever's own small faction shields (its player frame tucks them against the level circle), then
-- Retail's badges, then the old Classic files
local PVP_ICONS = {
    Horde    = { "UI-HUD-UnitFrame-SmallCircle-Horde",    "UI-HUD-UnitFrame-Player-PVP-HordeIcon",    "Interface\\TargetingFrame\\UI-PVP-Horde" },
    Alliance = { "UI-HUD-UnitFrame-SmallCircle-Alliance", "UI-HUD-UnitFrame-Player-PVP-AllianceIcon", "Interface\\TargetingFrame\\UI-PVP-Alliance" },
    FFA      = { "UI-HUD-UnitFrame-SmallCircle-FFA",      "UI-HUD-UnitFrame-Player-PVP-FFAIcon",      "Interface\\TargetingFrame\\UI-PVP-FFA" },
}
-- Forever's shield (24 x 27, its own size) sits just above the level circle, its centre 10.5px in from
-- the circle's (Forever's frame: the shield at x 22, the 39px circle at x 13). Its frame is taller than
-- ours, so it's placed from the circle rather than the frame's top. Mirrored on the right-portrait frames.
local PVP_SHIELD_POS = { -10.5, -20 }      -- from the level circle's top centre (both arts have clear margins)

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
            -- greyed first when it's tinted to the frame colour, so the art's gold doesn't mix in
            SetDesaturated = function(_, d)
                for _, t in ipairs({ glow, halo, lit }) do pcall(t.SetDesaturated, t, d) end
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
    -- party leader crown (shown by updateInfo, placed by placeIndicators)
    f.leaderIcon = ov:CreateTexture(nil, "OVERLAY", nil, 6)
    f.leaderIcon:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
    f.leaderIcon:SetSize(16, 16)
    f.leaderIcon:Hide()
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
    if f.leaderIcon then
        -- on top of the portrait ring, centred (the outer corner is the PvP badge's, the top right the Zzz's)
        f.leaderIcon:ClearAllPoints()
        f.leaderIcon:SetPoint("CENTER", p, "TOP", 0, 1)
    end
    if f.restIcon then
        f.restIcon:ClearAllPoints()
        f.restIcon:SetPoint("CENTER", p, "TOPRIGHT", -4, 4)
    end
    if f.pvpIcon then
        f.pvpIcon:ClearAllPoints()
        if f.pvpSmall and f.badge then
            -- Forever's small shield, exactly where Forever's own player frame has it (see PVP_SHIELD_POS)
            f.pvpIcon:SetPoint("BOTTOM", f.badge, "TOP", left and PVP_SHIELD_POS[1] or -PVP_SHIELD_POS[1], PVP_SHIELD_POS[2])
        elseif left then
            -- the larger fallback badge: outside the portrait on the frame's outer edge, raised
            f.pvpIcon:SetPoint("LEFT", p, "LEFT", -22, 14)
        else
            f.pvpIcon:SetPoint("RIGHT", p, "RIGHT", 22, 14)
        end
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
            local cornerOn = not showC
            f.corner:SetShown(cornerOn)
            if f.cornerBack then f.cornerBack:SetShown(cornerOn) end
        end
        if f.cornerGlow then f.cornerGlow:SetShown(f.corner and f.corner:IsShown() or false) end
        if f.status then
            local resting = false
            pcall(function() resting = IsResting() and true or false end)
            if showC then
                f.status:SetDesaturated(false)
                f.status:SetVertexColor(1, 0, 0)
                f.status:Show()
                if f.statusAnim and not f.statusAnim:IsPlaying() then f.statusAnim:Play() end
            elseif resting then
                if f.statusAnim then f.statusAnim:Stop() end
                f.status:SetAlpha(1)
                -- the resting glow takes the frame colour (brightened to full strength, so a dark
                -- frame still glows), gold when the frame is as drawn
                local c = f.tintColor
                if c then
                    local top = math.max(c[1], c[2], c[3], 0.01)
                    f.status:SetDesaturated(true)
                    f.status:SetVertexColor(c[1] / top, c[2] / top, c[3] / top)
                else
                    f.status:SetDesaturated(false)
                    f.status:SetVertexColor(1, 0.88, 0.25)
                end
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
        f.pvpSmall = f.badge and hasAtlas(ic[1]) and true or false
        if f.pvpSmall then
            f.pvpIcon:SetTexCoord(0, 1, 0, 1)
            f.pvpIcon:SetAtlas(ic[1], true)                -- its own size, 24 x 27
            f.pvpIcon:SetDrawLayer("OVERLAY", 2)           -- over the level circle (-1), under the level number (3)
        else
            setIcon(f.pvpIcon, ic[2], ic[3], 0, 0.609375, 0, 0.640625)
            f.pvpIcon:SetDrawLayer("OVERLAY", 5)
        end
        placeIndicators(f)
        f.pvpIcon:Show()
        if f.pvpHit then f.pvpHit:Show() end
    else
        f.pvpIcon:Hide()
        if f.pvpHit then f.pvpHit:Hide() end
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
-- Ours is driven by Blizzard's: Blizzard's target / focus frames keep running, invisible and parked off
-- the screen (see hideAllBlizzard), so their cast bars handle the protected cast data as usual, and
-- every frame ours copies the progress, fade, cast type, spell name and icon. Values only go to setters.
---------------------------------------------------------------------------
-- The box, in the frame's TOPLEFT coordinates. Its top border line is the frame art's bottom border line
-- (at y -71, under the mana bar): the cast bar shares that line with the mana bar.
-- On the target layout it runs on to the level badge, which is drawn on top and hides its end.
-- On the player layout it runs from just right of the ring to the end of the bars, with a side line at
-- each end level with the bars' own ends (x 83.5 and 210).
local CAST_BOX = { top = -71, right = { 20.5, 200 }, left = { 82, 211.5 } }
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
    -- the border: 3 rows x 3 columns of frame-art slices (left cap, stretched middle, and the
    -- left cap mirrored as a right cap: only the player layout uses that, the target's end is under the ring)
    cb.slices = {}
    for r = 1, 3 do
        for c = 1, 3 do
            local t = box:CreateTexture(nil, "BACKGROUND", nil, 2)
            local xs = (c == 2) and CAST_ART.midX or CAST_ART.capX
            if c == 3 then xs = { xs[2], xs[1] } end
            artSlice(t, xs[1], xs[2], CAST_ART.rows[r][1], CAST_ART.rows[r][2], CAST_ART.rows[r][3])
            t.row, t.col = r, c
            cb.slices[#cb.slices + 1] = t
        end
    end
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
    -- Blizzard's bar keeps running in its own (invisible, parked) frame; ours shows its progress
    if not getSetting(f.baseUnit, "castShow") then
        cb.box:Hide()
        return
    end
    -- the player layout (portrait left) runs from the ring to the frame's right end; the target layout
    -- from the frame's left end on under the ring
    local left = f.layoutLeft
    if left == nil then left = portraitOnLeft(f.baseUnit) end
    local x = left and CAST_BOX.left or CAST_BOX.right
    local h = castBoxHeight()
    local box = cb.box
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", f, "TOPLEFT", x[1], CAST_BOX.top)
    box:SetPoint("BOTTOMRIGHT", f, "TOPLEFT", x[2], CAST_BOX.top - h)
    -- the border slices: rows stacked down the box, the cap at the left, the middle stretched to the end
    -- (or to the right cap, on the player layout)
    local capW = CAST_ART.capX[2] - CAST_ART.capX[1]
    for _, t in ipairs(cb.slices) do
        local y = 0
        for r = 1, t.row - 1 do y = y + CAST_ART.rowH[r] end
        t:ClearAllPoints()
        if t.col == 1 then
            t:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -y)
            t:SetSize(capW, CAST_ART.rowH[t.row])
        elseif t.col == 3 then
            t:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, -y)
            t:SetSize(capW, CAST_ART.rowH[t.row])
        else
            t:SetPoint("TOPLEFT", box, "TOPLEFT", capW, -y)
            t:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", left and -capW or 0, -(y + CAST_ART.rowH[t.row]))
        end
    end
    -- the frame's own bar texture (a chosen SharedMedia one, or the default tintable fill) ...
    local fill = f.customTex or ((left and BAR_FILE.player or BAR_FILE.target) .. "Health-Status")
    if cb.fill ~= fill then
        cb.fill = fill
        cb:SetStatusBarTexture(fill)
        cb.fillMasked = nil
    end
    -- target layout: cut the box's end along the portrait ring (once per texture)
    if not left then
        if not cb.boxMaskSet then
            cb.boxMaskSet = true
            cb.boxMask:SetTexture(MEDIA .. "castbox-mask-target", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            for _, t in ipairs(cb.slices) do t:AddMaskTexture(cb.boxMask) end
        end
        if not cb.fillMasked then
            cb.fillMasked = true
            local tex = cb:GetStatusBarTexture()
            pcall(tex.AddMaskTexture, tex, cb.boxMask)   -- may already have it if the texture object was reused
        end
    end
    -- ... and its font, at the size and style of the health bar numbers
    pcall(function() cb.text:SetFont(f.hpText:GetFont()) end)
    -- the frame art's border (the right cap only on the player layout)
    for _, t in ipairs(cb.slices) do t:SetShown(t.col ~= 3 or left) end
    local inL, inT, inB = CAST_ART.inset.left, CAST_ART.inset.top, CAST_ART.inset.bottom
    local inR = left and inL or 0        -- the player layout's right cap has a side line too
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
    cb:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -inR, inB)
    -- the spell name is centred under the health bar (the bar itself runs on to the level badge)
    local fillLeft = x[1] + inL + (showIcon and (inner + 1) or 0)   -- (the shadow sits over the fill's first px)
    local hpMid = left and (85 + 124 / 2) or (23 + 126 / 2)
    cb.text:ClearAllPoints()
    -- (1px up: the font string's box includes room for descenders, so it sits low when centred)
    cb.text:SetPoint("CENTER", cb, "CENTER", hpMid - (fillLeft + x[2] - inR) / 2, 1)
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
    -- (Blizzard's bar stays in its own frame, which hideAllBlizzard keeps running but invisible)
    bar:HookScript("OnShow", function() pcall(placeCastbar, f) end)
    f:HookScript("OnUpdate", function() mirrorCastbar(f) end)
    placeCastbar(f)
end

---------------------------------------------------------------------------
-- Buffs and debuffs. Secret-safe: aura fields only ever go to setters, timers go through duration
-- objects (SetCooldownFromDurationObject) and stack counts through the display-count API.
---------------------------------------------------------------------------
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

-- Where the aura block starts: below the frame art (default), just above its name, or wherever it was
-- dragged in Edit Mode ("custom": auraX / auraY from the frame's top left; it starts where "below" is).
local function auraAnchor(f, pos)
    if pos == "custom" then
        local cx, cy = getSetting(f.baseUnit, "auraX"), getSetting(f.baseUnit, "auraY")
        if type(cx) == "number" and type(cy) == "number" then return "TOPLEFT", "TOPLEFT", cx, cy end
        pos = "below"
    end
    if f.small then
        if pos == "above" then return "BOTTOMLEFT", "TOPLEFT", 4, 2 end
        return "TOPLEFT", "BOTTOMLEFT", 4, 0
    end
    -- tucked under the frame art's bottom edge, from its left edge (on the player frame, just right of the level circle)
    local x = f.layoutLeft and 55 or 22
    -- above: sitting right on the frame art's top edge, over the name and lined up with its left end
    if pos == "above" then return "BOTTOMLEFT", "TOPLEFT", f.layoutLeft and 87 or 23, -15 end
    -- With a cast bar they lock onto its bottom (always, cast or not, so the icons don't jump about),
    -- lined up with its left line.
    if f.castbar and getSetting(f.baseUnit, "castShow") then
        local cx = (f.layoutLeft and CAST_BOX.left or CAST_BOX.right)[1]
        -- just below the cast box (its bottom line's soft shadow included)
        return "TOPLEFT", "TOPLEFT", cx + 1.5, CAST_BOX.top - castBoxHeight() - 1
    end
    return "TOPLEFT", "TOPLEFT", x, -87
end

-- The "Time left" option as two switches: the dark sweep and the countdown numbers.
local function auraTimerParts(base)
    local mode = getSetting(base, "auraTimer")
    return mode == "both" or mode == "swipe", mode == "both" or mode == "numbers"
end

local function updateAurasLegacy(f)
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
    local perRow, max = getSetting(base, "auraPerRow"), getSetting(base, "auraMax")
    local pos = getSetting(base, "auraPos")
    local point, relPoint, x, y = auraAnchor(f, pos)
    f.auraBox:ClearAllPoints()
    f.auraBox:SetPoint(point, f, relPoint, x, y)
    local up = (pos == "above")
    local swipe, timers = auraTimerParts(base)
    local u = f.wfUnit
    local n, col, rowY, size = 0, 0, 0, 0     -- rowY: how far the current row starts from the box edge

    local function place(b)
        b:SetSize(size, size)
        b:ClearAllPoints()
        local bx = col * (size + AURA_GAP)
        if up then b:SetPoint("BOTTOMLEFT", f.auraBox, "BOTTOMLEFT", bx, rowY)
        else b:SetPoint("TOPLEFT", f.auraBox, "TOPLEFT", bx, -rowY) end
        col = col + 1
        if col >= perRow then col, rowY = 0, rowY + size + AURA_GAP end
    end

    local function group(filter, isDebuff)
        size = getSetting(base, isDebuff and "auraDebuffSize" or "auraSize")
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
            -- sweep, countdown numbers and stack count sized to the icon
            pcall(b.cd.SetDrawSwipe, b.cd, swipe)
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
        if count > 0 and col > 0 then col, rowY = 0, rowY + size + AURA_GAP end   -- the next group starts a new row
    end

    if showB then group("HELPFUL", false) end
    if showD then group(getSetting(base, "auraMine") and "HARMFUL|PLAYER" or "HARMFUL", true) end
    for i = n + 1, #f.auraButtons do f.auraButtons[i]:Hide() end
    -- how tall the aura block is, so the cast bar can sit under it
    f.auraHeight = rowY
    placeCastbar(f)
end

---------------------------------------------------------------------------
-- Buffs and debuffs through Blizzard's AuraContainer (12.1, on Forever too). In combat the aura data is
-- protected, so addons can't read it; the container tracks and filters the unit's auras itself and fills
-- buttons we've styled: we give each button its icon texture, cooldown swipe, stack count and dispel
-- border, and set the layout. (updateAurasLegacy above is the fallback for clients without it.)
---------------------------------------------------------------------------
local AuraKit = { GROUPS = { "buffs", "debuffs" } }

-- Debuff edge colours by dispel type, as the container wants them (colour objects, "None" for none).
function AuraKit.dispelColors()
    if AuraKit.colorMap then return AuraKit.colorMap end
    local map = {}
    for name, c in pairs({ Magic = { 0.2, 0.6, 1 }, Curse = { 0.6, 0, 1 }, Disease = { 0.6, 0.4, 0 },
                           Poison = { 0, 0.6, 0 }, None = { 0.8, 0, 0 } }) do
        local dc = DebuffTypeColor and DebuffTypeColor[name == "None" and "none" or name]
        map[name] = CreateColor(dc and dc.r or c[1], dc and dc.g or c[2], dc and dc.b or c[3], 1)
    end
    AuraKit.colorMap = map
    return map
end

-- Styles one aura button (the container calls this as it creates them); f is the unit frame.
function AuraKit.styleButton(f, b)
    -- 1px edge: black behind every icon; on debuffs a second, white edge layer on top that the
    -- container tints by dispel type (see below)
    b.webbyBack = b:CreateTexture(nil, "BACKGROUND", nil, 0)
    b.webbyBack:SetAllPoints()
    b.webbyBack:SetColorTexture(0, 0, 0, 1)
    b.webbyEdge = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    b.webbyEdge:SetAllPoints()
    b.webbyEdge:SetColorTexture(1, 1, 1, 1)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    b:SetIcon(icon)
    -- (the template gives it a sweep texture; a bare Cooldown has none, so it drew no sweep)
    local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    cd:SetAllPoints(icon)
    pcall(cd.SetSwipeTexture, cd, "Interface\\Buttons\\WHITE8X8")
    pcall(cd.SetDrawSwipe, cd, true)
    pcall(cd.SetReverse, cd, true)
    pcall(cd.SetDrawEdge, cd, false)
    pcall(cd.SetSwipeColor, cd, 0, 0, 0, 0.6)
    pcall(cd.SetDrawBling, cd, false)            -- no flash when the aura ends
    pcall(b.SetDurationCooldown, b, cd)
    b.webbyCD = cd
    local top = CreateFrame("Frame", nil, b)
    top:SetAllPoints()
    top:SetFrameLevel(cd:GetFrameLevel() + 1)
    local count = top:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    count:SetPoint("BOTTOMRIGHT", 1, 0)
    pcall(b.SetApplicationCount, b, count)
    b.webbyCount = count
    -- Debuffs: the white edge layer, kept as it is (PreserveAsset) and tinted by the container per
    -- dispel type, red when there's none; it only shows on harmful auras, so buffs keep the black edge.
    -- (Blizzard's built-in Border style is a heavy old-style frame that didn't match the 1px edges.)
    local styles = Enum.CustomAuraButtonDispelTypeTextureStyle
    local ok = pcall(b.AddDispelTypeTexture, b, b.webbyEdge, {
        style = styles and styles.PreserveAsset,
        showWhenHarmful = true,
        showWithoutDispelType = true,
        customDispelColorMap = AuraKit.dispelColors(),
    })
    if not ok then b.webbyEdge:Hide() end
    AuraKit.sizeButton(f, b)
end

-- Size, sweep, countdown numbers and stack text to the frame's current options.
function AuraKit.sizeButton(f, b)
    local size = getSetting(f.baseUnit, b.webbyDebuff and "auraDebuffSize" or "auraSize")
    b:SetSize(size, size)
    local swipe, timers = auraTimerParts(f.baseUnit)
    if b.webbyCD then
        pcall(b.webbyCD.SetDrawSwipe, b.webbyCD, swipe)
        pcall(b.webbyCD.SetHideCountdownNumbers, b.webbyCD, not timers)
        pcall(function()
            local fs = b.webbyCD:GetCountdownFontString()
            fs:SetFont(fs:GetFont() or STANDARD_TEXT_FONT, math.max(8, math.floor(size * 0.45)), "OUTLINE")
        end)
    end
    if b.webbyCount then
        pcall(function() b.webbyCount:SetFont(b.webbyCount:GetFont() or STANDARD_TEXT_FONT, math.max(8, math.floor(size * 0.5)), "OUTLINE") end)
    end
end

-- The frame's container, made on first use; nil if the client doesn't have AuraContainer.
function AuraKit.container(f)
    if f.auraContainer ~= nil then return f.auraContainer or nil end
    local ok, c = pcall(CreateFrame, "AuraContainer", nil, f.ov or f, "CustomAuraContainerTemplate")
    if not (ok and c) then f.auraContainer = false; return nil end
    local function initBuff(b) pcall(AuraKit.styleButton, f, b) end
    local function initDebuff(b) b.webbyDebuff = true; pcall(AuraKit.styleButton, f, b) end
    local ok2 = pcall(function()
        c:SetUnit(f.wfUnit)
        c:AddAuraGroup("buffs", "HELPFUL", { initializeFrame = initBuff })
        c:AddAuraGroup("debuffs", "HARMFUL", { initializeFrame = initDebuff })
    end)
    if not ok2 then c:Hide(); f.auraContainer = false; return nil end
    f.auraContainer = c
    return c
end

local updateAuras     -- (below; the mover calls it)

-- every unit frame
function AuraKit.allFrames()
    local list = {}
    for _, unit in ipairs(UNITS) do if frames[unit] then list[#list + 1] = frames[unit] end end
    return list
end

-- Custom position: in Edit Mode a box shows where the buffs and debuffs start (one row's size); drag it
-- and the block follows. The spot is saved as an offset from the frame's top left (per Edit Mode layout).
function AuraKit.placeMover(f, w, h)
    local on = AuraKit.editing and getSetting(f.baseUnit, "auraPos") == "custom"
        and (getSetting(f.baseUnit, "auraBuffs") or getSetting(f.baseUnit, "auraDebuffs"))
    if not on then
        if f.auraMover then f.auraMover:Hide() end
        return
    end
    local m = f.auraMover
    if not m then
        m = CreateFrame("Frame", nil, f.ov or f)
        m:SetFrameLevel((f.ov or f):GetFrameLevel() + 10)
        local bg = m:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.2, 0.55, 1, 0.35)
        local edge = m:CreateTexture(nil, "BORDER")
        edge:SetPoint("TOPLEFT", -1, 1); edge:SetPoint("BOTTOMRIGHT", 1, -1)
        edge:SetColorTexture(0.4, 0.75, 1, 0.9)
        local inner = m:CreateTexture(nil, "BORDER", nil, 1)
        inner:SetAllPoints()
        inner:SetColorTexture(0.05, 0.15, 0.3, 0.6)
        m.label = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        m.label:SetPoint("CENTER")
        m.label:SetText("Buffs / debuffs")
        m:SetMovable(true)
        m:SetClampedToScreen(true)
        m:EnableMouse(true)
        m:RegisterForDrag("LeftButton")
        m:SetScript("OnDragStart", function(self) self:StartMoving() end)
        m:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local x = math.floor((self:GetLeft() - f:GetLeft()) * 2 + 0.5) / 2
            local y = math.floor((self:GetTop() - f:GetTop()) * 2 + 0.5) / 2
            local u = unitData(f.baseUnit, true)
            u.auraX, u.auraY = x, y
            for _, other in ipairs(AuraKit.allFrames()) do
                if other.baseUnit == f.baseUnit then pcall(updateAuras, other) end
            end
        end)
        m:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Buffs and debuffs", 1, 1, 1)
            GameTooltip:AddLine("Drag to move them. The first row starts here.", 1, 0.82, 0, true)
            GameTooltip:Show()
        end)
        m:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f.auraMover = m
    end
    local point, relPoint, x, y = auraAnchor(f, "custom")
    m:ClearAllPoints()
    m:SetPoint(point, f, relPoint, x, y)
    m:SetSize(math.max(w, 40), math.max(h, 12))
    m:Show()
end

-- Edit Mode on / off: show or hide the boxes.
function AuraKit.setEditing(on)
    AuraKit.editing = on and true or nil
    for _, f in ipairs(AuraKit.allFrames()) do pcall(updateAuras, f) end
end

function updateAuras(f)       -- (the local declared above)
    local c = AuraKit.container(f)
    if not c then return updateAurasLegacy(f) end
    local base = f.baseUnit
    local showB = getSetting(base, "auraBuffs") and true or false
    local showD = getSetting(base, "auraDebuffs") and true or false
    local perRow, max = getSetting(base, "auraPerRow"), getSetting(base, "auraMax")
    -- rows are as wide as perRow of the bigger icons, so neither group spills past them
    local size = math.max(showB and getSetting(base, "auraSize") or 0, showD and getSetting(base, "auraDebuffSize") or 0)
    if size == 0 then size = getSetting(base, "auraSize") end
    local pos = getSetting(base, "auraPos")
    local up = (pos == "above")
    pcall(function() if c:GetUnit() ~= f.wfUnit then c:SetUnit(f.wfUnit) end end)
    pcall(c.SetAuraGroupEnabled, c, "buffs", showB)
    pcall(c.SetAuraGroupEnabled, c, "debuffs", showD)
    pcall(c.SetAuraGroupFilterString, c, "debuffs", getSetting(base, "auraMine") and "HARMFUL|PLAYER" or "HARMFUL")
    for _, g in ipairs(AuraKit.GROUPS) do
        pcall(c.SetAuraGroupMaxFrameCount, c, g, max)
        pcall(c.SetAuraGroupLayout, c, g, { elementSpacing = AURA_GAP, lineSpacing = AURA_GAP, groupSpacing = AURA_GAP, groupLineSpacing = AURA_GAP })
    end
    -- flow: rows of perRow icons, growing right and down (up when above the frame)
    pcall(function()
        local A = AnchorUtil
        c:SetFlowLayoutAxis(A.FlowLayoutAxis.Horizontal)
        c:SetFlowLayoutAnchorPoint(up and "BOTTOMLEFT" or "TOPLEFT")
        c:SetFlowLayoutGrowthDirection(A.FlowDirection.Right, up and A.FlowDirection.Up or A.FlowDirection.Down)
        c:SetFlowLayoutMaximumLineSize(perRow * (size + AURA_GAP))
    end)
    local point, relPoint, x, y = auraAnchor(f, pos)
    c:ClearAllPoints()
    c:SetPoint(point, f, relPoint, x, y)
    -- one row's size, so the first row sits exactly on the anchor (more rows grow on past it)
    pcall(c.SetSize, c, perRow * (size + AURA_GAP), size)
    AuraKit.placeMover(f, perRow * (size + AURA_GAP) - AURA_GAP, size)
    -- resize the buttons made so far (new ones are sized as they're made)
    for _, g in ipairs(AuraKit.GROUPS) do
        local n = 0
        pcall(function() n = c:GetAuraGroupFrameCount(g) end)
        for i = 1, n do
            local b
            pcall(function() b = c:GetAuraGroupFrame(g, i) end)
            if b then pcall(AuraKit.sizeButton, f, b) end
        end
    end
    c:SetShown(showB or showD)
    f.auraBox = c
    f.auraHeight = 0
    placeCastbar(f)
end


---------------------------------------------------------------------------
-- Combat numbers: damage and healing the unit takes pop up over its portrait and fade, like Blizzard's
-- old portrait hit indicator. From UNIT_COMBAT; the amount may be protected, so it only goes to setters.
---------------------------------------------------------------------------
local HIT_WORDS = {   -- actions shown as a word instead of a number
    DODGE = DODGE, PARRY = PARRY, BLOCK = BLOCK, MISS = MISS, IMMUNE = IMMUNE, ABSORB = ABSORB,
    RESIST = RESIST, EVADE = EVADE, DEFLECT = DEFLECT, REFLECT = REFLECT,
}

local function hitText(f)
    if f.hitText then return f.hitText end
    local fs = f.ov:CreateFontString(nil, "OVERLAY", "NumberFontNormalHuge")
    fs:SetDrawLayer("OVERLAY", 7)
    fs:SetPoint("CENTER", f.portrait, "CENTER", 0, 0)
    fs:Hide()
    local ag = fs:CreateAnimationGroup()
    local fade = ag:CreateAnimation("Alpha")
    fade:SetFromAlpha(1); fade:SetToAlpha(0)
    fade:SetStartDelay(0.7); fade:SetDuration(0.5)
    ag:SetScript("OnFinished", function() fs:Hide() end)
    fs.anim = ag
    f.hitText = fs
    return fs
end

local function showHit(f, action, indicator, amount)
    -- the General page's master switch, then the frame's own option
    -- one switch on the General page; the numbers show on the player, target and focus frames
    if DB.combatNumbers == false or not defaultFor(f.baseUnit, "combatNumbers") then return end
    local fs = hitText(f)
    -- (the action and crit flag may be protected too: compared inside pcall, a protected one counts as a hit)
    local crit, word, kind = false, nil, "WOUND"
    pcall(function() crit = (indicator == "CRITICAL" or indicator == "CRUSHING") end)
    pcall(function() word = HIT_WORDS[action] end)
    pcall(function() if action == "HEAL" or action == "ENERGIZE" or action == "WOUND" then kind = action elseif not word then kind = nil end end)
    -- sized to the portrait: about 40% of it, more for a crit
    local size = math.floor((f.portrait:GetHeight() or 60) * (crit and 0.5 or 0.38))
    pcall(function() fs:SetFont(STANDARD_TEXT_FONT, math.max(10, size), "OUTLINE") end)
    if word then
        fs:SetText(word)
        fs:SetTextColor(1, 1, 1)
    elseif kind then
        if not pcall(function() fs:SetText(AbbreviateLargeNumbers(amount)) end) then
            if not pcall(function() fs:SetFormattedText("%d", amount) end) then return end
        end
        if kind == "HEAL" then fs:SetTextColor(0.1, 1, 0.3)
        elseif kind == "ENERGIZE" then fs:SetTextColor(0.4, 0.6, 1)
        else fs:SetTextColor(1, 0.15, 0.15) end
    else
        return
    end
    fs.anim:Stop()
    fs:SetAlpha(1)
    fs:Show()
    fs.anim:Play()
end

---------------------------------------------------------------------------
-- Extras: raid markers, the combo point arc, hunter pet happiness and frame colour. Kept in one table so
-- they add a single name to the main chunk (Lua allows 200 locals there).
---------------------------------------------------------------------------
local Extras = {
    COMBO_MAX = 5,
    COMBO_RADIUS = 38,                 -- pips sit just outside the portrait ring (gold edge ~29.5px out)
    -- UI-PetHappiness: unhappy, content, happy
    HAPPY_COORDS = { { 0.375, 0.5625, 0, 0.359375 }, { 0.1875, 0.375, 0, 0.359375 }, { 0, 0.1875, 0, 0.359375 } },
    -- Forever's mood icons (as EllesmereUI uses): unhappy, content, happy
    HAPPY_ATLAS = { "UI-PetMad", "UI-PetNeutral", "UI-PetHappiness" },
}

Extras.allFrames = AuraKit.allFrames     -- every unit frame

-- Raid markers: at the top of the portrait; side by side with the leader crown when both show.
function Extras.raid(f)
    local p = f.portrait
    if not (p and f.ov) then return end
    local idx
    pcall(function() idx = GetRaidTargetIndex(f.wfUnit) end)
    local icon = f.raidIcon
    if idx and not icon then
        icon = f.ov:CreateTexture(nil, "OVERLAY", nil, 6)
        icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        f.raidIcon = icon
    end
    if idx and not pcall(SetRaidTargetIconTexture, icon, idx) then idx = nil end
    if icon then icon:SetShown(idx and true or false) end
    local crown = f.leaderIcon and f.leaderIcon:IsShown() and not f.small
    if idx then
        local s = f.small and 14 or 20
        icon:SetSize(s, s)
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", p, "TOP", crown and 10 or 0, f.small and 0 or 2)
    end
    if f.leaderIcon and not f.small then
        f.leaderIcon:ClearAllPoints()
        f.leaderIcon:SetPoint("CENTER", p, "TOP", idx and -10 or 0, 1)
    end
end

-- Combo points (rogues, druids), on the target: five pips in an arc round the right of its portrait.
-- A protected point count can't be compared, so each pip is a tiny bar covering one point (min i-1,
-- max i): the game fills it once the count reaches i.
function Extras.combo(f)
    local _, class = UnitClass("player")
    local want = (class == "ROGUE" or class == "DRUID") and getSetting("target", "comboPoints")
    if not want then
        if f.comboBox then f.comboBox:Hide() end
        return
    end
    if not f.comboBox then
        local box = CreateFrame("Frame", nil, f.ov)
        box:SetAllPoints(f.portrait)
        box:SetFrameLevel(f.ov:GetFrameLevel() + 2)
        box.pips = {}
        for i = 1, Extras.COMBO_MAX do
            local pip = CreateFrame("StatusBar", nil, box)
            pip:SetSize(10, 10)
            -- gold rim, dark socket, glowing fill: all circles
            local rim = pip:CreateTexture(nil, "BACKGROUND", nil, 0)
            rim:SetTexture(CIRCLE_FALLBACK)
            rim:SetPoint("TOPLEFT", -1.5, 1.5); rim:SetPoint("BOTTOMRIGHT", 1.5, -1.5)
            rim:SetVertexColor(0.8, 0.65, 0.3, 1)
            local socket = pip:CreateTexture(nil, "BACKGROUND", nil, 1)
            socket:SetTexture(CIRCLE_FALLBACK)
            socket:SetAllPoints()
            socket:SetVertexColor(0.05, 0.05, 0.05, 1)
            pip:SetStatusBarTexture(CIRCLE_FALLBACK)
            pip:SetStatusBarColor(1, 0.55, 0.1, 1)
            pip:SetMinMaxValues(i - 1, i)
            pip:SetValue(0)
            local a = math.rad(70 - (i - 1) * 20)        -- from up-and-right, round to just below level
            pip:SetPoint("CENTER", box, "CENTER", Extras.COMBO_RADIUS * math.cos(a), Extras.COMBO_RADIUS * math.sin(a))
            box.pips[i] = pip
        end
        f.comboBox = box
    end
    -- the count goes straight to the pips; fall back to the older API if the first can't be read
    local function fill(v) for _, pip in ipairs(f.comboBox.pips) do pip:SetValue(v) end end
    if not pcall(function() fill(UnitPower("player", Enum.PowerType.ComboPoints)) end) then
        if not pcall(function() fill(GetComboPoints("player", "target")) end) then fill(0) end
    end
    f.comboBox:SetShown(UnitExists("target") and true or false)
end

-- Hunter pet happiness: the mood face, shown like the first buff in the pet's aura row; the tooltip
-- has the details.
function Extras.happinessTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(_G["PET_HAPPINESS" .. self.h] or "Happiness", 1, 1, 1)
    -- (with the badge, the pet's level: the badge looks like a level circle but holds the face)
    pcall(function() if self.level then GameTooltip:AddLine((LEVEL or "Level") .. " " .. self.level, 1, 0.82, 0) end end)
    -- what the pet eats
    pcall(function()
        local foods = { C_PetInfo.GetPetFoodTypes() }
        if #foods > 0 and PET_DIET_TEMPLATE then
            GameTooltip:AddLine(PET_DIET_TEMPLATE:format(table.concat(foods, PET_FOOD_DELIMIT or ", ")), 1, 1, 1, true)
        end
    end)
    pcall(function()
        if self.dmg and PET_DAMAGE_PERCENTAGE then GameTooltip:AddLine(string.format(PET_DAMAGE_PERCENTAGE, self.dmg), 1, 0.82, 0) end
    end)
    pcall(function()
        if self.loyalty and self.loyalty > 0 and GAINING_LOYALTY then GameTooltip:AddLine(GAINING_LOYALTY, 0.1, 1, 0.1)
        elseif self.loyalty and self.loyalty < 0 and LOSING_LOYALTY then GameTooltip:AddLine(LOSING_LOYALTY, 1, 0.1, 0.1) end
    end)
    GameTooltip:Show()
end

function Extras.happiness(f)
    -- Forever: C_PetInfo.GetPetHappiness (the old global as a fallback); HasPetUI says it's a hunter pet
    local h, dmg, loyalty, isHunterPet
    pcall(function() local _, hunter = HasPetUI(); isHunterPet = hunter end)
    local mode = getSetting("pet", "petHappy")
    if isHunterPet and mode ~= "off" then
        pcall(function()
            if C_PetInfo and C_PetInfo.GetPetHappiness then h, dmg, loyalty = C_PetInfo.GetPetHappiness()
            elseif GetPetHappiness then h, dmg, loyalty = GetPetHappiness() end
        end)
    end
    local coords, atlas
    pcall(function()
        coords = h and Extras.HAPPY_COORDS[h]
        atlas = h and Extras.HAPPY_ATLAS[h]
    end)
    -- Two spots on the pet portrait, scaled from the player frame's (whose portrait is 60px to the pet's
    -- 37): "corner" at its bottom right, where the player's corner point and combat swords are, on a dark
    -- round backing like the swords'; "badge" at its bottom left, in a round badge like the player's
    -- level circle (the tooltip gives the pet's level).
    if coords and not f.happyIcon then
        local parent = f.ov or f
        local ic = CreateFrame("Frame", nil, parent)
        ic:SetFrameLevel(parent:GetFrameLevel() + 3)
        ic.back = ic:CreateTexture(nil, "BACKGROUND")
        ic.back:SetTexture(CIRCLE_FALLBACK)
        ic.back:SetVertexColor(0, 0, 0, 1)
        ic.ring = ic:CreateTexture(nil, "BORDER")
        if hasAtlas("UI-HUD-UnitFrame-SmallCircle") then ic.ring:SetAtlas("UI-HUD-UnitFrame-SmallCircle") else ic.ring:Hide() end
        ic.tex = ic:CreateTexture(nil, "ARTWORK")
        ic.tex:SetTexture("Interface\\PetPaperDollFrame\\UI-PetHappiness")
        ic:EnableMouse(true)
        ic:SetScript("OnEnter", Extras.happinessTooltip)
        ic:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f.happyIcon = ic
    end
    -- (the small frame never shows a level number; this only matters on a frame with a level badge)
    local function showLevel(on) if f.level and f.badge then f.level:SetShown(on) end end
    if not f.happyIcon then showLevel(true); return end
    local ic = f.happyIcon
    if coords then
        local p = f.portrait or f
        ic:ClearAllPoints()
        ic.tex:ClearAllPoints(); ic.back:ClearAllPoints(); ic.ring:ClearAllPoints()
        if mode == "badge" then
            -- where the player's level badge sits (39px by a 60px portrait), at the portrait's bottom left:
            -- just the face on its dark round backing, no badge ring
            ic:SetSize(24, 24)
            ic:SetPoint("CENTER", p, "BOTTOMLEFT", 5, 3)
            ic.ring:Hide()
            ic.back:SetPoint("TOPLEFT", 3, -3); ic.back:SetPoint("BOTTOMRIGHT", -3, 3)
            ic.back:Show()
            ic.tex:SetPoint("TOPLEFT", 4, -4); ic.tex:SetPoint("BOTTOMRIGHT", -4, 4)
            ic.level = UnitLevel("pet")
        else
            -- the corner spot (the player frame's combat swords: 18px on a 22px backing, by a 60px portrait)
            ic:SetSize(16, 16)
            ic:SetPoint("CENTER", p, "BOTTOMRIGHT", -6, 4)
            ic.ring:Hide()
            ic.back:SetAllPoints()
            ic.back:Show()
            ic.tex:SetPoint("TOPLEFT", 1.5, -1.5); ic.tex:SetPoint("BOTTOMRIGHT", -1.5, 1.5)
            ic.level = nil
        end
        if f.badge then showLevel(mode ~= "badge") end
        -- Forever's mood icons, or the Classic texture sheet when the client lacks them
        if not (atlas and pcall(ic.tex.SetAtlas, ic.tex, atlas) and ic.tex:GetAtlas()) then
            ic.tex:SetTexture("Interface\\PetPaperDollFrame\\UI-PetHappiness")
            ic.tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        end
        ic.h, ic.dmg, ic.loyalty = h, dmg, loyalty
        ic:Show()
    else
        ic:Hide()
        showLevel(true)
    end
end

-- per-frame part of updateAll
-- Frame colour: the frame art (border, portrait ring, corner accent, level circle, cast bar border)
-- greyed and tinted, or left as drawn. "Silver" is just greyed; "class" is your class colour.
Extras.TINTS = { dark = { 0.32, 0.32, 0.32 }, silver = { 1, 1, 1 } }

-- unit: whose options; shown: the unit the frame shows (for "unitclass": a player's class colour, the
-- art as drawn for NPCs)
function Extras.tintColor(unit, shown)
    local mode = getSetting(unit, "frameTint")
    if mode == "class" or mode == "unitclass" then
        local class
        pcall(function()
            local who = (mode == "unitclass") and (shown or unit) or "player"
            if mode == "unitclass" and not UnitIsPlayer(who) then return end
            class = select(2, UnitClass(who))
        end)
        local c = class and (RAID_CLASS_COLORS or {})[class]
        if c then return { c.r, c.g, c.b } end
        return nil
    elseif mode == "custom" then
        local c = getSetting(unit, "frameColor")
        if type(c) == "table" then return { c[1] or 1, c[2] or 1, c[3] or 1 } end
        return { 1, 1, 1 }
    end
    return Extras.TINTS[mode]
end

function Extras.tint(f)
    local c = Extras.tintColor(f.baseUnit, f.wfUnit)
    f.tintColor = c
    pcall(updateIndicators, f)       -- the resting glow follows the frame colour
    local list = { f.border, f.ringTop, f.corner, f.badge }
    if f.cb then for _, t in ipairs(f.cb.slices) do list[#list + 1] = t end end
    for _, t in pairs(list) do
        if t then
            pcall(t.SetDesaturated, t, c and true or false)
            if c then t:SetVertexColor(c[1], c[2], c[3]) else t:SetVertexColor(1, 1, 1) end
        end
    end
end

-- Opens the colour picker on a frame's custom colour (and switches it to the custom colour).
function Extras.pickColor(unit, set)
    local old = Extras.tintColor(unit) or { 1, 1, 1 }
    Extras.openPicker(old, function(r, g, b)
        set(unit, "frameColor", { r, g, b })
        set(unit, "frameTint", "custom")
    end)
end

-- Opens the colour picker on the custom colour for hostile NPCs' health bars (and switches to it).
function Extras.pickNpcColor(unit, set)
    local c = getSetting(unit, "npcColorRGB")
    local old = type(c) == "table" and { c[1] or 0.1, c[2] or 0.8, c[3] or 0.1 } or { 0.1, 0.8, 0.1 }
    Extras.openPicker(old, function(r, g, b)
        set(unit, "npcColorRGB", { r, g, b })
        set(unit, "npcColor", "custom")
    end)
end

-- Blizzard's colour picker, starting at `old`; apply(r, g, b) as it changes (and back to old on cancel).
function Extras.openPicker(old, apply)
    local info = {
        r = old[1], g = old[2], b = old[3], hasOpacity = false,
        swatchFunc = function() apply(ColorPickerFrame:GetColorRGB()) end,
        cancelFunc = function() apply(old[1], old[2], old[3]) end,
    }
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow(info)
    else
        ColorPickerFrame.func, ColorPickerFrame.cancelFunc = info.swatchFunc, info.cancelFunc
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame:SetColorRGB(old[1], old[2], old[3])
        ColorPickerFrame:Hide(); ColorPickerFrame:Show()
    end
end

function Extras.update(f)
    pcall(Extras.raid, f)
    -- a frame coloured by the unit's class changes colour with the unit
    if getSetting(f.baseUnit, "frameTint") == "unitclass" or f.tintFollows then
        f.tintFollows = getSetting(f.baseUnit, "frameTint") == "unitclass" or nil
        pcall(Extras.tint, f)
    end
    if f.baseUnit == "pet" then pcall(Extras.happiness, f) end
    if f.baseUnit == "target" then pcall(Extras.combo, f) end
end

-- event watchers, once the frames exist
function Extras.init()
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("RAID_TARGET_UPDATE")
    ev:RegisterEvent("PLAYER_TARGET_CHANGED")
    pcall(ev.RegisterUnitEvent, ev, "UNIT_POWER_UPDATE", "player")
    pcall(ev.RegisterUnitEvent, ev, "UNIT_POWER_FREQUENT", "player")
    pcall(ev.RegisterUnitEvent, ev, "UNIT_MAXPOWER", "player")
    pcall(ev.RegisterUnitEvent, ev, "UNIT_HAPPINESS", "pet")
    pcall(ev.RegisterUnitEvent, ev, "UNIT_PET", "player")
    pcall(ev.RegisterEvent, ev, "PET_UI_UPDATE")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", function(_, event)
        if event == "RAID_TARGET_UPDATE" then
            for _, f in ipairs(Extras.allFrames()) do pcall(Extras.raid, f) end
        elseif event == "UNIT_HAPPINESS" or event == "UNIT_PET" or event == "PET_UI_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
            if frames.pet then pcall(Extras.happiness, frames.pet) end
        elseif frames.target then
            pcall(Extras.combo, frames.target)
        end
    end)
end

-- Each part on its own, so one failing (say, on a protected value) can't stop the others, the
-- buffs and debuffs included. Errors are still reported, once each, for /webby errors.
local updateErrors = {}
local function safely(fn, f)
    local ok, err = pcall(fn, f)
    if not ok and err and not updateErrors[err] then updateErrors[err] = true; updateErrors[#updateErrors + 1] = err end
end
local function updateAll(f)
    safely(updateInfo, f); safely(updateHealth, f); safely(updatePower, f); safely(updateIndicators, f)
    safely(updateThreat, f); safely(updateAuras, f); safely(Extras.update, f)
end

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
    local on = (hasCorner(f.baseUnit) and f.layoutLeft and not f.small) and true or false
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

-- true if `unit` is somewhere up `start`'s chain of sticky attachments (attaching start to it would loop)
local function attachLoops(start, unit, layoutName)
    local seen, cur = 0, start
    while cur and seen < 10 do
        if cur == unit then return true end
        local u = unitData(cur, false, layoutName)
        cur = u and u.attach
        seen = seen + 1
    end
    return false
end

-- Puts a frame where its options say: stuck to another frame (see
-- updateAttachment), at its saved spot, or the default.
local function placeFrame(f, unit)
    local u = unitData(unit)
    local d = DEFAULT_POS[unit]
    f:ClearAllPoints()
    local p = u and u.attach and frames[u.attach]
    if p and p ~= f and not attachLoops(u.attach, unit) and type(u.ax) == "number" and type(u.ay) == "number" then
        f:SetPoint("TOPLEFT", p, "TOPLEFT", u.ax, u.ay)
    elseif u and u.point then
        f:SetPoint(u.point, UIParent, u.point, u.x, u.y)
    else
        f:SetPoint(d.point, UIParent, d.point, d.x, d.y)
    end
end

local function applyUnit(f)
    local unit = f.baseUnit
    local changed = applyLayout(f)
    if f.small and applySmallLayout(f) then changed = true end
    placeFrame(f, unit)
    f:SetScale(getSetting(unit, "scale"))
    local showName = getSetting(unit, "showName") and true or false
    f.name:SetShown(showName)
    if f.plate then f.plate:SetShown(showName and not f.layoutLeft) end
    applyCorner(f)
    placeIndicators(f)
    pcall(applyFont, f)
    pcall(updateThreat, f)
    pcall(updateIndicators, f)
    pcall(updateAuras, f)
    pcall(placeCastbar, f)
    pcall(Extras.tint, f)
    if f.updateRest then pcall(f.updateRest) end
    -- textures: health (also the cast bar and the heal / shield overlays) and power, each the frame's
    -- default fill or a chosen one
    local tex = resolveTexture(getSetting(unit, "barTexture"))
    if tex ~= f.customTex then
        f.customTex = tex
        f.hpCurrent = nil
        changed = true
    end
    local ptex = resolveTexture(getSetting(unit, "powerTexture"))
    if ptex ~= f.powerTex then
        f.powerTex = ptex
        f.mpCurrent = nil
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
    -- the pet's bar can follow the player frame's colour
    if unit == "player" and frames.pet then pcall(updateHealth, frames.pet) end
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
    f:SetScript("OnEvent", function(self, event, ...)
        if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then updateHealth(self)
        elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then updatePower(self)
        elseif event == "PLAYER_UPDATE_RESTING" then
            if self.updateRest then self.updateRest() end
            updateIndicators(self)
        elseif event == "PLAYER_REGEN_DISABLED" then self.combatFlag = true; updateIndicators(self)
        elseif event == "PLAYER_REGEN_ENABLED" then self.combatFlag = false; updateIndicators(self)
        elseif event == "PLAYER_FLAGS_CHANGED" or event == "UNIT_FLAGS" then updateIndicators(self)
        elseif event:find("^UNIT_THREAT") then updateThreat(self)
        elseif event == "UNIT_AURA" then safely(updateAuras, self)
        elseif event == "UNIT_COMBAT" then local _, action, indicator, amount = ...; pcall(showHit, self, action, indicator, amount)
        elseif event == "UNIT_HEAL_PREDICTION" or event:find("ABSORB_AMOUNT_CHANGED$") then pcall(updatePrediction, self)
        else updateAll(self) end
    end)
    for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
                         "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED", "UNIT_FACTION", "UNIT_CONNECTION", "UNIT_AURA",
                         "UNIT_HEAL_PREDICTION", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "UNIT_COMBAT" }) do
        pcall(f.RegisterUnitEvent, f, e, unit)
    end
    -- smooth energy / rage / focus ticks on your own frame
    if isPlayer then pcall(f.RegisterUnitEvent, f, "UNIT_POWER_FREQUENT", unit) end
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    -- who leads the group (the crown)
    f:RegisterEvent("GROUP_ROSTER_UPDATE")
    f:RegisterEvent("PARTY_LEADER_CHANGED")
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

    f:SetScript("OnEvent", function(self, event, ...)
        if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then updateHealth(self)
        elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then updatePower(self)
        elseif event == "UNIT_AURA" then safely(updateAuras, self)
        elseif event == "UNIT_COMBAT" then local _, action, indicator, amount = ...; pcall(showHit, self, action, indicator, amount)
        elseif event == "UNIT_HEAL_PREDICTION" or event:find("ABSORB_AMOUNT_CHANGED$") then pcall(updatePrediction, self)
        else updateAll(self) end
    end)
    for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
                         "UNIT_NAME_UPDATE", "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED", "UNIT_FACTION", "UNIT_CONNECTION", "UNIT_AURA",
                         "UNIT_HEAL_PREDICTION", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "UNIT_COMBAT" }) do
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
local function sampleFrames()
    local list = {}
    for _, unit in ipairs({ "target", "targettarget", "focus", "focustarget", "pet" }) do
        if frames[unit] then list[#list + 1] = frames[unit] end
    end
    return list
end

local function enterSample()
    if InCombatLockdown() then return end
    for _, f in ipairs(sampleFrames()) do
        UnregisterUnitWatch(f)
        f.wfUnit = "player"
        f:Show()
        updateAll(f)
    end
    AuraKit.setEditing(true)       -- the buff / debuff boxes for frames set to "drag in Edit Mode"
end

local function exitSample()
    AuraKit.setEditing(false)
    if InCombatLockdown() then return end
    for _, f in ipairs(sampleFrames()) do
        f.wfUnit = f.baseUnit
        RegisterUnitWatch(f)
        updateAll(f)
    end
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
    for _, unit in ipairs(UNITS) do
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

-- Sticky frames: a frame dropped within SNAP_DIST of another Webby frame (touching, overlapping or just
-- beside it) is attached to it and follows it when that frame moves. Dropped further away, it's free
-- again. Its own frame is preferred when it's in reach (focus target -> focus, target of target ->
-- target, pet -> player). Saved as attach = the other frame's unit, ax / ay = its top left offset.
local NATURAL_PARENT = { focustarget = "focus", targettarget = "target", pet = "player" }

local function updateAttachment(f, unit, layoutName)
    local u = unitData(unit, true, layoutName)
    local l, b, r, t = boxOf(f)
    local best, bestD
    if l then
        for _, other in ipairs(UNITS) do
            local o = frames[other]
            if other ~= unit and o and o:IsVisible() and not attachLoops(other, unit, layoutName) then
                local ol, ob, orr, ot = boxOf(o)
                if ol then
                    -- gap between the two boxes (0 when they touch or overlap)
                    local gx = math.max(0, ol - r, l - orr)
                    local gy = math.max(0, ob - t, b - ot)
                    local d = math.max(gx, gy)
                    if NATURAL_PARENT[unit] == other then d = d - 0.5 end
                    if d <= SNAP_DIST and (not bestD or d < bestD) then best, bestD = other, d end
                end
            end
        end
    end
    if not best then
        u.attach, u.ax, u.ay = nil, nil, nil
        return
    end
    local p = frames[best]
    local ui = UIParent:GetEffectiveScale()
    local fs, ps = f:GetEffectiveScale() / ui, p:GetEffectiveScale() / ui
    u.attach = best
    u.ax = (f:GetLeft() * fs - p:GetLeft() * ps) / fs
    u.ay = (f:GetTop() * fs - p:GetTop() * ps) / fs
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

    for _, unit in ipairs(UNITS) do
        local f = frames[unit]
        local d = DEFAULT_POS[unit]
        lib:AddFrame(f, function(_, layoutName, point, x, y)
            local sp, sx, sy = snapFrame(f)
            if sp then point, x, y = sp, sx, sy end
            local u = unitData(unit, true, layoutName)
            u.point, u.x, u.y = point, x, y         -- (kept for when its frame is gone)
            -- sticky: dropped by another frame, it now moves with that frame
            pcall(updateAttachment, f, unit, layoutName)
            if layoutName == activeLayout then pcall(placeFrame, f, unit) end
        end, { point = d.point, x = d.x, y = d.y }, "Webby " .. UNIT_LABEL[unit] .. " Frame")
        -- The library's box covers the whole (larger, clickable) frame; fit it to the frame art instead,
        -- the same box snapping lines up (it follows the art when the layout changes).
        pcall(function()
            local sel = lib.frameSelections and lib.frameSelections[f]
            if sel and f.border then
                sel:ClearAllPoints()
                sel:SetPoint("TOPLEFT", f.border, "TOPLEFT")
                sel:SetPoint("BOTTOMRIGHT", f.border, "BOTTOMRIGHT")
            end
        end)
    end

    -- No settings dialog when a frame is clicked: the options all live in Esc > Options. The library
    -- still needs its dialog (closing it deselects the frame, and it handles the arrow keys that nudge
    -- the selected frame 1px, 10px with Shift), so it's kept open but invisible, off the screen.
    pcall(function()
        local dlg = lib.internal and lib.internal.dialog
        if dlg and not dlg.webbyHidden then
            dlg.webbyHidden = true
            hooksecurefunc(dlg, "Update", function(d)
                d:ClearAllPoints()
                d:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", -5000, -5000)
                d:SetAlpha(0)
            end)
        end
    end)

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
local COPY_KEYS = { "scale", "showName", "textMode", "textFormat", "barTexture", "powerTexture", "font", "showThreat",
                    "auraBuffs", "auraDebuffs", "auraMine", "auraSize", "auraDebuffSize", "auraPerRow", "auraMax", "auraPos", "auraTimer",
                    "castShow", "castText", "castIcon", "smoothBars", "healPrediction", "absorbs",
                    "colorMode", "healthFade", "frameTint", "frameColor", "petHappy", "petColor", "comboPoints", "npcColor", "npcColorRGB" }

function resetFrame(unit)
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

function copySettings(from, to)
    if InCombatLockdown() then print("|cff33ccffWebby Frames:|r can't copy in combat."); return end
    for _, key in ipairs(COPY_KEYS) do
        local v = getSetting(from, key)
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

---------------------------------------------------------------------------
-- Profiles: the current Edit Mode layout's options and positions, every frame, as one line of text to
-- paste somewhere and import again (here or on another character). The text is a small typed format
-- (strings carry their length, so anything can be in them) in base64; importing only ever reads data.
---------------------------------------------------------------------------
local Profiles = { PREFIX = "WF1:", B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/" }

function Profiles.pack(v, out)
    local t = type(v)
    if t == "string" then out[#out + 1] = "s" .. #v .. ":" .. v
    elseif t == "number" then out[#out + 1] = "n" .. string.format("%.17g", v) .. ";"
    elseif t == "boolean" then out[#out + 1] = v and "t" or "f"
    elseif t == "table" then
        out[#out + 1] = "{"
        for k, val in pairs(v) do
            local kt, vt = type(k), type(val)
            if (kt == "string" or kt == "number") and (vt == "string" or vt == "number" or vt == "boolean" or vt == "table") then
                Profiles.pack(k, out); Profiles.pack(val, out)
            end
        end
        out[#out + 1] = "}"
    end
    return out
end

-- Reads one value from s at i; returns it and the next position (errors on anything malformed).
function Profiles.unpack(s, i, depth)
    if depth > 20 then error("too deep") end
    local c = s:sub(i, i)
    if c == "s" then
        local len, rest = s:match("^(%d+):()", i + 1)
        len = tonumber(len)
        if not len then error("bad string") end
        return s:sub(rest, rest + len - 1), rest + len
    elseif c == "n" then
        local num, rest = s:match("^([^;]+);()", i + 1)
        num = tonumber(num)
        if not num then error("bad number") end
        return num, rest
    elseif c == "t" then return true, i + 1
    elseif c == "f" then return false, i + 1
    elseif c == "{" then
        local tbl = {}
        i = i + 1
        while s:sub(i, i) ~= "}" do
            if i > #s then error("unfinished table") end
            local k, v
            k, i = Profiles.unpack(s, i, depth + 1)
            v, i = Profiles.unpack(s, i, depth + 1)
            if type(k) == "table" then error("bad key") end
            tbl[k] = v
        end
        return tbl, i + 1
    end
    error("bad data")
end

function Profiles.encode(s)
    local A, out = Profiles.B64, {}
    for i = 1, #s, 3 do
        local a, b, c = s:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local q = { math.floor(n / 262144) % 64, math.floor(n / 4096) % 64, math.floor(n / 64) % 64, n % 64 }
        out[#out + 1] = A:sub(q[1] + 1, q[1] + 1) .. A:sub(q[2] + 1, q[2] + 1)
            .. (b and A:sub(q[3] + 1, q[3] + 1) or "=") .. (c and A:sub(q[4] + 1, q[4] + 1) or "=")
    end
    return table.concat(out)
end

function Profiles.decode(s)
    local A, out = Profiles.B64, {}
    s = s:gsub("[^%w%+/=]", "")
    for i = 1, #s, 4 do
        local n, pad = 0, 0
        for j = 0, 3 do
            local ch = s:sub(i + j, i + j)
            local v = A:find(ch, 1, true)
            if ch == "=" or ch == "" then pad = pad + 1; v = 1 elseif not v then error("bad text") end
            n = n * 64 + (v - 1)
        end
        local bytes = string.char(math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256)
        out[#out + 1] = bytes:sub(1, 3 - pad)
    end
    return table.concat(out)
end

function Profiles.export()
    local l = DB.layouts and DB.layouts[activeLayout] or {}
    return Profiles.PREFIX .. Profiles.encode(table.concat(Profiles.pack({ v = 1, layout = l }, {})))
end

-- Returns true, or false and why not.
function Profiles.import(text)
    if InCombatLockdown() then return false, "can't import in combat" end
    text = (text or ""):gsub("%s", "")
    if text:sub(1, #Profiles.PREFIX) ~= Profiles.PREFIX then return false, "that isn't a Webby Frames profile" end
    local ok, data = pcall(function()
        local raw = Profiles.decode(text:sub(#Profiles.PREFIX + 1))
        local v, nexti = Profiles.unpack(raw, 1, 0)
        if nexti ~= #raw + 1 then error("extra data") end
        return v
    end)
    if not (ok and type(data) == "table" and type(data.layout) == "table") then return false, "the text is damaged or incomplete" end
    for unit, u in pairs(data.layout) do
        if type(unit) ~= "string" or type(u) ~= "table" then return false, "the text is damaged or incomplete" end
    end
    DB.layouts = DB.layouts or {}
    DB.layouts[activeLayout] = data.layout
    for _, f in pairs(frames) do f.layoutLeft = nil end
    applyAll()
    for _, f in pairs(frames) do pcall(updateAll, f) end
    if lib then for _, f in pairs(frames) do pcall(lib.RefreshFrameSettings, lib, f) end end
    return true
end

-- The export and import boxes (Blizzard's popup with an edit box).
function Profiles.editBox(dialog)
    return dialog.editBox or dialog.EditBox or (dialog.GetEditBox and dialog:GetEditBox())
end

function Profiles.show(which)
    if not StaticPopupDialogs.WEBBYFRAMES_EXPORT then
        StaticPopupDialogs.WEBBYFRAMES_EXPORT = {
            text = "Webby Frames profile for the |cffffd100%s|r layout.\nCopy it with Ctrl+C:",
            button1 = CLOSE or "Close",
            hasEditBox = true, maxLetters = 0, editBoxWidth = 350,
            OnShow = function(self, data)
                local eb = Profiles.editBox(self)
                if eb then eb:SetText(data or ""); eb:HighlightText(); eb:SetFocus() end
            end,
            EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
            timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        }
        StaticPopupDialogs.WEBBYFRAMES_IMPORT = {
            text = "Paste a Webby Frames profile (Ctrl+V).\nIt replaces every frame's options and position in the |cffffd100%s|r layout.",
            button1 = "Import", button2 = CANCEL or "Cancel",
            hasEditBox = true, maxLetters = 0, editBoxWidth = 350,
            OnShow = function(self) local eb = Profiles.editBox(self); if eb then eb:SetText(""); eb:SetFocus() end end,
            OnAccept = function(self)
                local eb = Profiles.editBox(self)
                local ok, why = Profiles.import(eb and eb:GetText())
                if ok then print("|cff33ccffWebby Frames:|r profile imported.")
                else print("|cff33ccffWebby Frames:|r couldn't import: " .. why .. ".") end
            end,
            EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
            timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        }
    end
    if which == "export" then
        StaticPopup_Show("WEBBYFRAMES_EXPORT", activeLayout, nil, Profiles.export())
    else
        StaticPopup_Show("WEBBYFRAMES_IMPORT", activeLayout)
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
-- its options in collapsible sections. Edit Mode is only for moving the frames.
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

-- Re-checks the shown rows' enabled state (options greyed out while what they depend on is off).
local function refreshSettingStates()
    pcall(function()
        SettingsPanel:GetSettingsList().ScrollBox:ForEachFrame(function(frame)
            if frame.EvaluateState then pcall(frame.EvaluateState, frame) end
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
        -- Switches and dropdowns can have options that depend on them (see B.under): when one changes,
        -- the visible rows re-check whether they're enabled.
        local function watch(key)
            pcall(Settings.SetOnValueChangedCallback, prefix .. key, function() C_Timer.After(0, refreshSettingStates) end)
        end
        function B.check(key, label, tip, default)
            local st = Settings.RegisterAddOnSetting(category, prefix .. key, key, proxy, Settings.VarType.Boolean, label, default)
            watch(key)
            return attach(Settings.CreateCheckbox(category, st, tip))
        end
        function B.slider(key, label, tip, default, lo, hi, step, fmt)
            local st = Settings.RegisterAddOnSetting(category, prefix .. key, key, proxy, Settings.VarType.Number, label, default)
            local o = Settings.CreateSliderOptions(lo, hi, step)
            o:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, fmt or function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end)
            return attach(Settings.CreateSlider(category, st, o, tip))
        end
        -- Indents a control under the one it depends on and greys it out while isOn() is false.
        function B.under(parent, isOn, ...)
            for _, init in ipairs({ ... }) do
                if init and parent and init.SetParentInitializer then pcall(init.SetParentInitializer, init, parent, isOn) end
            end
        end
        function B.dropdown(key, label, tip, default, choices)
            local st = Settings.RegisterAddOnSetting(category, prefix .. key, key, proxy, Settings.VarType.String, label, default)
            watch(key)
            return attach(Settings.CreateDropdown(category, st, function()
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
            -- addon-wide switches, both on unless turned off
            __index = function(_, k) if k == "enabled" or k == "combatNumbers" then return DB[k] ~= false end end,
            __newindex = function(_, k, v) if k == "enabled" or k == "combatNumbers" then DB[k] = v and true or false end end,
        })
        local B = builders(root, rootLayout, general, "WEBBY_general_")
        B.header("Webby Frames  |cff808080v" .. addonVersion() .. "|r")
        B.check("enabled", "Enable Webby Frames", "Replaces Blizzard's player, target, target of target, focus, focus target and pet frames.\n\n|cffffd100Needs a /reload.|r", true)
        B.check("combatNumbers", "Combat numbers", "Damage and healing popping up over the portraits. Turn this off if you prefer Blizzard's floating combat text (Esc > Options > Gameplay > Combat).\n\nShown on the player, target and focus frames.", true)

        B.header("Frames")
        B.button("Position", "Open Edit Mode", openEditMode, "Drag the frames where you want them. They snap to each other and to the screen edges.")
        B.button("Start over", "Reset all frames", function()
            for _, unit in ipairs(UNITS) do resetFrame(unit) end
        end, "Puts every frame back to its default options and position, for the current Edit Mode layout.")

        B.header("Profiles")
        B.button("Share", "Export profile", function() Profiles.show("export") end,
            "Every frame's options and position in this Edit Mode layout, as text you can copy and keep or share.")
        B.button("Load", "Import profile", function() Profiles.show("import") end,
            "Paste a profile exported here or on another character. It replaces this layout's options and positions.")

        B.header("Pick a frame on the left for its own options.")
        B.header("|cff808080Options are saved per Edit Mode layout.  /webby help lists the commands.|r")
    end

    -- one page per frame ---------------------------------------------------------
    local fontList = function() local l = {}; for _, c in ipairs(fontChoices()) do l[#l + 1] = { c[1], c[2] } end; return l end

    -- All frames: the options most people want the same everywhere, set on every frame at once. It shows
    -- the player frame's choice; changing it sets every frame (each frame's page can still differ after).
    do
        local sub, subLayout = Settings.RegisterVerticalLayoutSubcategory(root, "All frames")
        unitPages.all = sub
        local function setAll(_, k, v) for _, unit in ipairs(UNITS) do setSetting(unit, k, v) end end
        local proxy = setmetatable({}, {
            __index = function(_, k) return getSetting("player", k) end,
            __newindex = setAll,
        })
        local B = builders(sub, subLayout, proxy, "WEBBY_all_")
        B.header("|cff808080Changes here apply to every frame. Each frame's own page can then differ.|r")

        B.section("Look", true)
        B.dropdown("frameTint", "Frame colour", "Colours the frame art on every frame. The player's resting glow takes the colour too.", "default",
            { { "default", "Gold (as drawn)" }, { "dark", "Dark" }, { "silver", "Silver" }, { "class", "Your class colour" }, { "unitclass", "The unit's class colour" }, { "custom", "Custom" } })
        B.button("Custom colour", "Pick colour", function() Extras.pickColor("player", setAll) end,
            "Pick any colour for every frame's art (sets Frame colour to Custom).")
        B.dropdown("barTexture", "Health texture", "Every frame's health bar fill (and cast bar and heal / shield overlays).", "default", textureChoices)
        B.dropdown("powerTexture", "Power texture", "Every frame's mana, rage or energy fill.", "default", textureChoices)
        B.dropdown("font", "Font", "For the names and bar numbers on every frame.", "default", fontList)

        B.section("Bars", false)
        local numbers = B.dropdown("textMode", "Numbers", "When the bars show their numbers, on every frame.", "always",
            { { "always", "Always" }, { "mouseover", "On mouseover" }, { "off", "Never" } })
        B.under(numbers, function() return getSetting("player", "textMode") ~= "off" end,
            B.dropdown("textFormat", "Style", "Totals, percentages, or both.", "value",
                { { "value", "12.3K" }, { "percent", "85%" }, { "both", "12.3K (85%)" } }))
        B.check("smoothBars", "Smooth bars", "Health and power slide to their new value instead of jumping.", true)
        B.check("healthFade", "Fade to red", "As health drops, each frame's health colour shifts towards red.", false)
        B.dropdown("npcColor", "Enemy NPCs", "The health colour for hostile NPCs on every frame (with the Class / reaction or Reaction colour). Green lets Fade to red show their health dropping.", "reaction",
            { { "reaction", "Red (reaction colour)" }, { "green", "Green" }, { "custom", "Custom" } })
        B.button("Enemy NPC colour", "Pick colour", function() Extras.pickNpcColor("target", setAll) end,
            "Pick any health colour for hostile NPCs on every frame (sets Enemy NPCs to Custom).")
        B.check("healPrediction", "Incoming heals", "Heals on their way, in green past the end of the health.", true)
        B.check("absorbs", "Absorbs", "Damage shields and healing absorbs on the health bars.", true)

        B.section("Buffs and debuffs", false)
        B.dropdown("auraTimer", "Time left", "How each icon shows the time it has left, on every frame.", "both",
            { { "both", "Sweep and numbers" }, { "swipe", "Sweep" }, { "numbers", "Numbers" }, { "none", "Nothing" } })
    end

    for _, unit in ipairs(UNITS) do
        local sub, subLayout = Settings.RegisterVerticalLayoutSubcategory(root, UNIT_LABEL[unit])
        unitPages[unit] = sub
        local proxy = setmetatable({}, {
            __index = function(_, k) return getSetting(unit, k) end,
            __newindex = function(_, k, v) setSetting(unit, k, v) end,
        })
        local B = builders(sub, subLayout, proxy, "WEBBY_" .. unit .. "_")

        local px = function(v) return string.format("%d px", math.floor(v + 0.5)) end
        local whole = function(v) return string.format("%d", math.floor(v + 0.5)) end
        local function isOn(key) return function() return getSetting(unit, key) and true or false end end

        -- the frame itself and the icons on its portrait
        B.section("Frame", true)
        B.slider("scale", "Scale", "How big the frame is.", defaultFor(unit, "scale"), 0.5, 2, 0.05)
        B.check("showName", "Name", "The unit's name above its health bar.", true)
        B.dropdown("frameTint", "Frame colour", "Colours the frame art: its border, portrait ring, corner accent, level circle and cast bar border."
            .. (unit == "player" and " The resting glow takes the colour too." or ""), "default",
            { { "default", "Gold (as drawn)" }, { "dark", "Dark" }, { "silver", "Silver" }, { "class", "Your class colour" }, { "unitclass", "The unit's class colour" }, { "custom", "Custom" } })
        B.button("Custom colour", "Pick colour", function() Extras.pickColor(unit, setSetting) end,
            "Pick any colour for the frame art (sets Frame colour to Custom).")
        if unit == "target" then
            B.check("comboPoints", "Combo points", "Rogues and druids: your combo points in an arc round the target's portrait.", true)
        end
        if unit == "pet" then
            B.dropdown("petHappy", "Pet happiness", "Hunters: your pet's mood, with its diet, damage and loyalty in the tooltip.\n\nCorner: at the portrait's bottom right, where your frame has its corner point and combat swords.\nLevel badge: at the portrait's bottom left, where your frame has its level circle (the tooltip gives the pet's level).", "corner",
                { { "off", "Off" }, { "corner", "On the corner" }, { "badge", "Level badge" } })
        end

        -- how the bars are drawn and labelled
        B.section("Bars", false)
        B.dropdown("barTexture", "Health texture", "The health bar's fill (the cast bar and the incoming heal and shield overlays use it too). SharedMedia textures are listed too.", "default", textureChoices)
        B.dropdown("powerTexture", "Power texture", "The mana, rage or energy bar's fill. A custom texture is coloured by power type. Follows the health texture until you pick one.", "default", textureChoices)
        B.dropdown("font", "Font", "For the name and the numbers on the bars. SharedMedia fonts are listed too.", "default", fontList)
        local numbers = B.dropdown("textMode", "Numbers", "When the bars show their numbers. On mouseover, only the bar under the cursor shows its number.",
            defaultFor(unit, "textMode"), { { "always", "Always" }, { "mouseover", "On mouseover" }, { "off", "Never" } })
        B.under(numbers, function() return getSetting(unit, "textMode") ~= "off" end,
            B.dropdown("textFormat", "Style", "Totals, percentages, or both.",
                defaultFor(unit, "textFormat"), { { "value", "12.3K" }, { "percent", "85%" }, { "both", "12.3K (85%)" } }))
        B.check("smoothBars", "Smooth bars", "Health and power slide to their new value instead of jumping.", true)

        -- the health bar's colour and what's drawn past its end
        B.section("Health", false)
        if unit == "pet" then   -- (the pet's own reaction colour flips around, so these two)
            B.dropdown("petColor", "Colour", "How the pet's health bar is coloured: the same as your player frame's (your class colour, if that's what the player frame uses), or plain green.", "player",
                { { "player", "Match the player frame" }, { "plain", "Plain green" } })
        else
            local colour = B.dropdown("colorMode", "Colour", "How the health bar is coloured.", "smart", COLOR_MODES)
            if unit ~= "player" then
                local npcChoices = { { "reaction", "Red (reaction colour)" }, { "green", "Green" }, { "custom", "Custom" } }
                B.under(colour, function() local m = getSetting(unit, "colorMode"); return m == "smart" or m == "reaction" end,
                    B.dropdown("npcColor", "Enemy NPCs", "The health colour for hostile NPCs. Green (or a colour of your own) lets Fade to red show their health dropping. Neutral NPCs stay yellow.", "reaction", npcChoices))
                B.button("Enemy NPC colour", "Pick colour", function() Extras.pickNpcColor(unit, setSetting) end,
                    "Pick any health colour for hostile NPCs (sets Enemy NPCs to Custom).")
            end
        end
        B.check("healthFade", "Fade to red", "As health drops, the health colour (whichever you picked above) shifts towards red.", false)
        B.check("healPrediction", "Incoming heals", "Heals on their way to the unit, in green past the end of its health.", true)
        B.check("absorbs", "Absorbs", "Damage shields past the end of its health, and healing absorbs eating back into it in red.", true)

        B.section("Buffs and debuffs", false)
        local buffs = B.check("auraBuffs", "Buffs", nil, defaultFor(unit, "auraBuffs"))
        B.under(buffs, isOn("auraBuffs"),
            B.slider("auraSize", "Size", nil, defaultFor(unit, "auraSize"), 12, 40, 1, px))
        local debuffs = B.check("auraDebuffs", "Debuffs", nil, defaultFor(unit, "auraDebuffs"))
        B.under(debuffs, isOn("auraDebuffs"),
            B.slider("auraDebuffSize", "Size", nil, defaultFor(unit, "auraSize"), 12, 40, 1, px),
            B.check("auraMine", "Only mine", "Only the debuffs you applied.", false))
        B.dropdown("auraPos", "Position", "Where the icons sit. With \"Drag in Edit Mode\", Edit Mode shows a blue box for them: drag it anywhere.", defaultFor(unit, "auraPos"),
            { { "below", "Below the frame" }, { "above", "Above the frame" }, { "custom", "Drag in Edit Mode" } })
        B.button("Move", "Open Edit Mode", openEditMode, "Drag the buffs and debuffs box (Position: Drag in Edit Mode).")
        B.slider("auraPerRow", "Per row", "How many icons fit on a row before the next one starts.", defaultFor(unit, "auraPerRow"), 1, 16, 1, whole)
        B.slider("auraMax", "Most shown", "How many buffs, and how many debuffs, can show at once.", defaultFor(unit, "auraMax"), 1, 32, 1, whole)
        B.dropdown("auraTimer", "Time left", "How each icon shows the time it has left: a dark sweep across the icon, countdown numbers, or both.", "both",
            { { "both", "Sweep and numbers" }, { "swipe", "Sweep" }, { "numbers", "Numbers" }, { "none", "Nothing" } })

        if hasCastAndThreat(unit) then
            B.section("Cast bar and threat", false)
            local cast = B.check("castShow", "Cast bar", "What the unit is casting, under its mana bar: yellow for a cast, green for a channel, grey when you can't interrupt it, red when interrupted.", true)
            B.under(cast, isOn("castShow"),
                B.check("castText", "Spell name", nil, true),
                B.check("castIcon", "Spell icon", "At the bar's left end.", true))
            B.check("showThreat", "Threat", "Your threat on hostile units: the frame glows yellow, orange or red, with your threat % by the name.", true)
        end

        B.section("Reset and copy", false)
        if unit ~= "player" then
            B.button("Copy", "Copy from player", function() copySettings("player", unit) end,
                "Gives this frame the player frame's options. Its position stays put.")
        end
        B.button("Reset", "Reset this frame", function() resetFrame(unit) end,
            "Puts this frame back to its default options and position, for the current Edit Mode layout.")
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
-- Target and focus: Blizzard's frames keep running, just invisible, unclickable and parked off the
-- screen, because their cast bars (which ours copy) need them: a cast bar inside a hidden frame stops,
-- and one moved into ours can't start when you pick a target that's already casting (Blizzard's bar
-- asks its own frame where to sit first). Edit Mode re-anchoring them puts them back off the screen.
local ghosted = {}
local function parkBlizzard(frame)
    if InCombatLockdown() or ghosted[frame] == "parking" then return end
    ghosted[frame] = "parking"
    pcall(function()
        frame:ClearAllPoints()
        frame:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", -3000, -3000)
    end)
    ghosted[frame] = true
end
local function ghostBlizzard(frame)
    if not frame then return end
    pcall(function()
        frame:SetAlpha(0)
        frame:EnableMouse(false)
        frame:SetClampedToScreen(false)
    end)
    parkBlizzard(frame)
end
local ghostHooked = {}
local function ghostHooks(frame)
    if not frame or ghostHooked[frame] then return end
    ghostHooked[frame] = true
    hooksecurefunc(frame, "SetAlpha", function(self, a) if a ~= 0 then self:SetAlpha(0) end end)
    hooksecurefunc(frame, "SetPoint", function(self) if ghosted[self] ~= "parking" then parkBlizzard(self) end end)
    if frame.ApplySystemAnchor then hooksecurefunc(frame, "ApplySystemAnchor", function(self) parkBlizzard(self) end) end
end

local function hideAllBlizzard()
    hideBlizzard(_G.PlayerFrame)
    for _, fr in ipairs({ _G.TargetFrame, _G.FocusFrame }) do
        if fr then ghostHooks(fr); ghostBlizzard(fr) end
    end
    hideBlizzard(_G.TargetFrameToT); hideBlizzard(_G.FocusFrameToT); hideBlizzard(_G.PetFrame)
    -- (party frames are left alone: Blizzard's, or whatever addon you use for them)
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
    -- a 0.57 test build briefly gave the pet the player's (larger) frame and cut a saved pet scale to
    -- match; the pet is the small frame again, so a scale cut then is put back
    if DB.petFrameV2 then
        DB.petFrameV2 = nil
        for _, l in pairs(DB.layouts or {}) do
            local u = type(l) == "table" and l.pet
            if type(u) == "table" and type(u.scale) == "number" then u.scale = u.scale * 198 / 120 end
        end
    end
    if not pcall(buildSettings) then
        print("|cffff9900Webby Frames:|r couldn't build the settings page; Edit Mode still works.")
    end
    if DB.enabled == false then return end

    for _, unit in ipairs(UNITS) do
        if unit == "targettarget" or unit == "focustarget" or unit == "pet" then createSmallFrame(unit) else createFrame(unit) end
    end
    Extras.init()
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
        local pf = _G.PlayerFrame
        if pf then print("Blizzard PlayerFrame shown", tostring(pf:IsShown()), "alpha", pf:GetAlpha(), "parent", tostring(pf:GetParent() and pf:GetParent():GetName())) end
        -- pet happiness as the game reports it (hunters)
        local hok, h, dmg, loyalty = pcall(function()
            if C_PetInfo and C_PetInfo.GetPetHappiness then return C_PetInfo.GetPetHappiness() end
            if GetPetHappiness then return GetPetHappiness() end
        end)
        local _, hunterPet = pcall(function() return select(2, HasPetUI()) end)
        print("Pet happiness:", (C_PetInfo and C_PetInfo.GetPetHappiness) and "C_PetInfo API" or (GetPetHappiness and "old API" or "no API"),
            "hunter pet", tostring(hunterPet), "pet", tostring(UnitExists("pet")), "->", tostring(hok), tostring(h), tostring(dmg), tostring(loyalty))
        local ac = frames.target and frames.target.auraContainer
        print("Aura containers:", ac and "in use" or (ac == false and "not available, using the old aura code" or "not made yet"))
        print("Version", addonVersion())
    elseif msg == "test" then
        -- a 10-second preview on your own frame: health slides to 60% (smooth bars), with 20% incoming
        -- heals, a 15% shield and a 10% heal-absorb; then everything goes back to the real values
        local f = frames.player
        if not f then return end
        pcall(updatePrediction, f)
        if not f.healBar then print("|cff33ccffWebby Frames:|r turn on Incoming heals or Absorb shields for the player frame first."); return end
        f.previewing = true
        f.hp:SetMinMaxValues(0, 100)
        f.hp:SetValue(100)
        for _, b in ipairs({ f.healBar, f.otherHealBar, f.absorbBar, f.healAbsorbBar }) do b:SetMinMaxValues(0, 100) end
        C_Timer.After(0.3, function()
            setBarValue(f, f.hp, 60)
            f.healBar:SetValue(getSetting("player", "healPrediction") and 12 or 0)
            f.otherHealBar:SetValue(getSetting("player", "healPrediction") and 8 or 0)
            f.absorbBar:SetValue(getSetting("player", "absorbs") and 15 or 0)
            f.healAbsorbBar:SetValue(getSetting("player", "absorbs") and 10 or 0)
        end)
        pcall(showHit, f, "WOUND", "CRITICAL", 1234)      -- and a combat number on the portrait
        C_Timer.After(10, function() f.previewing = nil; pcall(updateAll, f) end)
        print("|cff33ccffWebby Frames:|r previewing heals (green), a shield, a heal-absorb (red) and a combat number on your frame for 10 seconds.")
    elseif msg == "export" or msg == "import" then
        Profiles.show(msg)
    elseif msg == "errors" then
        -- the errors caught while updating the frames (each shown once)
        if #updateErrors == 0 then print("|cff33ccffWebby Frames:|r no errors caught.") end
        for i, err in ipairs(updateErrors) do print("|cffff6060Webby Frames error " .. i .. ":|r " .. tostring(err)) end
    elseif msg == "help" then
        print("|cff33ccffWebby Frames:|r /webby (options)   /webby edit (move the frames)   /webby reset (reset all frames)   /webby test (preview heals and shields)   /webby export / import (profiles)   /webby errors   /webby debug")
    else
        print("|cff33ccffWebby Frames:|r unknown command. Type |cff33ccff/webby help|r.")
    end
end
