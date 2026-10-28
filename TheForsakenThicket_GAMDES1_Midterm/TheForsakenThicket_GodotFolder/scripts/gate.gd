extends StaticBody2D
## A quest gate: Thorn Barrier (O1), Ruin Gate (O3) or Arena Seal (O6).
## It opens when the matching quest is handed in (GameState.gate_opened).

@export var gate_id := "thorn"
@export var open_message := "The way is open."

@onready var sprite: Sprite2D = $Sprite
@onready var shape: CollisionShape2D = $CollisionShape2D
var opened := false


func save_state() -> Dictionary:
	return {}


func load_state(_d: Dictionary) -> void:
	if GameState.gates.get(gate_id, false):
		_finish_open()


func _ready() -> void:
	add_to_group("saveable")
	GameState.gate_opened.connect(_on_gate_opened)
	if GameState.gates.get(gate_id, false):
		_finish_open()


func _on_gate_opened(id: String) -> void:
	if id != gate_id or opened:
		return
	opened = true
	Sfx.play("gate")
	GameState.toast(open_message, "good")
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("shake"):
		p.shake(2.5, 0.8)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(sprite, "modulate:a", 0.0, 1.0)
	tw.tween_property(sprite, "scale", Vector2(1.0, 0.7), 1.0)
	tw.chain().tween_callback(_finish_open)


func _finish_open() -> void:
	opened = true
	shape.set_deferred("disabled", true)
	visible = false
