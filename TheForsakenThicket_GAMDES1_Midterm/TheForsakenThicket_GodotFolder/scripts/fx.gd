class_name Fx
extends RefCounted
## Tiny helpers for one-shot visual effects (spritesheet bursts, floating text).

static func sheet(parent: Node, tex_path: String, hframes: int, pos: Vector2, fps: float = 14.0,
		scale_: float = 1.0, tint: Color = Color.WHITE) -> void:
	var s := Sprite2D.new()
	s.texture = load(tex_path)
	s.hframes = hframes
	s.global_position = pos
	s.scale = Vector2(scale_, scale_)
	s.modulate = tint
	s.z_index = 50
	parent.add_child(s)
	s.global_position = pos
	var tw := s.create_tween()
	for i in hframes:
		tw.tween_callback(func(): s.frame = i)
		tw.tween_interval(1.0 / fps)
	tw.tween_callback(s.queue_free)


static func float_text(parent: Node, text: String, pos: Vector2, color: Color = Color.WHITE) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override("outline_size", 3)
	l.z_index = 100
	parent.add_child(l)
	l.global_position = pos + Vector2(-10, -4)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "global_position:y", pos.y - 22, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)
