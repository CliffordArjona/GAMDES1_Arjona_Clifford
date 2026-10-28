# The Forsaken Thicket - Godot 4.7 prototype

AG ARC Interactive - GAMDES1 (BSCS IAC2).  A 2D top-down survival action-adventure:
farm, gather, craft, fight and escape the Thicket of the tyrant Benizaurus.
This build is the **term prototype** described in the GDD (Section 1.4): one forest zone,
two monsters (slime, wolf), one mini-boss that stands in for Benizaurus, one weapon type,
one MP skill and three fetch quests from one NPC.

## 1. Run it
1. Install **Godot 4.7.x** (the same version as your lab, 4.7.2 is fine).
2. Extract the zip, open Godot, click **Import**, choose `project.godot`.
3. The first open imports the art (about 10-20 seconds). Then press **F5**.
   The main scene is `scences/main.tscn` (the folder name keeps your original spelling).

## 2. Controls
| Action | Keys |
|---|---|
| Move | W A S D / arrow keys |
| Sword | Space / left click (needs a weapon: craft the Wooden Sword first) |
| Mana Bolt (18 MP, aim with the mouse) | Q / right click |
| Dodge (free - there is no stamina) | Shift |
| Interact: till, plant, water, harvest, chop, mine, talk, craft, sleep, rest (hold to keep chopping) | E |
| Health potion / Mana potion | 1 / 2 |
| Status window (STR, AGI, INT, gear) | Tab or C |
| Pause menu | Esc |
| Mute / Fullscreen | M / F11 |

## 2b. Menus, saving and loading (like Terraria / Stardew Valley)
* **Main menu** (opens first): the pixel logo over the live world while the camera slowly tours the zones, fireflies and music.
  Buttons: **Continue**, **New Game**, **How to Play**, **Options**, **Credits**, **Exit Game**
  (mouse, arrow keys or W/S + Enter; Esc goes back from a sub-screen).
* **Continue** is greyed out until a save exists. It opens the **Continue** screen with **three slots**
  (Slot 1 / 2 / 3). Each card shows the day, zone, current quest, play time, monsters defeated and the date saved.
  Choose a slot to load it, or press **Delete** to remove one (it asks first).
* **Pause menu** (Esc in game): **Resume**, **Save Game**, **Options**, **How to Play**, **Main Menu**, **Exit Game**.
  * **Save Game** -> pick a slot. If the slot already holds a different save, it asks before overwriting.
  * **Main Menu** and **Exit Game** first ask **"Save before leaving?"**: pick a slot to save and leave, **Don't save**, or **Cancel**.
* **Autosave**: sleeping in the bed saves into the slot the game came from (like Stardew Valley).
  A brand-new game has no slot until the first time you save.
* What is saved: stats, items, gear, quests, gates, the day clock, your position, every farm plot (and its crops), trees and rocks,
  defeated monsters, opened chests, the shrine and dropped items. Monsters that were fighting you go back to their homes when you load.
* Save files are readable text in `user://saves/slot_1.save` ... `slot_3.save`
  (Windows: `%APPDATA%\Godot\app_userdata\The Forsaken Thicket\saves`). Settings are in `user://settings.cfg`.
* **Options**: music volume, sound-effects volume, fullscreen (also F11), sound on/off (also M).
* Code: `scripts/save_game.gd` (slots/files), `GameState.capture()/apply_save()`, `World.capture_save()/apply_save()`,
  each saveable object has `save_state()` / `load_state()`, menus in `scripts/ui/screens.gd`, flows in `scripts/ui/hud.gd`.
* GDD note: Section 1.4 listed a complex multi-zone save system as out of scope. This build has a *simple* single-zone save
  (3 slots). Update 1.4 / 4.4 (out-game actions: Save, Load, between sessions) if you keep it.

## 2c. Pixel font
All text uses **Jersey 10** (SIL Open Font License, see `assets/fonts/OFL.txt`) with anti-aliasing off so the edges stay
pixel-sharp. It is set once in Project Settings > GUI > Theme > Custom Font (`resources/pixel_font.res`).
`UIKit.FONT_SCALE` (in `scripts/ui/ui_kit.gd`) makes all UI text bigger or smaller in one place.
The title logo is a picture (`assets/generated/ui/logo.png`, made by `tools/art_ui.py`).

## 2d. Submitting to GitHub + the executable
See `GITHUB_SUBMISSION_STEPS.md` (branches `main` and `master`, remote `origin`, and the Windows build in
`builds/TheForsakenThicket_Windows.zip`).

