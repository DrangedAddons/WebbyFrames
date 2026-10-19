# Changelog

## 1.14.0
A new look for the settings window
- Flat dark panels with an amber accent: a title bar with a glow and an accent line, a soft shadow, and a quick fade in when it opens.
- The page list: the page you're on lit with an accent bar; the frame pages folded under All frames.
- Sections are cards with a chevron, all folded each time the window opens.
- Toggle switches instead of check boxes, slim sliders with an accent fill, flat dropdowns and buttons that light up on hover, colour swatches to match.
- The Click casting page in the same style.

Settings search
- A search box at the top of the window, on every page: as you type, the page is swapped for every matching setting from every page, under its page and section, and they work right there. Clearing it (or picking a page) brings the page back.

## 1.13.0
Click casting, reworked (the page laid out like NeoHeal's)
- Pick a modifier (no modifier, Shift, Ctrl, Alt), then each mouse button's row: what it does, its rank, who it casts on, and Also target.
- Rank: Highest (follows new ranks), Highest -1 (cheaper on mana, also follows) or a fixed rank, for any spell you know in two ranks or more.
- Cast on: the member, their target or their target's target. Also target: target the member as well as casting, in one click.
- The action picker is grouped (the basics, your class's best heals and dispels, then your spellbook by tab), with spell icons and a search box.
- Custom keybinds: add your own (+ Add a keybind, then press the key), up to twelve, each with the same choices as a mouse button; they cast on whoever your mouse is over. Set by the game's secure handler, so they work in combat.
- Resurrect: a choice that resurrects a dead member and does nothing on a living one.
- Reset to class defaults: healers get their main heal on left click, a heal over time on right click, dispels on Shift, resurrect on Alt + left, and target / menu on Ctrl.
- Your bindings show in party members' tooltips (hold a modifier for just its bindings), and can work on your own frames too (On every frame).

New
- Weapon enchants: your weapons' temporary enchants and imbues (poisons, oils, stones, Rockbiter, Windfury...) as icons just before your buffs, with the time left (player page).
- Buffs as timer bars: your buffs (or only the ones you cast) as bars with icon, name and time left, in a block placed in Edit Mode (Webby Buff Bars).
- Druid bars: in a form, the frame's bar can keep your mana and the slim bar show the form's rage or energy (Mana first).
- Dark health bars: Health colour Dark on any frame.
- Health and power bar opacity sliders on every frame. (The red recent-damage trail is clipped to past the end of the health, so it no longer shows through a see-through fill.)
Raid-style party frames
- Party page, Style: Raid style. The party as flat tiles, like Blizzard's raid-style party frames: class-coloured health with incoming heals and absorbs, a slim power bar, name, role, leader, raid marker, ready check / summon / resurrection in the middle, a white edge on your target, the threat colour on whoever has aggro, a pulsing tint for a debuff you can dispel, their debuffs and your heals over time, fading out of range.
- Options: tile width, height and spacing, include yourself, power bars and their texture, health and mana numbers (the same Numbers and Style options as the other frames: always, on mouseover or never; totals, percentages or both), icon size; stacked or side by side and group or role order like the portrait frames. Placed in Edit Mode on its own; shown in a party, hidden in a raid.
- Click casting works on the tiles too.
- More for the raid-style tiles (ideas from EllesmereUI's party and raid frames, used with its author's permission): health colours (class, dark with the missing part in class colour, custom, or green to red by health) with a shade for the missing part; power bars per role (tanks, healers, damage); name colour, position and length; a light edge on mouseover; pets as small tiles beside their owners; show when solo; AFK and dead / offline colours; striped or plain shields, optionally from the right edge so full-health shields show.
- The tiles' dispel highlight is now drawn by the game, so it works in combat too: a gradient, flat tint or edge in the debuff type's colour, pulsing, with the type's icon.
- Big defensive cooldowns (Shield Wall, Divine Shield, Pain Suppression, Ice Block, Barkskin and more) as a large icon in the middle of the tile.
- Both party styles: missing buffs (icons of buffs a member lacks that you can cast, a paladin blessing by role), a healer mana list placed in Edit Mode, tooltips always / out of combat / never, and how faded out-of-range members are.
- Every frame: Dispel glow for debuffs you can dispel, or any dispellable one.
- Sample party: five made-up members in every state (aggro, a heal coming in, a debuff you could dispel, dead, out of range), in Edit Mode, from the Party page's Preview button, or /webby party. The Preview button works for the portrait frames too: four made-up members with names, health, class portraits and a hunter's pet.
- Also in this version (from 1.12.4):
- Dispel glow: only for debuffs you can dispel, never on enemies, and on every frame by default (player, target, focus, their targets, pet, party). It now sits behind the frame's bars, icons, level and text instead of over them.
- /webby glow lists each frame's debuffs as the game reports them.

## 1.12.3
- Dispel glow, done like the resting glow: when you or a party member has a debuff someone can dispel, the frame takes its colour (magic blue, curse purple, disease brown, poison green), border and portrait ring included, and pulses like the resting glow. On your own frame the resting / combat glow takes the colour too. On by default for you and the party.
- /webby glow: what each frame's dispel glow sees.

## 1.12.2
- Dispel glow much more visible: the frame's border, portrait ring included, turns the dispel colour (magic blue, curse purple, disease brown, poison green) with a glow on and just round it. It blinks hard four times when the debuff lands, then pulses deeply every 0.8 seconds, back and forth between the frame's own colour and the dispel colour.

## 1.12.1
- Fixed: buffs and debuffs not showing in 1.12.0, and the dispel glow not flashing or pulsing (the game's aura icons refuse script hooks; the flash, pulse and tooltip moving now run elsewhere).

## 1.12.0
- Every Webby Frames tooltip (frames, buffs and debuffs, pets, icons, settings, minimap button) now shows in the game's default tooltip spot.
- Dispel glow: brighter, flashes three times when a debuff you can dispel lands, then pulses until it's gone.
- The party frames and click casting are now their own modules (Party.lua and ClickCasting.lua), loaded with the addon as before. Nothing to install separately.
- Party: the "Their targets" option is gone, along with the small target bars beside each member.
- Fixed: since 1.10.1, incoming heals, absorbs, the damage trail and damage prediction were off unless you had switched them on yourself (their defaults had slipped into a comment).

## 1.11.0
Party frames, part two
- Layout: stacked or side by side (side by side leaves room for each member's buffs, debuffs and target).
- Order: as in your group, or by role (tanks, healers, damage).
- Pets (on by default): each member's pet as a small copy of the party frame under theirs (same border, round portrait, health and power bars, in the frame's colour), only for members with a pet out.
- Their targets: what each member is targeting, in a small bar to their right. Both clickable.
- Status on the portrait: summons (pending, accepted, declined), incoming resurrections and members in another phase, after the ready check.
- Threat glow round a member about to pull or holding aggro, following the target frame's threat options (on when they show a glow, in their threat colours).
- Click casting: a new Click casting page. Each mouse button, alone or with Shift, Ctrl or Alt, can target, open the menu, do nothing or cast one of your spells on the member you click. Saved per class.
- Click casting for healers: Main heal, Heal over time, Dispel and Second dispel choices that always cast your best rank of your class's spell, and a "Set up for healing" button (Shift-click heals, Ctrl-click dispels, middle click heals).
- Changes that move members between slots, and click bindings changed in combat, wait for combat to end (the game doesn't allow them during it).

## 1.10.1
- In Edit Mode every frame's buffs and debuffs fill with sample icons (Blizzard's own aura preview), so you can see how they sit, party frames included.
- Buffs and debuffs "Right of the frame" (party, target of target, focus target, pet): two rows beside the frame, at most a row of buffs and a row of debuffs, the ones that matter first, so nothing spills over the next frame. The party's default, with the members 6 px apart.
- Debuffs on every frame are in Blizzard's own unit frame order: the ones that matter (boss, crowd control, priority) come first. Nothing is left out.
- Buffs and debuffs, on every frame's page:
  - Style: Retail (on a friend, only the buffs you put on them, your heals over time and shields; on an enemy, all their buffs) or Everything. The party starts on Retail, the other frames on Everything.
  - Dispel glow: the frame glows in the dispel colour when the unit has a debuff you can dispel. Works in combat. On for the party, off for the rest until you turn it on.
  - Bigger own debuffs: your own debuffs first and bigger (not on the player and pet frames). Off until you turn it on.

## 1.10.0
- Frame colour "Class colour" on the target, focus, their targets and the party is now the class of whoever the frame shows (NPCs stay gold). The player and pet frames keep your own class colour.

Party frames
- Webby party frames: the four members in the same art as the small frames, stacked under each other, with health and power, name, portrait, debuffs, incoming heals and shields, raid markers, a role icon, the leader's crown and the ready check. Members out of range fade out.
- Frame colour for the party: gold, or each member in their own class colour.
- A Party page with the small frames' options plus spacing and range fade (the role icons and leader crown are always shown); move them as one in Edit Mode (they show you as a stand-in there). Turned on by default; turn them off on the General page to get Blizzard's back (after a /reload).

## 1.9.3
- Options window: the frame pages fold away under All frames; click its + to show them (it remembers). Frames turned off on the General page drop out of the list.
- Every section starts closed, so each page opens as a short list of headings.

## 1.9.2
- Threat colours are Green to red or Blizzard's. An older saved choice (status, colourblind, class) draws as the gradient.
- The frames do less work while they are shown: the cast bar, damage trail, heal and absorb overlays, threat and the options window. What you see is the same.

## 1.9.1
- Credits read "Webby, Lexible and Dranged" everywhere: the addon list, the options window, the AddOns options page and the README.

## 1.9.0
- The options are now a window of their own (`/webby`): the same pages, sections and options as before, but it no longer takes over the screen the way Esc > Options does, so it can stay open while you play, target things or use Edit Mode. Drag it by its edge; it remembers where you put it, and Esc closes it.
- Esc > Options > AddOns > Webby Frames now describes the addon and has buttons that open the options window and Edit Mode.
- Minimap button (the web icon): click it for the options, right-click it for Edit Mode, drag it round the minimap. It can be turned off on the General page.

## 1.8.2
- Credits read "Webby, Lexible & Dranged" everywhere: the addon list, the General options page and the README.

## 1.8.1
- Colour swatches: custom frame, enemy NPC and fade stop colours show as a swatch of the colour itself; click it to change the colour (as in CastCount).
- Combo points can be dragged anywhere in Edit Mode, like the druid mana bar.
- Credits: made by Lexi and Chris (addon list, General options page, README).
- Fixes for the 1.8.0 options: the two-to-a-row checkboxes take clicks, and opening a section no longer hides the rest of the page.

## 1.8.0
Tidier options
- Checkboxes that belong together now sit side by side, two to a row.
- Options that depend on another one only appear while it's on (the fade-to-red colours and stops, the custom colour pickers, the cast bar's name and icon, the spell cost shading).
- "Health" is now "Health bar", with clearer names: Health colour, Enemy NPC colour, Fade to red as health drops, Shields and heal absorbs, Show recent damage, Preview spell damage.
- The name and number text options are gone (the defaults are kept), and smooth bars are always on. Your own name always shows on the player frame.
- Frame colour: Gold, Class colour or Custom.
- Threat colours: Green to red, or Blizzard's.

Class options
- Druid mana is only offered to druids, and the bar can be dragged anywhere in Edit Mode.
- Combo points are only offered to rogues and druids, and for druids only show in cat form.

## 1.7.14
- Show or hide frames: target of target, focus, focus target and pet can each be turned off (General page, or "Show this frame" on the frame's own page). A frame that's off stays hidden, in Edit Mode too. The player and target frames are always on.

## 1.7.13
- The Retail corner accent's black backing no longer spills onto the green frame border: it only shows on the inner side, toward the portrait.

## 1.7.12
- The Forever corner accent fits the frame: a hairline black edge along its curve and a 1px black line along its bottom are built into its art, so the portrait no longer shows in the cracks beside it, and its bottom arm tapers away like its top one.
- `/webby corner x y` fine-tunes where the corner accent sits (right / up, in pixels, halves too); `/webby corner` alone resets it.

## 1.7.11
- Damage prediction no longer hangs on after fast spells: a hit that lands just before the cast finishes now clears it too, and it waits at most 1.5 seconds for a spell in flight.

## 1.7.10
- Damage prediction clears the moment the spell lands (the target's health moves, or it's hit, missed or resisted), instead of lingering and looking like another cast.
- Fixed the "blocked from an action" Disable / Ignore popup that 1.7.9 could bring up (it listened to the combat log, which addons may not on this client).

## 1.7.9
- Damage prediction stays on the bar after the cast while the spell is on its way, until it hits, misses or is resisted (at most 3 seconds). A failed or interrupted cast still clears it at once, as does changing target.

## 1.7.8
- No threat on players: enemy players, their pets and totems never show the threat glow or %, so it stays out of the way in PvP.

## 1.7.7
- Damage trail (every frame and All frames, on by default): when health drops, the part just lost stays in red for a moment, then slides away, so you can see how big each hit was.
- Damage prediction (target and focus, on by default): while you cast at an enemy, the damage your spell will do (from its tooltip) shows lighter at the end of its health. `/webby cost` shows what it read.

## 1.7.6
- Corner accent (Player page): Retail's pointed corner, or Forever's older rounder one (no longer in the game, so it's bundled). The frame colour and the resting / combat glow follow either.

## 1.7.5
- Spell cost shade set to darker now darkens only the cast preview; the flash when a spell goes off stays light.

## 1.7.4
- Spell cost shade (Player page, under Spell cost): show the cost lighter or darker than the bar, and by how much.

## 1.7.3
- Druid mana: in bear or cat form, your mana shows in a slim bar just under the player frame (Player page, on by default).
- The player's resting and combat glows pulse the way the default player frame's do, in your frame colour.
- Spell cost (Player page, on by default): while you cast, the part of your mana bar the spell will use shows lighter; and when any spell or ability goes off (instants too), what it spent flashes past the end of the bar. `/webby cost` shows what it found.
- Colour the Zzz (Player page): the resting Zzz takes the frame colour.
- Coloured resting glows look truer: richer colour, and yellow-greens lean green (the hunter's glow was coming out yellow).
- EllesmereUI: the frames can be moved in its Unlock Mode as well as in Edit Mode. Both save to the same place.

## 1.7.2
- Enemy levels are coloured by difficulty again (grey, green, yellow, orange, red), and unknown levels show the skull in the level badge.
- Name and number colours: a Custom name colour and a Number colour, each with a colour picker. The outline options are gone.
- The Pet page no longer offers the portrait style (pets always show their picture).
- The All frames page now has the same sections, in the same order, as each frame's page.
- Clearer tooltips throughout, `/webby help` lists every command, and the threat colours are described correctly (blue: about to lose aggro, purple: holding it securely).
- Behind the scenes: old code for removed features and older clients is gone.

## 1.7.1
- The threat % keeps updating while you hold aggro: it's then your threat against the next highest in your group (pets included), so after a re-pull it climbs again instead of standing still. It's also re-read five times a second, since the game sends few threat updates while you tank.
- Simpler threat number: always the percentage, shown as just the number beside the raid marker (default) or in the box above the name. The differential and the round badge are gone; a badge setting reads as just the number.

## 1.7.0
Threat, reworked (target and focus)
- Threat is worked out the way Foofi's ThreatDisplay does it. Number shows: Percentage (your raw threat against the mob's current target: about 110% is a melee pull, 130% a ranged pull), Differential (your threat minus the highest in your group: +0 when you're top, -500 when someone has 500 more), or Both (120% | +500).
- Threat colours for the number and the glow: Status (yellow safe, red about to pull, blue tanking, purple losing aggro), Colourblind-friendly, Gradient (green to red), your class colour, or Blizzard's.
- Where the number sits: a round badge like the level circle beside the raid marker (new default), just the number in that spot with no ring or backing, or the box above the name.
- `/webby threat` prints what the game reports for your target's threat (yours, your pet's and your group's) and the differential.

## 1.6.2
- Fixed the Lua error ("attempt to call a nil value") every time an options section was opened or closed on Forever: the section headers now handle their own clicks.

## 1.6.1
- Fixed the Lua errors ("Implement GetExtent") the options pages threw on Forever whenever they were opened or a section was opened or closed.

## 1.6.0
New options
- Text: name colour (gold, white, class colour or reaction colour), name size and outline; bar number size, outline and position (centre, left or right). On every frame page and the All frames page.
- Portrait: the unit's picture or, for players, their class icon.
- Buffs and debuffs: rows can grow to the right or to the left, the gap between icons (0 - 10px), and the stack count size.

Threat
- The threat % sits in its own small box above the name strip, dark inside with the frames' line style round it, so it's easy to read even at 100% on a red enemy name strip. The name keeps its full width.

Fixes
- No more errors when changing the custom fade stops or picking their colours. The stop colour buttons work while Fade style is Custom stops, and dragging in the colour picker is smoother.

Versions
- Small updates now go 1.6.1, 1.6.2 ...; big ones move on to the next number (1.7.0).

## 1.5
- Custom health fade: under Fade to red, choose Automatic (the class-aware fade) or Custom stops. Custom gives three stops, each a health % and a colour you pick (yellow at 60%, orange at 35% and red at 20% to start; 0% turns a stop off), and Smooth blend to blend between stops or switch colour right at each one. On every frame page and the All frames page.

## 1.4
- Threat is now a choice on target and focus: glow and number, glow only, number only, or off. (If you had threat turned off, it stays off.)
- Mobs someone else has tagged stay plain grey: no fade to red on their health bar, and the name strip behind their name is grey too.

## 1.3
- Fade to red: shamans, mages and warlocks each have their own route to red, so they never look like one another while their health drops. Shaman stays dark (navy, deep plum, crimson), mage stays light (pale sky, lilac, coral), warlock stays a bright violet (violet, magenta). The other classes keep the colour-wheel fade.

## 1.2
- Cleaner Fade to red: no more grey, washed-out look. Each colour now turns to red round the colour wheel the short way, staying bright: green goes through yellow and orange like Blizzard's bars, blue classes through purple and pink, priest white warms through pink. Full colour at full health, red from 25% down.

## 1.1
- Enemy NPC health colour: hostile NPCs can be red (as before), green or any colour you pick, so Fade to red shows their health dropping. Per frame, or for every frame on the All frames page. Neutral NPCs stay yellow.
- New frame colour, "The unit's class colour": the frame art takes the class colour of whoever the frame shows (target, focus and so on), changing with them. NPCs keep the gold art.

## 1.0
New features
- Cast bars on target and focus, built into the frame: they share the mana bar's bottom border line, use the frame art's own border, run on under the portrait ring to the level badge, and take the frame's bar texture and font. Spell icon and name, coloured by cast type (yellow cast, green channel, grey can't interrupt, red interrupted). They also show when you target someone who is already casting.
- Threat, the Retail way: the target and focus frames glow yellow, orange or red by your threat status, with your threat % in small coloured text by the name.
- Buffs and debuffs on every frame, working in combat too (through Blizzard's aura container): buffs and debuffs on or off and sized separately, only your debuffs, below the frame, just above it, or dragged anywhere in Edit Mode, icons per row, how many, and the time left as a sweep, countdown numbers, both or nothing. Debuffs are edged in their dispel colour; hovering an icon shows its tooltip. On by default for target and focus.
- Health bar extras: incoming heals (yours and other players' in two greens) and absorb shields past the end of the health fill, and healing absorbs eating back into it (red). `/webby test` previews them on your frame.
- Smooth bars, and an optional fade to red as health drops, from whichever health colour you picked.
- Combat numbers: damage, heals and misses pop up over the player, target and focus portraits, bigger on crits. One switch on the General page.
- Frame colour: gold as drawn, dark, silver, your class colour or any colour from the colour picker. The player's resting glow takes the colour too.
- Separate health and power bar textures (SharedMedia ones included), per frame.
- An All frames options page that sets the common options (frame colour, textures, font, numbers, bar extras, aura timers) on every frame at once.
- Profiles: export every frame's options and positions as text and import it again, here or on another character (General page, or `/webby export` / `/webby import`).
- Raid target markers on the portraits, a combo point arc round the target's portrait (rogues, druids), and party leader crowns.
- Hunter pet happiness on the pet frame: on the portrait's corner or where a level badge would be, with the pet's diet, damage, loyalty and level in its tooltip.
- The pet's health bar can match the player frame's colour (your class colour, say) or stay plain green.
- Elite, rare and world boss units get the dragon around their portrait; offline players get a greyed-out portrait with the lightning bolt.

Edit Mode
- Frames snap to each other, to Blizzard's Edit Mode frames and to the screen's centre lines, and the selection box fits each frame's art exactly.
- Sticky frames: a frame dropped next to another (within 10px) attaches to it and moves with it, e.g. focus target with focus. Drop it further away to free it.
- Clicking a frame just selects it; the arrow keys nudge it 1px (10px with Shift). All options are in the options pages.

New look
- Every frame uses DragonflightUI's bundled copies of the Retail art (borders, bar fills and masks, name plate, corner accent, combat glow, resting Zzz), because Forever replaces many of the Retail atlases.
- Bars fill exactly the sections of the frame art, custom textures included, and the portrait ring covers their ends cleanly.
- The PvP badge is Forever's own small faction shield by the level circle (with the flag timer on hover).
- The player's corner accent glows with the resting / combat glow and gives way to the crossed swords in combat.
- Target and focus have the portrait on the right, the other frames on the left.
- Level numbers are coloured by difficulty on enemies, like the default UI.

Options
- All options are in Esc > Options > AddOns > Webby Frames (/webby): General, All frames, and one page per frame in collapsible sections. Options that depend on another are indented under it and greyed out while it's off.
- Rage, energy and other non-mana power always show plain numbers, never percentages.
- Health colour is one dropdown (class and reaction / class / reaction / plain). Old settings carry over.
- Removed: the portrait side option, the corner accent and raid marker switches (always on), the PvP / combat / resting toggles, the threat box, the range fade and the `/webby atlas` dev command.
- Party frames are left to Blizzard or your party frame addon.

Fixes
- Sturdier updates: one part of a frame failing can't stop the rest; `/webby errors` lists anything caught.
- Target of target and focus target update live.
- Threat updates when your own threat changes, not only the mob's list.
- Smoother energy, rage and focus on the player frame; hovering a frame shows the unit tooltip.
- The frames no longer set an addon `.unit` field, which can stop pings from reading protected unit data.

## 0.56
- First release through DrangedAddons: retail-style player, target, target of target, focus, focus target and pet frames for WoW Forever, editable in Edit Mode.
