# Name: Clifford Xhyrus D. Arjona
# Course: GAMDES1
# Date: 10/09/2026
# player.gd

extends CharacterBody2D

# --- Settings you can change ---------------------------------------------

# Running speed, in pixels per second.
const SPEED: float = 300.0

# Jump strength, in pixels per second. It is negative because in Godot's 2D
# space the Y axis points DOWN, so "up" is a negative number.
const JUMP_VELOCITY: float = -450.0

# --- Variables -----------------------------------------------------------

# How strongly gravity pulls, read from the project's physics settings so the
# whole game uses one shared value (the default is 980).
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# Remembers where the player started, so we can send the player back later.
var start_position: Vector2

# Reference to the AnimatedSprite2D child node that shows the player's art.
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


# _ready() runs once, when the Player first appears in the game.
func _ready() -> void:
	# Save the position the player starts at.
	start_position = global_position
	# Put this node in a group named "player". Other scripts, like the
	# enemy's, use the group name to recognize the player.
	add_to_group("player")


# _physics_process() runs many times per second (60 by default).
# "delta" is the time since the last run, in seconds.
func _physics_process(delta: float) -> void:
	# 1. GRAVITY: when the player is in the air, pull downward.
	if not is_on_floor():
		velocity.y += gravity * delta

	# 2. JUMP: only when the jump action was just pressed AND the player
	# is standing on something. This stops jumping in mid-air.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# 3. RUN: get_axis() returns -1 (left), 0 (nothing pressed), or 1 (right).
	var direction: float = Input.get_axis("move_left", "move_right")
	velocity.x = direction * SPEED

	# 4. MOVE: use velocity to move the player. move_and_slide() also stops
	# the player at solid bodies (floor, obstacles) and updates is_on_floor().
	move_and_slide()

	# 5. ANIMATE: show the right sprite animation for what the player is doing.
	update_animation()


# update_animation() picks which animation plays and which way the sprite faces.
func update_animation() -> void:
	if not is_on_floor():
		sprite.play("jump")
	elif velocity.x != 0:
		sprite.play("run")
	else:
		sprite.play("idle")

	# Face left when moving left, right when moving right.
	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0


# respawn() is called by the enemy when it touches the player.
# It puts the player back at the start and stops all movement.
func respawn() -> void:
	global_position = start_position
	velocity = Vector2.ZERO
