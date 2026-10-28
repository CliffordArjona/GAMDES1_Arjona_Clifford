extends CharacterBody2D
class_name Player
## The player: top-down movement (WASD / arrows), sword (Space / left click),
## Mana Bolt skill (Q / right click), free dodge (Shift), interact (E).
## Stamina is cut from the prototype, so dodging costs nothing (GDD 1.4).

enum State { FREE, ATTACK, DODGE, HURT, DEAD }

const FLASH_SHADER := preload("res://shaders/flash.gdshader")
const BOLT_SCENE := preload("res://scences/projectile.tscn")

## Where the sword hitbox sits for each facing direction.
const SWORD_OFFSET := {
	"down": Vector2(0, 6), "up": Vector2(0, -22), "left": Vector2(-15, -9), "right": Vector2(15, -9),
}
const FACING_VEC := {
	"down": Vector2.DOWN, "up": Vector2.UP, "left": Vector2.LEFT, "right": Vector2.RIGHT,
}

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var sword_area: Area2D = $SwordHit
@onready var sword_shape: CollisionShape2D = $SwordHit/CollisionShape2D
@onready var interact_area: Area2D = $InteractArea
@onready var camera: Camera2D = $Camera2D

var state: State = State.FREE
var face_name := "down"
var facing := Vector2.DOWN
var dodge_dir := Vector2.ZERO
var dodge_time := 0.0
var dodge_cd := 0.0
var skill_cd := 0.0
var invuln := 0.0
var hurt_time := 0.0
var knock := Vector2.ZERO
var casting := false
var hit_this_swing: Dictionary = {}
var interact_repeat := 0.0
var _msg_cd := 0.0
var _mat: ShaderMaterial
var _shake := 0.0

## Optional: a test bot can fill this in to drive the player without a keyboard.
var bot: Dictionary = {}


func _ready() -> void:
	add_to_group("player")
	_mat = ShaderMaterial.new()
	_mat.shader = FLASH_SHADER
	sprite.material = _mat
	sprite.animation_finished.connect(_on_anim_finished)
	sprite.frame_changed.connect(_on_frame_changed)
	GameState.player_died.connect(_on_died)
	sword_area.monitoring = false
	sprite.play("idle_down")


# ------------------------------------------------------------------ input helpers (bot-aware)
func _move_input() -> Vector2:
	if bot.has("move"):
		return bot["move"]
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func _pressed(action: String) -> bool:
	if bot.has("press") and bot["press"].get(action, false):
		return true
	return Input.is_action_just_pressed(action)

func _held(action: String) -> bool:
	if bot.has("hold") and bot["hold"].get(action, false):
		return true
	return Input.is_action_pressed(action)

func _aim_dir() -> Vector2:
	if bot.has("aim"):
		return bot["aim"]
	var d := get_global_mouse_position() - (global_position + Vector2(0, -8))
	return d.normalized() if d.length() > 4.0 else facing


# ------------------------------------------------------------------ main loop
func _physics_process(delta: float) -> void:
	invuln = maxf(0.0, invuln - delta)
	dodge_cd = maxf(0.0, dodge_cd - delta)
	skill_cd = maxf(0.0, skill_cd - delta)
	_msg_cd = maxf(0.0, _msg_cd - delta)
	interact_repeat = maxf(0.0, interact_repeat - delta)
	_update_camera_shake(delta)

	# blink while invulnerable after a hit
	sprite.modulate.a = 0.55 if (invuln > 0.0 and state != State.DEAD and state != State.DODGE and int(invuln * 20.0) % 2 == 0) else 1.0

	match state:
		State.DEAD:
			velocity = Vector2.ZERO
			return
		State.FREE:
			_state_free()
		State.ATTACK:
			velocity = facing * 12.0 if not casting else Vector2.ZERO
			move_and_slide()
			_check_sword_hits()
			if not GameState.input_blocked() and _pressed("dodge") and dodge_cd <= 0.0:
				_start_dodge(_move_input())
		State.DODGE:
			velocity = dodge_dir * GameState.move_speed() * 2.5
			move_and_slide()
			dodge_time -= delta
			if dodge_time <= 0.0:
				state = State.FREE
		State.HURT:
			velocity = knock * (hurt_time / 0.25)
			move_and_slide()
			hurt_time -= delta
			if hurt_time <= 0.0:
				state = State.FREE
	_update_interaction()


