# Ashen Wilds (Godot 4.3+)

2D pixel-art action RPG / survival. Open `project.godot` in Godot 4.3+ and press F5. All art is procedural PNG (tools/generate_assets*.py) and can be replaced.

## Controls
WASD move | Shift run | Mouse aim, Click/Space attack | Q E R class skills | F dash | V mend | 1-4 quick use (HP potion, MP potion, food, campfire)
I bag | C character | K skills | B craft | M map | T interact (talk, chests, portals) | F5 quick save | Esc menu | H hide help

## Character
- Level cap 100. Each level: full heal, +10 stat points, +5 skill points (start with 10 / 5).
- Stats: STR, VIT, INT, MIND, DEX, LUCK feed HP, MP, attacks, defenses, speed, crit and drop rate. Element resistances come from gear and skills.
- Classes: Warrior, Ranger, Assassin, Mage, Priest. Each has 3 active + 2 passive skills with its own tree, plus a shared Common tree. Skills have elements (light, dark, fire, water, earth, wind) and rank up to 20 (rank cap rises with level).
- Inventory: 40 slots, filter, sort, stack/merge, split, discard. Gear: weapons, armor, accessories in 6 rarities (Common to Mythical) with random affixes.
- Hunger meter: eat food. Campfires cook and smelt.

## World
- Random world with beach, plains, forest, mushroom grove, highlands and volcanic biomes; trees, ores, herbs, monsters and animals. Hit resources with any weapon (STR boosts gathering).
- Hidden dungeons spawn at random, last a limited time, and can be cleared once. Get close to reveal the entrance. Each is a maze with chests, spike/dart traps, mini bosses (good loot) and a main boss in the far arena, which leaves a golden treasure chest with a unique item.
- 16 monster types plus deer; levelled by distance and biome.

## Save
Multiple save slots from the pause menu (Esc). Old v1 saves are not compatible.


## v3 update

- **Skills**: 10 active + 10 passive per class (plus Common tree and six element Tome skills). Only **4 actives** can be equipped (Q/E/R/F): left-click a node to learn/rank up, right-click to equip into the selected slot.
- **Scrollable UI**: Character and Skills windows scroll when content is long.
- **Gear slots**: weapon, armor, necklace, 2 rings, 2 bracelets.
- **Town**: Adventurer Guild (quest board), Gear Shop, Blacksmith (craft + enchant + re-roll), Potion, Artifact (limited Rare+ gear), Magic (spell books -> Tome skills), Food shops.
- **Dungeons**: difficulty Rank 1-100, always visible on the map (even unexplored).
- Assets for tomes: `tools/generate_assets_v3.py`; skill data generator: `tools/gen_skill_data.py`.
- Note: the old V (mend) key is gone; Dash and Mend are Common-tree skills you can equip.
- **Recall**: press G to teleport to town at any time (3s channel, cancelled by moving or taking damage, 20s cooldown). Works inside dungeons too.
- **Town walls**: the town is enclosed by a stone wall with 4 gates (N/S/E/W). Eight strong Town Guards (two per gate) strike any monster that comes near. Enchant/re-roll is at the Blacksmith.
- **World generation**: biome patches are cleaned of tiny specks, lava keeps away from water, volcanic land gets a scorched dirt rim, mushroom groves never touch volcanic land and have a meadow gap to forest / mountain, and a meadow ring surrounds the town.
- **Ranged gathering**: arrows, bolts, area skills and melee skills now also chop trees and break ore / rocks.
- **Town**: bigger walled town with cobblestone roads and plaza, fountain, benches, lamps, flower beds, gate banners and a separate building for each shop (art: `tools/generate_assets_v4.py`). NPC names show under their feet.
- **World** is now 240x240 tiles (was 160): more land, more monsters (scaled with area), up to 8 dungeons at once. Old v2 saves are not compatible with the larger map.
- **Town** is larger (about 32x26 tiles inside the wall) with open lawns, benches and flower beds between the shops and the wall.
- **Default Dash**: every class has Dash on Ctrl or right mouse button (1.4 s cooldown, brief invulnerability, cooldown shown left of the skill bar). The old equippable Dash skill was removed.
- **Minimap toggle**: press **N** (or click the small "Map" button) to cycle the minimap small / large / hidden.
- **Map window**: mouse-wheel zoom, drag to pan, click for a waypoint, right-click to clear; Me / All / + / - buttons, coordinate grid, hover readout and dungeon tooltips (rank and time left), town wall outline, nearest-first dungeon list.
- **Bag upgrades**: the Inventory has an "Expand bag" button: +8 slots per upgrade (250g, 1000g, 2250g, ... scaling), from 40 up to 120 slots. The bag list scrolls and the size is saved.
- **Skill tree UI**: tiered rows, ACTIVE / PASSIVE headers, level requirements under each node, key badges on equipped skills, and a bigger 4-slot loadout bar. **Drag** a learned active skill onto a slot to equip it (or right-click it), drag slot to slot to swap, right-click a slot to clear it.
- **Rebindable keys**: Esc menu (or Title) -> **Controls**, or the "Keys..." button in the Skills window. Rebind the 4 skill slots, 4 quick-item slots, Dash and Recall; conflicting keys are swapped. Saved in `user://settings.json`; the skill bar, quick-item bar and help text follow your bindings.

