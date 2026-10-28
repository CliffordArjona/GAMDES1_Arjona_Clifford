extends Node2D
## Checkpoint Shrine.  Touching it moves the respawn point here (GDD 5.4 mechanic 9)
## and banks your materials; pressing E also restores HP and MP.

@export var checkpoint_label := "Checkpoint Shrine"
@export var active := false

@onready var sprite: Sprite2D = $Sprite
@onready var touch: Area2D = $Touch
var _t := 0.0


func save_state() -> Dictionary:
	return {"active": active}


func load_state(d: Dictionary) -> void:
	active = bool(d.get("active", false))
	_refresh()


func _ready() -> void:
	add_to_group("saveable")
	touch.body_entered.connect(_on_touch)
	_refresh()


func _process(delta: float) -> void:
	_t += delta
	if active:
		sprite.position.y = -20.0 + sin(_t * 2.5) * 0.8


func _refresh() -> void:
	sprite.texture = load("res://assets/generated/gates/shrine_on.png" if active else "res://assets/generated/gates/shrine_off.png")


func _on_touch(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	var first := not active
	active = true
	_refresh()
	GameState.set_checkpoint(global_position + Vector2(0, 14), checkpoint_label)
	if first:
		Sfx.play("shrine")
		GameState.toast("Checkpoint saved. Your materials are safe.", "good")
		Fx.sheet(get_parent(), "res://assets/generated/fx/burst.png", 4, global_position + Vector2(0, -20), 12.0, 2.0, Color(0.6, 0.95, 1.0))


func get_prompt() -> String:
	return "Rest at the shrine" if active else ""


func interact(_player: Node) -> void:
	GameState.full_restore()
	GameState.bank_progress()
	Sfx.play("shrine", -6)
	GameState.toast("HP and MP restored.", "good")
	Fx.float_text(get_parent(), "rested", global_position + Vector2(0, -34), Color(0.6, 0.95, 1.0))
