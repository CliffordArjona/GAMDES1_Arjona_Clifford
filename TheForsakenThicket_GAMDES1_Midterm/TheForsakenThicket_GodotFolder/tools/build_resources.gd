extends SceneTree
## Builds resources/*.tres (SpriteFrames for every character + the TileSet).
## Run:  godot --headless --path . -s tools/build_resources.gd

const U := preload("res://tools/build_util.gd")
const W := "res://assets/world/"
const G := "res://assets/generated/"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://resources")
	_player()
	_slime()
	_wolf("res://resources/wolf_frames.tres", G + "sprites/wolf.png", 32)
	_wolf("res://resources/boss_frames.tres", G + "sprites/boss.png", 64)
	_npc()
	_chest()
	_tileset()
	quit()


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	print("saved ", path, " err=", err)


func _player() -> void:
	var sf := U.new_frames()
	var cell := Vector2i(32, 32)
	for d in ["Down", "Up", "Left", "Right"]:
		var n: String = d.to_lower()
		U.add_anim(sf, "idle_" + n, U.tex(W + "Player/Idle/Idle%s.png" % d), cell, 0, 0, 4, 5.0, true)
		U.add_anim(sf, "walk_" + n, U.tex(W + "Player/Walk/Walk%s.png" % d), cell, 0, 0, 4, 9.0, true)
		U.add_anim(sf, "run_" + n, U.tex(W + "Player/Run/Run%s.png" % d), cell, 0, 0, 6, 18.0, true)
		U.add_anim(sf, "attack_" + n, U.tex(W + "Player/Attack/Attack%s.png" % d), cell, 0, 0, 6, 16.0, false)
		U.add_anim(sf, "hit_" + n, U.tex(W + "Player/Hit/Hit%s.png" % d), cell, 0, 0, 4, 10.0, false)
	_save(sf, "res://resources/player_frames.tres")


func _slime() -> void:
	var sf := U.new_frames()
	var t := U.tex(W + "Enemies/SlimeAnim.png")
	var cell := Vector2i(32, 32)
	U.add_anim(sf, "idle", t, cell, 0, 0, 3, 4.0, true)
	U.add_anim(sf, "move", t, cell, 1, 0, 4, 7.0, true)
	U.add_anim(sf, "hurt", t, cell, 2, 0, 3, 12.0, false)
	_save(sf, "res://resources/slime_frames.tres")


func _wolf(path: String, sheet: String, size: int) -> void:
	var sf := U.new_frames()
	var t := U.tex(sheet)
	var cell := Vector2i(size, size)
	U.add_anim(sf, "idle", t, cell, 0, 0, 2, 3.0, true)
	U.add_anim(sf, "walk", t, cell, 0, 2, 4, 9.0, true)
	U.add_anim(sf, "windup", t, cell, 0, 6, 1, 1.0, true)
	U.add_anim(sf, "lunge", t, cell, 0, 7, 1, 1.0, true)
	U.add_anim(sf, "hurt", t, cell, 0, 8, 1, 1.0, true)
	_save(sf, path)


func _npc() -> void:
	var sf := U.new_frames()
	U.add_anim(sf, "idle", U.tex(G + "sprites/npc_idle.png"), Vector2i(32, 32), 0, 0, 4, 3.0, true)
	_save(sf, "res://resources/npc_frames.tres")


func _chest() -> void:
	var sf := U.new_frames()
	var t := U.tex(W + "Objects/ChestAnim.png")
	var cell := Vector2i(32, 16)
	U.add_anim(sf, "closed_silver", t, cell, 0, 0, 1, 1.0, true)
	U.add_anim(sf, "open_silver", t, cell, 0, 1, 3, 8.0, false)
	U.add_anim(sf, "closed_gold", t, cell, 1, 0, 1, 1.0, true)
	U.add_anim(sf, "open_gold", t, cell, 1, 1, 3, 8.0, false)
	_save(sf, "res://resources/chest_frames.tres")


func _tileset() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	# source 0 = ground atlas (8 x 4), source 1 = decor atlas (8 x 2)
	for spec in [[G + "tiles/ground_atlas.png", 8, 4], [G + "tiles/decor_atlas.png", 8, 2]]:
		var src := TileSetAtlasSource.new()
		src.texture = U.tex(spec[0])
		src.texture_region_size = Vector2i(16, 16)
		for y in spec[2]:
			for x in spec[1]:
				src.create_tile(Vector2i(x, y))
		ts.add_source(src)
	# canopy tiles (ground atlas indices 20,21,22 -> x 4,5,6 on row 2) are solid walls
	var ground := ts.get_source(0) as TileSetAtlasSource
	var poly := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	for x in [4, 5, 6]:
		var td := ground.get_tile_data(Vector2i(x, 2), 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, poly)
	_save(ts, "res://resources/tileset.tres")
