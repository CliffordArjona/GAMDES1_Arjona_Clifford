extends Node
## Root of the game: the world + the HUD.  Everything else is instanced inside them.
## (Set as the project's main scene.)

func _ready() -> void:
	# The HUD shows the title screen first; the world waits until Play is pressed.
	GameState.reset_run()
