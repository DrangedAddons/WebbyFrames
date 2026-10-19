-- Webby Frames: Edit Mode, in the settings window's look. While Edit Mode is open:
--   - every Webby frame and box (ns.MOVERS) gets an amber outline and a name tag instead of Blizzard's
--     blue boxes, lit up when it's picked;
--   - the frame you pick gets a small toolbar: its settings page, back to its default spot, detach it
--     from the frame it's stuck to, and how to nudge it;
--   - amber guide lines show while you drag, wherever it would snap (to the other frames, Blizzard's,
--     the middle of the screen: ns.snapGuides, the same rules as the snapping itself);
--   - a banner at the top says what to do, with a button for the settings.
-- EllesmereUI's Unlock Mode has its own look and tools; every Webby frame and box is registered there
-- too (WebbyFrames.lua, setupEllesmere). Loads after Options.lua, whose look it borrows (ns.Opt).
local _, ns = ...
local Opt = ns.Opt
local EK = {}
ns.EditKit = EK

local function editLib() return LibStub and LibStub("LibEditMode", true) end
local function moverOf(frame)
    for _, m in ipairs(ns.MOVERS or {}) do if m.frame == frame then return m end end
end
local function selectionOf(frame)
    local l = editLib()
    return l and l.frameSelections and l.frameSelections[frame]
end