## Visual polish pass
- Project-wide UI theme (`ui_theme.tres`, built by `UI.make_theme()`): buttons now have clearly visible fills, gold borders and hover/pressed/disabled states, including the pause menu.
- Inventory: bag grid scrolls in its own panel; the bag-upgrade button and info label no longer overlap anything.
- 114 generated skill icons (`assets/skillicons/`, from `tools/generate_skill_icons.py`) used on the skill bar, skill tree and drag previews.
- Terrain edges blend smoothly between biomes (`_blend_edges` in world.gd).
- Wind sway shader on trees, herbs and banners; animated town fountain; lamps glow only at night with a gentle flicker (`night_light.gd`).
- Ambient particles per biome (pollen, leaves, embers, spores, fireflies at night), footstep dust tinted by ground, and idle breathing for NPCs and guards.

## Run toggle and bars
- Run is now an on/off toggle (default Shift, rebindable in Esc > Controls). "Running (key)" shows under the HUD while on.
- New `fancy_bar.gd` HP/MP bars: border, gradient and gloss, numbers, damage flash and delayed damage trail. Enemy bars are bigger, colour-shift green to red, have a trail and a centred name.

## Mage / Priest MP regen balance
- Mage and Priest regen is now (1.5 + Mind*0.06 + MaxMP*1%) x class multiplier (Mage 1.0, Priest 1.25) plus gear/buffs, so it scales with their pool and skill costs. Other classes are unchanged.
- All classes regenerate MP 1.6x faster while out of combat.

## Refined art pack
All 317 PNGs under `assets/` were replaced by the refined art set (same paths and sizes): class-coloured skill icons, character highlights/trim, stronger mob/boss contrast, richer props, tiles, items and spell effects. Note: the `tools/generate_*.py` scripts would overwrite these, so don't re-run them.

## Ranger arrows and bullets
- Arrows now fly point-first (they were drawn sideways before), 25% larger, with a fading trail and a soft glow tinted by the weapon's element.
- Bullets are longer tracers with a yellow trail and glow, a muzzle flash and a tiny camera kick.
- Hits throw a spark burst; arrows that hit walls or rocks stick in briefly, then fade.

## Art style pass (v5)
`tools/generate_assets_v5.py` redraws terrain tiles (grass, forest, dirt, sand, cobble stone, mushroom ground), oak/pine trees, bush, rock and stump with darker outlines, multi-tone leaf clusters and light-from-top-left shading. A soft vignette frames the screen. Other sprites (buildings, characters, mobs) still use the refined art pack.

## Autosave
The game autosaves every 60s into the current slot (skipped while dead). F5 still quick-saves manually.

## New game slot picker
After choosing a class you pick a save slot (Start on an empty slot, Overwrite on a used one). The new game is saved there immediately and autosaves keep using it.

## Simpler, roomier dungeons
Dungeons are now a 3x3 to 5x5 grid of big open rooms (9-13 tiles across) joined by 3-tile-wide corridors, with a 15x15 boss arena in the far corner. 2-4 monsters per room. Layouts are checked to always be fully connected.

## Save on exit
Closing the window or choosing Quit to Title saves to the current slot first (not when dead).

## Map teleport
Open the map (M): click a discovered dungeon marker to select it, then press Teleport to Dungeon (3s channel, stand still, costs 20+2 gold per rank, shares the 20s recall cooldown). Teleport to Town is also a button on the map (free, same as G). Selected dungeon is ringed in green.

## Sound and music
- `tools/generate_audio.py` synthesises everything (needs numpy + ffmpeg): 11 music loops in `assets/music/` and 30 effects in `assets/sfx/`. Edit the track table in `music()` to change tunes.
- `scripts/audio.gd` (autoload `Audio`) crossfades music by place: title screen, town, wilderness by day / night, one track per dungeon biome (Magma Cavern, Verdant Labyrinth, Spore Warren, Overgrown Ruins, Sunken Grotto, Deep Cave) and a boss track inside the boss arena.
- Effects: attacks, hits/crits, enemy and player death, hurt, spells, dash, bow/gun, pickups, coins, level up, chests, chopping/mining, portals/teleport, shop, equip and every UI button click.
- Music and Sound volume sliders are on the pause menu (saved in settings).

