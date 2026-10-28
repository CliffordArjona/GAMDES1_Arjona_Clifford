extends Node
## Builds scences/world.tscn (the prototype forest zone from GDD Figure 5.1) and scences/main.tscn.
## Run:  godot --headless --path . res://tools/build_runner.tscn -- build_world
## After this the map is a normal scene: open world.tscn in the editor and drag things around.

const U := preload("res://tools/build_util.gd")
const G := "res://assets/generated/"
const S := "res://scences/"
const T := 16
const W := 112
const H := 78

# --- zones (tile rects).  Keep in sync with scripts/world.gd ---------------------------
const ZONES := {
	"Ranch Base": Rect2i(4, 28, 32, 26),
	"Whispering Grove": Rect2i(4, 4, 32, 22),
	"Rocky Outcrop": Rect2i(4, 56, 32, 18),
	"Slime Meadow": Rect2i(50, 4, 60, 22),
	"Wolf Hollow": Rect2i(50, 28, 60, 26),
	"Checkpoint Shrine": Rect2i(68, 57, 18, 17),
	"Mini-Boss Arena": Rect2i(90, 56, 20, 19),
}
const CORRIDORS := [
	Rect2i(17, 26, 6, 2),    # Grove <-> Ranch (open)
	Rect2i(17, 54, 6, 2),    # Ranch <-> Outcrop (open)
	Rect2i(36, 31, 10, 4),   # Ranch east exit  (Thorn Barrier O1)
	Rect2i(42, 12, 4, 23),   # trail north to the meadow
	Rect2i(46, 12, 4, 4),    # into Slime Meadow
	Rect2i(36, 43, 14, 4),   # Ranch -> Wolf Hollow (Ruin Gate O3)
	Rect2i(78, 54, 4, 3),    # Wolf Hollow -> Shrine
	Rect2i(86, 63, 4, 4),    # Shrine -> Arena (Arena Seal O6)
]
const PATHS := [             # dirt paths painted over the ground
	Rect2i(10, 35, 3, 3), Rect2i(13, 36, 22, 2), Rect2i(31, 32, 4, 6), Rect2i(31, 43, 5, 4),
	Rect2i(17, 26, 6, 11), Rect2i(17, 47, 6, 9),
]
const GARDEN := Rect2i(9, 39, 6, 4)   # farm plots (4 x 2) sit in here

# tile coordinates in assets/generated/tiles/ground_atlas.png (8 columns)
const TILE_NAMES := [
	"grass_a", "grass_b", "grass_c", "grass_d", "meadow_a", "meadow_b", "path_a", "path_b",
	"plot_dirt", "tilled_dry", "tilled_wet", "rock_a", "rock_b", "cursed_a", "cursed_b", "cursed_c",
	"arena_a", "arena_b", "arena_rune", "shrine_floor", "canopy_a", "canopy_b", "canopy_c", "wood_floor",
]
const DECOR_NAMES := ["flower_a", "flower_b", "flower_c", "mushroom_r", "mushroom_b", "tuft_a", "tuft_b", "pebble",
	"leaf_a", "bone", "skull", "glow_a", "glow_b", "rubble", "weed_dead", "crack"]

var rng := RandomNumberGenerator.new()
var walk := PackedByteArray()
var zone_grid: Array = []          # zone name per cell ("" = wall, "Trail" = corridor)
var ground: TileMapLayer
var decor: TileMapLayer
var canopy: TileMapLayer
var entities: Node2D
var fence_body: StaticBody2D


func _ready() -> void:
	rng.seed = 20260921
	_make_grids()
	var world := Node2D.new()
	world.name = "World"
	world.set_script(load("res://scripts/world.gd"))
	var ts: TileSet = load("res://resources/tileset.tres")
	ground = _layer(world, "Ground", ts, -10)
	decor = _layer(world, "Decor", ts, -9)
	canopy = _layer(world, "Canopy", ts, -8)
	entities = Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	world.add_child(entities)
	fence_body = StaticBody2D.new()
	fence_body.name = "Fences"
	fence_body.collision_layer = U.bits([1])
	fence_body.collision_mask = 0
	entities.add_child(fence_body)
	_paint_ground()
	_paint_walls()
	_scatter_decor()
	_border_trees()
	_place_ranch()
	_place_grove()
	_place_outcrop()
	_place_meadow()
	_place_hollow()
	_place_shrine_and_arena()
	_place_player()
	U.save_scene(world, S + "world.tscn")
	world.free()
	_save_main()
	get_tree().quit()


