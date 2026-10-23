-- Webby Frames
-- Frame art, bar fills and masks are DragonflightUI's bundled copies of the Retail art (Media\).
-- Draws its own player / target / target of target / focus / focus target / pet frames using Blizzard's built-in Retail
-- unit frame art (atlases), so the border and the pointed bars match Retail and
-- no other addon is needed. Layout numbers come from Blizzard's PlayerFrame.xml
-- and TargetFrame.xml. Position and options are editable in Edit Mode (bundled
-- LibEditMode) and in Esc > Options > AddOns > Webby Frames, saved per layout.

-- The addon's files share one table (ns, the second value the game passes every file): this file puts
-- the helpers the modules use on it (see the end of the file); the modules (Party.lua,
-- ClickCasting.lua) load after it, as the .toc lists them, and add their parts. ns.pages: functions
-- the settings window calls to add a module's own page (builders, Opt).
local _, ns = ...
ns.pages = {}

-- carry settings over from the old DFFramesForever name, once
WebbyFramesDB = WebbyFramesDB or DFFramesForeverDB or {}

-- "party" is the party frames: four small frames (party1 - party4) sharing one set of options. The
-- first is frames.party, positioned like any other frame (Edit Mode, snapping, EllesmereUI); the others
-- (Party.members) stack under it.
local UNITS = { "player", "target", "targettarget", "focus", "focustarget", "pet", "party" }
local UNIT_LABEL = { player = "Player", target = "Target", targettarget = "Target of Target", focus = "Focus", focustarget = "Focus Target", pet = "Pet", party = "Party" }
-- Portrait side is fixed per frame: target and focus have it on the right (Retail's target art),
-- the player and the small frames on the left.
local function portraitOnLeft(unit) return unit ~= "target" and unit ~= "focus" end
-- only the full-size target and focus frames have the cast bar, interrupt flash and threat
local function hasCastAndThreat(unit) return unit == "target" or unit == "focus" end
-- the pointed corner accent is only offered on the player frame; the rest keep a round ring
local function hasCorner(unit) return unit == "player" end
-- your own frames (class colour = yours; no "your debuffs" on them)
local OWN_CLASS = { player = true, pet = true }

local COLOR_MODES = {
    { "plain",    "Default" },          -- (the bar as the game draws it: green)
    { "smart",    "Class for players, reaction for NPCs" },
    { "class",    "Class colour (players only)" },
    { "reaction", "By reaction" },
    { "dark",     "Dark" },
}

local DEFAULT_POS = {
    player = { point = "TOPLEFT", x = 20,  y = -40 },
    target = { point = "TOPLEFT", x = 270, y = -40 },
    focus  = { point = "TOPLEFT", x = 270, y = -170 },
    pet    = { point = "TOPLEFT", x = 20,  y = -170 },
    focustarget = { point = "TOPLEFT", x = 394, y = -260 },
    -- Retail puts target of target at the bottom right of the target frame
    targettarget = { point = "TOPLEFT", x = 394, y = -130 },
    party  = { point = "TOPLEFT", x = 20,  y = -260 },
}

-- per-frame defaults that differ from DEFAULT_SETTINGS (the small frame is too narrow for long numbers)
local UNIT_DEFAULTS = {
    player = { combatNumbers = true },
    target = { auraBuffs = true, auraDebuffs = true, combatNumbers = true },
    focus  = { auraBuffs = true, auraDebuffs = true, combatNumbers = true },
    targettarget = { textMode = "off", textFormat = "percent" },
    pet = { textMode = "off", textFormat = "percent", combatNumbers = true },
    focustarget = { textMode = "off", textFormat = "percent" },
    -- party: health as a percentage, and their debuffs (small, one row under each member)
    party = { colorMode = "class", textMode = "always", textFormat = "percent", auraBuffs = true, auraDebuffs = true, auraSize = 16, auraPerRow = 6, auraMax = 6,
              auraStyle = "retail", dispelGlow = true, auraPos = "side", partyGap = 6,
              -- raid style (RaidParty.lua): tiles, their size and gap, you among them, power bars, health text
              partyStyle = "portrait", rpWidth = 96, rpHeight = 48, rpGap = 3, rpSelf = true,
              rpPowerTank = true, rpPowerHealer = true, rpPowerDPS = false,
              rpAuraSize = 14, rpDefSize = 20, rpDefensives = true,
              rpHealthColor = "class", rpHealthCustom = { 0.15, 0.75, 0.25 }, rpMissingDark = 75,
              rpDispelStyle = "gradient", rpDispelIcon = true,
              rpNameColor = "white", rpNameMax = 0, rpNamePos = "topleft",
              rpHoverEdge = true, rpPets = false, rpPetPos = "after", rpPetHeight = 24, rpDebuffs = true, rpBuffs = true, rpSolo = false, rpAFK = true,
              rpDeadColor = { 0.3, 0.1, 0.1 }, rpOfflineColor = { 0.35, 0.35, 0.35 },
              rpShieldStyle = "striped", rpShieldEdge = false,
              -- both styles: fading out of range, missing buffs, the healer mana list, tooltips
              rangeAlpha = 0.45, missingBuffs = true, healerMana = false, partyTooltip = "always" },
}

local DEFAULT_SETTINGS = {
    scale = 1, showName = true, healthFade = false, textMode = "always", textFormat = "value", barTexture = "default", font = "default", threatShow = "both",
    threatStyle = "text",       -- the threat %: "text" (just the number, by the raid marker) or "box" (above the name)
    threatColors = "gradient",  -- "gradient" (green to red) or "blizzard"
    -- health bar colour: "smart" (class colour for players, reaction colour for NPCs), "class", "reaction" or "plain"
    colorMode = "smart",
    npcColor = "reaction",   -- hostile NPCs: "reaction" (red), "green" or "custom" (npcColorRGB = { r, g, b })
    -- buffs and debuffs (off unless a frame's defaults turn them on)
    auraBuffs = false, auraDebuffs = false, auraMine = false,
    auraSize = 18, auraPerRow = 8, auraMax = 16, auraPos = "below", auraTimer = "both",   -- auraDebuffSize follows auraSize until set
    auraGap = 2, auraGrowth = "right", auraStack = 50,      -- gap between icons, row direction, stack count size (% of icon)
    portraitStyle = "picture",   -- "picture" or "class" (class icon for players)
    -- cast bar (target and focus): Blizzard's own bar drives one built into our frame
    castShow = true, castText = true, castIcon = true,
    -- the cast bar's looks: its texture ("default": the frame's health texture), a spark on the fill's
    -- edge, how it goes when a cast ends (off / fade / flash) and how long that takes. Its colours
    -- (castColorCast, Channel, Locked, Interrupted) are unset until picked: CAST_COLORS then.
    castTexture = "default", castSpark = true, castFade = "fade", castFadeTime = 0.5,
    -- frame art colour: "default" (gold, as drawn), "class" or "custom" (frameColor = { r, g, b })
    frameTint = "default",
    -- health bar extras
    frameShown = true,       -- target of target, focus, focus target, pet, party: the frame is used at all
    -- party: gap between members (room for a row of debuffs), role / leader icons, fading out of range
    partyGap = 24, rangeFade = true,
    -- party layout: "vertical" (stacked) or "horizontal" (side by side); order "group" (Blizzard's) or
    -- "role" (tanks, healers, damage); each member's pet as a mini frame
    partyLayout = "vertical", partySort = "group", partyPets = true,
    -- buffs and debuffs: "all" (every buff) or "retail" (the party's default: only your own buffs);
    -- dispelGlow: the party frame glows in the dispel colour when you can dispel something on it
    auraStyle = "all", dispelGlow = true, dispelWho = "mine", auraMineBig = false,   -- (auraMineBig: your own debuffs first, bigger)
    healPrediction = true, absorbs = true, damageTrail = true, damagePredict = true,
    -- recent damage: the health bar's own fill, red, until you pick otherwise (Damage trail texture,
    -- colour, delay, opacity). Delay is how long a hit stays; steady damage still catches up.
    damageTrailTexture = "default", damageTrailAlpha = 0.9, damageTrailDelay = 0.4,
    -- shields: their texture ("default": the health bar's; "striped": Blizzard's stripes) and opacity;
    -- absorbColor unset until picked (pale blue)
    absorbTexture = "default", absorbAlpha = 0.7,
    -- glows on shields and incoming heals: off / pulse / shimmer / snow / blizzard, and how strong, and
    -- the border glow (ns.barGlow)
    absorbGlow = "off", absorbGlowAlpha = 0.6, healGlow = "off", healGlowAlpha = 0.6,
    absorbBorder = false, healBorder = false,
    -- incoming heals (everyone's, one bar): their texture ("default": the health bar's); healColor and
    -- healAlpha unset until picked (green, as drawn before)
    healTexture = "default",
    combatNumbers = false,   -- damage / heal numbers over the portrait: fixed per frame (player, target, focus, pet), one General switch
    -- icons and extras
    comboPoints = true,
    druidMana = true,        -- player: a druid's mana in a slim bar under the frame while in a form
    -- player: weapon enchants before your buffs, your buffs as timer bars (PlayerExtras.lua)
    weaponEnchants = true, buffBars = false, buffBarsWho = "mine", buffBarsMax = 8, buffBarsWidth = 180,
    hpAlpha = 1, mpAlpha = 1,   -- how solid the health and power fills are
    druidBars = "form",      -- player, druids in a form: "form" (the frame's bar: form power; slim bar: mana) or "mana" (the other way round)
    restTint = false,        -- player: the resting Zzz takes the frame colour
    costPredict = true,      -- player: while casting, the spell's cost shows on the power bar
    manaTick = true,         -- player: a light crossing the mana bar for the five second rule
    manaTickSparkle = true, manaTickTrail = true, manaTickSize = 100,
    costShade = 55,          -- player: how much lighter (above 0) or darker (below 0) the cost shows
    costGlow = "off", costGlowAlpha = 0.6,   -- player: glow on the cost while you cast (pulse / shimmer / snow / blizzard)
    cornerStyle = "retail",  -- player: the corner accent's art, Retail's or Forever's own
    petColor = "player",     -- pet health bar: "player" (the player frame's colour) or "plain" (Default: as drawn)
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
-- the party frames, slot 1 - 4 (slot 1 is frames.party); see "Party frames"
local Party = { members = {}, SLOTS = 4 }   -- (filled in by Party.lua)
ns.Party = Party
-- buffs and debuffs (Auras.lua fills it in); groups, in the order they show: buffs, your own debuffs
-- (only with "bigger own debuffs"), the rest
local AuraKit = { GROUPS = { "buffs", "debuffsMine", "debuffs" } }
ns.AuraKit = AuraKit
local function updateAuras(f) return AuraKit.update(f) end
-- the unit events a small frame (and a party slot, again whenever it's given another unit) listens to
Party.UNIT_EVENTS = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
    "UNIT_NAME_UPDATE", "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED", "UNIT_FACTION", "UNIT_CONNECTION", "UNIT_AURA",
    "UNIT_HEAL_PREDICTION", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "UNIT_COMBAT" }
local activeLayout = "Default"
local pendingApply = false
-- the settings window (Options.lua fills it in)
local Opt = { pages = {}, order = {}, ROW_H = 28, LABEL_X = 16, CONTROL_X = 300, CONTROL_W = 240, CONTENT_W = 580, MENU_ROWS = 14 }
ns.Opt = Opt

---------------------------------------------------------------------------
-- Saved settings (per Edit Mode layout)
---------------------------------------------------------------------------
-- Older saved keys, rewritten once per unit table. The live fallback (debuff icon size) stays in
-- getSetting, because it's "use the other setting until this one is set".
local migratedUnits = {}
local function migrateUnit(u)
    if migratedUnits[u] then return end
    migratedUnits[u] = true
    if u.textMode == nil and u.showText == false then u.textMode = "off" end
    u.showText = nil
    if u.colorMode == nil and (u.smartColor ~= nil or u.classColor ~= nil or u.reactionColor ~= nil) then
        if u.smartColor ~= false or (u.classColor and u.reactionColor) then u.colorMode = "smart"
        elseif u.classColor then u.colorMode = "class"
        elseif u.reactionColor then u.colorMode = "reaction"
        else u.colorMode = "plain" end
    end
    u.smartColor, u.classColor, u.reactionColor = nil, nil, nil
    if type(u.healthFade) == "string" then u.healthFade = (u.healthFade ~= "off") end
    if u.auraPos == "right" then u.auraPos = "custom" end
    if u.petHappy == nil and u.petHappiness == false then u.petHappy = "off" end
    u.petHappiness = nil
    if u.auraTimer == nil and u.auraTimers == false then u.auraTimer = "swipe" end
    u.auraTimers = nil
    if u.threatShow == nil and u.showThreat == false then u.threatShow = "off" end
    u.showThreat = nil
    if u.threatStyle == "badge" then u.threatStyle = "text" end
    if u.threatColors and u.threatColors ~= "blizzard" and u.threatColors ~= "gradient" then u.threatColors = "gradient" end
    local tint = u.frameTint
    if tint == "dark" or tint == "silver" or tint == "unitclass" then u.frameTint = "default" end
    -- name / number text and smooth bars are no longer options
    u.nameSize, u.nameColor, u.nameColorRGB = nil, nil, nil
    u.textSize, u.textColor, u.textColorRGB, u.textAnchor = nil, nil, nil
    u.smoothBars = nil
    -- the power bar's texture used to follow the health bar's until it was set; now they're separate, so
    -- a frame relying on that keeps its look by having it saved as its own
    if u.powerTexture == nil and u.barTexture ~= nil and u.barTexture ~= "default" then u.powerTexture = u.barTexture end
end

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
    if u then migrateUnit(u) end
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
    -- 0.57 test builds had one icon size
    if v == nil and key == "auraDebuffSize" then return getSetting(unit, "auraSize") end
    if v == nil then v = defaultFor(unit, key) end
    return v
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
-- Whether a value is hidden from addons (a "secret" in combat): it may only go to setters, never be
-- compared or worked with. (A client without secrets has nothing hidden.)
local function isSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) or false
end
-- An API's answer when it's usable (no error, not hidden), else nil. For tests in the hot paths, in
-- place of a throwaway pcall(function() ... end) each time.
local function plain(fn, ...)
    local ok, v = pcall(fn, ...)
    if ok and not isSecret(v) then return v end
end

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
    local scale = CurveConstants and CurveConstants.ScaleTo100
    local ok, pct
    if kind == "hp" and UnitHealthPercent then ok, pct = pcall(UnitHealthPercent, u, false, scale)
    elseif kind == "mp" and UnitPowerPercent then ok, pct = pcall(UnitPowerPercent, u, token, false, scale) end
    if ok and isSecret(pct) then return pct end              -- (hidden: straight to the text)
    if ok and pct ~= nil then return scale == nil and pct * 100 or pct end
    -- older clients: worked out, when the numbers aren't hidden
    local cur = plain(kind == "hp" and UnitHealth or UnitPower, u)
    local max = plain(kind == "hp" and UnitHealthMax or UnitPowerMax, u)
    if cur and max and max > 0 then return cur / max * 100 end
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
    if kind == "mp" and (isSecret(token) or token ~= "MANA") then fmt = "value" end
    local pct = (fmt ~= "value") and percentOf(kind, u, token) or nil
    local hasPct = isSecret(pct) or pct ~= nil
    local okA, valueText = pcall(AbbreviateLargeNumbers, cur)
    local ok
    if fmt == "value" then ok = okA and pcall(fs.SetText, fs, valueText)
    elseif fmt == "percent" then ok = hasPct and pcall(fs.SetFormattedText, fs, "%d%%", pct)
    else ok = okA and hasPct and pcall(fs.SetFormattedText, fs, "%s (%d%%)", valueText, pct) end
    if not ok and not pcall(fs.SetFormattedText, fs, "%d", cur) then fs:SetText("") end
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

-- Every tooltip of ours shows where the game puts tooltips by default (bottom right, or wherever Edit
-- Mode moved it), owned by `owner`.
local function defaultTip(owner)
    if GameTooltip_SetDefaultAnchor then GameTooltip_SetDefaultAnchor(GameTooltip, owner)
    else GameTooltip:SetOwner(owner, "ANCHOR_NONE"); GameTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -(CONTAINER_OFFSET_X or 0) - 13, CONTAINER_OFFSET_Y or 64) end
end
-- (a tooltip the game already filled, e.g. a buff's: moved to the default spot without clearing it)
local function moveTipToDefault(owner)
    if GameTooltip:GetOwner() ~= owner then return end
    GameTooltip:ClearAllPoints()
    local box = rawget(_G, "GameTooltipDefaultContainer")
    if box then GameTooltip:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT")
    else GameTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -(CONTAINER_OFFSET_X or 0) - 13, CONTAINER_OFFSET_Y or 64) end
end
-- Our buff and debuff icons (b.webbyAura): the game shows and refreshes their tooltips itself, next to
-- the icon; each time, it's moved to the default spot.
pcall(function()
    local function check(tt)
        local o = tt:GetOwner()
        if not (o and o.webbyAura) then return end
        local _, rel = tt:GetPoint(1)
        if rel == o then moveTipToDefault(o) end
    end
    GameTooltip:HookScript("OnShow", check)
    -- Blizzard re-anchors an aura tooltip beside the icon on later frames. Only ours get here.
    GameTooltip:HookScript("OnUpdate", function(tt)
        local o = tt:GetOwner()
        if o and o.webbyAura then check(tt) end
    end)
end)

---------------------------------------------------------------------------
-- Colours
---------------------------------------------------------------------------

-- (both run on every health change: no throwaway functions)
local function classColorOf(u)
    if not plain(UnitIsPlayer, u) then return end
    local ok, _, token = pcall(UnitClass, u)
    if not ok or isSecret(token) then return end
    local c = token and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
    if c then return c.r, c.g, c.b end
end

local function reactionColorOf(u)
    local ok, r, g, b = pcall(UnitSelectionColor, u, true)
    if ok and type(r) == "number" then return r, g, b end
end

-- Your own class token ("DRUID"), read once. (On ns, as are the other helpers added since: this file
-- is close to Lua's limit of 200 locals in one chunk.)
function ns.playerClass()
    if not ns.PLAYER_CLASS then ns.PLAYER_CLASS = select(2, UnitClass("player")) end
    return ns.PLAYER_CLASS
end


local PLAYER_AS_FRAME = { wfUnit = "player", baseUnit = "player" }

-- Another player, friendly or hostile. Not you. Their bar stays their class colour.
local function otherPlayer(u)
    if plain(UnitIsPlayer, u) ~= true then return false end
    if plain(UnitIsUnit, u, "player") then return false end
    return true
end

local function healthColor(f)
    local u, base = f.wfUnit, f.baseUnit
    local r, g, b

    if not plain(UnitPlayerControlled, u) and plain(UnitIsTapDenied, u) then return 0.5, 0.5, 0.5 end

    -- the pet's own selection colour flips around (neutral / friendly / controlled), so its bar is either
    -- the player frame's colour (as set on the player page: your class colour, say) or Default: the bar
    -- as the game draws it
    if base == "pet" then
        if getSetting("pet", "petColor") == "player" then return healthColor(PLAYER_AS_FRAME) end
        return nil
    end

    -- Other players, friendly or hostile: class colour only. Health colour and the fade would paint over it.
    if otherPlayer(u) then return classColorOf(u) end

    local mode = getSetting(base, "colorMode")
    if mode == "dark" then return 0.2, 0.2, 0.22 end      -- Dark: a flat dark bar (EllesmereUI's dark mode)
    if mode == "custom" then                                -- Custom: one colour of your own
        local c = getSetting(base, "healthColorRGB")
        if type(c) == "table" then return c[1] or 0.15, c[2] or 0.75, c[3] or 0.25 end
        return 0.15, 0.75, 0.25
    end
    if mode == "gradient" then return 0.15, 0.85, 0.25 end  -- By health: green when full (applyHealthFade does the rest)
    -- friendly pets and guardians (on any frame, e.g. targeting your pet): their selection colour
    -- flips between friendly, neutral and "controlled" blue, so they are always green
    if mode ~= "plain" and mode ~= "class" then
        if plain(UnitPlayerControlled, u) and plain(UnitIsPlayer, u) == false and plain(UnitCanAttack, "player", u) == false then
            return 0.1, 0.8, 0.1
        end
        -- hostile NPCs can have their own colour instead of reaction red (green, say, so the fade to red
        -- has somewhere to go); neutral ones keep their yellow
        local npc = getSetting(base, "npcColor")
        if npc == "green" or npc == "custom" then
            if plain(UnitIsPlayer, u) == false and (plain(UnitReaction, u, "player") or 9) <= 3 then
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
    if plain(UnitIsPlayer, u) and plain(UnitIsConnected, u) == false then return "Offline" end
    if plain(UnitIsGhost, u) then return "Ghost" end
    if plain(UnitIsDead, u) then return "Dead" end
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

-- Setting a font file on a string drops the game's font family, and with it the fonts for other
-- alphabets: Korean, Chinese and Cyrillic names then show as boxes. So a font is set as a family of our
-- own: the chosen (or default) file for Latin letters, the game's own fonts for the rest. Cached per
-- file, size and outline. Its colour and shadow are kept. (A client without font families: the plain
-- file, as before.)
ns.FONT_ALPHABETS = {
    { "korean", "Fonts\\2002.TTF" }, { "simplifiedchinese", "Fonts\\ARKai_T.ttf" },
    { "traditionalchinese", "Fonts\\blei00d.TTF" }, { "russian", "Fonts\\FRIZQT___CYR.TTF" },
}
ns.fontFamilies, ns.fontFamilyCount = {}, 0
function ns.setFont(fs, path, size, flags)
    if not (fs and path and size) then return false end
    flags = flags or ""
    if not CreateFontFamily then return fs:SetFont(path, size, flags) end
    local key = path .. "|" .. size .. "|" .. flags
    local fam = ns.fontFamilies[key]
    if fam == nil then
        local members = { { alphabet = "roman", file = path, height = size, flags = flags } }
        for _, a in ipairs(ns.FONT_ALPHABETS) do
            members[#members + 1] = { alphabet = a[1], file = a[2], height = size, flags = flags }
        end
        ns.fontFamilyCount = ns.fontFamilyCount + 1
        local ok, obj = pcall(CreateFontFamily, "WebbyFramesFont" .. ns.fontFamilyCount, members)
        fam = ok and obj or false
        ns.fontFamilies[key] = fam
    end
    if not fam then return fs:SetFont(path, size, flags) end
    -- (a font object brings its own colour and shadow: the string's are put back)
    local r, g, b, a = fs:GetTextColor()
    local sx, sy = fs:GetShadowOffset()
    local sr, sg, sb, sa = fs:GetShadowColor()
    fs:SetFontObject(fam)
    if r then fs:SetTextColor(r, g, b, a) end
    if sx then fs:SetShadowOffset(sx, sy) end
    if sr then fs:SetShadowColor(sr, sg, sb, sa) end
    return true
end

-- The chosen font, at each string's own size. Name and number size, colour and anchor are locked:
-- the font's own size and colour, numbers centred on their bar.
local function applyFont(f)
    local path = resolveFont(getSetting(f.baseUnit, "font"))
    f.fontDefaults = f.fontDefaults or {}
    for _, fs in ipairs({ f.name, f.hpText, f.mpText }) do
        if fs then
            if not f.fontDefaults[fs] then
                local fp, fz, ff = fs:GetFont()
                local r, g, b = fs:GetTextColor()
                f.fontDefaults[fs] = { fp, fz, ff, r, g, b }
            end
            local d = f.fontDefaults[fs]
            local size, ol = d[2], d[3]
            if fs ~= f.name and d[4] then fs:SetTextColor(d[4], d[5], d[6]) end
            -- (as a family, so names in other alphabets still have their letters: ns.setFont)
            local ok = false
            if path and size then ok = ns.setFont(fs, path, size, ol) end
            if not ok and d[1] then ns.setFont(fs, d[1], size or d[2], ol) end
        end
    end
    for _, pair in ipairs({ { f.hpText, f.hp }, { f.mpText, f.mp } }) do
        local fs, bar = pair[1], pair[2]
        if fs and bar then
            fs:ClearAllPoints()
            fs:SetPoint("CENTER", bar, "CENTER", 0, 0)
            fs:SetJustifyH("CENTER")
        end
    end
end

-- Health colour fade: the colour is chosen by a curve the GAME evaluates from the unit's health
-- percent, so it works with protected values; the result is only ever passed to a setter. Above 66%
-- the bar keeps its own colour, then a smooth blend: yellow at 66%, orange at 33%, red at 1% and
-- below. Other players do not fade: their bar stays their class colour (see otherPlayer).
local FADE_YELLOW = { 0.95, 0.90, 0.15 }
local FADE_ORANGE = { 0.96, 0.55, 0.10 }
local FADE_RED    = { 0.89, 0.19, 0.19 }
local fadeCurves = {}

local function getHealthFadeCurve(r, g, b)
    r, g, b = r or 0.1, g or 0.8, b or 0.1
    local key = string.format("%.2f:%.2f:%.2f", r, g, b)
    local c = fadeCurves[key]
    if c ~= nil then return c or nil end
    fadeCurves[key] = false
    pcall(function()
        if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return end
        local curve = C_CurveUtil.CreateColorCurve()
        pcall(function() curve:SetType(Enum.LuaCurveType.Linear) end)
        curve:AddPoint(0, CreateColor(FADE_RED[1], FADE_RED[2], FADE_RED[3], 1))
        curve:AddPoint(0.01, CreateColor(FADE_RED[1], FADE_RED[2], FADE_RED[3], 1))
        curve:AddPoint(0.33, CreateColor(FADE_ORANGE[1], FADE_ORANGE[2], FADE_ORANGE[3], 1))
        curve:AddPoint(0.66, CreateColor(FADE_YELLOW[1], FADE_YELLOW[2], FADE_YELLOW[3], 1))
        curve:AddPoint(1, CreateColor(r, g, b, 1))
        fadeCurves[key] = curve
    end)
    return fadeCurves[key] or nil
end

-- Returns true when the fade painted the bar.
local function applyHealthFade(f, r, g, b)
    -- Other players stay their class colour. No fade, and no green-yellow-red.
    if otherPlayer(f.wfUnit) then return false end
    -- on: the health colour chosen above (class, reaction or plain green) fades to red as health drops
    -- (Health colour "By health" is this fade too, along a fixed green - yellow - red)
    local byHealth = getSetting(f.baseUnit, "colorMode") == "gradient"
    if not getSetting(f.baseUnit, "healthFade") and not byHealth then return false end
    if not (UnitHealthPercent and UnitExists(f.wfUnit)) then return false end
    -- a mob someone else has tagged stays plain grey: its health is no business of yours
    if not plain(UnitPlayerControlled, f.wfUnit) and plain(UnitIsTapDenied, f.wfUnit) then return false end
    local curve
    if byHealth then
        if fadeCurves.byHealth == nil then
            fadeCurves.byHealth = false
            pcall(function()
                local c = C_CurveUtil.CreateColorCurve()
                pcall(function() c:SetType(Enum.LuaCurveType.Linear) end)
                c:AddPoint(0, CreateColor(0.9, 0.12, 0.1, 1))
                c:AddPoint(0.5, CreateColor(0.95, 0.82, 0.1, 1))
                c:AddPoint(1, CreateColor(0.15, 0.85, 0.25, 1))
                fadeCurves.byHealth = c
            end)
        end
        curve = fadeCurves.byHealth or nil
    else
        curve = getHealthFadeCurve(r, g, b)
    end
    if not curve then return false end
    local ok, color = pcall(UnitHealthPercent, f.wfUnit, true, curve)
    if ok and color then ok = pcall(f.hp.SetStatusBarColor, f.hp, color:GetRGB()) end
    -- (the bar is on its tintable fill while fading, see updateHealthColor: no greying needed)
    return ok
end

local function updateHealthColor(f)
    local ok, r, g, b = pcall(healthColor, f)
    if not ok then r, g, b = nil, nil, nil end
    local tex = f.hp:GetStatusBarTexture()
    -- the tintable fill for a colour or a fade (tinting the green fill meant greying it first, which
    -- dulled every colour); the plain green fill otherwise
    local fading = getSetting(f.baseUnit, "healthFade") and not otherPlayer(f.wfUnit) and true or false
    local want = ((r or fading) and f.hpStatusAtlas) or f.hpAtlas
    if f.customTex then
        if f.hpCurrent ~= f.customTex then
            f.hpCurrent = f.customTex
            f.hp:SetStatusBarTexture(f.customTex)
            if f.hpMaskOn then f.hp:GetStatusBarTexture():AddMaskTexture(f.hpMask) end
            useClip(f.hp, true)
        end
        if tex then tex:SetDesaturated(false) end
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
        if tex then tex:SetDesaturated(want == f.hpAtlas) end   -- plain art needs desaturating to tint cleanly
        f.hp:SetStatusBarColor(r, g, b, 1)
    else
        if tex then tex:SetDesaturated(false) end
        -- the tintable fill (fading) starts out green; the plain green fill as drawn
        if want == f.hpStatusAtlas then f.hp:SetStatusBarColor(0.1, 0.8, 0.1, 1) else f.hp:SetStatusBarColor(1, 1, 1, 1) end
    end
    applyHealthFade(f, r, g, b)
end

local refreshText   -- defined with the settings code below

-- Sets a bar's value, sliding to it (Blizzard's own interpolation, so protected values are fine).
-- Smooth bars are always on.
local SMOOTH = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
local function setBarValue(f, bar, value)
    if SMOOTH and pcall(bar.SetValue, bar, value, SMOOTH) then return end
    bar:SetValue(value)
end

---------------------------------------------------------------------------
-- Health bar extras: incoming heals past the end of the health fill, and absorb shields there or over
-- it (Shield placement). Secret-safe: each is a bar as long as the health bar, anchored to the health
-- fill's moving end (no maths on the values), with the same min / max; the values only ever go to
-- setters. They're clipped to the health bar, so nothing spills past its end.
---------------------------------------------------------------------------
local PLAIN_FILL = "Interface\\TargetingFrame\\UI-StatusBar"

local function newOverlay(f, r, g, b, a)
    local bar = CreateFrame("StatusBar", nil, f.predClip)
    bar:SetFrameLevel(f.predClip:GetFrameLevel())
    bar:SetStatusBarTexture(PLAIN_FILL)
    bar.color = { r, g, b, a }
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    return bar
end

-- The overlays wear the frame's own bar texture (a chosen SharedMedia one, or the frame's tintable
-- default fill), tinted, with the health bar's shape mask.
-- Shields have looks of their own (Shield texture, Shield colour, Shield opacity): in the health
-- bar's texture, Blizzard's stripes, or any texture.
-- Looks for a heal / shield / trail overlay (texture, colour, glow). Texture and colour are cached
-- so health ticks skip that work; the glow is still ensured every time (barGlow early-outs when it
-- is already running). A first pass can run before the fill exists, or while the UI is still hidden
-- after /reload (Play() then no-ops): skipping barGlow left pulse / shimmer / snow stuck until the
-- options were toggled.
local function styleOverlay(f, bar)
    local tex = f.customTex or f.hpStatusAtlas or PLAIN_FILL
    local grey, striped = not f.customTex, false
    local c = bar.color
    local r, g, b, a = c[1], c[2], c[3], c[4]
    local glowMode, glowStr, glowEdge
    if bar == f.absorbBar or bar == f.absorbBack then
        local key = getSetting(f.baseUnit, "absorbTexture") or "default"
        if key == "striped" then tex, grey, striped = "Interface\\RaidFrame\\Shield-Overlay", false, true
        elseif key ~= "default" then
            local own = resolveTexture(key)
            if own then tex, grey = own, false end
        end
        local sc = getSetting(f.baseUnit, "absorbColor")
        a = tonumber(getSetting(f.baseUnit, "absorbAlpha")) or a
        if type(sc) == "table" then r, g, b = sc[1] or r, sc[2] or g, sc[3] or b end
        glowMode = getSetting(f.baseUnit, "absorbGlow") or "off"
        glowStr = tonumber(getSetting(f.baseUnit, "absorbGlowAlpha")) or 0.6
        glowEdge = getSetting(f.baseUnit, "absorbBorder") and true or false
    elseif bar == f.healBar then
        -- incoming heals, everyone's, on the one bar (Heal texture, Heal colour, Heal opacity)
        local key = getSetting(f.baseUnit, "healTexture") or "default"
        if key ~= "default" then
            local own = resolveTexture(key)
            if own then tex, grey = own, false end
        end
        local hc = getSetting(f.baseUnit, "healColor")
        a = tonumber(getSetting(f.baseUnit, "healAlpha")) or a
        if type(hc) == "table" then r, g, b = hc[1] or r, hc[2] or g, hc[3] or b end
        glowMode = getSetting(f.baseUnit, "healGlow") or "off"
        glowStr = tonumber(getSetting(f.baseUnit, "healGlowAlpha")) or 0.6
        glowEdge = getSetting(f.baseUnit, "healBorder") and true or false
    elseif bar == f.hpTrail then
        -- recent damage (Trail texture, Trail colour, Opacity). Default: the health bar's own fill, red.
        local key = getSetting(f.baseUnit, "damageTrailTexture") or "default"
        if key ~= "default" then
            local own = resolveTexture(key)
            if own then tex, grey = own, false end
        end
        local dc = getSetting(f.baseUnit, "damageTrailColor")
        a = tonumber(getSetting(f.baseUnit, "damageTrailAlpha")) or a
        if type(dc) == "table" then r, g, b = dc[1] or r, dc[2] or g, dc[3] or b end
    end
    local wantMask = f.hpMaskOn and true or false
    local styleSame = bar.styleTex == tex and bar.styleGrey == grey and bar.styleStripe == striped
        and bar.styleR == r and bar.styleG == g and bar.styleB == b and bar.styleA == a
        and bar.styleGlow == glowMode and bar.styleGlowA == glowStr and bar.styleEdge == glowEdge
        and (not wantMask or bar.masked)
    if not styleSame then
        bar.styleTex, bar.styleGrey, bar.styleStripe = tex, grey, striped
        bar.styleR, bar.styleG, bar.styleB, bar.styleA = r, g, b, a
        bar.styleGlow, bar.styleGlowA, bar.styleEdge = glowMode, glowStr, glowEdge
        if bar.tex ~= tex then
            bar.tex = tex
            if not pcall(bar.SetStatusBarTexture, bar, tex) or not bar:GetStatusBarTexture() then bar:SetStatusBarTexture(PLAIN_FILL) end
            bar.masked, bar.grey = nil, nil
            -- (the stripes repeat along the bar; anything else stretches)
            local tx = bar:GetStatusBarTexture()
            if tx then pcall(tx.SetHorizTile, tx, striped); pcall(tx.SetVertTile, tx, striped) end
        end
        bar:SetStatusBarColor(r, g, b, a)
        if bar.grey ~= grey then
            local tx = bar:GetStatusBarTexture()
            if tx then tx:SetDesaturated(grey); bar.grey = grey end
        end
        if wantMask and not bar.masked then
            bar.masked = true
            pcall(function() bar:GetStatusBarTexture():AddMaskTexture(f.hpMask) end)
        end
    end
    -- Heal / shield glow: always ensure (cheap when already live). Texture cache alone used to skip
    -- this after a no-fill or hidden-UI first pass, so animations never started until options changed.
    if glowMode ~= nil then
        local ok, err = pcall(ns.barGlow, bar, glowMode, r, g, b, glowStr, glowEdge)
        if not ok and not ns.glowErr then          -- (said once, so a broken glow isn't silent)
            ns.glowErr = true
            print("|cffffd100Webby Frames|r glow: " .. tostring(err))
        end
    end
end

-- A glow on a heal or shield bar, over its fill only (a frame clipped to the fill texture, so it's
-- exactly where the heal or shield is, however its amount is hidden from addons):
--   pulse: a soft wash in its colour, breathing in and out (an animation: no Lua while it runs);
--   shimmer: a band of light sweeping across it, about once a second;
--   snow: a snowglobe. Glowing flakes float in it, bobbing and drifting; when it changes
--   (barGlowShake: a shield gained or hit, a heal coming in) they swirl up and settle again;
--   blizzard: a snowstorm. Lots of small flakes driven down and across by the wind.
-- border: a glowing edge round it as well (or on its own): ns.barGlowEdge.
-- Called on every restyle, so it only does anything when the look has changed.
local GLOW_FLAKES = { snow = 48, blizzard = 90 }
function ns.barGlow(bar, mode, r, g, b, strength, border)
    local fx = bar.wfFx
    local fill = bar:GetStatusBarTexture()
    if not GLOW_FLAKES[mode] and mode ~= "pulse" and mode ~= "shimmer" then mode = "off" end
    -- (the bar hangs off the health fill, so its size can be secret: then the overlay holder's)
    local w, h
    for _, region in ipairs({ bar, bar:GetParent() }) do
        local ok, rw, rh = pcall(region.GetSize, region)
        if ok and rw and rh and not isSecret(rw) and not isSecret(rh) then w, h = rw, rh; break end
    end
    w, h = math.max(w or 100, 1), math.min(math.max(h or 10, 1), 40)
    -- The glow is light added on top, so the wash is in the bar's own colour: it brightens it
    -- without bleaching it (anything paler added over the bar turns it white). The band, the
    -- flakes and the border are small, so they can be a little paler, to read as light. Glow
    -- strength 0 is a faint glow, 100 full.
    local cr, cg, cb = 0.3 + r * 0.7, 0.3 + g * 0.7, 0.3 + b * 0.7
    if mode == "off" or not fill then
        ns.barGlowEdge(bar, fill, false, cr, cg, cb, 0.3 + 0.7 * strength, h)
        if fx then fx:Hide(); fx.sig = nil end
        return
    end
    -- Same look and already shown: keep the edge in sync, revive animations that Play() missed while
    -- the UI was hidden (/reload), and leave flakes alone (OnUpdate keeps them moving).
    local sig = mode .. math.floor(r * 50) .. math.floor(g * 50) .. math.floor(b * 50) .. math.floor(strength * 20) .. math.floor(w) .. math.floor(h)
    if fx and fx.sig == sig and fx:IsShown() and fx.fill == fill then
        ns.barGlowEdge(bar, fill, border and true or false, cr, cg, cb, 0.3 + 0.7 * strength, h)
        if mode == "pulse" and fx.washAg and not fx.washAg:IsPlaying() then fx.washAg:Play() end
        if mode == "shimmer" and fx.band then fx.band:Show() end
        if GLOW_FLAKES[mode] then
            fx.snowing = true
            fx.flakes = GLOW_FLAKES[mode]
            if not fx:GetScript("OnUpdate") then
                fx:SetScript("OnUpdate", function(self, dt) ns.barGlowSnow(self, bar, dt) end)
            end
        end
        return
    end
    ns.barGlowEdge(bar, fill, border and true or false, cr, cg, cb, 0.3 + 0.7 * strength, h)
    if not fx then
        fx = CreateFrame("Frame", nil, bar)
        fx:Hide()          -- (shown once it's coloured: never a bare white wash)
        fx:SetFrameLevel(bar:GetFrameLevel() + 1)
        fx:SetClipsChildren(true)
        fx.wash = fx:CreateTexture(nil, "OVERLAY")
        fx.wash:SetAllPoints()
        fx.wash:SetTexture("Interface\\Buttons\\WHITE8X8")
        fx.wash:SetBlendMode("ADD")
        local ag = fx.wash:CreateAnimationGroup()
        ag:SetLooping("BOUNCE")
        local a = ag:CreateAnimation("Alpha")
        a:SetFromAlpha(0)
        a:SetToAlpha(0.75)
        a:SetDuration(0.9)
        pcall(a.SetSmoothing, a, "IN_OUT")
        fx.washAg = ag
        -- (the shimmer: a spark the size of the fill, its texture scrolled through it, so it
        -- crosses the heal or shield end to end however wide that is; addons can't know its width)
        fx.band = fx:CreateTexture(nil, "OVERLAY", nil, 1)
        fx.band:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark", "REPEAT", "CLAMP")
        fx.band:SetBlendMode("ADD")
        fx.band:SetAllPoints()
        fx.motes = {}
        fx:SetScript("OnUpdate", function(self, dt) ns.barGlowSnow(self, bar, dt) end)
        -- (back in view, the heal or shield coming back: the pulse going again)
        fx:SetScript("OnShow", function(self)
            if self.mode == "pulse" and not self.washAg:IsPlaying() then self.washAg:Play() end
        end)
        bar.wfFx = fx
    end
    if fx.fill ~= fill then
        fx.fill = fill
        fx:ClearAllPoints()
        fx:SetAllPoints(fill)
    end
    fx.sig = sig
    fx.cr, fx.cg, fx.cb, fx.h, fx.w = cr, cg, cb, h, w
    fx:SetAlpha(0.3 + 0.7 * strength)
    fx.wash:SetVertexColor(r, g, b)
    fx.band:SetVertexColor(cr, cg, cb)
    fx.mode = mode
    -- (shown before its animations start: the game doesn't play them on a hidden frame)
    fx:Show()
    -- pulse: the wash breathing (a faint steady wash under the others)
    if mode == "pulse" then
        fx.washAg:Play()
    else
        fx.washAg:Stop()
        fx.wash:SetAlpha(mode == "shimmer" and 0.1 or 0.15)
    end
    -- shimmer: the band sweeping across (moved by barGlowSnow too)
    if mode == "shimmer" then fx.band:Show() else fx.band:Hide() end
    -- snow and blizzard: the flakes (moved by barGlowSnow, every frame while shown), sized from
    -- the bar's height each time, within limits
    local n = GLOW_FLAKES[mode] or 0
    for i = 1, math.max(n, #fx.motes) do
        local m = fx.motes[i]
        if i <= n then
            if not m then
                m = { tex = fx:CreateTexture(nil, "OVERLAY", nil, 2) }
                m.tex:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
                m.tex:SetBlendMode("ADD")
                m.tex:SetAlpha(0.8)
                fx.motes[i] = m
                m.x, m.y = math.random() * w, (math.random() - 0.5) * h
                m.vx, m.vy, m.phase, m.k = 0, 0, math.random() * 6.28, math.random()
            end
            local size = mode == "blizzard" and math.min(math.max(h * (0.15 + 0.15 * m.k), 2), 4)
                or math.min(math.max(h * (0.3 + 0.25 * m.k), 3), 7)
            m.tex:SetVertexColor(cr, cg, cb)
            m.tex:SetSize(size, size)
            m.tex:SetAlpha(0.8)
            m.lx, m.ly = nil, nil          -- (place again on the next snow step)
            m.tex:Show()
        elseif m then
            m.tex:Hide()
        end
    end
    fx.snowing = n > 0 or nil
    fx.flakes = n
end

-- The border glow: Blizzard's modern spell alert loop: the proc flipbook (6 x 5, 30 frames a second),
-- desaturated and tinted, 1.4 times the height of what it's round, with a faint untinted copy added
-- on top for the sparkle. A bar is long and thin, so the square loop is cut in three, like a
-- button's border: its left half and right half at their true size on the ends, and a sliver of its
-- middle stretched between them, so the ring's corners and sides stay where they belong at any
-- length. (Its frames stepped by hand, as the three slices each show part of the same frame.)
-- Round the heal or shield: in a frame outside the health bar's clipping so it can spill above and
-- below, but cut off at the fill's own ends, so it's only ever as long as the heal or shield (and
-- gone when that's empty: its width is hidden from addons), and at the health bar's ends. Hidden
-- with the bar.
local EDGE_ATLAS = "UI-HUD-ActionBar-Proc-Loop-Flipbook"
function ns.barGlowEdge(bar, fill, on, cr, cg, cb, alpha, h)
    local eg = bar.wfEdge
    if not on then
        if eg then eg.on = nil; eg.sig = nil; eg:Hide() end
        return
    end
    if not eg then
        -- (inside a holder as long as the bar's own clipping, the health bar, but taller: so the glow
        -- spills above and below, never past the bar's ends, where a shield at full health sits)
        -- (the holder hangs off the first frame up that doesn't clip, so nothing cuts it short)
        local clip = bar:GetParent()
        local top = clip
        while top and top:GetParent() and top.DoesClipChildren and top:DoesClipChildren() do top = top:GetParent() end
        local holder = CreateFrame("Frame", nil, top or bar)
        holder:SetClipsChildren(true)
        holder.clip = clip or bar
        eg = CreateFrame("Frame", nil, holder)
        eg.holder = holder
        eg:SetClipsChildren(true)
        eg:Hide()
        -- the atlas's place in its file, for the frames' texture coordinates
        local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(EDGE_ATLAS)
        eg.file = info and (info.file or info.filename)
        eg.L, eg.R = info and info.leftTexCoord or 0, info and info.rightTexCoord or 1
        eg.T, eg.B = info and info.topTexCoord or 0, info and info.bottomTexCoord or 1
        -- left, middle, right: the tinted loop, then the sparkle over it
        eg.parts = {}
        for i = 1, 6 do
            local tex = eg:CreateTexture(nil, "OVERLAY", nil, i > 3 and 7 or 6)
            if eg.file then tex:SetTexture(eg.file) end
            if i > 3 then tex:SetBlendMode("ADD"); tex:SetAlpha(0.35) else tex:SetDesaturated(true) end
            eg.parts[i] = tex
        end
        eg.frame, eg.t = -1, 0
        eg:SetScript("OnUpdate", function(self, dt) ns.barGlowEdgeStep(self, dt) end)
        bar:HookScript("OnShow", function() if eg.on then eg:Show() end end)
        bar:HookScript("OnHide", function() eg:Hide() end)
        bar.wfEdge = eg
    end
    eg.on = true
    if not eg.file then return end
    local sig = math.floor(cr * 50) .. math.floor(cg * 50) .. math.floor(cb * 50) .. math.floor(alpha * 20) .. math.floor(h) .. tostring(fill)
    if eg.sig ~= sig then
        eg.sig = sig
        local pad = h * 0.2           -- (1.4 times the height: 0.2 of it all round)
        local half = h * 0.7          -- (each end: half the square loop)
        local holder = eg.holder
        holder:SetFrameLevel(bar:GetFrameLevel() + 2)
        holder:ClearAllPoints()
        holder:SetPoint("TOPLEFT", holder.clip, "TOPLEFT", 0, pad)
        holder:SetPoint("BOTTOMRIGHT", holder.clip, "BOTTOMRIGHT", 0, -pad)
        eg:SetFrameLevel(bar:GetFrameLevel() + 2)
        eg:ClearAllPoints()
        eg:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, pad)
        eg:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, -pad)
        for i = 0, 3, 3 do
            local l, m, r = eg.parts[i + 1], eg.parts[i + 2], eg.parts[i + 3]
            l:ClearAllPoints(); m:ClearAllPoints(); r:ClearAllPoints()
            l:SetPoint("TOPLEFT", fill, "TOPLEFT", -pad, pad)
            l:SetPoint("BOTTOMLEFT", fill, "BOTTOMLEFT", -pad, -pad)
            l:SetWidth(half)
            r:SetPoint("TOPRIGHT", fill, "TOPRIGHT", pad, pad)
            r:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", pad, -pad)
            r:SetWidth(half)
            m:SetPoint("TOPLEFT", l, "TOPRIGHT")
            m:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT")
        end
        for i = 1, 3 do eg.parts[i]:SetVertexColor(cr, cg, cb) end
        eg:SetAlpha(alpha)
        eg.frame = -1
    end
    if bar:IsShown() and not eg:IsShown() then eg:Show() end
end

-- The border glow's next frame: the same cell of the 5 x 6 loop on each slice (its left half, a
-- sliver of its middle, its right half).
function ns.barGlowEdgeStep(eg, dt)
    eg.t = (eg.t + (dt or 0)) % 1
    local n = math.floor(eg.t * 30)
    if n == eg.frame then return end
    eg.frame = n
    local cw, ch = (eg.R - eg.L) / 5, (eg.B - eg.T) / 6
    local u, v = eg.L + (n % 5) * cw, eg.T + math.floor(n / 5) * ch
    local mid = u + cw * 0.5
    for i = 0, 3, 3 do
        eg.parts[i + 1]:SetTexCoord(u, mid, v, v + ch)
        eg.parts[i + 2]:SetTexCoord(mid - cw * 0.01, mid + cw * 0.01, v, v + ch)
        eg.parts[i + 3]:SetTexCoord(mid, u + cw, v, v + ch)
    end
end

-- One frame of the shimmer or the snow.
-- Shimmer: the spark sweeps left to right across the fill in 0.6s, then a half-second rest. The
-- texture shows half its width across the fill, so the one spark in it crosses from just off the
-- left end to just off the right (the copies either side of it stay out of view).
-- Snowglobe: the flakes float, sinking slowly as they bob and drift, and wrap round to the top.
-- Blizzard: the flakes are driven down and across by the wind, wrapping round.
-- Either way a shake throws them up and sideways, and they slow back down.
function ns.barGlowSnow(fx, bar, dt)
    if fx.mode == "shimmer" then
        local t = GetTime() % 1.1
        local p = t < 0.6 and (-0.4 + 1.8 * t / 0.6) or -0.4
        local a = 0.5 - 0.5 * p
        fx.band:SetTexCoord(a, a + 0.5, 0, 1)
        return
    end
    if not fx.snowing then return end
    dt = math.min(dt or 0.016, 0.05)
    local h, w = fx.h or 10, fx.w or 100
    local now = GetTime()
    local storm = fx.mode == "blizzard"
    local fall, wind = storm and h * 4 or h * 0.12, storm and h * 3 or 0
    local sway, bob = storm and h * 0.3 or h * 0.7, storm and 0 or h * 0.5
    if fx.shook then
        fx.shook = nil
        for i = 1, fx.flakes do
            local m = fx.motes[i]
            m.vy = h * (1.5 + math.random() * 2.5) + (storm and fall or 0)
            m.vx = (math.random() - 0.5) * h * 6
        end
    end
    local damp = math.max(0, 1 - 2.2 * dt)
    for i = 1, fx.flakes do
        local m = fx.motes[i]
        m.vy = (m.vy + fall) * damp - fall
        m.vx = m.vx * damp
        m.x = m.x + (m.vx + wind + math.sin(now * 0.9 + m.phase) * sway) * dt
        m.y = m.y + (m.vy + math.cos(now * 1.3 + m.phase * 1.7) * bob) * dt
        if m.y < -h * 0.7 then m.y = h * 0.7; m.x = math.random() * w end
        if m.y > h * 0.9 then m.y = h * 0.9; m.vy = -m.vy * 0.4 end
        if m.x < 0 then m.x = m.x + w elseif m.x > w then m.x = m.x - w end
        -- Layout only when the flake has moved about a pixel (motion math still runs every frame).
        if not m.lx or math.abs(m.x - m.lx) >= 0.5 or math.abs(m.y - m.ly) >= 0.5 then
            m.lx, m.ly = m.x, m.y
            m.tex:ClearAllPoints()
            m.tex:SetPoint("CENTER", fx, "LEFT", m.x, m.y)
        end
    end
end

-- The heal or shield changed: shake the snow.
function ns.barGlowShake(bar)
    local fx = bar and bar.wfFx
    if fx and fx.snowing then fx.shook = true end
end

local function value(fn, u)
    local ok, v = pcall(fn, u)
    if ok then return v end
end

-- Blizzard's heal prediction calculator (12.x): incoming heals clamped to the unit's health, and
-- whether shields are more than the missing health. nil on clients without it.
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
                -- shields clamped to the missing health: its second answer is then "more shield than
                -- missing health" (the overshield), which lights the glow at the bar's end
                if calc.SetDamageAbsorbClampMode and E.UnitDamageAbsorbClampMode then
                    calc:SetDamageAbsorbClampMode(E.UnitDamageAbsorbClampMode.MissingHealth)
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
        f.healBar = newOverlay(f, 0.1, 0.9, 0.3, 0.6)          -- incoming heals, everyone's: green
        -- Shields, in two parts, each in a frame that clips it (the shield's amount can be hidden from
        -- addons, so both parts are given all of it, and the clipping shows the right share of each):
        --   absorbBar: in the missing health, after the heals (missClip: the fill's end to the bar's end);
        --   absorbBack: what doesn't fit, back over the health from the bar's right end (curClip: the
        --   bar's start to the fill's end). (Laid out by placeShields.)
        f.missClip = CreateFrame("Frame", nil, f.predClip)
        f.missClip:SetClipsChildren(true)
        f.missClip:SetFrameLevel(f.predClip:GetFrameLevel())
        f.curClip = CreateFrame("Frame", nil, f.predClip)
        f.curClip:SetClipsChildren(true)
        f.curClip:SetFrameLevel(f.predClip:GetFrameLevel())
        f.absorbBar = newOverlay(f, 0.7, 0.9, 1, 0.7)          -- shields: pale blue
        f.absorbBar:SetParent(f.missClip)
        f.absorbBack = newOverlay(f, 0.7, 0.9, 1, 0.7)
        f.absorbBack:SetParent(f.curClip)
        -- the overshield: Blizzard's glow at the bar's end while shields are more than the missing health
        f.overGlow = f.hp:CreateTexture(nil, "OVERLAY", nil, 7)
        f.overGlow:SetTexture("Interface\\RaidFrame\\Shield-Overshield")
        f.overGlow:SetBlendMode("ADD")
        f.overGlow:SetWidth(12)
        f.overGlow:SetPoint("TOPRIGHT", f.hp, "TOPRIGHT", 6, 2)
        f.overGlow:SetPoint("BOTTOMRIGHT", f.hp, "BOTTOMRIGHT", 6, -2)
        f.overGlow:SetAlpha(0)
    end
    f.predBars = f.predBars or { f.healBar, f.absorbBar, f.absorbBack }
    for _, bar in ipairs(f.predBars) do styleOverlay(f, bar) end
    local u = f.wfUnit
    local fill = f.hp:GetStatusBarTexture()
    local healTex = f.healBar:GetStatusBarTexture()
    local w = f.hp:GetWidth()
    -- The anchors sit on the health fill, which already moves. Re-anchor only when that fill, the
    -- heal texture or the bar width changes.
    if fill and healTex and (f.predFill ~= fill or f.predHealTex ~= healTex or f.predW ~= w) then
        f.predFill, f.predHealTex, f.predW = fill, healTex, w
        -- the heals start at the end of the health fill
        f.healBar:ClearAllPoints()
        f.healBar:SetPoint("TOPLEFT", fill, "TOPRIGHT")
        f.healBar:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT")
        f.healBar:SetWidth(w)
        ns.placeShields(f, fill, healTex, w)
    end

    local max = value(UnitHealthMax, u)
    local dead = unitStatus(u) ~= nil
    for _, bar in ipairs(f.predBars) do
        if max then pcall(bar.SetMinMaxValues, bar, 0, max) end
    end
    -- incoming heals, everyone's together (through the calculator when the client has it, clamped
    -- like Blizzard's, else the older total)
    local heals
    f.overGlow:SetAlpha(0)          -- (lit again below while there's an overshield)
    if wantHeals and not dead then
        local calc = healCalculator(f)
        local ok = calc and pcall(UnitGetDetailedHealPrediction, u, "player", calc)
        local all
        if ok then
            -- (overshield: the answer may be hidden, so it goes straight to the glow's alpha)
            local okA, _, over = pcall(calc.GetDamageAbsorbs, calc)
            if okA and wantAbsorbs and (isSecret(over) or over ~= nil) and f.overGlow.SetAlphaFromBoolean then
                pcall(f.overGlow.SetAlphaFromBoolean, f.overGlow, over, 0.9, 0)
            end
            ok, all = pcall(calc.GetIncomingHeals, calc)          -- (all, yours, others')
        end
        if ok then heals = all else heals = value(UnitGetIncomingHeals, u) end
    end
    local absorb = (wantAbsorbs and not dead) and value(UnitGetTotalAbsorbs, u) or nil
    -- (a missing value counts as none; the heal bar stays at 0 so the shield still starts at the health end)
    if not pcall(setBarValue, f, f.healBar, heals) then f.healBar:SetValue(0) end
    ns.setShields(f, absorb)
end

-- Where shields go: in the missing health after the heals, and once that's full, what's left grows
-- back over the health from the bar's right end, so the whole shield always shows and never past
-- the bar's end. Both parts are bars the width of the health bar given the whole shield; the
-- clipping frames show the share of each (missClip: the missing health; curClip: the health).
function ns.placeShields(f, fill, healTex, w)
    local hp, fw, ab = f.hp, f.absorbBar, f.absorbBack
    local missClip, curClip = f.missClip, f.curClip
    missClip:ClearAllPoints(); curClip:ClearAllPoints(); fw:ClearAllPoints(); ab:ClearAllPoints()
    missClip:SetPoint("TOPLEFT", fill, "TOPRIGHT")
    missClip:SetPoint("BOTTOMRIGHT", hp, "BOTTOMRIGHT")
    fw:SetPoint("TOPLEFT", healTex, "TOPRIGHT")
    fw:SetPoint("BOTTOMLEFT", healTex, "BOTTOMRIGHT")
    fw:SetWidth(w)
    curClip:SetPoint("TOPLEFT", hp, "TOPLEFT")
    curClip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
    ab:SetReverseFill(true)
    ab:SetPoint("TOPRIGHT", hp, "TOPRIGHT")
    ab:SetPoint("BOTTOMRIGHT", hp, "BOTTOMRIGHT")
    ab:SetWidth(w)
end

-- The shield's amount into both its parts (as placed by placeShields), and its number: at the
-- health bar's right end, in the shield's colour, shown as the health's number is (the frame's
-- Numbers setting: always, on mouseover or never; refreshText).
function ns.setShields(f, absorb)
    if not f.absorbBar then return end
    if not pcall(setBarValue, f, f.absorbBar, absorb) then f.absorbBar:SetValue(0) end
    if not pcall(setBarValue, f, f.absorbBack, absorb) then f.absorbBack:SetValue(0) end
    local fs = f.shieldText
    if not fs and f.hpText then
        fs = f.hpText:GetParent():CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        fs:SetPoint("RIGHT", f.hp, "RIGHT", -3, 0)
        fs:SetJustifyH("RIGHT")
        fs:Hide()
        f.shieldText = fs
        if refreshText then refreshText(f) end      -- (shown now if its Numbers setting is Always)
    end
    if not fs then return end
    local font, size, flags = f.hpText:GetFont()
    if font then pcall(fs.SetFont, fs, font, size, flags) end
    local c = getSetting(f.baseUnit, "absorbColor")
    if type(c) ~= "table" then c = { 0.7, 0.9, 1 } end
    fs:SetTextColor(0.5 + (c[1] or 1) * 0.5, 0.5 + (c[2] or 1) * 0.5, 0.5 + (c[3] or 1) * 0.5)
    -- (none: no number. A hidden amount can't be checked for none, so the game writes it, blank
    -- when it's none, where it can; else as it is)
    local text = ""
    if isSecret(absorb) then
        local su = C_StringUtil
        local ok, s = false, nil
        if su and su.TruncateWhenZero then ok, s = pcall(su.TruncateWhenZero, absorb) end
        if not ok then ok, s = pcall(AbbreviateLargeNumbers, absorb) end
        if ok then text = s end
    elseif type(absorb) == "number" and absorb > 0 then
        text = AbbreviateLargeNumbers(absorb)
    end
    if not pcall(fs.SetText, fs, text) then fs:SetText("") end
end

-- Damage trail: when health drops, the part just lost stays on the bar for a moment, then slides
-- away. A bar under the health fill (createDamageTrail) that keeps the old health and follows the new
-- after a short wait, so it shows only where the fill has gone. Secret-safe: values only go to setters.
-- (Healing needs nothing: the fill grows over it, and it catches up underneath.)
-- The mana trail uses the same wait. Recent damage reads its own delay and scales the cap with it
-- (0.4s stays a 1s cap), so a longer delay is not cut short under steady damage.
local TRAIL_WAIT, TRAIL_MAXWAIT = 0.4, 1.0     -- seconds after the last hit; at most this long under steady damage

local function createDamageTrail(f)
    -- (inside a frame that clips it to the bar past the health fill's end, so it never shows behind a
    -- see-through fill: Health bar opacity; anchored by updateDamageTrail, which follows the fill)
    local clip = CreateFrame("Frame", nil, f)
    clip:SetClipsChildren(true)
    clip:SetFrameLevel(f.hp:GetFrameLevel())
    clip:SetAllPoints(f.hp)
    local t = CreateFrame("StatusBar", nil, clip)
    t:SetAllPoints(f.hp)
    t:SetFrameLevel(clip:GetFrameLevel())
    t.clip = clip
    f.hp:SetFrameLevel(t:GetFrameLevel() + 1)       -- (the health fill draws over it)
    t:SetStatusBarTexture(PLAIN_FILL)
    t.color = { 1, 0.15, 0.1, 0.9 }
    t:SetMinMaxValues(0, 1)
    t:SetValue(0)
    t:Hide()
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
-- Cached by spell id. The same cast does not parse its tooltip twice.
local function spellDamage(spell)
    local cache = ns.spellDamageCache
    if not cache then cache = {}; ns.spellDamageCache = cache end
    local hit = cache[spell]
    if hit ~= nil then return hit.amount, hit.line end
    local function num(s) return tonumber((s:gsub(",", ""))) end
    local foundAmount, foundLine
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
        if ok and amount and amount > 0 then foundAmount, foundLine = math.floor(amount + 0.5), text; break end
    end
    cache[spell] = { amount = foundAmount, line = foundLine }
    return foundAmount, foundLine
end

-- One hit of a channelled spell's damage or healing (kind: "damage" or "heal"), from its tooltip: a
-- missile, a wave, a tick (as spellDamage reads it; a total "over 3 sec" split into its ticks). Shown
-- for the whole channel at the end of the health, so it moves down as each hit lands, the damage
-- trail showing the one that just did. nil when the tooltip says none.
function ns.channelAmount(spell, kind)
    local cache = ns.channelCache
    if not cache then cache = {}; ns.channelCache = cache end
    local key = tostring(spell) .. kind
    if cache[key] ~= nil then return cache[key] or nil end
    local found = false
    local function num(s) return tonumber((s:gsub(",", ""))) end
    for _, text in ipairs(tooltipLines(spell)) do
        local ok, amount = pcall(function()
            local lower = text:lower()
            local at = lower:find(kind == "heal" and "heal" or "damage", 1, true)
            if not at then return nil end
            local before = lower:sub(1, at)
            local each
            local lo, hi
            for a, b in before:gmatch("(%d[%d,]*) to (%d[%d,]*)") do lo, hi = a, b end
            if lo then each = (num(lo) + num(hi)) / 2
            else
                local last
                for a in before:gmatch("(%d[%d,]*)") do last = a end
                each = last and num(last)
            end
            if not each then return nil end
            -- (a total "over 3 sec" is split into its ticks, one a second)
            local over = lower:match("over ([%d%.]+) sec")
            if over and not lower:find("each", 1, true) and not lower:find("every", 1, true) and not lower:find("wave", 1, true) then
                local secs = tonumber(over)
                if secs and secs >= 1 then each = each / math.floor(secs + 0.5) end
            end
            return each
        end)
        if ok and amount and amount > 0 then found = math.floor(amount + 0.5); break end
    end
    cache[key] = found
    return found or nil
end

local function updateDamagePrediction(f, spell, channel)
    if not (f and f.hp) then return end
    local amount
    if spell and getSetting(f.baseUnit, "damagePredict") then
        local hostile = false
        pcall(function() hostile = UnitCanAttack("player", f.wfUnit) and true or false end)
        if hostile then
            local line
            if channel then amount = ns.channelAmount(spell, "damage"); line = "one hit of the channel"
            else amount, line = spellDamage(spell) end
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

ns.DMG_UNITS = { "target", "focus" }
local function flyDamage(spell)
    local token = {}
    for _, unit in ipairs(ns.DMG_UNITS) do
        local f = frames[unit]
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
        for _, unit in ipairs(ns.DMG_UNITS) do
            local f = frames[unit]
            if f and f.dmgFlying == token then landDamage(f) end
        end
    end)
end

-- Your own channelled heal (Penance): the game's incoming heals leave channels out, so while you
-- channel one, its next hit's healing (ns.channelAmount) is shaded after the incoming heals, on whoever
-- it's going to: your target when it's friendly, else you. Gone when the channel ends. Only where
-- Incoming heals is on. spell nil: none.
function ns.channelHeal(spell)
    local who
    if spell then
        local friend = false
        pcall(function() friend = UnitExists("target") and UnitCanAssist("player", "target") and true or false end)
        who = friend and frames.target or frames.player
    end
    local amount = spell and ns.channelAmount(spell, "heal") or nil
    for _, f in ipairs({ frames.player, frames.target }) do
        local bar = f and f.chanHeal
        if f == who and amount and f.healBar and getSetting(f.baseUnit, "healPrediction") then
            if not bar then
                bar = CreateFrame("StatusBar", nil, f.predClip)
                bar:SetFrameLevel(f.predClip:GetFrameLevel() + 1)
                bar:SetStatusBarTexture(PLAIN_FILL)
                f.chanHeal = bar
            end
            local c = getSetting(f.baseUnit, "healColor")
            if type(c) ~= "table" then c = { 0.1, 0.9, 0.3 } end
            bar:SetStatusBarColor(0.4 + (c[1] or 0) * 0.6, 0.4 + (c[2] or 1) * 0.6, 0.4 + (c[3] or 0) * 0.6, 0.55)
            local healTex = f.healBar:GetStatusBarTexture()
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT", healTex, "TOPRIGHT")
            bar:SetPoint("BOTTOMLEFT", healTex, "BOTTOMRIGHT")
            bar:SetWidth(f.hp:GetWidth())
            local max = value(UnitHealthMax, f.wfUnit)
            if max then pcall(bar.SetMinMaxValues, bar, 0, max) end
            pcall(bar.SetValue, bar, amount)
            bar:Show()
        elseif bar then
            bar:Hide()
        end
    end
end

-- Runs only while a trail is waiting to catch up. A shown bar with no script costs nothing per frame.
local function followTrail(self, elapsed)
    self.wait = self.wait - elapsed
    self.waited = self.waited + elapsed
    -- (recent damage sets its own cap from Delay; the mana trail keeps TRAIL_MAXWAIT)
    local cap = self.maxWait or TRAIL_MAXWAIT
    if self.wait > 0 and self.waited < cap then return end
    self.pending = false
    self:SetScript("OnUpdate", nil)
    if not (SMOOTH and pcall(self.SetValue, self, self.target, SMOOTH)) then pcall(self.SetValue, self, self.target) end
end

local function updateDamageTrail(f, status)
    local t = f.hpTrail
    if not t then return end
    if not getSetting(f.baseUnit, "damageTrail") then
        t.pending = false
        t:SetScript("OnUpdate", nil)
        t:Hide()
        return
    end
    styleOverlay(f, t)
    -- the clip starts where the health fill ends (re-anchored when the fill texture changes)
    local fill = f.hp:GetStatusBarTexture()
    if fill and t.clipFill ~= fill then
        t.clipFill = fill
        t.clip:ClearAllPoints()
        t.clip:SetPoint("TOPLEFT", fill, "TOPRIGHT")
        t.clip:SetPoint("BOTTOMRIGHT", f.hp, "BOTTOMRIGHT")
    end
    local u = f.wfUnit
    local max = value(UnitHealthMax, u)
    if max then pcall(t.SetMinMaxValues, t, 0, max) end
    local now = value(UnitHealth, u)
    -- someone else in the frame (new target), or dead / offline: straight to the new health, no trail
    local _, who = pcall(UnitGUID, u)
    local fresh = false
    if not isSecret(who) and not isSecret(t.who) then fresh = (who ~= t.who) end
    t.who = who
    if fresh or status then
        t.pending = false
        t:SetScript("OnUpdate", nil)
        pcall(t.SetValue, t, now or 0)
    else
        t.target = now
        if not t.pending then
            t.pending, t.waited = true, 0
            t:SetScript("OnUpdate", followTrail)
        end
        -- Delay: how long a hit stays. The cap keeps the old ratio (0.4s waited at most 1s).
        local delay = tonumber(getSetting(f.baseUnit, "damageTrailDelay")) or TRAIL_WAIT
        if delay < 0 then delay = 0 elseif delay > 2 then delay = 2 end
        t.wait = delay
        t.maxWait = delay * (TRAIL_MAXWAIT / TRAIL_WAIT)
    end
    t:Show()
end


local function updateHealth(f, lite)
    if f.previewing then return end            -- /webby test is showing made-up values
    local u = f.wfUnit
    if not UnitExists(u) then return end
    local status = unitStatus(u)
    -- Class and reaction colour do not follow the health number. Fade and "by health" do.
    -- colorHold is cleared when the unit, faction or settings change (updateAll, setSetting).
    if status ~= f.statusText then f.colorHold = nil end
    local base = f.baseUnit
    local liveColor = not otherPlayer(u) and (getSetting(base, "healthFade") or getSetting(base, "colorMode") == "gradient")
    if liveColor or not f.colorHold then
        updateHealthColor(f)
        if not liveColor then f.colorHold = true end
    end
    local hpTex = f.hp:GetStatusBarTexture()
    if hpTex then hpTex:SetAlpha(tonumber(getSetting(f.baseUnit, "hpAlpha")) or 1) end
    f.hp:SetMinMaxValues(0, UnitHealthMax(u))
    if status == "Offline" then
        -- offline: a full grey bar, as the default UI does
        setBarValue(f, f.hp, UnitHealthMax(u))
        f.hp:SetStatusBarColor(0.5, 0.5, 0.5, 1)
        if hpTex then hpTex:SetDesaturated(true); hpTex:SetAlpha(tonumber(getSetting(f.baseUnit, "hpAlpha")) or 1) end
    else
        setBarValue(f, f.hp, UnitHealth(u))
    end
    -- lite: the target-of-target poll. Prediction and the damage trail already return immediately
    -- when their options are off; skip the call too. nil means the flags are not set yet (still do it).
    if not lite or f.wantPred ~= false then pcall(updatePrediction, f) end
    if not lite or f.wantTrail ~= false then pcall(updateDamageTrail, f, status) end
    -- the damage shading belongs to the unit it was cast at: gone if the frame now shows someone else
    if not lite and f.dmgBar and f.dmgBar:IsShown() then
        pcall(function()
            if f.dmgWho ~= UnitGUID(u) then f.dmgFlying = nil; f.dmgBar:Hide() end
        end)
    end
    -- "off" hides the number, so the percent / abbreviate work is wasted. Dead / Ghost / Offline still shows.
    if status then f.hpText:SetText(status)
    elseif f.textMode ~= "off" then setBarText(f.hpText, f, "hp") end
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

-- The cost of a spell in your current power type, or nil. Cached by spell and power type: a cast
-- asks on every power tick. The /webby cost text is built when that command runs (ns.costReport).
local function spellCost(spell)
    if not spell then return nil end
    local ptype = UnitPowerType("player")
    if isSecret(ptype) then ptype = nil end
    local cache = ns.spellCosts
    if not cache then cache = {}; ns.spellCosts = cache end
    local hit = ptype ~= nil and cache[spell]
    if hit and hit.ptype == ptype then return hit.cost end
    local cost
    pcall(function()
        local get = (C_Spell and C_Spell.GetSpellPowerCost) or GetSpellPowerCost
        if not get then return end
        local pt = UnitPowerType("player")
        local list = get(spell)
        for _, c in ipairs(list or {}) do
            local amount = c.cost or c.minCost
            if c.type == pt and amount and amount > 0 then cost = amount end
        end
    end)
    if ptype ~= nil then cache[spell] = { ptype = ptype, cost = cost } end
    return cost
end

-- What /webby cost prints. Not used while casting.
function ns.costReport(spell)
    if not spell then return "none yet (cast something with a cast time, then try again)" end
    local lines = "spell " .. tostring(spell)
    local ok, err = pcall(function()
        local get = (C_Spell and C_Spell.GetSpellPowerCost) or GetSpellPowerCost
        if not get then lines = lines .. ": no cost API"; return end
        local ptype = UnitPowerType("player")
        local list = get(spell)
        lines = lines .. ", power type " .. tostring(ptype) .. ", costs:"
        for _, c in ipairs(list or {}) do
            lines = lines .. " [type " .. tostring(c.type) .. " cost " .. tostring(c.cost or c.minCost) .. "]"
        end
    end)
    if not ok then lines = lines .. " (error: " .. tostring(err) .. ")" end
    local cost = spellCost(spell)
    return lines .. (cost and (" -> shown " .. tostring(cost)) or " -> nothing to show")
end

-- Fits one of the cost bars to the power bar: its fill, mask and length, its end on the fill's end.
local function fitCostBar(f, bar, side)
    -- Cost texture, or the power bar's own fill, tinted the way heals and shields are. The power
    -- bar's own art is desaturated only once a cost colour is picked, so that colour tints a neutral
    -- fill. A chosen texture keeps its own art.
    local key = getSetting("player", "costTexture") or "default"
    local own = key ~= "default" and resolveTexture(key) or nil
    local tex = own or f.mpCurrent or PLAIN_FILL
    local grey = not own and type(getSetting("player", "costColor")) == "table"
    if bar.tex ~= tex then
        bar.tex = tex
        bar.grey = nil
        if not pcall(bar.SetStatusBarTexture, bar, tex) or not bar:GetStatusBarTexture() then bar:SetStatusBarTexture(PLAIN_FILL) end
        if f.mpMaskOn then pcall(function() bar:GetStatusBarTexture():AddMaskTexture(f.mpMask) end) end
    end
    local tx = bar:GetStatusBarTexture()
    if tx then
        pcall(tx.SetBlendMode, tx, "BLEND")
        if bar.grey ~= grey then pcall(tx.SetDesaturated, tx, grey); bar.grey = grey end
    end
    bar:ClearAllPoints()
    bar:SetPoint("TOP", f.mp, "TOP")
    bar:SetPoint("BOTTOM", f.mp, "BOTTOM")
    bar:SetPoint(side, f.mp:GetStatusBarTexture(), "RIGHT")
    bar:SetWidth(f.mp:GetWidth())
    -- (the bar's own max: with Druid bars "Mana first" that's your mana, not the form's power)
    pcall(bar.SetMinMaxValues, bar, 0, f.mpMaxNow or UnitPowerMax("player"))
end

-- Shades a cost bar by the "Spell cost shade" slider (-100 to 100). The cast preview is tinted like
-- a heal or shield: the colour multiplies the fill, so a texture and a colour both show. Below 0 it
-- darkens (black laid over). The trail of what was spent (`flash`) still lightens by adding its colour.
-- False at 0 (nothing to show).
local function shadeCostBar(bar, flash)
    local v = tonumber(getSetting("player", "costShade")) or 55
    if v == 0 and not flash then return false end
    local a = math.min(1, math.abs(v) / 100 + (flash and 0.25 or 0))
    local tex = bar:GetStatusBarTexture()
    if not tex then return false end
    local c = getSetting("player", flash and "costTrailColor" or "costColor")
    if type(c) ~= "table" then c = { 1, 1, 1 } end
    if flash or v > 0 then
        if flash then pcall(tex.SetBlendMode, tex, "ADD") end
        bar:SetStatusBarColor(c[1] or 1, c[2] or 1, c[3] or 1, a)
    else
        pcall(tex.SetBlendMode, tex, "BLEND")
        bar:SetStatusBarColor(0, 0, 0, a)
    end
    return true
end

-- The glow on the cost while you cast (Cost glow), in its colour. Off when the preview hides.
local function glowCostBar(bar, on)
    if not ns.barGlow then return end
    local c = getSetting("player", "costColor")
    if type(c) ~= "table" then c = { 1, 1, 1 } end
    local mode = on and (getSetting("player", "costGlow") or "off") or "off"
    local s = tonumber(getSetting("player", "costGlowAlpha")) or 0.6
    pcall(ns.barGlow, bar, mode, c[1] or 1, c[2] or 1, c[3] or 1, s, false)
end

local function updateCostPrediction(f)
    local cp = f.costBar
    if not cp then return end
    local cost
    -- (the spell being cast; or, just after it went off, it still, until the mana actually drops and
    -- the trail takes over: no gap between the two)
    local spell = f.castSpell or (f.costHold and f.costHold.spell)
    if spell and getSetting("player", "costPredict") then
        cost = spellCost(spell)
        f.costSpell = spell
    end
    if not cost then glowCostBar(cp, false); cp:Hide(); return end
    fitCostBar(f, cp, "RIGHT")
    if not shadeCostBar(cp) then glowCostBar(cp, false); cp:Hide(); return end
    pcall(cp.SetValue, cp, cost)
    cp:Show()
    glowCostBar(cp, true)
end

-- The mana trail: when your power drops, the part just spent stays lit (in the cost shading) where it
-- was, with the bar's end sliding down over it; a moment later it slides away too. Like the health
-- bar's recent damage (updateDamageTrail): a bar under the power fill that keeps the old value,
-- clipped to past the fill's end, so it's always exactly the part just spent, however the fill
-- animates. (It replaced a flash pinned to the fill's end, which slid along with the fill.)
local function updateManaTrail(f, maxP, curP, token)
    local t = f.mpTrail
    if not getSetting("player", "costPredict") then
        t.pending, t.shown = false, nil
        t:SetScript("OnUpdate", nil)
        t:Hide()
        return
    end
    -- (Trail texture, or the power bar's own fill)
    local tex = resolveTexture(getSetting("player", "costTrailTexture")) or f.mpCurrent or PLAIN_FILL
    if t.tex ~= tex then
        t.tex = tex
        if not pcall(t.SetStatusBarTexture, t, tex) or not t:GetStatusBarTexture() then t:SetStatusBarTexture(PLAIN_FILL) end
        if f.mpMaskOn then pcall(function() t:GetStatusBarTexture():AddMaskTexture(f.mpMask) end) end
    end
    if not shadeCostBar(t, true) then t:Hide(); return end
    -- the clip starts where the power fill ends (re-anchored when the fill texture changes)
    local fill = f.mp:GetStatusBarTexture()
    if fill and t.clipFill ~= fill then
        t.clipFill = fill
        t.clip:ClearAllPoints()
        t.clip:SetPoint("TOPLEFT", fill, "TOPRIGHT")
        t.clip:SetPoint("BOTTOMRIGHT", f.mp, "BOTTOMRIGHT")
    end
    pcall(t.SetMinMaxValues, t, 0, maxP)
    -- It never compares numbers (in combat the game can hide your power from addons, and testing a
    -- hidden number fails): the trail just follows your power a moment late. After a drop it still
    -- shows the old amount, lit, past the fill's new end; when it rises the trail is under the fill,
    -- where the clip hides it. A switch of power type (a druid's form) goes straight there.
    f.costHold = nil              -- (the cast preview hands over to it: the power has moved)
    local switched = isSecret(token) or t.token ~= token
    t.token = (not isSecret(token)) and token or nil
    t.target = curP
    if switched then
        t.pending = false
        t:SetScript("OnUpdate", nil)
        pcall(t.SetValue, t, curP)
    else
        if not t.pending then
            t.pending, t.waited = true, 0
            t:SetScript("OnUpdate", followTrail)
        end
        t.wait = TRAIL_WAIT
    end
    t:Show()
end

-- The five second rule, across the whole mana bar: when a spell that costs mana goes off, a light
-- starts at the bar's left end and travels to its right end over 5 seconds (no regen from spirit
-- until then), growing as it goes, a star sparkling in it; there it stops. Another spell starts it
-- over. Its colour, size, sparkle and the sparkle's texture are options (player page, Mana tick).
-- Started from the spell's cost, which the game doesn't hide (your mana it often does, in combat).
local MANA_RULE = 5
-- (the sparkle's textures: the game's own; on ns so the options can list them, ns.MANA_SPARKLE_CHOICES)
ns.MANA_SPARKLES = {
    star = "Interface\\Cooldown\\star4", starburst = "Interface\\Cooldown\\starburst",
    ring = "Interface\\Cooldown\\ping4", spark = "Interface\\CastingBar\\UI-CastingBar-Spark",
    flare = "Interface\\Buttons\\UI-ActionButton-Border",
    raidstar = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1", diamond = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3",
    glow = "Interface\\Buttons\\CheckButtonGlow",
}
ns.MANA_SPARKLE_CHOICES = { { "star", "Star" }, { "starburst", "Starburst" }, { "ring", "Ring" }, { "spark", "Spark" }, { "flare", "Flare" },
    { "raidstar", "Raid star" }, { "diamond", "Diamond" }, { "glow", "Soft glow" } }
local function updateManaTick(f, curP, maxP, isMana)
    local mt = f.manaTick
    if not (isMana and getSetting("player", "manaTick")) then
        if mt then mt:Hide(); mt.clearDust(); mt.dust:Hide(); mt.ruleUntil, mt.opts = nil, nil end     -- (off: a spell won't start it either)
        return
    end
    if not mt then
        mt = CreateFrame("Frame", nil, f.mp)
        mt:SetFrameLevel(f.mp:GetFrameLevel() + 4)
        mt:SetSize(1, 1)
        mt.glow = mt:CreateTexture(nil, "OVERLAY")
        mt.glow:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
        mt.glow:SetBlendMode("ADD")
        mt.glow:SetPoint("CENTER")
        mt.star = mt:CreateTexture(nil, "OVERLAY", nil, 1)
        mt.star:SetBlendMode("ADD")
        mt.star:SetPoint("CENTER")
        -- the sparkle trail: little stars left behind as the light goes, twinkling, drifting and fading
        -- (on a frame of their own, so they stay where they were dropped while the light moves on)
        mt.dust = CreateFrame("Frame", nil, f.mp)
        mt.dust:SetAllPoints(f.mp)
        mt.dust:SetFrameLevel(f.mp:GetFrameLevel() + 4)
        mt.motes = {}
        local function clearDust()
            for _, m in ipairs(mt.motes) do m.tex:Hide(); m.live = false end
        end
        local function dropMote(x, h, c, z, now)
            local m
            for _, o in ipairs(mt.motes) do if not o.live then m = o; break end end
            if not m then
                if #mt.motes >= 24 then return end
                m = { tex = mt.dust:CreateTexture(nil, "OVERLAY") }
                m.tex:SetBlendMode("ADD")
                mt.motes[#mt.motes + 1] = m
            end
            if m.texFile ~= mt.starTex then m.texFile = mt.starTex; m.tex:SetTexture(mt.starTex) end
            m.live, m.born = true, now
            m.life = 0.45 + math.random() * 0.4
            m.x, m.y = x, (math.random() - 0.5) * h * 0.9
            m.drift = (math.random() - 0.5) * h * 0.8          -- (up or down a little as it fades)
            m.size = h * (0.35 + math.random() * 0.45) * z
            m.spin = (math.random() - 0.5) * 6
            m.tex:SetVertexColor(0.6 + c[1] * 0.4, 0.6 + c[2] * 0.4, 0.6 + c[3] * 0.4)
            m.tex:Show()
        end
        local function moveDust(now)
            local any = false
            for _, m in ipairs(mt.motes) do
                if m.live then
                    local a = (now - m.born) / m.life
                    if a >= 1 then
                        m.live = false
                        m.tex:Hide()
                    else
                        -- (a quick twinkle in, then fading and shrinking out)
                        local tw = a < 0.15 and a / 0.15 or 1 - (a - 0.15) / 0.85
                        local s = m.size * (0.6 + 0.4 * tw)
                        m.tex:ClearAllPoints()
                        m.tex:SetPoint("CENTER", mt.dust, "LEFT", m.x, m.y + m.drift * a)
                        m.tex:SetSize(s, s)
                        m.tex:SetAlpha(0.9 * tw)
                        if m.spin ~= 0 then
                            if mt.canSpin == nil then mt.canSpin = pcall(m.tex.SetRotation, m.tex, m.spin * a)
                            elseif mt.canSpin then m.tex:SetRotation(m.spin * a) end
                        end
                        any = true
                    end
                end
            end
            -- (nothing left twinkling: the trail's frame rests until the next star)
            if not any then mt.dust:Hide() end
        end
        -- (the stars fade out on their own, so they finish after the light has stopped)
        -- Every other frame: a mote lives under half a second, and the eye does not catch the skip.
        mt.dust:SetScript("OnUpdate", function()
            mt.dustFlip = not mt.dustFlip
            if mt.dustFlip then return end
            moveDust(GetTime())
        end)
        mt.dust:Hide()
        mt.clearDust = clearDust
        mt:SetScript("OnUpdate", function(self)
            local o, now = self.opts, GetTime()
            -- done: it stops at the bar's end
            if not (o and self.ruleUntil and now < self.ruleUntil) then self:Hide(); return end
            local h, w = f.mp:GetHeight() or 10, f.mp:GetWidth() or 100
            local p = 1 - (self.ruleUntil - now) / MANA_RULE    -- 0 at the left end, 1 at the right
            local k = p * p                                      -- (slow at first, swelling towards the end)
            local c, z = o.color, o.size
            -- (the trail: a new star every few hundredths of a second, more as it speeds up and grows)
            if o.trail and now >= (self.nextMote or 0) then
                dropMote(p * w, h, c, z, now)
                self.dust:Show()
                self.nextMote = now + 0.09 - 0.05 * k
            end
            self:ClearAllPoints()
            self:SetPoint("CENTER", f.mp, "LEFT", p * w, 0)
            self.glow:SetVertexColor(c[1], c[2], c[3])
            self.glow:SetSize((4 + 10 * k) * z, h * (0.9 + 1.1 * k) * z)
            self.glow:SetAlpha(0.3 + 0.7 * k)
            if o.sparkle then
                -- (the star a paler version of the colour)
                self.star:SetVertexColor(0.5 + c[1] / 2, 0.5 + c[2] / 2, 0.5 + c[3] / 2)
                local s = h * (0.5 + 1.5 * k) * z
                self.star:SetSize(s, s)
                self.star:SetAlpha(0.2 + 0.8 * k)
                if self.canSpin == nil then self.canSpin = pcall(self.star.SetRotation, self.star, now * 1.4)
                elseif self.canSpin then self.star:SetRotation(now * 1.4) end
                self.star:Show()
            else
                self.star:Hide()
            end
        end)
        f.manaTick = mt
    end
    -- its options, read here (on every power change and option change), not every frame
    local c = getSetting("player", "manaTickRuleColor")
    -- the sparkle's texture (Sparkle texture); a file this client doesn't have falls back to the star
    local starTex = ns.MANA_SPARKLES[getSetting("player", "manaTickStar") or "star"] or ns.MANA_SPARKLES.star
    if mt.starTex ~= starTex then
        mt.starTex = starTex
        if mt.star:SetTexture(starTex) == false then mt.star:SetTexture(ns.MANA_SPARKLES.star) end
    end
    local sparkle = getSetting("player", "manaTickSparkle") ~= false
    local trailOn = getSetting("player", "manaTickTrail") ~= false
    local size = (tonumber(getSetting("player", "manaTickSize")) or 100) / 100
    local cr, cg, cb = 1, 1, 1
    if type(c) == "table" then cr, cg, cb = c[1] or 1, c[2] or 1, c[3] or 1 end
    local o = mt.opts
    if not (o and o.sparkle == sparkle and o.trail == trailOn and o.size == size and o.cr == cr and o.cg == cg and o.cb == cb) then
        mt.opts = { sparkle = sparkle, trail = trailOn, size = size, cr = cr, cg = cg, cb = cb, color = { cr, cg, cb } }
    end
end

-- A spell went off: if it cost mana, the five second rule starts (over).
function ns.manaSpend(f, spell)
    local mt = f.manaTick
    if not (mt and mt.opts and spell) then return end
    local cost = spellCost(spell)
    if not (cost and cost > 0) then return end
    mt.ruleUntil = GetTime() + MANA_RULE
    mt:Show()
end
local function updatePower(f)
    local u = f.wfUnit
    if not UnitExists(u) then return end
    local _, token = UnitPowerType(u)
    -- a druid in a form, with Druid bars "Mana first": the frame's bar keeps showing mana, and the slim
    -- bar under it the form's rage or energy
    local formToken = token
    local swap = f.altMana and getSetting("player", "druidMana") and getSetting("player", "druidBars") == "mana"
        and not isSecret(token) and token ~= "MANA" and ns.playerClass() == "DRUID"
    local MANA = Enum.PowerType and Enum.PowerType.Mana or 0
    if swap then token = "MANA" end
    local fill, tinted = f.powerTex, true
    if not fill then
        -- the bundled pre-shaped fill for this power type and frame, drawn untinted
        local kind = (not isSecret(token) and token) and POWER_FILE[token] or nil
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
        local c = PowerBarColor and ((not isSecret(token) and token and PowerBarColor[token]) or PowerBarColor[0])
        if c and c.r then pr, pg, pb = c.r, c.g, c.b end
    end
    local mpTex = f.mp:GetStatusBarTexture()
    if mpTex then mpTex:SetDesaturated(false) end
    -- (the opacity after the colour: a bar's colour sets its fill's alpha too)
    f.mp:SetStatusBarColor(pr, pg, pb, 1)
    if mpTex then mpTex:SetAlpha(tonumber(getSetting(f.baseUnit, "mpAlpha")) or 1) end
    if swap then
        f.mp:SetMinMaxValues(0, UnitPowerMax(u, MANA))
        setBarValue(f, f.mp, UnitPower(u, MANA))
        if f.textMode ~= "off" then pcall(f.mpText.SetText, f.mpText, AbbreviateLargeNumbers(UnitPower(u, MANA))) end
    else
        f.mp:SetMinMaxValues(0, UnitPowerMax(u))
        setBarValue(f, f.mp, UnitPower(u))
        if f.textMode ~= "off" then setBarText(f.mpText, f, "mp") end
    end
    -- your own frame: the trail of what was just spent, then the cast's cost (in that order: a drop
    -- ends the preview's hold)
    if f.mpTrail then
        local maxP, curP
        if swap then maxP, curP = UnitPowerMax(u, MANA), UnitPower(u, MANA) else maxP, curP = UnitPowerMax(u), UnitPower(u) end
        f.mpMaxNow = maxP
        pcall(updateManaTrail, f, maxP, curP, token)
        pcall(updateManaTick, f, curP, maxP, not isSecret(token) and token == "MANA")
    end
    if f.costBar then pcall(updateCostPrediction, f) end
    -- a druid in bear or cat form: their mana in the slim bar under the frame
    local am = f.altMana
    if am then
        local show = getSetting("player", "druidMana") and ns.playerClass() == "DRUID"
            and not isSecret(formToken) and formToken ~= "MANA"
        am:SetShown(show and true or false)
        if show then
            -- (the slim bar: mana, or with Mana first the form's own power, in its own fill)
            local file = BAR_FILE.player .. (swap and (POWER_FILE[formToken] or "Rage") or "Mana")
            if am.file ~= file then am.file = file; am.bar:SetStatusBarTexture(file) end
            -- (the values may be hidden: they only go to setters, never tested)
            local maxP, curP
            if swap then maxP, curP = UnitPowerMax("player"), UnitPower("player")
            else maxP, curP = UnitPowerMax("player", MANA), UnitPower("player", MANA) end
            pcall(am.bar.SetMinMaxValues, am.bar, 0, maxP)
            pcall(setBarValue, f, am.bar, curP)
            local okA, txt = pcall(AbbreviateLargeNumbers, curP)
            if okA then pcall(am.text.SetText, am.text, txt) end
            am.text:SetShown((f.textMode or getSetting("player", "textMode")) ~= "off")
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

local function updateLeader(f)
    if not f.leaderIcon then return end
    local lead = false
    pcall(function() lead = UnitIsGroupLeader(f.wfUnit) and true or false end)
    f.leaderIcon:SetShown(lead)
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
    -- Small frames have no level number.
    if f.level then
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
    end
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
    updateLeader(f)
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
        glow:SetBlendMode("ADD")        -- The outline glow doesn't cover the corner accent, so it gets its own: a larger additive halo
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
        -- Blizzard's own pulse (PlayerFrame_OnUpdate): the alpha ramps straight up from 55/255 to full
        -- over half a second, then straight back down, for resting and combat alike. An animation, so
        -- it keeps time while the glow is hidden and costs no Lua while it shows. Colour is ours
        -- (updateIndicators). The same helper drives the dispel glow, so they stay in step when both
        -- were started together.
        if AuraKit.attachPulse then AuraKit.attachPulse(sf); AuraKit.attachPulse(cf) end
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
    -- the player's flag countdown, just left of the shield (no tooltip). Half the level number.
    if f.baseUnit == "player" then
        local fs = ov:CreateFontString(nil, "OVERLAY")
        fs:SetDrawLayer("OVERLAY", 7)
        local p, s = f.level and f.level:GetFont()
        fs:SetFont(p or STANDARD_TEXT_FONT, math.max(6, math.floor(((s or 12) / 2) + 0.5)) + 2, "OUTLINE")
        fs:SetTextColor(1, 1, 1)
        fs:SetJustifyH("RIGHT")
        fs:SetPoint("RIGHT", f.pvpIcon, "LEFT", -2, 0)
        fs:Hide()
        f.pvpTimer = fs
    end
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
        -- or just the number, at the top of the portrait beside the raid marker (placed by placeIndicators)
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

-- "5m" down to "1m", then "59" ... "0". At or above 5:00 is the zone cap, not a countdown.
local function pvpCountdownLabel(ms)
    if type(ms) ~= "number" or ms <= 0 or ms >= 300000 then return nil end
    local sec = ms / 1000
    if sec >= 60 then return math.floor(sec / 60 + 0.5) .. "m" end
    return tostring(math.floor(sec))
end

-- GetPVPTimer sits on 5:00 and jumps back there while you are in a PvP area. The number shows
-- only once that value is actually falling (the five minutes after you leave).
local function syncPvpTimer(f)
    local fs = f.pvpTimer
    if not fs then return end
    if f.baseUnit ~= "player" or not (f.pvpIcon and f.pvpIcon:IsShown()) then
        if f.pvpTicker then f.pvpTicker:Cancel(); f.pvpTicker = nil end
        f.pvpTimerMs, f.pvpTimerAt = nil, nil
        fs.shownLabel = nil
        fs:Hide()
        return
    end
    if not f.pvpTicker then
        f.pvpTicker = C_Timer.NewTicker(0.25, function() syncPvpTimer(f) end)
    end
    local ms
    pcall(function() ms = GetPVPTimer() end)
    local now = GetTime()
    local prev, at = f.pvpTimerMs, f.pvpTimerAt
    f.pvpTimerMs, f.pvpTimerAt = ms, now
    local elapsed = at and (now - at) or 0
    local falling = type(ms) == "number" and type(prev) == "number" and elapsed >= 0.2
        and ms < prev - elapsed * 400
    local label = falling and pvpCountdownLabel(ms) or nil
    if label then
        if fs.shownLabel ~= label then fs.shownLabel = label; fs:SetText(label) end
        fs:Show()
    else
        fs.shownLabel = nil
        fs:Hide()
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
            if f.cornerBack then f.cornerBack:SetShown(cornerOn and getSetting(f.baseUnit, "cornerStyle") ~= "forever") end
        end
        if f.cornerGlow then f.cornerGlow:SetShown(f.corner and f.corner:IsShown() or false) end
        if f.status then
            local resting = false
            pcall(function() resting = IsResting() and true or false end)
            if f.dispelRGB then
                -- a debuff someone can dispel: the glow takes its colour, over combat and resting
                -- (set by AuraKit.paintGlow)
                f.status:SetDesaturated(true)
                f.status:SetVertexColor(f.dispelRGB[1], f.dispelRGB[2], f.dispelRGB[3])
                f.status:Show()
            elseif showC then
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
    local kind, seen = nil, false
    pcall(function()
        if not UnitExists(u) then return end
        seen = true
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
    else
        f.pvpIcon:Hide()
    end
    syncPvpTimer(f)
    -- You becoming flagged: the game's own PvP update sound. A login while already flagged
    -- does not play (there was no unflagged reading yet). Target and focus stay silent.
    if base == "player" and seen then
        local flagged = kind ~= nil
        if f.pvpWas == false and flagged then
            pcall(function()
                if SOUNDKIT and SOUNDKIT.IG_PVP_UPDATE then PlaySound(SOUNDKIT.IG_PVP_UPDATE) end
            end)
        end
        f.pvpWas = flagged
    end
end

-- Threat percentage, the same number as the default target frame. Raw % against whoever the mob is
-- hitting (about 110% pulls in melee, 130% at range) until you are tanking, then the game's own lead
-- (UnitThreatPercentageOfLead), which keeps climbing past 255. No group walk for the number.
-- Colour is the gradient (green to red on the scaled percent) or Blizzard's own threat colours.
-- An older saved choice (status, colourblind, class) reads as the gradient.
local function threatColor(base, status, scaled)
    local r, g, b
    if getSetting(base, "threatColors") == "blizzard" then
        local ok, cr, cg, cb = pcall(GetThreatStatusColor, status)
        if ok then r, g, b = cr, cg, cb end
    elseif not isSecret(scaled) then
        local p = math.max(0, math.min(1, (tonumber(scaled) or 0) / 100))
        if p < 0.5 then r, g, b = p * 2, 1, 0 else r, g, b = 1, 1 - ((p - 0.5) * 2), 0 end
    end
    if not r then r, g, b = 1, 1, 0 end
    return r, g, b
end

-- One roster, rebuilt when the group changes. The solo hide reads it.
local threatRoster = { "pet" }
local function rebuildThreatRoster()
    for i = 2, #threatRoster do threatRoster[i] = nil end
    local n = 1
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            n = n + 1; threatRoster[n] = "raid" .. i
            n = n + 1; threatRoster[n] = "raidpet" .. i
        end
    elseif IsInGroup() then
        for i = 1, GetNumGroupMembers() - 1 do
            n = n + 1; threatRoster[n] = "party" .. i
            n = n + 1; threatRoster[n] = "partypet" .. i
        end
    end
end

-- Your threat on u: status, scaled %, and the % to show. Run inside pcall (the values can be hidden,
-- and testing a hidden one errors): an error means nothing to show.
function ns.readThreat(u, wantNumber)
    if not UnitExists(u) or not UnitCanAttack("player", u) then return end
    -- PvP: players (and their pets and totems) have no threat to show
    if UnitIsPlayer(u) or UnitPlayerControlled(u) then return end
    local tanking, st, sc, raw = UnitDetailedThreatSituation("player", u)
    -- The default frame's number (UnitFrame_UpdateThreatIndicator): raw until you are tanking, then
    -- the game's lead. A hidden lead is handed straight to the font; comparing it would throw. 0 and
    -- nil show nothing, as the default frame does.
    local pct = raw
    if tanking and wantNumber and UnitThreatPercentageOfLead then
        local ok, lead = pcall(UnitThreatPercentageOfLead, "player", u)
        if ok then
            if isSecret(lead) or (type(lead) == "number" and lead ~= 0) then pct = lead else pct = nil end
        end
    end
    return st, sc, pct
end

-- Solo only: true when your pet has threat on this mob. False when you are the only one. In a group
-- updateThreat does not call this, and the threat shows as usual.
local function threatHasCompany(mob)
    for _, gu in ipairs(threatRoster) do
        if UnitExists(gu) and not UnitIsUnit(gu, "player") then
            local _, _, _, _, v = UnitDetailedThreatSituation(gu, mob)
            if v and v > 0 then return true end
        end
    end
    return false
end

local function updateThreat(f)
    if not f.threatText then return end
    -- what to show: "both" (glow and number), "glow", "number" or "off"
    local mode = getSetting(f.baseUnit, "threatShow")
    local wantGlow, wantNumber = (mode == "both" or mode == "glow"), (mode == "both" or mode == "number")
    -- where the number goes: "text" (just the number, by the raid marker) or "box" (above the name row)
    local inBox = getSetting(f.baseUnit, "threatStyle") == "box"
    local status, scaled, pct
    if wantGlow or wantNumber then
        local ok, st, sc, p = pcall(ns.readThreat, f.wfUnit, wantNumber)
        if ok then status, scaled, pct = st, sc, p end
    end
    -- Values may be protected: they only go to SetFormattedText and are only compared when plain. The
    -- glow shows from status 1 up (about to pull, tanking); a status that can't be compared shows none.
    local shown, glowOn = false, false
    local has = (isSecret(status) or status ~= nil) and (isSecret(pct) or pct ~= nil)
    if has then
        local r, g, b = threatColor(f.baseUnit, status, scaled)
        if wantNumber then
            local fs = (not inBox and f.threatBadge) and f.threatBadge.text or f.threatText
            shown = pcall(fs.SetFormattedText, fs, "%d%%", pct)
            if shown then fs:SetTextColor(r, g, b) end
        end
        glowOn = wantGlow and not isSecret(status) and status >= 1
        if glowOn then f.threatGlow:SetVertexColor(r, g, b) end
    end
    -- Solo and alone on the mob: hide. A pet with threat shows it again. In a group it shows as usual,
    -- and this scan does not run. A value that can't be read leaves it shown.
    if (shown or glowOn) and not IsInGroup() and not isSecret(status) and status and status >= 2 then
        local ok, company = pcall(threatHasCompany, f.wfUnit)
        if ok and company == false then shown, glowOn = false, false end
    end
    local byMarker = not inBox and f.threatBadge ~= nil
    f.threatText:SetShown(shown and not byMarker)
    if f.threatBox then f.threatBox:SetShown(shown and not byMarker) end
    if f.threatBadge then
        -- placed by placeIndicators, beside the raid marker on the bars' side
        f.threatBadge:SetShown(shown and byMarker)
    end
    f.threatGlow:SetShown(glowOn)
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

-- (each cast type's own colour option; unset, its CAST_COLORS one)
ns.CAST_COLOR_KEY = {
    [CAST_COLORS.standard] = "castColorCast", [CAST_COLORS.empowered] = "castColorCast",
    [CAST_COLORS.channel] = "castColorChannel", [CAST_COLORS.uninterruptable] = "castColorLocked",
    [CAST_COLORS.interrupted] = "castColorInterrupted",
}
function ns.castRGB(unit, c)
    local key = ns.CAST_COLOR_KEY[c]
    local v = key and getSetting(unit, key)
    if type(v) == "table" then return v[1] or c[1], v[2] or c[2], v[3] or c[3] end
    return c[1], c[2], c[3]
end

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
    -- the flash over the bar as a cast ends (Cast bar fade: Flash and fade), cut by the box's mask
    cb.flash = top:CreateTexture(nil, "ARTWORK")
    cb.flash:SetAllPoints(cb)
    cb.flash:SetTexture("Interface\\Buttons\\WHITE8X8")
    cb.flash:SetBlendMode("ADD")
    cb.flash:AddMaskTexture(cb.boxMask)
    cb.flash:Hide()
    -- the spark on the fill's moving edge (Spark), cut by the box's mask too
    cb.spark = top:CreateTexture(nil, "OVERLAY")
    cb.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    cb.spark:SetBlendMode("ADD")
    cb.spark:AddMaskTexture(cb.boxMask)
    cb.spark:Hide()
    box:Hide()
    return cb
end

-- The cast bar going away as a cast ends (When a cast ends), instead of vanishing. It starts the moment
-- the cast is over (ns.castEnded), holds a beat, then eases out over the fade time; a finished cast
-- fills the bar first. The endings:
--   Fade: just that.
--   Flash: a bright wash over the bar, dying down.
--   Blizzard glow: Blizzard's own cast-finished glow round the bar.
--   Shine: a bright band sweeping across the bar.
--   Sparkle burst: little stars bursting off the bar, spinning away.
-- In the Flash colour (white to start with); an interrupted cast in the interrupted colour.
-- (Blizzard's own bar fades with an animation we can't read, so ours runs its own.)

-- Whether Blizzard's bar has finished its cast (it's still shown while it fades itself). Only after
-- it's been seen casting: a client without these flags just fades from when the bar hides.
function ns.castEnded(f, bar)
    local live = bar.casting or bar.channeling or bar.reverseChanneling
    if live then f.castLive, f.castFaded = true, nil; return false end
    return f.castLive and true or false
end

function ns.castFadeStart(f)
    local cb = f.cb
    local box = cb and cb.box
    if not (box and box:IsShown()) or box.fading then return end
    -- (this cast's ending has started: it plays once, and the bar stays gone until the next cast,
    -- even while Blizzard's hidden bar is still fading itself)
    f.castFaded = true
    local style = getSetting(f.baseUnit, "castFade") or "fade"
    if style == "off" then box:Hide(); return end
    local interrupted = f.castColor == CAST_COLORS.interrupted
    local len = math.max(0.2, tonumber(getSetting(f.baseUnit, "castFadeTime")) or 0.5)
    local fd = { start = GetTime(), len = len, hold = math.min(0.15, len * 0.3), style = style }
    box.fading = fd
    box:SetAlpha(1)
    cb.spark:Hide()
    -- (a finished cast: the bar full; a channel ends drained, and stays so)
    if not interrupted and f.castColor ~= CAST_COLORS.channel then
        local okM, _, max = pcall(cb.GetMinMaxValues, cb)
        if okM then pcall(cb.SetValue, cb, max) end
    end
    -- the effect's colour
    local r, g, b
    if interrupted then
        r, g, b = ns.castRGB(f.baseUnit, CAST_COLORS.interrupted)
        r, g, b = math.min(1, r + 0.2), math.min(1, g + 0.15), math.min(1, b + 0.15)
    else
        local c = getSetting(f.baseUnit, "castFlashColor")
        if type(c) == "table" then r, g, b = c[1] or 1, c[2] or 1, c[3] or 1 else r, g, b = 1, 1, 1 end
    end
    local h, w = cb:GetHeight() or 10, cb:GetWidth() or 150
    if style == "flash" then
        cb.flash:SetVertexColor(r, g, b)
        cb.flash:SetAlpha(0.85)
        cb.flash:Show()
    elseif style == "glow" then
        if not cb.glow then
            cb.glow = cb.flash:GetParent():CreateTexture(nil, "OVERLAY", nil, 2)
            if cb.glow:SetTexture("Interface\\CastingBar\\UI-CastingBar-Flash") == false then cb.glow:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark") end
            cb.glow:SetBlendMode("ADD")
        end
        cb.glow:ClearAllPoints()
        cb.glow:SetPoint("TOPLEFT", cb, "TOPLEFT", -h * 1.6, h * 1.4)
        cb.glow:SetPoint("BOTTOMRIGHT", cb, "BOTTOMRIGHT", h * 1.6, -h * 1.4)
        cb.glow:SetVertexColor(r, g, b)
        cb.glow:SetAlpha(1)
        cb.glow:Show()
    elseif style == "shine" then
        if not cb.shine then
            cb.shine = cb.flash:GetParent():CreateTexture(nil, "OVERLAY", nil, 2)
            cb.shine:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
            cb.shine:SetBlendMode("ADD")
            cb.shine:AddMaskTexture(cb.boxMask)
        end
        cb.shine:SetSize(h * 3, h * 2.2)
        cb.shine:SetVertexColor(r, g, b)
        cb.shine:Show()
    elseif style == "burst" then
        cb.motes = cb.motes or {}
        local parent = cb.flash:GetParent()
        for i = 1, 12 do
            local m = cb.motes[i]
            if not m then
                m = { tex = parent:CreateTexture(nil, "OVERLAY", nil, 3) }
                m.tex:SetTexture("Interface\\Cooldown\\star4")
                m.tex:SetBlendMode("ADD")
                cb.motes[i] = m
            end
            -- along the bar, flying up or down and outwards, spinning
            m.x = w * (0.1 + 0.8 * math.random())
            local ang = math.random() * math.pi * 2
            local speed = h * (2 + 3 * math.random())
            m.vx, m.vy = math.cos(ang) * speed, math.sin(ang) * speed
            m.size = h * (0.8 + 0.8 * math.random())
            m.spin = (math.random() - 0.5) * 8
            m.tex:SetVertexColor(r, g, b)
            m.tex:Show()
        end
    end
    box:SetScript("OnUpdate", function(self)
        local d = self.fading
        if not d then self:SetScript("OnUpdate", nil); return end
        local since = GetTime() - d.start
        local t = since / d.len
        if t >= 1 then ns.castFadeStop(f); self:Hide(); return end
        -- the bar: holds a beat, then eases out smoothly
        local u = math.max(0, (since - d.hold) / (d.len - d.hold))
        self:SetAlpha(0.5 + 0.5 * math.cos(math.pi * u))
        if d.style == "flash" then
            cb.flash:SetAlpha(0.85 * math.max(0, 1 - t * 2.5) ^ 2)
        elseif d.style == "glow" then
            -- (a quick swell, then dying down)
            cb.glow:SetAlpha(t < 0.15 and (0.6 + t / 0.15 * 0.4) or math.max(0, 1 - (t - 0.15) / 0.65))
        elseif d.style == "shine" then
            local s = math.min(1, t / 0.7)
            cb.shine:ClearAllPoints()
            cb.shine:SetPoint("CENTER", cb, "LEFT", s * cb:GetWidth(), 0)
            cb.shine:SetAlpha(math.sin(math.pi * s) * 0.95)
        elseif d.style == "burst" then
            for _, m in ipairs(cb.motes) do
                m.tex:ClearAllPoints()
                m.tex:SetPoint("CENTER", cb, "LEFT", m.x + m.vx * since, m.vy * since)
                local s = m.size * (1 - 0.6 * t)
                m.tex:SetSize(s, s)
                m.tex:SetAlpha((t < 0.1 and t / 0.1 or 1) * (1 - t))
                pcall(m.tex.SetRotation, m.tex, m.spin * since)
            end
        end
    end)
end
-- (a fade cut short: a new cast, the option turned off, the frame shows someone else)
function ns.castFadeStop(f)
    local cb = f.cb
    local box = cb and cb.box
    if not box then return end
    box.fading = nil
    box:SetScript("OnUpdate", nil)
    cb.flash:Hide()
    if cb.glow then cb.glow:Hide() end
    if cb.shine then cb.shine:Hide() end
    for _, m in ipairs(cb.motes or {}) do m.tex:Hide() end
end

local function placeCastbar(f)
    local bar, cb = f.castbar, f.cb
    if not (bar and cb) then return end
    -- Blizzard's bar keeps running in its own (invisible, parked) frame; ours shows its progress
    if not getSetting(f.baseUnit, "castShow") then
        ns.castFadeStop(f)
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
    -- its own texture (Cast bar texture), else the frame's bar texture (a chosen SharedMedia one, or the
    -- default tintable fill, which is greyed to take the colour cleanly) ...
    local own = resolveTexture(getSetting(f.baseUnit, "castTexture"))
    local fill = own or f.customTex or (BAR_FILE.target .. "Health-Status")
    cb.fillPlain = not (own or f.customTex)
    if cb.fill ~= fill then
        cb.fill = fill
        cb:SetStatusBarTexture(fill)
        cb.fillMasked = nil
    end
    f.castColor = nil        -- (the colours are applied afresh: an option may have changed)
    cb.sparkFill = nil
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

-- The cast's colour: Retail bars name their cast type in barType; older ones have channeling /
-- notInterruptible flags. (Run in pcall: a flag could be hidden.)
function ns.castColor(bar)
    if CAST_COLORS[bar.barType] then return CAST_COLORS[bar.barType] end
    if bar.notInterruptible then return CAST_COLORS.uninterruptable end
    if bar.channeling then return CAST_COLORS.channel end
end

-- Copies Blizzard's bar onto ours while that bar is shown. Every frame of a cast, so no throwaway
-- functions: each call goes straight into pcall.
local function mirrorCastbar(f)
    local bar, cb = f.castbar, f.cb
    local box = cb.box
    if not getSetting(f.baseUnit, "castShow") or not bar:IsShown() then
        if box:IsShown() and not box.fading then box:Hide() end
        f.castColor, f.castText, f.castIconTex = nil, nil, nil
        return
    end
    -- the cast is over (Blizzard's bar still shown while it fades itself): ours runs its own ending
    local okE, ended = pcall(ns.castEnded, f, bar)
    ended = okE and ended
    -- (its ending already played: stay gone until a new cast starts)
    if ended and f.castFaded and not box.fading then
        if box:IsShown() then box:Hide() end
        return
    end
    if box.fading then
        if ended then return end
        ns.castFadeStop(f)        -- (a new cast while the last one was still fading: back to the live bar)
    end
    pcall(cb.SetMinMaxValues, cb, bar:GetMinMaxValues())
    pcall(cb.SetValue, cb, bar:GetValue())
    box:SetAlpha(bar:GetAlpha())
    local ok, c = pcall(ns.castColor, bar)
    if not (ok and c) then c = CAST_COLORS.standard end
    -- colour, spell name and icon hold still for the whole cast. Value and alpha do not.
    if f.castColor ~= c then
        f.castColor = c
        -- (in your own colour for this cast type, if you picked one)
        local r, g, b = ns.castRGB(f.baseUnit, c)
        cb:SetStatusBarColor(r, g, b, 1)
        local tex = cb:GetStatusBarTexture()
        if tex then tex:SetDesaturated(cb.fillPlain and true or false) end
        cb.spark:SetVertexColor(math.min(1, r * 0.5 + 0.6), math.min(1, g * 0.5 + 0.6), math.min(1, b * 0.5 + 0.6))
    end
    -- the spark on the fill's edge (re-anchored when the fill texture changes)
    if getSetting(f.baseUnit, "castSpark") then
        local tex = cb:GetStatusBarTexture()
        if tex and cb.sparkFill ~= tex then
            cb.sparkFill = tex
            cb.spark:ClearAllPoints()
            cb.spark:SetPoint("CENTER", tex, "RIGHT", 0, 0)
            local h = cb:GetHeight() or 10
            cb.spark:SetSize(10, h * 2.4)
        end
        if not cb.spark:IsShown() then cb.spark:Show() end
    elseif cb.spark:IsShown() then
        cb.spark:Hide()
    end
    if bar.Text then
        local okT, text = pcall(bar.Text.GetText, bar.Text)
        if okT and isSecret(text) then pcall(cb.text.SetText, cb.text, text)
        elseif okT and text ~= f.castText then f.castText = text; pcall(cb.text.SetText, cb.text, text) end
    end
    if bar.Icon then
        local okI, icon = pcall(bar.Icon.GetTexture, bar.Icon)
        if okI and isSecret(icon) then pcall(cb.icon.SetTexture, cb.icon, icon)
        elseif okI and icon ~= f.castIconTex then f.castIconTex = icon; pcall(cb.icon.SetTexture, cb.icon, icon) end
    end
    if not box:IsShown() then box:Show() end
    -- (after the colour above, so an interrupted cast is known as one)
    if ended then pcall(ns.castFadeStart, f) end
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
    -- Their OnUpdate runs only while their bar is shown, and it stops when the bar hides. The old
    -- unit-frame poll noticed a hide because our frame stayed shown. This hook needs OnHide, or our
    -- box stays up after you switch away, or after the cast ends and the fade finishes.
    bar:HookScript("OnUpdate", function() mirrorCastbar(f) end)
    bar:HookScript("OnHide", function()
        local box = f.cb and f.cb.box
        if not (box and box:IsShown()) then return end
        -- the cast ended: fade out (Cast bar fade), or straight away if the frame now shows someone
        -- else or the cast bar is off
        if getSetting(f.baseUnit, "castShow") and UnitExists(f.wfUnit) then
            pcall(ns.castFadeStart, f)
            if not box.fading then box:Hide() end
        else
            box:Hide()
        end
    end)
    placeCastbar(f)
end

---------------------------------------------------------------------------
-- Buffs and debuffs: Auras.lua (AuraKit)
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Combat numbers: damage and healing the unit takes pop up over its portrait and fade, like Blizzard's
-- old portrait hit indicator. From UNIT_COMBAT; the amount may be protected, so it only goes to setters.
-- Static sits in the middle. Straight rises. Fountain arcs, alternating sides, on the same quarter
-- circle Ellesmere's combat text uses. Straight and Fountain are clipped to the portrait.
---------------------------------------------------------------------------
local HIT_WORDS = {   -- actions shown as a word instead of a number
    DODGE = DODGE, PARRY = PARRY, BLOCK = BLOCK, MISS = MISS, IMMUNE = IMMUNE, ABSORB = ABSORB,
    RESIST = RESIST, EVADE = EVADE, DEFLECT = DEFLECT, REFLECT = REFLECT,
}

local Hit = {
    -- quarter circle of radius 1: x toward the side, y along the rise (Ellesmere's fountain)
    ARC = { { 0.134, 0.5 }, { 0.5, 0.866 }, { 1, 1 } },
    POOL = 6,
    RISE = 0.5,       -- how far a number travels, as a fraction of the portrait's height
    DROP = 0.14,      -- straight and fountain start this far below centre (fraction of the portrait)
    NORM = 0.38,      -- normal hit, fraction of the portrait height
    CRIT = 0.456,     -- where a crit rests: 30/25 of a normal hit
    CRIT_FROM = 0.5,  -- starts at half of that, and faint (the 390 clip)
    CRIT_PEAK = 2.05, -- crest, about twice the settled size
    CRIT_GROW = 0.12, -- small and faint, up to the crest
    CRIT_LAND = 0.15, -- crest back down to the settled size
    CRIT_DIP = 0.10,  -- starts this far below centre, fraction of the portrait
    CRIT_ARC = 0.16,  -- crest this far above centre, then it drops back
    CRIT_HOLD = 1.0,  -- full strength after it lands
    CRIT_OUT = 0.6,   -- then it fades
    MOVE_DUR = 1.05,
    FADE_FRAC = 0.3,  -- moving numbers fade across the last part of the rise. Crits fade on their own.
    STATIC_FADE = 0.5,
    -- UNIT_COMBAT's school mask. Physical (and a hidden school) is white. A mix uses the first magic school.
    SCHOOL = {
        [1]  = { 1, 1, 1 },          -- physical
        [2]  = { 1, 0.92, 0.4 },     -- holy
        [4]  = { 1, 0.15, 0.08 },    -- fire
        [8]  = { 0.16, 0.5, 0.08 },   -- nature (poison). Darker than a heal, which is (0.1, 1, 0.3)
        [16] = { 0.35, 0.68, 1 },    -- frost
        [32] = { 0.58, 0.32, 1 },    -- shadow
        [64] = { 0.85, 0.42, 1 },    -- arcane
    },
}

function Hit.woundColor(school)
    local c = Hit.SCHOOL[school]
    if c then return c[1], c[2], c[3] end
    local b = 2
    while b <= 64 do
        if school % (b * 2) >= b then
            c = Hit.SCHOOL[b]
            if c then return c[1], c[2], c[3] end
        end
        b = b * 2
    end
    return 1, 1, 1
end

function Hit.mode()
    local m = DB and DB.combatStyle
    if m == "straight" or m == "fountain" then return m end
    return "static"
end

-- How far along its rise a number is, 0 to 1. Linear for Straight. Fountain's control points are
-- evenly spaced in time, so its height comes off the arc. None for Static.
function Hit.travel(m, now)
    if m.mode ~= "straight" and m.mode ~= "fountain" then return 0 end
    -- the pop and the pause are spent sitting still; the rise starts after them
    local frac = (now - m.t0 - (m.stick or 0)) / m.dur
    if frac > 1 then frac = 1 elseif frac < 0 then frac = 0 end
    if m.mode ~= "fountain" then return frac end
    local n = #Hit.ARC
    local seg = frac * n
    local i = math.floor(seg)
    if i >= n then return Hit.ARC[n][2] end
    local from = i > 0 and Hit.ARC[i][2] or 0
    return from + (Hit.ARC[i + 1][2] - from) * (seg - i)
end

-- A new number starts at origin (centre, or just below it). Push this side's live numbers up until
-- the nearest one clears it, but only a little: a full line would kick it straight out of the portrait.
function Hit.clear(box, lane, h, origin)
    local now = GetTime()
    local near, nearD
    for i = 1, #box.pool do
        local m = box.pool[i]
        if m.live and m.lane == lane and now - m.t0 < m.dur + (m.stick or 0) then
            local d = m.y0 + m.rise * Hit.travel(m, now)
            if not nearD or d < nearD then near, nearD = m, d end
        end
    end
    if not near then return end
    local need = (h + near.h) * 0.5 + 2 - (nearD - (origin or 0))
    if need <= 0 then return end
    local cap = box:GetHeight() * 0.22
    if cap < 6 then cap = 6 end
    if need > cap then need = cap end
    for i = 1, #box.pool do
        local m = box.pool[i]
        if m.live and m.lane == lane and now - m.t0 < m.dur + (m.stick or 0) then
            m.y0 = m.y0 + need
            m.holder:ClearAllPoints()
            m.holder:SetPoint("CENTER", box, "CENTER", 0, m.y0)
        end
    end
end

function Hit.box(f)
    if f.hitBox then return f.hitBox end
    local box = CreateFrame("Frame", nil, f.ov)
    box:SetAllPoints(f.portrait)
    pcall(box.SetClipsChildren, box, true)
    box:SetFrameLevel(f.ov:GetFrameLevel() + 4)
    box.pool = {}
    box.xDir = 1
    box.next = 0
    for i = 1, Hit.POOL do
        -- movement and fade run on this frame. The text is pinned to its centre. A crit changes the
        -- font size from here, so the glyphs grow from the middle instead of a corner.
        local holder = CreateFrame("Frame", nil, box)
        holder:SetSize(2, 2)
        holder:Hide()
        local fs = holder:CreateFontString(nil, "OVERLAY")
        fs:SetDrawLayer("OVERLAY", 7)
        fs:SetPoint("CENTER", holder, "CENTER", 0, 0)
        fs:SetJustifyH("CENTER")
        fs:SetJustifyV("MIDDLE")
        fs:Hide()
        fs.holder = holder
        fs.cps = {}
        local ag = holder:CreateAnimationGroup()
        fs.mv = ag:CreateAnimation("Translation")
        pcall(function()
            local path = ag:CreateAnimation("Path")
            path:SetCurveType("SMOOTH")
            local cps = {}
            for j = 1, #Hit.ARC do cps[j] = path:CreateControlPoint(nil, nil, j) end
            fs.path, fs.cps = path, cps
        end)
        local fade = ag:CreateAnimation("Alpha")
        fade:SetFromAlpha(1)
        fade:SetToAlpha(0)
        fs.fade = fade
        ag:SetScript("OnFinished", function() fs:Hide(); holder:Hide(); fs.live = nil end)
        fs.ag = ag
        box.pool[i] = fs
    end
    f.hitBox = box
    return box
end

function Hit.stop(m)
    m.ag:Stop()
    m.live = nil
    m:Hide()
    m.holder:Hide()
    pcall(m.holder.SetScript, m.holder, "OnUpdate", nil)
end

-- Leaves the origin quickly and eases into the end. The 390 clip does not creep up to its crest.
local function hitEase(t)
    if t < 0 then return 0 elseif t > 1 then return 1 end
    t = 1 - t
    return 1 - t * t
end

-- The 390 clip: small and faint, below where it will rest. It grows and becomes solid while it
-- rises, crests, then settles to a size still above a normal hit. Font size, not a scale, so the
-- centre of the glyphs stays put. The rise and fade group is not played for a crit.
function Hit.critPlay(fs, settled, ph)
    local small = math.max(8, settled * Hit.CRIT_FROM)
    local big = settled * Hit.CRIT_PEAK
    local dip, crest = -ph * Hit.CRIT_DIP, ph * Hit.CRIT_ARC
    local grow, land = Hit.CRIT_GROW, Hit.CRIT_LAND
    local holdEnd = grow + land + Hit.CRIT_HOLD
    local life = holdEnd + Hit.CRIT_OUT
    local t0 = GetTime()
    local parent = fs.holder:GetParent()
    local shown = -1
    local function place(holder, size, alpha, y)
        if math.abs(size - shown) >= 0.4 then
            shown = size
            pcall(fs.SetFont, fs, STANDARD_TEXT_FONT, size, "OUTLINE")
        end
        holder:SetAlpha(alpha)
        holder:ClearAllPoints()
        holder:SetPoint("CENTER", parent, "CENTER", 0, (fs.y0 or 0) + y)
    end
    place(fs.holder, small, 0.2, dip)
    fs.holder:SetScript("OnUpdate", function(holder)
        local e = GetTime() - t0
        local size, alpha, y
        if e < grow then
            local u = hitEase(e / grow)
            size = small + (big - small) * u
            alpha = 0.2 + 0.8 * u
            y = dip + (crest - dip) * u
        elseif e < grow + land then
            local u = hitEase((e - grow) / land)
            size = big + (settled - big) * u
            alpha = 1
            y = crest * (1 - u)
        elseif e < holdEnd then
            size, alpha, y = settled, 1, 0
        elseif e < life then
            size, alpha, y = settled, 1 - (e - holdEnd) / Hit.CRIT_OUT, 0
        else
            holder:SetScript("OnUpdate", nil)
            pcall(fs.SetFont, fs, STANDARD_TEXT_FONT, settled, "OUTLINE")
            fs:Hide()
            holder:Hide()
            fs.live = nil
            return
        end
        place(holder, size, alpha, y)
    end)
end

function Hit.arm(fs, mode, rise, dur, xDir, crit)
    -- straight and fountain move normal hits. A crit is not played here; critPlay throws it.
    local moving = mode ~= "static" and not crit
    fs.stick = 0
    fs.mv:SetOffset(0, (moving and mode == "straight") and rise or 0)
    fs.mv:SetStartDelay(0)
    fs.mv:SetDuration(dur)
    if fs.path then
        fs.path:SetStartDelay(0)
        fs.path:SetDuration(dur)
        if moving and mode == "fountain" then
            for j = 1, #Hit.ARC do
                fs.cps[j]:SetOffset(xDir * Hit.ARC[j][1] * rise, Hit.ARC[j][2] * rise)
            end
        else
            for j = 1, #fs.cps do fs.cps[j]:SetOffset(0, 0) end
        end
    elseif moving and mode == "fountain" then
        fs.mv:SetOffset(0, rise)   -- no path animation here: rise instead of the arc
    end
    if crit then
        -- the crit's fade is Hit.critPlay. This group is not played for one.
        fs.fade:SetStartDelay(0)
        fs.fade:SetDuration(0.01)
    elseif mode == "static" then
        fs.fade:SetDuration(Hit.STATIC_FADE)
        fs.fade:SetStartDelay(math.max(0, dur - Hit.STATIC_FADE))
    else
        local fadeDur = Hit.MOVE_DUR * Hit.FADE_FRAC
        fs.fade:SetDuration(fadeDur)
        fs.fade:SetStartDelay(math.max(0, dur - fadeDur))
    end
end

local function showHit(f, action, indicator, amount, school)
    -- the General page's master switch, then the frame's own option
    -- one switch on the General page; the numbers show on the player, target, focus and pet frames
    if DB.combatNumbers == false or not defaultFor(f.baseUnit, "combatNumbers") then return end
    -- target: every hit on them, yours or not. Off means no text and no animation. The event itself
    -- still marks a spell preview as landed (UNIT_COMBAT below).
    if f.baseUnit == "target" and DB.combatTarget == false then return end
    if not (f.ov and f.portrait) then return end
    -- (the action and crit flag may be protected too: compared inside pcall, a protected one counts as a hit)
    local crit, word, kind = false, nil, "WOUND"
    pcall(function() crit = (indicator == "CRITICAL" or indicator == "CRUSHING") end)
    pcall(function() word = HIT_WORDS[action] end)
    pcall(function() if action == "HEAL" or action == "ENERGIZE" or action == "WOUND" then kind = action elseif not word then kind = nil end end)
    if not word and not kind then return end
    local box = Hit.box(f)
    local mode = Hit.mode()
    -- the text is set before any running number is stopped, so a value the game won't show leaves them alone
    local idx = mode == "static" and 1 or (box.next % #box.pool + 1)
    local fs = box.pool[idx]
    -- normal hits ~40% of the portrait. A crit settles a little larger; critPlay grows it past that.
    -- the font has to be set before the text. Without one, SetText fails and the hit is dropped.
    local ph = f.portrait:GetHeight() or 60
    local size = math.max(10, math.floor(ph * (crit and Hit.CRIT or Hit.NORM)))
    pcall(fs.SetFont, fs, STANDARD_TEXT_FONT, size, "OUTLINE")
    if word then
        fs:SetText(word)
        fs:SetTextColor(1, 1, 1)
    else
        if not pcall(function() fs:SetText(AbbreviateLargeNumbers(amount)) end) then
            if not pcall(function() fs:SetFormattedText("%d", amount) end) then return end
        end
        if kind == "HEAL" then fs:SetTextColor(0.1, 1, 0.3)
        elseif kind == "ENERGIZE" then fs:SetTextColor(0.4, 0.6, 1)
        else
            -- physical, or a school the game has hidden: white. A readable school takes its own colour.
            local r, g, b = 1, 1, 1
            pcall(function() r, g, b = Hit.woundColor(school) end)
            fs:SetTextColor(r, g, b)
        end
    end
    if mode == "static" then
        for i = 1, #box.pool do
            local m = box.pool[i]
            Hit.stop(m)
        end
    else
        Hit.stop(fs)
        box.next = idx
    end
    local rise = ph * Hit.RISE
    local dur = mode == "static" and (0.7 + Hit.STATIC_FADE) or Hit.MOVE_DUR
    local lane, xDir = 0, 1
    if mode == "fountain" and not crit then
        box.xDir = -box.xDir
        xDir, lane = box.xDir, box.xDir
    end
    local h = size * 1.15
    -- straight and fountain come in from just below centre. A crit rests in the middle; its throw
    -- is the arc in critPlay, not this style.
    local origin = (mode == "static" or crit) and 0 or -(ph * Hit.DROP)
    if crit then rise = 0; dur = Hit.CRIT_GROW + Hit.CRIT_LAND + Hit.CRIT_HOLD + Hit.CRIT_OUT end
    if mode ~= "static" then Hit.clear(box, lane, h, origin) end
    -- the pop is larger than the portrait, so a crit is not clipped to it
    pcall(box.SetClipsChildren, box, mode ~= "static" and not crit)
    fs.t0, fs.y0, fs.h, fs.lane = GetTime(), origin, h, lane
    fs.mode, fs.rise, fs.dur, fs.live = mode, rise, dur, true
    fs.holder:ClearAllPoints()
    fs.holder:SetPoint("CENTER", box, "CENTER", 0, origin)
    fs.holder:SetAlpha(1)
    fs:Show()
    fs.holder:Show()
    Hit.arm(fs, mode, rise, dur, xDir, crit)
    if crit then
        Hit.critPlay(fs, size, ph)
    else
        fs.ag:Play()
    end
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

-- every unit frame (looked up when called: Auras.lua, which defines it, loads after this file)
function Extras.allFrames() return AuraKit.allFrames() end

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
            defaultTip(self)
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
    local class = ns.playerClass()
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
    defaultTip(self)
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

-- Frame colour: gold as drawn, your class colour, or a custom colour.
-- Class colour: on the player and pet frames, your class; on the others (target, focus, their targets,
-- the party), the class of whoever the frame shows, gold for an NPC or no one. who: the unit shown.
-- ("theirclass" is the party's name for the same thing.)
function Extras.tintColor(unit, who)
    local mode = getSetting(unit, "frameTint")
    if mode == "class" or mode == "theirclass" then
        local class
        pcall(function()
            if OWN_CLASS[unit] then class = select(2, UnitClass("player"))
            elseif who and UnitIsPlayer(who) then class = select(2, UnitClass(who)) end
        end)
        local c = class and (RAID_CLASS_COLORS or {})[class]
        if c then return { c.r, c.g, c.b } end
        return nil
    elseif mode == "custom" then
        local c = getSetting(unit, "frameColor")
        if type(c) == "table" then return { c[1] or 1, c[2] or 1, c[3] or 1 } end
        return { 1, 1, 1 }
    end
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
    -- a frame in its unit's class colour changes colour with who it shows (your own frames don't)
    local mode = getSetting(f.baseUnit, "frameTint")
    if (mode == "class" or mode == "theirclass") and not OWN_CLASS[f.baseUnit] then pcall(Extras.tint, f) end
    if f.baseUnit == "pet" then pcall(Extras.happiness, f) end
    if f.baseUnit == "target" then pcall(Extras.combo, f) end
end

-- event watchers, once the frames exist
function Extras.init()
    rebuildThreatRoster()
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
    -- combo points ride on your power events: only rogues and druids have any
    local cls = ns.playerClass()
    if cls == "ROGUE" or cls == "DRUID" then
        if not pcall(ev.RegisterUnitEvent, ev, "UNIT_POWER_FREQUENT", "player") then
            pcall(ev.RegisterUnitEvent, ev, "UNIT_POWER_UPDATE", "player")
        end
        pcall(ev.RegisterUnitEvent, ev, "UNIT_MAXPOWER", "player")
        pcall(ev.RegisterUnitEvent, ev, "UNIT_DISPLAYPOWER", "player")   -- (a druid shifting in or out of cat form)
    end
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
    f.colorHold = nil
    safely(updateInfo, f); safely(updateHealth, f); safely(updatePower, f); safely(updateIndicators, f)
    safely(updateThreat, f); safely(updateAuras, f); safely(Extras.update, f)
    -- a teleport repaints the frame from here (PLAYER_ENTERING_WORLD). The resting glow is in
    -- updateIndicators; the Zzz is not, so it stayed off until a reload.
    if f.updateRest then safely(f.updateRest) end
end

-- The settings' Preview tickboxes: one effect (heal: an incoming heal, absorb: a shield) shown on the
-- live frame, so you can see it as it really looks.
-- While any is on, the frame shows made-up values: health at 60% (room for them), and each effect
-- ticked at a share of the bar. Real health updates wait (f.previewing) until the last one is off.
function ns.applyFxPreview(f)
    local fx = f and f.fxPreview
    if not fx then return end
    -- (the overlays made, styled and anchored by the normal code, on a 60% fill, then given their shares)
    f.previewing = nil
    f.hp:SetMinMaxValues(0, 100)
    f.hp:SetValue(60)
    -- (the recent damage trail would read the drop to 60% as damage and paint it red: hidden for now,
    -- back with the real values when the preview ends)
    local t = f.hpTrail
    if t then t.pending = false; t:SetScript("OnUpdate", nil); t:Hide() end
    pcall(updatePrediction, f)
    f.previewing = true
    if not f.predBars then return end
    for _, b in ipairs(f.predBars) do b:SetMinMaxValues(0, 100) end
    f.healBar:SetValue(fx.heal and 20 or 0)
    -- (a shield that fits in the missing health, after the heal)
    ns.setShields(f, fx.absorb and 15 or 0)
    -- (a snowglobe glow shaken, to show it off)
    ns.barGlowShake(f.absorbBar); ns.barGlowShake(f.absorbBack); ns.barGlowShake(f.healBar)
end

function ns.setFxPreview(f, kind, on)
    if not (f and f.hp) then return end
    local fx = f.fxPreview or {}
    fx[kind] = on and true or nil
    if next(fx) then
        f.fxPreview = fx
        ns.applyFxPreview(f)
    else
        -- the last one off: back to the real values
        f.fxPreview, f.previewing = nil, nil
        pcall(updateAll, f)
    end
end

-- (every preview off: the settings window closed)
function ns.clearFxPreviews()
    local list = {}
    for _, unit in ipairs(UNITS) do list[#list + 1] = frames[unit] end
    for i = 1, Party.SLOTS do list[#list + 1] = Party.members[i] end
    for _, f in pairs(list) do
        if f and f.fxPreview then
            f.fxPreview, f.previewing = nil, nil
            pcall(updateAll, f)
        end
    end
end

-- Several unit events often land in one frame (health, heal prediction, an absorb). Paint once,
-- before the frame is drawn. Events run before OnUpdate.
ns.paintQ, ns.paintN = {}, 0
ns.paintHost = CreateFrame("Frame")
ns.paintHost:Hide()
ns.paintHost:SetScript("OnUpdate", function(self)
    self:Hide()
    local n, q = ns.paintN, ns.paintQ
    ns.paintN = 0
    for i = 1, n do
        local f = q[i]
        q[i] = nil
        if f then
            local all, info, hp, mp, pred = f.paintAll, f.paintInfo, f.paintHP, f.paintMP, f.paintPred
            f.paintQueued, f.paintAll, f.paintInfo, f.paintHP, f.paintMP, f.paintPred = nil, nil, nil, nil, nil, nil
            if not f.wfOff then
                pcall(function()
                    if all then updateAll(f)
                    else
                        if info then updateInfo(f) end
                        if hp then updateHealth(f) end
                        if mp then updatePower(f) end
                        if pred and not hp then updatePrediction(f) end
                    end
                end)
            end
        end
    end
end)
function ns.markPaint(f, kind)
    if not f or f.wfOff then return end
    if not f.paintQueued then
        f.paintQueued = true
        ns.paintN = ns.paintN + 1
        ns.paintQ[ns.paintN] = f
        ns.paintHost:Show()
    end
    if kind == "all" then f.paintAll = true
    elseif kind == "info" then f.paintInfo = true
    elseif kind == "health" then f.paintHP = true
    elseif kind == "power" then f.paintMP = true
    elseif kind == "pred" then f.paintPred = true end
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
    return true
end

---------------------------------------------------------------------------
-- Applying settings
---------------------------------------------------------------------------
function refreshText(f)
    local mode = getSetting(f.baseUnit, "textMode")
    f.textMode = mode          -- updateHealth / updatePower / the hover poll read this, not getSetting
    local always = (mode == "always")
    local over = (mode == "mouseover")
    -- Dead / Ghost / Offline always shows, whatever the text mode
    f.hpText:SetShown((always or f.statusText or (over and f.hoverHP)) and true or false)
    f.mpText:SetShown((always or (over and f.hoverMP)) and true or false)
    -- the shield's number: by the frame's Numbers setting, as the health's (Never: none)
    if f.shieldText then
        f.shieldText:SetShown(((always or (over and f.hoverHP)) and getSetting(f.baseUnit, "absorbs") and not f.statusText) and true or false)
    end
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

-- The portrait party frames: on, and not swapped for the raid-style tiles (RaidParty.lua).
function Party.portraitsOn()
    return frameOn("party") and getSetting("party", "partyStyle") ~= "raid"
end

local function applyShown(f)
    local unit = f.baseUnit
    if ALWAYS_SHOWN[unit] then return end
    local on = frameOn(unit)
    if unit == "party" then on = Party.portraitsOn() end
    if on == (f.wfOff ~= true) then return end
    f.wfOff = not on
    if on then
        Party.watch(f)
        if Party.listen then Party.listen(f) end
        pcall(updateAll, f)        -- (it ignored its events while off: catch up)
    else
        Party.unwatch(f)
        f:Hide()
        if Party.silence then Party.silence(f) end
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
            defaultTip(self)
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
    -- Portrait party frames, hidden (party off, or raid style): nothing further to lay out or paint.
    -- Turning them back on runs the rest, with the settings as they are then.
    if unit == "party" and f.wfOff and not Party.portraitsOn() then
        pcall(updateAuras, f)        -- (drops the aura unit, so a hidden frame is not scanned)
        return
    end
    if f.altMana then placeAltMana(f) end
    local changed = applyLayout(f)
    if f.small and applySmallLayout(f) then changed = true end
    -- party slots 2 - 4 stack under the one before; the rest sit where they were put
    if f.partyIndex and f.partyIndex > 1 then Party.place(f) else placeFrame(f, unit) end
    f:SetScale(getSetting(unit, "scale"))
    local showName = (unit == "player" or getSetting(unit, "showName")) and true or false   -- (your own name always)
    f.name:SetShown(showName)
    if f.plate then f.plate:SetShown(showName and not f.layoutLeft) end
    applyCorner(f)
    placeIndicators(f)
    pcall(applyFont, f)
    pcall(updateInfo, f)          -- name, level and portrait
    pcall(updateThreat, f)
    pcall(updateIndicators, f)
    pcall(updateAuras, f)
    pcall(placeCastbar, f)
    pcall(Extras.tint, f)
    if unit == "pet" then pcall(Extras.happiness, f) end      -- (its spot or off: straight away)
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
    f.wantPred = (getSetting(unit, "healPrediction") or getSetting(unit, "absorbs")) and true or false
    f.wantTrail = getSetting(unit, "damageTrail") and true or false
    if changed then pcall(updateAll, f) end
end

local function applyAll()
    if InCombatLockdown() then pendingApply = true; return end
    pendingApply = false
    for _, unit in ipairs(UNITS) do
        if frames[unit] then applyUnit(frames[unit]) end
    end
    for i = 2, Party.SLOTS do if Party.members[i] then applyUnit(Party.members[i]) end end
    if Party.sync then pcall(Party.sync) end   -- (party off: listeners and tickers stop here)
end

local function touchOptions()
    if Opt and Opt.changed then Opt.changed() end
end

local function setSetting(unit, key, value)
    unitData(unit, true)[key] = value
    -- (the party's options are every party slot's)
    local list = { frames[unit] }
    if unit == "party" then
        -- Off, and staying off: nothing to paint. Turning them off still hides them once.
        if frameOn("party") or key == "frameShown" then
            for i = 2, Party.SLOTS do list[#list + 1] = Party.members[i] end
        else
            list = {}
        end
    end
    for _, f in ipairs(list) do
        if f then f.colorHold = nil end
        if key == "textMode" then f.textMode = value end
        pcall(updateHealth, f)
        pcall(updatePower, f)
        if InCombatLockdown() then pendingApply = true else applyUnit(f) end
        if lib and f == frames[unit] then lib:RefreshFrameSettings(f) end
        -- (a heal or shield preview on it: shown again in the new look)
        if f.fxPreview then pcall(ns.applyFxPreview, f) end
    end
    -- the pet's bar can follow the player frame's colour
    if unit == "player" and frames.pet then frames.pet.colorHold = nil; pcall(updateHealth, frames.pet) end
    if unit == "player" and ns.PlayerExtras then pcall(ns.PlayerExtras.apply) end
    -- the party: listeners, tickers, who goes in which slot. Off, this is what makes them stop.
    if unit == "party" and Party.sync then pcall(Party.sync) end
    touchOptions()
end

---------------------------------------------------------------------------
-- Frame creation (art and numbers from Blizzard's PlayerFrame.xml / TargetFrame.xml)
---------------------------------------------------------------------------
-- The clickable secure button both frame sizes are built on. The live unit lives in f.wfUnit, not
-- f.unit: an addon-written .unit field stops pings from reading the unit's (secret) GUID.
-- wf: the unit it shows, when that isn't the frame's own (the party frames: "party" shows party1 - 4).
local function newUnitButton(unit, w, h, wf)
    wf = wf or unit
    local f
    local name = "WebbyFrames_" .. (wf ~= unit and wf or unit)
    if not pcall(function() f = CreateFrame("Button", name, UIParent, "SecureUnitButtonTemplate,PingableUnitFrameTemplate") end) or not f then
        f = CreateFrame("Button", name, UIParent, "SecureUnitButtonTemplate")
    end
    f.wfUnit, f.baseUnit, f.homeUnit = wf, unit, wf
    f:SetSize(w, h)
    f:SetFrameStrata("LOW")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:RegisterForClicks("AnyUp")
    f:SetAttribute("unit", wf)
    f:SetAttribute("type1", "target")
    f:SetAttribute("type2", "togglemenu")
    f:SetPoint(DEFAULT_POS[unit].point, UIParent, DEFAULT_POS[unit].point, DEFAULT_POS[unit].x, DEFAULT_POS[unit].y)
    return f
end

-- Unit tooltip on hover, and the per-bar "show on mouseover" numbers.
-- (whether the cursor is over a bar; cx, cy: the cursor, in screen pixels)
local function cursorOver(bar, cx, cy)
    local sc = bar:GetEffectiveScale()
    local l, b, w, h = bar:GetRect()
    if not (l and sc and sc > 0) then return false end
    local x, y = cx / sc, cy / sc
    return x >= l and x <= l + w and y >= b and y <= b + h
end

local function addHover(f)
    -- Numbers on mouseover: which bar the cursor is on, every frame while it's over this one (a child
    -- that only runs while shown, so nothing runs otherwise).
    local watch = CreateFrame("Frame", nil, f)
    watch:Hide()
    watch:SetScript("OnUpdate", function()
        local cx, cy = GetCursorPosition()
        local hp, mp = cursorOver(f.hp, cx, cy), cursorOver(f.mp, cx, cy)
        if not hp and not mp then
            -- (a second opinion, the frame's own; there's no global MouseIsOver on Forever)
            hp = f.hp:IsMouseOver() and true or false
            mp = f.mp:IsMouseOver() and true or false
        end
        if hp ~= f.hoverHP or mp ~= f.hoverMP then
            f.hoverHP, f.hoverMP = hp, mp
            refreshText(f)
        end
    end)
    f:HookScript("OnEnter", function(self)
        self.hover = true
        watch:SetShown(self.textMode == "mouseover")
        if self.baseUnit == "party" and Party.tipAllowed and not Party.tipAllowed() then return end
        pcall(function()
            defaultTip(self)
            if GameTooltip:SetUnit(self.wfUnit) ~= false then GameTooltip:Show() end
        end)
        if ns.Click then pcall(ns.Click.addTooltip, self) end      -- (your click casting, under it)
    end)
    f:HookScript("OnLeave", function(self)
        self.hover = false; self.hoverHP = false; self.hoverMP = false; refreshText(self)
        watch:Hide()
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
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
        -- the trail of what was just spent (updateManaTrail): under the power fill, inside a frame that
        -- clips it to past the fill's end (anchored there by updateManaTrail), as the health trail is
        local tclip = CreateFrame("Frame", nil, f)
        tclip:SetClipsChildren(true)
        tclip:SetFrameLevel(f.mp:GetFrameLevel())
        tclip:SetAllPoints(f.mp)
        local mt = CreateFrame("StatusBar", nil, tclip)
        mt:SetAllPoints(f.mp)
        mt:SetFrameLevel(tclip:GetFrameLevel())
        mt.clip = tclip
        mt:SetMinMaxValues(0, 1)
        mt:SetValue(0)
        mt:Hide()
        f.mp:SetFrameLevel(mt:GetFrameLevel() + 1)       -- (the power fill draws over it)
        f.mpTrail = mt
        for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
                             "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_SUCCEEDED",
                             "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP" }) do
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
    -- One point above GameNormalNumberFont. Player and target only.
    if unit == "player" or unit == "target" then
        local p, s, fl = f.level:GetFont()
        if p and s then f.level:SetFont(p, s + 1, fl) end
    end
    if hasAtlas("UI-HUD-UnitFrame-SmallCircle") then
        f.badge = ov:CreateTexture(nil, "OVERLAY", nil, -1)
        f.badge:SetAtlas("UI-HUD-UnitFrame-SmallCircle")
    end

    -- Corner accent (DragonflightUI's art; shown by applyCorner), player frame only, with a solid
    -- black silhouette of itself, a little larger, behind it so nothing behind the accent shows through.
    if isPlayer then
        f.cornerBack = ov:CreateTexture(nil, "OVERLAY", nil, 0)
        setArt(f.cornerBack, ART.corner, false, 1.15)
        f.cornerBack:SetVertexColor(0, 0, 0, 1)
        f.cornerBack:SetPoint("CENTER", f, "CENTER", CORNER_POS[1], CORNER_POS[2])
        f.corner = ov:CreateTexture(nil, "OVERLAY", nil, 1)
        setArt(f.corner, ART.corner)
        f.corner:SetPoint("CENTER", f, "CENTER", CORNER_POS[1], CORNER_POS[2])
    end

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
            local resting = false
            pcall(function() resting = IsResting() and true or false end)
            rest:SetShown(resting)
            if not anim then return end
            if not resting then
                rest:SetScript("OnUpdate", nil)
                anim:Stop()
                return
            end
            -- Play() while a teleport's loading screen has the UI hidden does nothing, and the
            -- flipbook then sits on the whole sheet, which does not read as a Zzz. Start it once
            -- the frame is on screen. Leave a running one alone (updateAll calls this often).
            if rest:IsVisible() then
                if not anim:IsPlaying() then anim:Play() end
            else
                rest:SetScript("OnUpdate", function(self)
                    if not self:IsVisible() then return end
                    self:SetScript("OnUpdate", nil)
                    if anim and self:IsShown() then anim:Stop(); anim:Play() end
                end)
            end
        end
        f:RegisterEvent("PLAYER_UPDATE_RESTING")
    end

    addHover(f)

    -- events
    f:SetScript("OnEvent", function(self, event, ...)
        if self.wfOff then return end      -- (turned off: nothing to draw; applyShown catches it up when it's back)
        if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
            -- a spell on its way has landed (see flyDamage). The bar paint waits for this frame's other events.
            if event == "UNIT_HEALTH" then self.hitAt = GetTime(); if self.dmgFlying then landDamage(self) end end
            ns.markPaint(self, "health")
        elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
            ns.markPaint(self, "power")

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
        elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
            -- a channel (Arcane Missiles, Mind Flay, Penance): its whole damage on your target (and
            -- focus when that's the same mob), or its whole healing on who it's going to, while it lasts
            local _, _, spellID = ...
            pcall(updateDamagePrediction, frames.target, spellID, true)
            local same = false
            pcall(function() same = UnitIsUnit("focus", "target") and true or false end)
            pcall(updateDamagePrediction, frames.focus, same and spellID or nil, true)
            pcall(ns.channelHeal, spellID)
        elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
            pcall(updateDamagePrediction, frames.target, nil)
            pcall(updateDamagePrediction, frames.focus, nil)
            pcall(ns.channelHeal, nil)
        elseif event:find("^UNIT_SPELLCAST_") then
            -- (what a spell spent shows as the mana trail, when your power drops: updateManaTrail)
            -- any spell that went off (instants too): the five second rule, if it cost mana (Mana tick)
            if event == "UNIT_SPELLCAST_SUCCEEDED" and self.manaTick then
                local _, _, spellID = ...
                pcall(ns.manaSpend, self, spellID)
            end
            -- only the cast being shown ends it (a failed second spell mid-cast leaves it alone)
            local _, guid = ...
            local mine = true
            pcall(function() mine = (guid == self.castGUID) end)
            if mine then
                local spell = self.castSpell
                self.castSpell, self.castGUID = nil, nil
                -- went off: the cost preview stays until the mana actually drops (the trail takes over
                -- then), or half a second if it never does (a free cast)
                if event == "UNIT_SPELLCAST_SUCCEEDED" and spell then
                    local hold = { spell = spell }
                    self.costHold = hold
                    C_Timer.After(0.5, function()
                        if self.costHold == hold then self.costHold = nil; pcall(updateCostPrediction, self) end
                    end)
                end
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
        elseif event == "PLAYER_FLAGS_CHANGED" or event == "UNIT_FLAGS" then
            updateIndicators(self)
            -- (a mob someone else tagged turns grey: its held health colour is read again)
            if event == "UNIT_FLAGS" then self.colorHold = nil; ns.markPaint(self, "health") end
        elseif event:find("^UNIT_THREAT") then updateThreat(self)
        elseif event == "GROUP_ROSTER_UPDATE" or event == "PARTY_LEADER_CHANGED" then
            updateLeader(self)
            pcall(Extras.raid, self)
            if event == "GROUP_ROSTER_UPDATE" then rebuildThreatRoster() end
        elseif event == "UNIT_AURA" then
            local _, info = ...
            pcall(AuraKit.auraChanged, self, info)   -- (the aura containers redraw on their own)
        elseif event == "UNIT_COMBAT" then
            -- target numbers can be off: still note the hit for a spell preview, but draw nothing
            if self.baseUnit ~= "target" or DB.combatTarget ~= false then
                local _, action, indicator, amount, school = ...; pcall(showHit, self, action, indicator, amount, school)
            end
            -- the spell landed (or missed): its next combat event after the cast
            self.hitAt = GetTime()
            if self.dmgFlying then landDamage(self) end
        elseif event == "UNIT_HEAL_PREDICTION" or event:find("ABSORB_AMOUNT_CHANGED$") then
            ns.markPaint(self, "pred")
            -- (a snowglobe glow on the shield or the heals: shaken)
            if event == "UNIT_ABSORB_AMOUNT_CHANGED" then ns.barGlowShake(self.absorbBar); ns.barGlowShake(self.absorbBack)
            elseif event == "UNIT_HEAL_PREDICTION" then ns.barGlowShake(self.healBar) end
        elseif event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED"
            or event == "UNIT_NAME_UPDATE" or event == "UNIT_LEVEL" then
            -- name / level / portrait only: not a full bar and aura repaint
            ns.markPaint(self, "info")
        elseif event == "UNIT_FACTION" or event == "UNIT_CONNECTION" then
            -- plate colour, offline bolt, and health colour (tapped / reaction / grey).
            -- Faction also carries PvP flag changes (e.g. walking into contested territory): the icon
            -- lives in updateIndicators, not updateInfo, so it must run here. Before 1.16.50 this
            -- went through updateAll; skipping it left the shield stuck until another indicator event.
            self.colorHold = nil
            ns.markPaint(self, "info")
            ns.markPaint(self, "health")
            if event == "UNIT_FACTION" then updateIndicators(self) end
        elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
            -- the rest flag can land after the event that brought you into the city
            if self.updateRest then C_Timer.After(0.5, function() if self.updateRest then self.updateRest() end end) end
            ns.markPaint(self, "all")
        else ns.markPaint(self, "all") end
    end)
    -- smooth energy / rage / focus ticks on your own frame (every change: the plain power update would
    -- then only redraw the bar a second time)
    local frequent = isPlayer and pcall(f.RegisterUnitEvent, f, "UNIT_POWER_FREQUENT", unit)
    for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
                         "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED", "UNIT_FACTION", "UNIT_CONNECTION", "UNIT_AURA",
                         "UNIT_HEAL_PREDICTION", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "UNIT_COMBAT" }) do
        if not (frequent and e == "UNIT_POWER_UPDATE") then pcall(f.RegisterUnitEvent, f, e, unit) end
    end
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
-- wf: the unit shown (party members: "party" frames showing party1 - party4); index: the party slot.
local function createSmallFrame(unit, wf, index)
    local f = newUnitButton(unit, 120, 49, wf)
    f.partyIndex = index
    local shown = f.wfUnit
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
    f.ov = ov

    addHover(f)

    -- Compound units (targettarget, focustarget) get no unit events, so while shown they are polled
    -- four times a second: bars only, name / portrait when the unit changes. A secret GUID can't be
    -- compared, so that case counts as changed (repaint rather than show stale info). A ticker, not
    -- an OnUpdate: nothing runs on the frames in between.
    if unit == "targettarget" or unit == "focustarget" then
        ns.totPoll = ns.totPoll or {}
        ns.totPoll[#ns.totPoll + 1] = f
        if not ns.totTicker then
            ns.totTicker = C_Timer.NewTicker(0.25, function()
                for _, self in ipairs(ns.totPoll) do
                    if self:IsShown() and not self.wfOff then
                        local u = self.wfUnit
                        if UnitExists(u) then
                            local guid = UnitGUID(u)
                            local same = not isSecret(guid) and not isSecret(self.lastGUID) and guid == self.lastGUID
                            if not same then
                                self.lastGUID = guid
                                self.colorHold = nil
                                pcall(updateAll, self)
                            else
                                pcall(updateHealth, self, true)
                                pcall(updatePower, self)
                            end
                        end
                    end
                end
            end)
        end
    end

    f:SetScript("OnEvent", function(self, event, ...)
        if self.wfOff then return end      -- (turned off: nothing to draw; applyShown catches it up when it's back)
        if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
            if event == "UNIT_HEALTH" then self.hitAt = GetTime(); if self.dmgFlying then landDamage(self) end end
            ns.markPaint(self, "health")
        elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then ns.markPaint(self, "power")
        elseif event == "UNIT_AURA" then
            local _, info = ...
            pcall(AuraKit.auraChanged, self, info)   -- (the aura containers redraw on their own)
        elseif event == "UNIT_COMBAT" then
            local _, action, indicator, amount, school = ...; pcall(showHit, self, action, indicator, amount, school)
            -- the spell landed (or missed): its next combat event after the cast
            self.hitAt = GetTime()
            if self.dmgFlying then landDamage(self) end
        elseif event == "UNIT_HEAL_PREDICTION" or event:find("ABSORB_AMOUNT_CHANGED$") then
            ns.markPaint(self, "pred")
            -- (a snowglobe glow on the shield or the heals: shaken)
            if event == "UNIT_ABSORB_AMOUNT_CHANGED" then ns.barGlowShake(self.absorbBar); ns.barGlowShake(self.absorbBack)
            elseif event == "UNIT_HEAL_PREDICTION" then ns.barGlowShake(self.healBar) end
        elseif event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED"
            or event == "UNIT_NAME_UPDATE" then
            ns.markPaint(self, "info")
        elseif event == "UNIT_FACTION" or event == "UNIT_CONNECTION" then
            self.colorHold = nil
            ns.markPaint(self, "info")
            ns.markPaint(self, "health")
            -- (PvP shield on player/target/focus: small frames have none, updateIndicators returns)
            if event == "UNIT_FACTION" then updateIndicators(self) end
        else ns.markPaint(self, "all") end
    end)
    -- Party slots that are not in use (party off, or raid style) register nothing. Party.listen
    -- puts the events back when the portrait frames are shown again.
    local partyOn = unit ~= "party" or Party.portraitsOn()
    if partyOn then
        for _, e in ipairs(Party.UNIT_EVENTS) do
            pcall(f.RegisterUnitEvent, f, e, shown)
        end
    end
    if unit == "pet" then
        pcall(f.RegisterUnitEvent, f, "UNIT_PET", "player")
    elseif unit == "focustarget" then
        pcall(f.RegisterUnitEvent, f, "UNIT_TARGET", "focus")
        f:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif unit == "party" then
        if partyOn then f:RegisterEvent("GROUP_ROSTER_UPDATE") end   -- (who is in each slot changes)
    else
        pcall(f.RegisterUnitEvent, f, "UNIT_TARGET", "target")   -- the target changed who it is targeting
    end
    if unit ~= "party" then f:RegisterEvent("PLAYER_TARGET_CHANGED") end
    if partyOn then f:RegisterEvent("PLAYER_ENTERING_WORLD") end

    if partyOn then Party.watch(f) end
    if not index or index == 1 then frames[unit] = f end
    if index then Party.members[index] = f end
    if partyOn then updateAll(f) end
    return f
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
    if Party.portraitsOn() then
        if frames.party then list[#list + 1] = frames.party end
        for i = 2, Party.SLOTS do if Party.members[i] then list[#list + 1] = Party.members[i] end end
    end
    return list
end

-- Everything Webby that can be moved (the unit frames, the raid-style party box, Healer Mana, Buff
-- Bars), for Edit Mode's look and toolbar (EditMode.lua), snapping, and EllesmereUI's Unlock Mode.
--   frame, label, page (its settings page), unit (a unit frame: it can be attached to another);
--   store(point, x, y) / place() (its saved spot, from UIParent's point, and putting it there),
--   reset() (back to its default spot), enter() / exit() (Edit Mode or Unlock Mode opening / closing)
ns.MOVERS = ns.MOVERS or {}
function ns.addMover(m)
    for _, o in ipairs(ns.MOVERS) do if o.frame == m.frame then return end end
    ns.MOVERS[#ns.MOVERS + 1] = m
end

local function enterSample()
    -- (the modules' own stand-ins: the raid-style sample party, the healer mana and buff bar samples)
    for _, m in ipairs(ns.MOVERS) do if m.enter then pcall(m.enter) end end
    if InCombatLockdown() then return end
    if Party.stopSamples then pcall(Party.stopSamples) end    -- (Edit Mode has its own stand-ins)
    for _, f in ipairs(sampleFrames()) do
        Party.unwatch(f)
        f.wfUnit = "player"
        f:Show()
        updateAll(f)
    end
    AuraKit.setEditing(true)       -- the buff / debuff boxes for frames set to "drag in Edit Mode"
    pcall(editAltMana, true)       -- the druid mana bar, to drag
    pcall(Extras.editCombo, true)  -- and the combo points
end

local function exitSample()
    for _, m in ipairs(ns.MOVERS) do if m.exit then pcall(m.exit) end end
    AuraKit.setEditing(false)
    pcall(editAltMana, false)
    pcall(Extras.editCombo, false)
    if InCombatLockdown() then return end
    for _, f in ipairs(sampleFrames()) do
        f.wfUnit = f.homeUnit or f.baseUnit      -- (a party slot goes back to its partyN)
        Party.watch(f)
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
    -- (and the other Webby boxes: raid-style party, Healer Mana, Buff Bars)
    for _, m in ipairs(ns.MOVERS) do
        local o = m.frame
        if not m.unit and o ~= self and o:IsVisible() then list[#list + 1] = o end
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
ns.snapFrame = snapFrame       -- (the other modules' boxes snap as they're dropped too)

-- The lines a frame being dragged would snap to right now (each { x = ..., y1, y2 } or { y = ..., x1,
-- x2 }, in UIParent's coordinates): drawn as guides while you drag (EditMode.lua). The same rules as
-- snapFrame.
function ns.snapGuides(f)
    local out = {}
    local snapOn = true
    pcall(function() if EditModeManagerFrame.IsSnapEnabled then snapOn = EditModeManagerFrame:IsSnapEnabled() end end)
    if not snapOn then return out end
    local l, b, r, t = boxOf(f)
    if not l then return out end
    local function near(a, c) return math.abs(a - c) <= SNAP_DIST end
    local function vline(x, y1, y2) out[#out + 1] = { x = x, y1 = y1, y2 = y2 } end
    local function hline(y, x1, x2) out[#out + 1] = { y = y, x1 = x1, x2 = x2 } end
    for _, o in ipairs(snapTargets(f)) do
        local ol, ob, orr, ot = boxOf(o)
        if ol then
            local y1, y2, x1, x2 = math.min(b, ob), math.max(t, ot), math.min(l, ol), math.max(r, orr)
            for _, x in ipairs({ ol, orr }) do
                if near(l, x) or near(r, x) then vline(x, y1, y2) end
            end
            if near((l + r) / 2, (ol + orr) / 2) then vline((ol + orr) / 2, y1, y2) end
            for _, y in ipairs({ ob, ot }) do
                if near(b, y) or near(t, y) then hline(y, x1, x2) end
            end
            if near((b + t) / 2, (ob + ot) / 2) then hline((ob + ot) / 2, x1, x2) end
        end
    end
    local W, H = UIParent:GetSize()
    if near((l + r) / 2, W / 2) then vline(W / 2, 0, H) end
    if near((b + t) / 2, H / 2) then hline(H / 2, 0, W) end
    return out
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

-- The frame a unit frame is attached to (its label), or nil; and letting it go where it is now.
function ns.attachedTo(unit)
    local u = unitData(unit)
    return u and u.attach and UNIT_LABEL[u.attach] or nil
end
function ns.detachFrame(unit)
    local f = frames[unit]
    if InCombatLockdown() or not f or not f:GetLeft() then return end
    local u = unitData(unit, true)
    local H = UIParent:GetHeight() * UIParent:GetEffectiveScale() / f:GetEffectiveScale()
    u.point, u.x, u.y = "TOPLEFT", f:GetLeft(), f:GetTop() - H
    u.attach, u.ax, u.ay = nil, nil, nil
    pcall(placeFrame, f, unit)
end

-- Edit Mode is only for moving the frames: the library's own settings dialog is kept out of sight, and
-- EditMode.lua puts a toolbar of our own on the frame you pick (its settings page, reset, detach).
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
        ns.addMover({
            frame = f, label = UNIT_LABEL[unit] .. (unit == "party" and " frames" or " frame"), page = unit, unit = unit,
            reset = function()
                if InCombatLockdown() then return end
                local u = unitData(unit, true)
                u.point, u.x, u.y, u.attach, u.ax, u.ay = nil, nil, nil, nil, nil, nil
                pcall(placeFrame, f, unit)
            end,
        })
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
            hooksecurefunc(dlg, "Update", function(d, selection)
                d:ClearAllPoints()
                d:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", -5000, -5000)
                d:SetAlpha(0)
                -- our toolbar on the frame picked instead (EditMode.lua)
                local sel = selection or d.selection
                if ns.EditKit then pcall(ns.EditKit.select, sel and sel.parent) end
            end)
            dlg:HookScript("OnHide", function() if ns.EditKit then pcall(ns.EditKit.hide) end end)
        end
    end)

    lib:RegisterCallback("layout", function(layoutName)
        activeLayout = layoutName
        applyAll()
        touchOptions()
    end)
    lib:RegisterCallback("enter", function() enterSample(); if ns.EditKit then pcall(ns.EditKit.enter) end end)
    lib:RegisterCallback("exit", function() exitSample(); if ns.EditKit then pcall(ns.EditKit.exit) end end)
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
    -- and the other boxes (raid-style party, Healer Mana, Buff Bars), saved where their Edit Mode spot is
    for i, m in ipairs(ns.MOVERS) do
        if not m.unit and m.store then
            local f = m.frame
            list[#list + 1] = {
                key = "WebbyFrames_box" .. i,
                label = "Webby " .. m.label,
                order = 520 + i,
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
                    m.store("CENTER", cx, cy)
                    pcall(m.place)
                end,
                clearPosition = function()
                    if not InCombatLockdown() and m.reset then pcall(m.reset) end
                end,
                applyPosition = function()
                    if not InCombatLockdown() then pcall(m.place) end
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
                    "castShow", "castText", "castIcon", "castTexture", "castSpark", "castFade", "castFadeTime",
                    "castColorCast", "castColorChannel", "castColorLocked", "castColorInterrupted", "castFlashColor", "absorbTexture", "absorbAlpha", "absorbColor", "healTexture", "healColor", "healAlpha","absorbGlow", "absorbGlowAlpha", "healGlow", "healGlowAlpha", "absorbBorder", "healBorder", "healPrediction", "absorbs", "damageTrail", "damageTrailTexture", "damageTrailColor", "damageTrailAlpha", "damageTrailDelay", "damagePredict",
                    "colorMode", "healthFade", "frameTint", "frameColor", "petHappy", "petColor", "comboPoints", "npcColor", "npcColorRGB",
                    "auraGap", "auraGrowth", "auraStack", "portraitStyle" }

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
    if unit == "party" then Party.applyRest() end
    touchOptions()
end

function copySettings(from, to)
    if InCombatLockdown() then print("|cff33ccffWebby Frames:|r can't copy in combat."); return end
    for _, key in ipairs(COPY_KEYS) do
        local v = getSetting(from, key)
        -- (the party's own names for the same choices: its members are players, each in their own class)
        if to == "party" then
            if key == "colorMode" and (v == "smart" or v == "reaction") then v = "class" end
            if key == "frameTint" and v == "class" then v = "theirclass" end
        end
        if v ~= nil then unitData(to, true)[key] = v end
    end
    local f = frames[to]
    if f then
        f.layoutLeft = nil
        applyUnit(f)
        pcall(updateAll, f)
        if lib then lib:RefreshFrameSettings(f) end
    end
    if to == "party" then Party.applyRest() end
    touchOptions()
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
    touchOptions()
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
-- Settings window: Options.lua (built at login: Opt.build)
---------------------------------------------------------------------------
local function addonVersion()
    local v
    pcall(function() v = C_AddOns.GetAddOnMetadata("WebbyFrames", "Version") end)
    return v or "?"
end


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
    -- Blizzard's party frames, while ours are on: ghosted like target and focus (invisible, unclickable,
    -- off the screen) rather than torn out, so Edit Mode and the rest of Blizzard's UI don't trip over
    -- them. (Turned back on, they need a /reload.) The raid-style party frames are left alone.
    if frameOn("party") and _G.PartyFrame then
        ghostHooks(_G.PartyFrame); ghostBlizzard(_G.PartyFrame)
    end
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
    if not (Opt.build and pcall(Opt.build)) then
        print("|cffff9900Webby Frames:|r couldn't build the settings window; Edit Mode still works.")
    end
    pcall(Opt.buildAddOnsPage)
    pcall(Opt.setupMinimap)
    if DB.enabled == false then return end

    for _, unit in ipairs(UNITS) do
        if unit == "party" then
            for i = 1, Party.SLOTS do createSmallFrame("party", "party" .. i, i) end
        elseif unit == "targettarget" or unit == "focustarget" or unit == "pet" then createSmallFrame(unit)
        else createFrame(unit) end
    end
    pcall(Party.init)
    if ns.PlayerExtras then pcall(ns.PlayerExtras.init) end   -- (weapon enchants, buff timer bars)
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
        if ns.openSettings then ns.openSettings() end     -- (the settings window's own, from Options.lua)
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
        if not f then print("|cff33ccffWebby Frames:|r no player frame."); return end
        pcall(updatePrediction, f)
        if not f.healBar then print("|cff33ccffWebby Frames:|r turn on Incoming heals or Absorb shields for the player frame first."); return end
        f.previewing = true
        f.hp:SetMinMaxValues(0, 100)
        f.hp:SetValue(100)
        for _, b in ipairs(f.predBars) do b:SetMinMaxValues(0, 100) end
        C_Timer.After(0.3, function()
            setBarValue(f, f.hp, 60)
            f.healBar:SetValue(getSetting("player", "healPrediction") and 20 or 0)
            ns.setShields(f, getSetting("player", "absorbs") and 15 or 0)
        end)
        local ok, err = pcall(showHit, f, "WOUND", "CRITICAL", 1234)      -- and a combat number on the portrait
        if not ok then print("|cff33ccffWebby Frames:|r combat number failed: " .. tostring(err)) end
        C_Timer.After(10, function() f.previewing = nil; pcall(updateAll, f) end)
        print("|cff33ccffWebby Frames:|r previewing heals (green), a shield, a heal-absorb (red) and a combat number on your frame for 10 seconds.")
    elseif msg == "crit" then
        -- a normal hit, then a crit, so the throw and the longer hold can be seen on your portrait
        local f = frames.player
        if not f then print("|cff33ccffWebby Frames:|r no player frame."); return end
        if DB.combatNumbers == false then print("|cff33ccffWebby Frames:|r combat numbers are off."); return end
        local ok, err = pcall(showHit, f, "WOUND", nil, 412)
        if not ok then print("|cff33ccffWebby Frames:|r combat number failed: " .. tostring(err)) end
        C_Timer.After(0.45, function()
            local ok2, err2 = pcall(showHit, f, "WOUND", "CRITICAL", 1840)
            if not ok2 then print("|cff33ccffWebby Frames:|r crit failed: " .. tostring(err2)) end
        end)
        print("|cff33ccffWebby Frames:|r a normal hit, then a crit, on your portrait.")
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
    elseif msg == "party" then
        -- the party frames' sample party (raid style or portrait frames)
        Party.toggleSamples()
    elseif msg == "glow" then
        -- what each frame's dispel glow is doing
        local p = "|cff33ccffWebby Frames:|r "
        print(p .. "glow pulse " .. (AuraKit.glowDriver and "running" or "not started") .. ", " .. #AuraKit.glowFrames .. " frames with the glow")
        for _, f in ipairs(AuraKit.glowFrames) do
            local typ = AuraKit.dispelType(f.wfUnit)
            print(p .. tostring(f.wfUnit) .. ": " .. (f.dglowWant and "on" or "off") .. (f:IsVisible() and "" or " (frame hidden)")
                .. ", dispellable debuff " .. (typ == nil and "unknown (the game won't say)" or tostring(typ))
                .. ", glow box " .. ((f.dispelBox and f.dispelBox:IsVisible()) and "up" or "not up")
                .. ", Blizzard's " .. (f.dispelBox == false and "unavailable" or (f.dispelBox and string.format("alpha %.2f", f.dispelBox:GetAlpha()) or "not made")))
            -- each debuff as the game reports it to us
            local ok, err = pcall(function()
                for i = 1, 40 do
                    local d = C_UnitAuras.GetAuraDataByIndex(f.wfUnit, i, "HARMFUL")
                    if not d then
                        if i == 1 then print(p .. "   no debuffs reported") end
                        break
                    end
                    print(p .. "   " .. tostring(d.name) .. ": dispel type " .. tostring(d.dispelName))
                end
            end)
            if not ok then print(p .. "   couldn't read its debuffs: " .. tostring(err)) end
        end
    elseif msg == "pets" then
        -- what each party slot's pet bar is doing
        local p = "|cff33ccffWebby Frames:|r "
        print(p .. "Pets is " .. (getSetting("party", "partyPets") and "on" or "off") .. (InCombatLockdown() and " (in combat)" or ""))
        for i = 1, Party.SLOTS do
            local f = Party.members[i]
            if f then
                local m = f.miniPet
                local unit = f.homeUnit or f.wfUnit
                local pet = Party.petOf(unit)
                local exists = false
                pcall(function() exists = UnitExists(pet) and true or false end)
                local where = "-"
                if m then pcall(function() local x, y = m:GetCenter(); where = x and string.format("%d, %d", x, y) or "nowhere" end) end
                print(p .. string.format("slot %d: %s, pet %s %s; bar %s, unit %s, shown %s, at %s", i, tostring(unit), pet,
                    exists and "exists" or "doesn't exist", m and "made" or "not made", m and tostring(m:GetAttribute("unit")) or "-",
                    m and tostring(m:IsShown()) or "-", where))
            end
        end
    elseif msg == "cost" then
        -- what the spell cost prediction saw on your last cast
        local f = frames.player
        local p = "|cff33ccffWebby Frames:|r "
        if not (f and f.costBar) then print(p .. "no player frame."); return end
        print(p .. "Spell cost is " .. (getSetting("player", "costPredict") and "on" or "off")
            .. "; cast starts seen: " .. tostring(f.costStarts or 0)
            .. "; C_Spell.GetSpellPowerCost " .. ((C_Spell and C_Spell.GetSpellPowerCost) and "yes" or "no")
            .. ", GetSpellPowerCost " .. (GetSpellPowerCost and "yes" or "no"))
        print(p .. "last cast: " .. ns.costReport(f.costSpell))
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
        print("  /webby crit - a normal hit, then a crit, on your portrait")
        print("  /webby party - a sample party on your party frames")
        print("  /webby cost - what the spell cost bar saw on your last cast")
        print("  /webby corner x y - fine-tune where the corner accent sits (right / up, in pixels)")
        print("  /webby export, /webby import - share a profile   /webby errors - anything that went wrong")
    else
        print("|cff33ccffWebby Frames:|r unknown command. Type |cff33ccff/webby help|r.")
    end
end

-- What the modules (Party.lua, ClickCasting.lua) use from this file.
ns.getSetting, ns.frameOn, ns.applyUnit, ns.updateAll, ns.threatColor = getSetting, frameOn, applyUnit, updateAll, threatColor
ns.AuraKit, ns.ART, ns.BAR_FILE, ns.POWER_FILE, ns.CIRCLE_FALLBACK = AuraKit, ART, BAR_FILE, POWER_FILE, CIRCLE_FALLBACK
ns.hasAtlas, ns.newBar, ns.setArt, ns.setFileMask, ns.resolveFont = hasAtlas, newBar, setArt, setFileMask, resolveFont
ns.defaultTip, ns.isSecret, ns.plain = defaultTip, isSecret, plain
ns.unitData, ns.resolveTexture, ns.defaultFor, ns.updateIndicators = unitData, resolveTexture, defaultFor, updateIndicators
-- (and for the settings window, Options.lua)
ns.UNITS, ns.UNIT_LABEL, ns.frames, ns.Extras, ns.setSetting = UNITS, UNIT_LABEL, frames, Extras, setSetting
ns.styleOverlay = styleOverlay     -- (the settings' heal and shield preview draws with it)
ns.DEFAULT_SETTINGS, ns.ALWAYS_SHOWN, ns.OWN_CLASS, ns.COLOR_MODES = DEFAULT_SETTINGS, ALWAYS_SHOWN, OWN_CLASS, COLOR_MODES
ns.hasCastAndThreat, ns.textureChoices, ns.fontChoices, ns.Profiles = hasCastAndThreat, textureChoices, fontChoices, Profiles
ns.moveTipToDefault, ns.addonVersion = moveTipToDefault, addonVersion
ns.CAST_BOX, ns.castBoxHeight, ns.setBarText = CAST_BOX, castBoxHeight, setBarText
ns.resetFrame, ns.copySettings, ns.openSettings, ns.openEditMode = resetFrame, copySettings, openSettings, openEditMode