## Gear comparison
Hovering gear in the bag, shops or blacksmith list now shows each stat with its difference versus what you wear (green up / red down, lost stats listed), an UPGRADE / DOWNGRADE / Sidegrade verdict weighted for your class (e.g. INT/Magic Atk for casters, STR/Phy Atk for fighters), and a second panel with the equipped item. Rings and bracelets compare against the weaker worn one.

Tooltips taller than the screen are now capped to the screen height and scroll with the mouse wheel while hovering (a 'Mouse wheel: scroll' hint appears).

## Attack combos
Holding / repeating left click chains a weapon combo (resets after a short pause; pips above the character show progress). The last hit is a flashy finisher with bigger damage, knockback, screen shake and an effect:
- Sword (3): alternating slashes, then a wide spin slash x2.0. Dagger (4): quick stabs, then a lunging guaranteed-crit double slash x2.1.
- Spear (3): thrusts, then a long lunge x2.0. Hammer (3): swings, then an earth slam with a shockwave x2.2.
- Bow (3): arrows, then a piercing power arrow x2.2. Gun (3): shots, then a 3-bullet shotgun blast.
- Wand (4) / Grimoire (3): bolts/orbs, then a big exploding orb x2.3 (double mana). Each step before the finisher also hits a little harder (+10% per step). The finisher has a longer recovery.

## Bigger dungeons, traps and spawners
- Rooms are now 15-21 tiles across (boss arena 23x23) on a 26-tile grid, joined by 3-wide corridors; 4-7 monsters per room.
- Monster spawning devices (`spawner.gd`), one per biome: Magma Vent, Root Nest, Spore Pod, Ruined Totem, Coral Hive, Bone Altar. They summon up to 3 monsters at a time while you are near; destroy one (it has HP) for gold and XP. Destroyed devices stay destroyed.
- Traps (`dtrap.gd`, `trap.gd`, mimic in `chest.gd`): Spike, Arrow (wall turrets), Bouncing Boulder, Poison Gas vents, Teleportation rune (random other room), Mimic (a chest that bites), Pit fall (damage + stun + drop into another room), Falling Boom (telegraphed bombs).
- Each biome has its own trap mix: Magma Cavern (boulder/boom/spike/arrow), Verdant Labyrinth (arrow/gas/pit/mimic/spike), Spore Warren (gas/teleport/mimic/spike), Overgrown Ruins (boulder/pit/arrow/boom), Sunken Grotto (gas/pit/teleport/arrow), Deep Cave (boom/spike/mimic/pit/boulder).
- `tools/generate_dungeon_assets.py` draws the spawner and mimic sprites.

## Dungeon Designer (custom dungeons)

Open it from the **Esc / pause menu -> Dungeon Designer**. Everything is free and saved automatically (`user://dungeon_bp.json`).

You can adjust:
- **Name**, **biome** and **room size** (Small / Medium / Large rooms and boss arena), plus **rooms per side** (2-6).
- **Difficulty rank** (1-100; rank sets monster level and difficulty tier).
- **Monsters per room** (0-10), **which monster types** spawn (none selected = biome default) and **spawner devices** (0-12).
- **Traps**: Off / Rare / Normal / Many for Bouncing Boulder, Poison Gas, Teleport Rune, Pitfall, Falling Boom, Spikes, Arrow Trap and Mimic Chest.
- **Boss** (any of the 6) and **mini bosses** (0-8, with a chosen mini boss type or random).

Buttons:
- **Test Run** - enter the dungeon immediately to explore it. Test runs give no loot, XP or gold. Leave with the exit as usual.
- **Create Seal** - makes a *Dungeon Seal* item holding the blueprint. Use it from your bag on open ground outside town and the dungeon rises in front of you as a permanent entrance (custom dungeons have no collapse timer; they disappear once the boss is beaten). Each seal keeps its own settings, so you can carry several different dungeons.
- **Reset** - back to defaults. **Back** - return to the pause menu.

### Dungeon Designer - Drag & Drop layout mode

In the Designer, set **Customize by -> Drag & Drop layout**, then press **Open Layout Editor**. (Option selection mode is unchanged.)

