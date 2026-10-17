# Changelog

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
