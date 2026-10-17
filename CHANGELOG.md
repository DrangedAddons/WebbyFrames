# Changelog

## 0.57
New frames and features
- Party frames: four frames in the target-of-target style, stacked in one movable group, with a leader crown. They show in a party and hide in a raid, replacing Blizzard's party frames.
- Buffs and debuffs on every frame: show buffs / debuffs, only my debuffs, position (below, above, right), icon size, icons per row and how many. Debuffs are bordered by dispel type, timers and stacks work with Forever's protected aura data, and hovering an icon shows its tooltip. On by default for target and focus, debuffs only for party.
- Threat, the Retail way: the target and focus frames glow yellow, orange or red by your threat status, with your threat % in small coloured text by the name.
- Elite, rare and world boss units get the dragon around their portrait.
- Offline players get a greyed-out portrait with the red lightning bolt, as on the party frames, and "Offline" on a grey health bar. Dead and Ghost show on the health bar too.
- Edit Mode snapping: a dropped frame lines up with other Webby frames, Blizzard's Edit Mode frames and the screen's centre lines.

New look
- Every frame uses DragonflightUI's bundled copies of the Retail art (borders, bar fills and masks, name plate, corner accent, combat glow, resting Zzz), because Forever replaces many of the Retail atlases and its mana bar art drew nothing.
- Custom bar textures are trimmed to fit the bar's slot like the default ones.
- The player's corner accent glows with the resting / combat glow, and gives way to the crossed swords (with a dark outline) in combat.
- Target and focus have the portrait on the right, the other frames on the left; only the player has the corner accent.
- PvP badge, combat swords and resting Zzz sit where DragonflightUI puts them, and are always on.
- Level numbers are coloured by difficulty on enemies, like the default UI.

Options
- All options are in Esc > Options > AddOns > Webby Frames (/webby): a General page and one page per frame, in collapsible Layout, Bars, Colours, Buffs and debuffs, Combat and Reset sections. Edit Mode is for moving frames, with Options and Reset buttons on each.
- Health colour is one dropdown (class and reaction / class / reaction / plain) instead of three overlapping checkboxes. Old settings carry over.
- Removed: the portrait side option, the PvP / combat / resting toggles and the threat box.

Fixes
- Target of target and focus target update live (they get no game events, so they are polled while shown).
- Your pet's health bar stays green when you target it.
- Threat updates when your own threat changes, not only the mob's list.
- Smoother energy, rage and focus on the player frame; hovering a frame shows the unit tooltip.
- The frames no longer set an addon `.unit` field, which can stop pings from reading protected unit data.

## 0.56
- First release through DrangedAddons: retail-style player, target, target of target, focus, focus target and pet frames for WoW Forever, editable in Edit Mode.
