extends Node2D
## The Escape Gate in the arena.  It opens when the Warden (the mini-boss that stands
## in for Benizaurus in this prototype) is defeated.  Walking in wins the game.

@onready var sprite: Sprite2D = $Sprite
@onready var block_shape: CollisionShape2D = $Block/CollisionShape2D
@onready var trigger: Area2D = $Trigger
var is_open := false


func save_state() -> Dictionary:
	return {}


func load_state(_d: Dictionary) -> void:
	if GameState.boss_dead and not is_open:
		_open()


func _ready() -> void:
	add_to_group("saveable")
	trigger.monitoring = false
	trigger.body_entered.connect(_on_enter)
	GameState.boss_defeated.connect(_on_boss_defeated)
	if GameState.boss_dead:
		_open()


func _on_boss_defeated() -> void:
	await get_tree().create_timer(1.4).timeout
	Sfx.play("gate")
	GameState.toast("The Warden has fallen. The Escape Gate is open!", "good")
	_open()


func _open() -> void:
	is_open = true
	sprite.texture = load("res://assets/generated/gates/escape_gate_open.png")
	block_shape.set_deferred("disabled", true)
	trigger.set_deferred("monitoring", true)


func _on_enter(body: Node) -> void:
	if is_open and body.is_in_group("player"):
		GameState.win_game()
