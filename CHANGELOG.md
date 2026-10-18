# Changelog

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
