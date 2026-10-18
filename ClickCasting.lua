-- Webby Frames: click casting
-- What each click on a party frame does. Loads after WebbyFrames.lua and Party.lua (see the .toc); its
-- settings page is added to the window through ns.pages.
local _, ns = ...
local Party = ns.Party
local Click = {}
ns.Click = Click

-- Click-casting on the party frames: each mouse button, alone or with Shift / Ctrl / Alt, can target,
-- open the menu, do nothing, or cast a spell from your spellbook on whoever you click. Kept per class
-- (WebbyFramesDB.clickCast[class][binding], binding like "1", "shift-2"); unset, a plain left click targets and a
-- right click opens the menu. Set on the frames as secure click attributes, so only out of combat (a
-- change in combat waits for it to end).
Click.BUTTONS = { { "1", "Left button" }, { "2", "Right button" }, { "3", "Middle button" }, { "4", "Button 4" }, { "5", "Button 5" } }
Click.MODS = { { "", "Click" }, { "shift-", "Shift + click" }, { "ctrl-", "Ctrl + click" }, { "alt-", "Alt + click" } }
Click.DEFAULT = { ["1"] = "target", ["2"] = "menu" }

function Click.bindings()
    if not WebbyFramesDB then return {} end
    local class = select(2, UnitClass("player")) or "ALL"
    WebbyFramesDB.clickCast = WebbyFramesDB.clickCast or {}
    WebbyFramesDB.clickCast[class] = WebbyFramesDB.clickCast[class] or {}
    return WebbyFramesDB.clickCast[class]
end

-- A binding's choice: "target", "menu", "none" or a spell name.
function Click.get(binding)
    local v = Click.bindings()[binding]
    if v == nil then v = Click.DEFAULT[binding] or "none" end
    return v
end

function Click.set(binding, v)
    Click.bindings()[binding] = v
    Click.apply()
end

-- Healer choices: your class's spell for each, the first of these you know (cast by name, so always the
-- highest rank). Shown in the menus with the spell they stand for.
Click.HEALER = {
    PRIEST  = { heal = { "Flash Heal", "Greater Heal", "Heal", "Lesser Heal" }, hot = { "Renew" },
                dispel = { "Dispel Magic", "Purify" }, dispel2 = { "Abolish Disease", "Cure Disease" } },
    DRUID   = { heal = { "Regrowth", "Healing Touch" }, hot = { "Rejuvenation" },
                dispel = { "Remove Corruption", "Remove Curse" }, dispel2 = { "Abolish Poison", "Cure Poison" } },
    PALADIN = { heal = { "Flash of Light", "Holy Light" }, hot = {},
                dispel = { "Cleanse", "Purify" }, dispel2 = {} },
    SHAMAN  = { heal = { "Lesser Healing Wave", "Healing Wave" }, hot = { "Riptide" },
                dispel = { "Cleanse Spirit", "Cure Toxins", "Cure Poison" }, dispel2 = { "Cure Disease" } },
}
Click.HEALER_LABEL = { heal = "Main heal", hot = "Heal over time", dispel = "Dispel", dispel2 = "Second dispel" }

-- The spell a healer choice stands for, if you know one (nil otherwise). known: the spellbook's names.
function Click.healerSpell(choice, known)
    local list = (Click.HEALER[select(2, UnitClass("player"))] or {})[choice]
    if not list then return nil end
    known = known or Click.knownSpells()
    for _, name in ipairs(list) do if known[name] then return name end end
end

