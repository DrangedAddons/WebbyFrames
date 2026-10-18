# Webby Frames

Retail-style player, target, target of target, focus, focus target and pet frames for WoW Forever, built from
Blizzard's own unit frame art (gold ring with the pointed corner, pointed bars). Nothing else is needed.

## Install
Unzip the `WebbyFrames` folder into `World of Warcraft/_classic_beta_/Interface/AddOns`
(delete any older `DFFramesForever` or `WebbyFrames` folder first; settings carry over).

## Use
- `/webby` opens the options (Esc > Options > AddOns > Webby Frames): **General**, **All frames** (sets the
  common options on every frame at once) and one page per frame, in collapsible sections.
- `/webby edit` opens Edit Mode to move the frames: they snap to each other, a frame dropped next to another
  sticks to it and moves with it, and the arrow keys nudge the clicked frame (1px, or 10px with Shift).
- With EllesmereUI, the frames can also be moved in its Unlock Mode (same saved positions).
- Everything is saved per Edit Mode layout. Profiles can be exported and imported as text (General page).

Commands: `/webby` (options), `/webby edit`, `/webby reset`, `/webby test` (preview heals, shields and a combat
number), `/webby threat` (what the game reports for your target's threat), `/webby export` / `import`,
`/webby errors`, `/webby help`.

## Options per frame
- **Frame:** show or hide (target of target, focus, focus target, pet), scale, name, portrait (picture or class
  icon), frame colour (gold, your class colour or any colour; the player's resting glow follows it), corner
  accent and spell costs (player), combo points (target; rogues, and druids in cat form), druid mana in bear
  and cat form, movable in Edit Mode (player; druids), pet happiness (pet)
- **Bars:** health and power textures, font (SharedMedia ones too), numbers always / on mouseover / never as
  totals, percentages or both
- **Health bar:** class or reaction colour, enemy NPC colour, fade to red as health drops (automatic or your own
  stops), incoming heals, shields and heal absorbs, recent damage, spell damage preview (target, focus)
- **Buffs and debuffs:** buffs and debuffs sized separately, only your debuffs, below / above the frame or
  dragged anywhere in Edit Mode, row direction, gap, per row, how many, stack size, and time left as a sweep,
  numbers, both or nothing
- **Cast bar and threat** (target, focus): a cast bar built into the frame art (spell name and icon), and
  threat as a glow and / or a % (by the raid marker or in a box), green to red or in Blizzard's colours

Always on: the player's corner accent, raid markers, combat swords and resting Zzz, the PvP shield, enemy level
colours (and the skull for unknown levels). Combat numbers on the player, target and focus have one switch on
the General page. Mobs tagged by someone else stay grey. Party frames are left to Blizzard or your party addon.

## Credits
Made by **Webby**, **Lexible** and **Dranged**.

Includes LibEditMode by p3lim (unmodified, see Libs/LibEditMode/LICENSE.txt) and the public-domain LibStub.
The frame art, bar fills, masks, elite dragons and resting animation in `Media/` come from
[DragonflightUI](https://github.com/Karl-HeinzSchneider/WoW-DragonflightUI) by Karl-Heinz Schneider
(MIT, see Media/LICENSE-DragonflightUI.txt), as are the art positions. Threat maths follow Foofi's ThreatDisplay.
