# Clifford Xhyrus D. Arjona		IAC2		10/9/2026	

# enemy.gd
# Detects when the player touches the enemy and sends the player back to the start.
# Attach this script to the Enemy node (a CharacterBody2D).
extends CharacterBody2D


# _ready() runs once, when the Enemy first appears in the game.
func _ready() -> void:
	$Hitbox.body_entered.connect(_on_hitbox_body_entered)


# Runs automatically each time something enters the Hitbox area.
func _on_hitbox_body_entered(body) -> void:
	if body.is_in_group("player"):
		print("Player touched the enemy!")
		body.respawn()
