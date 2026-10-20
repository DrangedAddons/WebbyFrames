-- Webby Frames: party frames
-- Two styles, one set of "party" options (the Party page's Style):
-- * Portrait frames: four small frames (party1 - party4). Slot 1 is frames.party and sits where it was
--   put; slots 2 - 4 stack under it, partyGap apart. The frames themselves are the small frames
--   WebbyFrames.lua builds (createSmallFrame); this file is what's party only: placing the slots, role
--   order, each member's pet, the role / leader / ready check / status icons, the threat glow and fading
--   out of range.
-- * Raid style: flat tiles (see "Raid style" below).
-- Loads after WebbyFrames.lua (see the .toc), which shares its helpers through ns.
local _, ns = ...
local Party = ns.Party
local getSetting, frameOn, applyUnit, updateAll, threatColor = ns.getSetting, ns.frameOn, ns.applyUnit, ns.updateAll, ns.threatColor
local AuraKit, ART, BAR_FILE, POWER_FILE, CIRCLE_FALLBACK = ns.AuraKit, ns.ART, ns.BAR_FILE, ns.POWER_FILE, ns.CIRCLE_FALLBACK
local hasAtlas, newBar, setArt, setFileMask, resolveFont = ns.hasAtlas, ns.newBar, ns.setArt, ns.setFileMask, ns.resolveFont
local resolveTexture, defaultTip, unitData = ns.resolveTexture, ns.defaultTip, ns.unitData
local isSecret, plain = ns.isSecret, ns.plain

-- Showing and hiding by unit: the game's unit watch (shown while the unit exists). For every frame
-- (applyShown, Edit Mode).
function Party.watch(f) RegisterUnitWatch(f) end
function Party.unwatch(f) UnregisterUnitWatch(f) end

-- Slot 2 - 5: under the slot before it, or to its right (Layout: Side by side). Side by side leaves room
-- for buffs and debuffs to the right of each frame.
function Party.place(f)
    local prev = Party.members[f.partyIndex - 1]
    if not prev then return end
    local gap = tonumber(getSetting("party", "partyGap")) or 6
    f:ClearAllPoints()
    if getSetting("party", "partyLayout") == "horizontal" then
        f:SetPoint("TOPLEFT", prev, "TOPRIGHT", gap + Party.sideRoom(), 0)
    else
        f:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -(gap + Party.belowRoom(prev)))
    end
end

-- Room taken beside a party frame (side-by-side layout) and under it (stacked): its buffs and debuffs
-- when they sit beside it, its pet's mini frame.
function Party.sideRoom()
    local w = 0
    if getSetting("party", "auraPos") == "side" and (getSetting("party", "auraBuffs") or getSetting("party", "auraDebuffs")) then
        local size, gap = getSetting("party", "auraSize") or 16, getSetting("party", "auraGap") or 2
        w = w + (getSetting("party", "auraPerRow") or 6) * (size + gap)
    end
    return w
end
-- (under a member: room for their pet's bar only while they have a pet out)
function Party.belowRoom(prev)
    if not getSetting("party", "partyPets") then return 0 end
    local has = prev.partySample and prev.partySample.pet and true or false
    if not prev.partySample then
        pcall(function() has = UnitExists(Party.petOf(prev.homeUnit or prev.wfUnit)) and true or false end)
    end
    -- (the pet's height, less what tucks under the frame and its art's own transparent bottom edge)
    return has and math.floor(49 * Party.PET_SCALE - Party.PET_TUCK - 4 * Party.PET_SCALE + 0.5) or 0
end

-- partyN -> partypetN
function Party.petOf(unit)
    return (tostring(unit):gsub("^party", "partypet"))
end

-- Every slot back in place (a pet came or went): out of combat only, else once it ends.
function Party.reflow()
    if InCombatLockdown() then Party.pendingReflow = true; return end
    Party.pendingReflow = nil
    for i = 2, Party.SLOTS do
        local f = Party.members[i]
        if f then pcall(Party.place, f) end
    end
end

-- Each member's pet: a small copy of the party frame itself (the same border art, round portrait,
-- health and power bars with their shaped ends, the name), at PET_SCALE of it, hung under the member's
-- frame (part of it, so it moves, scales and fades with it), clickable to target. One per party slot,
-- made at login (secure buttons can't be made in combat); shown while the pet exists (the game's unit
-- watch). Health, power and the name come from the pet's unit events. The portrait is a rendered
-- model, refreshed about every two seconds. Values only go to setters.
Party.PET_SCALE = 0.6
Party.PET_INDENT, Party.PET_TUCK = 24, 2  -- in from the member frame's portrait side; up under its bottom edge
Party.PET_EVENTS = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE" }

-- Listen to `unit`, or to nothing. A hidden pet is not listening. Same unit twice does nothing.
function Party.petListen(m, unit)
    if m.petUnit == unit then return end
    for _, e in ipairs(Party.PET_EVENTS) do pcall(m.UnregisterEvent, m, e) end
    m.petUnit = unit
    if not unit then return end
    for _, e in ipairs(Party.PET_EVENTS) do pcall(m.RegisterUnitEvent, m, e, unit) end
end

