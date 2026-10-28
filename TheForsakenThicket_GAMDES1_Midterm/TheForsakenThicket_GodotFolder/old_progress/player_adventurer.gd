extends CharacterBody2D

@export var speed := 200.0

@onready var sprite = $AnimatedSprite2D

var last_direction := "south"

func _physics_process(_delta):
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	velocity = direction * speed
	move_and_slide()

	if direction == Vector2.ZERO:
		sprite.stop()
		return

	var animation_name = get_direction_animation(direction)
	sprite.animation = animation_name
	sprite.play()

func get_direction_animation(direction: Vector2) -> String:
	var x = direction.x
	var y = direction.y

	if x > 0 and y < 0:
		last_direction = "northeast"
	elif x < 0 and y < 0:
		last_direction = "northwest"
	elif x > 0 and y > 0:
		last_direction = "southeast"
	elif x < 0 and y > 0:
		last_direction = "southwest"
	elif x > 0:
		last_direction = "east"
	elif x < 0:
		last_direction = "west"
	elif y < 0:
		last_direction = "north"
	elif y > 0:
		last_direction = "south"

	return "walk_" + last_direction
