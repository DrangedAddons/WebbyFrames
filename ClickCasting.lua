-- Webby Frames: click casting
-- What a click (or, while the mouse is over a member, a hover key) on a party frame does: target them,
-- open their menu, or cast a spell on them, at the rank you choose, on them or on their target. Loads
-- after WebbyFrames.lua and Party.lua (see the .toc); its settings page is added to the window through
-- ns.pages. (The page's layout, ranks, Cast on and Also target follow NeoHeal's click casting (MIT);
-- hover keys and resurrect EllesmereUI's, used with its author's permission, and Clique.)
local _, ns = ...
local Party = ns.Party
local Click = {}
ns.Click = Click

-- Saved per class: WebbyFramesDB.clickCast[class], keyed by binding:
--   "1" .. "5", with a modifier in front ("shift-2", "ctrl-1", "alt-3"; older combined ones like
--   "ctrl-shift-1" still work): a mouse button.  "hover1" .. "hover12": a custom keybind, whose key is kept
--   under "hoverkey1" .. ("SHIFT-F", the game's binding form).
--   The value: "target", "menu", "none", a spell's name, or a smart choice that means your class's
--   spell for it: "heal", "hot", "dispel", "dispel2", "res".
--   Per binding: [binding .. "@rank"] = "max" (highest, the default) / "max-1" / a rank number;
--   [binding .. "@on"] = nil (the member) / "target" / "targettarget"; [binding .. "@also"] = true to
--   target the member as well.
-- Unset, a plain left click targets and a right click opens the menu. Everything goes onto the frames as
-- secure attributes, so only out of combat (a change in combat waits for it to end).
Click.BUTTONS = { { "1", "Left click" }, { "2", "Right click" }, { "3", "Middle click" }, { "4", "Button 4" }, { "5", "Button 5" } }
Click.TABS = { { "", "No modifier" }, { "shift-", "Shift" }, { "ctrl-", "Ctrl" }, { "alt-", "Alt" } }
Click.DEFAULT = { ["1"] = "target", ["2"] = "menu" }
Click.HOVER_SLOTS = 12
Click.tab = ""            -- (the page's modifier: which mouse bindings it shows)

function Click.bindings()
    if not WebbyFramesDB then return {} end
    local class = select(2, UnitClass("player")) or "ALL"
    WebbyFramesDB.clickCast = WebbyFramesDB.clickCast or {}
    local t = WebbyFramesDB.clickCast[class]
    if not t then t = {}; WebbyFramesDB.clickCast[class] = t end
    if Click.tidied == t then return t end
    Click.tidied = t
    -- (once: keys added before keybind slots go into the first free slots)
    for b, v in pairs(t) do
        local key = type(b) == "string" and b:match("^key:(.+)$")
        if key then
            t[b] = nil
            for i = 1, Click.HOVER_SLOTS do
                if not t["hoverkey" .. i] then t["hoverkey" .. i], t["hover" .. i] = key, v; break end
            end
        end
    end
    return t
end

function Click.get(binding)
    local v = Click.bindings()[binding]
    if v == nil then v = Click.DEFAULT[binding] or "none" end
    return v
end

function Click.set(binding, v)
    local t = Click.bindings()
    if v == "none" and not Click.DEFAULT[binding] then v = nil end
    t[binding] = v
    -- (a new action: its rank starts at the highest again)
    t[binding .. "@rank"] = nil
    Click.apply()
end

-- A binding's own option (rank, on, also).
function Click.opt(binding, key) return Click.bindings()[binding .. "@" .. key] end
function Click.setOpt(binding, key, v)
    Click.bindings()[binding .. "@" .. key] = v
    Click.apply()
end

-- Addon-wide click casting options (not per class).
function Click.option(key)
    if not WebbyFramesDB then return nil end
    local v = WebbyFramesDB[key]
    if v == nil then return (key == "clickTooltip") end      -- (tooltips on, other frames off)
    return v
end

---------------------------------------------------------------------------
-- Smart choices: your class's spell for each, the first of these you know. "Dispel" is your class's
-- best dispel; a click can't pick one by the debuff's type, so a second dispel has its own choice.
---------------------------------------------------------------------------
Click.HEALER = {
    PRIEST  = { heal = { "Flash Heal", "Greater Heal", "Heal", "Lesser Heal" }, hot = { "Renew" },
                dispel = { "Dispel Magic", "Purify" }, dispel2 = { "Abolish Disease", "Cure Disease" }, res = { "Resurrection" } },
    DRUID   = { heal = { "Regrowth", "Healing Touch" }, hot = { "Rejuvenation" },
                dispel = { "Remove Corruption", "Remove Curse" }, dispel2 = { "Abolish Poison", "Cure Poison" }, res = { "Rebirth" } },
    PALADIN = { heal = { "Flash of Light", "Holy Light" }, hot = {},
                dispel = { "Cleanse", "Purify" }, dispel2 = {}, res = { "Redemption" } },
    SHAMAN  = { heal = { "Lesser Healing Wave", "Healing Wave" }, hot = { "Riptide" },
                dispel = { "Cleanse Spirit", "Cure Toxins", "Cure Poison" }, dispel2 = { "Cure Disease" }, res = { "Ancestral Spirit" } },
}
Click.SMART = { "heal", "hot", "dispel", "dispel2", "res" }
Click.HEALER_LABEL = { heal = "Main heal", hot = "Heal over time", dispel = "Dispel", dispel2 = "Second dispel", res = "Resurrect" }

function Click.healerSpell(choice, known)
    local list = (Click.HEALER[select(2, UnitClass("player"))] or {})[choice]
    if not list then return nil end
    known = known or Click.knownSpells()
    for _, name in ipairs(list) do if known[name] then return name end end
end

-- Your spellbook's castable spells: a set by name, the names in spellbook order, the spellbook's tabs
-- (their spells' names and icons, for the picker), and each spell's known ranks (numbers, low to high).
-- (read once, then kept until the spellbook changes: SPELLS_CHANGED)
function Click.knownSpells()
    local k = Click.spellCache
    if k then return k[1], k[2], k[3], k[4] end
    local set, names, tabs, ranks = Click.readSpells()
    Click.spellCache = { set, names, tabs, ranks }
    return set, names, tabs, ranks
end

function Click.readSpells()
    local set, names, tabs, ranks = {}, {}, {}, {}
    local function add(tab, name, icon, sub)
        if not name or name == "" then return end
        local r = sub and tonumber(tostring(sub):match("(%d+)"))
        if r then
            ranks[name] = ranks[name] or {}
            table.insert(ranks[name], r)
        end
        if set[name] then return end
        set[name] = true
        names[#names + 1] = name
        tab.spells[#tab.spells + 1] = { name, icon }
    end
    local ok = pcall(function()
        local SB = C_SpellBook
        local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
        for line = 1, SB.GetNumSpellBookSkillLines() do
            local info = SB.GetSpellBookSkillLineInfo(line)
            if info and not info.shouldHide then
                local tab = { name = info.name or "Spells", spells = {} }
                for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                    local item = SB.GetSpellBookItemInfo(i, bank)
                    if item and not item.isPassive and item.itemType == Enum.SpellBookItemType.Spell then
                        add(tab, item.name, item.iconID, item.subName)
                    end
                end
                if #tab.spells > 0 then tabs[#tabs + 1] = tab end
            end
        end
    end)
    if not ok and GetNumSpellTabs then      -- older spellbook API
        pcall(function()
            for t = 1, GetNumSpellTabs() do
                local tabName, _, offset, count = GetSpellTabInfo(t)
                local tab = { name = tabName or "Spells", spells = {} }
                for i = offset + 1, offset + count do
                    if not IsPassiveSpell(i, BOOKTYPE_SPELL or "spell") then
                        local name, sub = GetSpellBookItemName(i, BOOKTYPE_SPELL or "spell")
                        add(tab, name, GetSpellBookItemTexture(i, BOOKTYPE_SPELL or "spell"), sub)
                    end
                end
                if #tab.spells > 0 then tabs[#tabs + 1] = tab end
            end
        end)
    end
    for _, list in pairs(ranks) do table.sort(list) end
    return set, names, tabs, ranks
end

local function spellIcon(name)
    local tex
    pcall(function() tex = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(name)) or GetSpellTexture(name) end)
    return tex
end

-- The spell a binding casts (smart choices turned into your spell), or nil for target / menu / nothing.
function Click.spellOf(v, known)
    if Click.HEALER_LABEL[v] then return Click.healerSpell(v, known) end
    if v and v ~= "target" and v ~= "menu" and v ~= "none" then return v end
end

-- The spell as the game should cast it, at the binding's rank: by name (the highest you know), or
-- "Name(Rank N)" for Highest -1 or a fixed rank you know.
function Click.ranked(binding, spell, ranks)
    local list = spell and ranks and ranks[spell]
    if not list or #list < 2 then return spell end
    local r = Click.opt(binding, "rank") or "max"
    if r == "max-1" then return spell .. "(Rank " .. list[#list - 1] .. ")" end
    local n = tonumber(r)
    if n then
        for _, k in ipairs(list) do if k == n then return spell .. "(Rank " .. n .. ")" end end
    end
    return spell
end

-- What a choice is called (smart choices with the spell they stand for).
function Click.choiceLabel(v, known)
    if v == "target" then return "Target" end
    if v == "menu" then return "Open their menu" end
    if v == "none" or v == nil then return "Nothing" end
    if Click.HEALER_LABEL[v] then
        local s = Click.healerSpell(v, known)
        return Click.HEALER_LABEL[v] .. (s and (" (" .. s .. ")") or " (not learned)")
    end
    return v
end

-- The action picker: nothing and the basics, the smart choices you have, then your spellbook by tab.
function Click.choices()
    local known, _, tabs = Click.knownSpells()
    local list = {
        { "none", "Nothing" }, { "target", "Target" }, { "menu", "Open their menu" },
    }
    local smart = {}
    for _, key in ipairs(Click.SMART) do
        local s = Click.healerSpell(key, known)
        if s then smart[#smart + 1] = { key, Click.HEALER_LABEL[key] .. " (" .. s .. ")", icon = spellIcon(s) } end
    end
    if #smart > 0 then
        list[#list + 1] = { nil, "Your class's best", header = true }
        for _, c in ipairs(smart) do list[#list + 1] = c end
    end
    for _, tab in ipairs(tabs) do
        list[#list + 1] = { nil, tab.name, header = true }
        for _, s in ipairs(tab.spells) do list[#list + 1] = { s[1], s[1], icon = s[2] } end
    end
    return list
end

-- A binding's name: "Shift + Left click", "Key: Shift + F".
function Click.bindingLabel(binding)
    local slot = binding:match("^hover(%d+)$")
    if slot then
        local key = Click.bindings()["hoverkey" .. slot]
        if not key then return "Keybind " .. slot end
        local parts = {}
        for part in key:gmatch("[^-]+") do parts[#parts + 1] = part:sub(1, 1) .. part:sub(2):lower() end
        if key:sub(-1) == "-" then parts[#parts + 1] = "-" end
        return "Key: " .. table.concat(parts, " + ")
    end
    local mods, button = binding:match("^(.-)(%d)$")
    local words = {}
    for m in (mods or ""):gmatch("(%a+)%-") do words[#words + 1] = m:sub(1, 1):upper() .. m:sub(2) end
    for _, b in ipairs(Click.BUTTONS) do if b[1] == button then words[#words + 1] = b[2] end end
    return table.concat(words, " + ")
end

-- Every binding that does something other than the default, mouse first, then hover keys (tooltips).
function Click.list()
    local t, out = Click.bindings(), {}
    local mods = { "", "shift-", "ctrl-", "alt-", "ctrl-shift-", "alt-shift-", "alt-ctrl-", "alt-ctrl-shift-" }
    for _, m in ipairs(mods) do
        for _, b in ipairs(Click.BUTTONS) do
            local id = m .. b[1]
            local v = Click.get(id)
            if v ~= "none" and Click.DEFAULT[id] ~= v then out[#out + 1] = id end
        end
    end
    for i = 1, Click.HOVER_SLOTS do
        if t["hoverkey" .. i] and t["hover" .. i] and t["hover" .. i] ~= "none" then out[#out + 1] = "hover" .. i end
    end
    return out
end

---------------------------------------------------------------------------
-- Onto the frames
---------------------------------------------------------------------------
Click.OTHER_UNITS = { "player", "target", "targettarget", "focus", "focustarget", "pet" }
function Click.frames()
    local list = {}
    for slot = 1, Party.SLOTS do list[#list + 1] = Party.members[slot] end
    if ns.RaidParty then
        for _, t in ipairs(ns.RaidParty.tiles) do list[#list + 1] = t end
        for _, p in ipairs(ns.RaidParty.petTiles) do list[#list + 1] = p end
    end
    return list
end
function Click.otherFrames()
    local list = {}
    for _, u in ipairs(Click.OTHER_UNITS) do if ns.frames and ns.frames[u] then list[#list + 1] = ns.frames[u] end end
    return list
end

-- One binding's attributes on a frame (prefix .. "type" .. suffix, its spell, macro and unit).
local function setAction(f, prefix, suffix, binding, v, known, ranks)
    local tk, sk, mk, uk = prefix .. "type" .. suffix, prefix .. "spell" .. suffix, prefix .. "macrotext" .. suffix, prefix .. "unit" .. suffix
    local typ, spell, macro, unit
    local u = f:GetAttribute("unit")
    if v == "res" then
        -- resurrect: only on someone dead (on anyone else it does nothing)
        local s = Click.healerSpell("res", known)
        if s and u then typ, macro = "macro", "/cast [@" .. u .. ",dead] " .. s end
    elseif v == "target" then typ = "target"
    elseif v == "menu" then typ = "togglemenu"
    else
        local s = Click.ranked(binding, Click.spellOf(v, known), ranks)
        if s then
            -- Cast on: the member, their target, or their target's target; Also target: target the
            -- member too (a macro, as one click does both)
            local on = Click.opt(binding, "on")
            local castUnit = (u and on == "target" and u .. "target") or (u and on == "targettarget" and u .. "targettarget") or nil
            if Click.opt(binding, "also") and u then
                typ, macro = "macro", "/target [@" .. u .. "]\n/cast [@" .. (castUnit or u) .. "] " .. s
            else
                typ, spell, unit = "spell", s, castUnit
            end
        end
    end
    f:SetAttribute(tk, typ)
    f:SetAttribute(sk, spell)
    f:SetAttribute(mk, macro)
    f:SetAttribute(uk, unit)
end

-- Every binding on one frame. Mouse: every modifier and button combination (cleared first, so a removed
-- one does nothing). Hover keys: listed in "webby-keys" for the hover handler, each on a virtual button
-- ("*type-hk1": any modifier, since the key itself carries them).
local MODS = { "", "shift-", "ctrl-", "alt-", "ctrl-shift-", "alt-shift-", "alt-ctrl-", "alt-ctrl-shift-" }
function Click.applyTo(f, known, ranks, onlyDefaults)
    for _, m in ipairs(MODS) do
        for b = 1, 5 do
            local id = m .. b
            local v = (m == "" and Click.DEFAULT[tostring(b)]) or "none"
            if not onlyDefaults then v = Click.get(id) end
            setAction(f, m, tostring(b), id, v, known, ranks)
        end
    end
    local t, keys = Click.bindings(), {}
    if not onlyDefaults then
        for i = 1, Click.HOVER_SLOTS do
            local key, v = t["hoverkey" .. i], t["hover" .. i]
            if key and v and v ~= "none" then keys[#keys + 1] = { key, "hover" .. i, v } end
        end
    end
    local names = {}
    for i = 1, math.max(#keys, f.webbyKeyCount or 0) do
        local k = keys[i]
        if k then
            names[#names + 1] = k[1]
            setAction(f, "*", "-hk" .. i, k[2], k[3], known, ranks)
        else
            setAction(f, "*", "-hk" .. i, "none", "none", known, ranks)
        end
    end
    f.webbyKeyCount = #keys
    f:SetAttribute("webby-keys", #names > 0 and table.concat(names, ",") or nil)
    Click.wrap(f)
end

-- Puts the bindings on every frame (out of combat). Smart choices and ranks turn into your spells here,
-- so learning one (SPELLS_CHANGED) re-applies; so does a party change (bindings name the member's unit).
function Click.apply()
    if InCombatLockdown() then Click.pending = true; return end
    Click.pending = nil
    local known, _, _, ranks = Click.knownSpells()
    for _, f in ipairs(Click.frames()) do if f then Click.applyTo(f, known, ranks) end end
    -- your own frames: the bindings with "On every frame", else just target and menu again
    local all = Click.option("clickAllFrames")
    if all or Click.othersSet then
        for _, f in ipairs(Click.otherFrames()) do Click.applyTo(f, known, ranks, not all) end
        Click.othersSet = all or nil
    end
end

---------------------------------------------------------------------------
-- Hover keys: while the mouse is over a frame, your keys click it (on their virtual buttons). Set and
-- cleared by the game's secure handler as the mouse comes and goes, so it works in combat too.
---------------------------------------------------------------------------
Click.ENTER = [[
    local keys = self:GetAttribute("webby-keys")
    if not keys then return end
    local i = 0
    for key in string.gmatch(keys, "[^,]+") do
        i = i + 1
        self:SetBindingClick(true, key, self, "hk" .. i)
    end
]]
Click.LEAVE = [[ self:ClearBindings() ]]

function Click.wrap(f)
    if f.webbyWrapped or not Click.header or InCombatLockdown() then return end
    if not pcall(Click.header.WrapScript, Click.header, f, "OnEnter", Click.ENTER) then return end
    pcall(Click.header.WrapScript, Click.header, f, "OnLeave", Click.LEAVE)
    pcall(Click.header.WrapScript, Click.header, f, "OnHide", Click.LEAVE)
    f.webbyWrapped = true
end

---------------------------------------------------------------------------
-- In the tooltip: your bindings under the member's own lines (hold a modifier: just that modifier's)
---------------------------------------------------------------------------
function Click.addTooltip(f)
    if not Click.option("clickTooltip") or not f then return end
    if f.baseUnit ~= "party" and not Click.option("clickAllFrames") then return end
    local held = (IsAltKeyDown() and "alt-" or "") .. (IsControlKeyDown() and "ctrl-" or "") .. (IsShiftKeyDown() and "shift-" or "")
    local known = Click.knownSpells()
    local shown = false
    for _, b in ipairs(Click.list()) do
        local mods = b:match("^(.-)%d$")
        if held == "" or mods == held then
            if not shown then GameTooltip:AddLine(" "); GameTooltip:AddLine("Click casting", 1, 0.82, 0); shown = true end
            local label = Click.choiceLabel(Click.get(b), known)
            local on = Click.opt(b, "on")
            if on == "target" then label = label .. " on their target" elseif on == "targettarget" then label = label .. " on their target's target" end
            GameTooltip:AddDoubleLine(Click.bindingLabel(b), label, 0.8, 0.8, 0.8, 1, 1, 1)
        end
    end
    if shown then GameTooltip:Show() end
end

-- Started by Party.init once the party frames exist.
function Click.init()
    Click.header = CreateFrame("Frame", "WebbyFrames_ClickHeader", UIParent, "SecureHandlerBaseTemplate")
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("SPELLS_CHANGED")
    ev:SetScript("OnEvent", function(_, event)
        if event == "SPELLS_CHANGED" then Click.spellCache = nil end
        if event == "SPELLS_CHANGED" or Click.pending then pcall(Click.apply) end
    end)
    pcall(Click.apply)
end

-- Your class's starting bindings (Reset to class defaults). Healers: the main heal on left click, a heal
-- over time on right click where the class has one, dispels on Shift, resurrect on Alt + left click,
-- and target / menu moved to Ctrl. Everyone else: left click targets, right click opens the menu.
function Click.classDefaults()
    local class = select(2, UnitClass("player"))
    if not Click.HEALER[class] then return {} end
    local known = Click.knownSpells()
    local d = { ["ctrl-1"] = "target", ["ctrl-2"] = "menu", ["alt-1"] = "res" }
    if Click.healerSpell("heal", known) then d["1"] = "heal" end
    if Click.healerSpell("hot", known) then d["2"] = "hot" end
    if Click.healerSpell("dispel", known) then d["shift-1"] = "dispel" end
    if Click.healerSpell("dispel2", known) then d["shift-2"] = "dispel2" end
    return d
end

function Click.resetToDefaults()
    local t = Click.bindings()
    for k in pairs(t) do t[k] = nil end
    for k, v in pairs(Click.classDefaults()) do t[k] = v end
    Click.apply()
end

---------------------------------------------------------------------------
-- The Click casting page (laid out like NeoHeal's): pick a modifier, then for each mouse button what it
-- does, at which rank, on whom, and whether it targets them too; your hover keys the same; reset.
---------------------------------------------------------------------------
ns.pages[#ns.pages + 1] = function(builders, Opt)
    local opts = setmetatable({}, {
        __index = function(_, k) return Click.option(k) end,
        __newindex = function(_, k, v) if WebbyFramesDB then WebbyFramesDB[k] = v and true or false end; Click.apply() end,
    })
    local B = builders(Opt.newPage("click", "Click casting"), opts)
    -- columns: the binding's name (or its key), What it does, Rank, Cast on, Also target. Fitted inside the
    -- cards (6 px in from each side of the page), with 8 px between, so the last heading isn't cut off.
    local X = { name = 22, action = 120, rank = 296, on = 380, also = 496 }
    local W = { name = 92, action = 168, rank = 76, on = 108 }
    local ON = { { "member", "The member" }, { "target", "Their target" }, { "targettarget", "Their target's target" } }

    -- a dropdown-looking button (text, arrow, optional icon)
    local function drop(f, x, w)
        local b = CreateFrame("Button", nil, f, "BackdropTemplate")
        b:SetSize(w, 26)
        b:SetPoint("LEFT", x, 0)
        Opt.styleField(b)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(20, 20)
        b.icon:SetPoint("LEFT", 3, 0)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.icon:Hide()
        b.text = Opt.text(b, 11)
        b.text:SetJustifyH("LEFT")
        pcall(b.text.SetWordWrap, b.text, false)
        local arrow = Opt.chevron(b, 12)
        arrow:SetPoint("RIGHT", -5, 0)
        function b:Set(text, icon)
            self.text:SetText(text)
            self.icon:SetShown(icon and true or false)
            if icon then self.icon:SetTexture(icon) end
            self.text:ClearAllPoints()
            self.text:SetPoint("LEFT", icon and 24 or 6, 0)
            self.text:SetPoint("RIGHT", -16, 0)
        end
        function b:Allow(on)
            self:SetEnabled(on)
            self:SetAlpha(on and 1 or 0.35)
        end
        return b
    end

    -- One row for a binding: binding() gives its id (the mouse rows follow the modifier picked above).
    -- nameSetup(f) makes the left part (a label, or the hover key's button) and returns its refresh.
    local function bindingRow(binding, nameSetup)
        return B.custom(Opt.ROW_H + 4, function(f, r)
            local nameRefresh = nameSetup(f)
            local action = drop(f, X.action, W.action)
            local rank = drop(f, X.rank, W.rank)
            local on = drop(f, X.on, W.on)
            local also = Opt.newCheck(f)
            also:SetPoint("LEFT", X.also + 20, 0)      -- (under the middle of its heading)
            Opt.tip(also, "Also target", "Clicking it targets the member as well as casting.")
            Opt.tip(action, "Does", "What it does on a party member: target them, open their menu, or cast a spell on them.")
            Opt.tip(rank, "Rank", "Which rank of the spell: Highest (follows you as you learn new ranks), Highest -1 (cheaper on mana, and follows too), or a fixed rank. For spells you know in two ranks or more.")
            Opt.tip(on, "Cast on", "Who the spell lands on: the member, their target, or their target's target.")
            action:SetScript("OnClick", function(self)
                if Opt.menu and Opt.menu:IsShown() and Opt.menu.owner == self then Opt.closeMenu(); return end
                local id = binding()
                Opt.openMenu(self, Click.choices(), Click.get(id), function(v) Click.set(id, v); Opt.changed() end)
            end)
            rank:SetScript("OnClick", function(self)
                if Opt.menu and Opt.menu:IsShown() and Opt.menu.owner == self then Opt.closeMenu(); return end
                local id = binding()
                local known, _, _, ranks = Click.knownSpells()
                local list = ranks[Click.spellOf(Click.get(id), known) or ""] or {}
                local choices = { { "max", "Highest" }, { "max-1", "Highest -1" } }
                for i = #list, 1, -1 do choices[#choices + 1] = { tostring(list[i]), "Rank " .. list[i] } end
                Opt.openMenu(self, choices, tostring(Click.opt(id, "rank") or "max"), function(v)
                    Click.setOpt(id, "rank", v ~= "max" and v or nil); Opt.changed()
                end)
            end)
            on:SetScript("OnClick", function(self)
                if Opt.menu and Opt.menu:IsShown() and Opt.menu.owner == self then Opt.closeMenu(); return end
                local id = binding()
                Opt.openMenu(self, ON, Click.opt(id, "on") or "member", function(v)
                    Click.setOpt(id, "on", v ~= "member" and v or nil); Opt.changed()
                end)
            end)
            also:SetScript("OnClick", function(self) Click.setOpt(binding(), "also", self:GetChecked() and true or nil); Opt.changed() end)
            r.refresh = function()
                local id = binding()
                if nameRefresh then nameRefresh() end
                local v = Click.get(id)
                local known, _, _, ranks = Click.knownSpells()
                local spell = Click.spellOf(v, known)
                action:Set(Click.choiceLabel(v, known), spell and spellIcon(spell))
                -- rank: for a spell you know in two ranks or more
                local list = spell and ranks[spell]
                local hasRanks = (list and #list >= 2) and true or false
                local rv = Click.opt(id, "rank")
                rank:Set(not hasRanks and "-" or (rv == "max-1" and "Highest -1") or (tonumber(rv) and ("Rank " .. rv)) or "Highest")
                rank:Allow(hasRanks)
                -- cast on / also target: for spells (not target, menu, nothing or resurrect)
                local isSpell = spell ~= nil and v ~= "res"
                local ov = Click.opt(id, "on")
                on:Set(not isSpell and "-" or (ov == "target" and "Their target") or (ov == "targettarget" and "Target's target") or "The member")
                on:Allow(isSpell)
                also:SetChecked(isSpell and Click.opt(id, "also") and true or false)
                also:SetEnabled(isSpell)
                also:SetAlpha(isSpell and 1 or 0.35)
            end
            r.controls = {}       -- (each control greys itself: Allow)
        end)
    end

    -- (the description: a row tall enough for its lines, wrapped to the page's width)
    B.custom(54, function(f)
        local fs = Opt.text(f, 11, Opt.THEME.dim)
        fs:SetPoint("TOPLEFT", X.name, -8)
        -- (a set width, not one from the row's right edge: the row has no width yet when this is made, so
        -- the text would sit on one line, cut off, until the next redraw)
        fs:SetWidth(Opt.CONTENT_W - X.name - 16)
        pcall(fs.SetWordWrap, fs, true)
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("TOP")
        fs:SetText("What a click on a party member does: target them, open their menu, or cast a spell on them. Pick a modifier, then set each mouse button. Hover keys work while your mouse is over a member. Saved for this class; changes in combat apply when it ends.")
    end)

    -- the modifier buttons (the one shown is pressed)
    B.custom(36, function(f, r)
        local buttons = {}
        for i, tab in ipairs(Click.TABS) do
            local b = Opt.newButton(f, 112, 26, tab[2])
            b:SetPoint("LEFT", X.name + (i - 1) * 118, 0)
            b:SetScript("OnClick", function() Click.tab = tab[1]; Opt.changed() end)
            buttons[i] = b
        end
        -- (the one showing: lit with the accent and in white; the rest dimmed)
        r.refresh = function()
            local T = Opt.THEME
            for i, tab in ipairs(Click.TABS) do
                local b, on = buttons[i], Click.tab == tab[1]
                if on then b:LockHighlight() else b:UnlockHighlight() end
                local c = on and T.text or T.dim
                b:GetFontString():SetTextColor(c[1], c[2], c[3])
            end
        end
        r.controls = {}
    end)

    -- column headings
    -- (the headings and binding rows sit on a card, like the other pages' sections: row.card)
    local function headings(first)
        local r = B.custom(26, function(f)
            local function col(x, text)
                local fs = Opt.text(f, 10, Opt.THEME.accent)
                fs:SetPoint("LEFT", x, -2)
                fs:SetText(text:upper())
            end
            col(X.name, first); col(X.action, "Does"); col(X.rank, "Rank"); col(X.on, "Cast on"); col(X.also, "Also target")
        end)
        r.card = true
        return r
    end
    headings("Mouse")
    for _, btn in ipairs(Click.BUTTONS) do
        local row = bindingRow(function() return Click.tab .. btn[1] end, function(f)
            local label = Opt.text(f, 12)
            label:SetPoint("LEFT", X.name, 0)
            label:SetWidth(W.name)
            label:SetJustifyH("LEFT")
            pcall(label.SetWordWrap, label, false)
            return function()
                local word = ({ ["shift-"] = "Shift + ", ["ctrl-"] = "Ctrl + ", ["alt-"] = "Alt + " })[Click.tab] or ""
                label:SetText(word .. btn[2])
            end
        end)
        row.card = true
    end

    -- Custom keybinds: none to start with; "+ Add a keybind" takes the next key you press and gives it a
    -- row like the mouse buttons' (what it does, rank, cast on, also target), with a button to change the
    -- key and one to remove the row. They work while your mouse is over a member.
    -- (a gap between the two cards; the keybind headings only once there's a keybind under them)
    B.custom(10, function() end)
    local function anyKey()
        local t = Click.bindings()
        for i = 1, Click.HOVER_SLOTS do if t["hoverkey" .. i] then return true end end
        return false
    end
    B.showIf(anyKey, headings("Keybind"))
    local function freeSlot()
        local t = Click.bindings()
        for i = 1, Click.HOVER_SLOTS do if not t["hoverkey" .. i] then return i end end
    end
    -- (a button that waits for a key: done(key) with it in the game's form, "SHIFT-F")
    local function keyCapture(b, fs, idle, done)
        local function stop()
            b:EnableKeyboard(false)
            pcall(b.SetPropagateKeyboardInput, b, true)
            idle()
        end
        b:SetScript("OnClick", function()
            if InCombatLockdown() then return end
            fs:SetText("|cff33ccffPress a key (Esc cancels)|r")
            b:EnableKeyboard(true)
            pcall(b.SetPropagateKeyboardInput, b, false)
        end)
        b:SetScript("OnKeyDown", function(_, key)
            if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" then return end
            stop()
            if key == "ESCAPE" then return end
            done((IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "") .. key)
        end)
        b:SetScript("OnHide", stop)
    end
    for i = 1, Click.HOVER_SLOTS do
        local row = bindingRow(function() return "hover" .. i end, function(f)
            local kb = CreateFrame("Button", nil, f, "BackdropTemplate")
            kb:SetSize(W.name, 26)
            kb:SetPoint("LEFT", X.name, 0)
            Opt.styleField(kb)
            local fs = Opt.text(kb, 11)
            fs:SetPoint("LEFT", 6, 0)
            fs:SetPoint("RIGHT", -6, 0)
            pcall(fs.SetWordWrap, fs, false)
            Opt.tip(kb, "Keybind", "Click, then press a different key to change it (with Shift, Ctrl or Alt if you like). Esc cancels.")
            local function show()
                fs:SetText((Click.bindingLabel("hover" .. i):gsub("^Key: ", "")))
            end
            keyCapture(kb, fs, show, function(key)
                Click.bindings()["hoverkey" .. i] = key
                Click.apply()
                Opt.changed()
            end)
            -- remove the keybind (and what it did)
            local del = Opt.newX(f, 22)
            del:SetPoint("LEFT", X.also + 60, 0)
            Opt.tip(del, "Remove", "Remove this keybind.")
            del:SetScript("OnClick", function()
                if InCombatLockdown() then return end
                local t = Click.bindings()
                for _, k in ipairs({ "hoverkey" .. i, "hover" .. i, "hover" .. i .. "@rank", "hover" .. i .. "@on", "hover" .. i .. "@also" }) do t[k] = nil end
                Click.apply()
                Opt.changed()
            end)
            return show
        end)
        row.card = true
        B.showIf(function() return Click.bindings()["hoverkey" .. i] ~= nil end, row)
    end
    -- + Add a keybind
    local addRow = B.custom(Opt.ROW_H + 8, function(f, r)
        local b = CreateFrame("Button", nil, f, "BackdropTemplate")
        b:SetSize(W.name + W.action + 6, 26)
        b:SetPoint("LEFT", X.name, 0)
        Opt.styleField(b)
        -- (dashed-looking: a dim accent edge, as a slot waiting to be filled)
        b:SetBackdropBorderColor(Opt.THEME.accent[1], Opt.THEME.accent[2], Opt.THEME.accent[3], 0.35)
        local fs = Opt.text(b, 11, Opt.THEME.accent)
        fs:SetPoint("LEFT", 10, 0)
        fs:SetPoint("RIGHT", -8, 0)
        fs:SetJustifyH("LEFT")
        Opt.tip(b, "Add a keybind", "Click, then press the key you want (with Shift, Ctrl or Alt if you like). It gets its own row: pick what it does there. While your mouse is over a party member, the key does it. Esc cancels.")
        local function idle() fs:SetText(freeSlot() and "+ Add a keybind" or "|cff808080All " .. Click.HOVER_SLOTS .. " keybinds in use|r") end
        keyCapture(b, fs, idle, function(key)
            local slot = freeSlot()
            if not slot then return end
            Click.bindings()["hoverkey" .. slot] = key
            Click.apply()
            Opt.changed()
        end)
        r.refresh = idle
        r.controls = {}
    end)
    addRow.card = true

    -- reset, and the options
    B.custom(44, function(f, r)
        local b = Opt.newButton(f, 200, 26, "Reset to class defaults")
        b:SetPoint("LEFT", X.name, 0)
        b:SetScript("OnClick", function() Click.resetToDefaults(); Opt.changed() end)
        Opt.tip(b, "Reset to class defaults", Click.HEALER[select(2, UnitClass("player"))]
            and "Your main heal on left click, a heal over time on right click (where your class has one), your dispels on Shift + left and Shift + right click, resurrect on Alt + left click, and target / menu on Ctrl + left / right click. Replaces your bindings."
            or "Left click targets, right click opens the menu. Replaces your bindings.")
        r.controls = {}
    end)
    B.section("Options", false)
    B.check("clickTooltip", "Bindings in tooltips", "Hovering a party member lists your bindings under their tooltip (hold a modifier to see just its bindings).", true)
    B.check("clickAllFrames", "On every frame", "Your bindings work on your player, target, focus, their targets and pet frames too, not just the party.", false)
end
