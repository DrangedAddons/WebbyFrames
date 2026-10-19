-- Webby Frames: buffs and debuffs, through Blizzard's AuraContainer (and the dispel glow, drawn by the
-- game too). Loads after WebbyFrames.lua (see the .toc), which shares what it needs through ns; the
-- frames call AuraKit.update when their unit or options change (the containers redraw on their own as
-- auras come and go).
local _, ns = ...
local AuraKit = ns.AuraKit
local ART, CAST_BOX, castBoxHeight, defaultTip, frames = ns.ART, ns.CAST_BOX, ns.castBoxHeight, ns.defaultTip, ns.frames
local getSetting, isSecret, OWN_CLASS, Party, unitData, UNITS = ns.getSetting, ns.isSecret, ns.OWN_CLASS, ns.Party, ns.unitData, ns.UNITS
local function updateIndicators(f) return ns.updateIndicators(f) end
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
        -- right of the frame: two rows beside its art (the party's default, like Retail's party frames)
        if pos == "side" then return "TOPLEFT", "TOPRIGHT", -4, -5 end
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
-- groups, in the order they show: buffs, your own debuffs (only with "bigger own debuffs"), the rest

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
    -- (the game fills the icon's tooltip; the GameTooltip hook by moveTipToDefault moves it to the
    -- default spot. The game's aura buttons don't take script hooks.)
    b.webbyAura = true
    -- 1px edge: black behind every icon; on debuffs a second, white edge layer on top that the
    -- container tints by dispel type (see below)
    b.webbyBack = b:CreateTexture(nil, "BACKGROUND", nil, 0)
    b.webbyBack:SetAllPoints()
    b.webbyBack:SetColorTexture(0, 0, 0, 1)
    b.webbyEdge = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    b.webbyEdge:SetAllPoints()
    b.webbyEdge:SetColorTexture(1, 1, 1, 1)
    -- (the 1px edge in whole screen pixels, crisp at any scale)
    local px = 1
    pcall(function()
        local _, ph = GetPhysicalScreenSize()
        local es = (f.ov or f.hp or UIParent):GetEffectiveScale()
        if ph and ph > 0 and es and es > 0 then px = 768 / ph / es end
    end)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", px, -px)
    icon:SetPoint("BOTTOMRIGHT", -px, px)
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
    if b.webbyMine then size = math.floor(size * 1.35 + 0.5) end     -- (your own debuffs, bigger)
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

-- One of Blizzard's aura orders (AuraContainerSortMethod: Default, UnitFrameDebuff, BigDefensive,
-- Expiration, Name ...), or nil on a client without it. (A global table, not under Enum.)
function AuraKit.sortBy(name)
    local E = rawget(_G, "AuraContainerSortMethod") or (Enum and Enum.AuraContainerSortMethod)
    return E and E[name]
end

-- The frame's container, made on first use; nil if the client doesn't have AuraContainer.
function AuraKit.container(f)
    if f.auraContainer ~= nil then return f.auraContainer or nil end
    local ok, c = pcall(CreateFrame, "AuraContainer", nil, f.ov or f, "CustomAuraContainerTemplate")
    if not (ok and c) then f.auraContainer = false; return nil end
    local function initBuff(b) pcall(AuraKit.styleButton, f, b) end
    local function initDebuff(b) b.webbyDebuff = true; pcall(AuraKit.styleButton, f, b) end
    local function initMine(b) b.webbyDebuff, b.webbyMine = true, true; pcall(AuraKit.styleButton, f, b) end
    local ok2 = pcall(function()
        c:SetUnit(f.wfUnit)
        c:AddAuraGroup("buffs", "HELPFUL", { initializeFrame = initBuff })
        c:AddAuraGroup("debuffsMine", "HARMFUL|PLAYER", { initializeFrame = initMine })
        c:AddAuraGroup("debuffs", "HARMFUL", { initializeFrame = initDebuff })
        c:SetAuraGroupEnabled("debuffsMine", false)
    end)
    if not ok2 then c:Hide(); f.auraContainer = false; return nil end
    f.auraContainer = c
    return c
end


