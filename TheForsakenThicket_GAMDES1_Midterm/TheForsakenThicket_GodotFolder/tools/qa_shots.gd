extends Node
## QA helper: boots the game, teleports the player around and saves screenshots.
## xvfb-run godot --path . res://tools/qa_runner.tscn
var spots := {
	"title": null,
	"ranch_start": Vector2(176, 600),
	"cabin": Vector2(176, 530),
	"bench_npc": Vector2(500, 580),
	"grove": Vector2(300, 330),
	"outcrop": Vector2(300, 960),
	"meadow": Vector2(1000, 220),
	"pit": Vector2(1500, 190),
	"hollow": Vector2(1050, 700),
	"hollow_deep": Vector2(1400, 640),
	"shrine": Vector2(1240, 1030),
	"arena": Vector2(1600, 1050),
}

func _ready() -> void:
	var main: Node = load("res://scences/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.8).timeout
	_shot("title")
	var hud := get_tree().get_first_node_in_group("hud")
	hud.start_game()
	GameState.equipment["weapon"] = ""
	await get_tree().create_timer(0.5).timeout
	var player: Node2D = get_tree().get_first_node_in_group("player")
	for k in spots:
		if spots[k] == null:
			continue
		player.global_position = spots[k]
		player.camera.reset_smoothing()
		await get_tree().create_timer(0.7).timeout
		_shot(k)
	get_tree().quit()

func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("/home/claude/shots/%s.png" % name)
	print("shot ", name)