**Room map**
- Click an empty slot (or drag the *Room* chip onto it) to add a room; right-click a room or drag it to the *Trash* box to remove it; drag a room to an empty slot to move it.
- Click the bar between two neighbouring rooms to connect / disconnect them, or select a room and use the Up / Down / Left / Right buttons (these also create the neighbour room).
- Drag the *Start* and *Boss* chips onto rooms to choose the start room and the boss room. The grid can be 2x2 up to 6x6.
- The editor warns if a room cannot be reached from the start; Test Run / Create Seal are blocked until it is fixed.

**Room editor** (double-click a room, or *Edit Room*)
- Room width / height can be changed (limited by the Room size setting).
- **Monsters**: drag any monster into the room to pin it to a spot, or drop it on the *RANDOM spot* box to let it appear anywhere in the room. *Mini: ON* makes placed monsters mini bosses. *Spawner* adds a monster spawning device.
- **Traps** (Boulder, Gas, Teleport, Pitfall, Falling Boom, Spikes, Arrow, Mimic chest) and **Treasure** chests work the same way: pinned or random.
- **Terrain**: paint Wall, Cliff, Water or Lava (lava burns you) with click / drag, 3 colour styles each, Eraser or right-click to erase. Corridor lanes to linked rooms are always kept clear.
- Pinned items can be dragged to a new spot; the list at the bottom shows every entry in the room and lets you delete it.
- You can also click a chip to arm it and then click the room instead of dragging.

### Randomized rooms, random monsters / traps, lava

- **Room editor -> Random tab**: tick *Terrain / Monsters / Traps*, pick an *Amount* (Few / Some / Many) and press **Randomize now** to fill the room with random terrain patches, monsters and traps (it replaces the ticked parts; you can still edit the result). Turn on **Re-roll each run** to have the room add fresh random terrain / monsters / traps every time that dungeon is built, on top of what you placed by hand. The map screen has **Randomize all** for every room.
- Randomization never blocks the way: door lanes, the room centre, the exit / start area and the boss area stay clear, and no walkable pocket is ever sealed off.
- **Random monster** and **Random trap** chips (Monster / Trap tabs): the type is rolled every run; drag them to a specific tile to pin the location, or drop them on the RANDOM box to roll the location too.
- **Lava** can be walked on but burns: periodic damage plus a *Burning* damage-over-time that keeps ticking for a few seconds after you leave.

### Random terrain for generated dungeons

Generated dungeons now get random cliffs, water, lava and walls inside their rooms (a few patches normally, more on higher-difficulty dungeons). In the Dungeon Designer (option-selection mode) the new **Random terrain** setting (Off / Few / Some / Many) controls it for your own dungeons. Doors, the exit, the boss area and every walkable tile stay reachable, and monsters / chests / traps are moved onto floor tiles.

### Adventurer NPCs and the Dungeon Board

**Adventurers (NPC players)**
- Every game starts with **2-5 adventurers**. The roster grows with your level (about one new adventurer per two levels, one recruit every ~15 s) up to a hard limit of **50**.
- Each adventurer has a class (Warrior / Ranger / Assassin / Mage / Priest), a level, gear, up to 4 equipped class skills, an inventory, potions and gold - just like you. Open the **Adventurers** tab in the guild, or stand next to one in the world and press **T**, to inspect them.
- **AI**: they hunt monsters near their level (they fight for real when you are close, and are simulated when far away), earn gold / XP / loot, drink potions, recall to town when hurt or full, sell loot, restock potions and buy better gear, so they steadily get stronger. They also take **guild quests** and **play dungeons from the Dungeon Board**.
- Adventurers that you see in town wander around; ones that finished resting walk out the south gate to hunt.

**Dungeon Board (Adventurer Guild -> Dungeon Board)**
- Every listed dungeon (yours or an adventurer's) shows its biome, boss, rooms, owner, **reward cut** and play count. Press **Enter** to play it. Board runs give **half gold / XP**, and the owner receives their cut of the gold you earn, and a share of the item drops (unique boss items always stay with you). Leaving early is fine (Recall / portal); the play count rises when the boss is defeated.
- The board always keeps a few adventurer dungeons, ranked around your level.

**Placing your own dungeons (Guild -> My Dungeons)**
- Craft a Dungeon Seal in the **Dungeon Designer**, then press **List (x% cut)** next to it in the My Dungeons tab. Adventurers (and you, via the board) will play it according to their rank.
- You start with **3 listing slots** and can buy more up to **10** (cost 400 x (slots - 2) gold per slot). Each listing has its own **cut of 0-30%** (default 10%), adjustable with the +/- buttons at any time. Higher cuts make adventurers less likely to run your dungeon.
- Gold and items adventurers earn from your dungeons are held in a **stash**; press **Collect** to take them. **Withdraw** removes a listing and returns the seal.
- Your listings and every adventurer are stored in your save file (old saves simply get a fresh roster).
