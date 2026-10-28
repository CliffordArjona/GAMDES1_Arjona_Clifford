extends Node
## Runs one of the build_*.gd tools inside a normal scene so the autoloads
## (GameState, Sfx) exist.   godot --headless --path . res://tools/build_runner.tscn -- build_scenes

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("usage: ... build_runner.tscn -- <build_scenes|build_world>")
		get_tree().quit()
		return
	var script: GDScript = load("res://tools/%s.gd" % args[0])
	var b: Node = script.new()
	add_child(b)
