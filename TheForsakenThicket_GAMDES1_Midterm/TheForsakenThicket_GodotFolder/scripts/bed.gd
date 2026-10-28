extends Node2D
## The bed in the cabin.  Sleeping restores HP/MP, banks your materials (they
## can no longer be lost on death) and moves on to the next morning.

func get_prompt() -> String:
	return "Sleep"

func interact(_player: Node) -> void:
	get_tree().call_group("world", "do_sleep")
