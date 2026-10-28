extends Node
## Builds every reusable scene in scences/ (player, enemies, farm plot, nodes, gates ...).
## Run:  godot --headless --path . -s tools/build_scenes.gd
## (You normally never need to run this again - open the .tscn files in the editor and edit them.)

const U := preload("res://tools/build_util.gd")
const G := "res://assets/generated/"
const OUT := "res://scences/"

# physics layers (see Project Settings > Layer Names > 2D Physics)
const L_WORLD := 1
const L_PLAYER := 2
const L_ENEMY := 3
const L_INTERACT := 4
const L_PLAYER_ATTACK := 5
const L_ENEMY_ATTACK := 6
const L_ENEMY_HURT := 7
const L_PLAYER_HURT := 8
const L_LOW_WALL := 9


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("res://scences")
	_projectile()
	_pickup()
	_player()
	_enemy("slime", "res://resources/slime_frames.tres", {
		"display_name": "Slime", "max_hp": 24, "move_speed": 30.0, "contact_damage": 8, "aggro_radius": 82.0,
		"leash_radius": 170.0, "attack_range": 20.0, "windup_time": 0.9, "attack_time": 0.28, "attack_speed": 85.0,
		"recover_time": 1.3, "hurt_stun": 0.3, "zone_name": "Slime Meadow",
		"drops": {"slime_gel": Vector2i(1, 2)},
	}, Vector2(0, -6), 7.0, Vector2(0, -7), Vector2(0, -26), 20.0, 0.0)
	_enemy("wolf", "res://resources/wolf_frames.tres", {
		"display_name": "Wolf", "max_hp": 40, "move_speed": 66.0, "contact_damage": 14, "aggro_radius": 100.0,
		"leash_radius": 200.0, "attack_range": 46.0, "windup_time": 0.65, "attack_time": 0.34, "attack_speed": 215.0,
		"recover_time": 0.9, "hurt_stun": 0.22, "zone_name": "Wolf Hollow",
		"drops": {"wolf_fang": Vector2i(2, 2)},
	}, Vector2(0, -12), 6.0, Vector2(0, -9), Vector2(0, -34), 22.0, 0.0)
	_enemy("mini_boss", "res://resources/boss_frames.tres", {
		"display_name": "The Warden", "kind": "boss", "max_hp": 240, "move_speed": 78.0, "contact_damage": 24,
		"aggro_radius": 150.0, "leash_radius": 280.0, "attack_range": 62.0, "windup_time": 0.8, "attack_time": 0.38,
		"attack_speed": 230.0, "recover_time": 0.85, "zone_name": "Mini-Boss Arena", "is_boss": true,
		"slam_radius": 54.0, "slam_damage": 20, "respawns": false,
		"drops": {"health_potion": Vector2i(1, 1)},
	}, Vector2(0, -24), 9.0, Vector2(0, -18), Vector2(0, -62), 36.0, 1.0)
	_npc()
	_crop_plot()
	_resource_node("tree_node", G + "props/tree.png", G + "props/stump.png", "wood", 2, 3, "Chop tree", 5.0)
	_resource_node("stone_node", G + "props/stone_node.png", G + "props/stone_rubble.png", "stone", 2, 3, "Mine rock", 8.0)
	_bench()
	_bed()
	_shrine()
	_chest()
	_gate("gate_thorn", "thorn", G + "gates/thorn_barrier.png", "The thorns wither away. The path east is open.")
	_gate("gate_ruin", "ruin", G + "gates/ruin_gate.png", "The ruin gate grinds open. Wolf Hollow lies ahead.")
	_gate("gate_seal", "seal", G + "gates/arena_seal.png", "The Arena Seal shatters. The Warden awaits.")
	_escape_gate()
	_hud()
	get_tree().quit()


# ------------------------------------------------------------------ helpers
func foot_offset(tex_path: String) -> Vector2:
	var img := (load(tex_path) as Texture2D).get_image()
	var r := img.get_used_rect()
	return Vector2(-((r.position.x + r.end.x) / 2.0 - img.get_width() / 2.0), -(r.end.y - img.get_height() / 2.0))


func _save(root: Node, name: String) -> void:
	U.save_scene(root, OUT + name + ".tscn")
	root.free()


func _interact_area(radius: float, pos: Vector2 = Vector2.ZERO) -> Area2D:
	var a := U.area("Interact", [L_INTERACT], [], false, true)
	a.add_child(U.shape_node(U.circle(radius), pos))
	return a


