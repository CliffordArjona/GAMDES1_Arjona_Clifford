extends PanelContainer
class_name DialogueBox
## Bottom-of-screen conversation box (typewriter text).  Advance with E / Enter / Space / click.

signal finished

var _lines: Array = []
var _index := 0
var _on_done := Callable()
var _speaker: Label
var _text: Label
var _hint: Label
var _tween: Tween
var _typing := false


func _init() -> void:
	add_theme_stylebox_override("panel", UIKit.style(Color(0.07, 0.06, 0.09, 0.95), UIKit.COL_BORDER, 6, 3))
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 160
	offset_right = -160
	offset_top = -178
	offset_bottom = -64
	var v := VBoxContainer.new()
	add_child(v)
	_speaker = UIKit.label("", 18, UIKit.COL_GOLD)
	v.add_child(_speaker)
	_text = UIKit.label("", 17, UIKit.COL_TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(700, 56)
	v.add_child(_text)
	_hint = UIKit.label("[E] continue", 12, UIKit.COL_DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_hint)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func open(speaker: String, lines: Array, on_done: Callable) -> void:
	_lines = lines
	_index = 0
	_on_done = on_done
	_speaker.text = speaker
	visible = true
	GameState.open_ui()
	_show_line()


func _show_line() -> void:
	_text.text = String(_lines[_index])
	_text.visible_ratio = 0.0
	_typing = true
	_hint.text = "[E] continue" if _index < _lines.size() - 1 else "[E] close"
	if _tween:
		_tween.kill()
	_tween = create_tween()
	var dur := maxf(0.25, _text.text.length() * 0.018)
	_tween.tween_property(_text, "visible_ratio", 1.0, dur)
	_tween.tween_callback(func(): _typing = false)
	Sfx.play("talk", -6)


func is_open() -> bool:
	return visible


func advance() -> void:
	if _typing:
		if _tween:
			_tween.kill()
		_text.visible_ratio = 1.0
		_typing = false
		return
	_index += 1
	if _index >= _lines.size():
		visible = false
		GameState.close_ui()
		var cb := _on_done
		_on_done = Callable()
		if cb.is_valid():
			cb.call()
		finished.emit()
	else:
		_show_line()


func _gui_input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
		accept_event()
