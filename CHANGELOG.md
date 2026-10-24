# Changelog

## 1.2.0
- First release for the live WoW Forever client. The beta client is no longer targeted; install under `_forever_`.
- The PvP flag shows again when you walk into contested territory, and becoming flagged plays the game's PvP update sound.
- The player's PvP flag timer is a small white number just left of the shield (5m, 4m, 3m, 2m, 1m, then 59 down). It shows only while the five-minute countdown is actually running. The mouseover tooltip is gone.
- Faster in combat without changing how the frames look: heal and shield overlays keep their style between health ticks, snow and blizzard flakes only move when they have shifted, and the party range and healer mana tickers stay off until they are needed.
- Heal and shield glows (pulse, shimmer, snowglobe, blizzard) start again after a reload without toggling them in the options.

## 1.16.51
- The PvP flag on the player (and target / focus) shows again when you become flagged by walking
  into contested territory. `UNIT_FACTION` had stopped refreshing the icon after the 1.16.50 event
  split.
- Becoming PvP flagged plays the game's PvP update sound. A reload while already flagged stays quiet.
- The player's PvP flag timer is a small white number just left of the shield (5m, 4m, 3m, 2m, 1m, then 59 down). It shows only while the five-minute countdown is actually running, not while a PvP zone holds the timer at 5:00. The mouseover tooltip is gone.

## 1.16.50
- Faster in combat without changing how the frames look: heal and shield overlays keep their style
  between health ticks, snow and blizzard glows only move a flake when it has shifted about a pixel,
  name / portrait / level / faction events no longer repaint the whole frame, and the party range and
  healer mana tickers stay off until they are needed.
- Heal and shield glows (pulse, shimmer, snowglobe, blizzard) start again after a reload without
  toggling them in the options. The style cache still skips texture work; it no longer skips ensuring
  the glow is alive.

## 1.16.49
- Other players, friendly or hostile, keep their class colour. Health colour and Fade to red do not paint over it.
- Fade to red is one switch. The custom stops, colours and blend are gone. Above 66% the bar keeps its colour, then it blends through yellow, orange at 33% and red at 1%.
- The spell cost on the power bar tints its texture and colour the way heals and shields do, instead of washing out white. Glow: Soft pulse, Shimmer, Snowglobe or Blizzard, with a strength.

## 1.16.48
- The threat number is the game's own: the raw percent until you are tanking (about 110% pulls in melee, 130% at range), then the game's lead over the next person, which keeps climbing past 255%.
- Solo, threat hides while you are the only one on the mob. A pet with threat shows it again. In a group it shows as usual.
- The level number on the player and target frames is one point larger.
- `/webby threat` is gone.

## 1.16.47
- Recent damage has its own look, under that switch on every frame, the portrait party and All frames: texture (the health bar's own, or any SharedMedia texture), colour (red until you pick one), delay (how long a hit stays, 0.4s) and opacity.

## 1.16.46
- Channelled spells preview one hit at a time (a missile, a wave, a tick) instead of the whole cast: it moves down the health as each one lands, with the recent damage trail showing the hit that just did. Channelled heals the same.

## 1.16.45
- The shield number follows each frame's Numbers setting, as the health number does: always shown, on mouseover, or never.

## 1.16.44
- Channelled spells get previews too: while you channel at an enemy (Arcane Missiles, Mind Flay, Penance), its whole damage is shaded off the end of the target's health (and focus, when that's the same mob). While you channel a heal (Penance), its whole healing shows after the incoming heals, on your target when it's friendly, else on you. The whole amount is read from the tooltip (each hit times the hits: waves, every second for so long). Gone when the channel ends.

## 1.16.43
- Shield number on mouseover: with the mouse on the health bar, the shield's amount shows at the bar's right end, in the shield's colour (nothing when there's no shield). Whatever the Numbers setting.

## 1.16.42
- Shields simplified: always in the missing health after the health, and when there's more shield than that, the rest grows back over the health from the bar's right end. The Placement and Overshield options are gone.
- The shield Preview shows a shield that fits in the missing health, without the extra slice over the health.