function Party.makePet(f)
    local m = CreateFrame("Button", "WebbyFrames_partypet" .. f.partyIndex, f, "SecureUnitButtonTemplate")
    m:SetSize(120, 49)
    m:SetScale(Party.PET_SCALE)
    m:SetFrameLevel(f:GetFrameLevel() + 3)
    m:SetHitRectInsets(0, 6, 4, 4)
    m:RegisterForClicks("AnyUp")
    m:SetAttribute("type1", "target")
    m:SetAttribute("type2", "togglemenu")
    m.kind = "partypet"
    m.portrait = m:CreateTexture(nil, "BACKGROUND", nil, 1)
    m.portrait:SetSize(37, 37)
    m.pmask = m:CreateMaskTexture()
    if hasAtlas("CircleMask") then m.pmask:SetAtlas("CircleMask") else
        m.pmask:SetTexture(CIRCLE_FALLBACK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    end
    m.pmask:SetAllPoints(m.portrait)
    m.portrait:AddMaskTexture(m.pmask)
    local pbg = m:CreateTexture(nil, "BACKGROUND", nil, 0)
    pbg:SetColorTexture(0.05, 0.05, 0.05, 1)
    pbg:SetAllPoints(m.portrait)
    pbg:AddMaskTexture(m.pmask)
    m.border = m:CreateTexture(nil, "BACKGROUND", nil, 3)
    m.border:SetTexelSnappingBias(0)
    m.border:SetSnapToPixelGrid(false)
    m.hp, m.hpMask = newBar(m)
    m.mp, m.mpMask = newBar(m)
    local ov = CreateFrame("Frame", nil, m)
    ov:SetAllPoints()
    ov:SetFrameLevel(m:GetFrameLevel() + 5)
    m.name = ov:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    m.name:SetSize(68, 14)
    m.name:SetJustifyH("LEFT"); m.name:SetWordWrap(false)
    m:SetScript("OnEnter", function(self)
        pcall(function()
            ns.defaultTip(self)
            if GameTooltip:SetUnit(self:GetAttribute("unit")) ~= false then GameTooltip:Show() end
        end)
    end)
    m:SetScript("OnLeave", function() GameTooltip:Hide() end)
    m:SetScript("OnEvent", function(self)
        if self:IsShown() then pcall(Party.paintPet, self, true) end
    end)
    m:HookScript("OnShow", function(self)
        local u = self:GetAttribute("unit")
        if u then Party.petListen(self, u) end
        pcall(Party.paintPet, self)
    end)
    m:HookScript("OnHide", function(self) Party.petListen(self, nil) end)
    m:Hide()
    return m
end

-- The pet's art for the side its member's portrait is on (as applySmallLayout lays out the frame).
function Party.layoutPet(m, left)
    if m.left == left then return end
    m.left = left
    m.portrait:ClearAllPoints()
    m.portrait:SetPoint(left and "TOPLEFT" or "TOPRIGHT", m, left and "TOPLEFT" or "TOPRIGHT", left and 5 or -5, -5)
    m.border:ClearAllPoints()
    setArt(m.border, ART.smallBorder, not left)
    m.border:SetPoint("CENTER", m, "CENTER", 0, 0)
    m.hp:ClearAllPoints(); m.mp:ClearAllPoints()
    m.hp:SetSize(70, 10.5)
    m.hp:SetPoint("TOPLEFT", m, "TOPLEFT", left and 44 or 6, -16.5)
    m.mp:SetSize(74, 7.5)
    m.mp:SetPoint("TOPLEFT", m, "TOPLEFT", left and 40 or 6, -27.5)
    m.hpTex, m.mpTex = nil, nil
    m.name:ClearAllPoints()
    if left then m.name:SetPoint("BOTTOMLEFT", m.hp, "TOPLEFT", 0, 1) else m.name:SetPoint("BOTTOMLEFT", m.hp, "TOPLEFT", 2, 1) end
    m:SetHitRectInsets(left and 0 or 6, left and 6 or 0, 4, 4)
end

-- `barsOnly`: health, power and the name. The portrait and the font stay for a full paint.
function Party.paintPet(m, barsOnly)
    local u = m:GetAttribute("unit")
    if not (u and UnitExists(u)) then return end
    local f = m:GetParent()
    Party.layoutPet(m, f.layoutLeft ~= false)
    -- border in the member frame's colour (Frame colour), as drawn otherwise
    local c = f.tintColor
    pcall(m.border.SetDesaturated, m.border, c and true or false)
    if c then m.border:SetVertexColor(c[1], c[2], c[3]) else m.border:SetVertexColor(1, 1, 1) end
    -- health: the party's chosen texture, or the frame's own green fill
    local hpTex = f.customTex or (BAR_FILE.small .. "Health")
    if m.hpTex ~= hpTex then
        m.hpTex = hpTex
        m.hp:SetStatusBarTexture(hpTex)
        setFileMask(m.hp, m.hpMask, "uipartyframeportraitonhealthmask", 128, 16.5, -29, 3, not m.left)
        if f.customTex then m.hp:SetStatusBarColor(0.1, 0.8, 0.1) else m.hp:SetStatusBarColor(1, 1, 1) end
    end
    -- power: the frame's fill for the pet's power type
    local _, token = UnitPowerType(u)
    if isSecret(token) then token = nil end
    local mpTex = f.powerTex or (BAR_FILE.small .. (POWER_FILE[token or ""] or "Mana"))
    if m.mpTex ~= mpTex then
        m.mpTex = mpTex
        m.mp:SetStatusBarTexture(mpTex)
        setFileMask(m.mp, m.mpMask, "uipartyframeportraitonmanamask", 128, 16.5, -27, 4, not m.left)
    end
    -- (setters take hidden values as they are)
    m.hp:SetMinMaxValues(0, UnitHealthMax(u)); m.hp:SetValue(UnitHealth(u))
    m.mp:SetMinMaxValues(0, UnitPowerMax(u)); m.mp:SetValue(UnitPower(u))
    m.name:SetText(UnitName(u))
    if not barsOnly then
        pcall(SetPortraitTexture, m.portrait, u)
        local font = resolveFont(getSetting("party", "font"))
        if m.font ~= font then
            m.font = font
            -- (its own font remembered, so Default goes back to it; other alphabets kept: ns.setFont)
            if not m.name.wfFontOrig then m.name.wfFontOrig = { m.name:GetFont() } end
            local o = m.name.wfFontOrig
            pcall(ns.setFont, m.name, font or o[1], o[2], o[3])
        end
    end
    if m.sampleName then m.name:SetText(m.sampleName) end      -- (a sample member's pet)
end

-- A slot's pet: its unit (from the slot's unit), where it sits, on or off. Its unit and showing only
-- change out of combat; a change in combat waits (Party.arrange after it).
function Party.minis(f)
    if not f.partyIndex then return end
    if InCombatLockdown() then Party.pendingArrange = true; return end
    local m = f.miniPet or Party.makePet(f)
    f.miniPet = m
    -- under the frame, in from its portrait side (offsets in the pet's own, smaller scale: its art's
    -- transparent top edge tucks under the frame)
    m:ClearAllPoints()
    local s = Party.PET_SCALE
    if f.layoutLeft == false then
        m:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", -Party.PET_INDENT / s, Party.PET_TUCK / s)
    else
        m:SetPoint("TOPLEFT", f, "BOTTOMLEFT", Party.PET_INDENT / s, Party.PET_TUCK / s)
    end
    local s = f.partySample
    m.sampleName = s and s.pet or nil
    if s then
        UnregisterUnitWatch(m)
        m:SetAttribute("unit", "player")
        m:SetShown((s.pet and getSetting("party", "partyPets")) and true or false)
    else
        m:SetAttribute("unit", Party.petOf(f.homeUnit or f.wfUnit))
        if Party.portraitsOn() and getSetting("party", "partyPets") then RegisterUnitWatch(m) else UnregisterUnitWatch(m); m:Hide() end
    end
    Party.petListen(m, m:IsShown() and m:GetAttribute("unit") or nil)
    pcall(Party.paintPet, m)
end

-- Portrait pets off: no unit watch and no pet events. Out of combat only (the watch is secure).
function Party.hidePets()
    if InCombatLockdown() then return end
    for i = 1, Party.SLOTS do
        local m = Party.members[i] and Party.members[i].miniPet
        if m then
            UnregisterUnitWatch(m)
            m:Hide()
            Party.petListen(m, nil)
        end
    end
end


-- Which unit each slot shows: party1 - 4, as Blizzard orders them or by role (tank, healer, damage).
-- A slot's unit can only change out of combat; a change while in one waits for it to end.
local ROLE_RANK = { TANK = 1, HEALER = 2, DAMAGER = 3 }
function Party.arrange()
    if InCombatLockdown() then Party.pendingArrange = true; return end
    -- Portrait frames not in use (party off, or raid style): no role sort, no repaint of hidden slots.
    if not Party.portraitsOn() then
        Party.pendingArrange = nil
        Party.hidePets()
        return
    end
    if Party.testing then return end          -- (the sample party keeps the slots; stopping it arranges)
    Party.pendingArrange = nil
    local list = {}
    for i = 1, 4 do list[#list + 1] = "party" .. i end
    if getSetting("party", "partySort") == "role" then
        local rank = {}
        for i, u in ipairs(list) do
            local r = 9
            pcall(function()
                if UnitExists(u) then r = ROLE_RANK[UnitGroupRolesAssigned(u)] or 4 end
            end)
            rank[u] = r * 10 + i
        end
        table.sort(list, function(a, b) return rank[a] < rank[b] end)
    end
    for slot = 1, Party.SLOTS do
        local f = Party.members[slot]
        if f then
            Party.setUnit(f, list[slot] or ("party" .. slot))
            pcall(Party.minis, f)
        end
    end
    -- (click casting again: a resurrect binding names each frame's unit)
    if ns.Click and ns.Click.header then pcall(ns.Click.apply) end
end

-- Portrait frames sit hidden while the raid style is on. Drop their unit events until they are
-- shown again (applyShown). Other frames keep theirs.
-- Frame events (not unit events) a party slot also has. Silence drops them; listen puts them back.
Party.FRAME_EVENTS = { "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }

function Party.silence(f)
    if not f or f.baseUnit ~= "party" then return end
    for _, e in ipairs(Party.UNIT_EVENTS) do pcall(f.UnregisterEvent, f, e) end
    for _, e in ipairs(Party.FRAME_EVENTS) do pcall(f.UnregisterEvent, f, e) end
end

function Party.listen(f)
    if not f or f.baseUnit ~= "party" or f.wfOff then return end
    local unit = f.homeUnit or f:GetAttribute("unit") or f.wfUnit
    if not unit then return end
    for _, e in ipairs(Party.UNIT_EVENTS) do
        pcall(f.UnregisterEvent, f, e)
        pcall(f.RegisterUnitEvent, f, e, unit)
    end
    for _, e in ipairs(Party.FRAME_EVENTS) do pcall(f.RegisterEvent, f, e) end
end

-- Gives a party slot another unit: its secure unit, its unit events, how it shows and hides, and a
-- repaint. (In Edit Mode it keeps showing you as the stand-in until Edit Mode closes.)
-- While the portrait frames are off, the events stay unregistered.
function Party.setUnit(f, unit)
    if f.homeUnit == unit then return end
    f.homeUnit = unit
    f:SetAttribute("unit", unit)
    if f.wfOff then Party.silence(f) else Party.listen(f) end
    if not AuraKit.editing then
        f.wfUnit = unit
        if not f.wfOff then Party.watch(f) end
    end
    f.lastGUID = nil
    pcall(updateAll, f)
    if Party.minis then pcall(Party.minis, f) end
end

local ROLE_ATLAS = { TANK = "roleicon-tiny-tank", HEALER = "roleicon-tiny-healer", DAMAGER = "roleicon-tiny-dps" }
local READY_TEX = { ready = "READY_CHECK_READY_TEXTURE", notready = "READY_CHECK_NOT_READY_TEXTURE", waiting = "READY_CHECK_WAITING_TEXTURE" }

-- The role, leader and ready check icons on a party frame's portrait, made on first use.
function Party.icons(f)
    if f.partyIcons then return f.partyIcons end
    local p, ov = f.portrait, f.ov
    local icons = {}
    icons.role = ov:CreateTexture(nil, "OVERLAY", nil, 6)
    icons.role:SetSize(14, 14)
    icons.role:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", -3, -3)
    icons.leader = ov:CreateTexture(nil, "OVERLAY", nil, 6)
    icons.leader:SetSize(13, 13)
    icons.leader:SetPoint("BOTTOM", p, "TOP", -10, -5)
    icons.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
    icons.ready = ov:CreateTexture(nil, "OVERLAY", nil, 7)
    icons.ready:SetSize(22, 22)
    icons.ready:SetPoint("CENTER", p, "CENTER")
    -- aggro: a red copy of the frame's border art, glowing (added light)
    icons.aggro = ov:CreateTexture(nil, "OVERLAY", nil, 5)
    icons.aggro:SetPoint("TOPLEFT", f.border, "TOPLEFT")
    icons.aggro:SetPoint("BOTTOMRIGHT", f.border, "BOTTOMRIGHT")
    icons.aggro:SetBlendMode("ADD")
    for _, t in pairs(icons) do t:Hide() end
    f.partyIcons = icons
    return icons
end

-- What's in the middle of a member's portrait, most pressing first: the ready check, then a summon
-- (pending, accepted, declined), an incoming resurrection, or being in another phase.
local SUMMON_ATLAS = { [1] = "Raid-Icon-SummonPending", [2] = "Raid-Icon-SummonAccepted", [3] = "Raid-Icon-SummonDeclined" }
function Party.centerIcon(u)
    if Party.readyCheck or Party.readyLinger then
        local status = plain(GetReadyCheckStatus, u)
        local tex = status and READY_TEX[status] and _G[READY_TEX[status]]
        if tex then return "file", tex end
    end
    local IS = C_IncomingSummon
    local summon = IS and plain(IS.HasIncomingSummon, u) and plain(IS.IncomingSummonStatus, u)
    if summon and SUMMON_ATLAS[summon] then return "atlas", SUMMON_ATLAS[summon] end
    if plain(UnitHasIncomingResurrection, u) then return "file", "Interface\\RaidFrame\\Raid-Icon-Rez" end
    local phased
    if UnitPhaseReason then
        local ok, why = pcall(UnitPhaseReason, u)
        phased = ok and not isSecret(why) and why ~= nil
    elseif UnitInPhase then
        phased = plain(UnitInPhase, u) == false
    end
    if phased then return "file", "Interface\\TargetingFrame\\UI-PhasingIcon" end
end


-- Role, leader and ready check for one party frame (only while it shows a real party member).
function Party.updateIcons(f)
    local icons = Party.icons(f)
    local u = f.wfUnit
    local real = not AuraKit.editing and not f.partySample and UnitExists(u)      -- (not the stand-ins)
    -- role
    local role = real and plain(UnitGroupRolesAssigned, u) or nil
    local atlas = role and ROLE_ATLAS[role]
    if atlas and pcall(icons.role.SetAtlas, icons.role, atlas) then icons.role:Show() else icons.role:Hide() end
    -- leader
    icons.leader:SetShown((real and plain(UnitIsGroupLeader, u)) and true or false)
    -- the middle of the portrait: ready check (it stays a few seconds after the check ends, as
    -- Blizzard's does), summon, resurrection, another phase
    local kind, what
    if real then kind, what = Party.centerIcon(u) end
    if kind == "atlas" and pcall(icons.ready.SetAtlas, icons.ready, what) then icons.ready:Show()
    elseif kind == "file" then icons.ready:SetTexture(what); icons.ready:SetTexCoord(0, 1, 0, 1); icons.ready:Show()
    else icons.ready:Hide() end
    -- threat glow, as the target frame's threat options say (a glow, in its colours): when the member
    -- is about to pull (1), has aggro (2) or holds it securely (3)
    local status
    local mode = getSetting("target", "threatShow")
    if real and (mode == "both" or mode == "glow") then
        local s = plain(UnitThreatSituation, u)
        if s and s >= 1 then status = s end
    end
    if status then
        icons.aggro:SetTexture(f.border:GetTexture())
        icons.aggro:SetTexCoord(f.border:GetTexCoord())
        -- (the gradient needs a %: about to pull is most of the way, having it is all the way)
        local r, g, b = threatColor("target", status, status == 1 and 80 or 100)
        icons.aggro:SetVertexColor(r, g, b, 1)
    end
    icons.aggro:SetShown(status ~= nil)
end

-- Party slots 2 - 4 after the party's options were reset or copied (slot 1 is done as frames.party).
function Party.applyRest()
    for i = 2, Party.SLOTS do
        local f = Party.members[i]
        if f then
            f.layoutLeft = nil
            pcall(applyUnit, f)
            pcall(updateAll, f)
        end
    end
end

function Party.updateAllIcons()
    if not Party.portraitsLive() then return end
    for i = 1, Party.SLOTS do
        local f = Party.members[i]
        if f then pcall(Party.updateIcons, f) end
    end
end

-- Out of range: the frame fades (to "Out of range" on the Party page). UnitInRange's answer can be
-- hidden from addons in instances, so it goes straight to SetAlphaFromBoolean, which takes a hidden
-- answer too.
function Party.updateRange(f)
    local RANGE_OUT = tonumber(getSetting("party", "rangeAlpha")) or 0.45
    local u = f.wfUnit
    if f.partySample then f:SetAlpha((f.partySample.far and getSetting("party", "rangeFade")) and RANGE_OUT or 1); return end
    if u == "player" or not getSetting("party", "rangeFade") or not UnitExists(u) then f:SetAlpha(1); return end
    local ok, inRange, checked = pcall(UnitInRange, u)
    -- (not checked: the game can't tell, e.g. in another zone; then it stays fully shown)
    if not ok or (not isSecret(checked) and checked == false) or (not isSecret(inRange) and inRange == nil) then f:SetAlpha(1); return end
    if f.SetAlphaFromBoolean and pcall(f.SetAlphaFromBoolean, f, inRange, 1, RANGE_OUT) then return end
    if isSecret(inRange) then f:SetAlpha(1); return end
    f:SetAlpha(inRange and 1 or RANGE_OUT)
end

---------------------------------------------------------------------------
-- Sample party (portrait frames): made-up members on the four frames, to see the options without a
-- group: names, health, class portraits and frame colours, and a hunter's pet. From the Party page's
-- Preview button or /webby party (the raid style has its own, RP.toggleTest). Out of combat only;
-- combat ends it. The frames show you underneath (a harmless real unit), painted over.
---------------------------------------------------------------------------
Party.SAMPLES = {
    { name = "Brakka", class = "WARRIOR", hp = 0.64, mp = 0.3 },
    { name = "Lyssandra", class = "PRIEST", hp = 0.81, mp = 0.55, missing = 1243 },
    { name = "Thornek", class = "HUNTER", hp = 0.47, mp = 0.7, pet = "Fang" },
    { name = "Fenwick", class = "MAGE", hp = 0.12, mp = 0.9, far = true },
}

-- One frame painted as its sample member (after its normal paint, which shows you).
function Party.paintSample(f)
    local s = f.partySample
    if not s then return end
    f.name:SetText(s.name)
    pcall(function()
        f.hp:SetMinMaxValues(0, 100); f.hp:SetValue(s.hp * 100)
        f.mp:SetMinMaxValues(0, 100); f.mp:SetValue(s.mp * 100)
    end)
    pcall(function() if f.hpText:IsShown() then f.hpText:SetFormattedText("%d%%", s.hp * 100) end end)
    pcall(function() if f.mpText:IsShown() then f.mpText:SetFormattedText("%d%%", s.mp * 100) end end)
    -- their health colour, as the Health colour says (the frame underneath is you, so its own colour
    -- would be your class's): class colour, dark, your own, or by health; Default stays as drawn
    local mode = getSetting("party", "colorMode")
    local r, g, b
    if mode == "class" or mode == "smart" or mode == "reaction" then
        local c = (RAID_CLASS_COLORS or {})[s.class]
        if c then r, g, b = c.r, c.g, c.b end
    elseif mode == "dark" then r, g, b = 0.2, 0.2, 0.22
    elseif mode == "custom" then
        local c = getSetting("party", "healthColorRGB")
        if type(c) == "table" then r, g, b = c[1], c[2], c[3] else r, g, b = 0.15, 0.75, 0.25 end
    elseif mode == "gradient" then
        local h = math.max(0, math.min(1, s.hp))
        if h > 0.5 then local k = (h - 0.5) * 2; r, g, b = 0.95 - 0.8 * k, 0.82 + 0.03 * k, 0.1 + 0.15 * k
        else local k = h * 2; r, g, b = 0.9 + 0.05 * k, 0.12 + 0.7 * k, 0.1 end
    end
    if r then
        local tex = f.hp:GetStatusBarTexture()
        f.hp:SetStatusBarColor(r, g, b, 1)
        if tex then tex:SetAlpha(tonumber(getSetting("party", "hpAlpha")) or 1) end
    end
    -- their class icon for a portrait
    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[s.class]
    if coords then
        f.portrait:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
        f.portrait:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    end
    -- the frame art in their class colour (Frame colour: Their class colour)
    local c = getSetting("party", "frameTint") == "theirclass" and (RAID_CLASS_COLORS or {})[s.class]
    if c and f.border then
        pcall(f.border.SetDesaturated, f.border, true)
        f.border:SetVertexColor(c.r, c.g, c.b)
    end
    pcall(Party.updateIcons, f)
    pcall(Party.updateRange, f)
end

function Party.paintSamples()
    if not Party.testing then return end
    if not Party.portraitsOn() then return Party.stopSamples() end   -- (switched to the raid style, or off)
    for i = 1, Party.SLOTS do
        local f = Party.members[i]
        if f and f.partySample then pcall(updateAll, f); Party.paintSample(f); pcall(Party.minis, f) end
    end
    pcall(Party.reflow)
end

function Party.startSamples()
    if InCombatLockdown() then
        print("|cff33ccffWebby Frames:|r the sample party can't be shown in combat.")
        return
    end
    if not Party.portraitsOn() then return end
    Party.testing = true
    for i = 1, Party.SLOTS do
        local f = Party.members[i]
        if f then
            Party.unwatch(f)
            f.wfUnit = "player"
            f.partySample = Party.SAMPLES[i]
            f:Show()
            if f.auraContainer then pcall(f.auraContainer.SetEditModePreviewEnabled, f.auraContainer, true) end
        end
    end
    Party.paintSamples()
end

-- The secure half of stopping the sample party (unit watch, real units). Combat defers it.
function Party.finishSampleStop()
    if InCombatLockdown() then Party.sampleStop = true; return end
    Party.sampleStop = nil
    for i = 1, Party.SLOTS do
        local f = Party.members[i]
        if f then
            f.wfUnit = f.homeUnit or f.baseUnit
            if Party.portraitsOn() then Party.watch(f) else f:Hide() end
            f:SetAlpha(1)
            pcall(applyUnit, f)
            pcall(updateAll, f)
        end
    end
    pcall(Party.arrange)
    for i = 1, Party.SLOTS do if Party.members[i] then pcall(Party.minis, Party.members[i]) end end
    pcall(Party.reflow)
end

function Party.stopSamples()
    if not Party.testing then return end
    Party.testing = nil
    for i = 1, Party.SLOTS do
        local f = Party.members[i]
        if f then
            f.partySample = nil
            if f.miniPet then f.miniPet.sampleName = nil end
            f.portrait:SetTexCoord(0, 1, 0, 1)
            f:SetAlpha(1)
            if f.auraContainer then pcall(f.auraContainer.SetEditModePreviewEnabled, f.auraContainer, false) end
        end
    end
    if InCombatLockdown() then Party.sampleStop = true; Party.pendingArrange = true; return end
    Party.finishSampleStop()
end

-- The Party page's Preview button and /webby party: the sample party for the style in use.
function Party.toggleSamples()
    if getSetting("party", "partyStyle") == "raid" then
        if ns.RaidParty then ns.RaidParty.toggleTest() end
    elseif Party.testing then
        Party.stopSamples()
    else
        Party.startSamples()
    end
end

Party.GROUP = { "player", "party1", "party2", "party3", "party4" }
Party.GROUP_UNIT = { player = true, party1 = true, party2 = true, party3 = true, party4 = true }
Party.UNIT_ONLY = { UNIT_PHASE = true, UNIT_THREAT_SITUATION_UPDATE = true, UNIT_FLAGS = true, UNIT_CONNECTION = true, UNIT_PET = true }
Party.EVENTS = { "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "PLAYER_ROLES_ASSIGNED", "PLAYER_ENTERING_WORLD",
    "READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED", "PLAYER_REGEN_ENABLED",
    "INCOMING_RESURRECT_CHANGED", "INCOMING_SUMMON_CHANGED", "UNIT_PHASE", "UNIT_THREAT_SITUATION_UPDATE",
    "UNIT_FLAGS", "UNIT_CONNECTION", "UNIT_PET", "PLAYER_REGEN_DISABLED" }

-- Portrait frames are up, or still on screen because combat has not let them hide yet.
function Party.portraitsLive()
    if Party.portraitsOn() then return true end
    for i = 1, Party.SLOTS do
        local f = Party.members[i]
        if f and not f.wfOff then return true end
    end
end

function Party.onEvent(_, event, unit)
    -- (the unit events come for every unit about, nameplates included: only the group's matter)
    if Party.UNIT_ONLY[event] and not Party.GROUP_UNIT[unit] then return end
    if event == "PLAYER_REGEN_ENABLED" then
        -- a sample stop, a role sort or a pet reflow that had to wait out combat
        if Party.sampleStop then pcall(Party.finishSampleStop) end
        if Party.pendingArrange then pcall(Party.arrange) end
        if Party.pendingReflow then pcall(Party.reflow) end
        if not Party.portraitsLive() then
            Party.syncEvents()
            Party.syncTicker()
            return
        end
    end
    -- (portrait frames not in use: raid style, or the party frames off and already hidden)
    if not Party.portraitsLive() then
        if event == "PLAYER_REGEN_DISABLED" and Party.testing then Party.stopSamples() end
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        -- combat ends the sample party (the last moment its frames can still be changed)
        if Party.testing then Party.stopSamples() end
        return
    end
    -- who goes in which slot (role order): again when the group or its roles change
    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" or event == "PLAYER_ENTERING_WORLD" then
        pcall(Party.arrange)
    end
    -- a pet came or went (or the group changed): pet room under each member
    if event == "UNIT_PET" or event == "GROUP_ROSTER_UPDATE" then
        pcall(Party.reflow)
    end
    if event == "READY_CHECK" then
        Party.readyCheck, Party.readyLinger = true, nil
    elseif event == "READY_CHECK_FINISHED" then
        Party.readyCheck, Party.readyLinger = nil, true
        C_Timer.After(6, function() Party.readyLinger = nil; Party.updateAllIcons() end)
    end
    Party.updateAllIcons()
end

-- Range, five times a second, only while the portrait frames are in use. Pet bars come from unit
-- events; a shown pet's portrait is refreshed about every two seconds.
function Party.onTick()
    if not Party.portraitsLive() then return end
    for i = 1, Party.SLOTS do
        local f = Party.members[i]
        if f and f:IsShown() then pcall(Party.updateRange, f) end
        local m = f and f.miniPet
        if m and m:IsShown() then
            m.portraitTick = ((m.portraitTick or 0) + 1) % 10
            if m.portraitTick == 1 then
                local u = m:GetAttribute("unit")
                if u then pcall(SetPortraitTexture, m.portrait, u) end
            end
        end
    end
end

-- The portrait event frame listens only while those frames are in use. A combat-deferred sort keeps
-- the two regen events until it has run.
function Party.syncEvents()
    local ev = Party.ev
    if not ev then return end
    if Party.portraitsLive() then
        if Party.evMode ~= "all" then
            ev:UnregisterAllEvents()
            for _, e in ipairs(Party.EVENTS) do pcall(ev.RegisterEvent, ev, e) end
            Party.evMode = "all"
        end
    elseif Party.pendingArrange or Party.pendingReflow or Party.sampleStop or Party.testing then
        if Party.evMode ~= "regen" then
            ev:UnregisterAllEvents()
            ev:RegisterEvent("PLAYER_REGEN_ENABLED")
            ev:RegisterEvent("PLAYER_REGEN_DISABLED")
            Party.evMode = "regen"
        end
    elseif Party.evMode then
        ev:UnregisterAllEvents()
        Party.evMode = nil
    end
end

function Party.syncTicker()
    if Party.portraitsLive() then
        if not Party.rangeTicker then Party.rangeTicker = C_Timer.NewTicker(0.2, Party.onTick) end
    elseif Party.rangeTicker then
        Party.rangeTicker:Cancel()
        Party.rangeTicker = nil
    end
end

function Party.init()
    Party.ev = CreateFrame("Frame")
    Party.ev:SetScript("OnEvent", Party.onEvent)
    -- (listeners and the range ticker start from Party.sync, once applyAll has shown or hidden them)
    if ns.RaidParty then pcall(ns.RaidParty.init) end   -- (the raid-style tiles, made now so click casting gets them)
    if ns.Click then pcall(ns.Click.init) end     -- (click casting on the frames, now they're made)
end

---------------------------------------------------------------------------
-- Party extras, both styles: missing buffs, the healer mana list, tooltips
---------------------------------------------------------------------------
-- Tooltips on the party frames: always, out of combat only, or never (Party page).
function Party.tipAllowed()
    local mode = getSetting("party", "partyTooltip")
    if mode == "never" then return false end
    if mode == "ooc" then return not InCombatLockdown() end
    return true
end

-- Missing buffs: on each member, the icons of the buffs they lack that you can cast (any rank, or the
-- group version, counts as having it). One paladin blessing per member, by their role. By spell ID, so
-- any language works: you know a spell if you know any of its ranks; a member has a buff if they have
-- it under the spell's name in your language. Worked out when a member's buffs change (UNIT_AURA), the
-- group changes or you learn a spell, at most twice a second, and out of combat (buffing is); in combat
-- the icons stay as they were. (After EllesmereUI's Forever "Missing Buffs", used with its author's
-- permission.)
-- { cast: every rank you could know (group versions first), has: the buffs that count }
Party.BUFFS = {
    { cast = { 21562, 21564, 25392, 48162, 1243, 1244, 1245, 2791, 10937, 10938, 25389, 48161 }, has = { 1243, 21562 } },   -- Fortitude
    { cast = { 27681, 32999, 48074, 14752, 14818, 14819, 27841, 25312, 48073 }, has = { 14752, 27681 } },                  -- Spirit
    { cast = { 21849, 21850, 26991, 48470, 1126, 5232, 6756, 5234, 8907, 9884, 9885, 26990, 48469 }, has = { 1126, 21849 } }, -- Mark of the Wild
    { cast = { 23028, 27127, 43002, 1459, 1460, 1461, 10156, 10157, 27126, 42995 }, has = { 1459, 23028 }, mana = true },   -- Arcane Intellect
    { cast = { 467, 782, 1075, 8914, 9756, 9910, 26992, 53307 }, has = { 467 }, role = "TANK" },                          -- Thorns
}
-- paladin blessings: { cast (greater first), has }, by role
Party.BLESSING = {
    Kings = { cast = { 25898, 20217 }, has = { 20217, 25898 } },
    Sanctuary = { cast = { 25899, 20911, 20912, 20913, 20914, 27168 }, has = { 20911, 25899 } },
    Might = { cast = { 25782, 25916, 27141, 48933, 48934, 19740, 19834, 19835, 19836, 19837, 19838, 25291, 27140, 48931, 48932 }, has = { 19740, 25782 } },
    Wisdom = { cast = { 25894, 25918, 27143, 48937, 48938, 19742, 19850, 19852, 19853, 19854, 25290, 27142, 48935, 48936 }, has = { 19742, 25894 } },
}
Party.BLESSINGS = {
    TANK = { "Kings", "Sanctuary", "Might" },
    HEALER = { "Wisdom", "Kings" },
    MANA = { "Wisdom", "Kings" },          -- damage dealers with mana
    DAMAGER = { "Might", "Kings" },
}

local function spellName(id)
    local n
    if C_Spell and C_Spell.GetSpellName then n = plain(C_Spell.GetSpellName, id) end
    if not n and GetSpellInfo then n = plain(GetSpellInfo, id) end
    return n
end

local function spellIcon(spell)
    local tex
    if C_Spell and C_Spell.GetSpellTexture then tex = plain(C_Spell.GetSpellTexture, spell) end
    if not tex and GetSpellTexture then tex = plain(GetSpellTexture, spell) end
    return tex
end

local function knows(id)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local k = plain(C_SpellBook.IsSpellKnown, id)
        if k then return true end
    end
    return IsSpellKnown and plain(IsSpellKnown, id) or false
end

-- The first rank of `ids` you know (nil: none). Cached until you learn a spell.
Party.knownCache = {}
local function firstKnown(ids)
    local key = ids[1]
    local hit = Party.knownCache[key]
    if hit == nil then
        hit = false
        for _, id in ipairs(ids) do if knows(id) then hit = id; break end end
        Party.knownCache[key] = hit
    end
    return hit or nil
end

-- Whether `u` has any of the buffs `ids` (by name, in your language); nil when the game won't say.
local function hasAny(u, ids)
    for _, id in ipairs(ids) do
        local name = spellName(id)
        if name then
            local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, u, name, "HELPFUL")
            if not ok or isSecret(aura) then return nil end
            if aura then return true end
        end
    end
    return false
end

-- Up to `max` icons of buffs `u` lacks that you can cast ({} when none; nil when unknown).
function Party.missing(u, max)
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName) then return nil end
    local role = plain(UnitGroupRolesAssigned, u)
    local mana = plain(UnitPowerType, u) == 0
    local out = {}
    local unknown = false
    local function check(entry)
        local id = firstKnown(entry.cast)
        if not id then return end
        local has = hasAny(u, entry.has)
        if has == nil then unknown = true elseif not has then out[#out + 1] = spellIcon(id) end
    end
    for _, b in ipairs(Party.BUFFS) do
        if (not b.role or b.role == role) and (not b.mana or mana) then check(b) end
    end
    local list = Party.BLESSINGS[(role == "TANK" or role == "HEALER") and role or (mana and "MANA" or "DAMAGER")]
    for _, kind in ipairs(list) do
        local b = Party.BLESSING[kind]
        if firstKnown(b.cast) then check(b); break end
    end
    if unknown and #out == 0 then return nil end
    while #out > max do table.remove(out) end
    return out
end

-- The icons on a frame: small textures made on first use, in a row from `point` on `rel`.
function Party.paintMissing(f, list, point, rel, x, y, size)
    if not f.missIcons then
        f.missIcons = {}
        for i = 1, 3 do
            local tex = (f.ov or f):CreateTexture(nil, "OVERLAY", nil, 3)
            tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            tex:Hide()
            f.missIcons[i] = tex
        end
    end
    for i, tex in ipairs(f.missIcons) do
        tex:SetSize(size, size)
        tex:ClearAllPoints()
        if i == 1 then tex:SetPoint(point, rel, point, x, y)
        else tex:SetPoint("RIGHT", f.missIcons[i - 1], "LEFT", -1, 0) end
        local icon = list and list[i]
        if icon then tex:SetTexture(icon); tex:Show() else tex:Hide() end
    end
end

-- Each unit's missing icons, worked out when its buffs change (Party.missDirty) and kept for painting.
Party.missFor = {}
Party.missDirty = {}

function Party.markMissing(u)
    if u then Party.missDirty[u] = true
    else for _, x in ipairs(Party.GROUP) do Party.missDirty[x] = true end end
end

-- Paints every party frame's missing buffs from what was last worked out (or the samples').
function Party.updateMissing()
    -- (the party frames off: nothing to work out or paint)
    local on = getSetting("party", "missingBuffs") and frameOn("party")
    if not InCombatLockdown() then
        for u in pairs(Party.missDirty) do
            Party.missDirty[u] = nil
            local list = on and Party.missing(u, 2) or nil
            if list ~= nil or not on then Party.missFor[u] = list end
        end
    end
    for i = 1, Party.SLOTS do
        local f = Party.members[i]
        if f and f:IsVisible() then
            local list
            if on then
                if f.partySample then list = f.partySample.missing and { spellIcon(f.partySample.missing) }
                elseif not AuraKit.editing then list = Party.missFor[f.wfUnit] end
            end
            Party.paintMissing(f, list, "BOTTOMRIGHT", f.hp, -1, 13, 13)
        end
    end
    local RP = ns.RaidParty
    if RP and RP.box and RP.box:IsVisible() then
        for _, t in ipairs(RP.tiles) do
            if t:IsVisible() and t.wfUnit then
                local list
                if on then
                    if t.sample then list = t.sample.missing and { spellIcon(t.sample.missing) } else list = Party.missFor[t.wfUnit] end
                end
                Party.paintMissing(t, list, "TOPRIGHT", t.hp, -15, -2, 12)
            end
        end
    end
end

-- The events that make it look again: buffs changing on you or a member, the group, a spell learned.
-- Only while missing buffs is on and the party frames are on. Off, nothing is registered and the
-- ticker is not running. The frames are made the first time they're needed.
function Party.syncMissing()
    local on = getSetting("party", "missingBuffs") and frameOn("party")
    if not on then
        if Party.missTicker then Party.missTicker:Cancel(); Party.missTicker = nil end
        if Party.missEv then
            for _, ev in ipairs(Party.missEv) do ev:UnregisterAllEvents() end
        end
        if Party.missOn then
            Party.missOn = nil
            wipe(Party.missDirty)
            pcall(Party.updateMissing)     -- (icons that were up come off)
        end
        return
    end
    if not Party.missEv then
        local function onAura(_, _, u) Party.markMissing(u) end
        local ev, ev2, ev3 = CreateFrame("Frame"), CreateFrame("Frame"), CreateFrame("Frame")
        ev:SetScript("OnEvent", onAura)
        ev2:SetScript("OnEvent", onAura)
        ev3:SetScript("OnEvent", onAura)
        local g = CreateFrame("Frame")
        g:SetScript("OnEvent", function(_, event)
            if event == "SPELLS_CHANGED" then wipe(Party.knownCache) end
            Party.markMissing()
        end)
        Party.missEv = { ev, ev2, ev3, g }
    end
    if not Party.missOn then
        local ev, ev2, ev3, g = Party.missEv[1], Party.missEv[2], Party.missEv[3], Party.missEv[4]
        pcall(ev.RegisterUnitEvent, ev, "UNIT_AURA", "player", "party1")
        pcall(ev2.RegisterUnitEvent, ev2, "UNIT_AURA", "party2", "party3")
        pcall(ev3.RegisterUnitEvent, ev3, "UNIT_AURA", "party4")
        for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED" }) do
            pcall(g.RegisterEvent, g, e)
        end
        Party.missOn = true
        Party.markMissing()
    end
    if not Party.missTicker then
        Party.missTicker = C_Timer.NewTicker(0.5, function()
            if next(Party.missDirty) then pcall(Party.updateMissing) end
        end)
    end
end

-- Healer mana: a small block of text, one line per healer in the group (role Healer, or with no roles
-- set a priest, druid, paladin or shaman), class-coloured name and mana. Placed in Edit Mode.
Party.HEALER_CLASS = { PRIEST = true, DRUID = true, PALADIN = true, SHAMAN = true }
Party.MANA_POS = { point = "TOPLEFT", x = 20, y = -470 }
Party.MANA_SAMPLES = { { name = "Lyssandra", class = "PRIEST", pct = 72 }, { name = "Bramblewood", class = "DRUID", pct = 38 } }

function Party.makeManaBox()
    local m = CreateFrame("Frame", "WebbyFrames_HealerMana", UIParent)
    m:SetSize(120, 14)
    m:SetFrameStrata("LOW")
    m:SetClampedToScreen(true)
    m.lines = {}
    for i = 1, 5 do
        local fs = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", m, "TOPLEFT", 0, -(i - 1) * 13)
        fs:SetJustifyH("LEFT")
        fs:Hide()
        m.lines[i] = fs
    end
    m:Hide()
    Party.manaBox = m
    local lib = LibStub and LibStub("LibEditMode", true)
    if lib then
        lib:AddFrame(m, function(_, layoutName, point, x, y)
            local active = layoutName == lib:GetActiveLayoutName()
            if active and ns.snapFrame then
                local sp, sx, sy = ns.snapFrame(m)       -- (lines up with the other frames, as they do)
                if sp then point, x, y = sp, sx, sy end
            end
            local u = unitData("party", true, layoutName)
            u.hmPoint, u.hmX, u.hmY = point, x, y
            if active then Party.placeManaBox() end
        end, Party.MANA_POS, "Webby Healer Mana")
        lib:RegisterCallback("layout", function() C_Timer.After(0, Party.placeManaBox) end)
    end
    -- (for Edit Mode's toolbar, snapping and EllesmereUI's Unlock Mode; its sample lines while either is open)
    ns.addMover({
        frame = m, label = "Healer Mana", page = "party",
        store = function(point, x, y) local u = unitData("party", true); u.hmPoint, u.hmX, u.hmY = point, x, y end,
        place = Party.placeManaBox,
        reset = function() local u = unitData("party", true); u.hmPoint, u.hmX, u.hmY = nil, nil, nil; Party.placeManaBox() end,
        enter = function() Party.manaEditing = true; Party.updateMana() end,
        exit = function() Party.manaEditing = nil; Party.updateMana() end,
    })
    Party.placeManaBox()
end

function Party.placeManaBox()
    local m = Party.manaBox
    if not m then return end
    local u, d = unitData("party"), Party.MANA_POS
    m:ClearAllPoints()
    if u and u.hmPoint then m:SetPoint(u.hmPoint, UIParent, u.hmPoint, u.hmX or 0, u.hmY or 0)
    else m:SetPoint(d.point, UIParent, d.point, d.x, d.y) end
end

-- The healers' lines (twice a second while shown).
function Party.updateMana()
    local m = Party.manaBox
    if not m then return end
    local on = getSetting("party", "healerMana") and frameOn("party")
    local sample = Party.manaEditing or Party.testing or (ns.RaidParty and ns.RaidParty.testing)
    if not on or (not sample and not IsInGroup()) or IsInRaid() then m:Hide(); return end
    local units
    if sample then
        units = Party.MANA_SAMPLES
    else
        -- (twice a second: plain() reads, no throwaway functions)
        units = {}
        local roles = false
        for _, u in ipairs(Party.GROUP) do
            if UnitExists(u) and (plain(UnitGroupRolesAssigned, u) or "NONE") ~= "NONE" then roles = true; break end
        end
        for _, u in ipairs(Party.GROUP) do
            local healer = false
            if UnitExists(u) then
                if roles then healer = plain(UnitGroupRolesAssigned, u) == "HEALER"
                else
                    local ok, _, cls = pcall(UnitClass, u)
                    healer = ok and not isSecret(cls) and Party.HEALER_CLASS[cls or ""] and plain(UnitPowerType, u) == 0 or false
                end
            end
            if healer then units[#units + 1] = { unit = u } end
        end
    end
    local scale = CurveConstants and CurveConstants.ScaleTo100
    for i, fs in ipairs(m.lines) do
        local e = units[i]
        if e then
            local class = e.class
            if e.unit then pcall(function() class = select(2, UnitClass(e.unit)) end) end
            local c = (RAID_CLASS_COLORS or {})[class or ""]
            local hex = c and string.format("ff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255) or "ffffffff"
            local ok = pcall(function()
                if e.unit then
                    fs:SetFormattedText("|c" .. hex .. "%s|r  %d%%", UnitName(e.unit), UnitPowerPercent(e.unit, 0, false, scale))
                else
                    fs:SetFormattedText("|c" .. hex .. "%s|r  %d%%", e.name, e.pct)
                end
            end)
            fs:SetShown(ok)
        else
            fs:Hide()
        end
    end
    m:SetHeight(math.max(14, #units * 13))
    m:SetShown(#units > 0)
end

-- Twice a second, and only while the list is turned on (it is off by default).
function Party.watchMana()
    local on = getSetting("party", "healerMana") and frameOn("party")
    if on then
        if not Party.manaTicker then
            Party.manaTicker = C_Timer.NewTicker(0.5, function() pcall(Party.updateMana) end)
        end
        pcall(Party.updateMana)
    else
        if Party.manaTicker then Party.manaTicker:Cancel(); Party.manaTicker = nil end
        if Party.manaBox then Party.manaBox:Hide() end
    end
end

-- Party frames on or off, both styles. Called when a party option changes and after the frames are
-- applied (login, combat ending, a layout change). Off: no listeners, no tickers, no role sort.
function Party.sync()
    if not Party.ev then return end
    -- A sample stop that waited out combat has to put the real units back before anything else.
    if not Party.portraitsOn() and Party.testing then pcall(Party.stopSamples) end
    if Party.sampleStop and not InCombatLockdown() then pcall(Party.finishSampleStop) end
    if Party.portraitsOn() then
        pcall(Party.arrange)
        pcall(Party.updateAllIcons)
        if Party.testing then pcall(Party.paintSamples) end
    elseif not InCombatLockdown() then
        Party.pendingArrange = nil
        Party.pendingReflow = nil
        Party.hidePets()
    end
    Party.syncEvents()
    Party.syncTicker()
    Party.syncMissing()
    Party.watchMana()
    if ns.RaidParty and ns.RaidParty.sync then pcall(ns.RaidParty.sync) end
end

---------------------------------------------------------------------------
-- Raid style (Party page, Style: Raid style)
---------------------------------------------------------------------------
-- The party as flat, crisp tiles instead of the portrait frames, the way Blizzard's "Use Raid-Style
-- Party Frames" and EllesmereUI's party frames show it: health in a choice of colours with incoming
-- heals and shields, power bars by role, the name, role / leader / raid marker, the ready check,
-- summons and resurrections in the middle, a white edge on whoever you're targeting (and under the
-- mouse), the threat colour on whoever has aggro, a debuff you can dispel (or any dispellable one) as a
-- pulsing tint with its type icon, big defensive cooldowns in the middle, missing buffs, their debuffs
-- and your heals over time, and fading out of range. You can be one of the tiles
-- (Include yourself); pets get small tiles beside their owners. The same click casting as the portrait
-- frames (ns.RaidParty.tiles, petTiles). Placed in Edit Mode on its own, with a sample party.
-- (The layout and the combat-safe dispel highlight follow Blizzard's CompactUnitFrame and EllesmereUI's
-- raid frames, the latter used with its author's permission.)
local RP = { tiles = {}, petTiles = {}, MAX = 5 }
ns.RaidParty = RP

RP.FILL = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill"
RP.POWER_FILL = "Interface\\RaidFrame\\Raid-Bar-Resource-Fill"
RP.WHITE = "Interface\\Buttons\\WHITE8X8"
RP.STRIPES = "Interface\\RaidFrame\\Shield-Overlay"
RP.POWER_H = 4
RP.ROLE_ATLAS, RP.ROLE_RANK = ROLE_ATLAS, ROLE_RANK      -- (the portrait frames' own)
RP.DEFAULT_POS = { point = "TOPLEFT", x = 20, y = -250 }
RP.UNIT_EVENTS = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
    "UNIT_NAME_UPDATE", "UNIT_CONNECTION", "UNIT_FLAGS", "UNIT_HEAL_PREDICTION", "UNIT_ABSORB_AMOUNT_CHANGED",
    "UNIT_THREAT_SITUATION_UPDATE", "UNIT_PHASE" }
-- the dispel types: the game's token and its icon
RP.DISPEL_TYPES = {
    { "Magic", "RaidFrame-Icon-DebuffMagic" }, { "Curse", "RaidFrame-Icon-DebuffCurse" },
    { "Disease", "RaidFrame-Icon-DebuffDisease" }, { "Poison", "RaidFrame-Icon-DebuffPoison" },
}
-- Big defensive cooldowns (every rank): shown big in the middle of the tile while they're up.
RP.DEFENSIVES = {}
for _, id in ipairs({
    871, 12975, 12976, 20230, 23920, 55694,                          -- warrior: Shield Wall, Last Stand, Retaliation, Spell Reflection, Enraged Regeneration
    642, 1020, 498, 5573, 1022, 5599, 10278, 6940, 20729, 19752, 1044, -- paladin: Divine Shield, Divine Protection, Blessing of Protection / Sacrifice / Freedom, Divine Intervention
    33206, 47788, 47585, 10060,                                        -- priest: Pain Suppression, Guardian Spirit, Dispersion, Power Infusion
    22812, 61336, 22842, 22895, 22896, 29166,                          -- druid: Barkskin, Survival Instincts, Frenzied Regeneration, Innervate
    5277, 26669, 31224,                                                -- rogue: Evasion, Cloak of Shadows
    11958, 45438,                                                      -- mage: Ice Block
    19263,                                                             -- hunter: Deterrence
    30823,                                                             -- shaman: Shamanistic Rage
    48792, 48707, 55233,                                               -- death knight: Icebound Fortitude, Anti-Magic Shell, Vampiric Blood
}) do RP.DEFENSIVES[id] = true end

local function get(key) return getSetting("party", key) end

-- On: the party frames are on and their style is the raid style.
function RP.enabled()
    return frameOn("party") and get("partyStyle") == "raid"
end

-- Four thin textures round the inside of `parent` (or of `rel`): an edge `th` px wide, coloured as one.
local function edge(parent, layer, sub, th, rel)
    local e = {}
    rel = rel or parent
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = parent:CreateTexture(nil, layer, nil, sub)
        t:SetTexture(RP.WHITE)
        t.side = side
        pcall(t.SetSnapToPixelGrid, t, false)        -- (we snap it ourselves: e.px)
        pcall(t.SetTexelSnappingBias, t, 0)
        if side == "TOP" then t:SetPoint("TOPLEFT", rel); t:SetPoint("TOPRIGHT", rel); t:SetHeight(th)
        elseif side == "BOTTOM" then t:SetPoint("BOTTOMLEFT", rel); t:SetPoint("BOTTOMRIGHT", rel); t:SetHeight(th)
        elseif side == "LEFT" then t:SetPoint("TOPLEFT", rel); t:SetPoint("BOTTOMLEFT", rel); t:SetWidth(th)
        else t:SetPoint("TOPRIGHT", rel); t:SetPoint("BOTTOMRIGHT", rel); t:SetWidth(th) end
        t:Hide()
        e[#e + 1] = t
    end
    e.color = function(r, g, b, a) for _, t in ipairs(e) do t:SetVertexColor(r, g, b, a or 1) end end
    e.shown = function(on) for _, t in ipairs(e) do t:SetShown(on and true or false) end end
    e.alpha = function(a) for _, t in ipairs(e) do t:SetAlpha(a) end end
    -- `th` whole screen pixels wide, whatever the scale (px: one screen pixel in the frame's units)
    e.px = function(px)
        for _, t in ipairs(e) do
            if t.side == "TOP" or t.side == "BOTTOM" then t:SetHeight(th * px) else t:SetWidth(th * px) end
        end
    end
    return e
end

-- One screen pixel, in `region`'s own units (so 1px lines stay crisp at any UI or frame scale), and
-- `v` rounded to whole screen pixels. (EllesmereUI snaps everything this way.)
function RP.onePixel(region)
    local _, ph = GetPhysicalScreenSize()
    local es = region:GetEffectiveScale()
    if not (ph and ph > 0 and es and es > 0) then return 1 end
    return 768 / ph / es
end
function RP.snap(v, px)
    return math.floor(v / px + 0.5) * px
end

-- The name, cut to `n` letters (0: whole). Letters, not bytes, so accents survive.
function RP.shortName(name, n)
    if not n or n <= 0 then return name end
    local ok, out = pcall(function()
        local parts, count = {}, 0
        for ch in name:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
            count = count + 1
            if count > n then break end
            parts[#parts + 1] = ch
        end
        return table.concat(parts)
    end)
    return ok and out or name
end

---------------------------------------------------------------------------
-- Tiles
---------------------------------------------------------------------------
local function tooltip(self)
    if not Party.tipAllowed() then return end
    pcall(function()
        defaultTip(self)
        if GameTooltip:SetUnit(self.wfUnit) ~= false then GameTooltip:Show() end
    end)
    if ns.Click then pcall(ns.Click.addTooltip, self) end      -- (your click casting, under it)
end

function RP.makeTile(i)
    local t = CreateFrame("Button", "WebbyFrames_RaidParty" .. i, RP.box, "SecureUnitButtonTemplate")
    t:RegisterForClicks("AnyUp")
    t:SetAttribute("type1", "target")
    t:SetAttribute("type2", "togglemenu")
    t.index, t.baseUnit = i, "party"      -- (its options are the party's)
    -- black backing: the 1px edge round it all, and the line between health and power
    t.back = t:CreateTexture(nil, "BACKGROUND", nil, 0)
    t.back:SetAllPoints()
    t.back:SetColorTexture(0, 0, 0, 1)
    -- white over that edge while you're targeting them, softer while the mouse is over them
    t.sel = edge(t, "BACKGROUND", 2, 1)
    t.sel.color(1, 1, 1, 1)
    t.hov = edge(t, "BACKGROUND", 1, 1)
    t.hov.color(0.8, 0.8, 0.8, 0.9)
    -- health, its missing part darker
    t.hp = CreateFrame("StatusBar", nil, t)
    t.hp:SetPoint("TOPLEFT", 1, -1)
    t.hp:SetMinMaxValues(0, 1)
    t.hp:SetValue(1)
    t.hp:SetStatusBarTexture(RP.FILL)
    pcall(t.hp.SetClipsChildren, t.hp, true)    -- (heals and shields stop at the bar's end)
    t.hpBg = t.hp:CreateTexture(nil, "BACKGROUND")
    t.hpBg:SetAllPoints()
    t.hpBg:SetColorTexture(1, 1, 1, 1)
    -- incoming heals, then shields
    t.heal = CreateFrame("StatusBar", nil, t.hp)
    t.heal:SetStatusBarTexture(RP.WHITE)
    t.heal:SetStatusBarColor(0.25, 0.95, 0.45, 0.45)
    t.absorb = CreateFrame("StatusBar", nil, t.hp)
    -- the overshield: Blizzard's glow at the bar's end while shields are more than the missing health
    t.overGlow = t.hp:CreateTexture(nil, "OVERLAY", nil, 7)
    t.overGlow:SetTexture("Interface\\RaidFrame\\Shield-Overshield")
    t.overGlow:SetBlendMode("ADD")
    t.overGlow:SetWidth(8)
    t.overGlow:SetPoint("TOPRIGHT", t.hp, "TOPRIGHT", 2, 0)
    t.overGlow:SetPoint("BOTTOMRIGHT", t.hp, "BOTTOMRIGHT", 2, 0)
    t.overGlow:SetAlpha(0)
    -- power
    t.mp = CreateFrame("StatusBar", nil, t)
    t.mp:SetPoint("BOTTOMLEFT", 1, 1)
    t.mp:SetPoint("BOTTOMRIGHT", -1, 1)
    t.mp:SetHeight(RP.POWER_H)
    t.mp:SetStatusBarTexture(RP.POWER_FILL)
    t.mp:SetMinMaxValues(0, 1)
    -- text, icons and highlights, over the bars
    local ov = CreateFrame("Frame", nil, t)
    ov:SetAllPoints()
    ov:SetFrameLevel(t:GetFrameLevel() + 6)
    t.ov = ov
    -- (a sample member's dispel tint; real ones come from the game, see RP.buildDispel)
    t.wash = ov:CreateTexture(nil, "BACKGROUND")
    t.wash:SetAllPoints(t.hp)
    t.wash:SetTexture(RP.WHITE)
    t.wash:Hide()
    -- aggro (or a sample member's dispel): a 2px coloured edge inside the tile
    t.glow = edge(ov, "BORDER", 0, 2)
    t.name = ov:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t.name:SetWordWrap(false)
    t.status = ov:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    t.hpText = ov:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t.mpText = ov:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t.mpText:SetTextColor(0.75, 0.85, 1)
    t.role = ov:CreateTexture(nil, "OVERLAY")
    t.role:SetSize(12, 12)
    t.role:SetPoint("TOPLEFT", t.hp, "TOPLEFT", 2, -2)
    t.leader = ov:CreateTexture(nil, "OVERLAY", nil, 1)
    t.leader:SetSize(12, 12)
    t.leader:SetPoint("TOPLEFT", t, "TOPLEFT", -3, 6)
    t.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
    t.marker = ov:CreateTexture(nil, "OVERLAY")
    t.marker:SetSize(12, 12)
    t.marker:SetPoint("TOPRIGHT", t.hp, "TOPRIGHT", -2, -2)
    t.marker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    t.center = ov:CreateTexture(nil, "OVERLAY", nil, 2)
    t.center:SetSize(20, 20)
    t.center:SetPoint("CENTER", t.hp, "CENTER")
    -- (a sample member's defensive and dispel icons)
    t.sampleDef = ov:CreateTexture(nil, "OVERLAY", nil, 1)
    t.sampleDef:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    t.sampleDispel = ov:CreateTexture(nil, "OVERLAY", nil, 1)
    t.sampleDispel:SetSize(14, 14)
    for _, r in ipairs({ t.role, t.leader, t.marker, t.center, t.sampleDef, t.sampleDispel }) do r:Hide() end
    RP.makeAuras(t)
    t:SetScript("OnEnter", function(self)
        if get("rpHoverEdge") then self.hov.shown(true) end
        self.hovered = true
        if self.sample then RP.paintSample(self, self.sample) elseif self.wfUnit then RP.paintNumbers(self) end
        tooltip(self)
    end)
    t:SetScript("OnLeave", function(self)
        self.hov.shown(false)
        self.hovered = nil
        if self.sample then RP.paintSample(self, self.sample) elseif self.wfUnit then RP.paintNumbers(self) end
        GameTooltip:Hide()
    end)
    t:SetScript("OnEvent", RP.onEvent)
    t:Hide()
    RP.tiles[i] = t
    return t
end

-- A pet's small tile, beside its owner's: health, name, the same edges and clicks.
function RP.makePetTile(i)
    local p = CreateFrame("Button", "WebbyFrames_RaidPartyPet" .. i, RP.box, "SecureUnitButtonTemplate")
    p:RegisterForClicks("AnyUp")
    p:SetAttribute("type1", "target")
    p:SetAttribute("type2", "togglemenu")
    p.isPet, p.baseUnit = true, "party"
    p.back = p:CreateTexture(nil, "BACKGROUND", nil, 0)
    p.back:SetAllPoints()
    p.back:SetColorTexture(0, 0, 0, 1)
    p.sel = edge(p, "BACKGROUND", 2, 1)
    p.sel.color(1, 1, 1, 1)
    p.hov = edge(p, "BACKGROUND", 1, 1)
    p.hov.color(0.8, 0.8, 0.8, 0.9)
    p.hp = CreateFrame("StatusBar", nil, p)
    p.hp:SetPoint("TOPLEFT", 1, -1)
    p.hp:SetPoint("BOTTOMRIGHT", -1, 1)
    p.hp:SetStatusBarTexture(RP.FILL)
    p.hp:SetStatusBarColor(0.2, 0.75, 0.3)
    p.hp:SetMinMaxValues(0, 1)
    p.hpBg = p.hp:CreateTexture(nil, "BACKGROUND")
    p.hpBg:SetAllPoints()
    p.hpBg:SetColorTexture(0.05, 0.19, 0.08, 1)
    local ov = CreateFrame("Frame", nil, p)
    ov:SetAllPoints()
    ov:SetFrameLevel(p:GetFrameLevel() + 4)
    p.name = ov:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p.name:SetPoint("LEFT", p.hp, "LEFT", 3, 0)
    p.name:SetPoint("RIGHT", p.hp, "RIGHT", -2, 0)
    p.name:SetJustifyH("LEFT")
    p.name:SetWordWrap(false)
    p:SetScript("OnEnter", function(self)
        if get("rpHoverEdge") then self.hov.shown(true) end
        tooltip(self)
    end)
    p:SetScript("OnLeave", function(self) self.hov.shown(false); GameTooltip:Hide() end)
    p:SetScript("OnEvent", function(self, event)
        if self.sample or not self.wfUnit then return end
        if event == "PLAYER_TARGET_CHANGED" then RP.paintSelected(self) else RP.paintPet(self) end
    end)
    p:Hide()
    RP.petTiles[i] = p
    return p
end

function RP.paintPet(p)
    if p.sample then return end
    local u = p.wfUnit
    pcall(function()
        p.hp:SetMinMaxValues(0, UnitHealthMax(u))
        p.hp:SetValue(UnitHealth(u))
        p.name:SetText(UnitName(u))
    end)
    RP.paintSelected(p)
end

-- Their debuffs (bottom left, Blizzard's order: the ones that matter first), the buffs you put on them
-- (your heals over time, bottom right), and big defensives (middle): a few small icons each, styled like
-- the other frames'. (Icon size changes apply to new icons; /reload for all of them.)
function RP.makeAuras(t)
    local proxy = { baseUnit = "party" }
    local function make(filter, max, sizeKey, cand)
        local ok, c = pcall(CreateFrame, "AuraContainer", nil, t.ov, "CustomAuraContainerTemplate")
        if not (ok and c) then return nil end
        local function init(b)
            pcall(AuraKit.styleButton, proxy, b)
            local s = get(sizeKey) or 14
            pcall(b.SetSize, b, s, s)
        end
        if not pcall(c.AddAuraGroup, c, "a", filter, { initializeFrame = init, maxFrameCount = max }) then
            c:Hide()
            return nil
        end
        if cand then pcall(c.SetAuraGroupCandidateFilters, c, "a", cand) end
        local order = filter == "HARMFUL" and AuraKit.sortBy("UnitFrameDebuff")
        if order then pcall(c.SetAuraGroupSortMethod, c, "a", order) end
        pcall(c.SetAuraGroupLayout, c, "a", { elementSpacing = 1, lineSpacing = 1, groupSpacing = 1, groupLineSpacing = 1 })
        return c
    end
    t.debuffs = make("HARMFUL", 3, "rpAuraSize")
    t.buffs = make("HELPFUL|PLAYER", 3, "rpAuraSize")
    t.defs = make("HELPFUL", 2, "rpDefSize", { includeSpellIDs = RP.DEFENSIVES })
end

-- The aura rows' spot and flow (after a size change).
function RP.placeAuras(t)
    local s = get("rpAuraSize") or 14
    local ds = get("rpDefSize") or 20
    local function place(c, point, x, y, size, n, dir)
        if not c then return end
        pcall(function()
            local A = AnchorUtil
            c:SetFlowLayoutAxis(A.FlowLayoutAxis.Horizontal)
            c:SetFlowLayoutAnchorPoint(point)
            c:SetFlowLayoutGrowthDirection(dir == "left" and (A.FlowDirection.Left or -1) or A.FlowDirection.Right, A.FlowDirection.Up)
            c:SetFlowLayoutMaximumLineSize(n * (size + 1))
        end)
        c:ClearAllPoints()
        c:SetPoint(point, t.hp, point, x, y)
        pcall(c.SetSize, c, n * (size + 1), size)
    end
    place(t.debuffs, "BOTTOMLEFT", 2, 2, s, 3, "right")
    place(t.buffs, "BOTTOMRIGHT", -2, 2, s, 3, "left")
    -- (each on or off: Party page, Buffs and debuffs)
    if t.debuffs then t.debuffs:SetShown(get("rpDebuffs") ~= false) end
    if t.buffs then t.buffs:SetShown(get("rpBuffs") ~= false) end
    if t.defs then
        place(t.defs, "LEFT", 0, 0, ds, 2, "right")
        t.defs:ClearAllPoints()
        t.defs:SetPoint("CENTER", t.hp, "CENTER", 0, 0)
        t.defs:SetShown(get("rpDefensives") and true or false)
    end
    t.sampleDef:SetSize(ds, ds)
    t.sampleDef:SetPoint("CENTER", t.hp, "CENTER")
end

-- The dispel highlight, drawn by the game (so it works in combat, when the debuffs themselves are hidden
-- from addons): a container whose groups are "a debuff you can dispel" (or any dispellable one), one
-- per type; each group's button carries the tint (a gradient up from the bottom, a flat fill, or just
-- the edge), the 2px edge and the type's icon, all placed on the tile, in that type's colour. The tile
-- pulses it (an animation on the container). Rebuilt when its look changes (a container's groups can't be changed).
function RP.dispelFilter()
    return get("dispelWho") == "all" and "HARMFUL" or "HARMFUL|RAID"
end

function RP.buildDispel(t)
    local style, icon, on = get("rpDispelStyle") or "gradient", get("rpDispelIcon") and true or false, get("dispelGlow") and true or false
    local sig = tostring(on) .. style .. tostring(icon)
    if t.dispelSig == sig then
        -- only who it's for may have changed: the filters change live
        if t.dispelBox then
            for _, d in ipairs(RP.DISPEL_TYPES) do pcall(t.dispelBox.SetAuraGroupFilterString, t.dispelBox, d[1], RP.dispelFilter()) end
            AuraKit.attachPulse(t.dispelBox)
        end
        return
    end
    t.dispelSig = sig
    if t.dispelBox then
        local old = t.dispelBox
        AuraKit.stopPulse(old)
        old:Hide()
        pcall(old.SetEnabled, old, false)
        t.dispelBox = nil
    end
    if not on then return end
    local ok, c = pcall(CreateFrame, "AuraContainer", nil, t, "CustomAuraContainerTemplate")
    if not (ok and c) then return end
    c:SetPoint("TOPLEFT", t, "TOPLEFT")
    c:SetSize(1, 1)
    c:SetFrameLevel(t:GetFrameLevel() + 3)      -- (over the bars, under the text and icons)
    for _, d in ipairs(RP.DISPEL_TYPES) do
        local r, g, b = AuraKit.dispelRGB(d[1])
        local function init(btn)
            pcall(function()
                btn:EnableMouse(false)
                btn:SetSize(1, 1)
                if style ~= "edge" then
                    local w = btn:CreateTexture(nil, "BACKGROUND")
                    w:SetPoint("TOPLEFT", t.hp, "TOPLEFT")
                    w:SetPoint("BOTTOMRIGHT", t.hp, "BOTTOMRIGHT")
                    w:SetTexture(RP.WHITE)
                    if style == "fill" then w:SetVertexColor(r, g, b, 0.35)
                    else w:SetGradient("VERTICAL", CreateColor(r, g, b, 0.6), CreateColor(r, g, b, 0)) end
                end
                local e = edge(btn, "BORDER", 0, 2, t)
                e.px(RP.px or 1)
                e.color(r, g, b, 1)
                e.shown(true)
                if icon then
                    local ic = btn:CreateTexture(nil, "OVERLAY")
                    ic:SetSize(14, 14)
                    ic:SetPoint("RIGHT", t.hp, "RIGHT", -2, 0)
                    if not pcall(ic.SetAtlas, ic, d[2]) then ic:SetTexture("Interface\\RaidFrame\\Raid-Icon-Debuff" .. d[1]) end
                end
            end)
        end
        pcall(c.AddAuraGroup, c, d[1], RP.dispelFilter(), { initializeFrame = init, maxFrameCount = 1 })
        pcall(c.SetAuraGroupCandidateFilters, c, d[1], { includeDispelTypes = { [d[1]] = true } })
    end
    if t.wfUnit then pcall(c.SetUnit, c, t.wfUnit) end
    c:SetShown(not t.sample)
    t.dispelBox = c
    AuraKit.attachPulse(c)
end

---------------------------------------------------------------------------
-- Painting (values may be hidden from addons: they only go to setters; tests are inside pcall)
---------------------------------------------------------------------------
-- A member's class, when they're a player and the game will say.
function RP.classOf(u)
    if not plain(UnitIsPlayer, u) then return nil end
    local ok, _, class = pcall(UnitClass, u)
    if ok and not isSecret(class) then return class end
end

function RP.paintName(t)
    local u = t.wfUnit
    local name = UnitName(u)
    if isSecret(name) then t.name:SetText(name) else t.name:SetText(RP.shortName(name or "", get("rpNameMax") or 0)) end
    local c = get("rpNameColor") == "class" and (RAID_CLASS_COLORS or {})[RP.classOf(u) or ""]
    if c then t.name:SetTextColor(c.r, c.g, c.b) else t.name:SetTextColor(1, 1, 1) end
end

-- Dead, a ghost, offline or away.
function RP.state(u)
    if plain(UnitIsConnected, u) == false then return "Offline" end
    if plain(UnitIsGhost, u) then return "Ghost" end
    if plain(UnitIsDead, u) then return "Dead" end
    if get("rpAFK") and plain(UnitIsAFK, u) then return "AFK" end
end

-- Health from green (full) through yellow to red (empty): the colour the game works out, so it's right
-- even when the health itself is hidden from addons.
function RP.gradient()
    if RP.curve == nil then
        RP.curve = false
        pcall(function()
            local c = C_CurveUtil.CreateColorCurve()
            pcall(function() c:SetType(Enum.LuaCurveType.Linear) end)
            c:AddPoint(0, CreateColor(0.9, 0.12, 0.1, 1))
            c:AddPoint(0.5, CreateColor(0.95, 0.82, 0.1, 1))
            c:AddPoint(1, CreateColor(0.15, 0.85, 0.25, 1))
            RP.curve = c
        end)
    end
    return RP.curve or nil
end

-- The bar's colours: class / dark / custom / by health, the missing part darker (Missing health shade).
-- s: a sample member, else the tile's unit. state: dead / offline etc.
function RP.colorHealth(t, state, class, frac)
    local mode = get("rpHealthColor") or "class"
    local dark = (tonumber(get("rpMissingDark")) or 75) / 100
    if state == "Dead" or state == "Ghost" or state == "Offline" then
        local c = state == "Offline" and get("rpOfflineColor") or get("rpDeadColor")
        c = type(c) == "table" and c or { 0.35, 0.35, 0.35 }
        t.hp:SetStatusBarColor(c[1], c[2], c[3])
        t.hpBg:SetVertexColor(c[1], c[2], c[3])
        return
    end
    local cc = (RAID_CLASS_COLORS or {})[class or ""]
    local r, g, b = 0.2, 0.8, 0.2
    if cc then r, g, b = cc.r, cc.g, cc.b end
    if mode == "dark" then
        t.hp:SetStatusBarColor(0.16, 0.16, 0.18)
        t.hpBg:SetVertexColor(r * 0.85, g * 0.85, b * 0.85)
        return
    elseif mode == "default" then
        r, g, b = 0.1, 0.8, 0.1            -- (Blizzard's raid-frame green)
    elseif mode == "custom" then
        local c = get("rpHealthCustom")
        if type(c) == "table" then r, g, b = c[1], c[2], c[3] end
    elseif mode == "gradient" then
        t.hpBg:SetVertexColor(0.1, 0.1, 0.1)
        if frac then
            -- (a sample: worked out here)
            local f = math.max(0, math.min(1, frac))
            if f > 0.5 then local k = (f - 0.5) * 2; t.hp:SetStatusBarColor(0.95 + (0.15 - 0.95) * k, 0.82 + (0.85 - 0.82) * k, 0.1 + 0.15 * k)
            else local k = f * 2; t.hp:SetStatusBarColor(0.9 + 0.05 * k, 0.12 + 0.7 * k, 0.1) end
            return
        end
        local curve = RP.gradient()
        if curve then
            local ok, col = pcall(UnitHealthPercent, t.wfUnit, true, curve)
            if ok and col and pcall(t.hp.SetStatusBarColor, t.hp, col:GetRGB()) then return end
        end
    end
    t.hp:SetStatusBarColor(r, g, b)
    t.hpBg:SetVertexColor(r * (1 - dark), g * (1 - dark), b * (1 - dark))
end

-- Where the name, state and health text sit (Name position).
function RP.placeText(t)
    local pos = get("rpNamePos") or "topleft"
    t.name:ClearAllPoints()
    t.status:ClearAllPoints()
    t.hpText:ClearAllPoints()
    t.mpText:ClearAllPoints()
    t.mpText:SetPoint("TOP", t.hpText, "BOTTOM", 0, -1)
    if pos == "center" then
        t.name:SetPoint("CENTER", t.hp, "CENTER", 0, 4)
        t.name:SetWidth(t.hp:GetWidth() - 6)
        t.name:SetJustifyH("CENTER")
        t.status:SetPoint("TOP", t.name, "BOTTOM", 0, -1)
        t.hpText:SetPoint("TOP", t.name, "BOTTOM", 0, -1)
    else
        if pos == "top" then
            t.name:SetPoint("TOP", t.hp, "TOP", 0, -3)
            t.name:SetWidth(t.hp:GetWidth() - 30)
            t.name:SetJustifyH("CENTER")
        else
            t.name:SetPoint("TOPLEFT", t.hp, "TOPLEFT", t.role:IsShown() and 15 or 3, -3)
            t.name:SetPoint("TOPRIGHT", t.hp, "TOPRIGHT", -16, -3)
            t.name:SetJustifyH("LEFT")
        end
        t.status:SetPoint("CENTER", t.hp, "CENTER", 0, -3)
        t.hpText:SetPoint("CENTER", t.hp, "CENTER", 0, -3)
    end
end

function RP.paintHealth(t)
    local u = t.wfUnit
    t.hp:SetMinMaxValues(0, UnitHealthMax(u))     -- (setters take hidden values as they are)
    t.hp:SetValue(UnitHealth(u))
    local s = RP.state(u)
    RP.colorHealth(t, s, RP.classOf(u))
    t.status:SetText(s or "")
    t.status:SetShown(s ~= nil)
    t.state = s
    RP.paintNumbers(t)
    RP.paintPrediction(t)
end

-- Health and mana numbers, as the other frames have them (the Party page's Numbers and Style): always,
-- on mouseover (while the mouse is over the tile) or never; totals, percentages or both. Not while the
-- tile says Dead, Offline or AFK; mana only while the tile has a power bar.
function RP.numbersOn(t)
    local mode = get("textMode")
    if mode == "off" then return false end
    return mode ~= "mouseover" or t.hovered and true or false
end

function RP.paintNumbers(t)
    local on = RP.numbersOn(t) and not t.state
    if on then pcall(ns.setBarText, t.hpText, t, "hp") end
    t.hpText:SetShown(on)
    local mp = on and t.powerOn
    if mp then pcall(ns.setBarText, t.mpText, t, "mp") end
    t.mpText:SetShown(mp and true or false)
end

-- Heals coming in, then shields: straight after the health (shields striped or plain), or shields from
-- the right edge over the health, so a full-health member's shield still shows.
function RP.placeShields(t, w)
    local tex = t.hp:GetStatusBarTexture()
    t.heal:ClearAllPoints()
    t.heal:SetPoint("TOPLEFT", tex, "TOPRIGHT")
    t.heal:SetPoint("BOTTOMLEFT", tex, "BOTTOMRIGHT")
    t.heal:SetWidth(w)
    t.absorb:ClearAllPoints()
    if get("rpShieldEdge") then
        t.absorb:SetPoint("TOPRIGHT", t.hp, "TOPRIGHT")
        t.absorb:SetPoint("BOTTOMRIGHT", t.hp, "BOTTOMRIGHT")
        t.absorb:SetReverseFill(true)
    else
        t.absorb:SetPoint("TOPLEFT", t.heal:GetStatusBarTexture(), "TOPRIGHT")
        t.absorb:SetPoint("BOTTOMLEFT", t.heal:GetStatusBarTexture(), "BOTTOMRIGHT")
        t.absorb:SetReverseFill(false)
    end
    t.absorb:SetWidth(w)
    -- the look: Blizzard's stripes, plain, or any texture (Shield look), in Shield colour and opacity
    local style = get("rpShieldStyle") or "striped"
    local striped = style == "striped"
    local tex = striped and RP.STRIPES or (style == "plain" and RP.WHITE) or resolveTexture(style) or RP.WHITE
    t.absorb:SetStatusBarTexture(tex)
    local st = t.absorb:GetStatusBarTexture()
    if st then pcall(st.SetHorizTile, st, striped); pcall(st.SetVertTile, st, striped) end
    local c = get("rpShieldColor")
    if type(c) ~= "table" then c = { 1, 1, 1 } end
    -- (the opacity unset: the old looks, stripes 75%, plain 40%)
    local a = tonumber(get("rpShieldAlpha")) or (striped and 0.75 or 0.4)
    t.absorb:SetStatusBarColor(c[1] or 1, c[2] or 1, c[3] or 1, a)
    -- the glows (Shield glow, Heal glow: the party's, as on the portrait frames)
    if ns.barGlow then
        pcall(ns.barGlow, t.absorb, get("absorbGlow") or "off", c[1] or 1, c[2] or 1, c[3] or 1, tonumber(get("absorbGlowAlpha")) or 0.6)
        local hr, hg, hb = 0.1, 0.9, 0.3
        pcall(function() hr, hg, hb = t.heal:GetStatusBarColor() end)
        pcall(ns.barGlow, t.heal, get("healGlow") or "off", hr, hg, hb, tonumber(get("healGlowAlpha")) or 0.6)
    end
end

function RP.paintPrediction(t)
    local u = t.wfUnit
    local max = UnitHealthMax(u)
    t.heal:SetMinMaxValues(0, max)
    t.absorb:SetMinMaxValues(0, max)
    -- incoming heals: Blizzard's calculator when the client has it (clamped to the missing health),
    -- else the plain total
    local heal
    local calc = RP.calc
    if calc == nil then
        calc = false
        if CreateUnitHealPredictionCalculator and UnitGetDetailedHealPrediction then
            local ok, c = pcall(CreateUnitHealPredictionCalculator)
            if ok and c then
                local E = Enum or {}
                if c.SetIncomingHealClampMode and E.UnitIncomingHealClampMode then
                    pcall(c.SetIncomingHealClampMode, c, E.UnitIncomingHealClampMode.MissingHealth or E.UnitIncomingHealClampMode.MaximumHealth)
                end
                if c.SetDamageAbsorbClampMode and E.UnitDamageAbsorbClampMode then
                    pcall(c.SetDamageAbsorbClampMode, c, E.UnitDamageAbsorbClampMode.MissingHealth)
                end
                calc = c
            end
        end
        RP.calc = calc
    end
    t.overGlow:SetAlpha(0)
    if calc and pcall(UnitGetDetailedHealPrediction, u, "player", calc) then
        local ok, total = pcall(calc.GetIncomingHeals, calc)
        if ok then heal = total end
        -- (overshield: the answer may be hidden, so it goes straight to the glow's alpha)
        local okA, _, over = pcall(calc.GetDamageAbsorbs, calc)
        if okA and (isSecret(over) or over ~= nil) and t.overGlow.SetAlphaFromBoolean then
            pcall(t.overGlow.SetAlphaFromBoolean, t.overGlow, over, 0.9, 0)
        end
    end
    if heal == nil then local ok, v = pcall(UnitGetIncomingHeals, u); heal = ok and v or 0 end
    pcall(t.heal.SetValue, t.heal, heal or 0)
    local ok, absorb = pcall(UnitGetTotalAbsorbs, u)
    pcall(t.absorb.SetValue, t.absorb, ok and absorb or 0)
end

-- Power bars for the roles chosen (Power bars: tanks / healers / damage); the health takes the room
-- of a hidden one.
function RP.powerFor(role)
    if role == "TANK" then return get("rpPowerTank") end
    if role == "HEALER" then return get("rpPowerHealer") end
    return get("rpPowerDPS")
end

function RP.showPower(t, on)
    on = on and true or false
    if t.powerOn == on then return end
    t.powerOn = on
    local px = RP.px or 1
    t.hp:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -px, on and (RP.snap(RP.POWER_H, px) + 2 * px) or px)
    t.mp:SetShown(on)
end

function RP.paintPower(t)
    local u = t.wfUnit
    RP.showPower(t, RP.powerFor(plain(UnitGroupRolesAssigned, u)))
    if not t.powerOn then return end
    t.mp:SetMinMaxValues(0, UnitPowerMax(u))
    t.mp:SetValue(UnitPower(u))
    local _, token = UnitPowerType(u)
    local c = PowerBarColor and not isSecret(token) and token and PowerBarColor[token]
    if c then t.mp:SetStatusBarColor(c.r, c.g, c.b) else t.mp:SetStatusBarColor(0, 0.45, 1) end
    if t.mpText:IsShown() or RP.numbersOn(t) then RP.paintNumbers(t) end
end

-- Role, leader, raid marker, and the middle icon (ready check, summon, resurrection, phase).
function RP.paintIcons(t)
    local u = t.wfUnit
    local role = plain(UnitGroupRolesAssigned, u)
    local atlas = role and RP.ROLE_ATLAS[role]
    if atlas ~= t.roleAtlas then
        t.roleAtlas = atlas
        if atlas and pcall(t.role.SetAtlas, t.role, atlas) then t.role:Show() else t.role:Hide() end
        RP.placeText(t)
    end
    t.leader:SetShown(plain(UnitIsGroupLeader, u) and true or false)
    local mark = plain(GetRaidTargetIndex, u)
    local markOk = mark and pcall(SetRaidTargetIconTexture, t.marker, mark)
    t.marker:SetShown(markOk and true or false)
    local kind, what
    if Party.centerIcon then kind, what = Party.centerIcon(u) end
    if kind == "atlas" and pcall(t.center.SetAtlas, t.center, what) then t.center:Show()
    elseif kind == "file" then t.center:SetTexture(what); t.center:SetTexCoord(0, 1, 0, 1); t.center:Show()
    else t.center:Hide() end
end

-- White edge while you're targeting them.
function RP.paintSelected(t)
    t.sel.shown(plain(UnitIsUnit, t.wfUnit, "target"))
end

-- Aggro: the target frame's threat colours on the edge, when its threat options show a glow.
function RP.paintGlow(t)
    if t.sample then return end
    t.wash:Hide()
    t.glow.alpha(1)
    local status
    local mode = getSetting("target", "threatShow")
    if mode == "both" or mode == "glow" then
        local s = plain(UnitThreatSituation, t.wfUnit)
        if s and s >= 1 then status = s end
    end
    if status then
        local r, g, b = threatColor("target", status, status == 1 and 80 or 100)
        t.glow.color(r, g, b, 1)
        t.glow.shown(true)
    else
        t.glow.shown(false)
    end
end

function RP.paintAll(t)
    if not t.wfUnit then return end
    if t.sample then return RP.paintSample(t, t.sample) end
    RP.paintName(t)
    RP.paintHealth(t)
    RP.paintPower(t)
    RP.paintIcons(t)
    RP.paintSelected(t)
    RP.paintGlow(t)
end

function RP.onEvent(t, event)
    if t.sample or not t.wfUnit then return end      -- (a sample member, or an empty tile: nothing real to show)
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_CONNECTION" or event == "UNIT_FLAGS" then
        RP.paintHealth(t)
    elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
        RP.paintPower(t)
    elseif event == "UNIT_NAME_UPDATE" then
        RP.paintName(t)
    elseif event == "UNIT_HEAL_PREDICTION" or event == "UNIT_ABSORB_AMOUNT_CHANGED" then
        RP.paintPrediction(t)
        -- (a snowglobe glow: shaken)
        if ns.barGlowShake then ns.barGlowShake(event == "UNIT_ABSORB_AMOUNT_CHANGED" and t.absorb or t.heal) end
    elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
        RP.paintGlow(t)
    elseif event == "PLAYER_TARGET_CHANGED" then
        RP.paintSelected(t)
    else
        RP.paintAll(t)
    end
end

---------------------------------------------------------------------------
-- Units, layout, position
---------------------------------------------------------------------------
-- A tile's unit: its secure unit, its events and its auras. Out of combat only.
function RP.setUnit(t, u)
    t.wfUnit, t.roleAtlas = u, nil
    t:SetAttribute("unit", u)
    t:UnregisterAllEvents()
    if t.isPet then
        for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE" }) do pcall(t.RegisterUnitEvent, t, e, u) end
        t:RegisterEvent("PLAYER_TARGET_CHANGED")
        RP.paintPet(t)
        return
    end
    for _, e in ipairs(RP.UNIT_EVENTS) do pcall(t.RegisterUnitEvent, t, e, u) end
    t:RegisterEvent("PLAYER_TARGET_CHANGED")
    for _, c in ipairs({ t.debuffs, t.buffs, t.defs, t.dispelBox }) do
        if c then pcall(function() if c:GetUnit() ~= u then c:SetUnit(u) end end) end
    end
    RP.paintAll(t)
end

-- A pet's unit from its owner's.
function RP.petOf(u)
    if u == "player" then return "pet" end
    return Party.petOf(u)
end

-- No unit, no events, no aura scan. The aura containers keep listening until their unit is cleared.
local function dropContainer(c)
    if not c then return end
    AuraKit.stopPulse(c)
    pcall(c.SetUnit, c, nil)
end

function RP.clearUnit(t)
    if not t then return end
    UnregisterUnitWatch(t)
    t:Hide()
    t.wfUnit = nil
    t:UnregisterAllEvents()
    dropContainer(t.debuffs)
    dropContainer(t.buffs)
    dropContainer(t.defs)
    dropContainer(t.dispelBox)
end

-- Who goes in which tile: you first (Include yourself), then party1 - 4; or by role (tanks, healers,
-- damage). Each tile shows while its unit exists, its pet's beside it (Pets). Out of combat only.
function RP.arrange()
    if InCombatLockdown() then RP.pending = true; return end
    if RP.testing then return end
    -- raid style not in use (portrait frames, or the party frames off): no units, no events, nothing
    -- drawn in the background
    if not RP.enabled() then
        for i = 1, RP.MAX do
            RP.clearUnit(RP.tiles[i])
            RP.clearUnit(RP.petTiles[i])
        end
        if ns.Click and ns.Click.header then pcall(ns.Click.apply) end
        return
    end
    local list = {}
    if get("rpSelf") then list[#list + 1] = "player" end
    for i = 1, 4 do list[#list + 1] = "party" .. i end
    if get("partySort") == "role" then
        local rank = {}
        for i, u in ipairs(list) do
            local r = 9
            pcall(function()
                if UnitExists(u) then r = RP.ROLE_RANK[UnitGroupRolesAssigned(u)] or 4 end
            end)
            rank[u] = r * 10 + i
        end
        table.sort(list, function(a, b) return rank[a] < rank[b] end)
    end
    local on = RP.enabled()
    local pets = on and get("rpPets")
    local members = 0
    for i = 1, RP.MAX do
        local t = RP.tiles[i]
        local u = list[i]
        if u then
            if t.wfUnit ~= u then RP.setUnit(t, u) end
            if on then RegisterUnitWatch(t) else UnregisterUnitWatch(t); t:Hide() end
            if UnitExists(u) then members = members + 1 end
        else
            -- (an empty tile stops listening too: it has no one to draw)
            RP.clearUnit(t)
        end
    end
    -- The pets: their own group, in their owners' order, packed with no gaps: the pets out now take the
    -- first pet tiles, and the rest of the group's pet units the tiles after them (so a pet summoned in
    -- combat, when nothing can move, shows straight after the others).
    local out, later = {}, {}
    for _, u in ipairs(list) do
        local pu = RP.petOf(u)
        if pu then
            if UnitExists(pu) then out[#out + 1] = pu else later[#later + 1] = pu end
        end
    end
    local petCount = #out
    for _, pu in ipairs(later) do out[#out + 1] = pu end
    for i = 1, RP.MAX do
        local p, pu = RP.petTiles[i], out[i]
        if pu then
            if p.wfUnit ~= pu then RP.setUnit(p, pu) end
            if pets then RegisterUnitWatch(p) else UnregisterUnitWatch(p); p:Hide() end
        else
            RP.clearUnit(p)
        end
    end
    RP.placePets(members, pets and petCount or 0)
    -- (click casting again: a resurrect binding names each tile's unit)
    if ns.Click and ns.Click.header then pcall(ns.Click.apply) end
end

-- Size and spot of every tile (stacked or side by side, the party's Layout); the pet group and the box
-- round them all: RP.placePets.
function RP.layout()
    if InCombatLockdown() then RP.pending = true; return end
    RP.box:SetScale(get("scale") or 1)
    local px = RP.onePixel(RP.box)
    RP.px = px
    local w, h, gap = RP.snap(get("rpWidth") or 96, px), RP.snap(get("rpHeight") or 48, px), RP.snap(get("rpGap") or 3, px)
    local across = get("partyLayout") == "horizontal"
    -- (pet tiles: as wide as the members', their own height; placed by RP.placePets)
    local pw, ph = w, RP.snap(math.min(h, tonumber(get("rpPetHeight")) or 24), px)
    RP.dim = { w = w, h = h, gap = gap, pw = pw, ph = ph, across = across }
    local tex = resolveTexture(get("barTexture")) or RP.FILL
    local ptex = resolveTexture(get("powerTexture")) or RP.POWER_FILL     -- (the party's Power bar texture, both styles)
    local font = resolveFont(get("font"))
    local stepX, stepY = across and (w + gap) or 0, across and 0 or (h + gap)
    for i = 1, RP.MAX do
        local t, p = RP.tiles[i], RP.petTiles[i]
        t:SetSize(w, h)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", RP.box, "TOPLEFT", (i - 1) * stepX, -(i - 1) * stepY)
        -- (1px insets and edges, in screen pixels)
        t.hp:SetPoint("TOPLEFT", t, "TOPLEFT", px, -px)
        t.mp:ClearAllPoints()
        t.mp:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", px, px)
        t.mp:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -px, px)
        t.mp:SetHeight(RP.snap(RP.POWER_H, px))
        p.hp:SetPoint("TOPLEFT", p, "TOPLEFT", px, -px)
        p.hp:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -px, px)
        for _, e in ipairs({ t.sel, t.hov, t.glow, p.sel, p.hov }) do e.px(px) end
        t.powerOn = nil
        RP.showPower(t, true)
        if t.powerTex ~= ptex then t.powerTex = ptex; t.mp:SetStatusBarTexture(ptex) end
        if t.fillTex ~= tex then
            t.fillTex = tex
            t.hp:SetStatusBarTexture(tex)
            p.hp:SetStatusBarTexture(tex)
            p.hp:SetStatusBarColor(0.2, 0.75, 0.3)
        end
        RP.placeShields(t, w - 2 * px)
        if font ~= t.font then
            t.font = font
            -- (each string's own font remembered first, so Default goes back to it; set as a family that
            -- keeps the game's fonts for other alphabets, ns.setFont: Korean or Chinese names aren't boxes)
            for _, fs in ipairs({ t.name, t.status, t.hpText, t.mpText, p.name }) do
                if not fs.wfFontOrig then fs.wfFontOrig = { fs:GetFont() } end
                local o = fs.wfFontOrig
                pcall(ns.setFont, fs, font or o[1], o[2], o[3])
            end
        end
        RP.placeAuras(t)
        RP.buildDispel(t)
    end
    RP.placePets(RP.shownMembers or RP.MAX, RP.shownPets or 0)
end

-- The pet group's tiles, after `members` member tiles (Pet group: After the party: on down the stack,
-- or on along the row; Beside the party: a column to the right of the stack, or a row under the row),
-- `pets` of them out now; and the box round members and pets. Out of combat only.
function RP.placePets(members, pets)
    local d = RP.dim
    if not d or InCombatLockdown() then return end
    RP.shownMembers, RP.shownPets = members, pets
    local w, h, gap, pw, ph, across = d.w, d.h, d.gap, d.pw, d.ph, d.across
    local after = (get("rpPetPos") or "after") == "after"
    local right, bottom = 0, 0
    local function spot(p, x, y, sw, sh, counts)
        p:SetSize(sw, sh)
        p:ClearAllPoints()
        p:SetPoint("TOPLEFT", RP.box, "TOPLEFT", x, -y)
        if counts then right, bottom = math.max(right, x + sw), math.max(bottom, y + sh) end
    end
    -- (the box: always room for a full party, as before; and the pets out now)
    if across then right, bottom = RP.MAX * (w + gap) - gap, h else right, bottom = w, RP.MAX * (h + gap) - gap end
    for k = 1, RP.MAX do
        local x, y
        if across then
            if after then x, y = members * (w + gap) + (k - 1) * (pw + gap), 0 else x, y = (k - 1) * (pw + gap), h + gap end
        else
            if after then x, y = 0, members * (h + gap) + (k - 1) * (ph + gap) else x, y = w + gap, (k - 1) * (ph + gap) end
        end
        spot(RP.petTiles[k], x, y, pw, ph, k <= pets)
    end
    RP.box:SetSize(right, bottom)
end

-- The box's saved spot for this Edit Mode layout.
function RP.place()
    if InCombatLockdown() then RP.pending = true; return end
    local u = unitData("party")
    local d = RP.DEFAULT_POS
    RP.box:ClearAllPoints()
    if u and u.rpPoint then RP.box:SetPoint(u.rpPoint, UIParent, u.rpPoint, u.rpX or 0, u.rpY or 0)
    else RP.box:SetPoint(d.point, UIParent, d.point, d.x, d.y) end
end

-- Shown in a party (not in a raid, where raid frames take over), and solo too if asked, while the raid
-- style is on.
function RP.applyVisibility()
    if InCombatLockdown() then RP.pending = true; return end
    if RP.testing then return end
    if RP.enabled() then
        RegisterStateDriver(RP.box, "visibility", "[group:raid] hide; [group:party] show; " .. (get("rpSolo") and "show" or "hide"))
    else
        UnregisterStateDriver(RP.box, "visibility")
        RP.box:Hide()
    end
end

-- Everything again (an option changed).
function RP.apply()
    if not RP.box then return end
    if InCombatLockdown() then
        -- Already hidden and not in use: nothing secure is waiting, so don't keep a regen listen.
        if not RP.enabled() and not RP.testing and not RP.box:IsShown() then return end
        RP.pending = true
        return
    end
    RP.pending = nil
    -- Raid style off: clear the tiles and hide the box. No layout, no paint.
    if not RP.enabled() and not RP.testing then
        RP.arrange()
        RP.applyVisibility()
        return
    end
    RP.layout()
    RP.place()
    if RP.testing then RP.showSamples(); return end   -- (the sample party stays up, in the new layout)
    RP.arrange()
    RP.applyVisibility()
    for _, t in ipairs(RP.tiles) do if t.wfUnit then RP.paintAll(t) end end
    Party.updateMissing()
    Party.updateMana()
end

---------------------------------------------------------------------------
-- Sample party: made-up members in every state, to see and place the tiles without a group. In Edit
-- Mode, from the Party page's Preview button, or /webby party. Out of combat only; combat ends it.
---------------------------------------------------------------------------
-- (you first; then a tank holding aggro with Shield Wall up, a healer with a heal coming in, a hunter
-- with a poison you could dispel, a shield, a missing buff and his pet, someone dead and out of range)
RP.SAMPLES = {
    { you = true, hp = 0.92, mp = 0.8, leader = true },
    { name = "Brakka", class = "WARRIOR", role = "TANK", hp = 0.64, mp = 0.3, power = "RAGE", aggro = 3, marker = 8, defensive = 871 },
    { name = "Lyssandra", class = "PRIEST", role = "HEALER", hp = 0.81, mp = 0.55, heal = 0.12, target = true },
    { name = "Thornek", class = "HUNTER", role = "DAMAGER", hp = 0.38, mp = 0.9, dispel = "Poison", absorb = 0.15, pet = "Fang", missing = 1243, afk = true },
    { name = "Fenwick", class = "MAGE", role = "DAMAGER", hp = 0, mp = 0, dead = true, far = true },
}

-- The sample dispel pulse: the edge, the tint and the icon. Aggro stays at full alpha, so a sample
-- that is not dispelling stops these. Real threat uses the same edge and must not be left pulsing.
function RP.sampleRegions(t)
    local regs = t.pulseRegs
    if regs then return regs end
    regs = { t.wash, t.sampleDispel }
    for _, tex in ipairs(t.glow) do regs[#regs + 1] = tex end
    t.pulseRegs = regs
    return regs
end

function RP.startSamplePulse(t)
    for _, r in ipairs(RP.sampleRegions(t)) do AuraKit.attachPulse(r) end
end

function RP.stopSamplePulse(t)
    if not t.glow then return end
    for _, r in ipairs(RP.sampleRegions(t)) do AuraKit.stopPulse(r) end
end

-- A sample member's tile, painted from the made-up values.
function RP.paintSample(t, s)
    local name, class, role = s.name, s.class, s.role
    if s.you then
        pcall(function() name = UnitName("player"); class = select(2, UnitClass("player")); role = UnitGroupRolesAssigned("player") end)
    end
    t.name:SetText(RP.shortName(name or "", get("rpNameMax") or 0))
    local nc = get("rpNameColor") == "class" and (RAID_CLASS_COLORS or {})[class or ""]
    if nc then t.name:SetTextColor(nc.r, nc.g, nc.b) else t.name:SetTextColor(1, 1, 1) end
    t.hp:SetMinMaxValues(0, 100)
    t.hp:SetValue(s.hp * 100)
    local state = s.dead and "Dead" or ((s.afk and get("rpAFK")) and "AFK" or nil)
    RP.colorHealth(t, state, class, s.hp)
    t.status:SetText(state or "")
    t.status:SetShown(state ~= nil)
    local on = RP.numbersOn(t) and not state
    local fmt = get("textFormat")
    local function sampleText(fs, frac, max)
        local v = math.floor(frac * max + 0.5)
        local val = v >= 1000 and string.format("%.1fK", v / 1000) or tostring(v)
        if fmt == "percent" then fs:SetFormattedText("%d%%", frac * 100)
        elseif fmt == "both" then fs:SetFormattedText("%s (%d%%)", val, frac * 100)
        else fs:SetText(val) end
    end
    if on then sampleText(t.hpText, s.hp, 9800) end
    t.hpText:SetShown(on and true or false)
    for _, bar in ipairs({ { t.heal, s.heal }, { t.absorb, s.absorb } }) do
        bar[1]:SetMinMaxValues(0, 100)
        bar[1]:SetValue((bar[2] or 0) * 100)
    end
    RP.showPower(t, RP.powerFor(role))
    t.mp:SetMinMaxValues(0, 100)
    t.mp:SetValue(s.mp * 100)
    local mpOn = on and t.powerOn and (s.power or "MANA") == "MANA"
    if mpOn then sampleText(t.mpText, s.mp, 7200) elseif on and t.powerOn then t.mpText:SetText(tostring(math.floor(s.mp * 100))) end
    t.mpText:SetShown((on and t.powerOn) and true or false)
    local pc = PowerBarColor and PowerBarColor[s.power or "MANA"]
    if pc then t.mp:SetStatusBarColor(pc.r, pc.g, pc.b) end
    local atlas = role and RP.ROLE_ATLAS[role]
    if atlas and pcall(t.role.SetAtlas, t.role, atlas) then t.role:Show() else t.role:Hide() end
    t.roleAtlas = nil
    RP.placeText(t)
    t.leader:SetShown(s.leader and true or false)
    if s.marker then SetRaidTargetIconTexture(t.marker, s.marker) end
    t.marker:SetShown(s.marker and true or false)
    t.center:Hide()
    t.sel.shown(s.target)
    -- big defensive
    local defTex = s.defensive and get("rpDefensives") and spellIcon(s.defensive)
    if defTex then t.sampleDef:SetTexture(defTex) end
    t.sampleDef:SetShown(defTex and true or false)
    -- a dispellable debuff (its colour pulsing, in the chosen style), else aggro
    t.dispelRGB = (s.dispel and get("dispelGlow")) and { AuraKit.dispelRGB(s.dispel) } or nil
    t.sampleDispel:Hide()
    t.wash:Hide()
    t.glow.shown(false)
    if t.dispelRGB then
        local c, style = t.dispelRGB, get("rpDispelStyle") or "gradient"
        t.glow.color(c[1], c[2], c[3], 1)
        t.glow.shown(true)
        if style == "fill" then
            pcall(t.wash.SetGradient, t.wash, "VERTICAL", CreateColor(c[1], c[2], c[3], 0.35), CreateColor(c[1], c[2], c[3], 0.35))
            t.wash:Show()
        elseif style ~= "edge" then
            pcall(t.wash.SetGradient, t.wash, "VERTICAL", CreateColor(c[1], c[2], c[3], 0.6), CreateColor(c[1], c[2], c[3], 0))
            t.wash:Show()
        end
        if get("rpDispelIcon") then
            t.sampleDispel:ClearAllPoints()
            t.sampleDispel:SetPoint("RIGHT", t.hp, "RIGHT", -2, 0)
            if not pcall(t.sampleDispel.SetAtlas, t.sampleDispel, "RaidFrame-Icon-Debuff" .. s.dispel) then
                t.sampleDispel:SetTexture("Interface\\RaidFrame\\Raid-Icon-Debuff" .. s.dispel)
            end
            t.sampleDispel:Show()
        end
        RP.startSamplePulse(t)
    else
        RP.stopSamplePulse(t)
        if s.aggro then
            local r, g, b = threatColor("target", s.aggro, 100)
            t.glow.alpha(1)
            t.glow.color(r, g, b, 1)
            t.glow.shown(true)
        end
    end
    t:SetAlpha((s.far and get("rangeFade")) and (tonumber(get("rangeAlpha")) or 0.45) or 1)
end

-- The sample party on the tiles (the aura icons too: Blizzard's own sample icons).
function RP.showSamples()
    local list = {}
    for i, s in ipairs(RP.SAMPLES) do
        if i > 1 or get("rpSelf") then list[#list + 1] = s end
    end
    local pets = get("rpPets")
    -- (the sample pets, packed into the pet group as the real ones are)
    local samplePets = {}
    if pets then
        for _, s in ipairs(list) do if s.pet then samplePets[#samplePets + 1] = s.pet end end
    end
    for i, p in ipairs(RP.petTiles) do
        UnregisterUnitWatch(p)
        local name = samplePets[i]
        if name then
            p.sample = nil
            if p.wfUnit ~= "player" then RP.setUnit(p, "player") end
            p.sample = name
            p.name:SetText(name)
            p.hp:SetMinMaxValues(0, 100)
            p.hp:SetValue(75)
            p.sel.shown(false)
            p:Show()
        else
            p.sample = nil
            p:Hide()
        end
    end
    RP.placePets(#list, #samplePets)
    for i, t in ipairs(RP.tiles) do
        UnregisterUnitWatch(t)
        local s = list[i]
        if s then
            t.sample = nil
            if t.wfUnit ~= "player" then RP.setUnit(t, "player") end     -- (a harmless real unit to click)
            t.sample = s
            t:Show()
            RP.paintSample(t, s)
        else
            t.sample = nil
            RP.stopSamplePulse(t)
            t:Hide()
        end
        if t.dispelBox then t.dispelBox:SetShown(s == nil) end         -- (the samples draw their own)
        for _, c in ipairs({ t.debuffs, t.buffs }) do
            if c then pcall(c.SetEditModePreviewEnabled, c, s ~= nil) end
        end
        if t.defs then t.defs:SetShown(s == nil and get("rpDefensives") and true or false) end
    end
    Party.updateMissing()
    Party.updateMana()
end

function RP.startTest(fromEditMode)
    if not RP.box then return end
    if InCombatLockdown() then
        print("|cff33ccffWebby Frames:|r the sample party can't be shown in combat.")
        return
    end
    if not RP.enabled() then
        if not fromEditMode then print("|cff33ccffWebby Frames:|r set the Party page's Style to Raid style first.") end
        return
    end
    RP.testing = true
    RP.fromEditMode = fromEditMode
    UnregisterStateDriver(RP.box, "visibility")
    RP.box:Show()
    RP.showSamples()
end

function RP.stopTest()
    if not RP.testing then return end
    RP.testing, RP.fromEditMode = nil, nil
    for i, t in ipairs(RP.tiles) do
        local p = RP.petTiles[i]
        t.sample, t.dispelRGB, p.sample, t.roleAtlas = nil, nil, nil, nil
        t.wfUnit, p.wfUnit = nil, nil           -- (every tile gets its real unit back)
        t:SetAlpha(1)
        RP.stopSamplePulse(t)
        t.sampleDef:Hide()
        t.sampleDispel:Hide()
        if t.dispelBox then t.dispelBox:Show() end
        for _, c in ipairs({ t.debuffs, t.buffs }) do
            if c then pcall(c.SetEditModePreviewEnabled, c, false) end
        end
    end
    if InCombatLockdown() then RP.pending = true; return end
    RP.apply()
end

function RP.toggleTest()
    if RP.testing then RP.stopTest() else RP.startTest(false) end
end

-- Edit Mode: the sample party shows, and the box can be dragged.
function RP.enterEdit() RP.startTest(true) end
function RP.exitEdit() if RP.fromEditMode then RP.stopTest() end end

function RP.setupEditMode()
    local lib = LibStub and LibStub("LibEditMode", true)
    if not lib then return end
    lib:AddFrame(RP.box, function(_, layoutName, point, x, y)
        local active = layoutName == lib:GetActiveLayoutName()
        if active and ns.snapFrame then
            local sp, sx, sy = ns.snapFrame(RP.box)      -- (lines up with the other frames, as they do)
            if sp then point, x, y = sp, sx, sy end
        end
        local u = unitData("party", true, layoutName)
        u.rpPoint, u.rpX, u.rpY = point, x, y
        if active then RP.place() end
    end, RP.DEFAULT_POS, "Webby Party Frames (raid style)")
    lib:RegisterCallback("layout", function() C_Timer.After(0, RP.apply) end)
    -- (for Edit Mode's toolbar, snapping and EllesmereUI's Unlock Mode; the sample party while either is open)
    ns.addMover({
        frame = RP.box, label = "Party frames (raid style)", page = "party",
        store = function(point, x, y) local u = unitData("party", true); u.rpPoint, u.rpX, u.rpY = point, x, y end,
        place = RP.place,
        reset = function() local u = unitData("party", true); u.rpPoint, u.rpX, u.rpY = nil, nil, nil; RP.place() end,
        enter = RP.enterEdit,
        exit = RP.exitEdit,
    })
end

---------------------------------------------------------------------------
-- Start (from Party.init, at login, out of combat: secure buttons can't be made in combat)
---------------------------------------------------------------------------
RP.EVENTS = { "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
    "PLAYER_REGEN_DISABLED", "PARTY_LEADER_CHANGED", "READY_CHECK", "READY_CHECK_CONFIRM",
    "READY_CHECK_FINISHED", "RAID_TARGET_UPDATE", "INCOMING_RESURRECT_CHANGED",
    "INCOMING_SUMMON_CHANGED", "UNIT_PET" }

-- Raid style is on, or the box is still showing because combat has not let it hide.
function RP.live()
    if RP.enabled() or RP.testing then return true end
    return RP.box and RP.box:IsShown()
end

function RP.onGroup(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        -- combat ends the sample party (the last moment its tiles can still be changed)
        if RP.testing then RP.stopTest() end
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        if RP.pending then RP.apply() end
        RP.syncIdle()
        return
    end
    if RP.testing or not RP.enabled() then return end    -- (the sample party keeps the tiles; off, nothing to do)
    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" or event == "PLAYER_ENTERING_WORLD" or event == "UNIT_PET" then
        RP.arrange()
        for _, t in ipairs(RP.tiles) do if t.wfUnit then RP.paintAll(t) end end
        for _, p in ipairs(RP.petTiles) do if p.wfUnit then RP.paintPet(p) end end
    else
        -- (the ready check's icon lingers a few seconds after it ends, as the portrait frames' does)
        for _, t in ipairs(RP.tiles) do if t.wfUnit then RP.paintIcons(t) end end
        if event == "READY_CHECK_FINISHED" then
            C_Timer.After(6.1, function()
                if not RP.enabled() then return end
                for _, t in ipairs(RP.tiles) do if t.wfUnit then RP.paintIcons(t) end end
            end)
        end
    end
end

-- Range, five times a second, while the box is shown.
function RP.onTick()
    if not RP.box or not RP.box:IsVisible() then return end
    for _, t in ipairs(RP.tiles) do
        if t:IsVisible() and t.wfUnit and not t.sample then
            pcall(Party.updateRange, t)
        end
    end
end

function RP.syncEvents()
    local ev = RP.ev
    if not ev then return end
    if RP.live() then
        if RP.evMode ~= "all" then
            ev:UnregisterAllEvents()
            for _, e in ipairs(RP.EVENTS) do pcall(ev.RegisterEvent, ev, e) end
            RP.evMode = "all"
        end
    elseif RP.pending then
        if RP.evMode ~= "regen" then
            ev:UnregisterAllEvents()
            ev:RegisterEvent("PLAYER_REGEN_ENABLED")
            ev:RegisterEvent("PLAYER_REGEN_DISABLED")
            RP.evMode = "regen"
        end
    elseif RP.evMode then
        ev:UnregisterAllEvents()
        RP.evMode = nil
    end
end

function RP.syncTicker()
    if RP.live() then
        if not RP.rangeTicker then RP.rangeTicker = C_Timer.NewTicker(0.2, RP.onTick) end
    elseif RP.rangeTicker then
        RP.rangeTicker:Cancel()
        RP.rangeTicker = nil
    end
end

function RP.syncIdle()
    RP.syncEvents()
    RP.syncTicker()
end

-- Show or hide the raid style, and listen only while it is in use.
function RP.sync()
    if not RP.box then return end
    if not RP.enabled() and RP.testing then RP.stopTest() else pcall(RP.apply) end
    RP.syncIdle()
end

function RP.init()
    if RP.box then return end
    RP.box = CreateFrame("Frame", "WebbyFrames_RaidPartyBox", UIParent, "SecureHandlerStateTemplate")
    RP.box:SetFrameStrata("LOW")
    RP.box:SetClampedToScreen(true)
    RP.box:Hide()
    for i = 1, RP.MAX do RP.makeTile(i); RP.makePetTile(i) end
    RP.ev = CreateFrame("Frame")
    RP.ev:SetScript("OnEvent", RP.onGroup)
    -- (events and the range ticker start from RP.sync, and only while raid style is on)
    RP.setupEditMode()
    Party.makeManaBox()
end
