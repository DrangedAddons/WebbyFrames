-- Webby Frames: the settings window (/webby): a window of its own, with the pages on the left (General,
-- All frames, one per frame, the modules' own) and the page's options on the right in collapsible
-- sections. Being an ordinary frame, it can stay open while you play, target things or use Edit Mode.
-- Esc > Options > AddOns > Webby Frames only describes the addon and has a button that opens this
-- window. Loads after WebbyFrames.lua (see the .toc), which shares what it needs through ns; the main
-- file builds it at login (Opt.build).
local _, ns = ...
local Opt = ns.Opt
Opt.sections = {}       -- (every collapsible section on every page: all folded each time the window opens)
local UNITS, UNIT_LABEL, frames, Party, Extras = ns.UNITS, ns.UNIT_LABEL, ns.frames, ns.Party, ns.Extras
local getSetting, setSetting, defaultFor, frameOn, plain = ns.getSetting, ns.setSetting, ns.defaultFor, ns.frameOn, ns.plain
local DEFAULT_SETTINGS, ALWAYS_SHOWN, OWN_CLASS, COLOR_MODES = ns.DEFAULT_SETTINGS, ns.ALWAYS_SHOWN, ns.OWN_CLASS, ns.COLOR_MODES
local hasCastAndThreat, textureChoices, fontChoices, Profiles = ns.hasCastAndThreat, ns.textureChoices, ns.fontChoices, ns.Profiles
local defaultTip, moveTipToDefault, addonVersion = ns.defaultTip, ns.moveTipToDefault, ns.addonVersion
-- (the actions: assigned late in the main file, so read when used)
local function resetFrame(...) return ns.resetFrame(...) end
local function copySettings(...) return ns.copySettings(...) end
local function openSettings(...) return ns.openSettings(...) end
local function openEditMode(...) return ns.openEditMode(...) end


function Opt.tip(frame, title, tip)
    if not tip then return end
    frame:SetScript("OnEnter", function(self)
        defaultTip(self)
        GameTooltip:SetText(title or "", 1, 1, 1)
        GameTooltip:AddLine(tip, 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

---------------------------------------------------------------------------
-- The look: flat dark panels, one accent colour, thin lines. Everything is drawn from plain colour
-- textures (no art files), so the whole window recolours from THEME. Change THEME.accent to retint it.
---------------------------------------------------------------------------
local WHITE = "Interface\\Buttons\\WHITE8X8"
local THEME = {
    accent = { 1, 0.72, 0.18 },         -- amber: lit toggles, slider fills, the page you're on
    bg     = { 0.035, 0.04, 0.05 },     -- the window
    panel  = { 0.06, 0.068, 0.085 },    -- the page list and the page
    raised = { 0.1, 0.11, 0.135 },      -- fields, buttons, section cards
    line   = { 1, 1, 1, 0.08 },         -- hairlines
    text   = { 0.93, 0.94, 0.96 },
    dim    = { 0.56, 0.59, 0.65 },
}
Opt.THEME, Opt.WHITE = THEME, WHITE
Opt.LOGO = "Interface\\AddOns\\WebbyFrames\\Media\\logo"      -- (the web emblem; also the minimap button's and the AddOns list's icon)
local A = THEME.accent

-- Font objects by size (the game's own font, so every language still has its letters).
local fontObjects = {}
function Opt.fontObject(size)
    local name = "WebbyFramesOptFont" .. size
    if not fontObjects[size] then
        local f = CreateFont(name)
        local path = GameFontNormal and select(1, GameFontNormal:GetFont()) or "Fonts\\FRIZQT__.TTF"
        f:SetFont(path, size, "")
        f:SetShadowOffset(1, -1)
        f:SetShadowColor(0, 0, 0, 0.85)
        f:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3])
        fontObjects[size] = f
    end
    return name
end
function Opt.text(parent, size, color, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY", Opt.fontObject(size or 12))
    local c = color or THEME.text
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    return fs
end

function Opt.rect(parent, layer, c, a, sub)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub)
    t:SetColorTexture(c[1], c[2], c[3], a or c[4] or 1)
    return t
end

-- A colour fading across a texture (left to right: "HORIZONTAL"; bottom to top: "VERTICAL").
function Opt.gradient(tex, orient, c1, a1, c2, a2)
    tex:SetTexture(WHITE)
    local ok = CreateColor and pcall(tex.SetGradient, tex, orient, CreateColor(c1[1], c1[2], c1[3], a1), CreateColor(c2[1], c2[2], c2[3], a2))
    if not ok then pcall(tex.SetGradientAlpha, tex, orient, c1[1], c1[2], c1[3], a1, c2[1], c2[2], c2[3], a2) end
end

-- A one-pixel outline on a draw layer ("HIGHLIGHT": only while the mouse is over a button).
function Opt.outline(frame, layer, c, a)
    local lines = {}
    for i, p in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = Opt.rect(frame, layer or "BORDER", c, a)
        t:SetPoint(p[1]); t:SetPoint(p[2])
        if i <= 2 then t:SetHeight(1) else t:SetWidth(1) end
        lines[i] = t
    end
    return lines
end

-- A flat panel with a hairline edge. (edge: how bright the edge is, 0-1; the old grey value)
function Opt.dark(frame, edge, shade)
    local c = shade or THEME.raised
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    frame:SetBackdropColor(c[1], c[2], c[3], 0.96)
    frame:SetBackdropBorderColor(1, 1, 1, 0.05 + (edge or 0.4) * 0.2)
end

-- A clickable field (dropdowns, key buttons): a panel that lights its edge and brightens on hover.
function Opt.styleField(b)
    Opt.dark(b, 0.4)
    local hl = Opt.rect(b, "HIGHLIGHT", { 1, 1, 1 }, 0.04)
    hl:SetAllPoints()
    Opt.outline(b, "HIGHLIGHT", A, 0.8)
end

-- A small down-pointing chevron, tinted (rotate it with SetRotation to point elsewhere).
function Opt.chevron(parent, size)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetSize(size or 14, size or 14)
    t:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    pcall(t.SetDesaturated, t, true)
    t:SetVertexColor(THEME.dim[1], THEME.dim[2], THEME.dim[3])
    return t
end

-- A flat button: a raised panel, its text in capitals, an accent edge and lift on hover (and while
-- LockHighlight'ed, for a tab that's picked). b:SetText / b:GetFontString work as usual.
function Opt.newButton(parent, w, h, text)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w or 160, h or 26)
    Opt.dark(b, 0.5)
    local fs = Opt.text(b, 11)
    fs:SetPoint("LEFT", 8, 0)
    fs:SetPoint("RIGHT", -8, 0)
    pcall(fs.SetWordWrap, fs, false)
    b:SetFontString(fs)
    local hl = Opt.rect(b, "HIGHLIGHT", A, 0.12)
    hl:SetAllPoints()
    Opt.outline(b, "HIGHLIGHT", A, 0.9)
    local bar = Opt.rect(b, "HIGHLIGHT", A, 1)
    bar:SetPoint("BOTTOMLEFT"); bar:SetPoint("BOTTOMRIGHT"); bar:SetHeight(2)
    b:SetScript("OnMouseDown", function(self) if self:IsEnabled() then fs:SetPoint("LEFT", 9, -1) end end)
    b:SetScript("OnMouseUp", function() fs:SetPoint("LEFT", 8, 0) end)
    b:SetMotionScriptsWhileDisabled(true)
    if text then b:SetText(text:upper()) end
    return b
end

-- A flat X (the window's close button, a row's remove button).
function Opt.newX(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size or 26, size or 26)
    local hl = Opt.rect(b, "HIGHLIGHT", { 0.9, 0.25, 0.2 }, 0.35)
    hl:SetAllPoints()
    for _, deg in ipairs({ 45, -45 }) do
        local t = Opt.rect(b, "ARTWORK", THEME.text, 0.85)
        t:SetSize((size or 26) * 0.55, 2)
        t:SetPoint("CENTER")
        t:SetRotation(math.rad(deg))
    end
    return b
end

-- A toggle switch (a CheckButton, so GetChecked / SetChecked / OnClick work as for a check box): a dark
-- track with the knob on the left, or an accent track with the knob on the right when on.
function Opt.newCheck(parent)
    local cb = CreateFrame("CheckButton", nil, parent)
    cb:SetSize(36, 18)
    local track = Opt.rect(cb, "BACKGROUND", THEME.raised, 1)
    track:SetAllPoints()
    Opt.outline(cb, "BORDER", { 1, 1, 1 }, 0.12)
    local lit = Opt.rect(cb, "ARTWORK", A, 0.9)
    lit:SetAllPoints()
    cb:SetCheckedTexture(lit)
    local hl = Opt.rect(cb, "HIGHLIGHT", { 1, 1, 1 }, 0.08)
    hl:SetAllPoints()
    -- (the knob on a frame of its own above the switch, so the game's drawing of the checked fill can
    -- never cover it)
    local top = CreateFrame("Frame", nil, cb)
    top:SetAllPoints()
    top:SetFrameLevel(cb:GetFrameLevel() + 2)
    local shadow = Opt.rect(top, "ARTWORK", { 0, 0, 0 }, 0.45)
    shadow:SetSize(14, 14)
    local knob = Opt.rect(top, "OVERLAY", THEME.text, 1)
    knob:SetSize(12, 12)
    local function place()
        local on = cb:GetChecked() and true or false
        knob:ClearAllPoints()
        knob:SetPoint(on and "RIGHT" or "LEFT", on and -3 or 3, 0)
        shadow:ClearAllPoints()
        shadow:SetPoint("CENTER", knob, "CENTER", 0, -1)
        -- on: a light knob at the right of the amber track; off: a grey one at the left of the dark track
        if on then knob:SetColorTexture(1, 1, 1, 1) else knob:SetColorTexture(THEME.dim[1], THEME.dim[2], THEME.dim[3], 1) end
    end
    local setChecked = cb.SetChecked
    function cb:SetChecked(v) setChecked(self, v); place() end
    cb:SetScript("PostClick", place)        -- (the builders set OnClick; this runs after it)
    place()
    return cb
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
        m:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
        m:SetBackdropColor(THEME.bg[1], THEME.bg[2], THEME.bg[3], 0.98)
        m:SetBackdropBorderColor(A[1], A[2], A[3], 0.55)
        m.buttons = {}
        for i = 1, Opt.MENU_ROWS do
            local b = CreateFrame("Button", nil, m)
            b:SetHeight(20)
            b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 20)
            b:SetPoint("RIGHT", m, "RIGHT", -6, 0)
            local hl = Opt.rect(b, "HIGHLIGHT", A, 0.16)
            hl:SetAllPoints()
            -- (the choice that's set: an accent bar at its left)
            b.check = Opt.rect(b, "ARTWORK", A, 1)
            b.check:SetSize(3, 14)
            b.check:SetPoint("LEFT", 6, 0)
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetSize(16, 16)
            b.icon:SetPoint("LEFT", 22, 0)
            b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            b.text = Opt.text(b, 12)
            b.text:SetPoint("RIGHT", -4, 0)
            b.text:SetJustifyH("LEFT")
            pcall(b.text.SetWordWrap, b.text, false)
            b:SetScript("OnClick", function(self)
                m:Hide()
                if self.value ~= nil and m.pick then m.pick(self.value) end
            end)
            m.buttons[i] = b
        end
        m.more = Opt.text(m, 10, THEME.dim)
        m.more:SetPoint("BOTTOMRIGHT", -8, 4)
        -- a search box on top of long lists: typing keeps the choices whose name has it in
        m.search = CreateFrame("EditBox", nil, m, "BackdropTemplate")
        m.search:SetHeight(20)
        m.search:SetPoint("TOPLEFT", 6, -6)
        m.search:SetPoint("RIGHT", m, "RIGHT", -6, 0)
        m.search:SetAutoFocus(false)
        m.search:SetFontObject(Opt.fontObject(12))
        m.search:SetTextInsets(6, 6, 0, 0)
        Opt.dark(m.search, 0.5)
        m.search.hint = Opt.text(m.search, 12, THEME.dim)
        m.search.hint:SetPoint("LEFT", 6, 0)
        m.search.hint:SetText("Type to search")
        m.search:SetScript("OnTextChanged", function(self)
            self.hint:SetShown(self:GetText() == "")
            m.offset = 0
            m:Filter()
            m:Fill()
        end)
        m.search:SetScript("OnEscapePressed", function(self) self:ClearFocus(); m:Hide() end)
        m.search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        -- the choices shown: all of them, or those matching the search (headings drop out then)
        function m:Filter()
            local q = (self.searching and self.search:GetText() or ""):lower()
            if q == "" then self.choices = self.all; return end
            local list = {}
            for _, c in ipairs(self.all) do
                if not c.header and tostring(c[2] or c[1]):lower():find(q, 1, true) then list[#list + 1] = c end
            end
            self.choices = list
        end
        function m:Fill()
            local n = #self.choices
            local top = self.searching and 26 or 0
            for i, b in ipairs(self.buttons) do
                b:SetPoint("TOPLEFT", 6, -6 - top - (i - 1) * 20)
                local c = self.choices[self.offset + i]
                b:SetShown(c ~= nil)
                if c then
                    -- (a heading: gold, not clickable; a choice may have an icon)
                    b.value = (not c.header) and c[1] or nil
                    b:EnableMouse(not c.header)
                    b.text:SetText(c[2] or (not c.header and tostring(c[1])) or "")
                    local tc = c.header and A or THEME.text
                    b.text:SetTextColor(tc[1], tc[2], tc[3])
                    b.check:SetShown(not c.header and c[1] == self.current)
                    b.icon:SetShown(c.icon ~= nil)
                    if c.icon then b.icon:SetTexture(c.icon) end
                    b.text:ClearAllPoints()
                    b.text:SetPoint("LEFT", c.header and 4 or (c.icon and 42 or 22), 0)
                    b.text:SetPoint("RIGHT", -4, 0)
                end
            end
            local more = n > Opt.MENU_ROWS
            self.more:SetText(more and string.format("%d-%d of %d, scroll for more", self.offset + 1, math.min(n, self.offset + Opt.MENU_ROWS), n) or "")
            self:SetHeight(math.min(math.max(n, 1), Opt.MENU_ROWS) * 20 + 12 + top + (more and 14 or 0))
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
    m.owner, m.all, m.current, m.pick = owner, choices or {}, current, pick
    m.choices = m.all
    m.offset = 0
    -- (the search box, for lists longer than the menu)
    m.searching = #m.all > Opt.MENU_ROWS
    m.search:SetShown(m.searching)
    m.search:SetText("")
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
        local c = on and THEME.text or THEME.dim
        t:SetTextColor(c[1], c[2], c[3], on and 1 or 0.6)
    end
    -- (and its controls faded)
    for _, c in ipairs(row.controls or {}) do
        if c.SetAlpha then c:SetAlpha(on and 1 or 0.4) end
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
-- (a page's rows are made the first time it's shown, or searched)
local function makeRows(page)
    if page.content then return end
    page.content = CreateFrame("Frame", nil, Opt.scroll)
    page.content:SetSize(Opt.CONTENT_W, 10)
    page.content:Hide()
    for _, row in ipairs(page.rows) do
        local f = CreateFrame("Frame", nil, page.content)
        f:SetHeight(row.height)
        row.frame = f
        if row.section or row.card then
            -- (the rows of a section sit on its card; a page's own rows can ask for one too: row.card)
            local card = Opt.rect(f, "BACKGROUND", THEME.raised, 0.35)
            card:SetPoint("TOPLEFT", 6, 0)
            card:SetPoint("BOTTOMRIGHT", -6, 0)
        end
        local ok, err = pcall(row.make, f, row)
        if not ok and not layoutErrorShown then
            layoutErrorShown = true
            print("|cffff9900Webby Frames:|r an options row couldn't be drawn: " .. tostring(err))
        end
    end
end

-- Whether a row's own conditions (B.showIf, B.under, and its section's) let it show.
local function rowShowable(row)
    for _, r in ipairs({ row, row.section and row.section.header }) do
        for _, pred in ipairs(r.preds or {}) do
            local ok, v = pcall(pred)
            if not (ok and v) then return false end
        end
    end
    return true
end

-- Puts a row at y in content (the search results borrow rows from their pages), greys it out or
-- not, and redraws its controls. Returns the height it takes.
-- (off: greyed out whatever its own conditions say: a search result that isn't in use now)
-- (which: for a pair of switches, the one half a search matched; nil: both, as on the page)
local function placeRow(row, content, y, off, which)
    if row.frame:GetParent() ~= content then row.frame:SetParent(content) end
    row.frame:Show()
    if row.only and row.onlyNow ~= (which or 0) then
        row.onlyNow = which or 0
        row.only(which)
    end
    row.frame:ClearAllPoints()
    row.frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
    row.frame:SetPoint("RIGHT", content, "RIGHT")
    row.y = y
    local on = not off
    if on and row.enabledIf then
        local ok, v = pcall(row.enabledIf)
        on = ok and v and true or false
    end
    if on and row.parentRow and row.parentRow.enabled == false then on = false end
    Opt.setRowEnabled(row, on)
    if row.refresh then
        row.updating = true
        pcall(row.refresh)
        row.updating = false
    end
    return row.height
end

-- The search results, in place of a page (like the game's own settings search): every setting
-- whose name has what was typed in, from every page, live, under its page's and section's name.
local function layoutSearch(q)
    local content = Opt.searchContent
    if not content then
        content = CreateFrame("Frame", nil, Opt.scroll)
        content:SetSize(Opt.CONTENT_W, 10)
        content.heads = {}
        content.none = Opt.text(content, 13, THEME.dim)
        content.none:SetPoint("TOPLEFT", Opt.LABEL_X, -16)
        content.none:SetText("No settings match.")
        Opt.searchContent = content
    end
    for _, p in pairs(Opt.pages) do
        if p.content then p.content:Hide() end
    end
    content:Show()
    if Opt.scroll:GetScrollChild() ~= content then
        Opt.scroll:SetScrollChild(content)
        Opt.scroll:SetVerticalScroll(0)
    end
    for _, h in ipairs(content.heads) do h:Hide() end
    content.notes = content.notes or {}
    for _, n in ipairs(content.notes) do n:Hide() end
    for _, row in ipairs(Opt.borrowed or {}) do row.frame:Hide() end
    Opt.borrowed = {}
    local placed = {}
    local y, nHeads, nNotes, lastHead = 6, 0, 0, nil
    local function heading(text)
        if text == lastHead then return end
        lastHead = text
        nHeads = nHeads + 1
        local fs = content.heads[nHeads]
        if not fs then
            fs = Opt.text(content, 12, A)
            fs:SetJustifyH("LEFT")
            content.heads[nHeads] = fs
        end
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", content, "TOPLEFT", Opt.LABEL_X, -(y + 12))
        fs:SetText(text)
        fs:Show()
        y = y + 32
    end
    -- (a small line saying why the setting under it is greyed out)
    local function note(text, indent)
        nNotes = nNotes + 1
        local fs = content.notes[nNotes]
        if not fs then
            fs = Opt.text(content, 11, THEME.dim)
            fs:SetJustifyH("LEFT")
            content.notes[nNotes] = fs
        end
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", content, "TOPLEFT", Opt.LABEL_X + 20 + 18 * (indent or 0), -(y + 4))
        fs:SetText(text)
        fs:Show()
        y = y + 18
    end
    -- (what to look for: what was typed, and the words that mean the same)
    local terms = Opt.searchTerms(q)
    local function matches(text)
        if not text then return false end
        for _, term in ipairs(terms) do if text:find(term, 1, true) then return true end end
        return false
    end
    -- (a pair of switches where only one half's name matches: just that half)
    local function half(row)
        local h = row.halves
        if not h then return nil end
        local m1, m2 = matches(h[1]:lower()), matches(h[2]:lower())
        if m1 and not m2 then return 1 elseif m2 and not m1 then return 2 end
    end
    local function place(row, off, which)
        if placed[row] then return end
        placed[row] = true
        y = y + placeRow(row, content, y, off, which)
        Opt.borrowed[#Opt.borrowed + 1] = row
    end
    for _, id in ipairs(Opt.order) do
        local page = Opt.pages[id]
        local pageOff = page and UNIT_LABEL[id] and not frameOn(id)
        for _, row in ipairs(page and page.rows or {}) do
            if matches(row.find) and not placed[row] then
                makeRows(page)
                if row.frame then
                    -- a heading each time the page or section changes
                    heading(page.name:upper() .. (row.section and ("  |cff8f96a6/  " .. row.section.title:upper() .. "|r") or ""))
                    local why, parent, usable = Opt.whyOff(page, row, pageOff)
                    if not why then
                        place(row, false, half(row))
                    else
                        -- not in use now: the switch it needs, to turn on right here; a note saying why; then
                        -- the setting itself. It's greyed out only while that switch above it is off: a
                        -- setting for the other party style or a hidden frame can still be set, ready.
                        if parent and not placed[parent] and parent.frame then place(parent) end
                        note(why, row.indent)
                        place(row, not usable, half(row))
                    end
                end
            end
        end
    end
    content.none:SetShown(#Opt.borrowed == 0)
    return content, y
end

-- Words that mean the same: typing any of them (or the start of one, 3 letters on) searches for all of
-- them, so "threat" and "aggro" find the same settings, and "color" finds "colour".
Opt.SYNONYMS = {
    { "threat", "aggro" }, { "health", "hp" }, { "power", "mana", "rage", "energy" },
    { "dispel", "cleanse", "decurse" }, { "buff", "hot" }, { "debuff", "dot" }, { "absorb", "shield" },
    { "cast bar", "castbar", "casting" }, { "colour", "color" }, { "opacity", "alpha", "transparent", "see-through" },
    { "spacing", "gap", "padding" }, { "numbers", "values" }, { "pet", "minion" },
}
function Opt.searchTerms(q)
    -- (only when what's typed is one of the words, or from 3 letters the start of one: "health colour"
    -- stays as typed rather than turning into "anything with hp or color")
    local terms, seen = { q }, { [q] = true }
    for _, set in ipairs(Opt.SYNONYMS) do
        local hit = false
        for _, w in ipairs(set) do
            if w == q or (#q >= 3 and w:find(q, 1, true) == 1) then hit = true; break end
        end
        if hit then
            for _, w in ipairs(set) do if not seen[w] then seen[w] = true; terms[#terms + 1] = w end end
        end
    end
    return terms
end

-- Words people search for that aren't in a setting's name (by setting key), so "kick" finds Cast bar and
-- "oom" Healer mana. Only ever whole settings: section headings aren't searched (too broad).
Opt.SEARCH_WORDS = {
    enabled = "enable disable turn off addon", combatNumbers = "floating combat text fct damage numbers",
    minimapButton = "minimap icon", scale = "size bigger smaller", font = "text typeface",
    frameTint = "border color gold class", portraitStyle = "class icon face picture",
    barTexture = "hp health statusbar", powerTexture = "mana rage energy focus power statusbar",
    hpAlpha = "hp transparent see-through alpha", mpAlpha = "mana rage energy transparent see-through alpha",
    textMode = "hp mana values text", textFormat = "percent percentage values text",
    colorMode = "hp color class reaction", rpHealthColor = "hp color class", petColor = "hp color",
    npcColor = "hp color mob enemy", healthFade = "hp red low health gradient color",
    healPrediction = "heal prediction hots", absorbs = "shield absorb", damageTrail = "hit lost red hp",
    damagePredict = "spell damage preview", costPredict = "mana cost", costShade = "mana cost",
    threatOn = "aggro tank", threatShow = "aggro tank", threatStyle = "aggro tank percent", threatColors = "aggro tank color",
    dispelGlow = "cleanse decurse magic curse poison disease debuff", dispelWho = "cleanse decurse debuff",
    rpDispelStyle = "cleanse decurse debuff", rpDispelIcon = "cleanse decurse magic curse poison disease debuff",
    auraBuffs = "hots auras", auraDebuffs = "dots auras", rpBuffs = "hots auras", rpDebuffs = "dots auras", auraMine = "dots my debuffs", auraMineBig = "dots my debuffs",
    auraTimer = "cooldown duration timer countdown swipe", auraPos = "auras buffs debuffs",
    castShow = "castbar casting spell interrupt kick", castText = "castbar spell", castIcon = "castbar spell",
    partyGap = "gap padding", rpGap = "gap padding", rangeFade = "range distance alpha", rangeAlpha = "range distance alpha fade",
    partyTooltip = "mouseover hover", partyStyle = "raid frames compact grid tiles portrait", partySort = "order role sort",
    partyLayout = "horizontal vertical", rpPets = "pet minion", partyPets = "pet minion", rpPetPos = "pets", rpPetHeight = "pets",
    missingBuffs = "buff reminder fortitude intellect mark blessing", healerMana = "healer oom",
    druidMana = "bear cat form", druidBars = "bear cat form mana", comboPoints = "rogue cp",
    petHappy = "hunter loyalty feed", weaponEnchants = "poison oil sharpening stone imbue enchant",
    buffBars = "timer bars", rpShieldStyle = "absorb", rpShieldEdge = "absorb",
    rpDefensives = "cooldowns wall divine ice block barkskin", rpSelf = "me player", rpSolo = "alone",
    clickTooltip = "click casting bindings", clickAllFrames = "click casting bindings",
}

-- Why a search result isn't in use now (nil: it is); the row to show above it that would bring it in (a
-- switch it sits under, or the frame's own Show), if there is one; and whether it can still be changed
-- as it is (true, unless it sits under a switch that's off).
Opt.predNotes, Opt.predParts = {}, {}
local function firstFailing(row)
    for _, r in ipairs({ row, row.section and row.section.header }) do
        for _, pred in ipairs(r and r.preds or {}) do
            local ok, v = pcall(pred)
            if not (ok and v) then return pred end
        end
    end
end
-- (a condition made of others says why through the first of them that fails, else its own note)
local function noteFor(pred)
    for _, part in ipairs(Opt.predParts[pred] or {}) do
        local ok, v = pcall(part)
        if not (ok and v) then
            local n = noteFor(part)
            if n then return n end
        end
    end
    return Opt.predNotes[pred]
end
function Opt.whyOff(page, row, pageOff)
    if pageOff then
        for _, r in ipairs(page.rows) do
            if r.keys and r.keys.frameShown then return "The " .. page.name:lower() .. " frame is turned off.", r, true end
        end
        return "The " .. page.name:lower() .. " frame is turned off.", nil, true
    end
    local bad = firstFailing(row)
    if not bad then return nil end
    local parent = row.parentRow
    if parent and bad == row.enabledIf then
        -- (the switch it needs isn't in use either: say why that is)
        local parentWhy = Opt.whyOff(page, parent, false)
        if parentWhy then return parentWhy, parent, false end
        local label = parent.search or "the setting above"
        if parent.kind == "switch" then return "Needs " .. label .. " turned on.", parent, false end
        return "Depends on " .. label .. ".", parent, false
    end
    return noteFor(bad) or "Not used with your current choices.", nil, true
end

function Opt.layout()
    local w = Opt.window
    if not (w and w:IsShown()) then return end
    local q = Opt.query or ""
    local content, y
    if #q >= 2 then
        content, y = layoutSearch(q)
    else
        local page = Opt.pages[Opt.current]
        if not page then return end
        makeRows(page)
        if Opt.searchContent then Opt.searchContent:Hide() end
        for _, p in pairs(Opt.pages) do
            if p.content then p.content:SetShown(p == page) end
        end
        content = page.content
        if Opt.scroll:GetScrollChild() ~= content then
            Opt.scroll:SetScrollChild(content)
            Opt.scroll:SetVerticalScroll(0)
        end
        y = 6
        for _, row in ipairs(page.rows) do
            local shown = (not row.section or row.section.expanded) and rowShowable(row)
            if shown then
                y = y + placeRow(row, content, y)
            else
                if row.frame:GetParent() ~= content then row.frame:SetParent(content) end
                row.frame:Hide()
            end
        end
    end
    content:SetHeight(y + 10)
    -- (the plain scroll frame doesn't keep its position inside the new height by itself)
    local max = math.max(0, y + 10 - Opt.scroll:GetHeight())
    if Opt.scroll:GetVerticalScroll() > max then Opt.scroll:SetVerticalScroll(max) end
    -- the scroll bar only when there's something to scroll (the mouse wheel does nothing either way then)
    if Opt.scrollBar then Opt.scrollBar:SetShown(max > 0) end
    local searching = #q >= 2
    for id, b in pairs(Opt.navButtons or {}) do b.selected:SetShown(not searching and id == Opt.current) end
    Opt.layoutNav()
end

-- The page list: General, All frames, and under All frames the frame pages, folded away until its +
-- is clicked. Frames turned off on the General page aren't listed.
function Opt.layoutNav()
    if not Opt.navButtons then return end
    -- the page on show was a frame just turned off: go to All frames instead
    local cur = Opt.current
    if cur and UNIT_LABEL[cur] and not frameOn(cur) then
        Opt.current = "all"
        Opt.changed()
    end
    local y = 8
    for _, id in ipairs(Opt.order) do
        local b = Opt.navButtons[id]
        local isFrame = UNIT_LABEL[id] ~= nil      -- (General, All frames and Click casting are top-level)
        local shown = not isFrame or (Opt.framesOpen and frameOn(id))
        if b then
            b:SetShown(shown and true or false)
            if shown then
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", 1, -y)
                b:SetPoint("RIGHT", b:GetParent(), "RIGHT", -1, 0)
                y = y + b:GetHeight() + 2
            end
        end
    end
    local all = Opt.navButtons.all
    if all and all.toggle then all.toggle.fs:SetText(Opt.framesOpen and "-" or "+") end
end

-- After a change: redraw once, on the next frame (several settings can change in one click).
-- While a mouse button is down (a slider drag), wait until it is released so the drag isn't reset.
function Opt.changed()
    if Opt.pendingLayout then return end
    Opt.pendingLayout = true
    local function run()
        local down = IsMouseButtonDown and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton"))
        if down then C_Timer.After(0.05, run); return end
        Opt.pendingLayout = false
        Opt.layout()
    end
    C_Timer.After(0, run)
end

function Opt.select(id)
    if not Opt.pages[id] then id = "general" end
    -- a frame turned off has no page to show
    if UNIT_LABEL[id] and not frameOn(id) then id = "all" end
    Opt.current = id
    -- (picking a page ends a search)
    if Opt.searchBox and Opt.searchBox:GetText() ~= "" then Opt.searchBox:SetText(""); Opt.searchBox:ClearFocus() end
    Opt.closeMenu()
    Opt.layout()
end

-- The settings search, at the top of the window on every page: typing swaps the page for the
-- matching settings from every page (see layoutSearch); clearing it brings the page back.
function Opt.setQuery(text)
    local q = (text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if q == Opt.query then return end
    Opt.query = q
    Opt.closeMenu()
    Opt.scroll:SetVerticalScroll(0)
    Opt.layout()
end

function Opt.makeSearch(w, rightOf)
    local box = CreateFrame("EditBox", nil, w, "BackdropTemplate")
    box:SetSize(250, 28)
    -- (in the title bar, centred on it, left of the close button)
    box:SetPoint("RIGHT", rightOf, "LEFT", -10, 0)
    box:SetAutoFocus(false)
    box:SetFontObject(Opt.fontObject(12))
    box:SetTextInsets(28, 24, 0, 0)
    Opt.dark(box, 0.3, THEME.panel)
    -- (an accent underline while you're typing in it)
    local focus = Opt.rect(box, "ARTWORK", A, 1)
    focus:SetPoint("BOTTOMLEFT"); focus:SetPoint("BOTTOMRIGHT"); focus:SetHeight(2)
    focus:Hide()
    local glass = box:CreateTexture(nil, "OVERLAY")
    glass:SetSize(14, 14)
    glass:SetPoint("LEFT", 9, 0)
    glass:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    glass:SetVertexColor(THEME.dim[1], THEME.dim[2], THEME.dim[3])
    local hint = Opt.text(box, 12, THEME.dim)
    hint:SetPoint("LEFT", 28, 0)
    hint:SetText("Search settings")
    local clear = Opt.newX(box, 18)
    clear:SetPoint("RIGHT", -5, 0)
    clear:SetScript("OnClick", function() box:SetText(""); box:ClearFocus() end)
    clear:Hide()
    box:SetScript("OnTextChanged", function(self)
        local empty = self:GetText() == ""
        hint:SetShown(empty)
        clear:SetShown(not empty)
        Opt.setQuery(self:GetText())
    end)
    box:SetScript("OnEditFocusGained", function()
        focus:Show()
        glass:SetVertexColor(A[1], A[2], A[3])
    end)
    box:SetScript("OnEditFocusLost", function()
        focus:Hide()
        glass:SetVertexColor(THEME.dim[1], THEME.dim[2], THEME.dim[3])
    end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    Opt.searchBox = box
    return box
end

function Opt.buildWindow()
    if Opt.window then return Opt.window end
    local w = CreateFrame("Frame", "WebbyFramesOptions", UIParent, "BackdropTemplate")
    Opt.window = w
    w:Hide()
    w:SetSize(820, 600)
    local pos = WebbyFramesDB and WebbyFramesDB.optionsPos
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
        if WebbyFramesDB then WebbyFramesDB.optionsPos = { p, rp, x, y } end
    end)
    w:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 })
    w:SetBackdropBorderColor(1, 1, 1, 0.1)
    tinsert(UISpecialFrames, "WebbyFramesOptions")     -- (Esc closes it)
    -- a soft shadow round it
    for i, s in ipairs({ { 4, 0.35 }, { 10, 0.18 }, { 18, 0.08 } }) do
        local sh = Opt.rect(w, "BACKGROUND", { 0, 0, 0 }, s[2], -8 + i)
        sh:SetPoint("TOPLEFT", -s[1], s[1])
        sh:SetPoint("BOTTOMRIGHT", s[1], -s[1])
    end
    -- (the window's own fill, over the shadow)
    local fill = Opt.rect(w, "BACKGROUND", THEME.bg, 0.97, -4)
    fill:SetPoint("TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", -1, 1)

    -- the title bar: a faint glow of the accent from the left, and an accent line under it
    local BAR_H = 56
    local glow = w:CreateTexture(nil, "BACKGROUND", nil, 1)
    glow:SetPoint("TOPLEFT", 1, -1)
    glow:SetPoint("BOTTOMRIGHT", w, "TOPRIGHT", -1, -BAR_H)
    Opt.gradient(glow, "HORIZONTAL", A, 0.16, A, 0)
    local shine = w:CreateTexture(nil, "BACKGROUND", nil, 2)
    shine:SetPoint("TOPLEFT", 1, -1)
    shine:SetPoint("BOTTOMRIGHT", w, "TOPRIGHT", -1, -BAR_H)
    Opt.gradient(shine, "VERTICAL", { 1, 1, 1 }, 0, { 1, 1, 1 }, 0.04)
    local rule = w:CreateTexture(nil, "BORDER")
    rule:SetPoint("TOPLEFT", 1, -BAR_H)
    rule:SetPoint("TOPRIGHT", -1, -BAR_H)
    rule:SetHeight(1)
    Opt.gradient(rule, "HORIZONTAL", A, 0.9, A, 0.05)
    -- the logo: the web emblem, and the name stacked beside it (WEBBY large in the accent, F R A M E S
    -- small and spaced out under it)
    local logo = w:CreateTexture(nil, "ARTWORK")
    logo:SetSize(46, 46)
    logo:SetPoint("LEFT", w, "TOPLEFT", 12, -BAR_H / 2)
    logo:SetTexture(Opt.LOGO)
    local title = Opt.text(w, 19, A)
    title:SetPoint("TOPLEFT", logo, "RIGHT", 8, 16)     -- (the two lines together centred on the emblem)
    title:SetText("WEBBY")
    -- FRAMES: one letter each with the same gap between every pair, so the word starts and ends
    -- exactly under WEBBY (even gaps, not even steps: the letters aren't all as wide)
    local letters, fsList, used = { "F", "R", "A", "M", "E", "S" }, {}, 0
    for i, ch in ipairs(letters) do
        local fs = Opt.text(w, 11)
        fs:SetText(ch)
        fsList[i] = fs
        used = used + fs:GetStringWidth()
    end
    local gap = math.max(1, (title:GetStringWidth() - used) / (#fsList - 1))
    local x = 1
    for _, fs in ipairs(fsList) do
        fs:SetPoint("TOPLEFT", title, "BOTTOMLEFT", math.floor(x + 0.5), -4)
        x = x + fs:GetStringWidth() + gap
    end
    local ver = Opt.text(w, 10, THEME.dim)
    ver:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 10, 1)
    ver:SetText("v" .. addonVersion())
    local close = Opt.newX(w, 30)
    close:SetPoint("RIGHT", w, "TOPRIGHT", -14, -BAR_H / 2)
    close:SetScript("OnClick", function() w:Hide() end)
    Opt.makeSearch(w, close)
    -- Reload UI, between the name and the search (for the options that need a /reload)
    local reload = Opt.newButton(w, 104, 28, "Reload UI")
    reload:SetPoint("RIGHT", Opt.searchBox, "LEFT", -10, 0)
    reload:SetScript("OnClick", function()
        if C_UI and C_UI.Reload then C_UI.Reload() else ReloadUI() end
    end)
    Opt.tip(reload, "Reload UI", "Reloads the interface (the same as /reload), for the options that need it, like turning Webby Frames or its party frames on or off.")

    -- the page list
    local NAV_W, GAP = 172, 10
    local nav = CreateFrame("Frame", nil, w, "BackdropTemplate")
    nav:SetPoint("TOPLEFT", 14, -(BAR_H + 12))
    nav:SetPoint("BOTTOMLEFT", 14, 14)
    nav:SetWidth(NAV_W)
    Opt.dark(nav, 0.15, THEME.panel)
    Opt.navButtons = {}
    for i, id in ipairs(Opt.order) do
        local page = Opt.pages[id]
        local top = not UNIT_LABEL[id]          -- (General, All frames, Click casting...; the frames sit under All frames)
        local b = CreateFrame("Button", nil, nav)
        b:SetHeight(top and 30 or 24)
        b:SetPoint("TOPLEFT", 1, -6 - (i - 1) * 30)
        b:SetPoint("RIGHT", nav, "RIGHT", -1, 0)
        local hl = Opt.rect(b, "HIGHLIGHT", { 1, 1, 1 }, 0.05)
        hl:SetAllPoints()
        local fs = Opt.text(b, top and 12 or 11, THEME.dim)
        fs:SetPoint("LEFT", top and 16 or 28, 0)
        fs:SetText(top and page.name:upper() or page.name)
        -- (the page on show: an accent bar at its left, the accent fading out behind it, its name lit)
        -- (b.selected is an empty frame: shown / hidden by Opt.layout, it lights these up)
        local wash = b:CreateTexture(nil, "BACKGROUND")
        wash:SetAllPoints()
        Opt.gradient(wash, "HORIZONTAL", A, 0.22, A, 0)
        local bar = Opt.rect(b, "ARTWORK", A, 1)
        bar:SetPoint("TOPLEFT"); bar:SetPoint("BOTTOMLEFT"); bar:SetWidth(3)
        local sel = CreateFrame("Frame", nil, b)
        local function lit(on)
            wash:SetShown(on); bar:SetShown(on)
            local c = on and THEME.text or THEME.dim
            fs:SetTextColor(c[1], c[2], c[3])
        end
        sel:SetScript("OnShow", function() lit(true) end)
        sel:SetScript("OnHide", function() lit(false) end)
        lit(false)
        sel:Hide()
        b.selected = sel
        b:SetScript("OnClick", function()
            pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
            Opt.select(id)
        end)
        if id == "all" then
            -- the + / - that shows or folds away the frame pages under it
            local t = CreateFrame("Button", nil, b)
            t:SetSize(22, 22)
            t:SetPoint("RIGHT", -6, 0)
            local thl = Opt.rect(t, "HIGHLIGHT", { 1, 1, 1 }, 0.08)
            thl:SetAllPoints()
            t.fs = Opt.text(t, 16, THEME.dim)
            t.fs:SetPoint("CENTER", 0, 1)
            t:SetScript("OnClick", function()
                Opt.framesOpen = not Opt.framesOpen
                Opt.layoutNav()
            end)
            b.toggle = t
        end
        Opt.navButtons[id] = b
    end
    Opt.framesOpen = false
    Opt.layoutNav()

    -- the page itself, scrolling
    local area = CreateFrame("Frame", nil, w, "BackdropTemplate")
    area:SetPoint("TOPLEFT", nav, "TOPRIGHT", GAP, 0)
    area:SetPoint("BOTTOMRIGHT", -14, 14)
    Opt.dark(area, 0.15, THEME.panel)
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
    scroll:SetPoint("TOPLEFT", 4, -6)
    scroll:SetPoint("BOTTOMRIGHT", -16, 6)
    -- (the template's scroll bar, slimmed down: no arrow buttons, a thin track and a thin thumb)
    pcall(function()
        local bar = scroll.ScrollBar or _G["WebbyFramesOptionsScrollScrollBar"]
        if not bar then return end
        Opt.scrollBar = bar          -- (shown only while the page is longer than the window: Opt.layout)
        scroll.scrollBarHideable = true   -- (and the template's own range check agrees: it hides it at no range too)
        for _, r in ipairs({ bar:GetRegions() }) do if r.SetAlpha then r:SetAlpha(0) end end
        for _, k in ipairs({ "ScrollUpButton", "ScrollDownButton" }) do
            local btn = bar[k] or (bar:GetName() and _G[bar:GetName() .. k])
            if btn then btn:SetAlpha(0); btn:EnableMouse(false); btn:SetSize(1, 1) end
        end
        bar:ClearAllPoints()
        bar:SetPoint("TOPRIGHT", area, "TOPRIGHT", -5, -8)
        bar:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -5, 8)
        bar:SetWidth(6)
        local track = Opt.rect(bar, "BACKGROUND", { 1, 1, 1 }, 0.05)
        track:SetAllPoints()
        local thumb = bar:GetThumbTexture()
        if thumb then
            thumb:SetAlpha(1)
            thumb:SetColorTexture(A[1], A[2], A[3], 0.6)
            thumb:SetSize(6, 48)
        end
    end)
    Opt.scroll = scroll
    Opt.CONTENT_W = 820 - 14 - NAV_W - GAP - 14 - 4 - 16

    -- (opening: a quick fade in)
    local fade = w:CreateAnimationGroup()
    local a = fade:CreateAnimation("Alpha")
    a:SetFromAlpha(0)
    a:SetToAlpha(1)
    a:SetDuration(0.14)
    pcall(a.SetSmoothing, a, "OUT")
    -- every section starts folded each time the window opens
    w:SetScript("OnShow", function()
        fade:Stop(); fade:Play()
        for _, sec in ipairs(Opt.sections) do sec.expanded = false end
        Opt.framesOpen = false      -- (the frame pages under All frames start folded away too)
        Opt.layout()
    end)
    w:SetScript("OnHide", function() Opt.closeMenu(); GameTooltip:Hide() end)
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

-- (shared: the main file's /webby options and Edit Mode's Settings buttons open the window with it)
ns.openSettings = openSettings

function Opt.toggle()
    if Opt.window and Opt.window:IsShown() then Opt.window:Hide() else openSettings() end
end

-- Esc > Options > AddOns > Webby Frames: what the addon is, and a button to the settings window.
function Opt.buildAddOnsPage()
    local p = CreateFrame("Frame")
    p.name = "Webby Frames"
    local logo = p:CreateTexture(nil, "ARTWORK")
    logo:SetSize(48, 48)
    logo:SetPoint("TOPLEFT", 10, -8)
    logo:SetTexture(Opt.LOGO)
    local title = p:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 64, -16)
    title:SetText("Webby Frames")
    local sub = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    sub:SetText("|cff808080v" .. addonVersion() .. "  -  by Webby, Lexible and Dranged|r")
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
        Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(p, "Webby Frames"))
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
    if type(WebbyFramesDB.minimap) ~= "table" then WebbyFramesDB.minimap = { hide = false } end
    local launcher = LDB:NewDataObject("WebbyFrames", {
        type = "launcher",
        text = "Webby Frames",
        icon = Opt.LOGO,
        OnClick = function(_, button)
            if button == "RightButton" then openEditMode() else Opt.toggle() end
        end,
        OnTooltipShow = function(tt)
            if tt == GameTooltip then pcall(moveTipToDefault, tt:GetOwner()) end
            tt:AddLine("Webby Frames")
            tt:AddLine("|cffffd100Click|r to open the settings", 1, 1, 1)
            tt:AddLine("|cffffd100Right-click|r to open Edit Mode", 1, 1, 1)
            tt:AddLine("|cffffd100Drag|r to move this button", 1, 1, 1)
        end,
    })
    DBI:Register("WebbyFrames", launcher, WebbyFramesDB.minimap)
    Opt.DBI = DBI
end

function Opt.setMinimapShown(on)
    if type(WebbyFramesDB.minimap) ~= "table" then WebbyFramesDB.minimap = {} end
    WebbyFramesDB.minimap.hide = not on
    if Opt.DBI then
        if on then Opt.DBI:Show("WebbyFrames") else Opt.DBI:Hide("WebbyFrames") end
    end
end

local function buildSettings()
    -- Small builders; every setting reads and writes through a proxy table. Each adds a row to the
    -- page; the rows are only made when the page is first shown. B.section starts a collapsible
    -- section: the rows added after it only show while it is open.
    local function builders(page, proxy)
        local B = { page = page }      -- (page.rows: every row so far, for showing a run of them together)
        local current
        local L, CX, CW = Opt.LABEL_X, Opt.CONTROL_X, Opt.CONTROL_W
        local function add(row)
            -- (what the search looks through: the name, and the setting's own search words)
            local find = row.search
            for k in pairs(row.keys or {}) do
                if Opt.SEARCH_WORDS[k] then find = (find or "") .. " " .. Opt.SEARCH_WORDS[k] end
            end
            row.find = find and find:lower()
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
            local fs = Opt.text(f, 12)
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
        -- A row of your own: make(f, row) builds it (f: the row's frame); set row.refresh to redraw it.
        function B.custom(height, make)
            return add({ height = height or Opt.ROW_H, make = make })
        end
        function B.header(text)
            current = nil
            local small = text:find("^|cff808080") ~= nil
            return add({ height = small and 22 or 44, make = function(f)
                local fs = Opt.text(f, small and 11 or 17, small and THEME.dim or THEME.text)
                fs:SetPoint("BOTTOMLEFT", L, small and 4 or 14)
                fs:SetWidth(Opt.CONTENT_W - 2 * L)      -- (set, not from the row's edge: see the click page's text)
                fs:SetJustifyH("LEFT")
                fs:SetText(text)
                if not small then
                    -- (a short accent underline under a big heading)
                    local u = Opt.rect(f, "ARTWORK", A, 1)
                    u:SetSize(36, 2)
                    u:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -5)
                end
            end })
        end
        function B.section(text, open)
            local sec = { expanded = false, title = text }
            Opt.sections[#Opt.sections + 1] = sec
            current = nil
            -- (a card's top: a bar with the section's name in capitals and a chevron; the rows under it
            -- sit on the card's body, see makeRows)
            local header = add({ height = 44, make = function(f, row)
                local b = CreateFrame("Button", nil, f, "BackdropTemplate")
                b:SetPoint("TOPLEFT", 6, -8)
                b:SetPoint("BOTTOMRIGHT", -6, 0)
                Opt.dark(b, 0.2)
                local hl = Opt.rect(b, "HIGHLIGHT", { 1, 1, 1 }, 0.05)
                hl:SetAllPoints()
                local edge = Opt.rect(b, "ARTWORK", A, 1)
                edge:SetPoint("TOPLEFT"); edge:SetPoint("BOTTOMLEFT"); edge:SetWidth(3)
                local fs = Opt.text(b, 12)
                fs:SetPoint("LEFT", 16, 0)
                fs:SetText(text:upper())
                local chev = Opt.chevron(b, 14)
                chev:SetPoint("RIGHT", -12, 0)
                b:SetScript("OnClick", function()
                    sec.expanded = not sec.expanded
                    pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
                    Opt.layout()
                end)
                row.refresh = function()
                    -- open: the accent edge lit, the name white, the chevron down; shut: dimmed, pointing right
                    local open = sec.expanded or (Opt.query or "") ~= ""
                    edge:SetAlpha(open and 1 or 0.25)
                    local c = open and THEME.text or THEME.dim
                    fs:SetTextColor(c[1], c[2], c[3])
                    chev:SetRotation(open and 0 or math.rad(90))
                    b:SetBackdropColor(THEME.raised[1], THEME.raised[2], THEME.raised[3], open and 1 or 0.7)
                end
            end })
            sec.header = header
            current = sec
            return header      -- (so a whole section can be shown only sometimes: B.showIf)
        end
        -- (kind and keys: what the search's "not in use" notes say about a row, Opt.whyOff)
        function B.check(key, text, tip, default)
            return add({ search = text, tip = tip, kind = "switch", keys = { [key] = true }, make = function(f, row)
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
            return add({ search = a[2] .. (b and (" / " .. b[2]) or ""), tip = (a[3] or "") .. " " .. (b and b[3] or ""),
                -- (the search can show just the half that matches, by its name or its search words)
                halves = b and { a[2] .. " " .. (Opt.SEARCH_WORDS[a[1]] or ""), b[2] .. " " .. (Opt.SEARCH_WORDS[b[1]] or "") } or nil,
                kind = "switch", keys = { [a[1]] = true, [b and b[1] or a[1]] = true }, make = function(f, row)
                row.controls, row.texts = {}, {}
                local boxes = {}
                -- (the first switch where the other rows' names start, so it lines up with them; the second
                -- at the controls' column, with the other rows' controls)
                local firstX = L + 20 + 18 * (row.indent or 0)
                for i, d in ipairs({ a, b }) do
                    local cb = Opt.newCheck(f)
                    cb:SetPoint("LEFT", i == 1 and firstX or CX, 0)
                    local fs = Opt.text(f, 12)
                    fs:SetPoint("LEFT", cb, "RIGHT", 10, 0)
                    fs:SetText(d[2])
                    cb:SetScript("OnClick", function(self) set(d[1], self:GetChecked() and true or false, true) end)
                    Opt.tip(cb, d[2], d[3])
                    row.controls[#row.controls + 1] = cb
                    row.texts[#row.texts + 1] = fs
                    boxes[#boxes + 1] = { cb, d, fs }
                end
                row.refresh = function()
                    for _, x in ipairs(boxes) do x[1]:SetChecked(get(x[2][1], x[2][4]) and true or false) end
                end
                -- Both halves (which = nil), or just one, moved to the left (a search matching only it).
                row.only = function(which)
                    for i, x in ipairs(boxes) do
                        local show = not which or which == i
                        x[1]:SetShown(show); x[3]:SetShown(show)
                        x[1]:ClearAllPoints()
                        x[1]:SetPoint("LEFT", (i == 1 or which) and firstX or CX, 0)
                    end
                end
            end })
        end
        -- A colour row: label and a swatch of the colour, which opens the colour picker when clicked.
        -- getc() -> { r, g, b }; setc(r, g, b).
        function B.swatch(text, getc, setc, tip)
            return add({ search = text, tip = tip, make = function(f, row)
                label(f, row, text, tip)
                local b = CreateFrame("Button", nil, f, "BackdropTemplate")
                b:SetSize(36, 18)
                b:SetPoint("LEFT", CX, 0)
                Opt.dark(b, 0.6)
                b:SetBackdropColor(0, 0, 0, 1)
                Opt.outline(b, "HIGHLIGHT", A, 1)
                local tex = b:CreateTexture(nil, "ARTWORK")
                tex:SetPoint("TOPLEFT", 2, -2)
                tex:SetPoint("BOTTOMRIGHT", -2, 2)
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
            return add({ search = text, tip = tip, keys = { [key] = true }, make = function(f, row)
                label(f, row, text, tip)
                local s = CreateFrame("Slider", nil, f, "BackdropTemplate")
                s:SetOrientation("HORIZONTAL")
                s:SetSize(150, 18)
                s:SetPoint("LEFT", CX + 23, 0)      -- (so the - button, 18 px and a 5 px gap to its left, starts on the controls' column)
                -- (a thin track, the accent filling it up to a slim white thumb)
                local track = Opt.rect(s, "BACKGROUND", { 1, 1, 1 }, 0.1)
                track:SetPoint("LEFT"); track:SetPoint("RIGHT"); track:SetHeight(4)
                local thumb = Opt.rect(s, "OVERLAY", THEME.text, 1)
                thumb:SetSize(6, 16)
                s:SetThumbTexture(thumb)
                local filled = Opt.rect(s, "ARTWORK", A, 1)
                filled:SetPoint("LEFT", track, "LEFT")
                filled:SetPoint("RIGHT", thumb, "CENTER")
                filled:SetHeight(4)
                s:SetMinMaxValues(lo, hi)
                s:SetValueStep(step)
                pcall(s.SetObeyStepOnDrag, s, true)
                local val = Opt.text(f, 11, THEME.text)
                local function stepper(dir)
                    local b = Opt.newButton(f, 18, 18, dir < 0 and "-" or "+")
                    b:GetFontString():SetPoint("LEFT", 0, 1)
                    b:GetFontString():SetPoint("RIGHT", 0, 1)
                    b:SetScript("OnMouseDown", nil)
                    b:SetScript("OnMouseUp", nil)
                    b:SetScript("OnClick", function() s:SetValue(snap(s:GetValue() + dir * step)) end)
                    return b
                end
                local prev, nxt = stepper(-1), stepper(1)
                prev:SetPoint("RIGHT", s, "LEFT", -5, 0)
                nxt:SetPoint("LEFT", s, "RIGHT", 5, 0)
                val:SetPoint("LEFT", nxt, "RIGHT", 8, 0)
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
                    r.preds[#r.preds + 1] = isOn      -- (hidden while it doesn't apply, not just greyed)
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
            return add({ search = text, tip = tip, keys = { [key] = true }, make = function(f, row)
                label(f, row, text, tip)
                local b = CreateFrame("Button", nil, f, "BackdropTemplate")
                b:SetSize(CW, 26)
                b:SetPoint("LEFT", CX, 0)
                Opt.styleField(b)
                local arrow = Opt.chevron(b, 14)
                arrow:SetPoint("RIGHT", -8, 0)
                local fs = Opt.text(b, 12)
                fs:SetPoint("LEFT", 10, 0)
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
            return add({ search = text, tip = tip, make = function(f, row)
                label(f, row, text, tip)
                local b = Opt.newButton(f, 180, 26, buttonText)
                b:SetPoint("LEFT", CX, 0)
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
            return B.dropdown("auraGrowth", "Rows grow", "To the right: the first icon at the left end. To the left: the first icon at the right end, with the row filling leftwards.", "right",
                { { "right", "To the right" }, { "left", "To the left" } }),
            B.slider("auraGap", "Icon spacing", "Space between the icons.", 2, 0, 10, 1, function(v) return string.format("%d px", math.floor(v + 0.5)) end),
            B.slider("auraStack", "Stack count size", "How big the stack count is, as a share of the icon.", 50, 30, 90, 5,
                function(v) return string.format("%d%%", math.floor(v + 0.5)) end)
        end
        -- Fade to red with its style and custom stops. read: whose settings to show; set(unit, key, value).
        -- Fade to red, with its colours and (only while those are your own) the three stops; each part
        -- shows only while what it depends on is on. read: whose settings to show; set(unit, key, value).
        function B.fade(read, set, tip)
            local fade = B.check("healthFade", "Fade to red as health drops", tip, false)
            local function fadeOn() return getSetting(read, "healthFade") and true or false end
            local style = B.dropdown("fadeStyle", "Fade colours", "Automatic: the colour turns to red round the colour wheel (shamans, mages and warlocks each have their own route), fully red from 25% health.\n\nCustom: up to three colour stops, each at a health % you choose.", "auto",
                { { "auto", "Automatic" }, { "custom", "Custom" } })
            B.under(fade, fadeOn, style)
            B.showIf(fadeOn, style)
            local function custom() return fadeOn() and getSetting(read, "fadeStyle") == "custom" end
            Opt.predNotes[custom] = "Needs Fade to red on, with Fade colours set to Custom."
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
                if k == "enabled" or k == "combatNumbers" then return WebbyFramesDB[k] ~= false end
                if k == "minimapButton" then return not (type(WebbyFramesDB.minimap) == "table" and WebbyFramesDB.minimap.hide) end
                local unit = k:match("^show_(.+)$")
                if unit then return frameOn(unit) end
            end,
            __newindex = function(_, k, v)
                if k == "enabled" or k == "combatNumbers" then WebbyFramesDB[k] = v and true or false; return end
                if k == "minimapButton" then Opt.setMinimapShown(v); return end
                local unit = k:match("^show_(.+)$")
                if unit then setSetting(unit, "frameShown", v and true or false) end
            end,
        })
        local B = builders(Opt.newPage("general", "General"), general)
        B.header("Webby Frames  |cff808080v" .. addonVersion() .. "  -  by Webby, Lexible and Dranged|r")
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
        B.pair({ "show_party", "Party", "Show the party frames (and hide Blizzard's). Turned off, Blizzard's party frames come back after a /reload.", true })
        B.button("Position", "Open Edit Mode", openEditMode, "Drag the frames where you want them. They snap to each other and to the middle of the screen, and a frame dropped next to another moves with it.")
        B.button("Reset", "Reset all frames", function()
            for _, unit in ipairs(UNITS) do resetFrame(unit) end
        end, "Puts every frame back to its default options and position, for the current Edit Mode layout.")

        B.header("Profiles")
        B.button("Export", "Export profile", function() Profiles.show("export") end,
            "Every frame's options and position in this Edit Mode layout, as text you can copy and keep or share.")
        B.button("Import", "Import profile", function() Profiles.show("import") end,
            "Paste a profile exported here or on another character. It replaces this layout's options and positions.")

        B.header("Pick a frame on the left for its own options.")
        B.header("|cff808080Options are saved per Edit Mode layout.  /webby help lists the commands.|r")
    end

    -- one page per frame ---------------------------------------------------------
    local fontList = function() local l = {}; for _, c in ipairs(fontChoices()) do l[#l + 1] = { c[1], c[2] } end; return l end

    -- All frames: the options most people want the same everywhere, set on every frame at once. It shows
    -- the player frame's choice; changing it sets every frame (each frame's page can still differ after).
    do
        local function setAll(_, k, v)
            for _, unit in ipairs(UNITS) do
                -- (the party's class colour is each member's own: "theirclass")
                if unit == "party" and k == "frameTint" and v == "class" then setSetting(unit, k, "theirclass")
                else setSetting(unit, k, v) end
            end
            -- Health colour: the pet and the party's raid-style tiles have their own choices; they follow
            -- as closely as they can (the pet: Default, or the player frame's colour; the tiles: Default,
            -- Dark, or class colour)
            if k == "colorMode" then
                if v == "smart" or v == "reaction" then setSetting("party", "colorMode", "class") end
                setSetting("pet", "petColor", v == "plain" and "plain" or "player")
                if v == "dark" then setSetting("party", "rpHealthColor", "dark")
                elseif v == "plain" then setSetting("party", "rpHealthColor", "default")
                else setSetting("party", "rpHealthColor", "class") end
            end
        end
        local proxy = setmetatable({}, {
            __index = function(_, k) return getSetting("player", k) end,
            __newindex = setAll,
        })
        local B = builders(Opt.newPage("all", "All frames"), proxy)
        B.header("|cff808080Changes here apply to every frame. Each frame's own page can then differ.|r")

        -- (the same sections, in the same order, as each frame's page)
        B.section("Frame", false)
        B.dropdown("frameTint", "Frame colour", "Colours the frame art on every frame. Class colour: your class on the player and pet frames, the class of whoever the others show (NPCs stay gold; each party member in their own). The player's resting glow takes the colour too.", "default",
            { { "default", "Gold" }, { "class", "Class colour" }, { "custom", "Custom" } })
        B.showIf(function() return getSetting("player", "frameTint") == "custom" end,
            B.swatch("Custom frame colour", function() return Extras.tintColor("player") or { 1, 1, 1 } end,
                function(r, g, b) setAll(nil, "frameColor", { r, g, b }) end, "The colour for every frame's art. Click to change it."))
        B.dropdown("portraitStyle", "Portrait", "The unit's picture, or for players their class icon (NPCs keep their picture).", "picture",
            { { "picture", "Picture" }, { "class", "Class icon (players)" } })

        B.section("Health and power", false)
        B.dropdown("barTexture", "Health bar texture", "Every frame's health bar fill (and cast bar and heal / shield overlays).", "default", textureChoices)
        B.dropdown("powerTexture", "Power bar texture", "Every frame's mana, rage or energy fill.", "default", textureChoices)
        B.dropdown("font", "Font", "For the names and bar numbers on every frame.", "default", fontList)
        local numbers = B.dropdown("textMode", "Numbers", "When the bars show their numbers, on every frame.", "always",
            { { "always", "Always" }, { "mouseover", "On mouseover" }, { "off", "Never" } })
        B.under(numbers, function() return getSetting("player", "textMode") ~= "off" end,
            B.dropdown("textFormat", "Number format", "Totals, percentages, or both.", "value",
                { { "value", "12.3K" }, { "percent", "85%" }, { "both", "12.3K (85%)" } }))

        local colour = B.dropdown("colorMode", "Health colour", "Every frame's health colour at once (the pet and the party's raid-style tiles follow as closely as their own choices allow). Each frame's page can then differ.", "smart", COLOR_MODES)
        local function byReaction() local m = getSetting("player", "colorMode"); return m == "smart" or m == "reaction" end
        local npc = B.dropdown("npcColor", "Enemy NPC colour", "The health colour for hostile NPCs on every frame. Green lets Fade to red show their health dropping. Neutral NPCs stay yellow.", "reaction",
            { { "reaction", "Red" }, { "green", "Green" }, { "custom", "Custom" } })
        local npcCustom = B.swatch("Custom NPC colour", function()
            local c = getSetting("target", "npcColorRGB")
            return type(c) == "table" and c or { 0.1, 0.8, 0.1 }
        end, function(r, g, b) setAll(nil, "npcColorRGB", { r, g, b }) end, "The health colour for hostile NPCs on every frame. Click to change it.")
        B.under(colour, byReaction, npc)
        B.under(npc, function() return byReaction() and getSetting("target", "npcColor") == "custom" end, npcCustom)
        B.fade("player", setAll, "As health drops, each frame's health colour shifts towards red (or through your own stops).")
        B.pair({ "healPrediction", "Incoming heals", "Heals on their way, in green past the end of the health.", true },
               { "absorbs", "Shields and heal absorbs", "Damage shields and healing absorbs on the health bars.", true })
        B.pair({ "damageTrail", "Recent damage", "When health drops, the part just lost stays in red for a moment, then slides away.", true })

        B.section("Buffs and debuffs", false)
        local dispel = B.check("dispelGlow", "Dispel glow", "On every frame: when the unit has a debuff you can dispel, the frame takes the debuff type's colour and pulses.", true)
        B.under(dispel, function() return getSetting("player", "dispelGlow") and true or false end,
            B.dropdown("dispelWho", "Glow for", "Debuffs you can dispel yourself, or any debuff someone could dispel, on every frame.", "mine",
                { { "mine", "Ones I can dispel" }, { "all", "Any dispellable" } }))
        B.dropdown("auraTimer", "Time left", "How each icon shows the time it has left, on every frame.", "both",
            { { "both", "Sweep and numbers" }, { "swipe", "Sweep" }, { "numbers", "Numbers" }, { "none", "Nothing" } })
        B.auraDetails()
    end

    -- The Party page: laid out on its own, as the party has two styles (portrait frames, raid-style tiles)
    -- with their own options. Grouped by what they're about; each style's version of an option sits in
    -- the same spot, and options for the other style hide.
    --   Style and layout: the style, where and how big, who's in it, a sample party
    --   Members: what each member shows and how they behave
    --   Health and power: textures, font, numbers, colours, shields
    --   Buffs and debuffs: the dispel glow, defensives, icons
    local function partyPage(B)
        local function get(k) return getSetting("party", k) end
        local function on(k) return function() return get(k) and true or false end end
        local raid = function() return get("partyStyle") == "raid" end
        local portrait = function() return not raid() end
        -- (the search's notes for settings of the style not in use)
        Opt.predNotes[raid] = "Raid style only (Style and layout > Style)."
        Opt.predNotes[portrait] = "Portrait frames only (Style and layout > Style)."
        local function both(a, b)
            local fn = function() return a() and b() end
            Opt.predParts[fn] = { a, b }
            return fn
        end
        local px = function(v) return string.format("%d px", math.floor(v + 0.5)) end
        local whole = function(v) return string.format("%d", math.floor(v + 0.5)) end
        local pct = function(v) return string.format("%d%%", math.floor(v + 0.5)) end
        local swatch = function(key, text, tip, fallback)
            return B.swatch(text, function() local c = get(key); return type(c) == "table" and c or fallback end,
                function(r, g, b) setSetting("party", key, { r, g, b }) end, tip)
        end

        -- Style and layout ----------------------------------------------------------------
        B.section("Style and layout")
        B.pair({ "frameShown", "Show party frames", "Turned off, Blizzard's party frames come back after a /reload. Also on the General page.", true })
        B.dropdown("partyStyle", "Style", "Portrait frames: like your own frame, with portraits. Raid style: flat tiles like Blizzard's raid-style party frames. The raid style is placed in Edit Mode on its own.", "portrait",
            { { "portrait", "Portrait frames" }, { "raid", "Raid style" } })
        B.button("Preview", "Sample party on / off", function() Party.toggleSamples() end,
            "Made-up party members on your party frames, to see your options without a group. The raid style shows it in Edit Mode too. Combat ends it. Also /webby party.")
        B.slider("scale", "Scale", "How big the party frames are.", defaultFor("party", "scale"), 0.5, 2, 0.05)
        B.dropdown("partyLayout", "Layout", "Stacked: one under the other. Side by side: in a row.", "vertical",
            { { "vertical", "Stacked" }, { "horizontal", "Side by side" } })
        B.dropdown("partySort", "Order", "As in your group, or by role: tanks, then healers, then damage. (A change in combat waits for it to end.)", "group",
            { { "group", "As in your group" }, { "role", "By role" } })
        B.showIf(portrait,
            B.slider("partyGap", "Spacing", "The gap between party members. With buffs and debuffs below the frames, leave room for them (about 20 px a row).", defaultFor("party", "partyGap"), 0, 60, 1, px))
        B.showIf(raid,
            B.slider("rpWidth", "Tile width", "How wide each tile is.", defaultFor("party", "rpWidth"), 60, 200, 1, px),
            B.slider("rpHeight", "Tile height", "How tall each tile is.", defaultFor("party", "rpHeight"), 30, 100, 1, px),
            B.slider("rpGap", "Spacing", "The gap between tiles.", defaultFor("party", "rpGap"), 0, 20, 1, px))
        local me = B.check("rpSelf", "Include yourself", "You as one of the tiles, as Blizzard's raid-style party frames do.", true)
        local solo = B.check("rpSolo", "Show when solo", "The tiles stay up when you're not in a group (just you).", false)
        B.under(me, on("rpSelf"), solo)
        B.showIf(raid, me, solo)

        -- Members -------------------------------------------------------------------------
        B.section("Members", false)
        B.pair({ "showName", "Show names", "Each member's name.", true })
        B.showIf(portrait,
            B.dropdown("portraitStyle", "Portrait", "Each member's picture, or their class icon.", "picture",
                { { "picture", "Picture" }, { "class", "Class icon" } }),
            B.dropdown("frameTint", "Frame colour", "Colours each member's frame art: its border and portrait ring. Their class colour: each member in their own class's colour. Custom: one colour of your own.", "default",
                { { "default", "Gold" }, { "theirclass", "Their class colour" }, { "custom", "Custom" } }))
        B.showIf(both(portrait, function() return get("frameTint") == "custom" end),
            B.swatch("Custom frame colour", function() return Extras.tintColor("party") or { 1, 1, 1 } end,
                function(r, g, b) setSetting("party", "frameColor", { r, g, b }) end, "The colour for every member's frame art. Click to change it."))
        B.showIf(portrait,
            B.check("partyPets", "Pets", "Each member's pet, as a small party frame under theirs.", true))
        B.showIf(raid,
            B.dropdown("rpNameColor", "Name colour", "White, or each member's class colour.", "white", { { "white", "White" }, { "class", "Class colour" } }),
            B.dropdown("rpNamePos", "Name position", "Where the name sits on the tile.", "topleft", { { "topleft", "Top left" }, { "top", "Top" }, { "center", "Middle" } }),
            B.slider("rpNameMax", "Name length", "The most letters of a name shown (0: all of it).", defaultFor("party", "rpNameMax"), 0, 20, 1,
                function(v) v = math.floor(v + 0.5); return v == 0 and "All" or string.format("%d", v) end),
            B.pair({ "rpAFK", "Show AFK", "Away members say AFK on their tile.", true },
                   { "rpHoverEdge", "Edge on mouseover", "A light edge round the tile under your mouse, like the white one round your target.", true }))
        local rpPets = B.check("rpPets", "Pets", "The group's pets as their own group of tiles, as wide as the members' and in their owners' order, with no gaps for members without one.", false)
        local petOpts = {
            B.dropdown("rpPetPos", "Pet group", "After the party: on down the stack (or on along the row when side by side), like Blizzard's raid frames.\nBeside the party: a column to the right of the stack (or a row under it when side by side).", "after",
                { { "after", "After the party" }, { "beside", "Beside the party" } }),
            B.slider("rpPetHeight", "Pet height", "How tall each pet tile is (never taller than the members').", defaultFor("party", "rpPetHeight"), 14, 60, 1, px),
        }
        B.under(rpPets, on("rpPets"), unpack(petOpts))
        B.showIf(raid, rpPets, unpack(petOpts))
        B.pair({ "missingBuffs", "Missing buffs", "On each member, the icons of buffs they're missing that you can cast: Fortitude, Spirit, Mark of the Wild, Arcane Intellect, Thorns on tanks, and a paladin blessing chosen by their role. Checked out of combat.", true },
               { "healerMana", "Healer mana", "A small list of your group's healers and their mana, placed in Edit Mode (Webby Healer Mana).", false })
        local fade = B.check("rangeFade", "Fade when out of range", "Members too far away for your spells fade out.", true)
        B.under(fade, on("rangeFade"),
            B.slider("rangeAlpha", "Out of range opacity", "How much of a member still shows while out of range: lower fades them more.", defaultFor("party", "rangeAlpha"), 0.1, 0.9, 0.05))
        B.dropdown("partyTooltip", "Tooltips", "When hovering a party member shows their tooltip.", "always",
            { { "always", "Always" }, { "ooc", "Out of combat" }, { "never", "Never" } })

        -- Health and power ----------------------------------------------------------------
        B.section("Health and power", false)
        B.dropdown("barTexture", "Health bar texture", "The health bar's fill (and the incoming heal and shield overlays). SharedMedia textures are listed too.", "default", textureChoices)
        B.dropdown("powerTexture", "Power bar texture", "The mana, rage or energy bar's fill, coloured by power type. Chosen separately from the health bar texture.", "default", textureChoices)
        B.dropdown("font", "Font", "For the names and the numbers. SharedMedia fonts are listed too.", "default", fontList)
        local numbers = B.dropdown("textMode", "Numbers", "When the health and mana numbers show. On mouseover: while the mouse is over the member.",
            defaultFor("party", "textMode"), { { "always", "Always" }, { "mouseover", "On mouseover" }, { "off", "Never" } })
        B.under(numbers, function() return get("textMode") ~= "off" end,
            B.dropdown("textFormat", "Number format", "Totals, percentages, or both.",
                defaultFor("party", "textFormat"), { { "value", "12.3K" }, { "percent", "85%" }, { "both", "12.3K (85%)" } }))
        -- (colours: each style has its own)
        -- (party members are players: no reaction or NPC choices. An older "class for players, reaction
        -- for NPCs" or "by reaction" shows, and works, as Class colour.)
        local u = ns.unitData("party")
        if u and (u.colorMode == "smart" or u.colorMode == "reaction") then u.colorMode = "class" end
        -- (the same choices in both styles; the portrait frames keep theirs in colorMode, the tiles in
        -- rpHealthColor)
        B.showIf(portrait,
            B.dropdown("colorMode", "Health colour", "Default: the bar as the game draws it. Class colour: each member in their class's colour. Dark: a flat dark bar. Custom: a colour of your own. By health: green to yellow to red as health drops.", "class",
                { { "plain", "Default" }, { "class", "Class colour" }, { "dark", "Dark" }, { "custom", "Custom" }, { "gradient", "By health" } }))
        B.showIf(both(portrait, function() return get("colorMode") == "custom" end),
            swatch("healthColorRGB", "Custom health colour", "The health colour for every member. Click to change it.", { 0.15, 0.75, 0.25 }))
        B.showIf(raid,
            B.dropdown("rpHealthColor", "Health colour", "Default: Blizzard's raid-frame green. Class colour; Dark: dark bars with the missing part in their class colour; a colour of your own; or green to yellow to red as health drops.", "class",
                { { "default", "Default" }, { "class", "Class colour" }, { "dark", "Dark" }, { "custom", "Custom" }, { "gradient", "By health" } }))
        B.showIf(both(raid, function() return get("rpHealthColor") == "custom" end),
            swatch("rpHealthCustom", "Custom health colour", "The health colour for every tile. Click to change it.", { 0.15, 0.75, 0.25 }))
        B.showIf(both(raid, function() local m = get("rpHealthColor"); return m ~= "dark" and m ~= "gradient" end),
            B.slider("rpMissingDark", "Missing health shade", "How much darker the missing part of the bar is than the health.", defaultFor("party", "rpMissingDark"), 0, 100, 5, pct))
        local fadeFrom = #B.page.rows
        B.fade("party", setSetting, "As health drops, the health colour shifts towards red, or through your own stops.")
        -- (By health already is a fade: Fade to red only for the other colours)
        B.showIf(both(portrait, function() return get("colorMode") ~= "gradient" end), unpack(B.page.rows, fadeFrom + 1))
        B.showIf(portrait,
            B.slider("hpAlpha", "Health bar opacity", "How solid the health fill is.", defaultFor("party", "hpAlpha"), 0.2, 1, 0.05),
            B.slider("mpAlpha", "Power bar opacity", "How solid the mana, rage or energy fill is.", defaultFor("party", "mpAlpha"), 0.2, 1, 0.05),
            B.pair({ "healPrediction", "Incoming heals", "Heals on their way, in green past the end of the health.", true },
                   { "absorbs", "Shields and heal absorbs", "Damage shields past the end of the health, and healing absorbs eating back into it.", true }),
            B.pair({ "damageTrail", "Recent damage", "When health drops, the part just lost stays in red for a moment, then slides away.", true }))
        B.showIf(raid,
            B.pair({ "rpPowerTank", "Tank power bars", "A slim power bar along the bottom of tanks' tiles.", true },
                   { "rpPowerHealer", "Healer power bars", "A slim mana bar along the bottom of healers' tiles.", true }),
            B.pair({ "rpPowerDPS", "Damage power bars", "A slim power bar along the bottom of damage dealers' tiles (and anyone with no role).", false }),
            B.dropdown("rpShieldStyle", "Shield look", "Shields (absorbs) as Blizzard's stripes, or a plain white overlay.", "striped", { { "striped", "Striped" }, { "plain", "Plain" } }),
            B.pair({ "rpShieldEdge", "Shields from the right", "Shields drawn from the right edge over the health, so a member at full health still shows theirs. Off: straight after the health.", false }),
            swatch("rpDeadColor", "Dead colour", "The tile's colour while a member is dead or a ghost.", { 0.3, 0.1, 0.1 }),
            swatch("rpOfflineColor", "Offline colour", "The tile's colour while a member is offline.", { 0.35, 0.35, 0.35 }))

        -- Buffs and debuffs ---------------------------------------------------------------
        B.section("Buffs and debuffs", false)
        local dispel = B.check("dispelGlow", "Dispel glow", "When a member has a debuff you can dispel, their frame takes its colour (magic blue, curse purple, disease brown, poison green) and pulses.", true)
        B.under(dispel, on("dispelGlow"),
            B.dropdown("dispelWho", "Glow for", "Debuffs you can dispel yourself, or any debuff someone could dispel.", "mine",
                { { "mine", "Ones I can dispel" }, { "all", "Any dispellable" } }))
        local look = B.dropdown("rpDispelStyle", "Dispel look", "How it shows on the tile, in the debuff type's colour, pulsing: a tint rising from the bottom, a flat tint, or just the coloured edge.", "gradient",
            { { "gradient", "Gradient" }, { "fill", "Flat tint" }, { "edge", "Edge only" } })
        local typeIcon = B.check("rpDispelIcon", "Dispel type icon", "The debuff type's icon (magic, curse, disease, poison) on the right of the tile.", true)
        B.under(dispel, on("dispelGlow"), look, typeIcon)
        B.showIf(raid, look, typeIcon)
        local defs = B.check("rpDefensives", "Big defensives", "Big defensive cooldowns (Shield Wall, Divine Shield, Pain Suppression, Ice Block, Barkskin and more) as a large icon in the middle of the tile.", true)
        local defSize = B.slider("rpDefSize", "Size", "How big the defensive cooldown icon is.", defaultFor("party", "rpDefSize"), 12, 32, 1, px)
        B.under(defs, on("rpDefensives"), defSize)
        B.showIf(raid, defs, defSize)
        -- (the tiles' own two rows of icons, each on or off, and their size)
        local rpAuras = B.pair({ "rpDebuffs", "Debuffs", "Each member's debuffs, at the bottom left of their tile, the ones that matter most first.", true },
                               { "rpBuffs", "Buffs", "Each member's buffs from you (your heals over time, shields), at the bottom right of their tile, as Blizzard's raid frames show them.", true })
        local rpSize = B.slider("rpAuraSize", "Icon size", "Their debuffs and buffs. New sizes show on new icons; /reload for all of them.", defaultFor("party", "rpAuraSize"), 10, 24, 1, px)
        B.showIf(raid, rpAuras)
        B.showIf(both(raid, function() return get("rpDebuffs") ~= false or get("rpBuffs") ~= false end), rpSize)
        -- (the portrait frames' buffs and debuffs, as on the other frames)
        local function anyAuras() return portrait() and (get("auraBuffs") or get("auraDebuffs")) and true or false end
        Opt.predParts[anyAuras] = { portrait }
        Opt.predNotes[anyAuras] = "Needs Buffs or Debuffs turned on."
        local buffs = B.check("auraBuffs", "Buffs", "Each member's buffs, as icons by their frame.", defaultFor("party", "auraBuffs"))
        local buffOpts = {
            B.dropdown("auraStyle", "Buffs shown", "Retail: only the buffs you put on them (your heals over time, shields).\nEverything: all their buffs.", defaultFor("party", "auraStyle"),
                { { "retail", "Retail" }, { "all", "Everything" } }),
            B.slider("auraSize", "Size", "How big the buff icons are.", defaultFor("party", "auraSize"), 12, 40, 1, px),
        }
        B.under(buffs, on("auraBuffs"), unpack(buffOpts))
        local debuffs = B.check("auraDebuffs", "Debuffs", "Each member's debuffs, as icons by their frame, the ones that matter most first.", defaultFor("party", "auraDebuffs"))
        local debuffOpts = {
            B.slider("auraDebuffSize", "Size", "How big the debuff icons are.", defaultFor("party", "auraSize"), 12, 40, 1, px),
            B.check("auraMine", "Only mine", "Only the debuffs you applied.", false),
            B.check("auraMineBig", "Bigger own debuffs", "Your own debuffs first and bigger, so you can keep track of them.", false),
        }
        B.under(debuffs, on("auraDebuffs"), unpack(debuffOpts))
        B.showIf(portrait, buffs, debuffs, unpack(buffOpts))
        B.showIf(portrait, unpack(debuffOpts))
        B.showIf(anyAuras,
            B.dropdown("auraPos", "Position", "Where the icons sit. Right of the frame: two rows beside it, at most a row of buffs and a row of debuffs (the ones that matter first), so nothing spills over the next member. With \"Drag in Edit Mode\", Edit Mode shows a blue box for them: drag it anywhere.", defaultFor("party", "auraPos"),
                { { "side", "Right of the frame" }, { "below", "Below the frame" }, { "above", "Above the frame" }, { "custom", "Drag in Edit Mode" } }))
        B.showIf(both(anyAuras, function() return get("auraPos") == "custom" end),
            B.button("Move", "Open Edit Mode", openEditMode, "Drag the buffs and debuffs box."))
        B.showIf(anyAuras,
            B.slider("auraPerRow", "Per row", "How many icons fit on a row before the next one starts.", defaultFor("party", "auraPerRow"), 1, 16, 1, whole),
            B.slider("auraMax", "Most shown", "How many buffs, and how many debuffs, can show at once.", defaultFor("party", "auraMax"), 1, 32, 1, whole))
        -- (both styles' icons)
        B.dropdown("auraTimer", "Time left", "How each icon shows the time it has left: a dark sweep across the icon, countdown numbers, or both.", "both",
            { { "both", "Sweep and numbers" }, { "swipe", "Sweep" }, { "numbers", "Numbers" }, { "none", "Nothing" } })
        local grow, gap, stack = B.auraDetails()
        B.showIf(anyAuras, grow, gap)

        -- Reset ---------------------------------------------------------------------------
        B.section("Reset and copy", false)
        B.button("Copy", "Copy from player", function() copySettings("player", "party") end,
            "Gives the party frames the player frame's options. Their position doesn't change.")
        B.button("Reset", "Reset the party frames", function() resetFrame("party") end,
            "Puts the party frames back to their default options and position, for the current Edit Mode layout.")
    end

    -- A frame's page (player, target, target of target, focus, focus target, pet): the same sections in
    -- the same order on every one, each option under what it depends on and hidden while that's off.
    --   Frame: shown, size, name, portrait, frame colour and this frame's own touches
    --   Health and power: textures, font, numbers, colours, heals and shields, spell costs
    --   Buffs and debuffs: the dispel glow, the icons and where they sit, your weapon enchants and timer bars
    --   Cast bar and threat (target and focus)
    --   Reset and copy
    local function framePage(B, unit)
        local function get(k) return getSetting(unit, k) end
        local function isOn(k) return function() return get(k) and true or false end end
        local function both(a, b)
            local fn = function() return a() and b() end
            Opt.predParts[fn] = { a, b }
            return fn
        end
        local px = function(v) return string.format("%d px", math.floor(v + 0.5)) end
        local whole = function(v) return string.format("%d", math.floor(v + 0.5)) end
        local myClass = select(2, UnitClass("player"))
        local isPlayer, isPet = unit == "player", unit == "pet"

        -- Frame ---------------------------------------------------------------------------
        B.section("Frame")
        if not ALWAYS_SHOWN[unit] then
            B.pair({ "frameShown", "Show this frame", "Turned off, the frame stays hidden, in Edit Mode too. Also on the General page.", true })
        end
        B.slider("scale", "Scale", "How big the frame is.", defaultFor(unit, "scale"), 0.5, 2, 0.05)
        if not isPlayer then   -- (your own name always shows)
            B.pair({ "showName", "Show name", "The unit's name above its health bar.", true })
        end
        if not isPet then      -- (a pet has no class: it always shows its picture)
            B.dropdown("portraitStyle", "Portrait", "The unit's picture, or for players their class icon (NPCs keep their picture).", "picture",
                { { "picture", "Picture" }, { "class", "Class icon (players)" } })
        end
        local tint = B.dropdown("frameTint", "Frame colour", "Colours the frame art: its border, portrait ring, corner accent, level circle and cast bar border. "
            .. ((isPlayer or isPet) and "Class colour is your class's colour." or "Class colour is the class of whoever the frame shows (NPCs stay gold).")
            .. (isPlayer and " The resting glow takes the colour too." or ""), "default",
            { { "default", "Gold" }, { "class", "Class colour" }, { "custom", "Custom" } })
        local custom = B.swatch("Custom frame colour", function() return Extras.tintColor(unit) or { 1, 1, 1 } end,
            function(r, g, b) setSetting(unit, "frameColor", { r, g, b }) end, "The colour for the frame art. Click to change it.")
        B.under(tint, function() return get("frameTint") == "custom" end, custom)
        if isPlayer then
            local zzz = B.check("restTint", "Zzz in frame colour", "The resting Zzz by the portrait takes the frame colour.", false)
            B.under(tint, function() return get("frameTint") ~= "default" end, zzz)
            B.dropdown("cornerStyle", "Corner accent", "The gold corner at the portrait's bottom right: Retail's pointed one, or Forever's older rounder one.", "retail",
                { { "retail", "Retail" }, { "forever", "Forever" } })
        end
        if unit == "target" and (myClass == "ROGUE" or myClass == "DRUID") then
            B.check("comboPoints", "Combo points", "Your combo points in an arc round the target's portrait" .. (myClass == "DRUID" and ", while you're in cat form." or ".") .. " Drag them anywhere in Edit Mode.", true)
        end
        if isPet and myClass == "HUNTER" then
            B.dropdown("petHappy", "Pet happiness", "Your pet's mood, with its diet, damage and loyalty in the tooltip.\n\nCorner: at the portrait's bottom right, where your frame has its corner point and combat swords.\nLevel badge: at the portrait's bottom left, where your frame has its level circle (the tooltip gives the pet's level).", "corner",
                { { "off", "Off" }, { "corner", "Corner" }, { "badge", "Level badge" } })
        end

        -- Health and power ----------------------------------------------------------------
        B.section("Health and power", false)
        B.dropdown("barTexture", "Health bar texture", "The health bar's fill (the cast bar and the incoming heal and shield overlays use it too). SharedMedia textures are listed too.", "default", textureChoices)
        B.dropdown("powerTexture", "Power bar texture", "The mana, rage or energy bar's fill, coloured by power type. Chosen separately from the health bar texture.", "default", textureChoices)
        B.dropdown("font", "Font", "For the name and the numbers on the bars. SharedMedia fonts are listed too.", "default", fontList)
        local numbers = B.dropdown("textMode", "Numbers", "When the bars show their numbers. On mouseover, only the bar under the cursor shows its number.",
            defaultFor(unit, "textMode"), { { "always", "Always" }, { "mouseover", "On mouseover" }, { "off", "Never" } })
        B.under(numbers, function() return get("textMode") ~= "off" end,
            B.dropdown("textFormat", "Number format", "Totals, percentages, or both.",
                defaultFor(unit, "textFormat"), { { "value", "12.3K" }, { "percent", "85%" }, { "both", "12.3K (85%)" } }))
        if isPet then   -- (the pet's own reaction colour flips around, so these two)
            B.dropdown("petColor", "Health colour", "Default: the bar as the game draws it (green). Or the same as your player frame's (your class colour, if that's what the player frame uses).", "player",
                { { "plain", "Default" }, { "player", "Match the player frame" } })
        else
            local colour = B.dropdown("colorMode", "Health colour", "Default: the bar as the game draws it (green).\nClass for players, reaction for NPCs: players in their class colour, NPCs red, yellow or green by how they feel about you.\nClass colour: players in their class colour, NPCs as drawn.\nBy reaction: everyone red, yellow or green by how they feel about you.\nDark: a flat dark bar.", "smart", COLOR_MODES)
            if not isPlayer then
                local function byReaction() local m = get("colorMode"); return m == "smart" or m == "reaction" end
                local npc = B.dropdown("npcColor", "Enemy NPC colour", "The health colour for hostile NPCs. Green (or your own colour) lets Fade to red show their health dropping. Neutral NPCs stay yellow.", "reaction",
                    { { "reaction", "Red" }, { "green", "Green" }, { "custom", "Custom" } })
                local npcCustom = B.swatch("Custom NPC colour", function()
                    local c = get("npcColorRGB")
                    return type(c) == "table" and c or { 0.1, 0.8, 0.1 }
                end, function(r, g, b) setSetting(unit, "npcColorRGB", { r, g, b }) end, "The health colour for hostile NPCs. Click to change it.")
                B.under(colour, byReaction, npc)
                B.under(npc, both(byReaction, function() return get("npcColor") == "custom" end), npcCustom)
            end
        end
        B.fade(unit, setSetting, "As health drops, the health colour (whichever you picked above) shifts towards red, or through your own stops.")
        B.slider("hpAlpha", "Health bar opacity", "How solid the health fill is: lower lets the frame art and the background show through.", defaultFor(unit, "hpAlpha"), 0.2, 1, 0.05)
        B.slider("mpAlpha", "Power bar opacity", "How solid the mana, rage or energy fill is.", defaultFor(unit, "mpAlpha"), 0.2, 1, 0.05)
        B.pair({ "healPrediction", "Incoming heals", "Heals on their way to the unit, in green past the end of its health.", true },
               { "absorbs", "Shields and heal absorbs", "Damage shields in pale blue past the end of its health (and a glow at the end when they're more than the missing health), and healing absorbs eating back into it in red.", true })
        B.pair({ "damageTrail", "Recent damage", "When its health drops, the part just lost stays in red for a moment, then slides away, so you can see how big each hit was.", true },
               (unit == "target" or unit == "focus") and { "damagePredict", "Preview spell damage", "While you cast at it, the damage your spell will do shows lighter at the end of its health (the tooltip's damage; crits, resists and armour aren't counted).", true } or nil)
        if isPlayer then
            local cost = B.check("costPredict", "Spell costs", "On your mana (or other power) bar: while you cast, the part the spell will use is shaded; when your power drops (any spell or ability, instants too), the part just spent stays lit where it was for a moment, then slides away.", true)
            B.under(cost, isOn("costPredict"),
                B.slider("costShade", "Shading", "How the cost shows on the bar while you cast: lighter (right) or darker (left), and by how much. The trail of what was just spent always stays light.", 55, -100, 100, 5,
                    function(v)
                        v = math.floor(v + 0.5)
                        if v == 0 then return "Off" end
                        return string.format(v > 0 and "Lighter %d%%" or "Darker %d%%", math.abs(v))
                    end))
            if myClass == "DRUID" then
                local druid = B.check("druidMana", "Druid mana", "While you're in bear or cat form, your mana shows in a slim bar under the frame. Drag it anywhere in Edit Mode.", true)
                B.under(druid, isOn("druidMana"),
                    B.dropdown("druidBars", "Bar order", "In bear or cat form: the frame's bar shows your rage or energy and the slim bar your mana, or the frame's bar keeps your mana and the slim bar shows the form's rage or energy.", "form",
                        { { "form", "Form power first" }, { "mana", "Mana first" } }))
            end
        end

        -- Buffs and debuffs ---------------------------------------------------------------
        B.section("Buffs and debuffs", false)
        local function anyAuras() return (get("auraBuffs") or get("auraDebuffs")) and true or false end
        Opt.predNotes[anyAuras] = "Needs Buffs or Debuffs turned on."
        local dispel = B.check("dispelGlow", "Dispel glow", "When the unit has a debuff you can dispel, the frame takes its colour (magic blue, curse purple, disease brown, poison green) and pulses, like the resting glow.", defaultFor(unit, "dispelGlow"))
        B.under(dispel, isOn("dispelGlow"),
            B.dropdown("dispelWho", "Glow for", "Debuffs you can dispel yourself, or any debuff someone could dispel (magic, curse, disease, poison).", "mine",
                { { "mine", "Ones I can dispel" }, { "all", "Any dispellable" } }))
        local buffs = B.check("auraBuffs", "Buffs", "The unit's buffs, as icons by the frame.", defaultFor(unit, "auraBuffs"))
        B.under(buffs, isOn("auraBuffs"),
            B.dropdown("auraStyle", "Buffs shown", "Retail: on a friend, only the buffs you put on them (your heals over time, shields); on an enemy, all their buffs.\nEverything: all their buffs.", defaultFor(unit, "auraStyle"),
                { { "retail", "Retail" }, { "all", "Everything" } }),
            B.slider("auraSize", "Size", "How big the buff icons are.", defaultFor(unit, "auraSize"), 12, 40, 1, px))
        local debuffs = B.check("auraDebuffs", "Debuffs", "The unit's debuffs, as icons by the frame, the ones that matter most first.", defaultFor(unit, "auraDebuffs"))
        local debuffOpts = {
            B.slider("auraDebuffSize", "Size", "How big the debuff icons are.", defaultFor(unit, "auraSize"), 12, 40, 1, px),
            B.check("auraMine", "Only mine", "Only the debuffs you applied.", false),
        }
        if not OWN_CLASS[unit] then
            debuffOpts[#debuffOpts + 1] = B.check("auraMineBig", "Bigger own debuffs", "Your own debuffs (your damage over time and so on) first and bigger, so you can keep track of them.", false)
        end
        B.under(debuffs, isOn("auraDebuffs"), unpack(debuffOpts))
        -- (the small frames can also have them beside the frame: two rows, a row of buffs and of debuffs at most)
        local small = unit == "targettarget" or unit == "focustarget" or isPet
        local positions = { { "below", "Below the frame" }, { "above", "Above the frame" }, { "custom", "Drag in Edit Mode" } }
        if small then table.insert(positions, 1, { "side", "Right of the frame" }) end
        local timer = B.dropdown("auraTimer", "Time left", "How each icon shows the time it has left: a dark sweep across the icon, countdown numbers, or both.", "both",
            { { "both", "Sweep and numbers" }, { "swipe", "Sweep" }, { "numbers", "Numbers" }, { "none", "Nothing" } })
        local grow, gap, stack = B.auraDetails()
        B.showIf(anyAuras,
            B.dropdown("auraPos", "Position", "Where the icons sit."
                .. (small and " Right of the frame: two rows beside it, at most a row of buffs and a row of debuffs (the ones that matter first), so nothing spills over the next frame." or "")
                .. " With \"Drag in Edit Mode\", Edit Mode shows a blue box for them: drag it anywhere.", defaultFor(unit, "auraPos"), positions))
        B.showIf(both(anyAuras, function() return get("auraPos") == "custom" end),
            B.button("Move", "Open Edit Mode", openEditMode, "Drag the buffs and debuffs box (Position: Drag in Edit Mode)."))
        B.showIf(anyAuras,
            B.slider("auraPerRow", "Per row", "How many icons fit on a row before the next one starts.", defaultFor(unit, "auraPerRow"), 1, 16, 1, whole),
            B.slider("auraMax", "Most shown", "How many buffs, and how many debuffs, can show at once.", defaultFor(unit, "auraMax"), 1, 32, 1, whole))
        B.showIf(anyAuras, timer, grow, gap, stack)
        if isPlayer then
            -- weapon enchants and your buffs as timer bars (PlayerExtras.lua)
            B.check("weaponEnchants", "Weapon enchants", "Your weapons' temporary enchants and imbues (poisons, oils, stones, Rockbiter, Windfury, Flametongue...) as icons just before your buffs, with the time left. Hover for the details.", true)
            local bars = B.check("buffBars", "Buffs as timer bars", "Your buffs as bars with their icon, name and time left, in a block you place in Edit Mode (Webby Buff Bars).", false)
            B.under(bars, isOn("buffBars"),
                B.dropdown("buffBarsWho", "Bars show", "Only the buffs you cast on yourself, or every buff on you.", "mine",
                    { { "mine", "Buffs I cast" }, { "all", "All buffs on me" } }),
                B.slider("buffBarsMax", "Most bars", "How many bars show at once.", 8, 1, 16, 1, whole),
                B.slider("buffBarsWidth", "Bar width", "How wide each bar is.", 180, 100, 320, 1, px))
        end

        -- Cast bar and threat -------------------------------------------------------------
        if hasCastAndThreat(unit) then
            B.section("Cast bar and threat", false)
            local cast = B.check("castShow", "Cast bar", "What the unit is casting, under its mana bar: yellow for a cast, green for a channel, grey when you can't interrupt it, red when interrupted.", true)
            B.under(cast, isOn("castShow"),
                B.pair({ "castText", "Spell name", "The spell's name on the bar.", true },
                       { "castIcon", "Spell icon", "At the bar's left end.", true }))
            local threat = B.check("threatOn", "Threat", "Your threat on hostile mobs: a glow round the frame and / or your threat %, both in your threat colour.", true)
            B.under(threat, function() return get("threatShow") ~= "off" end,
                B.dropdown("threatShow", "Display", "A glow round the frame, your threat %, or both.", "both",
                    { { "both", "Glow and number" }, { "glow", "Glow only" }, { "number", "Number only" } }))
            B.under(threat, function() local m = get("threatShow"); return m == "both" or m == "number" end,
                B.dropdown("threatStyle", "Number style", "Your threat %. About 110% pulls aggro in melee and 130% at range. While you have aggro, it's your threat compared with the next highest in your group.\n\nJust the number: beside the raid marker on the portrait.\nIn a box: a small box above the end of the name.", "text",
                    { { "text", "Just the number" }, { "box", "In a box above the name" } }))
            B.under(threat, function() return get("threatShow") ~= "off" end,
                B.dropdown("threatColors", "Threat colours", "The colour of the glow and the number.\nGreen to red: green when you're safe, turning red as you get closer to pulling aggro.\nBlizzard's: the game's own threat colours.", "gradient",
                    { { "gradient", "Green to red" }, { "blizzard", "Blizzard's" } }))
        end

        -- Reset and copy ------------------------------------------------------------------
        B.section("Reset and copy", false)
        if not isPlayer then
            B.button("Copy", "Copy from player", function() copySettings("player", unit) end,
                "Gives this frame the player frame's options. Its position doesn't change.")
        end
        B.button("Reset", "Reset this frame", function() resetFrame(unit) end,
            "Puts this frame back to its default options and position, for the current Edit Mode layout.")
    end

    for _, unit in ipairs(UNITS) do
        local proxy = setmetatable({}, {
            __index = function(_, k)
                -- "threatOn": the Threat tickbox, over threatShow (off, or what it shows)
                if k == "threatOn" then return getSetting(unit, "threatShow") ~= "off" end
                return getSetting(unit, k)
            end,
            __newindex = function(_, k, v)
                if k == "threatOn" then
                    -- (turned back on, it shows what it showed before it was turned off)
                    local now = getSetting(unit, "threatShow")
                    if v then
                        if now == "off" then setSetting(unit, "threatShow", getSetting(unit, "threatLast") or "both") end
                    elseif now ~= "off" then
                        setSetting(unit, "threatLast", now)
                        setSetting(unit, "threatShow", "off")
                    end
                    return
                end
                setSetting(unit, k, v)
            end,
        })
        local B = builders(Opt.newPage(unit, UNIT_LABEL[unit]), proxy)
        if unit == "party" then partyPage(B) else framePage(B, unit) end
    end

    -- the modules' own pages (Click casting), after the frame pages
    for _, build in ipairs(ns.pages) do
        local ok, err = pcall(build, builders, Opt)
        if not ok then print("|cffff9900Webby Frames:|r couldn't build a settings page: " .. tostring(err)) end
    end
end

-- Entry in the minimap addon compartment (needs the TOC fields below).
function WebbyFrames_OnCompartmentClick() Opt.toggle() end

Opt.build = buildSettings