## 3. How the game plays (about 30 minutes for one pass)
1. **Ranch (hub).** You start outside your cabin facing the farm. Till, plant and water Gumamela.
   Crops that are not watered for 2 game days wither (1 game day = 10 real minutes).
2. **Whispering Grove / Rocky Outcrop** (no enemies): chop 5 trees, mine 3 rocks.
3. **Base Bench**: craft the **Wooden Sword** (4 Wood + 2 Stone).
4. **Lola Pacita** (village NPC) gives **Quest 1** (3 Wood, 2 Stone) -> the **Thorn Barrier (O1)** opens.
5. **Slime Meadow**: slow slimes (watch the red wind-up, then dodge). The slime in the **pit** cannot be
   reached by the sword - use the Mana Bolt. Collect Slime Gel.
6. Harvest Gumamela -> **Quest 2** (2 Gumamela, 2 Slime Gel) -> **Ruin Gate (O3)** opens.
   Bench unlocks Gel Boots (AGI), Gumamela Charm (INT), potions.
7. **Wolf Hollow**: a lone wolf at the entrance, then a pair (the second wolf stays idle until you get close
   or attack). Wolves drop Wolf Fangs. Wolves give up the chase when you leave the Hollow.
8. **Quest 3** (3 Wolf Fang) -> **Arena Seal (O6)** opens. Craft the **Fang Sword**.
9. **Checkpoint Shrine**: touching it moves your respawn point; E restores HP/MP.
10. **Mini-Boss Arena**: defeat **The Warden** (placeholder for Benizaurus) -> the **Escape Gate** opens -> walk in to win.

Dying sends you to the last bed/shrine and you lose the raw materials gathered since that save point
(GDD 4.2 step 3).  Sleeping in the bed restores HP/MP, banks your materials and skips to the next morning.

## 4. GDD checklist
| GDD section | Where it is in the build |
|---|---|
| 1.4 scope: HP/MP always visible, STR/AGI/INT only on Tab/C | `scripts/ui/hud.gd`, `status_panel.gd` |
| 1.4 one crop (Gumamela), 2 resources (Wood, Stone), crafting at the Base Bench | `crop_plot.gd`, `resource_node.gd`, `bench.gd`, `GameState.RECIPES` |
| 1.4 slime + wolf + mini-boss, 1 weapon, 1 MP skill, 3 fetch quests, win = defeat mini-boss | `enemy.gd`, `projectile.gd`, `GameState.QUESTS`, `escape_gate.gd` |
| II rules: crops die in 2 days; no gathering in combat; no farming in the forest | `crop_plot.gd`, `resource_node.gd` (`GameState.in_combat()`), plots only at the ranch |
| II/4.2 day = 10 min, wake up and heal | `GameState.DAY_LENGTH = 600`, `bed.gd` |
| 4.3 micro / macro loops | gather-fight-loot-recover in the zones, farm-craft-quest at the ranch |
| 5.1 hub-and-spoke, quest-gated spokes | `scences/world.tscn` (Ranch hub; gates `ThornBarrier_O1`, `RuinGate_O3`, `ArenaSeal_O6`) |
| 5.2 map objects O1-O8, P1-P8 | node names in `world.tscn` (`Wolf_Lone_O4`, `Wolf_Pair_*_O5`, `Warden_O7`, `CheckpointShrine_P7`, ...) |
| 5.3 flow channel / pacing (rest at ranch and shrine, rises at meadow / hollow, peak at arena) | zone order + enemy numbers in `tools/build_scenes.gd` |
| 5.4 teaching without pop-ups: safe farm/gather areas, one-recipe bench, slow first slime, edge stone node that stops responding in combat, pit slime for the MP skill, telegraphed wolf lunge reused by the boss, shrine | see the zone scripts; the NPC never explains controls |
| 3.4 PX goals | challenged in forest/hollow, discovery on unlocking zones (hidden chests too), accomplishment at the Warden |

Cut on purpose (GDD 1.4): stamina, fishing, 3 zones, the 3 boss keys, Benizaurus' throne, Rebellion Gear, day/night,
weather, inventory storage, NPC reputation.

