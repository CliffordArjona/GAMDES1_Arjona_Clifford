extends Node
## SaveGame (Autoload) - three save slots, like Terraria / Stardew Valley.
##
## A slot is one text file in  user://saves/slot_N.save  (on Windows:
## %APPDATA%\Godot\app_userdata\The Forsaken Thicket\saves).  The file holds
##   meta  - what the slot card shows (day, zone, quest, play time, date)
##   state - GameState (stats, items, quests, day clock ...)
##   world - the player position + every object that remembers something
##           (farm plots, trees/rocks, monsters, chests, shrine, drops)
## It is written with var_to_str() so it keeps Vector2 / int types exactly.

const SLOTS := 3
const DIR := "user://saves/"
const VERSION := 1

## Slot that the running game came from / was last saved to (0 = a brand new game).
var current_slot := 0


func path(slot: int) -> String:
	return DIR + "slot_%d.save" % slot


func has_slot(slot: int) -> bool:
	return FileAccess.file_exists(path(slot))


func any_saves() -> bool:
	for i in range(1, SLOTS + 1):
		if has_slot(i):
			return true
	return false


func read(slot: int) -> Dictionary:
	if not has_slot(slot):
		return {}
	var f := FileAccess.open(path(slot), FileAccess.READ)
	if f == null:
		return {}
	var data = str_to_var(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) != VERSION:
		return {}
	return data


func meta(slot: int) -> Dictionary:
	return read(slot).get("meta", {})


func quest_summary() -> String:
	var q := GameState.current_quest()
	if q.is_empty():
		return "Defeat the Warden" if not GameState.boss_dead else "Reach the Escape Gate"
	if not GameState.quest_accepted:
		return "Talk to Lola Pacita"
	return "Quest: " + String(q["title"])


func save(slot: int, world_data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var data := {
		"version": VERSION,
		"meta": {
			"day": GameState.day,
			"zone": GameState.player_zone if GameState.player_zone != "" else GameState.ZONE_RANCH,
			"quest": quest_summary(),
			"played": GameState.run_time_text(),
			"saved_at": Time.get_datetime_string_from_system(false, true),
			"kills": GameState.kills,
			"deaths": GameState.deaths,
		},
		"state": GameState.capture(),
		"world": world_data,
	}
	var f := FileAccess.open(path(slot), FileAccess.WRITE)
	if f == null:
		push_error("could not write " + path(slot))
		return false
	f.store_string(var_to_str(data))
	f.close()
	current_slot = slot
	return true


func delete(slot: int) -> void:
	if has_slot(slot):
		DirAccess.remove_absolute(path(slot))
	if current_slot == slot:
		current_slot = 0
