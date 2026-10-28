extends Area2D
## The player's MP skill: "Mana Bolt".  A ranged shot, so it is the only way to
## hurt the slime trapped in the pit (GDD 5.4 mechanic 5).

var direction := Vector2.RIGHT
var damage := 20
var speed := 200.0
var life := 1.1
var _t := 0.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	rotation = 0.0
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_t += delta
	sprite.frame = int(_t * 16.0) % 4
	sprite.rotation = direction.angle()
	life -= delta
	if life <= 0.0:
		_burst()


func _on_area_entered(area: Area2D) -> void:
	var e := area.get_parent()
	if e != null and e.has_method("take_damage"):
		var landed: bool = e.take_damage(damage, global_position, "skill")
		if landed:
			Sfx.play_varied("skill_hit")
		_burst()


func _on_body_entered(_body: Node) -> void:
	_burst()


func _burst() -> void:
	if is_queued_for_deletion():
		return
	Fx.sheet(get_parent(), "res://assets/generated/fx/burst.png", 4, global_position, 18.0)
	queue_free()
