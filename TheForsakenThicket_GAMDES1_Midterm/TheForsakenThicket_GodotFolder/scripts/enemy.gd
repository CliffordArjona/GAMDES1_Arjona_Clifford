extends CharacterBody2D
class_name Enemy
## One script for every monster: Slime, Wolf and the Warden mini-boss.
## Behaviour: idle/wander -> chase -> WIND-UP (telegraph) -> attack -> recover.
## The wind-up is the "enemy telegraph" the level teaches (GDD 5.4 mechanic 8).

enum S { IDLE, CHASE, WINDUP, ATTACK, RECOVER, HURT, DEAD }

const FLASH_SHADER := preload("res://shaders/flash.gdshader")
const PICKUP_SCENE := preload("res://scences/pickup.tscn")

@export var kind := "slime"                  # slime | wolf | boss
@export var display_name := "Slime"
@export var max_hp := 24
@export var move_speed := 32.0
@export var contact_damage := 8
@export var aggro_radius := 80.0
@export var leash_radius := 150.0
@export var attack_range := 20.0             # distance at which the wind-up starts
@export var windup_time := 0.9
@export var attack_time := 0.25
@export var attack_speed := 95.0
@export var recover_time := 1.2
@export var hurt_stun := 0.3
@export var immobile := false                # the pit slime
@export var melee_immune := false            # the pit slime: only the MP skill hurts it
@export var wait_until_provoked := false     # 2nd wolf of the pair
@export var provoke_radius := 55.0
@export var zone_name := ""
@export var drops: Dictionary = {}           # item id -> Vector2i(min, max)
@export var is_boss := false
@export var slam_radius := 46.0
@export var slam_damage := 18
@export var respawns := true
@export var strafe := 0.0                    # radians; makes the pair flank from two sides

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hurtbox: Area2D = $Hurtbox
@onready var attack_box: Area2D = $AttackBox
@onready var alert: Sprite2D = $Alert
@onready var bar: Node2D = $Bar
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var telegraph: Sprite2D = get_node_or_null("Telegraph")

var state: S = S.IDLE
var hp := 1
var home := Vector2.ZERO
var provoked := false
var returning := false
var locked_dir := Vector2.RIGHT
var attack_kind := "lunge"
var enraged := false
var hit_done := false
var face_right := true
var _timer := 0.0
var _wander_timer := 0.0
var _wander_dir := Vector2.ZERO
var _windup_total := 1.0
var _knock := Vector2.ZERO
var _mat: ShaderMaterial


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("saveable")
	if is_boss:
		add_to_group("boss")
	hp = max_hp
	home = global_position
	_mat = ShaderMaterial.new()
	_mat.shader = FLASH_SHADER
	sprite.material = _mat
	attack_box.monitoring = false
	attack_box.area_entered.connect(_on_attack_hit)
	alert.visible = false
	if telegraph:
		telegraph.visible = false
	GameState.day_changed.connect(_on_new_day)
	GameState.player_respawned.connect(_on_player_respawned)
	_play("idle")


func _exit_tree() -> void:
	GameState.clear_aggro(self)


# ------------------------------------------------------------------ helpers
func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D

func _target_ok(p: Node2D) -> bool:
	if p == null or GameState.is_dead() or GameState.won:
		return false
	return zone_name == "" or GameState.player_zone == zone_name

func _play(anim: String) -> void:
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)

func _set_flash(color: Color, amount: float) -> void:
	_mat.set_shader_parameter("flash_color", color)
	_mat.set_shader_parameter("flash_amount", amount)


# ------------------------------------------------------------------ main loop
func _physics_process(delta: float) -> void:
	if state == S.DEAD:
		return
	_timer -= delta
	var p := _player()
	match state:
		S.IDLE: _do_idle(delta, p)
		S.CHASE: _do_chase(delta, p)
		S.WINDUP: _do_windup(delta, p)
		S.ATTACK: _do_attack(delta)
		S.RECOVER: _do_recover(p)
		S.HURT: _do_hurt(p)
	_update_visuals()


func _do_idle(delta: float, p: Node2D) -> void:
	if immobile:
		velocity = Vector2.ZERO
		return
	if returning:
		var to_home := home - global_position
		if to_home.length() < 4.0:
			returning = false
			hp = max_hp
			bar.pulse(1.0)
			bar.show_time = 0.0
		else:
			velocity = to_home.normalized() * move_speed * 1.4
			move_and_slide()
			return
	# idle wandering
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(1.2, 3.0)
		_wander_dir = Vector2.from_angle(randf() * TAU) if randf() < 0.65 else Vector2.ZERO
	if global_position.distance_to(home) > 34.0:
		_wander_dir = (home - global_position).normalized()
	velocity = _wander_dir * move_speed * 0.35
	move_and_slide()
	# notice the player?
	if _target_ok(p):
		var d := global_position.distance_to(p.global_position)
		if wait_until_provoked and not provoked:
			if d <= provoke_radius:
				provoked = true
		if (not wait_until_provoked or provoked) and d <= aggro_radius:
			_start_chase()


