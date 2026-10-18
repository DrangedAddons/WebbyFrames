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
    { "smart",    "Class for players, reaction for NPCs" },
    { "class",    "Class colour (players only)" },
    { "reaction", "By reaction" },
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
    scale = 1, showName = true, healthFade = false, textMode = "always", textFormat = "value", barTexture = "default", font = "default", threatShow = "both",
    threatStyle = "text",       -- the threat %: "text" (just the number, by the raid marker) or "box" (above the name)
    threatColors = "gradient",  -- "gradient" (green to red) or "blizzard"
    -- health bar colour: "smart" (class colour for players, reaction colour for NPCs), "class", "reaction" or "plain"
    colorMode = "smart",
    -- fade to red: "auto" (class-aware) or "custom" (up to three stops: health % and colour, 0% = off)
    fadeStyle = "auto", fadeBlend = true,
    fade1Pct = 60, fade1Color = { 0.93, 0.93, 0.20 },
    fade2Pct = 35, fade2Color = { 0.96, 0.55, 0.10 },
    fade3Pct = 20, fade3Color = { 0.89, 0.19, 0.19 },
    npcColor = "reaction",   -- hostile NPCs: "reaction" (red), "green" or "custom" (npcColorRGB = { r, g, b })
    -- buffs and debuffs (off unless a frame's defaults turn them on)
    auraBuffs = false, auraDebuffs = false, auraMine = false,
    auraSize = 18, auraPerRow = 8, auraMax = 16, auraPos = "below", auraTimer = "both",   -- auraDebuffSize follows auraSize until set
    auraGap = 2, auraGrowth = "right", auraStack = 50,      -- gap between icons, row direction, stack count size (% of icon)
    -- text: name size / outline / colour, bar numbers size / outline / place (size 0 = the font's own)
    nameSize = 0, nameColor = "default",           -- nameColor "custom": nameColorRGB = { r, g, b }
    textColor = "default",                         -- the bar numbers; "custom": textColorRGB = { r, g, b }
    textSize = 0, textAnchor = "center",
    portraitStyle = "picture",   -- "picture" or "class" (class icon for players)
    -- cast bar (target and focus): Blizzard's own bar drives one built into our frame
    castShow = true, castText = true, castIcon = true,
    -- frame art colour: "default" (gold, as drawn), "class" or "custom" (frameColor = { r, g, b })
    frameTint = "default",
    -- health bar extras
    frameShown = true,       -- target of target, focus, focus target, pet: the frame is used at all
    smoothBars = true, healPrediction = true, absorbs = true, damageTrail = true, damagePredict = true,
    combatNumbers = false,   -- damage / heal numbers over the portrait: fixed per frame (player, target, focus), one General switch
    -- icons and extras
    comboPoints = true,
    druidMana = true,        -- player: a druid's mana in a slim bar under the frame while in a form
    restTint = false,        -- player: the resting Zzz takes the frame colour
    costPredict = true,      -- player: while casting, the spell's cost shows on the power bar
    costShade = 55,          -- player: how much lighter (above 0) or darker (below 0) the cost shows
    cornerStyle = "retail",  -- player: the corner accent's art, Retail's or Forever's own
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

-- The corner accent's art, by the "Corner accent" setting: Retail's (DragonflightUI's, as drawn) or
-- Forever's older rounder gold one (no longer in the game; Media/corner-forever, made from a
-- screenshot of it, its bottom arm mirrored from the top one so both taper alike). Its texture: the
-- art in the top left 58 texels, right against the edges so both arms run thin to them, a hairline
-- black rim (1 texel; the art has its own dark edge there) along its curve so the portrait doesn't
-- show in the crack beside it, and
-- a 1px black line along its bottom, between it and the frame border; 58 x 60 texels in all. The gold
-- is 22px; the box's bottom right is where the gold's used to be.
local FOREVER_CORNER_SIZE = 22
local FOREVER_ART, FOREVER_RIM, FOREVER_LINE = 58, 0, 2   -- texels (FOREVER_RIM: the art's offset for the rim)

local function setCornerArt(tex, style, scale, nudge)
    local at = CORNER_POS
    -- plus any fine-tuning from /webby corner x y (right / up, in pixels)
    if nudge then at = { at[1] + (tonumber(nudge[1]) or 0), at[2] + (tonumber(nudge[2]) or 0) } end
    scale = scale or 1
    local f = tex:GetParent()
    while f and not f.baseUnit do f = f:GetParent() end        -- (the unit frame, past ov / the glow frames)
    if style == "forever" then
        local texel = FOREVER_CORNER_SIZE / FOREVER_ART * scale
        local half = FOREVER_CORNER_SIZE / 2 * scale
        if f then
            tex:ClearAllPoints()
            -- (the bottom line half below where the gold used to end: all of it below sat over the frame
            -- border, none of it left a gap)
            tex:SetPoint("BOTTOMRIGHT", f, "CENTER", at[1] + half, at[2] - half - FOREVER_LINE * texel / 2)
        end
        tex:SetTexture(MEDIA .. "corner-forever")
        local w, h = FOREVER_RIM + FOREVER_ART, FOREVER_RIM + FOREVER_ART + FOREVER_LINE
        tex:SetTexCoord(0, w / 64, 0, h / 64)
        tex:SetSize(w * texel, h * texel)
        return
    end
    if f then tex:ClearAllPoints(); tex:SetPoint("CENTER", f, "CENTER", at[1], at[2]) end
    setArt(tex, ART.corner, false, scale)
end

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

-- Options that are no longer options: always their default, whatever an older version saved (the
-- name / number text, and smooth bars, which are always on).
local FIXED = { nameSize = true, nameColor = true, textColor = true, textSize = true, textAnchor = true, smoothBars = true }
-- Choices that were taken out, read as what's left: frame colours dark, silver and the unit's class ->
-- gold; threat colours other than the gradient and Blizzard's -> the gradient.
local RETIRED = {
    frameTint = { dark = "default", silver = "default", unitclass = "default" },
    threatColors = { status = "gradient", colorblind = "gradient", class = "gradient" },
}

local function getSetting(unit, key)
    if FIXED[key] then return DEFAULT_SETTINGS[key] end
    local u = unitData(unit)
    local v = u and u[key]
    if v ~= nil and RETIRED[key] and RETIRED[key][v] then return RETIRED[key][v] end
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
    -- the threat switch became a choice of glow, number, both or off
    if v == nil and key == "threatShow" and u and u.showThreat == false then return "off" end
    -- the round threat badge is gone: it reads as just the number, in the same spot
    if key == "threatStyle" and v == "badge" then v = "text" end
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

-- Font and size for the name ("name...") and the bar numbers ("text..."): a size of 0 keeps each font
-- string's own; the numbers' colour (their own, or one you pick) and their place on their bar.
local function applyFont(f)
    local base = f.baseUnit
    local path = resolveFont(getSetting(base, "font"))
    f.fontDefaults = f.fontDefaults or {}
    for _, fs in ipairs({ f.name, f.hpText, f.mpText }) do
        if fs then
            if not f.fontDefaults[fs] then
                local fp, fz, ff = fs:GetFont()
                local r, g, b = fs:GetTextColor()
                f.fontDefaults[fs] = { fp, fz, ff, r, g, b }
            end
            local d = f.fontDefaults[fs]
            local pre = (fs == f.name) and "name" or "text"
            local size = getSetting(base, pre .. "Size")
            size = (type(size) == "number" and size > 0) and size or d[2]
            if size and fs ~= f.name and fs == f.mpText and getSetting(base, "textSize") > 0 then
                size = math.max(6, size - 1)          -- the power bar is thinner: its number a size down
            end
            local ol = d[3]
            if fs ~= f.name then
                -- the numbers' colour: their own, or the one picked
                local c = getSetting(base, "textColor") == "custom" and getSetting(base, "textColorRGB")
                if type(c) == "table" then fs:SetTextColor(c[1] or 1, c[2] or 1, c[3] or 1)
                elseif d[4] then fs:SetTextColor(d[4], d[5], d[6]) end
            end
            local ok = false
            if path and size then ok = fs:SetFont(path, size, ol) end
            if not ok and d[1] then fs:SetFont(d[1], size or d[2], ol) end
        end
    end
    -- the numbers: in the middle of their bar, or at its left or right end
    local where = getSetting(base, "textAnchor")
    for _, pair in ipairs({ { f.hpText, f.hp }, { f.mpText, f.mp } }) do
        local fs, bar = pair[1], pair[2]
        if fs and bar then
            fs:ClearAllPoints()
            if where == "left" then fs:SetPoint("LEFT", bar, "LEFT", 4, 0); fs:SetJustifyH("LEFT")
            elseif where == "right" then fs:SetPoint("RIGHT", bar, "RIGHT", -4, 0); fs:SetJustifyH("RIGHT")
            else fs:SetPoint("CENTER", bar, "CENTER", 0, 0); fs:SetJustifyH("CENTER") end
        end
    end
end

-- Health colour fade (like EllesmereUI): the colour is chosen by a curve the GAME evaluates from the
-- unit's health percent, so it works with protected values; the result is only ever passed to a setter.
-- The colour turns round the colour wheel to red the short way, staying saturated (no grey middle):
-- green passes yellow and orange like Blizzard's bars, blue goes by purple and pink, and white (priests)
-- just warms up to red. Full colour at full health, red from FADE_RED_AT down.
local FADE_RED    = { 0.89, 0.19, 0.19 }
local FADE_RED_AT = 0.25
local fadeCurves = {}

-- The blue and purple classes sit close together on the colour wheel, so going round it a mage would pass
-- through shaman blue. They get their own routes to red instead, kept apart by lightness as well as hue:
-- shaman stays dark, mage stays light and pastel, warlock stays a bright violet. (Stops between the
-- class colour at full health and red at FADE_RED_AT, evenly spaced.)
local FADE_ROUTES = {
    SHAMAN  = { { 0.08, 0.30, 0.74 }, { 0.32, 0.16, 0.58 }, { 0.58, 0.10, 0.36 }, { 0.76, 0.12, 0.22 } },
    MAGE    = { { 0.52, 0.80, 0.96 }, { 0.78, 0.72, 0.94 }, { 0.98, 0.64, 0.54 }, { 0.96, 0.42, 0.36 } },   -- (coral, not paladin pink)
    WARLOCK = { { 0.66, 0.46, 0.94 }, { 0.80, 0.36, 0.86 }, { 0.90, 0.28, 0.58 }, { 0.92, 0.22, 0.34 } },
}

-- The class whose colour this is (the bar's colour is a class colour when it's coloured by class)
local function fadeClassOf(r, g, b)
    local found
    pcall(function()
        for class, c in pairs(RAID_CLASS_COLORS or {}) do
            if math.abs(c.r - r) < 0.01 and math.abs(c.g - g) < 0.01 and math.abs(c.b - b) < 0.01 then found = class; return end
        end
    end)
    return found
end

local function toHSV(r, g, b)
    local mx, mn = math.max(r, g, b), math.min(r, g, b)
    local d = mx - mn
    local h = 0
    if d > 0 then
        if mx == r then h = ((g - b) / d) % 6 elseif mx == g then h = (b - r) / d + 2 else h = (r - g) / d + 4 end
        h = h * 60
    end
    return h, (mx > 0) and d / mx or 0, mx
end

local function fromHSV(h, s, v)
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c
    local r, g, b
    if h < 60 then r, g, b = c, x, 0 elseif h < 120 then r, g, b = x, c, 0 elseif h < 180 then r, g, b = 0, c, x
    elseif h < 240 then r, g, b = 0, x, c elseif h < 300 then r, g, b = x, 0, c else r, g, b = c, 0, x end
    return r + m, g + m, b + m
end

local function getFadeCurve(r, g, b)
    local key = string.format("%.2f:%.2f:%.2f", r, g, b)
    local c = fadeCurves[key]
    if c ~= nil then return c or nil end
    fadeCurves[key] = false
    pcall(function()
        if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return end
        local curve = C_CurveUtil.CreateColorCurve()
        pcall(function() curve:SetType(Enum.LuaCurveType.Linear) end)
        local route = FADE_ROUTES[fadeClassOf(r, g, b) or ""]
        if route then
            curve:AddPoint(0, CreateColor(FADE_RED[1], FADE_RED[2], FADE_RED[3], 1))
            curve:AddPoint(FADE_RED_AT, CreateColor(FADE_RED[1], FADE_RED[2], FADE_RED[3], 1))
            local n = #route + 1
            for i, s in ipairs(route) do
                curve:AddPoint(1 - (i / n) * (1 - FADE_RED_AT), CreateColor(s[1], s[2], s[3], 1))
            end
            curve:AddPoint(1, CreateColor(r, g, b, 1))
            fadeCurves[key] = curve
            return
        end
        local h1, s1, v1 = toHSV(r, g, b)
        local h2, s2, v2 = toHSV(FADE_RED[1], FADE_RED[2], FADE_RED[3])
        if s1 < 0.05 then h1 = h2 end               -- a grey or white has no hue of its own: just add red
        local dh = (h2 - h1 + 540) % 360 - 180       -- the short way round
        curve:AddPoint(0, CreateColor(FADE_RED[1], FADE_RED[2], FADE_RED[3], 1))
        local steps = 6
        for i = 0, steps do
            local p = i / steps                       -- 0 = your colour (full health), 1 = red
            local hp = 1 - p * (1 - FADE_RED_AT)
            local cr, cg, cb = fromHSV((h1 + dh * p) % 360, s1 + (s2 - s1) * p, v1 + (v2 - v1) * p)
            curve:AddPoint(hp, CreateColor(cr, cg, cb, 1))
        end
        fadeCurves[key] = curve
    end)
    return fadeCurves[key] or nil
end

-- Custom fade: up to three stops (fade1..3Pct, 0 = off, and fade1..3Color). Above the first stop the bar
-- keeps its colour; with fadeBlend the colours blend from one stop to the next, without it the bar
-- switches colour right at each stop. Below the last stop it stays that stop's colour.
local function getCustomFadeCurve(unit, r, g, b)
    local stops = {}
    for i = 1, 3 do
        local pct, col = getSetting(unit, "fade" .. i .. "Pct"), getSetting(unit, "fade" .. i .. "Color")
        if type(pct) == "number" and pct > 0 and type(col) == "table" then
            stops[#stops + 1] = { math.min(pct, 100) / 100, col[1] or 1, col[2] or 1, col[3] or 1 }
        end
    end
    if #stops == 0 then return nil end
    table.sort(stops, function(a, z) return a[1] > z[1] end)
    local blend = getSetting(unit, "fadeBlend") and true or false
    local parts = { blend and "b" or "s", string.format("%.2f:%.2f:%.2f", r, g, b) }
    for _, s in ipairs(stops) do parts[#parts + 1] = string.format("%.2f:%.2f:%.2f:%.2f", s[1], s[2], s[3], s[4]) end
    local key = "custom|" .. table.concat(parts, "|")
    local c = fadeCurves[key]
    if c ~= nil then return c or nil end
    fadeCurves[key] = false
    pcall(function()
        if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return end
        -- the points, from full health down: { health fraction, r, g, b }
        local pts = { { 1, r, g, b } }
        for i, s in ipairs(stops) do
            if not blend then
                -- hold the colour above until just over the stop, then switch
                local prev = (i == 1) and { 0, r, g, b } or stops[i - 1]
                pts[#pts + 1] = { s[1] + 0.001, prev[2], prev[3], prev[4] }
            end
            pts[#pts + 1] = s
        end
        local last = stops[#stops]
        pts[#pts + 1] = { 0, last[2], last[3], last[4] }
        table.sort(pts, function(a, z) return a[1] < z[1] end)
        local curve = C_CurveUtil.CreateColorCurve()
        pcall(function() curve:SetType(Enum.LuaCurveType.Linear) end)
        local lastX
        for _, p in ipairs(pts) do
            local x = math.max(0, math.min(1, p[1]))
            if x ~= lastX then curve:AddPoint(x, CreateColor(p[2], p[3], p[4], 1)); lastX = x end
        end
        fadeCurves[key] = curve
    end)
    return fadeCurves[key] or nil
end

-- Returns true when the fade painted the bar.
local function applyHealthFade(f, r, g, b)
    -- on: the health colour chosen above (class, reaction or plain green) fades to red as health drops
    if not getSetting(f.baseUnit, "healthFade") then return false end
    if not (UnitHealthPercent and UnitExists(f.wfUnit)) then return false end
    -- a mob someone else has tagged stays plain grey: its health is no business of yours
    local tapped
    pcall(function() tapped = (not UnitPlayerControlled(f.wfUnit)) and UnitIsTapDenied(f.wfUnit) end)
    if tapped then return false end
    local curve
    if getSetting(f.baseUnit, "fadeStyle") == "custom" then
        curve = getCustomFadeCurve(f.baseUnit, r or 0.1, g or 0.8, b or 0.1)
    else
        curve = getFadeCurve(r or 0.1, g or 0.8, b or 0.1)
    end
    if not curve then return false end
    local ok = pcall(function()
        local color = UnitHealthPercent(f.wfUnit, true, curve)
        local cr, cg, cb = color:GetRGB()
        f.hp:SetStatusBarColor(cr, cg, cb, 1)
    end)
    -- (the bar is on its tintable fill while fading, see updateHealthColor: no greying needed)
    return ok
end

local function updateHealthColor(f)
    local r, g, b
    pcall(function() r, g, b = healthColor(f) end)
    local tex = f.hp:GetStatusBarTexture()
    -- the tintable fill for a colour or a fade (tinting the green fill meant greying it first, which
    -- dulled every colour); the plain green fill otherwise
    local fading = getSetting(f.baseUnit, "healthFade") and true or false
    local want = ((r or fading) and f.hpStatusAtlas) or f.hpAtlas
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
        -- the tintable fill (fading) starts out green; the plain green fill as drawn
        if want == f.hpStatusAtlas then f.hp:SetStatusBarColor(0.1, 0.8, 0.1, 1) else f.hp:SetStatusBarColor(1, 1, 1, 1) end
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

-- Damage trail: when health drops, the part just lost stays on the bar in red for a moment, then slides
-- away. A bar under the health fill (createDamageTrail) that keeps the old health and follows the new
-- after a short wait, so it shows only where the fill has gone. Secret-safe: values only go to setters.
-- (Healing needs nothing: the fill grows over it, and it catches up underneath.)
local TRAIL_WAIT, TRAIL_MAXWAIT = 0.4, 1.0     -- seconds after the last hit; at most this long under steady damage

local function createDamageTrail(f)
    local t = CreateFrame("StatusBar", nil, f)
    t:SetAllPoints(f.hp)
    t:SetFrameLevel(f.hp:GetFrameLevel())
    f.hp:SetFrameLevel(t:GetFrameLevel() + 1)       -- (the health fill draws over it)
    t:SetStatusBarTexture(PLAIN_FILL)
    t.color = { 1, 0.15, 0.1, 0.9 }
    t:SetMinMaxValues(0, 1)
    t:SetValue(0)
    t:Hide()
    t:SetScript("OnUpdate", function(self, elapsed)
        if not self.pending then return end
        self.wait = self.wait - elapsed
        self.waited = self.waited + elapsed
        if self.wait > 0 and self.waited < TRAIL_MAXWAIT then return end
        self.pending = false
        if not (SMOOTH and pcall(self.SetValue, self, self.target, SMOOTH)) then pcall(self.SetValue, self, self.target) end
    end)
    f.hpTrail = t
end

-- Damage prediction: while you cast at an enemy, the damage the spell will do (read from its tooltip:
-- "450 to 520 Fire damage" -> the middle, 485) is shaded off the end of its health fill. A reverse
-- bar from the fill's moving end with the health max and that amount, so nothing touches the
-- unit's (possibly secret) health. Base damage only: crits, resists and armour aren't known.
local scanTip
local function tooltipLines(spell)
    local lines = {}
    local ok = pcall(function()
        local data = C_TooltipInfo and C_TooltipInfo.GetSpellByID(spell)
        for _, l in ipairs(data and data.lines or {}) do
            if l.leftText then lines[#lines + 1] = l.leftText end
        end
    end)
    if ok and #lines > 0 then return lines end
    pcall(function()
        if not scanTip then
            scanTip = CreateFrame("GameTooltip", "WebbyFramesScanTip", nil, "GameTooltipTemplate")
        end
        scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
        scanTip:SetSpellByID(spell)
        for i = 1, scanTip:NumLines() do
            local fs = _G["WebbyFramesScanTipTextLeft" .. i]
            local text = fs and fs:GetText()
            if text then lines[#lines + 1] = text end
        end
        scanTip:Hide()
    end)
    return lines
end

-- The first damage in the tooltip: "X to Y ... damage" (the middle) or "X ... damage". nil if none.
local function spellDamage(spell)
    local function num(s) return tonumber((s:gsub(",", ""))) end
    for _, text in ipairs(tooltipLines(spell)) do
        local ok, amount = pcall(function()
            local lower = text:lower()
            local at = lower:find("damage")
            if not at then return nil end
            local before = lower:sub(1, at)
            local lo, hi
            for a, b in before:gmatch("(%d[%d,]*) to (%d[%d,]*)") do lo, hi = a, b end
            if lo then return (num(lo) + num(hi)) / 2 end
            local last
            for a in before:gmatch("(%d[%d,]*)") do last = a end
            return last and num(last) or nil
        end)
        if ok and amount and amount > 0 then return math.floor(amount + 0.5), text end
    end
    return nil
end

local function updateDamagePrediction(f, spell)
    if not (f and f.hp) then return end
    local amount
    if spell and getSetting(f.baseUnit, "damagePredict") then
        local hostile = false
        pcall(function() hostile = UnitCanAttack("player", f.wfUnit) and true or false end)
        if hostile then
            local line
            amount, line = spellDamage(spell)
            f.dmgInfo = "spell " .. tostring(spell) .. ": " .. (amount and (amount .. " from \"" .. tostring(line) .. "\"") or "no damage found in its tooltip")
        end
    end
    local bar = f.dmgBar
    if not amount then if bar then bar:Hide() end; return end
    if not bar then
        -- clipped to the health bar, over its fill
        local clip = CreateFrame("Frame", nil, f.hp)
        clip:SetAllPoints(f.hp)
        clip:SetClipsChildren(true)
        clip:SetFrameLevel(f.hp:GetFrameLevel() + 2)
        bar = CreateFrame("StatusBar", nil, clip)
        bar:SetReverseFill(true)
        bar:SetStatusBarTexture(PLAIN_FILL)
        bar.color = { 1, 1, 1, 0.5 }
        f.dmgBar = bar
    end
    styleOverlay(f, bar)
    pcall(function() bar:GetStatusBarTexture():SetBlendMode("ADD") end)
    local fill = f.hp:GetStatusBarTexture()
    bar:ClearAllPoints()
    bar:SetPoint("TOPRIGHT", fill, "TOPRIGHT")
    bar:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
    bar:SetWidth(f.hp:GetWidth())
    local max = value(UnitHealthMax, f.wfUnit)
    if max then pcall(bar.SetMinMaxValues, bar, 0, max) end
    pcall(bar.SetValue, bar, amount)
    pcall(function() f.dmgWho = UnitGUID(f.wfUnit) end)   -- (a new unit in the frame clears it: updateHealth)
    bar:Show()
end

-- After the cast: the shading stays while the spell is on its way (a Fireball in the air), until it
-- lands: the unit's health moves or it has a combat event (hit, miss, resist). At most FLY_MAX seconds.
-- (Someone else hitting it first ends it early too: nothing tells the hits apart. The combat log
-- would, but registering for it is forbidden to addons on 12.x and brings up the blocked-addon popup.)
local FLY_MAX = 1.5
local function landDamage(f)
    if f and f.dmgFlying then
        f.dmgFlying = nil
        pcall(updateDamagePrediction, f, nil)
    end
end

local function flyDamage(spell)
    local token = {}
    for _, f in ipairs({ frames.target, frames.focus }) do
        if f and f.dmgBar and f.dmgBar:IsShown() then
            -- a quick spell's hit can come in just before the cast's own "succeeded": already landed
            if GetTime() - (f.hitAt or 0) < 0.2 then
                pcall(updateDamagePrediction, f, nil)
            else
                f.dmgFlying = token
            end
        end
    end
    C_Timer.After(FLY_MAX, function()
        for _, f in ipairs({ frames.target, frames.focus }) do
            if f and f.dmgFlying == token then landDamage(f) end
        end
    end)
end

local function updateDamageTrail(f, status)
    local t = f.hpTrail
    if not t then return end
    if not getSetting(f.baseUnit, "damageTrail") then t:Hide(); return end
    styleOverlay(f, t)
    local u = f.wfUnit
    local max = value(UnitHealthMax, u)
    if max then pcall(t.SetMinMaxValues, t, 0, max) end
    local now = value(UnitHealth, u)
    -- someone else in the frame (new target), or dead / offline: straight to the new health, no trail
    local who
    pcall(function() who = UnitGUID(u) end)
    local fresh = false
    pcall(function() fresh = (who ~= t.who) end)
    t.who = who
    if fresh or status then
        t.pending = false
        pcall(t.SetValue, t, now or 0)
    else
        t.target = now
        if not t.pending then t.pending, t.waited = true, 0 end
        t.wait = TRAIL_WAIT
    end
    t:Show()
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
    pcall(updateDamageTrail, f, status)
    -- the damage shading belongs to the unit it was cast at: gone if the frame now shows someone else
    if f.dmgBar and f.dmgBar:IsShown() then
        pcall(function()
            if f.dmgWho ~= UnitGUID(u) then f.dmgFlying = nil; f.dmgBar:Hide() end
        end)
    end
    if status then f.hpText:SetText(status) else setBarText(f.hpText, f, "hp") end
    if status ~= f.statusText then
        f.statusText = status
        if refreshText then refreshText(f) end
    end
end

-- Spell cost (player), shown on the power bar in the bar's own fill, lightened:
--  - during a cast: the part the spell will spend.
--    A reverse-fill bar as long as the power bar, its right end on the fill's moving end.
--  - after: right after a spell goes off (keybinds and instants too), the part it just spent flashes
--    past the end of the fill and fades out. A normal bar, its left end on the fill's end.
-- Both have the power bar's max and the cost as their value, so no maths on the power itself.

-- The cost of a spell in your current power type, or nil; and what was found (kept for /webby cost).
local function spellCost(spell, label)
    local cost
    local info = label .. " spell " .. tostring(spell)
    local ok, err = pcall(function()
        local get = (C_Spell and C_Spell.GetSpellPowerCost) or GetSpellPowerCost
        if not get then info = info .. ": no cost API"; return end
        local ptype = UnitPowerType("player")
        local list = get(spell)
        info = info .. ", power type " .. tostring(ptype) .. ", costs:"
        for _, c in ipairs(list or {}) do
            local amount = c.cost or c.minCost
            info = info .. " [type " .. tostring(c.type) .. " cost " .. tostring(amount) .. "]"
            if c.type == ptype and amount and amount > 0 then cost = amount end
        end
    end)
    if not ok then info = info .. " (error: " .. tostring(err) .. ")" end
    return cost, info .. (cost and " -> shown" or " -> nothing to show")
end

-- Fits one of the cost bars to the power bar: its fill, mask and length, its end on the fill's end.
local function fitCostBar(f, bar, side)
    local tex = f.mpCurrent or PLAIN_FILL
    if bar.tex ~= tex then
        bar.tex = tex
        if not pcall(bar.SetStatusBarTexture, bar, tex) or not bar:GetStatusBarTexture() then bar:SetStatusBarTexture(PLAIN_FILL) end
        if f.mpMaskOn then pcall(function() bar:GetStatusBarTexture():AddMaskTexture(f.mpMask) end) end
    end
    bar:ClearAllPoints()
    bar:SetPoint("TOP", f.mp, "TOP")
    bar:SetPoint("BOTTOM", f.mp, "BOTTOM")
    bar:SetPoint(side, f.mp:GetStatusBarTexture(), "RIGHT")
    bar:SetWidth(f.mp:GetWidth())
    pcall(bar.SetMinMaxValues, bar, 0, UnitPowerMax("player"))
end

-- Shades a cost bar by the "Spell cost shade" slider (-100 to 100): above 0 it lightens the fill
-- (added white), below 0 it darkens it (black laid over), by that much. The spent flash (`flash`)
-- always lightens, by the same amount and a little more: only the cast preview darkens. False at 0
-- (nothing to show).
local function shadeCostBar(bar, flash)
    local v = tonumber(getSetting("player", "costShade")) or 55
    if v == 0 then return false end
    local a = math.min(1, math.abs(v) / 100 + (flash and 0.25 or 0))
    local tex = bar:GetStatusBarTexture()
    if v > 0 or flash then
        pcall(tex.SetBlendMode, tex, "ADD")
        bar:SetStatusBarColor(1, 1, 1, a)
    else
        pcall(tex.SetBlendMode, tex, "BLEND")
        bar:SetStatusBarColor(0, 0, 0, a)
    end
    return true
end

local function updateCostPrediction(f)
    local cp = f.costBar
    if not cp then return end
    local cost
    if f.castSpell and getSetting("player", "costPredict") then
        cost, f.costInfo = spellCost(f.castSpell, "cast")
    end
    if not cost then cp:Hide(); return end
    fitCostBar(f, cp, "RIGHT")
    if not shadeCostBar(cp) then cp:Hide(); return end
    pcall(cp.SetValue, cp, cost)
    cp:Show()
end

-- A spell just went off: flash what it spent.
local SPENT_FADE = 0.6       -- seconds
local function flashSpent(f, spell)
    local sb = f.spentBar
    if not (sb and spell and getSetting("player", "costPredict")) then return end
    local cost
    cost, f.costInfo = spellCost(spell, "spent")
    if not cost then return end
    fitCostBar(f, sb, "LEFT")
    if not shadeCostBar(sb, true) then return end
    pcall(sb.SetValue, sb, cost)
    sb.left = SPENT_FADE
    sb:SetAlpha(1)
    sb:Show()
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
    if f.costBar then pcall(updateCostPrediction, f) end
    -- a druid in bear or cat form: their mana in the slim bar under the frame
    local am = f.altMana
    if am then
        local show = false
        pcall(function()
            show = getSetting("player", "druidMana") and select(2, UnitClass("player")) == "DRUID" and token ~= "MANA"
        end)
        am:SetShown(show and true or false)
        if show then
            pcall(function()
                local mana = Enum.PowerType and Enum.PowerType.Mana or 0
                am.bar:SetMinMaxValues(0, UnitPowerMax("player", mana))
                setBarValue(f, am.bar, UnitPower("player", mana))
                am.text:SetText(AbbreviateLargeNumbers(UnitPower("player", mana)))
            end)
            am.text:SetShown(getSetting("player", "textMode") ~= "off")
        end
    end
end

-- The colour of a mob's level against yours, as the default UI shows it: grey (no challenge), green, yellow
-- (about your level), orange, red (5+ above). Blizzard's own way first, then the older one, then the
-- classic rule worked out here.
local function levelDifficultyColor(u, l)
    local c
    pcall(function()
        if C_PlayerInfo and C_PlayerInfo.GetContentDifficultyCreatureForPlayer and GetDifficultyColor then
            local d = GetDifficultyColor(C_PlayerInfo.GetContentDifficultyCreatureForPlayer(u))
            if d and d.r then c = { d.r, d.g, d.b } end
        end
    end)
    if c then return c end
    pcall(function()
        if GetCreatureDifficultyColor then
            local d = GetCreatureDifficultyColor(l)
            if d and d.r then c = { d.r, d.g, d.b } end
        end
    end)
    if c then return c end
    pcall(function()
        local diff = l - UnitLevel("player")
        local greyAt = (GetQuestGreenRange and GetQuestGreenRange()) or 5
        if diff >= 5 then c = { 1, 0.1, 0.1 }
        elseif diff >= 3 then c = { 1, 0.5, 0.25 }
        elseif diff >= -2 then c = { 1, 1, 0 }
        elseif -diff <= greyAt then c = { 0.25, 0.75, 0.25 }
        else c = { 0.5, 0.5, 0.5 } end
    end)
    return c
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
    local skull = false
    local shown = pcall(function()
        local l = UnitLevel(u)
        if l and l > 0 then
            f.level:SetText(tostring(l))
            if f.baseUnit ~= "player" and UnitCanAttack("player", u) then
                local c = levelDifficultyColor(u, l)
                if c then lr, lg, lb = c[1], c[2], c[3] end
            end
        else
            -- too high to tell (bosses, far higher mobs): the skull, as on Blizzard's frames
            f.level:SetText("??")
            if f.baseUnit ~= "player" then lr, lg, lb = 1, 0.1, 0.1; skull = true end
        end
    end)
    if not shown and not pcall(function() f.level:SetFormattedText("%d", UnitLevel(u)) end) then f.level:SetText("") end
    f.level:SetTextColor(lr, lg, lb)
    -- the skull sits in the level badge in place of "??"
    if skull and f.badge and not f.skull then
        f.skull = f.ov:CreateTexture(nil, "OVERLAY", nil, 4)
        if hasAtlas("UI-HUD-UnitFrame-Target-HighLevelTarget_Icon") then
            f.skull:SetAtlas("UI-HUD-UnitFrame-Target-HighLevelTarget_Icon")
        else
            f.skull:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
        end
        f.skull:SetSize(16, 16)
        f.skull:SetPoint("CENTER", f.badge, "CENTER", 0, 0)
    end
    if f.skull then f.skull:SetShown(skull) end
    if f.badge then f.level:SetShown(not (skull and f.skull)) end
    -- name colour: the font's own (gold), white, the unit's class colour (players; NPCs keep the gold)
    -- or its reaction colour
    if not f.nameDefault then f.nameDefault = { f.name:GetTextColor() } end
    local nm = getSetting(f.baseUnit, "nameColor")
    local nr, ng, nb = f.nameDefault[1], f.nameDefault[2], f.nameDefault[3]
    if nm == "white" then nr, ng, nb = 1, 1, 1
    elseif nm == "class" then
        pcall(function()
            if UnitIsPlayer(u) then
                local c = RAID_CLASS_COLORS[select(2, UnitClass(u))]
                if c then nr, ng, nb = c.r, c.g, c.b end
            end
        end)
    elseif nm == "reaction" then
        local r, g, b = reactionColorOf(u)
        if r then nr, ng, nb = r, g, b end
    elseif nm == "custom" then
        local c = getSetting(f.baseUnit, "nameColorRGB")
        if type(c) == "table" then nr, ng, nb = c[1] or 1, c[2] or 1, c[3] or 1 end
    end
    f.name:SetTextColor(nr, ng, nb)
    -- portrait: the unit's picture, or for players their class icon
    local classIcon = false
    if getSetting(f.baseUnit, "portraitStyle") == "class" then
        pcall(function()
            if UnitIsPlayer(u) then
                local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[select(2, UnitClass(u))]
                if coords then
                    f.portrait:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
                    f.portrait:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
                    classIcon = true
                end
            end
        end)
    end
    if not classIcon then
        f.portrait:SetTexCoord(0, 1, 0, 1)
        SetPortraitTexture(f.portrait, u)
    end
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
        -- a mob someone else has tagged: grey, like its health bar
        pcall(function() if (not UnitPlayerControlled(u)) and UnitIsTapDenied(u) then r, g, b = 0.5, 0.5, 0.5 end end)
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
        f.cornerGlowTex = { { halo, 1.35 }, { lit, 1 } }   -- (re-drawn by applyCorner for the corner style)
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
        -- pulse animations per frame, started and stopped together: a strong, quick one in combat and
        -- a soft, slow breath while resting
        -- Blizzard's own pulse (PlayerFrame_OnUpdate): the alpha ramps straight up from 55/255 to full
        -- over half a second, then straight back down, for resting and combat alike. Runs while the
        -- glow is shown; its colour is ours (updateIndicators).
        local counter, sign = 0, 1
        sf:SetScript("OnUpdate", function(_, elapsed)
            counter = counter + elapsed
            if counter > 0.5 then sign = -sign end
            counter = counter % 0.5
            local alpha
            if sign == 1 then alpha = (55 + counter * 400) / 255 else alpha = (255 - counter * 400) / 255 end
            alpha = math.max(0, math.min(1, alpha))
            sf:SetAlpha(alpha); cf:SetAlpha(alpha)
        end)
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
        -- the % in its own little box sitting on the frame's top edge above the end of the name row, so a red
        -- number never lands on a red name strip: a dark inside and the frame's line style round it (1px
        -- mid-grey line with a dark shadow inside, as the bars and cast bar have)
        local box = CreateFrame("Frame", nil, ov)
        box:SetSize(40, 16)
        box:SetFrameLevel(ov:GetFrameLevel() + 1)
        box.line = box:CreateTexture(nil, "BACKGROUND", nil, 0)
        box.line:SetAllPoints()
        box.line:SetColorTexture(0.55, 0.55, 0.55, 1)
        box.shadow = box:CreateTexture(nil, "BACKGROUND", nil, 1)
        box.shadow:SetPoint("TOPLEFT", 1, -1); box.shadow:SetPoint("BOTTOMRIGHT", -1, 1)
        box.shadow:SetColorTexture(0, 0, 0, 1)
        box.inside = box:CreateTexture(nil, "BACKGROUND", nil, 2)
        box.inside:SetPoint("TOPLEFT", 2, -2); box.inside:SetPoint("BOTTOMRIGHT", -2, 2)
        box.inside:SetColorTexture(0.08, 0.08, 0.08, 0.92)
        box:Hide()
        f.threatBox = box
        f.threatText = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.threatText:SetPoint("CENTER", box, "CENTER", 0, 0)
        f.threatText:SetJustifyH("CENTER")
        f.threatText:Hide()
        -- or just the number, at the top of the portrait beside the raid marker (see updateThreat)
        local spot = CreateFrame("Frame", nil, ov)
        spot:SetSize(42, 20)
        spot:SetFrameLevel(ov:GetFrameLevel() + 2)
        spot.text = spot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        spot.text:SetPoint("CENTER", spot, "CENTER", 0, 0)
        pcall(function()
            local fp = spot.text:GetFont()
            spot.text:SetFont(fp or STANDARD_TEXT_FONT, 11, "OUTLINE")
        end)
        spot:Hide()
        f.threatBadge = spot
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
        -- the threat box: on the frame art's top edge, above the end of the name row
        if f.threatBox then
            f.threatBox:ClearAllPoints()
            f.threatBox:SetPoint("BOTTOMRIGHT", f.hp, "TOPRIGHT", 0, 15)
        end
        -- the threat number's spot: on the portrait ring's top, on the bars' side of the raid marker (which
        -- sits at the top centre), clear of the portrait
        if f.threatBadge then
            f.threatBadge:ClearAllPoints()
            f.threatBadge:SetPoint("CENTER", p, "TOP", left and 36 or -36, -2)
        end
    end
end

-- A frame colour made fit for a glow (the resting glow, the Zzz). Glows are added on top of the art,
-- so pale colours wash out to white and yellow-greens read as yellow (the hunter's green looked gold).
-- So: full brightness, more saturation, and yellow-greens nudged greener. Greys stay grey.
local function glowColor(c)
    local r, g, b = c[1], c[2], c[3]
    local hi, lo = math.max(r, g, b), math.min(r, g, b)
    if hi <= 0.01 then return 1, 1, 1 end
    local s = (hi - lo) / hi
    if s < 0.08 then return 1, 1, 1 end                     -- white, grey or black: a white glow
    local h                                                 -- hue in degrees
    if hi == r then h = 60 * (((g - b) / (hi - lo)) % 6)
    elseif hi == g then h = 60 * ((b - r) / (hi - lo) + 2)
    else h = 60 * ((r - g) / (hi - lo) + 4) end
    if h > 65 and h < 115 then h = h + (115 - h) * 0.5 end   -- yellow-green: halfway to green
    s = math.min(1, s * 1.5 + 0.1)
    -- back to RGB at full brightness
    local x = s * (1 - math.abs((h / 60) % 2 - 1))
    local m = 1 - s
    local seg = math.floor(h / 60) % 6
    local rr, gg, bb
    if seg == 0 then rr, gg, bb = s, x, 0
    elseif seg == 1 then rr, gg, bb = x, s, 0
    elseif seg == 2 then rr, gg, bb = 0, s, x
    elseif seg == 3 then rr, gg, bb = 0, x, s
    elseif seg == 4 then rr, gg, bb = x, 0, s
    else rr, gg, bb = s, 0, x end
    return rr + m, gg + m, bb + m
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
            if f.cornerBack then f.cornerBack:SetShown(cornerOn and getSetting(f.baseUnit, "cornerStyle") ~= "forever") end
        end
        if f.cornerGlow then f.cornerGlow:SetShown(f.corner and f.corner:IsShown() or false) end
        if f.status then
            local resting = false
            pcall(function() resting = IsResting() and true or false end)
            if showC then
                f.status:SetDesaturated(false)
                f.status:SetVertexColor(1, 0, 0)
                f.status:Show()
            elseif resting then
                -- the resting glow takes the frame colour (made glow-fit, so a dark frame still glows
                -- and greens stay green), gold when the frame is as drawn
                local c = f.tintColor
                if c then
                    f.status:SetDesaturated(true)
                    f.status:SetVertexColor(glowColor(c))
                else
                    f.status:SetDesaturated(false)
                    f.status:SetVertexColor(1, 0.88, 0.25)
                end
                f.status:Show()
            else
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

-- Threat, worked out the way Foofi's ThreatDisplay does it:
-- - the percentage is your RAW threat against the mob's current target (melee pulls at about 110%, ranged
--   at about 130%; it stops changing once you have aggro), or the scaled one (100% = a pull from where
--   you stand) when there's no raw figure
-- - the differential is your threat minus the highest in your group (+0 when you're top, -500 when
--   someone has 500 more)
-- - colours by threat status: 0 safe, 1 about to pull, 2 tanking (insecurely), 3 tanking (securely)
local THREAT_SCHEMES = {
    status     = { [0] = { 1, 1, 0 }, [1] = { 1, 0, 0 }, [2] = { 0, 0.5, 1 }, [3] = { 0.7, 0, 0.7 } },
    colorblind = { [0] = { 0.9, 0.9, 0.9 }, [1] = { 1, 0.5, 0 }, [2] = { 0, 0.7, 1 }, [3] = { 1, 1, 0 } },
}

local function threatColor(base, status, scaled)
    local scheme = getSetting(base, "threatColors")
    local r, g, b
    pcall(function()
        if scheme == "gradient" then
            -- green -> yellow -> red on the scaled percent (100 = a pull)
            local p = math.max(0, math.min(1, (scaled or 0) / 100))
            if p < 0.5 then r, g, b = p * 2, 1, 0 else r, g, b = 1, 1 - ((p - 0.5) * 2), 0 end
        elseif scheme == "class" then
            local c = RAID_CLASS_COLORS[select(2, UnitClass("player"))]
            if c then r, g, b = c.r, c.g, c.b end
        elseif scheme == "blizzard" then
            r, g, b = GetThreatStatusColor(status)
        else
            local s = THREAT_SCHEMES[scheme] or THREAT_SCHEMES.status
            local c = s[status] or s[0]
            r, g, b = c[1], c[2], c[3]
        end
    end)
    if not r then r, g, b = 1, 1, 0 end
    return r, g, b
end

-- While you hold aggro the raw % stops updating (it's measured against the mob's target: you), so then
-- the % is your threat against the next highest in your group, pets included: 255% = 2.55 times theirs.
-- 100 when no one else is on the mob; nil when the amounts can't be read.
local function threatOverNext(mob)
    local _, _, _, _, mine = UnitDetailedThreatSituation("player", mob)
    if not mine or mine <= 0 then return nil end
    local units = { "pet" }
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. i; units[#units + 1] = "raidpet" .. i end
    elseif IsInGroup() then
        for i = 1, GetNumGroupMembers() - 1 do units[#units + 1] = "party" .. i; units[#units + 1] = "partypet" .. i end
    end
    local second = 0
    for _, gu in ipairs(units) do
        if UnitExists(gu) and not UnitIsUnit(gu, "player") then
            local _, _, _, _, v = UnitDetailedThreatSituation(gu, mob)
            if v and v > second then second = v end
        end
    end
    if second <= 0 then return 100 end
    return math.floor(mine / second * 100 + 0.5)
end

local function updateThreat(f)
    if not f.threatText then return end
    -- what to show: "both" (glow and number), "glow", "number" or "off"
    local mode = getSetting(f.baseUnit, "threatShow")
    local wantGlow, wantNumber = (mode == "both" or mode == "glow"), (mode == "both" or mode == "number")
    -- where the number goes: "text" (just the number, by the raid marker) or "box" (above the name row)
    local inBox = getSetting(f.baseUnit, "threatStyle") == "box"
    local status, scaled, pct
    pcall(function()
        if not (wantGlow or wantNumber) then return end
        local u = f.wfUnit
        if not UnitExists(u) or not UnitCanAttack("player", u) then return end
        -- PvP: players (and their pets and totems) have no threat to show
        if UnitIsPlayer(u) or UnitPlayerControlled(u) then return end
        local tanking, st, sc, raw = UnitDetailedThreatSituation("player", u)
        status, scaled = st, sc
        pct = raw or sc
        -- holding aggro: the raw % would sit frozen, so measure against the next highest instead
        if tanking then
            local over
            pcall(function() over = threatOverNext(u) end)
            if over then pct = over end
        end
    end)
    -- Values may be protected: they only go to SetFormattedText, and comparisons are inside pcall. The glow
    -- shows from status 1 up (about to pull, tanking); a status that can't be compared shows none.
    local shown, glowOn, has = false, false, false
    pcall(function() has = (status ~= nil and pct ~= nil) end)
    if has then
        local r, g, b = threatColor(f.baseUnit, status, scaled)
        if wantNumber then
            local fs = (not inBox and f.threatBadge) and f.threatBadge.text or f.threatText
            shown = pcall(fs.SetFormattedText, fs, "%d%%", pct)
            if shown then fs:SetTextColor(r, g, b) end
        end
        if wantGlow then pcall(function() glowOn = status >= 1 end) end
        if glowOn then f.threatGlow:SetVertexColor(r, g, b) end
    end
    local byMarker = not inBox and f.threatBadge ~= nil
    f.threatText:SetShown(shown and not byMarker)
    if f.threatBox then f.threatBox:SetShown(shown and not byMarker) end
    if f.threatBadge then
        -- just the number, beside the raid marker on the bars' side, clear of the portrait
        f.threatBadge:SetShown(shown and byMarker)
        if f.portrait then
            f.threatBadge:ClearAllPoints()
            f.threatBadge:SetPoint("CENTER", f.portrait, "TOP", f.layoutLeft and 36 or -36, -2)
        end
    end
    f.threatGlow:SetShown(glowOn)
    -- (the number sits in its own box above the name row now, so the name keeps its full width)
    if f.nameBaseW then f.name:SetWidth(f.nameBaseW) end
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
-- The box, in the frame's TOPLEFT coordinates (target and focus: portrait on the right). Its top border
-- line is the frame art's bottom border line (at y -71, under the mana bar): the cast bar shares that line
-- with the mana bar. It runs on to the level badge, which is drawn on top and hides its end.
local CAST_BOX = { top = -71, x1 = 20.5, x2 = 200 }
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
    -- the border: 3 rows x 2 columns of frame-art slices (left cap, stretched middle; the right end runs
    -- under the portrait ring)
    cb.slices = {}
    for r = 1, 3 do
        for c = 1, 2 do
            local t = box:CreateTexture(nil, "BACKGROUND", nil, 2)
            local xs = (c == 2) and CAST_ART.midX or CAST_ART.capX
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
    local h = castBoxHeight()
    local box = cb.box
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", f, "TOPLEFT", CAST_BOX.x1, CAST_BOX.top)
    box:SetPoint("BOTTOMRIGHT", f, "TOPLEFT", CAST_BOX.x2, CAST_BOX.top - h)
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
    local fill = f.customTex or (BAR_FILE.target .. "Health-Status")
    if cb.fill ~= fill then
        cb.fill = fill
        cb:SetStatusBarTexture(fill)
        cb.fillMasked = nil
    end
    -- the box's end cut along the portrait ring (once per texture)
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
    -- ... and its font, at the size and style of the health bar numbers
    pcall(function() cb.text:SetFont(f.hpText:GetFont()) end)
    local inL, inT, inB = CAST_ART.inset.left, CAST_ART.inset.top, CAST_ART.inset.bottom
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
    local fillLeft = CAST_BOX.x1 + inL + (showIcon and (inner + 1) or 0)
    local hpMid = 23 + 126 / 2
    cb.text:ClearAllPoints()
    -- (1px up: the font string's box includes room for descenders, so it sits low when centred)
    cb.text:SetPoint("CENTER", cb, "CENTER", hpMid - (fillLeft + CAST_BOX.x2) / 2, 1)
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
-- Buffs and debuffs: where the block sits, and the timer option.
---------------------------------------------------------------------------
local AURA_GAP = 2       -- default gap between icons

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
        -- just below the cast box (its bottom line's soft shadow included)
        return "TOPLEFT", "TOPLEFT", CAST_BOX.x1 + 1.5, CAST_BOX.top - castBoxHeight() - 1
    end
    return "TOPLEFT", "TOPLEFT", x, -87
end

-- The "Time left" option as two switches: the dark sweep and the countdown numbers.
local function auraTimerParts(base)
    local mode = getSetting(base, "auraTimer")
    return mode == "both" or mode == "swipe", mode == "both" or mode == "numbers"
end

---------------------------------------------------------------------------
-- Buffs and debuffs through Blizzard's AuraContainer (12.1, on Forever too). In combat the aura data is
-- protected, so addons can't read it; the container tracks and filters the unit's auras itself and fills
-- buttons we've styled: we give each button its icon texture, cooldown swipe, stack count and dispel
-- border, and set the layout.
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
        -- stack count: a share of the icon's size (Stack count size, 30 - 90%)
        local share = (getSetting(f.baseUnit, "auraStack") or 50) / 100
        pcall(function() b.webbyCount:SetFont(b.webbyCount:GetFont() or STANDARD_TEXT_FONT, math.max(7, math.floor(size * share)), "OUTLINE") end)
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
    if not c then return end          -- (a client without Blizzard's aura container: no auras)
    local base = f.baseUnit
    local showB = getSetting(base, "auraBuffs") and true or false
    local showD = getSetting(base, "auraDebuffs") and true or false
    local perRow, max = getSetting(base, "auraPerRow"), getSetting(base, "auraMax")
    -- rows are as wide as perRow of the bigger icons, so neither group spills past them
    local size = math.max(showB and getSetting(base, "auraSize") or 0, showD and getSetting(base, "auraDebuffSize") or 0)
    if size == 0 then size = getSetting(base, "auraSize") end
    local pos = getSetting(base, "auraPos")
    local up = (pos == "above")
    local gap = getSetting(base, "auraGap")
    gap = (type(gap) == "number" and gap >= 0) and gap or AURA_GAP
    local leftward = getSetting(base, "auraGrowth") == "left"
    pcall(function() if c:GetUnit() ~= f.wfUnit then c:SetUnit(f.wfUnit) end end)
    pcall(c.SetAuraGroupEnabled, c, "buffs", showB)
    pcall(c.SetAuraGroupEnabled, c, "debuffs", showD)
    pcall(c.SetAuraGroupFilterString, c, "debuffs", getSetting(base, "auraMine") and "HARMFUL|PLAYER" or "HARMFUL")
    for _, g in ipairs(AuraKit.GROUPS) do
        pcall(c.SetAuraGroupMaxFrameCount, c, g, max)
        pcall(c.SetAuraGroupLayout, c, g, { elementSpacing = gap, lineSpacing = gap, groupSpacing = gap, groupLineSpacing = gap })
    end
    -- flow: rows of perRow icons, growing right (or filling from the right, growing left) and down (up
    -- when above the frame); the block keeps the same spot either way
    pcall(function()
        local A = AnchorUtil
        c:SetFlowLayoutAxis(A.FlowLayoutAxis.Horizontal)
        local side = leftward and "RIGHT" or "LEFT"
        c:SetFlowLayoutAnchorPoint((up and "BOTTOM" or "TOP") .. side)
        local across = leftward and (A.FlowDirection.Left or -1) or A.FlowDirection.Right
        c:SetFlowLayoutGrowthDirection(across, up and A.FlowDirection.Up or A.FlowDirection.Down)
        c:SetFlowLayoutMaximumLineSize(perRow * (size + gap))
    end)
    local point, relPoint, x, y = auraAnchor(f, pos)
    c:ClearAllPoints()
    c:SetPoint(point, f, relPoint, x, y)
    -- one row's size, so the first row sits exactly on the anchor (more rows grow on past it)
    pcall(c.SetSize, c, perRow * (size + gap), size)
    AuraKit.placeMover(f, perRow * (size + gap) - gap, size)
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
-- Where the combo arc sits: round the portrait, moved by comboX / comboY (dragged in Edit Mode).
function Extras.placeCombo(f)
    local box = f.comboBox
    if not box then return end
    local x, y = getSetting("target", "comboX"), getSetting("target", "comboY")
    if type(x) ~= "number" or type(y) ~= "number" then x, y = 0, 0 end
    box:ClearAllPoints()
    box:SetPoint("CENTER", f.portrait, "CENTER", x, y)
    box:SetSize(f.portrait:GetSize())
end

-- In Edit Mode (rogues, druids): the arc shows, outlined, and can be dragged; dropped, its spot is saved.
function Extras.editCombo(on)
    local f = frames.target
    if not f then return end
    local _, class = UnitClass("player")
    local can = (class == "ROGUE" or class == "DRUID") and getSetting("target", "comboPoints")
    f.comboEditing = (on and can) and true or nil
    pcall(Extras.combo, f)
    local box = f.comboBox
    if not box then return end
    if not box.mover then
        local m = CreateFrame("Frame", nil, box)
        m:SetAllPoints()
        m:SetFrameLevel(box:GetFrameLevel() + 5)
        local t = m:CreateTexture(nil, "OVERLAY")
        t:SetAllPoints(); t:SetColorTexture(0.25, 0.6, 1, 0.3)
        m:EnableMouse(true)
        m:RegisterForDrag("LeftButton")
        m:SetScript("OnDragStart", function() box:SetMovable(true); box:StartMoving() end)
        m:SetScript("OnDragStop", function()
            box:StopMovingOrSizing()
            local bx, by = box:GetCenter()
            local px, py = f.portrait:GetCenter()
            local s = box:GetEffectiveScale() / f:GetEffectiveScale()
            local u = unitData("target", true)
            u.comboX, u.comboY = math.floor(bx * s - px + 0.5), math.floor(by * s - py + 0.5)
            Extras.placeCombo(f)
        end)
        m:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Combo points", 1, 1, 1)
            GameTooltip:AddLine("Drag to move them. Reset the target frame to put them back.", 1, 0.82, 0)
            GameTooltip:Show()
        end)
        m:SetScript("OnLeave", function() GameTooltip:Hide() end)
        box.mover = m
    end
    box.mover:SetShown(f.comboEditing and true or false)
end

function Extras.combo(f)
    local _, class = UnitClass("player")
    local want = (class == "ROGUE" or class == "DRUID") and getSetting("target", "comboPoints")
    -- druids: only in cat form (the form with energy); in Edit Mode, always (to place them)
    if want and class == "DRUID" and not f.comboEditing then
        local ptoken
        pcall(function() ptoken = select(2, UnitPowerType("player")) end)
        if ptoken ~= "ENERGY" then want = false end
    end
    if not want then
        if f.comboBox then f.comboBox:Hide() end
        return
    end
    if not f.comboBox then
        local box = CreateFrame("Frame", nil, f.ov)
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
    Extras.placeCombo(f)
    -- the count goes straight to the pips; fall back to the older API if the first can't be read
    local function fill(v) for _, pip in ipairs(f.comboBox.pips) do pip:SetValue(v) end end
    if not pcall(function() fill(UnitPower("player", Enum.PowerType.ComboPoints)) end) then
        if not pcall(function() fill(GetComboPoints("player", "target")) end) then fill(0) end
    end
    f.comboBox:SetShown((f.comboEditing or UnitExists("target")) and true or false)
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
        ic.tex = ic:CreateTexture(nil, "ARTWORK")
        ic.tex:SetTexture("Interface\\PetPaperDollFrame\\UI-PetHappiness")
        ic:EnableMouse(true)
        ic:SetScript("OnEnter", Extras.happinessTooltip)
        ic:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f.happyIcon = ic
    end
    if not f.happyIcon then return end
    local ic = f.happyIcon
    if coords then
        local p = f.portrait or f
        ic:ClearAllPoints()
        ic.tex:ClearAllPoints(); ic.back:ClearAllPoints()
        if mode == "badge" then
            -- where the player's level badge sits (39px by a 60px portrait), at the portrait's bottom left:
            -- just the face on its dark round backing
            ic:SetSize(24, 24)
            ic:SetPoint("CENTER", p, "BOTTOMLEFT", 5, 3)
            ic.back:SetPoint("TOPLEFT", 3, -3); ic.back:SetPoint("BOTTOMRIGHT", -3, 3)
            ic.back:Show()
            ic.tex:SetPoint("TOPLEFT", 4, -4); ic.tex:SetPoint("BOTTOMRIGHT", -4, 4)
            ic.level = UnitLevel("pet")
        else
            -- the corner spot (the player frame's combat swords: 18px on a 22px backing, by a 60px portrait)
            ic:SetSize(16, 16)
            ic:SetPoint("CENTER", p, "BOTTOMRIGHT", -6, 4)
            ic.back:SetAllPoints()
            ic.back:Show()
            ic.tex:SetPoint("TOPLEFT", 1.5, -1.5); ic.tex:SetPoint("BOTTOMRIGHT", -1.5, 1.5)
            ic.level = nil
        end
        -- Forever's mood icons, or the Classic texture sheet when the client lacks them
        if not (atlas and pcall(ic.tex.SetAtlas, ic.tex, atlas) and ic.tex:GetAtlas()) then
            ic.tex:SetTexture("Interface\\PetPaperDollFrame\\UI-PetHappiness")
            ic.tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        end
        ic.h, ic.dmg, ic.loyalty = h, dmg, loyalty
        ic:Show()
    else
        ic:Hide()
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
    -- the resting Zzz too, when asked (made glow-fit like the resting glow, so a dark frame still
    -- shows it)
    if f.restTex then
        local z = getSetting(f.baseUnit, "restTint") and c
        pcall(f.restTex.SetDesaturated, f.restTex, z and true or false)
        if z then
            f.restTex:SetVertexColor(glowColor(z))
        else
            f.restTex:SetVertexColor(1, 1, 1)
        end
    end
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
-- The picker reports every movement while you drag; the frames are updated with the latest colour at
-- most every 0.1s, and an error can't escape into the picker.
function Extras.openPicker(old, apply)
    local pending, queued
    local function flush()
        queued = nil
        if pending then local c = pending; pending = nil; pcall(apply, c[1], c[2], c[3]) end
    end
    local function later(r, g, b)
        pending = { r, g, b }
        if not queued then queued = true; C_Timer.After(0.1, flush) end
    end
    local info = {
        r = old[1], g = old[2], b = old[3], hasOpacity = false,
        swatchFunc = function() pcall(function() later(ColorPickerFrame:GetColorRGB()) end) end,
        cancelFunc = function() pending = nil; pcall(apply, old[1], old[2], old[3]) end,
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
    -- Threat on target and focus is re-read 5 times a second (as ThreatDisplay does): while you hold
    -- aggro the game sends few or no threat events, so the number would otherwise stand still.
    C_Timer.NewTicker(0.2, function()
        for _, unit in ipairs({ "target", "focus" }) do
            local f = frames[unit]
            if f and f:IsVisible() and getSetting(unit, "threatShow") ~= "off" then pcall(updateThreat, f) end
        end
    end)
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("RAID_TARGET_UPDATE")
    ev:RegisterEvent("PLAYER_TARGET_CHANGED")
    pcall(ev.RegisterUnitEvent, ev, "UNIT_POWER_UPDATE", "player")
    pcall(ev.RegisterUnitEvent, ev, "UNIT_POWER_FREQUENT", "player")
    pcall(ev.RegisterUnitEvent, ev, "UNIT_MAXPOWER", "player")
    pcall(ev.RegisterUnitEvent, ev, "UNIT_DISPLAYPOWER", "player")   -- (a druid shifting in or out of cat form)
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
    -- its art (Retail's or Forever's), for the accent, its black backing and its glow pieces
    local style = getSetting(f.baseUnit, "cornerStyle")
    -- (fine-tuning per style, from /webby corner x y)
    local nudge = getSetting(f.baseUnit, "cornerNudge_" .. tostring(style))
    if type(nudge) ~= "table" then nudge = nil end
    local key = tostring(style) .. (nudge and (" " .. tostring(nudge[1]) .. " " .. tostring(nudge[2])) or "")
    if on and f.cornerStyle ~= key then
        f.cornerStyle = key
        setCornerArt(c, style, nil, nudge)
        -- Retail's black backing: its silhouette, a touch larger, behind it, pinned to its bottom right
        -- so it only shows on the inner side (centred, it ran out over the green frame border too).
        -- Forever's has its rim and line built into the texture instead.
        if f.cornerBack then
            setCornerArt(f.cornerBack, style, 1.07, nudge)
            f.cornerBack:SetVertexColor(0, 0, 0, 1)
            f.cornerBack:ClearAllPoints()
            f.cornerBack:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT")
        end
        for _, g in ipairs(f.cornerGlowTex or {}) do setCornerArt(g[1], style, g[2], nudge) end
    end
    c:SetShown(on)
    if f.cornerBack then f.cornerBack:SetShown(on and style ~= "forever") end
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

-- Whether a frame is used at all ("Show" on the General page and the frame's page). The player and
-- target frames always are. A frame that's off has its unit watch removed and stays hidden (only ever
-- changed out of combat: settings changes wait for it).
local ALWAYS_SHOWN = { player = true, target = true }
local function frameOn(unit)
    return ALWAYS_SHOWN[unit] or getSetting(unit, "frameShown") ~= false
end

local function applyShown(f)
    local unit = f.baseUnit
    if ALWAYS_SHOWN[unit] then return end
    local on = frameOn(unit)
    if on == (f.wfOff ~= true) then return end
    f.wfOff = not on
    if on then
        RegisterUnitWatch(f)
    else
        UnregisterUnitWatch(f)
        f:Hide()
    end
end

-- The druid mana bar's spot: under the frame art by default, or wherever it was dragged in Edit Mode
-- (druidManaX / Y: its top left from the player frame's top left).
local ALT_MANA_AT = { 85, -74 }
local function placeAltMana(f)
    local am = f.altMana
    if not am then return end
    local x, y = getSetting("player", "druidManaX"), getSetting("player", "druidManaY")
    if type(x) ~= "number" or type(y) ~= "number" then x, y = ALT_MANA_AT[1], ALT_MANA_AT[2] end
    am:ClearAllPoints()
    am:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
end

-- In Edit Mode (druids): the bar shows, outlined, and can be dragged; dropped, its spot is saved.
local function editAltMana(on)
    local f = frames.player
    local am = f and f.altMana
    if not am then return end
    local druid = select(2, UnitClass("player")) == "DRUID" and getSetting("player", "druidMana")
    if not am.mover then
        local m = CreateFrame("Frame", nil, am)
        m:SetPoint("TOPLEFT", -2, 2); m:SetPoint("BOTTOMRIGHT", 2, -2)
        m:SetFrameLevel(am:GetFrameLevel() + 5)
        local t = m:CreateTexture(nil, "OVERLAY")
        t:SetAllPoints(); t:SetColorTexture(0.25, 0.6, 1, 0.35)
        m:EnableMouse(true)
        m:RegisterForDrag("LeftButton")
        m:SetScript("OnDragStart", function() am:SetMovable(true); am:StartMoving() end)
        m:SetScript("OnDragStop", function()
            am:StopMovingOrSizing()
            local s = am:GetEffectiveScale() / f:GetEffectiveScale()
            local x = am:GetLeft() * s - f:GetLeft()
            local y = am:GetTop() * s - f:GetTop()
            local u = unitData("player", true)
            u.druidManaX, u.druidManaY = math.floor(x + 0.5), math.floor(y + 0.5)
            placeAltMana(f)
        end)
        m:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Druid mana", 1, 1, 1)
            GameTooltip:AddLine("Drag to move it. Reset the player frame to put it back.", 1, 0.82, 0)
            GameTooltip:Show()
        end)
        m:SetScript("OnLeave", function() GameTooltip:Hide() end)
        am.mover = m
    end
    am.mover:SetShown(on and druid and true or false)
    if on and druid then am:Show() else pcall(updatePower, f) end
end

local function applyUnit(f)
    local unit = f.baseUnit
    applyShown(f)
    if f.altMana then placeAltMana(f) end
    local changed = applyLayout(f)
    if f.small and applySmallLayout(f) then changed = true end
    placeFrame(f, unit)
    f:SetScale(getSetting(unit, "scale"))
    local showName = (unit == "player" or getSetting(unit, "showName")) and true or false   -- (your own name always)
    f.name:SetShown(showName)
    if f.plate then f.plate:SetShown(showName and not f.layoutLeft) end
    applyCorner(f)
    placeIndicators(f)
    pcall(applyFont, f)
    pcall(updateInfo, f)          -- name colour and portrait style
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
    createDamageTrail(f)
    -- the player's druid mana while in a form: a slim bar just under the frame art, below the mana
    -- bar, in the frames' line style (shown by updatePower)
    if isPlayer then
        local am = CreateFrame("Frame", nil, f)
        am:SetPoint("TOPLEFT", f, "TOPLEFT", 85, -74)      -- (moved to its saved spot by placeAltMana)
        am:SetSize(124, 8)
        am:SetFrameLevel(f:GetFrameLevel() + 2)
        local line = am:CreateTexture(nil, "BACKGROUND", nil, 0)
        line:SetAllPoints(); line:SetColorTexture(0.55, 0.55, 0.55, 1)
        local inside = am:CreateTexture(nil, "BACKGROUND", nil, 1)
        inside:SetPoint("TOPLEFT", 1, -1); inside:SetPoint("BOTTOMRIGHT", -1, 1)
        inside:SetColorTexture(0.05, 0.05, 0.05, 0.9)
        am.bar = CreateFrame("StatusBar", nil, am)
        am.bar:SetPoint("TOPLEFT", 1, -1); am.bar:SetPoint("BOTTOMRIGHT", -1, 1)
        am.bar:SetStatusBarTexture(BAR_FILE.player .. "Mana")
        am.bar:SetMinMaxValues(0, 1)
        am.text = am.bar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        am.text:SetPoint("CENTER")
        pcall(function() local fp = am.text:GetFont(); am.text:SetFont(fp or STANDARD_TEXT_FONT, 8, "OUTLINE") end)
        am:Hide()
        f.altMana = am
        -- spell cost prediction (shown by updateCostPrediction while you cast)
        -- (both inside a frame that clips to the power bar, so neither can spill past its ends)
        local clip = CreateFrame("Frame", nil, f.mp)
        clip:SetAllPoints(f.mp)
        clip:SetFrameLevel(f.mp:GetFrameLevel() + 1)
        clip:SetClipsChildren(true)
        f.costBar = CreateFrame("StatusBar", nil, clip)
        f.costBar:SetReverseFill(true)
        f.costBar:Hide()
        -- the spent flash (flashSpent), fading out
        f.spentBar = CreateFrame("StatusBar", nil, clip)
        f.spentBar:Hide()
        f.spentBar:SetScript("OnUpdate", function(self, elapsed)
            self.left = (self.left or 0) - elapsed
            if self.left <= 0 then self:Hide(); return end
            self:SetAlpha(self.left / SPENT_FADE)
        end)
        for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
                             "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_SUCCEEDED" }) do
            pcall(f.RegisterUnitEvent, f, e, "player")
        end
    end

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
        f.restTex = tex      -- (Extras.tint colours it when "Colour the Zzz" is on)
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
        if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
            updateHealth(self)
            -- a spell on its way has landed (see flyDamage)
            if event == "UNIT_HEALTH" then self.hitAt = GetTime(); if self.dmgFlying then landDamage(self) end end
        elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then updatePower(self)
        elseif event == "PLAYER_UPDATE_RESTING" then
            if self.updateRest then self.updateRest() end
            updateIndicators(self)
        elseif event == "UNIT_SPELLCAST_START" then
            local _, guid, spellID = ...
            self.castSpell, self.castGUID = spellID, guid
            self.costStarts = (self.costStarts or 0) + 1   -- (for /webby cost)
            pcall(updateCostPrediction, self)
            -- the damage it will do, on your target (and on focus when that's the same mob)
            pcall(updateDamagePrediction, frames.target, spellID)
            local same = false
            pcall(function() same = UnitIsUnit("focus", "target") and true or false end)
            pcall(updateDamagePrediction, frames.focus, same and spellID or nil)
        elseif event:find("^UNIT_SPELLCAST_") then
            -- went off (cast or instant, however it was pressed): flash what it spent
            if event == "UNIT_SPELLCAST_SUCCEEDED" then local _, _, spellID = ...; pcall(flashSpent, self, spellID) end
            -- only the cast being shown ends it (a failed second spell mid-cast leaves it alone)
            local _, guid = ...
            local mine = true
            pcall(function() mine = (guid == self.castGUID) end)
            if mine then
                local spell = self.castSpell
                self.castSpell, self.castGUID = nil, nil
                pcall(updateCostPrediction, self)
                if event == "UNIT_SPELLCAST_SUCCEEDED" then
                    pcall(flyDamage, spell)                  -- on its way: stays until it lands
                else
                    pcall(updateDamagePrediction, frames.target, nil)
                    pcall(updateDamagePrediction, frames.focus, nil)
                end
            end
        elseif event == "PLAYER_REGEN_DISABLED" then self.combatFlag = true; updateIndicators(self)
        elseif event == "PLAYER_REGEN_ENABLED" then self.combatFlag = false; updateIndicators(self)
        elseif event == "PLAYER_FLAGS_CHANGED" or event == "UNIT_FLAGS" then updateIndicators(self)
        elseif event:find("^UNIT_THREAT") then updateThreat(self)
        elseif event == "UNIT_AURA" then safely(updateAuras, self)
        elseif event == "UNIT_COMBAT" then
            local _, action, indicator, amount = ...; pcall(showHit, self, action, indicator, amount)
            -- the spell landed (or missed): its next combat event after the cast
            self.hitAt = GetTime()
            if self.dmgFlying then landDamage(self) end
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
    createDamageTrail(f)

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
        if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
            updateHealth(self)
            -- a spell on its way has landed (see flyDamage)
            if event == "UNIT_HEALTH" then self.hitAt = GetTime(); if self.dmgFlying then landDamage(self) end end
        elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then updatePower(self)
        elseif event == "UNIT_AURA" then safely(updateAuras, self)
        elseif event == "UNIT_COMBAT" then
            local _, action, indicator, amount = ...; pcall(showHit, self, action, indicator, amount)
            -- the spell landed (or missed): its next combat event after the cast
            self.hitAt = GetTime()
            if self.dmgFlying then landDamage(self) end
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
        if frames[unit] and frameOn(unit) then list[#list + 1] = frames[unit] end   -- (frames turned off stay hidden)
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
    pcall(editAltMana, true)       -- the druid mana bar, to drag
    pcall(Extras.editCombo, true)  -- and the combo points
end

local function exitSample()
    AuraKit.setEditing(false)
    pcall(editAltMana, false)
    pcall(Extras.editCombo, false)
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

-- EllesmereUI's Unlock Mode: the frames can be dragged there too. Positions are saved in the same
-- place as Edit Mode's (this Edit Mode layout), so either one works and they agree. Ellesmere doesn't
-- anchor or reapply them itself (ownsPosition), so it never moves a secure frame in combat.
local ellesmereDone = false
local function setupEllesmere()
    local E = rawget(_G, "EllesmereUI")
    if ellesmereDone or type(E) ~= "table" or type(E.RegisterUnlockElements) ~= "function" then return end
    ellesmereDone = true
    -- a frame's spot as CENTER offsets from the screen's centre, in the frame's own scale
    local function centerOffset(f)
        local cx, cy = f:GetCenter()
        if not cx then return nil end
        local k = UIParent:GetEffectiveScale() / f:GetEffectiveScale()
        local ux, uy = UIParent:GetCenter()
        return cx - ux * k, cy - uy * k
    end
    local list = {}
    for i, unit in ipairs(UNITS) do
        local f = frames[unit]
        if f then
            list[#list + 1] = {
                key = "WebbyFrames_" .. unit,
                label = "Webby " .. UNIT_LABEL[unit] .. " Frame",
                order = 500 + i,
                ownsPosition = true, noAnchorTo = true, noResize = true, noSizeMatchTarget = true,
                getFrame = function() return f end,
                loadPosition = function()
                    local x, y = centerOffset(f)
                    if not x then return nil end
                    return { point = "CENTER", relPoint = "CENTER", x = x, y = y }
                end,
                savePosition = function(_, point, relPoint, x, y)
                    if InCombatLockdown() or type(x) ~= "number" or type(y) ~= "number" then return end
                    if type(relPoint) ~= "string" then relPoint = point end
                    f:ClearAllPoints()
                    f:SetPoint(point or "CENTER", UIParent, relPoint or "CENTER", x, y)
                    local cx, cy = centerOffset(f)
                    if not cx then return end
                    local u = unitData(unit, true)
                    u.point, u.x, u.y = "CENTER", cx, cy
                    pcall(updateAttachment, f, unit, activeLayout)   -- sticky frames work here too
                    pcall(placeFrame, f, unit)
                end,
                clearPosition = function()
                    if InCombatLockdown() then return end
                    local u = unitData(unit, true)
                    u.point, u.x, u.y, u.attach, u.ax, u.ay = nil, nil, nil, nil, nil, nil
                    pcall(placeFrame, f, unit)
                end,
                applyPosition = function()
                    if not InCombatLockdown() then pcall(placeFrame, f, unit) end
                end,
            }
        end
    end
    pcall(E.RegisterUnlockElements, E, list, "WebbyFrames")
    -- target, focus and the rest show the player as a stand-in while Unlock Mode is open, as in Edit Mode
    if type(E.RegisterUnlockModeListener) == "function" then
        pcall(E.RegisterUnlockModeListener, E, "WebbyFrames", function(active)
            if active then enterSample() else exitSample() end
        end)
    end
end

---------------------------------------------------------------------------
-- Actions used by the settings pages and slash commands
---------------------------------------------------------------------------
local COPY_KEYS = { "scale", "showName", "textMode", "textFormat", "barTexture", "powerTexture", "font", "threatShow", "threatStyle", "threatColors",
                    "auraBuffs", "auraDebuffs", "auraMine", "auraSize", "auraDebuffSize", "auraPerRow", "auraMax", "auraPos", "auraTimer",
                    "castShow", "castText", "castIcon", "smoothBars", "healPrediction", "absorbs", "damageTrail", "damagePredict",
                    "colorMode", "healthFade", "frameTint", "frameColor", "petHappy", "petColor", "comboPoints", "npcColor", "npcColorRGB",
                    "fadeStyle", "fadeBlend", "fade1Pct", "fade1Color", "fade2Pct", "fade2Color", "fade3Pct", "fade3Color",
                    "auraGap", "auraGrowth", "auraStack", "nameSize", "nameColor", "nameColorRGB",
                    "textSize", "textColor", "textColorRGB", "textAnchor", "portraitStyle" }

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
-- Settings window (/webby): a window of its own, with the pages on the left (General, All frames, one
-- per frame) and the page's options on the right in collapsible sections. Being an ordinary frame, it
-- can stay open while you play, target things or use Edit Mode. Esc > Options > AddOns > Webby Frames
-- only describes the addon and has a button that opens this window.
---------------------------------------------------------------------------
local Opt = { pages = {}, order = {}, ROW_H = 28, LABEL_X = 16, CONTROL_X = 300, CONTROL_W = 240, CONTENT_W = 580, MENU_ROWS = 14 }

local function addonVersion()
    local v
    pcall(function() v = C_AddOns.GetAddOnMetadata("WebbyFrames", "Version") end)
    return v or "?"
end

function Opt.tip(frame, title, tip)
    if not tip then return end
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText(title or "", 1, 1, 1)
        GameTooltip:AddLine(tip, 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- A plain check box made from textures (nothing depends on a template this client may not have).
function Opt.newCheck(parent)
    local cb = CreateFrame("CheckButton", nil, parent)
    cb:SetSize(26, 26)
    cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    pcall(cb.SetDisabledCheckedTexture, cb, "Interface\\Buttons\\UI-CheckBox-Check-Disabled")
    return cb
end

function Opt.dark(frame, edge)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    frame:SetBackdropColor(0, 0, 0, 0.6)
    frame:SetBackdropBorderColor(edge or 0.4, edge or 0.4, edge or 0.4, 1)
end

-- The open dropdown's list (one, shared by every dropdown). Long lists scroll with the mouse wheel;
-- a click anywhere else closes it.
function Opt.closeMenu() if Opt.menu then Opt.menu:Hide() end end

function Opt.openMenu(owner, choices, current, pick)
    local m = Opt.menu
    if not m then
        m = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        Opt.menu = m
        m:SetFrameStrata("FULLSCREEN_DIALOG")
        m:SetClampedToScreen(true)
        m:EnableMouse(true)
        m:EnableMouseWheel(true)
        m:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        m:SetBackdropColor(0.06, 0.06, 0.06, 0.97)
        m.buttons = {}
        for i = 1, Opt.MENU_ROWS do
            local b = CreateFrame("Button", nil, m)
            b:SetHeight(20)
            b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 20)
            b:SetPoint("RIGHT", m, "RIGHT", -6, 0)
            b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            b.check = b:CreateTexture(nil, "ARTWORK")
            b.check:SetSize(16, 16)
            b.check:SetPoint("LEFT", 2, 0)
            b.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            b.text:SetPoint("LEFT", 22, 0)
            b.text:SetPoint("RIGHT", -4, 0)
            b.text:SetJustifyH("LEFT")
            pcall(b.text.SetWordWrap, b.text, false)
            b:SetScript("OnClick", function(self)
                m:Hide()
                if self.value ~= nil and m.pick then m.pick(self.value) end
            end)
            m.buttons[i] = b
        end
        m.more = m:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        m.more:SetPoint("BOTTOMRIGHT", -8, 4)
        function m:Fill()
            local n = #self.choices
            for i, b in ipairs(self.buttons) do
                local c = self.choices[self.offset + i]
                b:SetShown(c ~= nil)
                if c then
                    b.value = c[1]
                    b.text:SetText(c[2] or tostring(c[1]))
                    b.check:SetShown(c[1] == self.current)
                end
            end
            local more = n > Opt.MENU_ROWS
            self.more:SetText(more and string.format("%d-%d of %d, scroll for more", self.offset + 1, math.min(n, self.offset + Opt.MENU_ROWS), n) or "")
            self:SetHeight(math.min(n, Opt.MENU_ROWS) * 20 + 12 + (more and 14 or 0))
        end
        m:SetScript("OnMouseWheel", function(self, delta)
            self.offset = math.max(0, math.min(#self.choices - Opt.MENU_ROWS, self.offset - delta * 3))
            self:Fill()
        end)
        pcall(m.RegisterEvent, m, "GLOBAL_MOUSE_DOWN")
        m:SetScript("OnEvent", function(self)
            if self:IsShown() and not self:IsMouseOver() and not (self.owner and self.owner:IsMouseOver()) then self:Hide() end
        end)
    end
    m.owner, m.choices, m.current, m.pick = owner, choices or {}, current, pick
    m.offset = 0
    for i, c in ipairs(m.choices) do
        if c[1] == current then m.offset = math.max(0, math.min(#m.choices - Opt.MENU_ROWS, i - math.floor(Opt.MENU_ROWS / 2))) end
    end
    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    m:SetWidth(math.max(owner:GetWidth(), 240))
    m:Fill()
    m:Show()
    m:Raise()
end

-- Greys a row out (and stops its controls taking clicks) while what it depends on is off.
function Opt.setRowEnabled(row, on)
    if row.enabled == on then return end
    row.enabled = on
    for _, c in ipairs(row.controls or {}) do
        if c.SetEnabled then pcall(c.SetEnabled, c, on)
        elseif on and c.Enable then pcall(c.Enable, c)
        elseif c.Disable then pcall(c.Disable, c) end
        if c.EnableMouse then pcall(c.EnableMouse, c, on) end
    end
    for _, t in ipairs(row.texts or {}) do
        if on then t:SetTextColor(1, 1, 1) else t:SetTextColor(0.5, 0.5, 0.5) end
    end
end

function Opt.newPage(id, name)
    local page = { id = id, name = name, rows = {} }
    Opt.pages[id] = page
    Opt.order[#Opt.order + 1] = id
    return page
end

-- Redraws the shown page: which rows show (closed sections and B.showIf hide them), where they sit,
-- which are greyed out (B.under) and what each control shows. Cheap enough to run on every change.
local layoutErrorShown = false
function Opt.layout()
    local w = Opt.window
    if not (w and w:IsShown()) then return end
    local page = Opt.pages[Opt.current]
    if not page then return end
    if not page.content then
        page.content = CreateFrame("Frame", nil, Opt.scroll)
        page.content:SetSize(Opt.CONTENT_W, 10)
        for _, row in ipairs(page.rows) do
            local f = CreateFrame("Frame", nil, page.content)
            f:SetHeight(row.height)
            row.frame = f
            local ok, err = pcall(row.make, f, row)
            if not ok and not layoutErrorShown then
                layoutErrorShown = true
                print("|cffff9900Webby Frames:|r an options row couldn't be drawn: " .. tostring(err))
            end
        end
    end
    for _, p in pairs(Opt.pages) do
        if p.content then p.content:SetShown(p == page) end
    end
    if Opt.scroll:GetScrollChild() ~= page.content then
        Opt.scroll:SetScrollChild(page.content)
        Opt.scroll:SetVerticalScroll(0)
    end
    local y = 6
    for _, row in ipairs(page.rows) do
        local shown = not row.section or row.section.expanded
        if shown then
            for _, pred in ipairs(row.preds) do
                local ok, v = pcall(pred)
                if not (ok and v) then shown = false; break end
            end
        end
        row.frame:SetShown(shown)
        if shown then
            row.frame:ClearAllPoints()
            row.frame:SetPoint("TOPLEFT", page.content, "TOPLEFT", 0, -y)
            row.frame:SetPoint("RIGHT", page.content, "RIGHT")
            y = y + row.height
            local on = true
            if row.enabledIf then
                local ok, v = pcall(row.enabledIf)
                on = ok and v and true or false
            end
            if row.parentRow and row.parentRow.enabled == false then on = false end
            Opt.setRowEnabled(row, on)
            if row.refresh then
                row.updating = true
                pcall(row.refresh)
                row.updating = false
            end
        end
    end
    page.content:SetHeight(y + 10)
    -- (the plain scroll frame doesn't keep its position inside the new height by itself)
    local max = math.max(0, y + 10 - Opt.scroll:GetHeight())
    if Opt.scroll:GetVerticalScroll() > max then Opt.scroll:SetVerticalScroll(max) end
    for id, b in pairs(Opt.navButtons or {}) do b.selected:SetShown(id == Opt.current) end
end

-- After a change: redraw once, on the next frame (several settings can change in one click).
function Opt.changed()
    if Opt.pendingLayout then return end
    Opt.pendingLayout = true
    C_Timer.After(0, function() Opt.pendingLayout = false; Opt.layout() end)
end

function Opt.select(id)
    if not Opt.pages[id] then id = "general" end
    Opt.current = id
    Opt.closeMenu()
    Opt.layout()
end

function Opt.buildWindow()
    if Opt.window then return Opt.window end
    local w = CreateFrame("Frame", "WebbyFramesOptions", UIParent, "BackdropTemplate")
    Opt.window = w
    w:Hide()
    w:SetSize(820, 600)
    local pos = DB and DB.optionsPos
    if type(pos) == "table" and pos[1] then w:SetPoint(pos[1], UIParent, pos[2] or pos[1], pos[3] or 0, pos[4] or 0)
    else w:SetPoint("CENTER") end
    w:SetFrameStrata("HIGH")
    w:SetToplevel(true)
    w:SetClampedToScreen(true)
    w:SetMovable(true)
    w:EnableMouse(true)
    w:RegisterForDrag("LeftButton")
    w:SetScript("OnDragStart", w.StartMoving)
    w:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        if DB then DB.optionsPos = { p, rp, x, y } end
    end)
    w:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
    tinsert(UISpecialFrames, "WebbyFramesOptions")     -- (Esc closes it)

    local title = w:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 22, -18)
    title:SetText("Webby Frames  |cff808080v" .. addonVersion() .. "|r")
    local close = CreateFrame("Button", nil, w, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    -- the page list
    local nav = CreateFrame("Frame", nil, w, "BackdropTemplate")
    nav:SetPoint("TOPLEFT", 16, -44)
    nav:SetPoint("BOTTOMLEFT", 16, 16)
    nav:SetWidth(160)
    Opt.dark(nav, 0.25)
    Opt.navButtons = {}
    for i, id in ipairs(Opt.order) do
        local page = Opt.pages[id]
        local b = CreateFrame("Button", nil, nav)
        b:SetHeight(22)
        b:SetPoint("TOPLEFT", 4, -6 - (i - 1) * 24)
        b:SetPoint("RIGHT", nav, "RIGHT", -4, 0)
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        b.selected = b:CreateTexture(nil, "BACKGROUND")
        b.selected:SetAllPoints()
        b.selected:SetColorTexture(1, 0.82, 0, 0.18)
        b.selected:Hide()
        local fs = b:CreateFontString(nil, "OVERLAY", (id == "general" or id == "all") and "GameFontNormal" or "GameFontHighlight")
        fs:SetPoint("LEFT", (id == "general" or id == "all") and 8 or 18, 0)
        fs:SetText(page.name)
        b:SetScript("OnClick", function() Opt.select(id) end)
        Opt.navButtons[id] = b
    end

    -- the page itself, scrolling
    local area = CreateFrame("Frame", nil, w, "BackdropTemplate")
    area:SetPoint("TOPLEFT", nav, "TOPRIGHT", 8, 0)
    area:SetPoint("BOTTOMRIGHT", -16, 16)
    Opt.dark(area, 0.25)
    local ok, scroll = pcall(CreateFrame, "ScrollFrame", "WebbyFramesOptionsScroll", area, "UIPanelScrollFrameTemplate")
    if not ok then
        scroll = CreateFrame("ScrollFrame", nil, area)
        scroll:EnableMouseWheel(true)
        scroll:SetScript("OnMouseWheel", function(self, delta)
            local child = self:GetScrollChild()
            local max = math.max(0, (child and child:GetHeight() or 0) - self:GetHeight())
            self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - delta * 40)))
        end)
    end
    scroll:SetPoint("TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", -26, 4)
    Opt.scroll = scroll
    Opt.CONTENT_W = 820 - 16 - 160 - 8 - 16 - 4 - 26

    w:SetScript("OnShow", function() Opt.layout() end)
    w:SetScript("OnHide", function() Opt.closeMenu(); GameTooltip:Hide() end)
    -- picks up changes made elsewhere (Edit Mode's dialogs, a layout switch), but not mid-drag
    local elapsed = 0
    w:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < 1 then return end
        elapsed = 0
        if not (IsMouseButtonDown and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton"))) then Opt.layout() end
    end)
    return w
end

function openSettings(unit)
    local ok, err = pcall(Opt.buildWindow)
    if not ok then
        print("|cffff9900Webby Frames:|r the settings window couldn't be made: " .. tostring(err))
        return
    end
    pcall(function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    end)
    Opt.window:Show()
    Opt.window:Raise()
    Opt.select((unit and Opt.pages[unit]) and unit or Opt.current or "general")
end

function Opt.toggle()
    if Opt.window and Opt.window:IsShown() then Opt.window:Hide() else openSettings() end
end

-- Esc > Options > AddOns > Webby Frames: what the addon is, and a button to the settings window.
function Opt.buildAddOnsPage()
    local p = CreateFrame("Frame")
    p.name = "Webby Frames"
    local title = p:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Webby Frames")
    local sub = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    sub:SetText("|cff808080v" .. addonVersion() .. "  -  by Webby, Lexible & Dranged|r")
    local desc = p:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -16)
    desc:SetWidth(560)
    desc:SetJustifyH("LEFT")
    desc:SetText("Retail-style player, target, target of target, focus, focus target and pet frames for WoW Forever, drawn from Blizzard's own unit frame art.\n\n"
        .. "Health and power bars with your choice of textures, fonts and colours, buffs and debuffs, cast bars, threat, incoming heals and shields, "
        .. "spell cost and damage previews, and combat numbers on the portraits.\n\n"
        .. "Move the frames in Edit Mode. Every other option is in the Webby Frames settings window.")
    local open = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    open:SetSize(240, 28)
    open:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -20)
    open:SetText("Open Webby Frames settings")
    open:SetScript("OnClick", function() openSettings() end)
    local edit = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    edit:SetSize(160, 28)
    edit:SetPoint("LEFT", open, "RIGHT", 10, 0)
    edit:SetText("Open Edit Mode")
    edit:SetScript("OnClick", openEditMode)
    local hint = p:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    hint:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -12)
    hint:SetText("You can also type /webby, or click the Webby Frames minimap button.")
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local cat = Settings.RegisterCanvasLayoutCategory(p, "Webby Frames")
        Settings.RegisterAddOnCategory(cat)
        settingsCategory = cat
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(p)
    end
end

-- The minimap button (LibDBIcon, so minimap button collectors can take it): click for the settings,
-- right-click for Edit Mode. Its position and whether it shows are kept in WebbyFramesDB.minimap.
function Opt.setupMinimap()
    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    local DBI = LibStub and LibStub("LibDBIcon-1.0", true)
    if not (LDB and DBI) then return end
    if type(DB.minimap) ~= "table" then DB.minimap = { hide = false } end
    local launcher = LDB:NewDataObject("WebbyFrames", {
        type = "launcher",
        text = "Webby Frames",
        icon = "Interface\\Icons\\Spell_Nature_Web",
        OnClick = function(_, button)
            if button == "RightButton" then openEditMode() else Opt.toggle() end
        end,
        OnTooltipShow = function(tt)
            tt:AddLine("Webby Frames")
            tt:AddLine("|cffffd100Click|r to open the settings", 1, 1, 1)
            tt:AddLine("|cffffd100Right-click|r to open Edit Mode", 1, 1, 1)
            tt:AddLine("|cffffd100Drag|r to move this button", 1, 1, 1)
        end,
    })
    DBI:Register("WebbyFrames", launcher, DB.minimap)
    Opt.DBI = DBI
end

function Opt.setMinimapShown(on)
    if type(DB.minimap) ~= "table" then DB.minimap = {} end
    DB.minimap.hide = not on
    if Opt.DBI then
        if on then Opt.DBI:Show("WebbyFrames") else Opt.DBI:Hide("WebbyFrames") end
    end
end

local function buildSettings()
    -- Small builders; every setting reads and writes through a proxy table. Each adds a row to the
    -- page; the rows are only made when the page is first shown. B.section starts a collapsible
    -- section: the rows added after it only show while it is open.
    local function builders(page, proxy)
        local B = {}
        local current
        local L, CX, CW = Opt.LABEL_X, Opt.CONTROL_X, Opt.CONTROL_W
        local function add(row)
            row.section = current
            row.preds = {}
            row.height = row.height or Opt.ROW_H
            page.rows[#page.rows + 1] = row
            return row
        end
        local function get(key, default)
            local v = proxy[key]
            if v == nil then v = default end
            return v
        end
        -- (switches and dropdowns can have options that depend on them: redraw the page after)
        local function set(key, v, redraw)
            proxy[key] = v
            if redraw then Opt.changed() end
        end
        local function label(f, row, text, tip)
            local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            fs:SetPoint("LEFT", L + 20 + 18 * (row.indent or 0), 0)
            fs:SetPoint("RIGHT", f, "LEFT", CX - 10, 0)
            fs:SetJustifyH("LEFT")
            pcall(fs.SetWordWrap, fs, false)
            fs:SetText(text)
            row.texts = { fs }
            f:EnableMouse(true)
            Opt.tip(f, text, tip)
            return fs
        end
        function B.header(text)
            current = nil
            local small = text:find("^|cff808080") ~= nil
            return add({ height = small and 22 or 36, make = function(f)
                local fs = f:CreateFontString(nil, "OVERLAY", small and "GameFontHighlightSmall" or "GameFontHighlightLarge")
                fs:SetPoint("BOTTOMLEFT", L, small and 4 or 8)
                fs:SetPoint("RIGHT", -L, 0)
                fs:SetJustifyH("LEFT")
                fs:SetText(text)
            end })
        end
        function B.section(text, open)
            local sec = { expanded = open and true or false }
            current = nil
            add({ height = 32, make = function(f, row)
                local b = CreateFrame("Button", nil, f, "BackdropTemplate")
                b:SetPoint("TOPLEFT", 6, -4)
                b:SetPoint("BOTTOMRIGHT", -6, 2)
                b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
                b:SetBackdropColor(1, 1, 1, 0.07)
                b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
                local icon = b:CreateTexture(nil, "ARTWORK")
                icon:SetSize(16, 16)
                icon:SetPoint("LEFT", 8, 0)
                local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                fs:SetPoint("LEFT", icon, "RIGHT", 8, 0)
                fs:SetText(text)
                b:SetScript("OnClick", function()
                    sec.expanded = not sec.expanded
                    pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
                    Opt.layout()
                end)
                row.refresh = function()
                    icon:SetTexture(sec.expanded and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
                end
            end })
            current = sec
        end
        function B.check(key, text, tip, default)
            return add({ make = function(f, row)
                label(f, row, text, tip)
                local cb = Opt.newCheck(f)
                cb:SetPoint("LEFT", CX, 0)
                cb:SetScript("OnClick", function(self) set(key, self:GetChecked() and true or false, true) end)
                Opt.tip(cb, text, tip)
                row.controls = { cb }
                row.refresh = function() cb:SetChecked(get(key, default) and true or false) end
            end })
        end
        -- Two checkboxes on one row: a and b are { key, label, tip, default } (b may be nil).
        function B.pair(a, b)
            return add({ make = function(f, row)
                row.controls, row.texts = {}, {}
                local boxes = {}
                for i, d in ipairs({ a, b }) do
                    local cb = Opt.newCheck(f)
                    cb:SetPoint("LEFT", i == 1 and (L + 18 * (row.indent or 0)) or (CX - 10), 0)
                    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                    fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
                    fs:SetText(d[2])
                    cb:SetScript("OnClick", function(self) set(d[1], self:GetChecked() and true or false, true) end)
                    Opt.tip(cb, d[2], d[3])
                    row.controls[#row.controls + 1] = cb
                    row.texts[#row.texts + 1] = fs
                    boxes[#boxes + 1] = { cb, d }
                end
                row.refresh = function()
                    for _, x in ipairs(boxes) do x[1]:SetChecked(get(x[2][1], x[2][4]) and true or false) end
                end
            end })
        end
        -- A colour row: label and a swatch of the colour, which opens the colour picker when clicked.
        -- getc() -> { r, g, b }; setc(r, g, b).
        function B.swatch(text, getc, setc, tip)
            return add({ make = function(f, row)
                label(f, row, text, tip)
                local b = CreateFrame("Button", nil, f, "BackdropTemplate")
                b:SetSize(22, 22)
                b:SetPoint("LEFT", CX + 2, 0)
                Opt.dark(b, 0.6)
                b:SetBackdropColor(0, 0, 0, 1)
                local tex = b:CreateTexture(nil, "ARTWORK")
                tex:SetPoint("TOPLEFT", 3, -3)
                tex:SetPoint("BOTTOMRIGHT", -3, 3)
                b:SetScript("OnClick", function()
                    local c = getc() or { 1, 1, 1 }
                    Extras.openPicker({ c[1] or 1, c[2] or 1, c[3] or 1 }, function(r, g, bl)
                        setc(r, g, bl)
                        tex:SetColorTexture(r, g, bl, 1)
                    end)
                end)
                Opt.tip(b, text, tip)
                row.controls = { b }
                row.refresh = function()
                    local c = getc() or { 1, 1, 1 }
                    tex:SetColorTexture(c[1] or 1, c[2] or 1, c[3] or 1, 1)
                end
            end })
        end
        function B.slider(key, text, tip, default, lo, hi, step, fmt)
            fmt = fmt or function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end
            local function snap(v)
                v = math.floor((v - lo) / step + 0.5) * step + lo
                return math.max(lo, math.min(hi, v))
            end
            return add({ make = function(f, row)
                label(f, row, text, tip)
                local s = CreateFrame("Slider", nil, f, "BackdropTemplate")
                s:SetOrientation("HORIZONTAL")
                s:SetSize(150, 17)
                s:SetPoint("LEFT", CX + 22, 0)
                s:SetBackdrop({ bgFile = "Interface\\Buttons\\UI-SliderBar-Background", edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
                    tile = true, tileSize = 8, edgeSize = 8, insets = { left = 3, right = 3, top = 6, bottom = 6 } })
                s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
                s:SetMinMaxValues(lo, hi)
                s:SetValueStep(step)
                pcall(s.SetObeyStepOnDrag, s, true)
                local val = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                local function stepper(dir)
                    local b = CreateFrame("Button", nil, f)
                    b:SetSize(20, 20)
                    local name = dir < 0 and "Prev" or "Next"
                    b:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. name .. "Page-Up")
                    b:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. name .. "Page-Down")
                    b:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. name .. "Page-Disabled")
                    b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
                    b:SetScript("OnClick", function() s:SetValue(snap(s:GetValue() + dir * step)) end)
                    return b
                end
                local prev, nxt = stepper(-1), stepper(1)
                prev:SetPoint("RIGHT", s, "LEFT", -1, 0)
                nxt:SetPoint("LEFT", s, "RIGHT", 1, 0)
                val:SetPoint("LEFT", nxt, "RIGHT", 4, 0)
                s:SetScript("OnValueChanged", function(_, v)
                    v = snap(v)
                    val:SetText(fmt(v))
                    if not row.updating then set(key, v) end
                end)
                s:EnableMouseWheel(false)
                Opt.tip(s, text, tip)
                row.controls = { s, prev, nxt }
                row.texts[#row.texts + 1] = val
                row.refresh = function()
                    local v = tonumber(get(key, default)) or default or lo
                    s:SetValue(v)
                    val:SetText(fmt(snap(v)))
                end
            end })
        end
        -- Indents controls under the one they depend on and greys them out while isOn() is false.
        function B.under(parent, isOn, ...)
            for _, r in ipairs({ ... }) do
                if r and parent then
                    r.indent = (parent.indent or 0) + 1
                    r.enabledIf = isOn
                    r.parentRow = parent
                end
            end
        end
        -- Shows controls only while isOn() is true (hidden rather than greyed).
        function B.showIf(isOn, ...)
            for _, r in ipairs({ ... }) do
                if r then r.preds[#r.preds + 1] = isOn end
            end
        end
        -- choices: { { value, label }, ... }, or a function returning that (read each time it opens).
        function B.dropdown(key, text, tip, default, choices)
            local function list() return (type(choices) == "function" and choices() or choices) or {} end
            return add({ make = function(f, row)
                label(f, row, text, tip)
                local b = CreateFrame("Button", nil, f, "BackdropTemplate")
                b:SetSize(CW, 24)
                b:SetPoint("LEFT", CX, 0)
                Opt.dark(b, 0.45)
                b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
                local arrow = b:CreateTexture(nil, "ARTWORK")
                arrow:SetSize(16, 16)
                arrow:SetPoint("RIGHT", -4, 0)
                arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
                local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                fs:SetPoint("LEFT", 8, 0)
                fs:SetPoint("RIGHT", arrow, "LEFT", -2, 0)
                fs:SetJustifyH("LEFT")
                pcall(fs.SetWordWrap, fs, false)
                b:SetScript("OnClick", function(self)
                    if Opt.menu and Opt.menu:IsShown() and Opt.menu.owner == self then Opt.closeMenu(); return end
                    Opt.openMenu(self, list(), get(key, default), function(v) set(key, v, true) end)
                end)
                Opt.tip(b, text, tip)
                row.controls = { b }
                row.texts[#row.texts + 1] = fs
                row.refresh = function()
                    local cur = get(key, default)
                    local shown = tostring(cur)
                    for _, c in ipairs(list()) do
                        if c[1] == cur then shown = c[2]; break end
                    end
                    fs:SetText(shown)
                end
            end })
        end
        function B.button(text, buttonText, onClick, tip)
            return add({ make = function(f, row)
                label(f, row, text, tip)
                local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
                b:SetSize(180, 24)
                b:SetPoint("LEFT", CX, 0)
                b:SetText(buttonText)
                b:SetScript("OnClick", function()
                    onClick()
                    Opt.changed()
                end)
                Opt.tip(b, text, tip)
                row.controls = { b }
            end })
        end
        -- Buff and debuff layout details (in the Buffs and debuffs section).
        function B.auraDetails()
            B.dropdown("auraGrowth", "Rows grow", "To the right: the first icon at the left end. To the left: the first icon at the right end, with the row filling leftwards.", "right",
                { { "right", "To the right" }, { "left", "To the left" } })
            B.slider("auraGap", "Gap", "Space between the icons.", 2, 0, 10, 1, function(v) return string.format("%d px", math.floor(v + 0.5)) end)
            B.slider("auraStack", "Stack count size", "How big the stack count is, as a share of the icon.", 50, 30, 90, 5,
                function(v) return string.format("%d%%", math.floor(v + 0.5)) end)
        end
        -- Fade to red with its style and custom stops. read: whose settings to show; set(unit, key, value).
        -- Fade to red, with its colours and (only while those are your own) the three stops; each part
        -- shows only while what it depends on is on. read: whose settings to show; set(unit, key, value).
        function B.fade(read, set, tip)
            local fade = B.check("healthFade", "Fade to red as health drops", tip, false)
            local function fadeOn() return getSetting(read, "healthFade") and true or false end
            local style = B.dropdown("fadeStyle", "Fade colours", "Automatic: the colour turns to red round the colour wheel (shamans, mages and warlocks each have their own route), fully red from 25% health.\n\nMy own: up to three colour stops, each at a health % you choose.", "auto",
                { { "auto", "Automatic" }, { "custom", "My own" } })
            B.under(fade, fadeOn, style)
            B.showIf(fadeOn, style)
            local function custom() return fadeOn() and getSetting(read, "fadeStyle") == "custom" end
            local pctText = function(v) v = math.floor(v + 0.5); return v <= 0 and "Off" or string.format("%d%%", v) end
            local inits = { B.check("fadeBlend", "Blend between stops", "On: the colour blends from one stop to the next. Off: the bar changes colour right at each stop.", true) }
            local names = { "First", "Second", "Third" }
            for i = 1, 3 do
                inits[#inits + 1] = B.slider("fade" .. i .. "Pct", names[i] .. " stop at", "The health % at which the bar reaches this stop's colour. 0 turns the stop off.",
                    DEFAULT_SETTINGS["fade" .. i .. "Pct"], 0, 100, 5, pctText)
            end
            B.under(style, custom, unpack(inits))
            B.showIf(custom, unpack(inits))
            -- (Blizzard's button rows error when made to depend on another setting, so the colour buttons
            -- are only shown / hidden, not indented)
            for i = 1, 3 do
                local key = "fade" .. i .. "Color"
                local sw = B.swatch(names[i] .. " stop colour", function()
                    local c = getSetting(read, key)
                    return type(c) == "table" and c or { 1, 1, 1 }
                end, function(r, g, b) set(read, key, { r, g, b }) end,
                    "The bar's colour at the " .. names[i]:lower() .. " stop. Click to change it.")
                B.showIf(custom, sw)
            end
        end
        return B
    end

    -- General ------------------------------------------------------------------
    do
        local general = setmetatable({}, {
            -- addon-wide switches, both on unless turned off; "show_<unit>" is that frame's Show
            __index = function(_, k)
                if k == "enabled" or k == "combatNumbers" then return DB[k] ~= false end
                if k == "minimapButton" then return not (type(DB.minimap) == "table" and DB.minimap.hide) end
                local unit = k:match("^show_(.+)$")
                if unit then return frameOn(unit) end
            end,
            __newindex = function(_, k, v)
                if k == "enabled" or k == "combatNumbers" then DB[k] = v and true or false; return end
                if k == "minimapButton" then Opt.setMinimapShown(v); return end
                local unit = k:match("^show_(.+)$")
                if unit then setSetting(unit, "frameShown", v and true or false) end
            end,
        })
        local B = builders(Opt.newPage("general", "General"), general)
        B.header("Webby Frames  |cff808080v" .. addonVersion() .. "  -  by Webby, Lexible & Dranged|r")
        B.pair({ "enabled", "Enable Webby Frames", "Replaces Blizzard's player, target, target of target, focus, focus target and pet frames.\n\n|cffffd100Needs a /reload.|r", true },
               { "combatNumbers", "Combat numbers", "Damage and healing popping up over the portraits. Turn this off if you prefer Blizzard's floating combat text (Esc > Options > Gameplay > Combat).\n\nShown on the player, target and focus frames.", true })
        B.pair({ "minimapButton", "Minimap button", "A Webby Frames button on the minimap: click it for these options, right-click it for Edit Mode. Drag it round the minimap to move it.", true })

        B.header("Frames")
        -- which of the optional frames are used (player and target always are)
        local function showItem(unit)
            return { "show_" .. unit, UNIT_LABEL[unit], "Show the " .. UNIT_LABEL[unit]:lower() .. " frame. Turned off, it stays hidden, in Edit Mode too. (Changes made in combat apply when it ends.)", true }
        end
        B.pair(showItem("targettarget"), showItem("focus"))
        B.pair(showItem("focustarget"), showItem("pet"))
        B.button("Position", "Open Edit Mode", openEditMode, "Drag the frames where you want them. They snap to each other and to the middle of the screen, and a frame dropped next to another moves with it.")
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
        local function setAll(_, k, v) for _, unit in ipairs(UNITS) do setSetting(unit, k, v) end end
        local proxy = setmetatable({}, {
            __index = function(_, k) return getSetting("player", k) end,
            __newindex = setAll,
        })
        local B = builders(Opt.newPage("all", "All frames"), proxy)
        B.header("|cff808080Changes here apply to every frame. Each frame's own page can then differ.|r")

        -- (the same sections, in the same order, as each frame's page)
        B.section("Frame", true)
        B.dropdown("frameTint", "Frame colour", "Colours the frame art on every frame. The player's resting glow takes the colour too.", "default",
            { { "default", "Gold" }, { "class", "Class colour" }, { "custom", "Custom" } })
        B.showIf(function() return getSetting("player", "frameTint") == "custom" end,
            B.swatch("Custom colour", function() return Extras.tintColor("player") or { 1, 1, 1 } end,
                function(r, g, b) setAll(nil, "frameColor", { r, g, b }) end, "The colour for every frame's art. Click to change it."))
        B.dropdown("portraitStyle", "Portrait", "The unit's picture, or for players their class icon (NPCs keep their picture).", "picture",
            { { "picture", "Picture" }, { "class", "Class icon (players)" } })

        B.section("Bars", false)
        B.dropdown("barTexture", "Health texture", "Every frame's health bar fill (and cast bar and heal / shield overlays).", "default", textureChoices)
        B.dropdown("powerTexture", "Power texture", "Every frame's mana, rage or energy fill.", "default", textureChoices)
        B.dropdown("font", "Font", "For the names and bar numbers on every frame.", "default", fontList)
        local numbers = B.dropdown("textMode", "Numbers", "When the bars show their numbers, on every frame.", "always",
            { { "always", "Always" }, { "mouseover", "On mouseover" }, { "off", "Never" } })
        B.under(numbers, function() return getSetting("player", "textMode") ~= "off" end,
            B.dropdown("textFormat", "Style", "Totals, percentages, or both.", "value",
                { { "value", "12.3K" }, { "percent", "85%" }, { "both", "12.3K (85%)" } }))

        B.section("Health bar", false)
        local npc = B.dropdown("npcColor", "Enemy NPC colour", "The health colour for hostile NPCs on every frame, when Health colour is set by reaction. Green lets Fade to red show their health dropping. Neutral NPCs stay yellow.", "reaction",
            { { "reaction", "Red" }, { "green", "Green" }, { "custom", "My own" } })
        B.showIf(function() return getSetting("target", "npcColor") == "custom" end,
            B.swatch("Custom NPC colour", function()
                local c = getSetting("target", "npcColorRGB")
                return type(c) == "table" and c or { 0.1, 0.8, 0.1 }
            end, function(r, g, b) setAll(nil, "npcColorRGB", { r, g, b }) end, "The health colour for hostile NPCs on every frame. Click to change it."))
        B.fade("player", setAll, "As health drops, each frame's health colour shifts towards red (or through your own stops).")
        B.pair({ "healPrediction", "Incoming heals", "Heals on their way, in green past the end of the health.", true },
               { "absorbs", "Shields and heal absorbs", "Damage shields and healing absorbs on the health bars.", true })
        B.pair({ "damageTrail", "Show recent damage", "When health drops, the part just lost stays in red for a moment, then slides away.", true })

        B.section("Buffs and debuffs", false)
        B.dropdown("auraTimer", "Time left", "How each icon shows the time it has left, on every frame.", "both",
            { { "both", "Sweep and numbers" }, { "swipe", "Sweep" }, { "numbers", "Numbers" }, { "none", "Nothing" } })
        B.auraDetails()
    end

    for _, unit in ipairs(UNITS) do
        local proxy = setmetatable({}, {
            __index = function(_, k) return getSetting(unit, k) end,
            __newindex = function(_, k, v) setSetting(unit, k, v) end,
        })
        local B = builders(Opt.newPage(unit, UNIT_LABEL[unit]), proxy)

        local px = function(v) return string.format("%d px", math.floor(v + 0.5)) end
        local whole = function(v) return string.format("%d", math.floor(v + 0.5)) end
        local function isOn(key) return function() return getSetting(unit, key) and true or false end end

        -- the frame itself and the icons on its portrait
        B.section("Frame", true)
        local myClass = select(2, UnitClass("player"))
        local nameItem = { "showName", "Show name", "The unit's name above its health bar.", true }
        if unit == "player" then   -- (your own name always shows)
            B.pair({ "restTint", "Zzz in frame colour", "The resting Zzz by the portrait takes the frame colour (it stays as drawn while the frame is gold).", false })
        elseif unit == "target" and (myClass == "ROGUE" or myClass == "DRUID") then
            B.pair(nameItem, { "comboPoints", "Combo points", "Your combo points in an arc round the target's portrait" .. (myClass == "DRUID" and ", while you're in cat form." or ".") .. " Drag them anywhere in Edit Mode.", true })
        elseif not ALWAYS_SHOWN[unit] then
            B.pair({ "frameShown", "Show this frame", "Turned off, the frame stays hidden, in Edit Mode too. Also on the General page.", true }, nameItem)
        else
            B.pair(nameItem)
        end
        B.slider("scale", "Scale", "How big the frame is.", defaultFor(unit, "scale"), 0.5, 2, 0.05)
        if unit ~= "pet" then   -- (a pet has no class: it always shows its picture)
            B.dropdown("portraitStyle", "Portrait", "The unit's picture, or for players their class icon (NPCs keep their picture).", "picture",
                { { "picture", "Picture" }, { "class", "Class icon (players)" } })
        end
        B.dropdown("frameTint", "Frame colour", "Colours the frame art: its border, portrait ring, corner accent, level circle and cast bar border. Class colour is your class's colour."
            .. (unit == "player" and " The resting glow takes the colour too." or ""), "default",
            { { "default", "Gold" }, { "class", "Class colour" }, { "custom", "Custom" } })
        B.showIf(function() return getSetting(unit, "frameTint") == "custom" end,
            B.swatch("Custom colour", function() return Extras.tintColor(unit) or { 1, 1, 1 } end,
                function(r, g, b) setSetting(unit, "frameColor", { r, g, b }) end, "The colour for the frame art. Click to change it."))
        if unit == "player" then
            B.dropdown("cornerStyle", "Corner accent", "The gold corner at the portrait's bottom right: Retail's pointed one, or Forever's older rounder one.", "retail",
                { { "retail", "Retail" }, { "forever", "Forever" } })
            B.pair({ "costPredict", "Show spell costs", "On your mana (or other power) bar: while you cast, the part the spell will use is shaded; when any spell or ability goes off (instants too), what it used flashes past the end of the bar.", true },
                   myClass == "DRUID" and { "druidMana", "Druid mana", "While you're in bear or cat form, your mana shows in a slim bar under the frame. Drag it anywhere in Edit Mode.", true } or nil)
            B.showIf(function() return getSetting("player", "costPredict") and true or false end,
                B.slider("costShade", "Spell cost shading", "How the cost shows on the bar while you cast: lighter (right) or darker (left), and by how much. The flash when a spell goes off always stays light.", 55, -100, 100, 5,
                    function(v)
                        v = math.floor(v + 0.5)
                        if v == 0 then return "Off" end
                        return string.format(v > 0 and "Lighter %d%%" or "Darker %d%%", math.abs(v))
                    end))
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

        -- the health bar's colour and what's drawn on and past it
        B.section("Health bar", false)
        if unit == "pet" then   -- (the pet's own reaction colour flips around, so these two)
            B.dropdown("petColor", "Health colour", "The same as your player frame's (your class colour, if that's what the player frame uses), or plain green.", "player",
                { { "player", "Match the player frame" }, { "plain", "Plain green" } })
        else
            local colour = B.dropdown("colorMode", "Health colour", "How the health bar is coloured.", "smart", COLOR_MODES)
            if unit ~= "player" then
                local function byReaction() local m = getSetting(unit, "colorMode"); return m == "smart" or m == "reaction" end
                local npc = B.dropdown("npcColor", "Enemy NPC colour", "The health colour for hostile NPCs. Green (or your own colour) lets Fade to red show their health dropping. Neutral NPCs stay yellow.", "reaction",
                    { { "reaction", "Red" }, { "green", "Green" }, { "custom", "My own" } })
                B.under(colour, byReaction, npc)
                B.showIf(byReaction, npc)
                B.showIf(function() return byReaction() and getSetting(unit, "npcColor") == "custom" end,
                    B.swatch("Custom NPC colour", function()
                        local c = getSetting(unit, "npcColorRGB")
                        return type(c) == "table" and c or { 0.1, 0.8, 0.1 }
                    end, function(r, g, b) setSetting(unit, "npcColorRGB", { r, g, b }) end, "The health colour for hostile NPCs. Click to change it."))
            end
        end
        B.fade(unit, setSetting, "As health drops, the health colour (whichever you picked above) shifts towards red, or through your own stops.")
        B.pair({ "healPrediction", "Incoming heals", "Heals on their way to the unit, in green past the end of its health.", true },
               { "absorbs", "Shields and heal absorbs", "Damage shields in pale blue past the end of its health, and healing absorbs eating back into it in red.", true })
        B.pair({ "damageTrail", "Show recent damage", "When its health drops, the part just lost stays in red for a moment, then slides away, so you can see how big each hit was.", true },
               (unit == "target" or unit == "focus") and { "damagePredict", "Preview spell damage", "While you cast at it, the damage your spell will do shows lighter at the end of its health (the tooltip's damage; crits, resists and armour aren't counted).", true } or nil)

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
        B.auraDetails()

        if hasCastAndThreat(unit) then
            B.section("Cast bar and threat", false)
            B.check("castShow", "Cast bar", "What the unit is casting, under its mana bar: yellow for a cast, green for a channel, grey when you can't interrupt it, red when interrupted.", true)
            B.showIf(isOn("castShow"),
                B.pair({ "castText", "Spell name", "The spell's name on the bar.", true },
                       { "castIcon", "Spell icon", "At the bar's left end.", true }))
            local threat = B.dropdown("threatShow", "Threat", "Your threat on hostile mobs: a glow round the frame and / or your threat %, both in your threat colour.", "both",
                { { "both", "Glow and number" }, { "glow", "Glow only" }, { "number", "Number only" }, { "off", "Off" } })
            B.under(threat, function() local m = getSetting(unit, "threatShow"); return m == "both" or m == "number" end,
                B.dropdown("threatStyle", "Threat number", "Your threat %. About 110% pulls aggro in melee and 130% at range. While you have aggro, it's your threat compared with the next highest in your group.\n\nJust the number: beside the raid marker on the portrait.\nBox: a small box above the end of the name.", "text",
                    { { "text", "Just the number" }, { "box", "In a box above the name" } }))
            B.under(threat, function() return getSetting(unit, "threatShow") ~= "off" end,
                B.dropdown("threatColors", "Threat colours", "The colour of the glow and the number.\nGreen to red: green when you're safe, turning red as you get closer to pulling aggro.\nBlizzard's: the game's own threat colours.", "gradient",
                    { { "gradient", "Green to red" }, { "blizzard", "Blizzard's" } }))
        end

        B.section("Reset and copy", false)
        if unit ~= "player" then
            B.button("Copy", "Copy from player", function() copySettings("player", unit) end,
                "Gives this frame the player frame's options. Its position doesn't change.")
        end
        B.button("Reset", "Reset this frame", function() resetFrame(unit) end,
            "Puts this frame back to its default options and position, for the current Edit Mode layout.")
    end
end

-- Entry in the minimap addon compartment (needs the TOC fields below).
function WebbyFrames_OnCompartmentClick() Opt.toggle() end

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
    if not pcall(buildSettings) then
        print("|cffff9900Webby Frames:|r couldn't build the settings window; Edit Mode still works.")
    end
    pcall(Opt.buildAddOnsPage)
    pcall(Opt.setupMinimap)
    if DB.enabled == false then return end

    for _, unit in ipairs(UNITS) do
        if unit == "targettarget" or unit == "focustarget" or unit == "pet" then createSmallFrame(unit) else createFrame(unit) end
    end
    Extras.init()
    hideAllBlizzard()
    C_Timer.After(2, hideAllBlizzard)
    setupEditMode()
    pcall(setupEllesmere)
    C_Timer.After(3, function() pcall(setupEllesmere) end)   -- (in case EllesmereUI finishes loading after us)
    applyAll()
    print("|cff33ccffWebby Frames|r v" .. addonVersion() .. " loaded. Type |cff33ccff/webby|r for options.")
end)

SLASH_WEBBYFRAMES1 = "/webby"
SlashCmdList.WEBBYFRAMES = function(msg)
    local rawmsg = (msg or ""):lower()      -- (the whole line, for commands that take numbers)
    msg = rawmsg:match("^%s*(%S*)") or ""
    if msg == "" then
        Opt.toggle()
    elseif msg == "options" then
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
        print("Aura containers:", ac and "in use" or (ac == false and "not available on this client (no buffs or debuffs)" or "not made yet"))
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
    elseif msg == "threat" then
        -- what the game reports for your target's threat: yours, then everyone else's in your group
        local mob = "target"
        if not UnitExists(mob) then print("|cff33ccffWebby Frames:|r target a mob first."); return end
        local function line(who)
            local ok, err = pcall(function()
                local tanking, status, scaled, raw, value = UnitDetailedThreatSituation(who, mob)
                if value == nil and status == nil then return end
                print(string.format("  %s (%s): tanking %s, status %s, pull meter %s, raw %s, threat %s",
                    tostring(UnitName(who)), who, tostring(tanking), tostring(status), tostring(scaled), tostring(raw), tostring(value)))
            end)
            if not ok then print("  " .. who .. ": can't be read (" .. tostring(err) .. ")") end
        end
        print("|cff33ccffWebby Frames:|r threat on " .. tostring(UnitName(mob)) .. ":")
        line("player")
        local units = { "pet" }
        if IsInRaid() then for i = 1, 40 do units[#units + 1] = "raid" .. i; units[#units + 1] = "raidpet" .. i end
        else for i = 1, 4 do units[#units + 1] = "party" .. i; units[#units + 1] = "partypet" .. i end end
        for _, gu in ipairs(units) do if UnitExists(gu) and not UnitIsUnit(gu, "player") then line(gu) end end
        local over
        local ok, err = pcall(function() over = threatOverNext(mob) end)
        print("  your % of the next highest: " .. (ok and tostring(over) or ("can't be worked out (" .. tostring(err) .. ")")))
    elseif msg == "export" or msg == "import" then
        Profiles.show(msg)
    elseif msg == "corner" then
        -- fine-tune the player's corner accent: /webby corner x y (right / up, pixels; 0 0 or none resets)
        local p = "|cff33ccffWebby Frames:|r "
        local x, y = (rawmsg or ""):match("corner%s+(%-?[%d%.]+)%s+(%-?[%d%.]+)")
        local style = getSetting("player", "cornerStyle")
        local key = "cornerNudge_" .. tostring(style)
        x, y = tonumber(x), tonumber(y)
        if x and y and (x ~= 0 or y ~= 0) then
            setSetting("player", key, { x, y })
        else
            setSetting("player", key, nil)
            x, y = 0, 0
        end
        local f = frames.player
        if f then f.cornerStyle = nil; pcall(applyCorner, f) end
        print(p .. "corner accent (" .. tostring(style) .. ") nudged " .. x .. " right, " .. y .. " up. Try /webby corner 0.5 -0.5 and so on; /webby corner resets.")
    elseif msg == "cost" then
        -- what the spell cost prediction saw on your last cast
        local f = frames.player
        local p = "|cff33ccffWebby Frames:|r "
        if not (f and f.costBar) then print(p .. "no player frame."); return end
        print(p .. "Spell cost is " .. (getSetting("player", "costPredict") and "on" or "off")
            .. "; cast starts seen: " .. tostring(f.costStarts or 0)
            .. "; C_Spell.GetSpellPowerCost " .. ((C_Spell and C_Spell.GetSpellPowerCost) and "yes" or "no")
            .. ", GetSpellPowerCost " .. (GetSpellPowerCost and "yes" or "no"))
        print(p .. "last cast: " .. tostring(f.costInfo or "none yet (cast something with a cast time, then try again)"))
        print(p .. "bar: " .. (f.costBar:IsShown() and "showing" or "hidden") .. ", width " .. tostring(math.floor(f.costBar:GetWidth() or 0)))
        local t = frames.target
        print(p .. "damage prediction, last cast at an enemy: " .. tostring(t and t.dmgInfo or "none yet"))
    elseif msg == "errors" then
        -- the errors caught while updating the frames (each shown once)
        if #updateErrors == 0 then print("|cff33ccffWebby Frames:|r no errors caught.") end
        for i, err in ipairs(updateErrors) do print("|cffff6060Webby Frames error " .. i .. ":|r " .. tostring(err)) end
    elseif msg == "help" then
        print("|cff33ccffWebby Frames|r commands:")
        print("  /webby - options   /webby edit - move the frames   /webby reset - reset every frame")
        print("  /webby test - preview heals, shields and a combat number on your frame")
        print("  /webby threat - what the game reports for your target's threat")
        print("  /webby cost - what the spell cost bar saw on your last cast")
        print("  /webby corner x y - fine-tune where the corner accent sits (right / up, in pixels)")
        print("  /webby export, /webby import - share a profile   /webby errors - anything that went wrong")
    else
        print("|cff33ccffWebby Frames:|r unknown command. Type |cff33ccff/webby help|r.")
    end
end