-- Dispel glow: when a friendly unit has a debuff you can dispel (or, Dispel glow for: any dispellable
-- one), the frame takes that debuff's colour (magic blue, curse purple, disease brown, poison green) and
-- pulses the way the player frame does while resting: its border (portrait ring included) recoloured,
-- with a glow on it and just round it. It's drawn by the game: an aura container whose one "debuff you
-- can dispel" button is copies of the border, tinted by the game per dispel type, so it works in combat
-- too, when the debuffs themselves are hidden from addons, and costs nothing while nobody has one (no
-- polling). The pulse is the box's alpha (AuraKit.startGlowPulse). On the player frame the resting /
-- combat glow takes the colour too: that one needs the type itself, read when your auras change
-- (AuraKit.auraChanged), and stays as it is while the game won't say.
-- (any frame with "Dispel glow" on: every frame's default)
local function copyBorder(t, f)
    t:SetTexture(f.border:GetTexture())
    t:SetTexCoord(f.border:GetTexCoord())
end
-- the glow's copies of the frame's border art: { px past the border, blend mode }. A plain one, greyed
-- and tinted, takes the border over in the dispel colour; the added-light ones on it and just round it
-- make it glow.
AuraKit.GLOW_LAYERS = { { 0, "BLEND" }, { 0, "ADD" }, { 3, "ADD" } }

-- dispel types, the one shown first when a unit has several
AuraKit.DISPEL_ORDER = { "Magic", "Curse", "Disease", "Poison" }
AuraKit.ALL_DISPEL = { includeDispelTypes = { Magic = true, Curse = true, Disease = true, Poison = true } }

-- The type of a debuff on `u` that you can dispel ("Magic", "Curse", "Disease", "Poison"), or with
-- `all` any dispellable one; false for none (or an enemy: nothing of theirs is yours to dispel), nil
-- when the game won't say. ("RAID" is the game's own "you can dispel this" filter.)
-- (on every aura change of yours: one scratch table, no throwaway functions)
local found = {}
function AuraKit.dispelType(u, all)
    if ns.plain(UnitCanAttack, "player", u) then return false end
    wipe(found)
    local filter = all and "HARMFUL" or "HARMFUL|RAID"
    for i = 1, 40 do
        local ok, d = pcall(C_UnitAuras.GetAuraDataByIndex, u, i, filter)
        if not ok or isSecret(d) then return nil end
        if not d then break end
        local t = d.dispelName
        if isSecret(t) then return nil end
        if t and t ~= "" then found[t] = true end
    end
    for _, t in ipairs(AuraKit.DISPEL_ORDER) do if found[t] then return t end end
    return false
end

-- A dispel type's colour (r, g, b).
function AuraKit.dispelRGB(typ)
    local c = AuraKit.dispelColors()[typ]
    if c then return c:GetRGB() end
    return 0.8, 0, 0
end

-- The pulse, the resting glow's (Blizzard's PlayerFrame_OnUpdate): from 55/255 straight up to full over
-- half a second, then straight back down. From the clock, so every glow pulses together.
function AuraKit.pulseAlpha()
    local p = GetTime() % 1
    local a = p < 0.5 and (55 + p * 400) / 255 or (255 - (p - 0.5) * 400) / 255
    return math.max(0, math.min(1, a))
end

-- The player frame's resting / combat glow in the debuff's colour (f.dispelType -> f.dispelRGB).
function AuraKit.paintGlow(f)
    local typ = f.dispelType
    f.dispelRGB = nil
    if type(typ) == "string" then f.dispelRGB = { AuraKit.dispelRGB(typ) } end
    pcall(updateIndicators, f)
end

-- A frame's unit's auras changed (UNIT_AURA), or its unit did: only the player frame's glow colour
-- needs the debuff's type itself; everything else redraws on its own.
function AuraKit.auraChanged(f)
    if not f.status then return end
    local typ = false
    if f.dglowWant then typ = AuraKit.dispelType(f.wfUnit, getSetting(f.baseUnit, "dispelWho") == "all") end
    if typ == nil then return end          -- (hidden: keep what's shown)
    if typ ~= f.dispelType then f.dispelType = typ; AuraKit.paintGlow(f) end
end

-- Every frame of a pulse: the glow boxes' alpha (the box shows nothing without a debuff, so this is all
-- the work there is).
AuraKit.glowFrames = {}
function AuraKit.startGlowPulse()
    if AuraKit.glowDriver then return end
    local d = CreateFrame("Frame")
    d:SetScript("OnUpdate", function()
        local a = AuraKit.pulseAlpha()
        for _, f in ipairs(AuraKit.glowFrames) do
            local c = f.dispelBox
            if c and f.dglowWant and c:IsVisible() then c:SetAlpha(a) end
        end
    end)
    AuraKit.glowDriver = d
end