## 5. Project map
```
project.godot           settings, autoloads (GameState, Sfx), input map, physics layer names
scences/                main.tscn, world.tscn + every reusable scene (player, slime, wolf, mini_boss, ...)
scripts/                game_state.gd (stats/items/recipes/quests)  player.gd  enemy.gd  world.gd ...
scripts/ui/             hud.gd, craft_menu.gd, status_panel.gd, dialogue_box.gd, screens.gd
resources/              SpriteFrames (animations) and the TileSet
assets/world/           your original art pack         assets/generated/  art + audio made for this game
tools/                  generators + QA bot (optional, see section 8)
old_progress/           your original adventurer player + grass test map (backup, not used)
```

## 6. Where to change things
* **Numbers** (HP, damage, speeds, recipes, quest requirements): `scripts/game_state.gd` (top of the file) and
  the `_enemy(...)` calls in `tools/build_scenes.gd` (or the exported values on `slime.tscn` / `wolf.tscn` / `mini_boss.tscn`).
* **Day length / wilt rule**: `GameState.DAY_LENGTH`, `GameState.CROP_WILT_DAYS`, `crop_plot.gd`.
* **New recipe**: add a line to `GameState.RECIPES` and an entry in `GameState.ITEMS`.
* **New quest**: add a dictionary to `GameState.QUESTS` and a gate scene with the same `gate_id`.
* **Move things on the map**: open `scences/world.tscn` and drag nodes inside `Entities` (they y-sort automatically).
  Painted ground/walls are the `Ground`, `Decor` and `Canopy` TileMapLayers.
* **Controls**: Project > Project Settings > Input Map (actions: attack, skill, dodge, interact, potion_health, potion_mana ...).

## 7. How it was built - step by step (for your documentation)
1. **Project setup** - 2D, GL Compatibility, nearest-neighbour textures, 1152x648 with `canvas_items` stretch,
   input actions, physics layers (world, player, enemy, interact, attacks, hurtboxes, low_wall). `tools/configure_project.gd`.
2. **Art** - reuse your pack (tiles, player, slime, chest); generate what it lacks in the same palette: wolf,
   Warden, NPC, crops, gates, shrine, cabin walls, icons, effects and audio. `python3 tools/make_assets.py`.
3. **Resources** - SpriteFrames for every character and the TileSet (canopy tiles are solid walls). `tools/build_resources.gd`.
4. **GameState autoload** - stats, items, equipment, recipes, quests, day clock, death penalty, signals.
5. **Player** (`CharacterBody2D`) - 8-way movement, 4-way facing, sword hitbox on animation frames 2-4, Mana Bolt, free dodge with i-frames, interaction probe.
6. **Enemies** - one state machine (idle -> chase -> wind-up -> attack -> recover -> hurt -> dead) reused by slime, wolf and boss.
7. **Interactables** - crop plot, tree / stone nodes, NPC, bench, bed, shrine, chests, three quest gates, escape gate.
8. **UI** - built in code (`scripts/ui`): HUD, dialogue, craft menu, status window, pause, title, death and victory screens.
9. **World** - hub-and-spoke map (Ranch, Grove, Outcrop, Slime Meadow, Wolf Hollow, Shrine, Arena) built by `tools/build_world.gd`.
10. **Audio** - zone music (calm ranch / tense hollow) and sound effects through the `Sfx` autoload.
11. **Testing** - see below.

## 8. Testing and the optional tools
* `godot --headless --path . res://tools/qa_bot_runner.tscn` plays the entire game with a bot and prints `RESULT: PASS`
  when the Escape Gate is reached (farm, chop, mine, craft, 3 quests, slimes, pit slime, wolves, boss).
* `res://tools/qa_ui_runner.tscn` drives the menus with real key presses.
* To rebuild scenes after editing a tool script:
  `godot --headless --path . -s tools/build_resources.gd`, then
  `godot --headless --path . res://tools/build_runner.tscn -- build_scenes`, then `... -- build_world`.
  (Rebuilding **overwrites** `scences/*.tscn`, so do this only if you have not edited those scenes by hand.)

## 9. Things in the GDD you may want to fix
* 4.1 loop diagram mentions "stamina", but stamina is cut (1.4).
* Section II, 4.2 and 3.4 still describe three keys, three zones and Rebellion Gear, while 1.4 cuts them. This build follows 1.4 and 5.2
  (quest-gated doors, one mini-boss as the final fight).
* 3.1 lists "Relaxation / Nurturing" and "Mastery / Progression" as kinds of fun; the class list is the Eight Kinds of Fun.
* "Benzaurus" is spelled three ways ("Benizaurus", "Benzaurus", "BenIzaurus").
* Sections VI onward are still templates; the numbers in `GameState` can be used to fill 6.1 (economy), 6.2 (progression) and 8.3 (controls).