func _state_free() -> void:
	if GameState.input_blocked():
		velocity = Vector2.ZERO
		move_and_slide()
		_play_move_anim(Vector2.ZERO)
		return
	var dir := _move_input()
	velocity = dir * GameState.move_speed()
	if dir != Vector2.ZERO:
		_set_facing(dir)
	move_and_slide()
	_play_move_anim(dir)

	if _pressed("dodge") and dodge_cd <= 0.0:
		_start_dodge(dir)
	elif _pressed("attack"):
		_try_attack()
	elif _pressed("skill"):
		_try_skill()
	if _pressed("potion_health"):
		_drink("health_potion")
	elif _pressed("potion_mana"):
		_drink("mana_potion")


func _set_facing(dir: Vector2) -> void:
	if absf(dir.x) > absf(dir.y):
		face_name = "right" if dir.x > 0.0 else "left"
	else:
		face_name = "down" if dir.y > 0.0 else "up"
	facing = FACING_VEC[face_name]


func _play_move_anim(dir: Vector2) -> void:
	var a := ("walk_" if dir != Vector2.ZERO else "idle_") + face_name
	if sprite.animation != a or not sprite.is_playing():
		sprite.play(a)


# ------------------------------------------------------------------ combat
func _try_attack() -> void:
	if not GameState.has_weapon():
		if _msg_cd <= 0.0:
			GameState.toast("You have no weapon yet. Craft one at the Base Bench.", "warn")
			Sfx.play("ui_deny")
			_msg_cd = 2.5
		return
	state = State.ATTACK
	casting = false
	hit_this_swing.clear()
	sword_shape.position = SWORD_OFFSET[face_name]
	sprite.play("attack_" + face_name)
	Sfx.play_varied("attack")


func _try_skill() -> void:
	if skill_cd > 0.0:
		return
	if not GameState.spend_mp(GameState.SKILL_COST):
		if _msg_cd <= 0.0:
			GameState.toast("Not enough MP", "warn")
			Sfx.play("ui_deny")
			_msg_cd = 1.2
		return
	var aim := _aim_dir()
	_set_facing(aim)
	state = State.ATTACK
	casting = true
	sword_area.monitoring = false
	sprite.play("attack_" + face_name)
	skill_cd = 0.35
	Sfx.play_varied("skill")
	var b := BOLT_SCENE.instantiate()
	b.direction = aim
	b.damage = GameState.skill_damage()
	get_parent().add_child(b)
	b.global_position = global_position + Vector2(0, -9) + aim * 10.0


func _start_dodge(dir: Vector2) -> void:
	dodge_dir = (dir if dir != Vector2.ZERO else facing).normalized()
	if dir != Vector2.ZERO:
		_set_facing(dir)
	state = State.DODGE
	dodge_time = 0.24
	dodge_cd = GameState.dodge_cooldown()
	invuln = maxf(invuln, 0.28)
	casting = false
	sword_area.monitoring = false
	sprite.play("run_" + face_name)
	Sfx.play("dodge")


func _check_sword_hits() -> void:
	if not sword_area.monitoring or casting:
		return
	for a in sword_area.get_overlapping_areas():
		var e := a.get_parent()
		if e == null or hit_this_swing.has(e) or not e.has_method("take_damage"):
			continue
		hit_this_swing[e] = true
		var landed: bool = e.take_damage(GameState.melee_damage(), global_position, "melee")
		if landed:
			Sfx.play_varied("hit")
			shake(1.5, 0.12)


