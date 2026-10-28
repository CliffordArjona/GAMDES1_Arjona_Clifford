extends Node
## GameState (Autoload) - the single source of truth for the whole prototype.
## Holds the player's stats, inventory, equipment, quests, the day clock and
## the unlocked gates.  UI and world scripts listen to its signals.
##
## GDD references: Section II (formal elements), 1.4 (scope), 4.2 (loop),
## 5.2 (gates O1/O3/O6), 6 (resources).

signal stats_changed
signal inventory_changed
signal equipment_changed
signal quest_changed
signal recipes_changed
signal day_changed(day: int)
signal message(text: String, kind: String)
signal dialogue_requested(speaker: String, lines: Array, on_done: Callable)
signal craft_menu_requested
signal gate_opened(gate_id: String)
signal zone_changed(zone_name: String)
signal player_died
signal player_respawned
signal checkpoint_saved(where: String)
signal boss_defeated
signal game_won
signal prompt_changed(text: String)

# ------------------------------------------------------------------ tuning
## GDD Section II: 1 in-game day = 10 minutes of real time.
const DAY_LENGTH := 600.0
## Crops die after 2 game days without water (GDD Section II / 4.2).
const CROP_WILT_DAYS := 2.0

const BASE_HP := 100
const BASE_STR := 2
const BASE_AGI := 2
const BASE_INT := 2
const SKILL_COST := 18.0
const POTION_HEAL := 50
const POTION_MANA := 40

# ------------------------------------------------------------------ items
## type: resource | consumable | equip.  equip items give stat bonuses (GDD 4.2 step 4).
const ITEMS := {
	"wood":          {"name": "Wood", "type": "resource", "icon": "res://assets/generated/icons/wood.png"},
	"stone":         {"name": "Stone", "type": "resource", "icon": "res://assets/generated/icons/stone.png"},
	"gumamela":      {"name": "Gumamela", "type": "resource", "icon": "res://assets/generated/icons/gumamela.png"},
	"slime_gel":     {"name": "Slime Gel", "type": "resource", "icon": "res://assets/generated/icons/slime_gel.png"},
	"wolf_fang":     {"name": "Wolf Fang", "type": "resource", "icon": "res://assets/generated/icons/wolf_fang.png"},
	"health_potion": {"name": "Health Potion", "type": "consumable", "icon": "res://assets/generated/icons/potion_health.png",
		"desc": "Restores 50 HP."},
	"mana_potion":   {"name": "Mana Potion", "type": "consumable", "icon": "res://assets/generated/icons/potion_mana.png",
		"desc": "Restores 40 MP."},
	"wooden_sword":  {"name": "Wooden Sword", "type": "equip", "slot": "weapon", "bonus": {"str": 3},
		"icon": "res://assets/generated/icons/sword_wooden.png", "desc": "STR +3"},
	"fang_sword":    {"name": "Fang Sword", "type": "equip", "slot": "weapon", "bonus": {"str": 7},
		"icon": "res://assets/generated/icons/sword_fang.png", "desc": "STR +7"},
	"gel_boots":     {"name": "Gel Boots", "type": "equip", "slot": "boots", "bonus": {"agi": 3},
		"icon": "res://assets/generated/icons/gel_boots.png", "desc": "AGI +3"},
	"gumamela_charm": {"name": "Gumamela Charm", "type": "equip", "slot": "charm", "bonus": {"int": 3},
		"icon": "res://assets/generated/icons/gumamela_charm.png", "desc": "INT +3"},
}
## Items that are lost if the player dies before reaching a save point.
const RAW := ["wood", "stone", "gumamela", "slime_gel", "wolf_fang"]
## Order shown in the HUD inventory strip.
const HUD_RESOURCES := ["wood", "stone", "gumamela", "slime_gel", "wolf_fang"]

## Base Bench recipes.  'unlock' is a flag name (see unlock_recipes()).
const RECIPES := [
	{"id": "wooden_sword", "cost": {"wood": 4, "stone": 2}, "unlock": "start"},
	{"id": "health_potion", "cost": {"gumamela": 1, "slime_gel": 1}, "unlock": "quest1"},
	{"id": "gel_boots", "cost": {"slime_gel": 3, "wood": 2}, "unlock": "quest2"},
	{"id": "gumamela_charm", "cost": {"gumamela": 2, "stone": 1}, "unlock": "quest2"},
	{"id": "mana_potion", "cost": {"gumamela": 1, "stone": 1}, "unlock": "quest2"},
	{"id": "fang_sword", "cost": {"wolf_fang": 2, "stone": 3, "wood": 2}, "unlock": "fang"},
]