## 1.16.41
- Shields stay inside the health bar, in two parts: in the missing health after the health, and what doesn't fit drawn back over the health, so the whole shield always shows, even at full health.
- Shield placement (in the Shields section): Overlay (the above), Overlay reverse (all of it back over the health), Overlay reverse (full), Right edge or Left edge (all of it over the whole bar from that end). Overshield, for Overlay: Always, From left (the extra from the bar's start) or Never (missing health only).
- The border glow no longer spills past the health bar's ends, and keeps its shape on long heals and shields (its ends at their true size, the middle stretched between them).
- Tidier inside: the unused heal absorb and second heal bars are gone.

## 1.16.40
- Heal absorbs are off for now, until they're confirmed in the game: no longer drawn on the frames, and their settings (the Heal absorbs section, its colour and preview) are gone. The Shields section's switch is now Show shields.

## 1.16.39
- Tidier settings: the long Health and power list is split into small sections of their own, on every frame, the party and All frames. Health and power (textures, font, numbers, opacity, recent damage), Health colour (with Fade to red), Incoming heals, Shields and Heal absorbs, each with its switch and its looks. The player's spell costs, mana tick and druid mana have their own Mana and spell costs section.

## 1.16.38
- Incoming heals are one heal now, yours and everyone else's together, with one set of options: Heal texture, Heal colour, Heal opacity and the glows. Others' heal colour is gone, and a glow or border covers the whole heal in one piece.

## 1.16.37
- A new glow, Blizzard: a snowstorm, lots of small flakes driven down and across by the wind.
- Heal border glow and Shield border glow: Blizzard's spell alert glow round incoming heals or shields, in their colour. With any glow, or on its own; Glow strength sets it too. On every frame, the portrait party and the raid-style tiles.
- Snowglobe flakes can no longer grow huge.

## 1.16.36
- Shimmer: twice as fast, a sweep about every second.
- Snowglobe: twice the flakes, and they float now (bobbing and drifting, sinking slowly) instead of falling.

## 1.16.35
- Glows look clearly different from each other on a narrow heal or shield. Shimmer: a band of light sweeps end to end across the heal or shield itself, at any width, then rests. Snowglobe: the flakes fall and sway visibly, at a steady brightness. Soft pulse: fades fully in and out, a little faster.

## 1.16.34
- Shield and heal glows: no longer turn the heal or shield pure white. The glow is now a brighter shade of the bar's own colour, with paler flakes and shimmer.
- Turning a glow off and back on now starts its animation again, and it restarts when the heal or shield comes back after emptying.
- Snowglobe: more, bigger flakes.
- A glow that fails now says why in chat, once, instead of failing silently.

## 1.16.33
- Shield glow and Heal glow: Soft pulse (a soft glow breathing in and out), Shimmer (a band of light sweeping across) or Snowglobe (glowing flakes drifting down inside, swirling up whenever the shield changes or a heal comes in), each with a Glow strength. On every frame, the portrait party and the raid-style tiles; the Preview tickboxes show them too.

## 1.16.32
- Heal and shield previews: the recent damage trail no longer paints the drop to the preview's 60% health red. It's hidden while a preview is on.

## 1.16.31
- Heal and shield previews on the live frame: Your heal, Others' heal, Shield and Heal absorb each have a Preview tickbox beside their colour. Tick any one, or any mix, and it shows on the frame itself (at 60% health), in the look you're setting, changing as you change it. Untick it, or close the settings, to go back. Replaces the all-in-one preview bar.

## 1.16.30
- Incoming heal looks (under Incoming heals, every frame and the portrait party): Heal texture, Heal colour (yours), Others' heal colour and Heal opacity.
- A live Preview under the heal and shield options: a health bar with incoming heals, a shield and a heal absorb, drawn as you have them set, changing as you change them.

## 1.16.29
- Shield looks (under Shields and heal absorbs, every frame and the portrait party): Shield texture (the health bar's, Blizzard's stripes, or any texture), Shield colour, Shield opacity and Heal absorb colour. Raid-style tiles: Shield look takes any texture too, with a Shield colour and opacity.
- The settings window opens as you left it: the same page, the same sections open, the frame pages under All frames shown or folded, and each page's scroll position. Kept after a /reload.

## 1.16.28
- Names in Korean, Chinese or Cyrillic letters show properly instead of boxes. Fonts are now set as a family that keeps the game's own fonts for those alphabets, with your chosen font (or the default) for Latin letters. On the unit frames, the raid-style tiles and the party pets.
- Raid-style tiles and party pets: setting Font back to Default goes back to the original font.

## 1.16.27
- Health colour: a mob someone else tags turns grey again on your target and focus frames (the held colour is read again when its flags change).

## 1.16.26
- Cast bars: the ending starts the moment a cast is over, holds a beat and eases out smoothly, and plays once (Fade used to flicker). More endings: Flash, Blizzard glow, Shine and Sparkle burst, in a Flash colour of your own; an interrupted cast in the interrupted colour. A finished channel fades from where it ended.

## 1.16.25
- Cast bars (target, focus): they fade out when a cast ends instead of vanishing. When a cast ends: Fade, Flash and fade (a finished cast fills the bar and flashes bright as it fades; an interrupted one flashes red), or Off. Fade time to choose.
- Cast bar looks: a spark on the fill's edge, its own texture (or the health bar's, as before), and your own colours for casting, channelling, can't interrupt and interrupted.