---------------------------------------------------------------------------
-- The boxes: an amber outline and a name tag on each Webby frame
---------------------------------------------------------------------------
function EK.style(sel, m)
    sel.webby = true
    local T, A = Opt.THEME, Opt.THEME.accent
    -- (the template's own blue boxes and label, hidden: ours instead)
    for _, r in ipairs({ sel:GetRegions() }) do pcall(r.SetAlpha, r, 0) end
    for _, c in ipairs({ sel:GetChildren() }) do pcall(c.SetAlpha, c, 0) end
    local fill = sel:CreateTexture(nil, "BACKGROUND", nil, 7)
    fill:SetAllPoints()
    local edges = Opt.outline(sel, "OVERLAY", A, 1)
    -- the name tag, just above the box's top left
    local tag = CreateFrame("Frame", nil, sel, "BackdropTemplate")
    tag:SetPoint("BOTTOMLEFT", sel, "TOPLEFT", 0, 3)
    tag:SetHeight(18)
    Opt.dark(tag, 0.2, T.bg)
    local bar = Opt.rect(tag, "ARTWORK", A, 1)
    bar:SetPoint("TOPLEFT"); bar:SetPoint("BOTTOMLEFT"); bar:SetWidth(2)
    local name = Opt.text(tag, 10)
    name:SetPoint("LEFT", 8, 0)
    name:SetText(m.label:upper())
    tag:SetWidth(math.ceil(name:GetStringWidth()) + 16)
    local function paint(selected)
        fill:SetColorTexture(A[1], A[2], A[3], selected and 0.16 or 0.06)
        for _, e in ipairs(edges) do e:SetAlpha(selected and 1 or 0.5) end
        local c = selected and T.text or T.dim
        name:SetTextColor(c[1], c[2], c[3])
        bar:SetAlpha(selected and 1 or 0.4)
    end
    paint(false)
    pcall(hooksecurefunc, sel, "ShowHighlighted", function() paint(false) end)
    pcall(hooksecurefunc, sel, "ShowSelected", function() paint(true) end)
    -- the guides while it's dragged
    sel:HookScript("OnDragStart", function() EK.startDrag(m.frame) end)
    sel:HookScript("OnDragStop", function() EK.stopDrag() end)
end

function EK.styleAll()
    for _, m in ipairs(ns.MOVERS or {}) do
        local sel = selectionOf(m.frame)
        if sel and not sel.webby then pcall(EK.style, sel, m) end
    end
end

---------------------------------------------------------------------------
-- The toolbar on the frame you pick
---------------------------------------------------------------------------
function EK.bar()
    if EK.toolbar then return EK.toolbar end
    local T, A = Opt.THEME, Opt.THEME.accent
    local b = CreateFrame("Frame", "WebbyFramesEditBar", UIParent, "BackdropTemplate")
    b:SetFrameStrata("DIALOG")
    b:SetClampedToScreen(true)
    b:EnableMouse(true)
    b:SetHeight(64)
    Opt.dark(b, 0.3, T.bg)
    local top = Opt.rect(b, "ARTWORK", A, 1)
    top:SetPoint("TOPLEFT", 1, -1); top:SetPoint("TOPRIGHT", -1, -1); top:SetHeight(2)
    b.title = Opt.text(b, 12)
    b.title:SetPoint("TOPLEFT", 10, -9)
    b.sub = Opt.text(b, 10, T.dim)
    b.sub:SetPoint("TOPLEFT", b.title, "BOTTOMLEFT", 0, -3)
    b.settings = Opt.newButton(b, 84, 22, "Settings")
    b.settings:SetPoint("BOTTOMLEFT", 8, 8)
    b.reset = Opt.newButton(b, 120, 22, "Reset position")
    b.reset:SetPoint("LEFT", b.settings, "RIGHT", 6, 0)
    b.detach = Opt.newButton(b, 76, 22, "Detach")
    b.detach:SetPoint("LEFT", b.reset, "RIGHT", 6, 0)
    Opt.tip(b.settings, "Settings", "Opens this frame's page in the Webby Frames settings.")
    Opt.tip(b.reset, "Reset position", "Puts it back where it starts out (for this Edit Mode layout). Its options stay as they are.")
    Opt.tip(b.detach, "Detach", "Unsticks it from the frame it's attached to: it stays where it is, but no longer moves with that frame.")
    b.settings:SetScript("OnClick", function()
        local m = EK.current
        if m and ns.openSettings then ns.openSettings(m.page) end
    end)
    b.reset:SetScript("OnClick", function()
        local m = EK.current
        if not m or InCombatLockdown() then return end
        if m.reset then pcall(m.reset) end
        C_Timer.After(0, function() if EK.current == m then EK.select(m.frame) end end)
    end)
    b.detach:SetScript("OnClick", function()
        local m = EK.current
        if not (m and m.unit) or InCombatLockdown() then return end
        pcall(ns.detachFrame, m.unit)
        EK.select(m.frame)
    end)
    b:Hide()
    EK.toolbar = b
    return b
end

function EK.select(frame)
    local m = frame and moverOf(frame)
    local b = EK.bar()
    EK.current = m
    if not m or EK.dragging then b:Hide(); return end
    b.title:SetText(m.label)
    local att = m.unit and ns.attachedTo and ns.attachedTo(m.unit)
    b.sub:SetText((att and ("Attached to the " .. att:lower() .. " frame.  ") or "") .. "Drag it, or nudge it with the arrow keys (Shift: 10 px).")
    b.detach:SetShown(att ~= nil)
    local w = 8 + 84 + 6 + 120 + (att and (6 + 76) or 0) + 8
    b:SetWidth(math.max(w, math.ceil(b.sub:GetStringWidth()) + 20, math.ceil(b.title:GetStringWidth()) + 20))
    -- above the frame (over its name tag), or under it when it's near the top of the screen
    local sel = selectionOf(frame) or frame
    b:ClearAllPoints()
    local topY = sel:GetTop() and sel:GetTop() * sel:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if topY and topY > UIParent:GetHeight() - 110 then
        b:SetPoint("TOPLEFT", sel, "BOTTOMLEFT", 0, -6)
    else
        b:SetPoint("BOTTOMLEFT", sel, "TOPLEFT", 0, 26)
    end
    b:Show()
end

function EK.hide()
    EK.current = nil
    if EK.toolbar then EK.toolbar:Hide() end
end

---------------------------------------------------------------------------
-- Guide lines while dragging
---------------------------------------------------------------------------
function EK.drawGuides()
    local g = EK.guides
    local list = EK.dragging and ns.snapGuides and ns.snapGuides(EK.dragging) or {}
    local A = Opt.THEME.accent
    for i, line in ipairs(list) do
        local t = g.lines[i]
        if not t then
            t = g:CreateTexture(nil, "OVERLAY")
            t:SetColorTexture(A[1], A[2], A[3], 0.9)
            g.lines[i] = t
        end
        t:ClearAllPoints()
        if line.x then
            t:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", line.x, line.y1 - 14)
            t:SetSize(1, (line.y2 - line.y1) + 28)
        else
            t:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", line.x1 - 14, line.y)
            t:SetSize((line.x2 - line.x1) + 28, 1)
        end
        t:Show()
    end
    for i = #list + 1, #g.lines do g.lines[i]:Hide() end
end

function EK.startDrag(frame)
    if not ns.snapGuides then return end
    local g = EK.guides
    if not g then
        g = CreateFrame("Frame", nil, UIParent)
        g:SetAllPoints(UIParent)
        g:SetFrameStrata("FULLSCREEN_DIALOG")
        g:EnableMouse(false)
        g.lines = {}
        EK.guides = g
    end
    EK.dragging = frame
    if EK.toolbar then EK.toolbar:Hide() end
    g:SetScript("OnUpdate", function() pcall(EK.drawGuides) end)
    g:Show()
end

function EK.stopDrag()
    local frame = EK.dragging
    EK.dragging = nil
    if EK.guides then
        EK.guides:SetScript("OnUpdate", nil)
        EK.guides:Hide()
    end
    -- (the toolbar back on it, once it has landed: it may have snapped or stuck to another frame)
    C_Timer.After(0.05, function()
        if frame and EK.current and EK.current.frame == frame then EK.select(frame) end
    end)
end

---------------------------------------------------------------------------
-- The banner at the top while Edit Mode is open
---------------------------------------------------------------------------
function EK.banner()
    if EK.top then return EK.top end
    local T, A = Opt.THEME, Opt.THEME.accent
    local b = CreateFrame("Frame", "WebbyFramesEditBanner", UIParent, "BackdropTemplate")
    b:SetFrameStrata("DIALOG")
    b:SetHeight(40)
    b:SetPoint("TOP", UIParent, "TOP", 0, -10)
    b:EnableMouse(true)
    Opt.dark(b, 0.3, T.bg)
    local line = b:CreateTexture(nil, "ARTWORK")
    line:SetPoint("BOTTOMLEFT", 1, 1); line:SetPoint("BOTTOMRIGHT", -1, 1); line:SetHeight(2)
    Opt.gradient(line, "HORIZONTAL", A, 0.9, A, 0.1)
    local logo = b:CreateTexture(nil, "ARTWORK")
    logo:SetSize(30, 30)
    logo:SetPoint("LEFT", 6, 1)
    logo:SetTexture(Opt.LOGO)
    local name = Opt.text(b, 13, A)
    name:SetPoint("LEFT", logo, "RIGHT", 6, 6)
    name:SetText("WEBBY FRAMES")
    local hint = Opt.text(b, 10, T.dim)
    hint:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
    hint:SetText("Click a Webby frame to pick it. Drag to move: it snaps to the others, and sticks to one it's dropped beside.")
    local open = Opt.newButton(b, 84, 24, "Settings")
    open:SetPoint("RIGHT", -8, 1)
    open:SetScript("OnClick", function() if ns.openSettings then ns.openSettings() end end)
    Opt.tip(open, "Settings", "Opens the Webby Frames settings.")
    b:SetWidth(6 + 30 + 6 + math.ceil(hint:GetStringWidth()) + 16 + 84 + 8)
    b:Hide()
    EK.top = b
    return b
end

function EK.enter()
    EK.styleAll()
    EK.banner():Show()
end

function EK.exit()
    EK.hide()
    EK.dragging = nil
    if EK.guides then EK.guides:SetScript("OnUpdate", nil); EK.guides:Hide() end
    if EK.top then EK.top:Hide() end
end
