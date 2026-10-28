extends Node2D
## Small health bar drawn above an enemy.  Shows for a few seconds after a hit.

@export var width := 18.0
var ratio := 1.0
var show_time := 0.0


func pulse(new_ratio: float) -> void:
	ratio = clampf(new_ratio, 0.0, 1.0)
	show_time = 3.0
	queue_redraw()


func _process(delta: float) -> void:
	if show_time > 0.0:
		show_time -= delta
		queue_redraw()


func _draw() -> void:
	if show_time <= 0.0:
		return
	draw_rect(Rect2(-width / 2.0 - 1.0, -1.0, width + 2.0, 4.0), Color(0.1, 0.07, 0.07, 0.85))
	var col := Color(0.35, 0.85, 0.35) if ratio > 0.5 else (Color(0.95, 0.8, 0.25) if ratio > 0.25 else Color(0.9, 0.25, 0.25))
	draw_rect(Rect2(-width / 2.0, 0.0, width * ratio, 2.0), col)
