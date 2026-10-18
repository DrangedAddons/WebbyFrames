# Webby Frames

Retail-style player, target, target of target, focus, focus target and pet frames for WoW Forever, built from
Blizzard's own unit frame art (gold ring with the pointed corner, pointed bars). Nothing else is needed.

## Install
Unzip the `WebbyFrames` folder into `World of Warcraft/_classic_beta_/Interface/AddOns`
(delete any older `DFFramesForever` or `WebbyFrames` folder first; settings carry over).

## Use
- `/webby` opens the options (Esc > Options > AddOns > Webby Frames): a General page, an All frames page that
  sets the common options (frame colour, textures, font, numbers, bar extras, aura timers) on every frame at once,
  and one page per frame, in collapsible sections.
- `/webby edit` opens Edit Mode to move the frames: they snap to each other, a frame dropped next to another
  sticks to it and moves with it, and the arrow keys nudge the clicked frame (1px, or 10px with Shift).
- `/webby reset` resets every frame, `/webby test` previews heals, shields and a combat number on your frame,
  `/webby export` and `/webby import` share a profile as text, `/webby errors` lists anything that went wrong,
  `/webby help` lists the commands.
- Everything is saved per Edit Mode layout.

## Options per frame
- **Frame:** scale, name, frame colour (gold, dark, silver, class or any colour; the player's resting glow follows it),
  combo points (target), pet happiness on the portrait's corner or in a level-style badge (pet)
- **Text:** name colour (gold, white, class or reaction), size and outline; bar number size, outline and position
- **Portrait:** the unit's picture or, for players, their class icon
- **Bars:** separate health and power textures, and font (SharedMedia ones too), numbers always / on mouseover / never as totals, percentages or both, smooth bars
- **Health:** class or reaction colour, fade to red as health drops, incoming heals (yours and others'), absorb shields
- **Buffs and debuffs:** on or off and sized separately, only your debuffs, below or above the frame or dragged
  anywhere in Edit Mode, icons per row, how many,
  and the time left as a sweep, numbers, both or nothing (debuffs are edged in their dispel colour)
- **Cast bar and threat** (target, focus): a cast bar built into the frame art, with spell name and icon; Retail-style threat
- Always on: the player's corner accent and raid target markers on the portraits
- **Combat numbers** on the player, target and focus portraits: one switch on the General page
- Always on: combat swords and resting Zzz on the player, PvP badge on the large frames

Dead, ghost and offline units are labelled on the health bar, and hovering a frame shows the unit tooltip.
Party frames are left as they are (Blizzard's, or whichever addon you use for them).

## Credits
Includes LibEditMode by p3lim (unmodified, see Libs/LibEditMode/LICENSE.txt) and the public-domain LibStub.
The frame art, bar fills, masks, elite dragons and resting animation in `Media/` come from
[DragonflightUI](https://github.com/Karl-HeinzSchneider/WoW-DragonflightUI) by Karl-Heinz Schneider
(MIT, see Media/LICENSE-DragonflightUI.txt), as are the art positions.
