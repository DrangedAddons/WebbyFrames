-- Shelved 2026-10-18: the party frame reskin (Blizzard's own party frames with the Webby art) and its
-- look-alike preview. Not loaded. It lived in WebbyFrames.lua just before the Edit Mode section and used
-- getSetting("party", ...), Extras.tintColor, setArt / setFileMask, ART.smallBorder, BAR_FILE.small,
-- POWER_FILE and MEDIA; it was started from the startup code with pcall(PartySkin.init) and had an
-- options page (Webby look, frame colour, Test) and /webby party.

---------------------------------------------------------------------------
-- Party frames: Blizzard's own, reskinned. Everything Blizzard does with them keeps working (buffs,
-- debuffs and their tooltip, pets, ready checks, roles, range, clicks, Edit Mode position and size);
-- only the look changes, to the same DragonflightUI art as the small frames: the frame art, the
-- health and mana fills and their masks, the portrait spot and the frame colour. Blizzard re-applies
-- its art (on roster changes, vehicles, connection changes), so the skin is re-applied after it.
-- Their geometry matches the small frames', so everything is placed from the health bar. Raid-style
-- party frames (Edit Mode) are left alone.
---------------------------------------------------------------------------
local PartySkin = { hooked = {}, skinned = {} }

-- every Blizzard party member frame we can find (pooled, named or child of PartyFrame)
function PartySkin.members()
    local list, seen = {}, {}
    local function add(m)
        if m and not seen[m] and type(m) == "table" and m.HealthBarContainer and m.ManaBar then
            seen[m] = true
            list[#list + 1] = m
        end
    end
    local pf = _G.PartyFrame
    if pf then
        pcall(function() for m in pf.PartyMemberFramePool:EnumerateActive() do add(m) end end)
        for i = 1, 4 do add(pf["MemberFrame" .. i]) end
        pcall(function() for _, c in ipairs({ pf:GetChildren() }) do add(c) end end)
    end
    for i = 1, 4 do add(_G["PartyMemberFrame" .. i]) end
    return list
end

function PartySkin.enabled() return getSetting("party", "partySkin") and true or false end

-- the mana / rage / energy fill for the member's power type
function PartySkin.mana(m)
    if not PartySkin.enabled() then return end
    local token
    pcall(function() token = select(2, UnitPowerType(m.unit or m.unitToken)) end)
    local kind
    pcall(function() kind = POWER_FILE[token] end)
    pcall(m.ManaBar.SetStatusBarTexture, m.ManaBar, BAR_FILE.small .. (kind or "Mana"))
    pcall(function() m.ManaBar:SetStatusBarColor(1, 1, 1, 1) end)
end

function PartySkin.skin(m)
    if not PartySkin.enabled() or m.state == "vehicle" then return end
    local hc, mb = m.HealthBarContainer, m.ManaBar
    local hb = hc and hc.HealthBar
    if not (hc and hb and mb) then return end
    PartySkin.skinned[m] = true
    -- frame art (Retail's party art, as the small frames draw it), from the health bar's corner
    if m.Texture then
        setArt(m.Texture, ART.smallBorder)
        m.Texture:ClearAllPoints()
        m.Texture:SetPoint("TOPLEFT", hc, "TOPLEFT", -44, 16.5)
        local c = Extras.tintColor("party")
        pcall(m.Texture.SetDesaturated, m.Texture, c and true or false)
        if c then m.Texture:SetVertexColor(c[1], c[2], c[3]) else m.Texture:SetVertexColor(1, 1, 1) end
    end
    -- portrait where the art's ring is (its circle mask follows it)
    if m.Portrait then
        m.Portrait:ClearAllPoints()
        m.Portrait:SetPoint("TOPLEFT", hc, "TOPLEFT", -39, 11.5)
        m.Portrait:SetSize(37, 37)
    end
    -- health fill and its shape mask
    pcall(hb.SetStatusBarTexture, hb, BAR_FILE.small .. "Health")
    local hm = hc.HealthBarMask
    if hm then
        hm:SetTexture(MEDIA .. "uipartyframeportraitonhealthmask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        hm:SetTexCoord(0, 1, 0, 1)
        hm:SetSize(128, 16.5)
        hm:ClearAllPoints()
        hm:SetPoint("TOPLEFT", hb, "TOPLEFT", -29, 3)
    end
    -- mana fill and its mask
    PartySkin.mana(m)
    local mm = mb.ManaBarMask
    if mm then
        mm:SetTexture(MEDIA .. "uipartyframeportraitonmanamask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mm:SetTexCoord(0, 1, 0, 1)
        mm:SetSize(128, 16.5)
        mm:ClearAllPoints()
        mm:SetPoint("TOPLEFT", mb, "TOPLEFT", -27, 4)
    end
end

-- Hooks each member frame once, so the skin goes back on whenever Blizzard redraws its art.
function PartySkin.apply()
    for _, m in ipairs(PartySkin.members()) do
        if not PartySkin.hooked[m] then
            PartySkin.hooked[m] = true
            for _, fn in ipairs({ "ToPlayerArt", "UpdateArt", "Setup" }) do
                if type(m[fn]) == "function" then hooksecurefunc(m, fn, function(self) pcall(PartySkin.skin, self) end) end
            end
            pcall(m.HookScript, m, "OnShow", function(self) pcall(PartySkin.skin, self) end)
        end
        pcall(PartySkin.skin, m)
    end
end

function PartySkin.init()
    if not PartySkin.enabled() then return end
    -- the mana fill changes with the power type
    if type(_G.UnitFrameManaBar_UpdateType) == "function" then
        hooksecurefunc("UnitFrameManaBar_UpdateType", function(bar)
            local m = bar and bar.GetParent and bar:GetParent()
            if m and PartySkin.skinned[m] then pcall(PartySkin.mana, m) end
        end)
    end
    local pf = _G.PartyFrame
    for _, fn in ipairs({ "UpdatePartyFrames", "Layout" }) do
        if pf and type(pf[fn]) == "function" then hooksecurefunc(pf, fn, function() pcall(PartySkin.apply) end) end
    end
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("GROUP_ROSTER_UPDATE")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    ev:SetScript("OnEvent", function() C_Timer.After(0, function() pcall(PartySkin.apply) end) end)
    PartySkin.apply()
end

-- Test: a look-alike preview of a full party, drawn with our own frames over where Blizzard's party
-- frames sit (same art, fills, masks, frame colour and geometry as the skin above), each with your
-- portrait and name and a full row of sample buffs and debuffs. Blizzard's own party frames are never
-- touched: driving them from an addon breaks their protected-value handling. Ends after TEST_TIME
-- seconds, on a second press, or when combat starts.
PartySkin.TEST_TIME = 30
PartySkin.STEP = 56             -- one party frame below the next (Blizzard's frame height plus its gap)
PartySkin.SAMPLE_BUFFS = { "Spell_Holy_WordFortitude", "Spell_Nature_Regeneration", "Spell_Holy_MagicalSentry",
                           "Spell_Holy_FistOfJustice", "Spell_Nature_Rejuvenation" }
PartySkin.SAMPLE_DEBUFFS = {
    { "Spell_Shadow_ShadowWordPain", "Magic" }, { "Spell_Shadow_CurseOfTounges", "Curse" },
    { "Ability_Creature_Poison_02", "Poison" }, { "Ability_Creature_Disease_02", "Disease" },
}
PartySkin.SAMPLE_HEALTH = { 1, 0.72, 0.45, 0.18 }   -- how full each sample's health bar is

-- One stand-in party frame, laid out like a skinned Blizzard one (120x53, health bar at 45,-19).
function PartySkin.newMock(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(120, 53)
    f.portrait = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    f.portrait:SetSize(37, 37)
    f.portrait:SetPoint("TOPLEFT", 6, -7.5)
    local pm = f:CreateMaskTexture()
    pm:SetTexture(CIRCLE_FALLBACK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    pm:SetAllPoints(f.portrait)
    f.portrait:AddMaskTexture(pm)
    f.art = f:CreateTexture(nil, "ARTWORK")
    setArt(f.art, ART.smallBorder)
    f.art:SetPoint("TOPLEFT", 1, -2.5)
    local function bar(w, h, x, y, maskFile, mx, my)
        local b = CreateFrame("StatusBar", nil, f)
        b:SetSize(w, h)
        b:SetPoint("TOPLEFT", x, y)
        b:SetFrameLevel(f:GetFrameLevel())
        b:SetMinMaxValues(0, 1)
        local m = b:CreateMaskTexture()
        b.maskFile, b.mx, b.my, b.m = maskFile, mx, my, m
        return b
    end
    f.hp = bar(70, 10, 45, -19, "uipartyframeportraitonhealthmask", -29, 3)
    f.mp = bar(74, 7, 41, -30, "uipartyframeportraitonmanamask", -27, 4)
    for _, b in ipairs({ f.hp, f.mp }) do
        b:SetStatusBarTexture(b == f.hp and (BAR_FILE.small .. "Health") or (BAR_FILE.small .. "Mana"))
        setFileMask(b, b.m, b.maskFile, 128, 16.5, b.mx, b.my)
    end
    local top = CreateFrame("Frame", nil, f)
    top:SetAllPoints()
    top:SetFrameLevel(f:GetFrameLevel() + 2)
    f.name = top:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.name:SetSize(57, 12)
    f.name:SetJustifyH("LEFT")
    f.name:SetPoint("TOPLEFT", 46, -6)
    f.hpText = top:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
    f.hpText:SetPoint("CENTER", f.hp, "CENTER")
    f.icons = {}
    return f
end

-- The sample aura row (buffs, then one debuff of each dispel type edged in its colour), under the bars.
function PartySkin.mockAuras(f)
    local list = {}
    for _, b in ipairs(PartySkin.SAMPLE_BUFFS) do list[#list + 1] = { b } end
    for _, d in ipairs(PartySkin.SAMPLE_DEBUFFS) do list[#list + 1] = d end
    local size, now = 17, GetTime()
    for i, a in ipairs(list) do
        local ic = f.icons[i]
        if not ic then
            ic = CreateFrame("Frame", nil, f)
            ic.edge = ic:CreateTexture(nil, "BACKGROUND")
            ic.edge:SetAllPoints()
            ic.tex = ic:CreateTexture(nil, "ARTWORK")
            ic.tex:SetPoint("TOPLEFT", 1, -1)
            ic.tex:SetPoint("BOTTOMRIGHT", -1, 1)
            ic.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            ic.cd = CreateFrame("Cooldown", nil, ic, "CooldownFrameTemplate")
            ic.cd:SetAllPoints(ic.tex)
            pcall(ic.cd.SetHideCountdownNumbers, ic.cd, true)
            pcall(ic.cd.SetDrawEdge, ic.cd, false)
            f.icons[i] = ic
        end
        ic:SetSize(size, size)
        ic:ClearAllPoints()
        ic:SetPoint("TOPLEFT", f, "TOPLEFT", 48 + (i - 1) * (size + 2), -43)
        ic.tex:SetTexture("Interface\\Icons\\" .. a[1])
        local c = a[2] and DebuffTypeColor and DebuffTypeColor[a[2]]
        if a[2] then ic.edge:SetColorTexture(c and c.r or 0.8, c and c.g or 0, c and c.b or 0, 1)
        else ic.edge:SetColorTexture(0, 0, 0, 1) end
        pcall(ic.cd.SetCooldown, ic.cd, now - i * 4, 60)     -- staggered sweeps
        ic:Show()
    end
end

function PartySkin.stopTest()
    if not PartySkin.testing then return end
    PartySkin.testing = nil
    PartySkin.testToken = nil
    if PartySkin.preview then PartySkin.preview:Hide() end
    if PartySkin.watch then PartySkin.watch:UnregisterAllEvents() end
    print("|cff33ccffWebby Frames:|r party test over.")
end

function PartySkin.test()
    if PartySkin.testing then PartySkin.stopTest(); return end
    local box = PartySkin.preview
    if not box then
        box = CreateFrame("Frame", nil, UIParent)
        box:SetFrameStrata("MEDIUM")
        box:SetSize(120, PartySkin.STEP * 4)
        box.frames = {}
        for i = 1, 4 do
            local f = PartySkin.newMock(box)
            f:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -(i - 1) * PartySkin.STEP)
            box.frames[i] = f
        end
        PartySkin.preview = box
    end
    -- where Blizzard's party frames sit, at their Edit Mode size; the default spot if it can't tell
    local pf = _G.PartyFrame
    box:ClearAllPoints()
    if pf and pf:GetLeft() then
        box:SetScale(pf:GetEffectiveScale() / UIParent:GetEffectiveScale())
        box:SetPoint("TOPLEFT", pf, "TOPLEFT")
    else
        box:SetScale(1)
        box:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -260)
    end
    local tint = Extras.tintColor("party")
    local name = UnitName("player") or "Party member"
    for i, f in ipairs(box.frames) do
        SetPortraitTexture(f.portrait, "player")
        f.name:SetText(name)
        pcall(f.art.SetDesaturated, f.art, tint and true or false)
        if tint then f.art:SetVertexColor(tint[1], tint[2], tint[3]) else f.art:SetVertexColor(1, 1, 1) end
        local hp = PartySkin.SAMPLE_HEALTH[i] or 1
        f.hp:SetValue(hp)
        f.mp:SetValue(1 - (i - 1) * 0.2)
        f.hpText:SetFormattedText("%d%%", hp * 100)
        PartySkin.mockAuras(f)
    end
    box:Show()
    PartySkin.testing = true
    -- ends by itself, and when combat starts
    if not PartySkin.watch then
        PartySkin.watch = CreateFrame("Frame")
        PartySkin.watch:SetScript("OnEvent", function() pcall(PartySkin.stopTest) end)
    end
    PartySkin.watch:RegisterEvent("PLAYER_REGEN_DISABLED")
    local token = {}
    PartySkin.testToken = token
    C_Timer.After(PartySkin.TEST_TIME, function()
        if PartySkin.testToken == token then pcall(PartySkin.stopTest) end
    end)
    print("|cff33ccffWebby Frames:|r party preview for " .. PartySkin.TEST_TIME
        .. " seconds (press Test again, or /webby party, to stop).")
end
