extends Node2D
## The Base Bench at the ranch: opens the crafting menu.

func get_prompt() -> String:
	return "Use Base Bench"

func interact(_player: Node) -> void:
	Sfx.play("ui_click")
	GameState.craft_menu_requested.emit()
