-- Webby Frames: party frames
-- Four small frames (party1 - party4) sharing the "party" options. Slot 1 is frames.party and sits where
-- it was put; slots 2 - 4 stack under it, partyGap apart. The frames themselves are the small frames
-- WebbyFrames.lua builds (createSmallFrame); this file is what's party only: placing the slots, role
-- order, each member's pet, the role / leader / ready check / status icons, the threat glow and fading
-- out of range. Loads after WebbyFrames.lua (see the .toc), which shares its helpers through ns.
local _, ns = ...
local Party = ns.Party
local getSetting, frameOn, applyUnit, updateAll, threatColor = ns.getSetting, ns.frameOn, ns.applyUnit, ns.updateAll, ns.threatColor
local AuraKit, ART, BAR_FILE, POWER_FILE, CIRCLE_FALLBACK = ns.AuraKit, ns.ART, ns.BAR_FILE, ns.POWER_FILE, ns.CIRCLE_FALLBACK
local hasAtlas, newBar, setArt, setFileMask, resolveFont = ns.hasAtlas, ns.newBar, ns.setArt, ns.setFileMask, ns.resolveFont

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
    local has = false
    pcall(function() has = UnitExists(Party.petOf(prev.homeUnit or prev.wfUnit)) and true or false end)
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
-- watch). Polled five times a second; values only go to setters.
Party.PET_SCALE = 0.6
Party.PET_INDENT, Party.PET_TUCK = 24, 2  -- in from the member frame's portrait side; up under its bottom edge

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

