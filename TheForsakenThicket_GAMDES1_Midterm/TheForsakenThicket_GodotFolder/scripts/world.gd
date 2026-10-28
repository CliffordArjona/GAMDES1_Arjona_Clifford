extends Node2D
## The prototype forest zone (GDD Section V, Figure 5.1): hub-and-spoke layout with
## the Ranch as the hub.  This script tracks which zone the player is in, plays the
## right music, handles sleeping and the death/respawn flow.

const TILE := 16
## Zones (tile rects: x0, y0, x1, y1).  MUST match tools/build_world.gd.
const ZONES := [
	{"name": "Ranch Base", "rect": Rect2i(4, 28, 32, 26), "music": "ranch"},
	{"name": "Whispering Grove", "rect": Rect2i(4, 4, 32, 22), "music": "ranch"},
	{"name": "Rocky Outcrop", "rect": Rect2i(4, 56, 32, 18), "music": "ranch"},
	{"name": "Slime Meadow", "rect": Rect2i(50, 4, 60, 22), "music": "ranch"},
	{"name": "Wolf Hollow", "rect": Rect2i(50, 28, 60, 26), "music": "danger"},
	{"name": "Checkpoint Shrine", "rect": Rect2i(68, 57, 18, 17), "music": "danger"},
	{"name": "Mini-Boss Arena", "rect": Rect2i(90, 56, 20, 19), "music": "danger"},
]

@export var map_size := Vector2i(112, 78)

@onready var player: Player = $Entities/Player
@onready var hud: Hud = get_tree().get_first_node_in_group("hud") as Hud

## The main menu shows the live world: a camera slowly tours the zones behind the logo.
const MENU_TOUR := [
	Vector2(300, 590), Vector2(300, 300), Vector2(1000, 200), Vector2(1500, 190), Vector2(1100, 700),
	Vector2(1240, 1000), Vector2(1600, 1040), Vector2(300, 960),
]
const MENU_SPEED := 34.0      # pixels per second

var menu_cam: Camera2D
var _menu_tween: Tween
var _zone := ""
var _zone_timer := 0.0
var _dead_flow := false
var _started := false


func _ready() -> void:
	add_to_group("world")
	var cam: Camera2D = player.camera
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = map_size.x * TILE
	cam.limit_bottom = map_size.y * TILE
	GameState.player_died.connect(_on_player_died)
	GameState.checkpoint_pos = player.global_position
	GameState.player_zone = zone_at(player.global_position)
	GameState.day_changed.connect(func(d): GameState.toast("A new day begins (Day %d). Water your crops!" % d, "info"))
	GameState.boss_defeated.connect(func(): Sfx.play("win", -4))
	if not GameState.playing:
		_start_menu_camera()


func _start_menu_camera() -> void:
	menu_cam = Camera2D.new()
	menu_cam.zoom = Vector2(3, 3)
	menu_cam.limit_left = 0
	menu_cam.limit_top = 0
	menu_cam.limit_right = map_size.x * TILE
	menu_cam.limit_bottom = map_size.y * TILE
	menu_cam.position = MENU_TOUR[0]
	add_child(menu_cam)
	player.camera.enabled = false
	player.visible = false          # the menu shows the empty world
	menu_cam.make_current()
	_menu_tween = create_tween().set_loops()
	for i in MENU_TOUR.size():
		var a: Vector2 = MENU_TOUR[i]
		var b: Vector2 = MENU_TOUR[(i + 1) % MENU_TOUR.size()]
		_menu_tween.tween_property(menu_cam, "position", b, a.distance_to(b) / MENU_SPEED).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_menu_tween.tween_interval(1.5)
	Sfx.play_music("ranch")


func on_game_started() -> void:
	if menu_cam:
		_menu_tween.kill()
		menu_cam.queue_free()
		menu_cam = null
		player.visible = true
		player.camera.enabled = true
		player.camera.make_current()
		player.camera.reset_smoothing()
	_started = true
	Sfx.play_music("ranch")
	_set_zone(zone_at(player.global_position), false)
	# GDD 5.4: the game opens with the player waking up at the ranch
	hud.screens.fade_rect.modulate.a = 1.0
	hud.fade_to(0.0, 1.6)