# ------------------------------------------------------------------ scenes
func _projectile() -> void:
	var a := U.area("Projectile", [L_PLAYER_ATTACK], [L_ENEMY_HURT, L_WORLD], true, false)
	a.set_script(load("res://scripts/projectile.gd"))
	var s := Sprite2D.new()
	s.name = "Sprite2D"
	s.texture = load(G + "fx/bolt.png")
	s.hframes = 4
	a.add_child(s)
	a.add_child(U.shape_node(U.circle(3.5)))
	_save(a, "projectile")


func _pickup() -> void:
	var n := Node2D.new()
	n.name = "Pickup"
	n.set_script(load("res://scripts/pickup.gd"))
	var sh := Sprite2D.new()
	sh.name = "Shadow"
	sh.texture = load(G + "fx/shadow.png")
	sh.scale = Vector2(0.5, 0.5)
	n.add_child(sh)
	var s := Sprite2D.new()
	s.name = "Sprite2D"
	s.position = Vector2(0, -6)
	n.add_child(s)
	_save(n, "pickup")


func _player() -> void:
	var p := CharacterBody2D.new()
	p.name = "Player"
	p.collision_layer = U.bits([L_PLAYER])
	p.collision_mask = U.bits([L_WORLD, L_LOW_WALL])
	p.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	p.set_script(load("res://scripts/player.gd"))
	var shadow := Sprite2D.new()
	shadow.name = "Shadow"
	shadow.texture = load(G + "fx/shadow.png")
	shadow.position = Vector2(0, -1)
	p.add_child(shadow)
	var spr := AnimatedSprite2D.new()
	spr.name = "Sprite"
	spr.sprite_frames = load("res://resources/player_frames.tres")
	spr.animation = &"idle_down"
	spr.autoplay = "idle_down"
	spr.offset = Vector2(0, -8)
	p.add_child(spr)
	p.add_child(U.shape_node(U.circle(4.5), Vector2(0, -2)))
	var hb := U.area("Hurtbox", [L_PLAYER_HURT], [], false, true)
	hb.add_child(U.shape_node(U.circle(6.0), Vector2(0, -9)))
	p.add_child(hb)
	var sw := U.area("SwordHit", [L_PLAYER_ATTACK], [L_ENEMY_HURT], false, false)
	sw.add_child(U.shape_node(U.rect(26.0, 22.0), Vector2(0, 6)))
	p.add_child(sw)
	var ia := U.area("InteractArea", [], [L_INTERACT], true, false)
	ia.add_child(U.shape_node(U.circle(22.0), Vector2(0, -6)))
	p.add_child(ia)
	var cam := Camera2D.new()
	cam.name = "Camera2D"
	cam.zoom = Vector2(3, 3)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 9.0
	cam.position = Vector2(0, -8)
	p.add_child(cam)
	_save(p, "player")


func _enemy(scene_name: String, frames: String, props: Dictionary, sprite_offset: Vector2, body_r: float,
		hurt_pos: Vector2, bar_pos: Vector2, hurt_size: float, boss: float) -> void:
	var e := CharacterBody2D.new()
	e.name = scene_name.capitalize().replace(" ", "")
	e.collision_layer = U.bits([L_ENEMY])
	e.collision_mask = U.bits([L_WORLD, L_LOW_WALL])
	e.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	e.set_script(load("res://scripts/enemy.gd"))
	e.set("kind", props.get("kind", scene_name))
	for k in props:
		if k != "kind":
			e.set(k, props[k])
	var shadow := Sprite2D.new()
	shadow.name = "Shadow"
	shadow.texture = load(G + ("fx/shadow_big.png" if boss > 0.5 else "fx/shadow.png"))
	shadow.position = Vector2(0, -1)
	e.add_child(shadow)
	var spr := AnimatedSprite2D.new()
	spr.name = "Sprite"
	spr.sprite_frames = load(frames)
	spr.animation = &"idle"
	spr.autoplay = "idle"
	spr.offset = sprite_offset
	e.add_child(spr)
	e.add_child(U.shape_node(U.circle(body_r), Vector2(0, -body_r * 0.6)))
	var hb := U.area("Hurtbox", [L_ENEMY_HURT], [], false, true)
	hb.add_child(U.shape_node(U.rect(hurt_size, hurt_size * (0.8 if scene_name != "slime" else 0.7)), hurt_pos))
	e.add_child(hb)
	var ab := U.area("AttackBox", [L_ENEMY_ATTACK], [L_PLAYER_HURT], false, false)
	ab.add_child(U.shape_node(U.circle(hurt_size * 0.55), Vector2(0, hurt_pos.y)))
	e.add_child(ab)
	var al := Sprite2D.new()
	al.name = "Alert"
	al.texture = load(G + "fx/alert.png")
	al.position = Vector2(0, bar_pos.y - 8)
	al.visible = false
	e.add_child(al)
	var bar := Node2D.new()
	bar.name = "Bar"
	bar.position = bar_pos
	bar.set_script(load("res://scripts/hp_bar.gd"))
	bar.set("width", 18.0 if boss < 0.5 else 30.0)
	e.add_child(bar)
	if boss > 0.5:
		var t := Sprite2D.new()
		t.name = "Telegraph"
		t.texture = load(G + "fx/telegraph.png")
		t.position = Vector2(0, -4)
		t.z_index = -1
		t.visible = false
		e.add_child(t)
	_save(e, scene_name)


