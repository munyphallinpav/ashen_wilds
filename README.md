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