func _start_chase() -> void:
	state = S.CHASE
	GameState.register_aggro(self)
	Sfx.play("alert", -10)


func _lose_target() -> void:
	state = S.IDLE
	returning = true
	provoked = false
	velocity = Vector2.ZERO
	GameState.clear_aggro(self)
	alert.visible = false


func _do_chase(_delta: float, p: Node2D) -> void:
	if not _target_ok(p) or global_position.distance_to(home) > leash_radius:
		_lose_target()
		return
	var to_p := p.global_position - global_position
	var dir := to_p.normalized()
	if strafe != 0.0 and to_p.length() > attack_range + 18.0:
		dir = dir.rotated(strafe)
	velocity = dir * move_speed * (1.25 if enraged else 1.0)
	move_and_slide()
	if absf(to_p.x) > 2.0:
		face_right = to_p.x > 0.0
	if to_p.length() <= attack_range:
		_start_windup(p)


func _start_windup(p: Node2D) -> void:
	state = S.WINDUP
	velocity = Vector2.ZERO
	attack_kind = "lunge"
	_windup_total = windup_time
	if is_boss:
		var near := global_position.distance_to(p.global_position) < slam_radius + 18.0
		if near and randf() < 0.45:
			attack_kind = "slam"
			_windup_total = windup_time + 0.25
	if enraged:
		_windup_total *= 0.78
	_timer = _windup_total
	alert.visible = true
	Sfx.play("alert", -4)
	if attack_kind == "slam" and telegraph:
		telegraph.visible = true
		var s := slam_radius * 2.0 / 96.0
		telegraph.scale = Vector2(s, s)
		telegraph.modulate.a = 0.5
	locked_dir = (p.global_position - global_position).normalized()


func _do_windup(_delta: float, p: Node2D) -> void:
	velocity = Vector2.ZERO
	var progress := 1.0 - clampf(_timer / _windup_total, 0.0, 1.0)
	# keep tracking the player for the first half, then commit to a direction
	if progress < 0.5 and _target_ok(p):
		locked_dir = (p.global_position - global_position).normalized()
		if absf(locked_dir.x) > 0.05:
			face_right = locked_dir.x > 0.0
	# telegraph: red pulsing flash (+ squash for slimes)
	_set_flash(Color(1, 0.15, 0.15), 0.25 + 0.4 * absf(sin(progress * 22.0)))
	if kind == "slime":
		sprite.scale = Vector2(1.0 + 0.2 * progress, 1.0 - 0.25 * progress)
	if telegraph and attack_kind == "slam":
		telegraph.modulate.a = 0.25 + 0.5 * progress
	if _timer <= 0.0:
		_start_attack()


func _start_attack() -> void:
	state = S.ATTACK
	alert.visible = false
	_set_flash(Color.WHITE, 0.0)
	sprite.scale = Vector2.ONE
	hit_done = false
	if attack_kind == "slam":
		_timer = 0.22
		_do_slam()
	else:
		_timer = attack_time
		attack_box.position.x = (1.0 if face_right else -1.0) * (18.0 if is_boss else 9.0)
		attack_box.monitoring = true


func _do_slam() -> void:
	if telegraph:
		telegraph.visible = false
	Sfx.play("slam")
	var p := _player()
	Fx.sheet(get_parent(), "res://assets/generated/fx/burst.png", 4, global_position + Vector2(0, -4), 14.0, slam_radius / 12.0, Color(1, 0.6, 0.5))
	if p != null:
		if p.has_method("shake"):
			p.shake(4.0, 0.3)
		if _target_ok(p) and global_position.distance_to(p.global_position) <= slam_radius:
			p.take_damage(slam_damage, global_position)


func _do_attack(_delta: float) -> void:
	if attack_kind == "lunge":
		velocity = locked_dir * attack_speed * (1.15 if enraged else 1.0)
		move_and_slide()
	else:
		velocity = Vector2.ZERO
	if _timer <= 0.0:
		attack_box.monitoring = false
		state = S.RECOVER
		_timer = recover_time * (0.7 if enraged else 1.0)
		velocity = Vector2.ZERO


func _on_attack_hit(area: Area2D) -> void:
	if hit_done or state != S.ATTACK:
		return
	var p := area.get_parent()
	if p != null and p.has_method("take_damage") and p.is_in_group("player"):
		hit_done = true
		p.take_damage(contact_damage, global_position)


func _do_recover(p: Node2D) -> void:
	velocity = Vector2.ZERO
	if _timer <= 0.0:
		if _target_ok(p):
			state = S.CHASE
		else:
			_lose_target()


func _do_hurt(p: Node2D) -> void:
	velocity = _knock * clampf(_timer / hurt_stun, 0.0, 1.0)
	move_and_slide()
	if _timer <= 0.0:
		_set_flash(Color.WHITE, 0.0)
		if _target_ok(p):
			state = S.CHASE
			GameState.register_aggro(self)
		else:
			state = S.IDLE