function Party.paintPet(m)
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
    local token
    pcall(function() token = select(2, UnitPowerType(u)) end)
    local mpTex = f.powerTex or (BAR_FILE.small .. (POWER_FILE[token or ""] or "Mana"))
    if m.mpTex ~= mpTex then
        m.mpTex = mpTex
        m.mp:SetStatusBarTexture(mpTex)
        setFileMask(m.mp, m.mpMask, "uipartyframeportraitonmanamask", 128, 16.5, -27, 4, not m.left)
    end
    pcall(function()
        m.hp:SetMinMaxValues(0, UnitHealthMax(u)); m.hp:SetValue(UnitHealth(u))
        m.mp:SetMinMaxValues(0, UnitPowerMax(u)); m.mp:SetValue(UnitPower(u))
        m.name:SetText(UnitName(u))
    end)
    -- the portrait now and then (it's a rendered model, not worth five times a second)
    m.portraitTick = ((m.portraitTick or 0) + 1) % 10
    if m.portraitTick == 1 then pcall(SetPortraitTexture, m.portrait, u) end
    local font = resolveFont(getSetting("party", "font"))
    if m.font ~= font then
        m.font = font
        pcall(function() local fp, fz, ff = m.name:GetFont(); m.name:SetFont(font or fp, fz, ff) end)
    end
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
    m.portraitTick = 0
    m:SetAttribute("unit", Party.petOf(f.homeUnit or f.wfUnit))
    if frameOn("party") and getSetting("party", "partyPets") then RegisterUnitWatch(m) else UnregisterUnitWatch(m); m:Hide() end
    pcall(Party.paintPet, m)
end


-- Which unit each slot shows: party1 - 4, as Blizzard orders them or by role (tank, healer, damage).
-- A slot's unit can only change out of combat; a change while in one waits for it to end.
local ROLE_RANK = { TANK = 1, HEALER = 2, DAMAGER = 3 }
function Party.arrange()
    if InCombatLockdown() then Party.pendingArrange = true; return end
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
end

-- Gives a party slot another unit: its secure unit, its unit events, how it shows and hides, and a
-- repaint. (In Edit Mode it keeps showing you as the stand-in until Edit Mode closes.)
function Party.setUnit(f, unit)
    if f.homeUnit == unit then return end
    f.homeUnit = unit
    f:SetAttribute("unit", unit)
    for _, e in ipairs(Party.UNIT_EVENTS) do
        pcall(f.UnregisterEvent, f, e)
        pcall(f.RegisterUnitEvent, f, e, unit)
    end
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
        local status
        pcall(function() status = GetReadyCheckStatus(u) end)
        local tex = status and READY_TEX[status] and _G[READY_TEX[status]]
        if tex then return "file", tex end
    end
    local summon
    pcall(function()
        if C_IncomingSummon and C_IncomingSummon.HasIncomingSummon(u) then summon = C_IncomingSummon.IncomingSummonStatus(u) end
    end)
    if summon and SUMMON_ATLAS[summon] then return "atlas", SUMMON_ATLAS[summon] end
    local rez = false
    pcall(function() rez = UnitHasIncomingResurrection(u) and true or false end)
    if rez then return "file", "Interface\\RaidFrame\\Raid-Icon-Rez" end
    local phased = false
    pcall(function()
        if UnitPhaseReason then phased = UnitPhaseReason(u) ~= nil
        elseif UnitInPhase then phased = not UnitInPhase(u) end
    end)
    if phased then return "file", "Interface\\TargetingFrame\\UI-PhasingIcon" end
end


-- Role, leader and ready check for one party frame (only while it shows a real party member).
function Party.updateIcons(f)
    local icons = Party.icons(f)
    local u = f.wfUnit
    local real = not AuraKit.editing and UnitExists(u)      -- (not the Edit Mode stand-ins)
    -- role
    local role
    if real then pcall(function() role = UnitGroupRolesAssigned(u) end) end
    local atlas = role and ROLE_ATLAS[role]
    if atlas and pcall(icons.role.SetAtlas, icons.role, atlas) then icons.role:Show() else icons.role:Hide() end
    -- leader
    local lead = false
    if real then pcall(function() lead = UnitIsGroupLeader(u) and true or false end) end
    icons.leader:SetShown(lead)
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
        pcall(function() local s = UnitThreatSituation(u); if s and s >= 1 then status = s end end)
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
    for i = 1, Party.SLOTS do
        local f = Party.members[i]
        if f then pcall(Party.updateIcons, f) end
    end
end

-- Out of range: the frame fades. UnitInRange's answer can be hidden from addons in instances, so it goes
-- straight to SetAlphaFromBoolean, which takes a hidden answer too.
local RANGE_OUT = 0.45
function Party.updateRange(f)
    local u = f.wfUnit
    if u == "player" or not getSetting("party", "rangeFade") or not UnitExists(u) then f:SetAlpha(1); return end
    local inRange, checked
    pcall(function() inRange, checked = UnitInRange(u) end)
    -- (not checked: the game can't tell, e.g. in another zone; then it stays fully shown)
    local known = true
    pcall(function() if checked == false then known = false end end)
    if not known or inRange == nil then f:SetAlpha(1); return end
    if f.SetAlphaFromBoolean and pcall(f.SetAlphaFromBoolean, f, inRange, 1, RANGE_OUT) then return end
    local ok, near = pcall(function() return inRange and true or false end)
    f:SetAlpha((ok and not near) and RANGE_OUT or 1)
end

function Party.init()
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "PLAYER_ROLES_ASSIGNED", "PLAYER_ENTERING_WORLD",
                         "READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED", "PLAYER_REGEN_ENABLED",
                         "INCOMING_RESURRECT_CHANGED", "INCOMING_SUMMON_CHANGED", "UNIT_PHASE", "UNIT_THREAT_SITUATION_UPDATE",
                         "UNIT_FLAGS", "UNIT_CONNECTION", "UNIT_PET" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", function(_, event)
        -- who goes in which slot (role order, you): again when the group or its roles change, or after
        -- combat if a change had to wait
        if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" or event == "PLAYER_ENTERING_WORLD"
            or (event == "PLAYER_REGEN_ENABLED" and Party.pendingArrange) then
            pcall(Party.arrange)
        end
        -- a pet came or went (or the group changed): pet room under each member
        if event == "UNIT_PET" or event == "GROUP_ROSTER_UPDATE" or (event == "PLAYER_REGEN_ENABLED" and Party.pendingReflow) then
            pcall(Party.reflow)
        end
        if event == "READY_CHECK" then
            Party.readyCheck, Party.readyLinger = true, nil
        elseif event == "READY_CHECK_FINISHED" then
            Party.readyCheck, Party.readyLinger = nil, true
            C_Timer.After(6, function() Party.readyLinger = nil; Party.updateAllIcons() end)
        end
        Party.updateAllIcons()
    end)
    -- range, five times a second, for the party frames on show
    C_Timer.NewTicker(0.2, function()
        for i = 1, Party.SLOTS do
            local f = Party.members[i]
            if f and f:IsShown() then pcall(Party.updateRange, f) end
            -- and the pet / target minis on show
            if f and f.miniPet and f.miniPet:IsShown() then pcall(Party.paintPet, f.miniPet) end
        end
    end)
    pcall(Party.arrange)
    if ns.Click then pcall(ns.Click.init) end     -- (click casting on the frames, now they're made)
    Party.updateAllIcons()
end