## Fetch quests from the Village NPC.  Each one opens a gate (GDD 5.2: O1, O3, O6).
const QUESTS := [
	{
		"id": "q1", "title": "Clear the Thorns", "gate": "thorn", "unlock": "quest1",
		"need": {"wood": 3, "stone": 2},
		"reward": {"health_potion": 1},
		"intro": [
			"Another soul washed up in the Thicket... Welcome to the ranch, child.",
			"Benizaurus the Tyrant rules these woods. Nobody leaves unless they are strong.",
			"A thorn wall blocks the path east. Bring me 3 Wood and 2 Stone, and I will cut it down.",
		],
		"remind": ["The Grove has wood. The Outcrop has stone. I will wait here."],
		"done": ["Good, good. That will do nicely.", "Stand back... the thorns will wither away."],
	},
	{
		"id": "q2", "title": "Gel and Blossoms", "gate": "ruin", "unlock": "quest2",
		"need": {"gumamela": 2, "slime_gel": 2},
		"reward": {"mana_potion": 1},
		"intro": [
			"You found the meadow! Those slimes drip a useful gel.",
			"The ruin gate to Wolf Hollow needs a ward. Bring me 2 Gumamela from your ranch and 2 Slime Gel.",
		],
		"remind": ["2 Gumamela and 2 Slime Gel. Keep your crops watered, child."],
		"done": ["Lovely blossoms. The ward is ready.", "The ruin gate is open. Mind the wolves."],
	},
	{
		"id": "q3", "title": "Fangs for the Warden", "gate": "seal", "unlock": "quest3",
		"need": {"wolf_fang": 3},
		"reward": {"health_potion": 2},
		"intro": [
			"Past the hollow lies the Warden's arena. Its seal answers only to wolf fangs.",
			"Bring me 3 Wolf Fangs. Then you may face the Warden... and the way out.",
		],
		"remind": ["Three Wolf Fangs. Rest at the shrine if you must."],
		"done": ["Wolf fangs... you are stronger than you look.", "The arena seal is broken. Good luck. Truly."],
	},
]

const ZONE_RANCH := "Ranch Base"
const SAVEABLE_ZONES := [ZONE_RANCH]

# ------------------------------------------------------------------ state
var playing := false            # false on the title screen
var ui_open := false            # dialogue / craft menu / status panel open
var input_block_until := 0      # physics frame number: ignore gameplay input right after closing a menu
var game_time := 0.0            # seconds of play (drives days and crops)
var day := 1

var hp := BASE_HP
var mp := 56.0
var inventory: Dictionary = {}
var equipment := {"weapon": "", "boots": "", "charm": ""}
var unlocked: Dictionary = {"start": true}
var unsaved: Dictionary = {}    # raw items gathered since the last save point
var quest_index := 0
var quest_accepted := false
var gates := {"thorn": false, "ruin": false, "seal": false}
var checkpoint_pos := Vector2.ZERO
var checkpoint_name := "Ranch bed"
var player_zone := ""
var aggro: Dictionary = {}      # enemies currently hunting the player
var prompt_text := ""

# run statistics (shown on the victory screen)
var deaths := 0
var kills := 0
var won := false
var boss_dead := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	reset_run()


func reset_run() -> void:
	playing = false
	ui_open = false
	game_time = 0.0
	day = 1
	inventory = {}
	equipment = {"weapon": "", "boots": "", "charm": ""}
	unlocked = {"start": true}
	unsaved = {}
	quest_index = 0
	quest_accepted = false
	gates = {"thorn": false, "ruin": false, "seal": false}
	aggro = {}
	deaths = 0
	kills = 0
	won = false
	boss_dead = false
	hp = max_hp()
	mp = max_mp()
	checkpoint_name = "Ranch bed"
	prompt_text = ""


func _process(delta: float) -> void:
	if not playing or won:
		return
	game_time += delta
	var d := int(game_time / DAY_LENGTH) + 1
	if d != day:
		day = d
		day_changed.emit(day)
	# slow mana regeneration (INT makes it faster)
	if mp < max_mp():
		mp = minf(max_mp(), mp + mp_regen() * delta)
		stats_changed.emit()


# ------------------------------------------------------------------ stats
func bonus(stat: String) -> int:
	var total := 0
	for slot in equipment:
		var id: String = equipment[slot]
		if id != "":
			total += int(ITEMS[id].get("bonus", {}).get(stat, 0))
	return total