func _npc() -> void:
	var n := StaticBody2D.new()
	n.name = "VillageNPC"
	n.collision_layer = U.bits([L_WORLD])
	n.collision_mask = 0
	n.set_script(load("res://scripts/npc.gd"))
	var sh := Sprite2D.new()
	sh.name = "Shadow"
	sh.texture = load(G + "fx/shadow.png")
	sh.position = Vector2(0, -1)
	n.add_child(sh)
	var spr := AnimatedSprite2D.new()
	spr.name = "Sprite"
	spr.sprite_frames = load("res://resources/npc_frames.tres")
	spr.animation = &"idle"
	spr.autoplay = "idle"
	spr.offset = Vector2(0, -8)
	n.add_child(spr)
	n.add_child(U.shape_node(U.circle(5.0), Vector2(0, -3)))
	n.add_child(_interact_area(22.0, Vector2(0, -6)))
	var m := Sprite2D.new()
	m.name = "Mark"
	m.texture = load(G + "sprites/quest_mark.png")
	m.position = Vector2(0, -34)
	n.add_child(m)
	_save(n, "village_npc")


func _crop_plot() -> void:
	var n := Node2D.new()
	n.name = "CropPlot"
	n.set_script(load("res://scripts/crop_plot.gd"))
	var soil := Sprite2D.new()
	soil.name = "Soil"
	soil.texture = load(G + "tiles/ground_atlas.png")
	soil.region_enabled = true
	soil.region_rect = Rect2(0, 16, 16, 16)
	n.add_child(soil)
	var crop := Sprite2D.new()
	crop.name = "Crop"
	crop.texture = load(G + "sprites/crops.png")
	crop.region_enabled = true
	crop.region_rect = Rect2(0, 0, 20, 28)
	crop.position = Vector2(0, -6)
	crop.visible = false
	n.add_child(crop)
	var a := U.area("Interact", [L_INTERACT], [], false, true)
	a.add_child(U.shape_node(U.rect(15.0, 15.0)))
	n.add_child(a)
	_save(n, "crop_plot")


func _resource_node(scene_name: String, full: String, depleted: String, item: String, amount: int, hits: int,
		verb: String, collider_r: float) -> void:
	var b := StaticBody2D.new()
	b.name = scene_name.capitalize().replace(" ", "")
	b.collision_layer = U.bits([L_WORLD])
	b.collision_mask = 0
	b.set_script(load("res://scripts/resource_node.gd"))
	b.set("item_id", item)
	b.set("amount", amount)
	b.set("hits_needed", hits)
	b.set("verb", verb)
	b.set("full_tex", load(full))
	b.set("depleted_tex", load(depleted))
	b.set("full_offset", foot_offset(full))
	b.set("depleted_offset", foot_offset(depleted))
	var s := Sprite2D.new()
	s.name = "Sprite"
	s.texture = load(full)
	s.offset = foot_offset(full)
	b.add_child(s)
	b.add_child(U.shape_node(U.circle(collider_r), Vector2(0, -collider_r * 0.5)))
	b.add_child(_interact_area(24.0, Vector2(0, -6)))
	_save(b, scene_name)


func _bench() -> void:
	var n := Node2D.new()
	n.name = "BaseBench"
	n.set_script(load("res://scripts/bench.gd"))
	var path := G + "props/bench.png"
	var s := U.sprite(path, foot_offset(path))
	n.add_child(s)
	var body := StaticBody2D.new()
	body.name = "Body"
	body.collision_layer = U.bits([L_WORLD])
	body.collision_mask = 0
	body.add_child(U.shape_node(U.rect(40.0, 9.0), Vector2(0, -6)))
	n.add_child(body)
	var a := U.area("Interact", [L_INTERACT], [], false, true)
	a.add_child(U.shape_node(U.rect(46.0, 24.0), Vector2(0, -6)))
	n.add_child(a)
	_save(n, "base_bench")