func _on_frame_changed() -> void:
	if state == State.ATTACK and not casting and sprite.animation.begins_with("attack_"):
		sword_area.monitoring = sprite.frame >= 2 and sprite.frame <= 4
	elif sword_area.monitoring and state != State.ATTACK:
		sword_area.monitoring = false


func _on_anim_finished() -> void:
	if state == State.ATTACK:
		state = State.FREE
		casting = false
		sword_area.monitoring = false


func _drink(id: String) -> void:
	if GameState.use_potion(id):
		Sfx.play("drink")
		var heal := id == "health_potion"
		GameState.toast("+%d %s" % [GameState.POTION_HEAL if heal else int(GameState.POTION_MANA), "HP" if heal else "MP"], "good")
		Fx.float_text(get_parent(), "+HP" if heal else "+MP", global_position + Vector2(0, -28),
			Color(1, 0.5, 0.55) if heal else Color(0.5, 0.75, 1))
	elif GameState.count(id) == 0:
		if _msg_cd <= 0.0:
			GameState.toast("No %s." % GameState.ITEMS[id]["name"], "warn")
			_msg_cd = 1.0
	else:
		if _msg_cd <= 0.0:
			GameState.toast("Already full.", "info")
			_msg_cd = 1.0


## Called by enemies. Returns true if damage was actually dealt.
func take_damage(amount: int, from_pos: Vector2) -> bool:
	if invuln > 0.0 or state == State.DEAD or GameState.won:
		return false
	invuln = 0.75
	Sfx.play("hurt")
	shake(3.0, 0.2)
	_flash(Color(1, 0.2, 0.2), 0.25)
	Fx.float_text(get_parent(), "-%d" % amount, global_position + Vector2(0, -26), Color(1, 0.35, 0.35))
	sword_area.monitoring = false
	casting = false
	GameState.damage_player(amount)
	if GameState.is_dead():
		return true
	knock = (global_position - from_pos).normalized() * 130.0
	hurt_time = 0.25
	state = State.HURT
	sprite.play("hit_" + face_name)
	return true


func _on_died() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	sword_area.monitoring = false
	sprite.play("hit_" + face_name)
	Sfx.play("die")
	GameState.set_prompt("")


func respawn_at(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	state = State.FREE
	invuln = 1.5
	face_name = "down"
	facing = Vector2.DOWN
	sprite.play("idle_down")
	if camera:
		camera.reset_smoothing()


func _flash(color: Color, time: float) -> void:
	_mat.set_shader_parameter("flash_color", color)
	_mat.set_shader_parameter("flash_amount", 0.8)
	var tw := create_tween()
	tw.tween_method(func(v): _mat.set_shader_parameter("flash_amount", v), 0.8, 0.0, time)


# ------------------------------------------------------------------ interaction
func _update_interaction() -> void:
	if GameState.input_blocked() or state == State.DEAD or state == State.HURT:
		GameState.set_prompt("")
		return
	var best: Node = null
	var best_d := 1e9
	# probe point slightly in front of the player so the plot/object you FACE wins
	var probe := global_position + Vector2(0, -4) + facing * 9.0
	for a in interact_area.get_overlapping_areas():
		var t := a.get_parent()
		if t == null or not t.has_method("get_prompt"):
			continue
		if t.get_prompt() == "":
			continue
		var d := (a.global_position - probe).length()
		if d < best_d:
			best_d = d
			best = t
	GameState.set_prompt(best.get_prompt() if best != null else "")
	if best == null or state != State.FREE:
		return
	var hold_ok: bool = best.has_method("allow_hold") and best.allow_hold()
	if _pressed("interact") or (hold_ok and _held("interact") and interact_repeat <= 0.0):
		interact_repeat = 0.42
		best.interact(self)


# ------------------------------------------------------------------ camera
func shake(strength: float, duration: float) -> void:
	_shake = maxf(_shake, strength)
	var tw := create_tween()
	tw.tween_property(self, "_shake", 0.0, duration)

func _update_camera_shake(_delta: float) -> void:
	if camera == null:
		return
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake if _shake > 0.05 else Vector2.ZERO
