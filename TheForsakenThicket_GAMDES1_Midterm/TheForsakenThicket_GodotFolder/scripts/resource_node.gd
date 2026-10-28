extends StaticBody2D
## A tree or a rock you strike with E (hold to repeat).  After a few strikes it breaks
## and drops materials.  It regrows at the start of the next in-game day.
## It does not respond while enemies are hunting you (GDD rule: no gathering in combat).

@export var item_id := "wood"
@export var amount := 2
@export var hits_needed := 3
@export var verb := "Chop tree"
@export var full_tex: Texture2D
@export var depleted_tex: Texture2D
@export var full_offset := Vector2.ZERO
@export var depleted_offset := Vector2.ZERO

var hits := 0
var depleted := false
var _t := 0.0

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	add_to_group("resource_nodes")
	add_to_group("saveable")
	sprite.texture = full_tex
	sprite.offset = full_offset
	GameState.day_changed.connect(_on_new_day)


func _process(delta: float) -> void:
	_t += delta
	# gentle highlight when something can be gathered; it switches off in combat
	if depleted:
		sprite.modulate = Color.WHITE
	elif GameState.in_combat():
		sprite.modulate = Color(0.8, 0.8, 0.8)
	else:
		sprite.modulate = Color.WHITE.lerp(Color(1.25, 1.25, 1.1), 0.5 + 0.5 * sin(_t * 3.0)) if _player_near() else Color.WHITE


func _player_near() -> bool:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	return p != null and p.global_position.distance_to(global_position) < 34.0


func save_state() -> Dictionary:
	return {"depleted": depleted, "hits": hits}


func load_state(d: Dictionary) -> void:
	depleted = bool(d.get("depleted", false))
	hits = int(d.get("hits", 0))
	sprite.texture = depleted_tex if depleted else full_tex
	sprite.offset = depleted_offset if depleted else full_offset


func get_prompt() -> String:
	if depleted or GameState.in_combat():
		return ""
	return verb


func allow_hold() -> bool:
	return true


func interact(_player: Node) -> void:
	if depleted or GameState.in_combat():
		return
	hits += 1
	Sfx.play_varied("gather")
	var s := create_tween()
	s.tween_property(sprite, "position:x", 2.0, 0.04)
	s.tween_property(sprite, "position:x", -2.0, 0.06)
	s.tween_property(sprite, "position:x", 0.0, 0.04)
	Fx.sheet(get_parent(), "res://assets/generated/fx/spark.png", 3, global_position + Vector2(0, -10), 20.0)
	if hits >= hits_needed:
		_deplete()


func _deplete() -> void:
	depleted = true
	Sfx.play("break")
	sprite.texture = depleted_tex
	sprite.offset = depleted_offset
	for i in amount:
		var pk := preload("res://scences/pickup.tscn").instantiate()
		pk.item_id = item_id
		get_parent().add_child(pk)
		pk.global_position = global_position + Vector2(0, -4)


func _on_new_day(_d: int) -> void:
	if depleted:
		depleted = false
		hits = 0
		sprite.texture = full_tex
		sprite.offset = full_offset
