extends Node2D
## A dropped item.  It pops out, then flies to the player when close (GDD 5.4: dropped
## materials appear as collectible item sprites).

@export var item_id := "wood"
@export var amount := 1

var _age := 0.0
var _target_offset := Vector2.ZERO
var _base_y := 0.0
var _collected := false

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("pickups")
	var info: Dictionary = GameState.ITEMS.get(item_id, {})
	if info.has("icon"):
		sprite.texture = load(info["icon"])
	# the spawner sets our position right after add_child(), so hop on the next idle frame
	call_deferred("_start_hop")


func _start_hop() -> void:
	# little hop away from the spawn point
	_target_offset = Vector2(randf_range(-14, 14), randf_range(-6, 10))
	var tw := create_tween()
	tw.tween_property(self, "position", position + _target_offset, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_age += delta
	sprite.position.y = -6.0 + sin(_age * 5.0) * 1.5
	if _collected or _age < 0.45:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or GameState.is_dead():
		return
	var d := global_position.distance_to(player.global_position + Vector2(0, -6))
	if d < 8.0:
		_collect()
	elif d < 42.0:
		global_position = global_position.move_toward(player.global_position + Vector2(0, -6), 150.0 * delta)


func _collect() -> void:
	_collected = true
	GameState.add_item(item_id, amount)
	Sfx.play_varied("pickup")
	var info: Dictionary = GameState.ITEMS.get(item_id, {})
	GameState.toast("+%d %s" % [amount, info.get("name", item_id)], "pickup")
	queue_free()