func zone_at(pos: Vector2) -> String:
	var t := Vector2i(int(pos.x / TILE), int(pos.y / TILE))
	for z in ZONES:
		if (z["rect"] as Rect2i).has_point(t):
			return z["name"]
	return "Trail"


func _physics_process(delta: float) -> void:
	_zone_timer -= delta
	if _zone_timer <= 0.0:
		_zone_timer = 0.15
		var z := zone_at(player.global_position)
		if z != _zone:
			_set_zone(z, true)


func _set_zone(z: String, announce: bool) -> void:
	_zone = z
	GameState.player_zone = z
	if announce and _started and z != "Trail":
		GameState.zone_changed.emit(z)
	for info in ZONES:
		if info["name"] == z and _started:
			Sfx.play_music(info["music"])


# ------------------------------------------------------------------ save / load (see SaveGame)
func capture_save() -> Dictionary:
	var nodes := {}
	for n in get_tree().get_nodes_in_group("saveable"):
		nodes[String(n.name)] = n.save_state()
	var drops: Array = []
	for p in get_tree().get_nodes_in_group("pickups"):
		drops.append({"id": p.item_id, "n": p.amount, "pos": p.global_position})
	return {"player_pos": player.global_position, "face": player.face_name, "nodes": nodes, "pickups": drops}


func apply_save(w: Dictionary) -> void:
	player.global_position = w.get("player_pos", player.global_position)
	var face: String = String(w.get("face", "down"))
	player.face_name = face
	player.facing = Player.FACING_VEC.get(face, Vector2.DOWN)
	player.state = Player.State.FREE
	player.invuln = 1.5
	player.sprite.play("idle_" + face)
	GameState.player_zone = zone_at(player.global_position)
	_zone = GameState.player_zone
	var nodes: Dictionary = w.get("nodes", {})
	for n in get_tree().get_nodes_in_group("saveable"):
		if nodes.has(String(n.name)):
			n.load_state(nodes[String(n.name)])
		elif n.has_method("load_state"):
			n.load_state({})
	for p in get_tree().get_nodes_in_group("pickups"):
		p.queue_free()
	for d in w.get("pickups", []):
		var pk: Node2D = preload("res://scences/pickup.tscn").instantiate()
		pk.item_id = String(d["id"])
		pk.amount = int(d["n"])
		$Entities.add_child(pk)
		pk.global_position = d["pos"]


# ------------------------------------------------------------------ sleeping
func do_sleep() -> void:
	if _dead_flow or GameState.ui_open:
		return
	GameState.open_ui()
	Sfx.play("sleep")
	await hud.fade_to(1.0, 0.7)
	# move on to the next morning
	GameState.game_time = float(GameState.day) * GameState.DAY_LENGTH + 1.0
	GameState.day = int(GameState.game_time / GameState.DAY_LENGTH) + 1
	GameState.day_changed.emit(GameState.day)
	GameState.full_restore()
	GameState.set_checkpoint(GameState.checkpoint_pos if GameState.checkpoint_name == "Ranch bed" else _bed_spawn(), "Ranch bed")
	# sleeping also autosaves into the slot this game came from (like Stardew Valley)
	if SaveGame.current_slot > 0 and SaveGame.save(SaveGame.current_slot, capture_save()):
		GameState.toast("Game saved to Slot %d." % SaveGame.current_slot, "good")
	await get_tree().create_timer(0.8).timeout
	await hud.fade_to(0.0, 0.7)
	GameState.close_ui()
	GameState.toast("You feel rested. HP and MP restored. Materials safe.", "good")


func _bed_spawn() -> Vector2:
	var n := get_node_or_null("Entities/PlayerStart")
	return n.global_position if n else player.global_position


# ------------------------------------------------------------------ death / respawn
func _on_player_died() -> void:
	if _dead_flow:
		return
	_dead_flow = true
	await get_tree().create_timer(1.1).timeout
	await hud.fade_to(1.0, 0.7)
	var where := GameState.checkpoint_name
	var lost := GameState.respawn()
	player.respawn_at(GameState.checkpoint_pos)
	hud.screens.show_death(lost, where)
	await get_tree().create_timer(2.8).timeout
	hud.screens.hide_death()
	await hud.fade_to(0.0, 0.7)
	_dead_flow = false