func str_total() -> int: return BASE_STR + bonus("str")
func agi_total() -> int: return BASE_AGI + bonus("agi")
func int_total() -> int: return BASE_INT + bonus("int")

func max_hp() -> int: return BASE_HP
func max_mp() -> float: return 40.0 + 8.0 * int_total()
func mp_regen() -> float: return 0.8 + 0.2 * int_total()
func move_speed() -> float: return 80.0 + 4.0 * agi_total()
func dodge_cooldown() -> float: return maxf(0.35, 0.8 - 0.04 * agi_total())
func melee_damage() -> int: return 2 + 3 * str_total()
func skill_damage() -> int: return 10 + 5 * int_total()
func has_weapon() -> bool: return equipment["weapon"] != ""

func is_dead() -> bool: return hp <= 0


func damage_player(amount: int) -> void:
	hp = maxi(0, hp - amount)
	stats_changed.emit()
	if hp <= 0:
		player_died.emit()

func heal(amount: int) -> void:
	hp = mini(max_hp(), hp + amount)
	stats_changed.emit()

func restore_mp(amount: float) -> void:
	mp = minf(max_mp(), mp + amount)
	stats_changed.emit()

func spend_mp(amount: float) -> bool:
	if mp < amount:
		return false
	mp -= amount
	stats_changed.emit()
	return true

func full_restore() -> void:
	hp = max_hp()
	mp = max_mp()
	stats_changed.emit()


# ------------------------------------------------------------------ inventory
func count(id: String) -> int:
	return int(inventory.get(id, 0))

func add_item(id: String, n: int = 1, track_unsaved: bool = true) -> void:
	inventory[id] = count(id) + n
	if track_unsaved and id in RAW:
		unsaved[id] = int(unsaved.get(id, 0)) + n
	if id == "wolf_fang":
		unlock_recipes("fang")
	inventory_changed.emit()

func remove_item(id: String, n: int = 1) -> bool:
	if count(id) < n:
		return false
	inventory[id] = count(id) - n
	inventory_changed.emit()
	return true

func can_afford(cost: Dictionary) -> bool:
	for id in cost:
		if count(id) < int(cost[id]):
			return false
	return true

func pay(cost: Dictionary) -> void:
	for id in cost:
		inventory[id] = count(id) - int(cost[id])
		# spending also uses up "unsaved" materials first
		if id in RAW and unsaved.has(id):
			unsaved[id] = maxi(0, int(unsaved[id]) - int(cost[id]))
	inventory_changed.emit()


# ------------------------------------------------------------------ crafting
func recipe_visible(r: Dictionary) -> bool:
	return unlocked.get(r["unlock"], false)

func unlock_recipes(flag: String) -> void:
	if unlocked.get(flag, false):
		return
	unlocked[flag] = true
	recipes_changed.emit()

func craft(recipe_id: String) -> bool:
	for r in RECIPES:
		if r["id"] != recipe_id:
			continue
		if not can_afford(r["cost"]):
			return false
		pay(r["cost"])
		var item: Dictionary = ITEMS[recipe_id]
		if item["type"] == "equip":
			equip(recipe_id)
		else:
			add_item(recipe_id, 1, false)
		message.emit("Crafted %s" % item["name"], "good")
		return true
	return false

func equip(id: String) -> void:
	var item: Dictionary = ITEMS[id]
	equipment[item["slot"]] = id
	# max MP / speed may have changed
	mp = minf(mp, max_mp())
	equipment_changed.emit()
	stats_changed.emit()

func use_potion(id: String) -> bool:
	if count(id) <= 0:
		return false
	if id == "health_potion":
		if hp >= max_hp():
			return false
		remove_item(id)
		heal(POTION_HEAL)
		return true
	if id == "mana_potion":
		if mp >= max_mp() - 0.5:
			return false
		remove_item(id)
		restore_mp(POTION_MANA)
		return true
	return false


# ------------------------------------------------------------------ quests
func current_quest() -> Dictionary:
	if quest_index >= QUESTS.size():
		return {}
	return QUESTS[quest_index]

func quest_ready() -> bool:
	var q := current_quest()
	return not q.is_empty() and quest_accepted and can_afford(q["need"])

func accept_quest() -> void:
	quest_accepted = true
	quest_changed.emit()

func turn_in_quest() -> void:
	var q := current_quest()
	if q.is_empty() or not can_afford(q["need"]):
		return
	pay(q["need"])
	for id in q["reward"]:
		add_item(id, int(q["reward"][id]), false)
	unlock_recipes(q["unlock"])
	gates[q["gate"]] = true
	quest_index += 1
	quest_accepted = false
	quest_changed.emit()
	gate_opened.emit(q["gate"])
	message.emit("Quest complete: %s" % q["title"], "good")


