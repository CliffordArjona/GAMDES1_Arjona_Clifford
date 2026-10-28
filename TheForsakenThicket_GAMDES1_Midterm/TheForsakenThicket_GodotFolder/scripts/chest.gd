extends Node2D
## A hidden chest (rewards exploring: the "Discovery" kind of fun).

@export var loot: Dictionary = {"health_potion": 1}
@export var gold := false
var opened := false

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	add_to_group("saveable")
	sprite.play("closed_gold" if gold else "closed_silver")


func save_state() -> Dictionary:
	return {"opened": opened}


func load_state(d: Dictionary) -> void:
	opened = bool(d.get("opened", false))
	if opened:
		var anim := "open_gold" if gold else "open_silver"
		sprite.animation = anim
		sprite.frame = sprite.sprite_frames.get_frame_count(anim) - 1
		sprite.stop()


func get_prompt() -> String:
	return "" if opened else "Open chest"


func interact(_player: Node) -> void:
	if opened:
		return
	opened = true
	Sfx.play("pickup")
	sprite.play("open_gold" if gold else "open_silver")
	await get_tree().create_timer(0.45).timeout
	for id in loot:
		for i in int(loot[id]):
			var pk := preload("res://scences/pickup.tscn").instantiate()
			pk.item_id = id
			get_parent().add_child(pk)
			pk.global_position = global_position + Vector2(0, 4)
	GameState.toast("You found a hidden chest!", "good")