function AuraKit.dispelGlow(f)
    local want = f.border and getSetting(f.baseUnit, "dispelGlow") and true or false
    f.dglowWant = want
    if not f.glowListed then
        f.glowListed = true
        AuraKit.glowFrames[#AuraKit.glowFrames + 1] = f
        AuraKit.startGlowPulse()
    end
    local c = f.dispelBox
    if not want then
        if c then c:Hide() end
        AuraKit.auraChanged(f)
        return
    end
    if c == false then return end
    if c == nil then
        local ok, box = pcall(CreateFrame, "AuraContainer", nil, f, "CustomAuraContainerTemplate")
        if not (ok and box) then f.dispelBox = false; return end
        local function init(b)
            pcall(function()
                local styles = Enum.CustomAuraButtonDispelTypeTextureStyle
                for _, layer in ipairs(AuraKit.GLOW_LAYERS) do
                    local grow, mode = layer[1], layer[2]
                    local t = b:CreateTexture(nil, "OVERLAY", nil, mode == "BLEND" and 6 or 7)
                    t:SetPoint("TOPLEFT", -grow, grow)
                    t:SetPoint("BOTTOMRIGHT", grow, -grow)
                    copyBorder(t, f)
                    t:SetBlendMode(mode)
                    t:SetDesaturated(true)
                    b:AddDispelTypeTexture(t, {
                        style = styles and styles.PreserveAsset,
                        showWhenHarmful = true,
                        showWithoutDispelType = false,
                        customDispelColorMap = AuraKit.dispelColors(),
                    })
                end
                b:EnableMouse(false)
            end)
            -- (made when a dispellable debuff first lands: the border's size now)
            pcall(function() b:SetSize(f.border:GetSize()) end)
        end
        if not pcall(function()
            box:SetUnit(f.wfUnit)
            box:AddAuraGroup("dispel", "HARMFUL|RAID", { initializeFrame = init, maxFrameCount = 1 })
        end) then box:Hide(); f.dispelBox = false; return end
        box:SetFrameLevel(f:GetFrameLevel())     -- (under the bars, f + 1, and the text and icons above)
        f.dispelBox = box
        c = box
    end
    pcall(function() if c:GetUnit() ~= f.wfUnit then c:SetUnit(f.wfUnit) end end)
    -- only yours, or any dispellable one (enemies never: their debuffs aren't yours to dispel)
    local hostile = false
    pcall(function() hostile = UnitCanAttack("player", f.wfUnit) and true or false end)
    pcall(c.SetAuraGroupFilterString, c, "dispel", getSetting(f.baseUnit, "dispelWho") == "all" and "HARMFUL" or "HARMFUL|RAID")
    pcall(c.SetAuraGroupCandidateFilters, c, "dispel", hostile and { includeDispelTypes = {} } or AuraKit.ALL_DISPEL)
    local w, h = ART.smallBorder[2], ART.smallBorder[3]
    pcall(function() w, h = f.border:GetSize() end)
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", f.border, "TOPLEFT")
    pcall(c.SetSize, c, w, h)
    c:Show()
    AuraKit.auraChanged(f)
end

-- every unit frame
function AuraKit.allFrames()
    local list = {}
    for _, unit in ipairs(UNITS) do if frames[unit] then list[#list + 1] = frames[unit] end end
    for i = 2, Party.SLOTS do if Party.members[i] then list[#list + 1] = Party.members[i] end end   -- (party slots 2 - 4)
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
                if other.baseUnit == f.baseUnit then pcall(AuraKit.update, other) end
            end
        end)
        m:SetScript("OnEnter", function(self)
            defaultTip(self)
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
-- (and the containers' own preview: full rows of sample icons, so you can see how the buffs and debuffs
-- will sit, party frames included, without anyone having any)
function AuraKit.setEditing(on)
    AuraKit.editing = on and true or nil
    for _, f in ipairs(AuraKit.allFrames()) do
        pcall(AuraKit.update, f)
        local c = f.auraContainer
        if c then pcall(c.SetEditModePreviewEnabled, c, on and true or false) end
    end
end

function AuraKit.update(f)
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
    if pos == "side" and not f.small then pos = "below" end      -- (only the small frames have room beside them)
    -- beside the frame there's room for two rows: buffs and debuffs a row's worth each at most, so
    -- together they never spill past the frame (the ones that matter come first)
    if pos == "side" then max = math.min(max, perRow) end
    local up = (pos == "above")
    local gap = getSetting(base, "auraGap")
    gap = (type(gap) == "number" and gap >= 0) and gap or AURA_GAP
    local leftward = getSetting(base, "auraGrowth") == "left"
    pcall(function() if c:GetUnit() ~= f.wfUnit then c:SetUnit(f.wfUnit) end end)
    local hostile = false
    pcall(function() hostile = UnitCanAttack("player", f.wfUnit) and true or false end)
    -- Debuffs. "Only mine": just yours. "Bigger own debuffs": yours first, bigger (their own group), then
    -- everyone else's.
    local onlyMine = getSetting(base, "auraMine") and true or false
    local big = getSetting(base, "auraMineBig") and not OWN_CLASS[base] and true or false
    pcall(c.SetAuraGroupEnabled, c, "debuffsMine", showD and big)
    pcall(c.SetAuraGroupEnabled, c, "debuffs", showD and not (big and onlyMine))
    pcall(c.SetAuraGroupFilterString, c, "debuffs", big and "HARMFUL|!PLAYER" or (onlyMine and "HARMFUL|PLAYER" or "HARMFUL"))
    -- Buffs. Retail style: on a friend, only the buffs you put on them (your heals over time, shields);
    -- on an enemy, all of them. Everything: all of them.
    local retail = getSetting(base, "auraStyle") == "retail" and not hostile
    pcall(c.SetAuraGroupEnabled, c, "buffs", showB)
    pcall(c.SetAuraGroupFilterString, c, "buffs", retail and "HELPFUL|PLAYER" or "HELPFUL")
    -- Debuffs in Blizzard's own unit frame order (the ones that matter first: boss, crowd control,
    -- priority), on every frame; nothing is left out, only the order changes.
    local order = AuraKit.sortBy("UnitFrameDebuff")
    if order and not f.auraSorted then
        f.auraSorted = true
        pcall(c.SetAuraGroupSortMethod, c, "debuffs", order)
        pcall(c.SetAuraGroupSortMethod, c, "debuffsMine", order)
    end
    pcall(AuraKit.dispelGlow, f)
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
end


