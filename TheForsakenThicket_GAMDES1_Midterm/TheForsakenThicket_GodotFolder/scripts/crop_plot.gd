extends Node2D
## One farm plot at the ranch.  till -> plant -> water -> grow -> harvest.
## GDD Section II / 4.2: crops die after 2 game days without water.
## GDD 5.4: a dry plot visibly droops so thirst is readable without text.

enum P { UNTILLED, TILLED, PLANTED, WILTED }

const GROW_SECONDS := 330.0        # time from planting to a mature flower (if watered)
const WET_SECONDS := 300.0         # how long the soil stays dark after watering
const SOIL_REGION := {"dirt": Rect2(0, 16, 16, 16), "dry": Rect2(16, 16, 16, 16), "wet": Rect2(32, 16, 16, 16)}

@onready var soil: Sprite2D = $Soil
@onready var crop: Sprite2D = $Crop

var state: P = P.UNTILLED
var planted_at := 0.0
var last_watered := 0.0
var watered := false
var _announced_wilt := false
var _t := 0.0


func _ready() -> void:
	add_to_group("saveable")
	_refresh()


func save_state() -> Dictionary:
	return {"state": int(state), "planted_at": planted_at, "last_watered": last_watered, "watered": watered, "ann": _announced_wilt}


func load_state(d: Dictionary) -> void:
	state = int(d.get("state", 0)) as P
	planted_at = float(d.get("planted_at", 0.0))
	last_watered = float(d.get("last_watered", 0.0))
	watered = bool(d.get("watered", false))
	_announced_wilt = bool(d.get("ann", false))
	_refresh()


func _process(delta: float) -> void:
	_t += delta
	if state == P.PLANTED and _dry_time() > GameState.CROP_WILT_DAYS * GameState.DAY_LENGTH:
		state = P.WILTED
		if not _announced_wilt:
			_announced_wilt = true
			GameState.toast("A gumamela withered from thirst!", "warn")
	if _t >= 0.2:
		_t = 0.0
		_refresh()


func _elapsed() -> float:
	return GameState.game_time - planted_at

func _dry_time() -> float:
	var ref := last_watered if watered else planted_at
	return GameState.game_time - ref

func _needs_water() -> bool:
	return (not watered) or (GameState.game_time - last_watered) > WET_SECONDS

func is_mature() -> bool:
	return state == P.PLANTED and watered and _elapsed() >= GROW_SECONDS

func _stage() -> int:
	var e := _elapsed()
	if e < 60.0:
		return 0
	if e < 170.0:
		return 1
	if is_mature():
		return 3
	return 2


func _refresh() -> void:
	match state:
		P.UNTILLED:
			soil.region_rect = SOIL_REGION["dirt"]
			crop.visible = false
		P.TILLED:
			soil.region_rect = SOIL_REGION["dry"]
			crop.visible = false
		P.PLANTED, P.WILTED:
			var wet := state == P.PLANTED and watered and (GameState.game_time - last_watered) < WET_SECONDS
			soil.region_rect = SOIL_REGION["wet"] if wet else SOIL_REGION["dry"]
			crop.visible = true
			var idx := 4
			if state == P.PLANTED:
				idx = _stage()
				# visibly droops after a full day without water
				if idx >= 1 and _dry_time() > GameState.DAY_LENGTH:
					idx = 5
			crop.region_rect = Rect2(idx * 20, 0, 20, 28)


func get_prompt() -> String:
	match state:
		P.UNTILLED: return "Till soil"
		P.TILLED: return "Plant gumamela seeds"
		P.PLANTED:
			if is_mature():
				return "Harvest gumamela"
			if _needs_water():
				return "Water crop"
			return ""
		P.WILTED: return "Clear withered plant"
	return ""


func interact(player: Node) -> void:
	var pos := global_position + Vector2(0, -14)
	match state:
		P.UNTILLED:
			state = P.TILLED
			Sfx.play_varied("till")
		P.TILLED:
			state = P.PLANTED
			planted_at = GameState.game_time
			watered = false
			_announced_wilt = false
			Sfx.play_varied("plant")
		P.PLANTED:
			if is_mature():
				state = P.TILLED
				Sfx.play("harvest")
				var pk := preload("res://scences/pickup.tscn").instantiate()
				pk.item_id = "gumamela"
				get_parent().add_child(pk)
				pk.global_position = global_position + Vector2(0, -6)
			elif _needs_water():
				watered = true
				last_watered = GameState.game_time
				Sfx.play("water")
				Fx.float_text(get_parent(), "watered", pos, Color(0.55, 0.8, 1.0))
		P.WILTED:
			state = P.TILLED
			Sfx.play_varied("till")
	_refresh()