# ------------------------------------------------------------------ save points / death
func bank_progress() -> void:
	unsaved = {}

func set_checkpoint(pos: Vector2, label: String) -> void:
	checkpoint_pos = pos
	checkpoint_name = label
	bank_progress()
	checkpoint_saved.emit(label)

## GDD 4.2 step 3: dying forfeits recent un-saved progress.
## We remove the raw materials gathered since the last bed / shrine.
func apply_death_penalty() -> Dictionary:
	var lost := {}
	for id in unsaved:
		var n := mini(int(unsaved[id]), count(id))
		if n > 0:
			inventory[id] = count(id) - n
			lost[id] = n
	unsaved = {}
	inventory_changed.emit()
	return lost

func respawn() -> Dictionary:
	deaths += 1
	var lost := apply_death_penalty()
	aggro = {}
	hp = max_hp()
	mp = max_mp()
	stats_changed.emit()
	player_respawned.emit()
	return lost


# ------------------------------------------------------------------ combat tracking
func register_aggro(e: Object) -> void:
	aggro[e.get_instance_id()] = true

func clear_aggro(e: Object) -> void:
	aggro.erase(e.get_instance_id())

func in_combat() -> bool:
	return aggro.size() > 0


# ------------------------------------------------------------------ save / load (see SaveGame)
func capture() -> Dictionary:
	return {
		"game_time": game_time, "hp": hp, "mp": mp,
		"inventory": inventory.duplicate(), "equipment": equipment.duplicate(),
		"unlocked": unlocked.duplicate(), "unsaved": unsaved.duplicate(),
		"quest_index": quest_index, "quest_accepted": quest_accepted, "gates": gates.duplicate(),
		"checkpoint_pos": checkpoint_pos, "checkpoint_name": checkpoint_name,
		"deaths": deaths, "kills": kills, "boss_dead": boss_dead,
	}


func apply_save(d: Dictionary) -> void:
	reset_run()
	game_time = float(d.get("game_time", 0.0))
	day = int(game_time / DAY_LENGTH) + 1
	for k in d.get("inventory", {}):
		inventory[k] = int(d["inventory"][k])
	for k in d.get("equipment", {}):
		equipment[k] = String(d["equipment"][k])
	unlocked = d.get("unlocked", {"start": true}).duplicate()
	unsaved = {}
	for k in d.get("unsaved", {}):
		unsaved[k] = int(d["unsaved"][k])
	quest_index = int(d.get("quest_index", 0))
	quest_accepted = bool(d.get("quest_accepted", false))
	for k in d.get("gates", {}):
		gates[k] = bool(d["gates"][k])
	checkpoint_pos = d.get("checkpoint_pos", Vector2.ZERO)
	checkpoint_name = String(d.get("checkpoint_name", "Ranch bed"))
	deaths = int(d.get("deaths", 0))
	kills = int(d.get("kills", 0))
	boss_dead = bool(d.get("boss_dead", false))
	hp = clampi(int(d.get("hp", max_hp())), 1, max_hp())
	mp = minf(float(d.get("mp", max_mp())), max_mp())
	inventory_changed.emit()
	equipment_changed.emit()
	recipes_changed.emit()
	quest_changed.emit()
	stats_changed.emit()


# ------------------------------------------------------------------ misc
func toast(text: String, kind: String = "info") -> void:
	message.emit(text, kind)

func open_ui() -> void:
	ui_open = true
	set_prompt("")

func close_ui() -> void:
	ui_open = false
	# stops the same key press from also triggering a world action (e.g. re-talking to the NPC)
	input_block_until = Engine.get_physics_frames() + 14

func input_blocked() -> bool:
	return ui_open or not playing or won or Engine.get_physics_frames() < input_block_until

func set_prompt(text: String) -> void:
	if text != prompt_text:
		prompt_text = text
		prompt_changed.emit(text)

func win_game() -> void:
	if won:
		return
	won = true
	game_won.emit()

func time_text() -> String:
	var t := fmod(game_time, DAY_LENGTH) / DAY_LENGTH * 24.0 + 6.0   # display clock: each day starts at 06:00
	t = fmod(t, 24.0)
	var h := int(t)
	var m := int((t - h) * 60.0)
	return "%02d:%02d" % [h, m]

func run_time_text() -> String:
	var s := int(game_time)
	return "%d:%02d" % [s / 60, s % 60]