# ------------------------------------------------------------------ visuals
func _update_visuals() -> void:
	sprite.flip_h = (not face_right) if kind != "slime" else false
	var moving := velocity.length() > 4.0
	match kind:
		"slime":
			match state:
				S.HURT: _play("hurt")
				S.IDLE, S.CHASE, S.ATTACK: _play("move" if moving or state == S.ATTACK else "idle")
				_: _play("idle")
		_:
			match state:
				S.WINDUP: _play("windup")
				S.ATTACK: _play("lunge" if attack_kind == "lunge" else "windup")
				S.HURT: _play("hurt")
				S.IDLE, S.CHASE, S.RECOVER: _play("walk" if moving else "idle")
				_: _play("idle")
	if state != S.WINDUP and state != S.HURT:
		_set_flash(Color.WHITE, 0.0)
		if kind == "slime":
			sprite.scale = sprite.scale.lerp(Vector2.ONE, 0.3)
	alert.visible = state == S.WINDUP


# ------------------------------------------------------------------ taking damage
## Returns true if the hit counted. 'source' is "melee" or "skill".
func take_damage(amount: int, from_pos: Vector2, source: String = "melee") -> bool:
	if state == S.DEAD:
		return false
	if melee_immune and source == "melee":
		Fx.float_text(get_parent(), "out of reach", global_position + Vector2(0, -22), Color(0.8, 0.8, 0.85))
		Sfx.play("ui_deny", -6)
		return false
	hp -= amount
	bar.pulse(float(hp) / float(max_hp))
	Fx.float_text(get_parent(), str(amount), global_position + Vector2(0, -26 if not is_boss else -50), Color(1, 0.95, 0.6))
	Fx.sheet(get_parent(), "res://assets/generated/fx/spark.png", 3, global_position + Vector2(0, -10), 20.0)
	provoked = true
	if hp <= 0:
		_die()
		return true
	if is_boss and not enraged and hp <= max_hp / 2:
		enraged = true
		GameState.toast("The Warden is enraged!", "warn")
		Sfx.play("alert", 2, 0.7)
	_set_flash(Color.WHITE, 0.9)
	var tw := create_tween()
	tw.tween_method(func(v): _set_flash(Color.WHITE, v), 0.9, 0.0, 0.14)
	if state == S.IDLE and not immobile and _target_ok(_player()):
		_start_chase()
	if not is_boss and not immobile and state != S.DEAD:
		_knock = (global_position - from_pos).normalized() * 90.0
		state = S.HURT
		_timer = hurt_stun
		alert.visible = false
		attack_box.monitoring = false
		sprite.scale = Vector2.ONE
		if telegraph:
			telegraph.visible = false
	return true


func _die() -> void:
	state = S.DEAD
	GameState.clear_aggro(self)
	GameState.kills += 1
	attack_box.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	body_shape.set_deferred("disabled", true)
	alert.visible = false
	if telegraph:
		telegraph.visible = false
	Sfx.play("break", 0, 1.2 if not is_boss else 0.7)
	_spawn_drops()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tw.tween_property(sprite, "scale", Vector2(1.3, 0.2), 0.5)
	tw.chain().tween_callback(func():
		visible = false
		sprite.modulate.a = 1.0
		sprite.scale = Vector2.ONE)
	if is_boss:
		GameState.boss_dead = true
		GameState.boss_defeated.emit()


func _spawn_drops() -> void:
	for id in drops:
		var range_v: Vector2i = drops[id]
		var n := randi_range(range_v.x, range_v.y)
		for i in n:
			var pk := PICKUP_SCENE.instantiate()
			pk.item_id = id
			pk.amount = 1
			get_parent().add_child(pk)
			pk.global_position = global_position + Vector2(0, -4)


# ------------------------------------------------------------------ save / load
func save_state() -> Dictionary:
	return {"dead": state == S.DEAD, "hp": hp, "enraged": enraged}


func load_state(d: Dictionary) -> void:
	if bool(d.get("dead", false)):
		state = S.DEAD
		visible = false
		attack_box.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
		body_shape.set_deferred("disabled", true)
	else:
		hp = clampi(int(d.get("hp", max_hp)), 1, max_hp)
		enraged = bool(d.get("enraged", false))
		bar.show_time = 0.0


# ------------------------------------------------------------------ respawn / reset
func _on_new_day(_d: int) -> void:
	if state == S.DEAD and respawns:
		_respawn()

func _respawn() -> void:
	global_position = home
	hp = max_hp
	state = S.IDLE
	provoked = false
	returning = false
	visible = true
	sprite.modulate.a = 1.0
	sprite.scale = Vector2.ONE
	hurtbox.set_deferred("monitorable", true)
	body_shape.set_deferred("disabled", false)
	bar.show_time = 0.0

func _on_player_respawned() -> void:
	if state != S.DEAD:
		attack_box.monitoring = false
		alert.visible = false
		if telegraph:
			telegraph.visible = false
		sprite.scale = Vector2.ONE
		_lose_target()
		if is_boss:
			hp = max_hp
			enraged = false