## 1.16.24
- Combat numbers: hits were dropped before they could draw, so nothing showed, crit or not. The font is set before the text again.

## 1.16.23
- Combat numbers: crits redone from the 390 clip. A crit starts small and faint, below centre. It grows and becomes solid while it rises, then settles back to a size still above a normal hit. It does not use a scale animation.

## 1.16.22
- Combat numbers: a critical hit changes font size around its centre instead of using a scale animation. The scale was pinned to a corner of the text, so the pop slid in from the right.

## 1.16.21
- Combat numbers: a critical hit scales from the middle of the number. It was growing from a corner, so the pop looked offset to the right.

## 1.16.20
- Combat numbers: a critical hit no longer follows Straight, Fountain or Static. It slams in at double size, shrinks back over a fifth of a second, and stays in the middle of the portrait until it fades, the way Blizzard's combat text does.

## 1.16.19
- Combat numbers: nature damage, including poison, is a darker green. Heals stay the bright green.

## 1.16.18
- Combat numbers: damage is white. Holy, fire, nature, frost, shadow and arcane each use their own colour. A school the game hides stays white. Heals stay green.

## 1.16.17
- Combat numbers: after a critical hit pops, it sits still for a moment, then its usual rise, arc or fade carries on. A crit heal stays readable before it moves.

## 1.16.16
- Combat numbers: a critical hit pops a little harder, then stays at full strength a moment longer than a normal hit before it fades. `/webby crit` plays a normal hit and then a crit on your portrait.

## 1.16.15
- Combat numbers: Target numbers, under Combat numbers on the General page. On to start with. Off, the target frame draws no combat numbers and runs none of that animation. You and your pet are unchanged. Every hit on a target shows, yours or not; the game no longer says which.

## 1.16.14
- Combat numbers: Straight and Fountain start just below the centre of the portrait. A critical hit pops large, then shrinks to a size a little above a normal hit, still inside the portrait.

## 1.16.13
- Combat numbers: Number style, under Combat numbers on the General page. Static sits in the middle and fades, as before. Straight rises up the portrait. Fountain arcs up, alternating left and right. Straight and Fountain stay inside the portrait. Player, target, focus and pet.

## 1.16.12
- Combat numbers on the pet frame: damage, heals and misses pop up over its portrait, the same as on the player, target and focus. Still the one switch on the General page.

## 1.16.11
- Click casting can be turned off (Click casting page). While it is off, none of it runs: no spellbook checks, no listeners. Clicks go back to targeting and the menu. Your bindings are kept, and come back when you turn it on.
- Buff bars: the per-frame update only runs while a bar is counting down in plain numbers.

## 1.16.10
- Party frames off: nothing of theirs keeps running. The portrait frames and the raid-style tiles stop listening, and the range, missing-buff and healer-mana checks stop. Turning the party frames back on starts that again. Click casting on your other frames is unchanged.

## 1.16.9
- Player glow: a buff on you no longer lights it. Gaining a magic buff (fortitude, intellect, a blessing) was read as a debuff you could dispel, so the frame glowed until that buff fell off. Casting one also starts the mana tick, which is why the glow seemed to follow the five second rule.

## 1.16.8
- Mana tick: a sparkle trail. Little stars are left behind as the light crosses the bar, twinkling, drifting and fading out (Sparkle trail, on to start with).
- More sparkle shapes: Raid star, Diamond and Soft glow, for the sparkle and the trail alike.

## 1.16.7
- Mana tick is now just the five second rule: when a spell that costs mana goes off, the light crosses your mana bar over 5 seconds, growing and sparkling, and stops at the end. The regen tick sweeps are gone. Options: Light colour, Light size, Sparkle, Sparkle texture.

## 1.16.6
- Mana tick: works when the game hides your mana from addons. The five second rule now starts when a spell that costs mana goes off, the ticks come from the mana changes themselves, and the light rests once they stop (full mana).

## 1.16.5
- Mana tick options (player page): the five second rule and the regen ticks can each be turned off, each has its own colour, the light's size, the sparkle on or off, and the sparkle's shape (Star, Starburst, Ring, Spark, Flare).

## 1.16.4
- Mana tick (player page): a light that runs along your mana bar. After you spend mana it crosses the bar over 5 seconds in white (the five second rule); then in blue it sweeps the bar every 2 seconds, growing as it goes and sparkling at the end as each mana tick lands. Shows while you're below full mana.