-- The spells in your spellbook that can be cast (not passive), by name, for the binding menus: first
-- the healer choices your class has, then every spell.
function Click.spellChoices()
    local list = { { "target", "Target the unit" }, { "menu", "Open its menu" }, { "none", "Nothing" } }
    local known, names = Click.knownSpells()
    for _, key in ipairs({ "heal", "hot", "dispel", "dispel2" }) do
        local spell = Click.healerSpell(key, known)
        if spell then list[#list + 1] = { key, Click.HEALER_LABEL[key] .. " (" .. spell .. ")" } end
    end
    for _, name in ipairs(names) do list[#list + 1] = { name, name } end
    return list
end

-- Your spellbook's castable spells: a set by name, and the names in spellbook order.
function Click.knownSpells()
    local set, names = {}, {}
    local function add(name)
        if name and name ~= "" and not set[name] then set[name] = true; names[#names + 1] = name end
    end
    local ok = pcall(function()
        local SB = C_SpellBook
        local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
        for line = 1, SB.GetNumSpellBookSkillLines() do
            local info = SB.GetSpellBookSkillLineInfo(line)
            if info and not info.shouldHide then
                for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                    local item = SB.GetSpellBookItemInfo(i, bank)
                    if item and not item.isPassive and item.itemType == Enum.SpellBookItemType.Spell then add(item.name) end
                end
            end
        end
    end)
    if not ok and GetNumSpellTabs then      -- older spellbook API
        pcall(function()
            for t = 1, GetNumSpellTabs() do
                local _, _, offset, count = GetSpellTabInfo(t)
                for i = offset + 1, offset + count do
                    if not IsPassiveSpell(i, BOOKTYPE_SPELL or "spell") then add(GetSpellBookItemName(i, BOOKTYPE_SPELL or "spell")) end
                end
            end
        end)
    end
    return set, names
end

-- Puts the bindings on every party frame (out of combat). Healer choices turn into your best-known spell
-- for them here, so learning a new one (SPELLS_CHANGED) re-applies.
function Click.apply()
    if InCombatLockdown() then Click.pending = true; return end
    Click.pending = nil
    local known = Click.knownSpells()
    for slot = 1, Party.SLOTS do
        local f = Party.members[slot]
        if f then
            for _, btn in ipairs(Click.BUTTONS) do
                for _, mod in ipairs(Click.MODS) do
                    local b, m = btn[1], mod[1]
                    local v = Click.get(m .. b)
                    if Click.HEALER_LABEL[v] then v = Click.healerSpell(v, known) or "none" end
                    if v == "target" then
                        f:SetAttribute(m .. "type" .. b, "target"); f:SetAttribute(m .. "spell" .. b, nil)
                    elseif v == "menu" then
                        f:SetAttribute(m .. "type" .. b, "togglemenu"); f:SetAttribute(m .. "spell" .. b, nil)
                    elseif v == "none" or v == nil then
                        f:SetAttribute(m .. "type" .. b, nil); f:SetAttribute(m .. "spell" .. b, nil)
                    else
                        f:SetAttribute(m .. "type" .. b, "spell"); f:SetAttribute(m .. "spell" .. b, v)
                    end
                end
            end
        end
    end
end

-- Started by Party.init once the party frames exist: the bindings on them, again after combat when a
-- change had to wait, and when you learn a spell (a healer choice may now mean a better one).
function Click.init()
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("SPELLS_CHANGED")
    ev:SetScript("OnEvent", function(_, event)
        if event == "SPELLS_CHANGED" or Click.pending then pcall(Click.apply) end
    end)
    pcall(Click.apply)
end

-- The Click casting page: a section per mouse button, a row per modifier, each a menu of Target /
-- Menu / Nothing / the healer choices / your spells. Saved per class.
ns.pages[#ns.pages + 1] = function(builders, Opt)
    local clicks = setmetatable({}, {
        __index = function(_, k) return Click.get(k) end,
        __newindex = function(_, k, v) Click.set(k, v) end,
    })
    local B = builders(Opt.newPage("click", "Click casting"), clicks)
    B.header("|cff808080On the party frames: what each click does to the member you click. Saved for this class; changes made in combat apply when it ends.|r")
    if Click.HEALER[select(2, UnitClass("player"))] then
        B.button("Healer", "Set up for healing", function()
            local t = Click.bindings()
            t["shift-1"], t["shift-2"], t["ctrl-1"], t["ctrl-2"], t["3"] = "heal", "hot", "dispel", "dispel2", "heal"
            Click.apply()
        end, "Shift + left click: your main heal. Shift + right click: your heal over time. Ctrl + left click: dispel, Ctrl + right click: your other dispel. Middle click: main heal. Left and right click still target and open the menu. Each uses your best rank as you learn it.")
    end
    for i, btn in ipairs(Click.BUTTONS) do
        B.section(btn[2], i <= 2)
        for _, mod in ipairs(Click.MODS) do
            local binding = mod[1] .. btn[1]
            B.dropdown(binding, mod[2], "Target the unit, open its menu, do nothing, or cast one of your spells on it. Main heal, Heal over time and Dispel always use your best rank.",
                Click.DEFAULT[binding] or "none", Click.spellChoices)
        end
    end
end
