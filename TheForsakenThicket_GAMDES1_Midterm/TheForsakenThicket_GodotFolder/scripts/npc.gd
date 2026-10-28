extends StaticBody2D
## Village NPC (Lola Pacita).  Gives the three fetch quests that unlock the
## Thorn Barrier (O1), Ruin Gate (O3) and Arena Seal (O6).
## She never explains controls (GDD 5.4: no tutorial pop-ups).

const NPC_NAME := "Lola Pacita"

@onready var mark: Sprite2D = $Mark
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	var q := GameState.current_quest()
	mark.visible = not q.is_empty() and GameState.playing
	if mark.visible:
		var ready := GameState.quest_ready()
		mark.texture = load("res://assets/generated/sprites/quest_done.png" if ready else "res://assets/generated/sprites/quest_mark.png")
		if GameState.quest_accepted and not ready:
			mark.visible = false
		mark.position.y = -34.0 + sin(_t * 4.0) * 1.5


func get_prompt() -> String:
	return "Talk to " + NPC_NAME


func interact(_player: Node) -> void:
	Sfx.play("talk")
	var q := GameState.current_quest()
	if q.is_empty():
		GameState.dialogue_requested.emit(NPC_NAME, [
			"You have done everything I asked, child.",
			"The Warden waits beyond the hollow. Defeat it, and the Escape Gate will open.",
			"Benizaurus will not forget you... but today, the Thicket will let you go.",
		], Callable())
	elif not GameState.quest_accepted:
		GameState.dialogue_requested.emit(NPC_NAME, q["intro"], func(): GameState.accept_quest())
	elif GameState.quest_ready():
		GameState.dialogue_requested.emit(NPC_NAME, q["done"], func(): GameState.turn_in_quest())
	else:
		GameState.dialogue_requested.emit(NPC_NAME, q["remind"], Callable())
