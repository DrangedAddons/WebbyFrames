# Webby Frames

Retail-style player, target, target of target, focus, focus target, pet and party frames for WoW Forever, built from
Blizzard's own unit frame art (gold ring with the pointed corner, pointed bars). Nothing else is needed.

## Install
Unzip the `WebbyFrames` folder into `World of Warcraft/_classic_beta_/Interface/AddOns`
(delete any older `DFFramesForever` or `WebbyFrames` folder first; settings carry over).

## Use
- `/webby` opens the options (Esc > Options > AddOns > Webby Frames): a General page and one page per frame,
  in Layout, Bars, Colours and Combat sections.
- `/webby edit` opens Edit Mode to move the frames; each frame's dialog has Options and Reset buttons.
- `/webby reset` resets every frame.
- Everything is saved per Edit Mode layout.

## Options per frame
- Scale, portrait side (all but the player), show name, corner accent
- Bar text: always / on mouseover / off, and totals / percentages / both
- Bar texture and font (including anything registered with SharedMedia)
- Health colour: class colour for players and reaction colour for NPCs (default), class only, reaction only, or plain green
- Health colour fade: green to red, or your colour to red, as health drops
- Target and focus: interrupt flash, and threat the Retail way (the frame glows by threat status, with your threat % by the name)
- Always on: combat swords and resting Zzz on the player, PvP badge on the large frames

Dead, ghost and offline units are labelled on the health bar, and hovering a frame shows the unit tooltip.

## Credits
Includes LibEditMode by p3lim (unmodified, see Libs/LibEditMode/LICENSE.txt) and the public-domain LibStub.
The frame art, bar fills, masks, elite dragons and resting animation in `Media/` come from
[DragonflightUI](https://github.com/Karl-HeinzSchneider/WoW-DragonflightUI) by Karl-Heinz Schneider
(MIT, see Media/LICENSE-DragonflightUI.txt), as are the art positions.