func _bed() -> void:
	var n := Node2D.new()
	n.name = "Bed"
	n.set_script(load("res://scripts/bed.gd"))
	var path := G + "props/bed.png"
	n.add_child(U.sprite(path, foot_offset(path)))
	var body := StaticBody2D.new()
	body.name = "Body"
	body.collision_layer = U.bits([L_WORLD])
	body.collision_mask = 0
	body.add_child(U.shape_node(U.rect(14.0, 22.0), Vector2(0, -12)))
	n.add_child(body)
	var a := U.area("Interact", [L_INTERACT], [], false, true)
	a.add_child(U.shape_node(U.rect(24.0, 34.0), Vector2(0, -14)))
	n.add_child(a)
	_save(n, "bed")


func _shrine() -> void:
	var n := Node2D.new()
	n.name = "CheckpointShrine"
	n.set_script(load("res://scripts/shrine.gd"))
	var s := Sprite2D.new()
	s.name = "Sprite"
	s.texture = load(G + "gates/shrine_off.png")
	s.position = Vector2(0, -20)
	n.add_child(s)
	var body := StaticBody2D.new()
	body.name = "Body"
	body.collision_layer = U.bits([L_WORLD])
	body.collision_mask = 0
	body.add_child(U.shape_node(U.circle(9.0), Vector2(0, -4)))
	n.add_child(body)
	var a := U.area("Interact", [L_INTERACT], [], false, true)
	a.add_child(U.shape_node(U.circle(26.0), Vector2(0, -4)))
	n.add_child(a)
	var t := U.area("Touch", [], [L_PLAYER], true, false)
	t.add_child(U.shape_node(U.circle(28.0), Vector2(0, 0)))
	n.add_child(t)
	_save(n, "checkpoint_shrine")


func _chest() -> void:
	var n := Node2D.new()
	n.name = "Chest"
	n.set_script(load("res://scripts/chest.gd"))
	var s := AnimatedSprite2D.new()
	s.name = "Sprite"
	s.sprite_frames = load("res://resources/chest_frames.tres")
	s.animation = &"closed_silver"
	s.offset = Vector2(0, -7)
	n.add_child(s)
	var body := StaticBody2D.new()
	body.name = "Body"
	body.collision_layer = U.bits([L_WORLD])
	body.collision_mask = 0
	body.add_child(U.shape_node(U.rect(18.0, 8.0), Vector2(0, -4)))
	n.add_child(body)
	var a := U.area("Interact", [L_INTERACT], [], false, true)
	a.add_child(U.shape_node(U.circle(16.0), Vector2(0, -4)))
	n.add_child(a)
	_save(n, "chest")


func _gate(scene_name: String, gate_id: String, tex_path: String, message: String) -> void:
	var g := StaticBody2D.new()
	g.name = scene_name.capitalize().replace(" ", "")
	g.collision_layer = U.bits([L_WORLD])
	g.collision_mask = 0
	g.set_script(load("res://scripts/gate.gd"))
	g.set("gate_id", gate_id)
	g.set("open_message", message)
	var s := Sprite2D.new()
	s.name = "Sprite"
	s.texture = load(tex_path)
	g.add_child(s)
	g.add_child(U.shape_node(U.rect(16.0, 66.0)))
	_save(g, scene_name)


func _escape_gate() -> void:
	var n := Node2D.new()
	n.name = "EscapeGate"
	n.set_script(load("res://scripts/escape_gate.gd"))
	var path := G + "gates/escape_gate_closed.png"
	n.add_child(U.sprite(path, foot_offset(path)))
	var body := StaticBody2D.new()
	body.name = "Block"
	body.collision_layer = U.bits([L_WORLD])
	body.collision_mask = 0
	body.add_child(U.shape_node(U.rect(40.0, 14.0), Vector2(0, -7)))
	n.add_child(body)
	var t := U.area("Trigger", [], [L_PLAYER], false, false)
	t.add_child(U.shape_node(U.rect(30.0, 16.0), Vector2(0, 6)))
	n.add_child(t)
	_save(n, "escape_gate")


func _hud() -> void:
	var h := CanvasLayer.new()
	h.name = "Hud"
	h.set_script(load("res://scripts/ui/hud.gd"))
	_save(h, "hud")