## 1.16.3
- Spell costs: pick the textures too. Cost texture for the cast preview and Trail texture for the trail (your power bar's own fill to start with; SharedMedia textures listed too).

## 1.16.2
- Spell costs: pick the colours yourself. Cost colour for the cast preview (when Shading is set lighter) and Trail colour for the trail of what was just used; both white to start with (player page, Health and power).

## 1.16.1
- Spell costs: the trail of what a spell just used shows again, in combat too. It now follows your power a moment late, as the health bar's recent damage does, instead of comparing amounts the game can hide in combat.
- Raid-style tiles: "Your buffs" is now just "Buffs".

## 1.16.0
Edit Mode, made nicer
- Every Webby frame and box has an amber outline and a name tag in Edit Mode, lit up when you pick it.
- Pick one for a toolbar: open its settings, reset its position, detach it from the frame it's stuck to, and a reminder of the arrow-key nudge.
- Amber guide lines while you drag, wherever it's about to snap. The raid-style party, Healer Mana and Buff Bars boxes snap now too.
- A banner at the top of the screen while Edit Mode is open, with a button for the settings.
- EllesmereUI's Unlock Mode can now move everything Webby: the raid-style party, Healer Mana and Buff Bars too, with their sample previews.

Fixes
- Spell costs: the part of your mana a spell just used now stays lit where it was, then slides away (it used to slide along with the bar, past its end). The cast preview holds until your mana actually drops.
- Errors when someone joined or left the group, with the party frames off or in either style: the raid-style tiles were kept up to date in the background even when not in use. They, the hidden frames, the party icons and missing buffs now rest while not in use.
- Raid markers: an error whenever they changed.
- /webby options opens the settings again.

Also
- Raid-style tiles: Debuffs and Your buffs can each be turned off (Party page, Buffs and debuffs).

## 1.15.2
- A Reload UI button in the settings window's title bar.
- Click casting page tidied: its columns fit (Also target was cut off), the bindings sit on cards like the other pages, and the keybind headings only show once you have a keybind.
- The scroll bar only shows when a page is long enough to scroll.
- The Click casting description no longer starts cut off on one line.

## 1.15.1
Settings search, smarter
- It finds settings that are switched off or hidden too, with a short note saying why ("Needs Pets turned on.", "Raid style only.", "The focus frame is turned off.") and the switch they need right above them. Only settings under a switch that's off stay greyed; ones for the other party style or a hidden frame can still be set.
- A pair of switches shows just the half that matches ("pet" no longer brings up Focus target).
- Hidden search words ("kick" finds Cast bar, "oom" Healer mana) and words that mean the same give the same results: threat / aggro, health / hp, mana / power / rage / energy, colour / color, dispel / cleanse and more.

Also
- Power bar texture is chosen on its own now (it no longer follows the health bar texture). Frames that relied on that keep their look.
- The switches' knob always shows (white when on), never covered by the amber.
- Clearer names: Health / Power bar texture, Number format, Buffs shown, Display, Icon spacing, Custom frame / health colour, Tank / Healer / Damage power bars.

## 1.15.0
Raid-style pets, reworked
- Pets on the raid-style party frames are now their own group, as Blizzard's raid frames and EllesmereUI do it: tiles as wide as the members', in their owners' order, packed with no gaps for members without a pet.
- Pet group: after the party (on down the stack, or on along the row when side by side) or beside it (a column to the right, or a row underneath).
- Pet height: how tall each pet tile is.
- The sample party shows its pet in the pet group too.

## 1.14.3
Settings tidy-up
- Paired switches and sliders now line up with the rest of the rows and the controls column.
- Every option has a tooltip (Buffs, Debuffs and their icon sizes had none; Click casting's Does, Rank and Cast on now explain themselves).
- Clearer tooltips: Health colour explains each choice, Out of range opacity (was Fade amount) says what the number means, and Debuffs no longer contradicts Only mine.
- Consistent names: Custom everywhere (was My own in places), Recent damage, Spell costs, Glow for, Bar order, Number style, Reset / Export / Import, and the buff bars' Buffs I cast / All buffs on me.

## 1.14.2
Lighter in combat
- Party frames only react to changes on you and your party (they were redrawing their icons for every unit about, nameplates included).
- Your power bar redraws once per tick instead of twice.
- Combo points are only looked at by rogues and druids.
- Target and focus cast bars, threat, health colours, druid mana, target of target, your dispel glow and the healer mana list do the same work with far less waste.
- Removed two leftover helpers nothing used any more.

## 1.14.1
- A logo: a web with a W and an F, in the settings window's title bar (with the name stacked beside it), on the minimap button, in the AddOns list, on the Esc > Options page and in the DrangedAddons app.

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
- More for the raid-style tiles: health colours (class, dark with the missing part in class colour, custom, or green to red by health) with a shade for the missing part; power bars per role (tanks, healers, damage); name colour, position and length; a light edge on mouseover; pets as small tiles beside their owners; show when solo; AFK and dead / offline colours; striped or plain shields, optionally from the right edge so full-health shields show.
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