# ------------------------------------------------------------------ grids
func _make_grids() -> void:
	walk.resize(W * H)
	zone_grid = []
	for i in W * H:
		zone_grid.append("")
	for name in ZONES:
		var r: Rect2i = ZONES[name]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				_mark(x, y, name)
	for r in CORRIDORS:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if zone_grid[y * W + x] == "":
					_mark(x, y, "Trail")


func _mark(x: int, y: int, name: String) -> void:
	if x < 0 or y < 0 or x >= W or y >= H:
		return
	walk[y * W + x] = 1
	zone_grid[y * W + x] = name


func _is_walk(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < W and y < H and walk[y * W + x] == 1


func _zone(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= W or y >= H:
		return ""
	return zone_grid[y * W + x]


func _layer(parent: Node, name: String, ts: TileSet, z: int) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.name = name
	l.tile_set = ts
	l.z_index = z
	parent.add_child(l)
	return l


func _tc(name: String) -> Vector2i:
	var i := TILE_NAMES.find(name)
	return Vector2i(i % 8, i / 8)


func _dc(name: String) -> Vector2i:
	var i := DECOR_NAMES.find(name)
	return Vector2i(i % 8, i / 8)


func _pick(names: Array, weights: Array) -> String:
	var total := 0.0
	for w in weights:
		total += w
	var r := rng.randf() * total
	for i in names.size():
		r -= weights[i]
		if r <= 0.0:
			return names[i]
	return names[0]


# ------------------------------------------------------------------ painting
func _paint_ground() -> void:
	for y in H:
		for x in W:
			var z := _zone(x, y)
			var tile := "grass_a"
			match z:
				"Ranch Base": tile = _pick(["grass_a", "grass_b", "grass_c", "grass_d"], [55, 20, 15, 10])
				"Whispering Grove": tile = _pick(["grass_b", "grass_c", "grass_d"], [30, 35, 35])
				"Rocky Outcrop": tile = _pick(["rock_a", "rock_b"], [60, 40])
				"Slime Meadow": tile = _pick(["meadow_a", "meadow_b", "grass_b", "grass_a"], [24, 14, 32, 30])
				"Wolf Hollow": tile = _pick(["cursed_a", "cursed_b", "cursed_c"], [55, 30, 15])
				"Checkpoint Shrine": tile = _pick(["grass_a", "grass_c", "grass_b"], [60, 25, 15])
				"Mini-Boss Arena": tile = _pick(["arena_a", "arena_b"], [60, 40])
				"Trail": tile = _pick(["path_a", "path_b"], [60, 40])
				_: tile = "grass_a"
			ground.set_cell(Vector2i(x, y), 0, _tc(tile))
	# dirt paths
	for r in PATHS:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if _is_walk(x, y):
					ground.set_cell(Vector2i(x, y), 0, _tc(_pick(["path_a", "path_b"], [65, 35])))
	# farm garden
	for y in range(GARDEN.position.y - 1, GARDEN.end.y + 1):
		for x in range(GARDEN.position.x - 1, GARDEN.end.x + 1):
			ground.set_cell(Vector2i(x, y), 0, _tc(_pick(["grass_a", "grass_b"], [70, 30])))
	for y in range(GARDEN.position.y, GARDEN.end.y):
		for x in range(GARDEN.position.x, GARDEN.end.x):
			ground.set_cell(Vector2i(x, y), 0, _tc("plot_dirt"))
	# stone circle around the shrine
	var sc := Vector2(77, 62)
	for y in range(56, 70):
		for x in range(70, 86):
			if Vector2(x, y).distance_to(sc) <= 4.6 and _is_walk(x, y):
				ground.set_cell(Vector2i(x, y), 0, _tc("shrine_floor"))
	# four rune tiles around the arena centre
	for p in [Vector2i(98, 64), Vector2i(102, 64), Vector2i(98, 68), Vector2i(102, 68)]:
		ground.set_cell(p, 0, _tc("arena_rune"))


func _paint_walls() -> void:
	for y in H:
		for x in W:
			if not _is_walk(x, y):
				canopy.set_cell(Vector2i(x, y), 0, _tc(_pick(["canopy_a", "canopy_b", "canopy_c"], [40, 35, 25])))


func _scatter_decor() -> void:
	for y in H:
		for x in W:
			if not _is_walk(x, y):
				continue
			var z := _zone(x, y)
			if GARDEN.grow(1).has_point(Vector2i(x, y)):
				continue
			var chance := 0.0
			var names: Array = []
			match z:
				"Ranch Base": chance = 0.05; names = ["flower_a", "flower_b", "tuft_a", "tuft_b", "leaf_a"]
				"Whispering Grove": chance = 0.10; names = ["mushroom_r", "mushroom_b", "flower_c", "tuft_a", "leaf_a", "flower_a"]
				"Rocky Outcrop": chance = 0.07; names = ["pebble", "rubble", "pebble", "tuft_b"]
				"Slime Meadow": chance = 0.12; names = ["flower_a", "flower_b", "flower_c", "tuft_a", "flower_a", "mushroom_r"]
				"Wolf Hollow": chance = 0.08; names = ["bone", "skull", "glow_a", "crack", "weed_dead", "glow_a", "rubble"]
				"Checkpoint Shrine": chance = 0.05; names = ["glow_b", "pebble", "tuft_b"]
				"Mini-Boss Arena": chance = 0.03; names = ["crack", "rubble"]
			if chance > 0.0 and rng.randf() < chance:
				decor.set_cell(Vector2i(x, y), 1, _dc(names[rng.randi() % names.size()]))


# ------------------------------------------------------------------ entity helpers
func foot_offset(tex_path: String) -> Vector2:
	var img := (load(tex_path) as Texture2D).get_image()
	var r := img.get_used_rect()
	return Vector2(-((r.position.x + r.end.x) / 2.0 - img.get_width() / 2.0), -(r.end.y - img.get_height() / 2.0))


func P(tx: float, ty: float) -> Vector2:
	return Vector2(tx * T + 8.0, ty * T + 8.0)


func _add(n: Node, pos: Vector2, name: String = "") -> Node:
	if name != "":
		n.name = name
	entities.add_child(n)
	n.position = pos
	return n


func inst(scene: String, pos: Vector2, name: String = "") -> Node:
	var n: Node = (load(S + scene + ".tscn") as PackedScene).instantiate()
	return _add(n, pos, name)


## A decorative prop; collider_r > 0 adds a solid circle at its feet.
func prop(tex_path: String, pos: Vector2, collider_r: float = 0.0, name: String = "", layer: int = 1) -> Node:
	var spr := Sprite2D.new()
	spr.texture = load(tex_path)
	spr.offset = foot_offset(tex_path)
	if collider_r <= 0.0:
		return _add(spr, pos, name)
	var b := StaticBody2D.new()
	b.collision_layer = U.bits([layer])
	b.collision_mask = 0
	b.add_child(spr)
	b.add_child(U.shape_node(U.circle(collider_r), Vector2(0, -collider_r * 0.4)))
	return _add(b, pos, name)


func _fence(x: int, y: int, horizontal: bool) -> void:
	var path := G + "props/" + ("fence_h.png" if horizontal else "fence_v.png")
	prop(path, Vector2(x * T + 8.0, y * T + 14.0), 0.0)
	fence_body.add_child(U.shape_node(U.rect(16.0, 7.0), Vector2(x * T + 8.0, y * T + 10.0), "Fence_%d_%d" % [x, y]))


# ------------------------------------------------------------------ border trees (decoration only)
func _border_trees() -> void:
	var tree := G + "props/tree.png"
	var tree_c := G + "props/tree_cursed.png"
	var bush := G + "props/bush.png"
	var bush_c := G + "props/bush_cursed.png"
	var boulder := G + "props/boulder_big.png"
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			if _is_walk(x, y):
				continue
			# nearest walkable cell within 2 tiles, to pick the style
			var near := ""
			var dist := 99
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if _is_walk(x + dx, y + dy):
						var d := maxi(absi(dx), absi(dy))
						if d < dist:
							dist = d
							near = _zone(x + dx, y + dy)
			if near == "" or dist < 2 or rng.randf() > 0.26:
				continue
			var pos := Vector2(x * T + 8.0 + rng.randf_range(-5, 5), y * T + 15.0 + rng.randf_range(-2, 2))
			var p := ""
			match near:
				"Wolf Hollow", "Checkpoint Shrine": p = tree_c if rng.randf() < 0.7 else bush_c
				"Mini-Boss Arena": p = bush_c if rng.randf() < 0.5 else boulder
				"Rocky Outcrop": p = boulder if rng.randf() < 0.55 else (tree if rng.randf() < 0.5 else bush)
				_: p = tree if rng.randf() < 0.72 else bush
			prop(p, pos)


# ------------------------------------------------------------------ the Ranch (hub)
func _place_ranch() -> void:
	# --- cabin (floor, walls, door frame) ---
	var cx := 96.0
	var cy := 464.0
	var floor_s := Sprite2D.new()
	floor_s.texture = load(G + "cabin/cabin_floor.png")
	floor_s.centered = false
	floor_s.z_index = -7
	_add(floor_s, Vector2(cx, cy), "CabinFloor")
	_wall_piece("cabin/cabin_back_wall.png", Vector2(cx, cy + 32), 32, "CabinBackWall")
	_wall_piece("cabin/cabin_side_wall.png", Vector2(cx, cy + 112), 112, "CabinLeftWall")
	_wall_piece("cabin/cabin_side_wall.png", Vector2(cx + 144, cy + 112), 112, "CabinRightWall")
	_wall_piece("cabin/cabin_front_left.png", Vector2(cx, cy + 112), 16, "CabinFrontLeft")
	_wall_piece("cabin/cabin_front_right.png", Vector2(cx + 96, cy + 112), 16, "CabinFrontRight")
	var door := Sprite2D.new()
	door.texture = load(G + "cabin/cabin_door_frame.png")
	door.offset = Vector2(0, -12)
	_add(door, Vector2(cx + 80, cy + 113), "CabinDoorFrame")
	var walls := StaticBody2D.new()
	walls.name = "CabinWalls"
	walls.collision_layer = U.bits([1])
	walls.collision_mask = 0
	for r in [Rect2(0, 0, 160, 30), Rect2(0, 0, 16, 112), Rect2(144, 0, 16, 112), Rect2(0, 98, 64, 14), Rect2(96, 98, 64, 14)]:
		var rr: Rect2 = r
		walls.add_child(U.shape_node(U.rect(rr.size.x, rr.size.y), Vector2(cx, cy) + rr.position + rr.size / 2.0))
	entities.add_child(walls)
	# --- furniture ---
	inst("bed", Vector2(cx + 28, cy + 70), "Bed")
	prop(G + "props/bookshelf.png", Vector2(cx + 124, cy + 52), 7.0, "Bookshelf")
	prop(G + "props/plant_pot_2.png", Vector2(cx + 44, cy + 52), 4.0)
	prop(G + "props/plant_pot_3.png", Vector2(cx + 108, cy + 52), 4.0)
	prop(G + "props/stool.png", Vector2(cx + 128, cy + 86), 4.0)

	# --- farm garden: 4 x 2 plots + a fence with a gap on the north side ---
	var gx := GARDEN.position.x
	var gy := GARDEN.position.y
	for i in 4:
		for j in 2:
			inst("crop_plot", P(gx + 1 + i, gy + 1 + j), "Plot_%d_%d" % [i, j])
	for x in range(gx - 1, gx + GARDEN.size.x + 1):
		if x != gx + 2 and x != gx + 3:
			_fence(x, gy - 1, true)
		_fence(x, gy + GARDEN.size.y, true)
	for y in range(gy, gy + GARDEN.size.y):
		_fence(gx - 1, y, false)
		_fence(gx + GARDEN.size.x, y, false)

	# --- crafting, NPC, gates, signs, decorations ---
	inst("base_bench", Vector2(24 * T + 8.0, 38 * T + 12.0), "BaseBench")
	inst("village_npc", Vector2(556.0, 556.0), "VillageNPC")
	inst("gate_thorn", Vector2(602.0, 528.0), "ThornBarrier_O1")
	inst("gate_ruin", Vector2(602.0, 720.0), "RuinGate_O3")
	prop(G + "props/signpost_arrow.png", P(32, 36), 3.0, "Sign_East")
	prop(G + "props/signpost.png", P(17, 29), 3.0, "Sign_Grove")
	prop(G + "props/signpost.png", P(21, 51), 3.0, "Sign_Outcrop")
	prop(G + "props/crate_stack.png", P(27, 37), 8.0, "Crates")
	prop(G + "props/crate.png", P(29, 38), 6.0)
	prop(G + "props/jar.png", P(26, 39), 4.0)
	prop(G + "props/log_horizontal.png", P(27, 45), 8.0)
	for p in [P(6, 43), P(7, 48), P(30, 29), P(33, 49), P(24, 47), P(20, 31), P(5, 52)]:
		prop(G + "props/bush.png", p, 8.0)
	for p in [P(4, 40), P(31, 41), P(15, 50), P(28, 31)]:
		prop(G + "props/plant_pot_%d.png" % rng.randi_range(0, 3), p, 0.0)


func _wall_piece(tex: String, bottom_left: Vector2, height: float, name: String) -> void:
	var s := Sprite2D.new()
	s.texture = load(G + tex)
	s.centered = false
	s.offset = Vector2(0, -height)
	_add(s, bottom_left, name)


# ------------------------------------------------------------------ Whispering Grove (wood)
func _place_grove() -> void:
	# 5 tree nodes: one near the ranch exit, the rest spread through the grove
	for i in 5:
		var pts := [P(19, 22), P(9, 17), P(27, 15), P(14, 9), P(30, 8)]
		inst("tree_node", pts[i], "TreeNode_%d" % (i + 1))
	var ch := inst("chest", P(6, 6), "HiddenChest_Grove")
	ch.set("loot", {"health_potion": 1})
	for p in [P(7, 7), P(8, 6), P(22, 5), P(31, 13), P(12, 20), P(24, 21), P(17, 14), P(6, 12)]:
		prop(G + "props/bush.png", p, 8.0)
	prop(G + "props/log_vertical.png", P(21, 12), 6.0)
	prop(G + "props/log_horizontal.png", P(11, 12), 8.0)
	prop(G + "props/crate.png", P(30, 22), 6.0)


# ------------------------------------------------------------------ Rocky Outcrop (stone)
func _place_outcrop() -> void:
	var pts := [P(18, 60), P(10, 66), P(27, 68)]
	for i in 3:
		inst("stone_node", pts[i], "StoneNode_%d" % (i + 1))
	for p in [P(6, 59), P(14, 70), P(31, 62), P(22, 71), P(7, 69), P(32, 58), P(24, 63)]:
		prop(G + "props/boulder_big.png", p, 11.0)
	prop(G + "props/rocks_small.png", P(15, 63), 0.0)
	prop(G + "props/rocks_small.png", P(29, 65), 0.0)


# ------------------------------------------------------------------ Slime Meadow
func _place_meadow() -> void:
	inst("stone_node", P(53, 10), "EdgeStoneNode")
	var s1 := inst("slime", P(57, 12), "Slime_1")
	var s2 := inst("slime", P(76, 17), "Slime_2")
	# the pit slime: trapped in a low stone pit, only the MP skill can reach it
	var c := Vector2(1576.0, 168.0)
	var pit := Sprite2D.new()
	pit.texture = load(G + "props/pit.png")
	pit.z_index = -6
	_add(pit, c + Vector2(0, -2), "PitFloor")
	var pit_slime := inst("slime", c + Vector2(0, 4), "Slime_Pit")
	pit_slime.set("immobile", true)
	pit_slime.set("melee_immune", true)
	for i in 10:
		var a := TAU * i / 10.0
		var pos := c + Vector2(cos(a) * 34.0, sin(a) * 22.0 + 6.0)
		prop(G + "props/rocks_small.png" if i % 2 == 0 else G + "props/boulder_big.png", pos, 10.0, "PitWall_%d" % i, 9)
	# invisible extra wall so nobody can squeeze between the boulders
	var pw := StaticBody2D.new()
	pw.name = "PitWallBody"
	pw.collision_layer = U.bits([9])
	pw.collision_mask = 0
	for i in 20:
		var a2 := TAU * i / 20.0
		pw.add_child(U.shape_node(U.circle(8.0), c + Vector2(cos(a2) * 31.0, sin(a2) * 21.0 + 6.0), "Seg_%d" % i))
	entities.add_child(pw)
	prop(G + "props/signpost.png", P(55, 15), 3.0, "Sign_Meadow")
	for p in [P(66, 7), P(84, 8), P(90, 20), P(70, 21), P(104, 22), P(58, 20), P(100, 6)]:
		prop(G + "props/bush.png", p, 8.0)
	prop(G + "props/log_horizontal.png", P(80, 12), 8.0)


# ------------------------------------------------------------------ Wolf Hollow (cursed ruins)
func _place_hollow() -> void:
	var lone := inst("wolf", P(61, 44), "Wolf_Lone_O4")
	lone.set("strafe", 0.0)
	var w1 := inst("wolf", P(88, 38), "Wolf_Pair_A_O5")
	w1.set("strafe", 0.45)
	var w2 := inst("wolf", P(93, 44), "Wolf_Pair_B_O5")
	w2.set("strafe", -0.45)
	w2.set("wait_until_provoked", true)
	# ruined pillars give cover near the lone wolf
	for p in [P(58, 41), P(65, 47), P(63, 40), P(60, 48)]:
		prop(G + "props/pillar_cursed_broken.png", p, 5.0)
	for p in [P(72, 36), P(76, 45), P(82, 49), P(97, 36), P(86, 33)]:
		prop(G + "props/pillar_cursed.png", p, 5.0)
	for p in [P(56, 34), P(70, 31), P(79, 41), P(100, 50), P(104, 38), P(66, 51), P(92, 31)]:
		prop(G + "props/tree_cursed.png", p, 5.0)
	var ch := inst("chest", P(105, 31), "HiddenChest_Hollow")
	ch.set("gold", true)
	ch.set("loot", {"mana_potion": 1})
	prop(G + "props/signpost_arrow.png", P(53, 42), 3.0, "Sign_Hollow")
	for p in [P(74, 51), P(100, 44), P(60, 33)]:
		prop(G + "props/boulder_big.png", p, 11.0)


# ------------------------------------------------------------------ Shrine and Arena
func _place_shrine_and_arena() -> void:
	inst("checkpoint_shrine", P(77, 62), "CheckpointShrine_P7")
	for p in [P(72, 60), P(82, 60), P(72, 68), P(82, 68)]:
		prop(G + "props/pillar_cursed_broken.png", p, 5.0)
	inst("gate_seal", Vector2(87 * T + 10.0, 65 * T), "ArenaSeal_O6")
	var boss := inst("mini_boss", P(100, 67), "Warden_O7")
	boss.set("zone_name", "Mini-Boss Arena")
	inst("escape_gate", Vector2(100 * T + 8.0, 59 * T), "EscapeGate")
	for p in [P(92, 59), P(107, 59), P(92, 72), P(107, 72)]:
		prop(G + "props/pillar_arena.png", p, 6.0)


func _place_player() -> void:
	var start := Marker2D.new()
	start.name = "PlayerStart"
	_add(start, Vector2(176.0, 598.0))
	inst("player", Vector2(176.0, 598.0), "Player")


# ------------------------------------------------------------------ main scene
func _save_main() -> void:
	var m := Node.new()
	m.name = "Main"
	m.set_script(load("res://scripts/main.gd"))
	var hud: Node = (load(S + "hud.tscn") as PackedScene).instantiate()
	hud.name = "Hud"
	m.add_child(hud)
	var world: Node = (load(S + "world.tscn") as PackedScene).instantiate()
	world.name = "World"
	m.add_child(world)
	U.save_scene(m, S + "main.tscn")
	m.free()
