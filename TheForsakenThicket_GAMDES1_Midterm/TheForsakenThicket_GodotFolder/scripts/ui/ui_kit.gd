class_name UIKit
extends RefCounted
## Small helpers to build the UI in code (so the team can read & tweak it).

## Jersey 10 is a small-looking pixel font, so every size used in the UI is multiplied by this.
const FONT_SCALE := 1.3

static func fs(size: int) -> int:
	return int(round(size * FONT_SCALE))


const COL_PANEL := Color(0.09, 0.075, 0.1, 0.9)
const COL_BORDER := Color(0.62, 0.48, 0.3, 1.0)
const COL_TEXT := Color(0.95, 0.92, 0.85, 1.0)
const COL_DIM := Color(0.7, 0.66, 0.6, 1.0)
const COL_GOOD := Color(0.55, 0.95, 0.55, 1.0)
const COL_BAD := Color(1.0, 0.45, 0.45, 1.0)
const COL_GOLD := Color(1.0, 0.85, 0.4, 1.0)


static func style(bg: Color = COL_PANEL, border: Color = COL_BORDER, radius: int = 5, bw: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


static func panel(bg: Color = COL_PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(bg))
	return p


static func label(text: String, size: int = 14, color: Color = COL_TEXT, outline: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		l.add_theme_constant_override("outline_size", 4)
	return l


static func icon(path: String, size: int = 28) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path)
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return t


static func bar(fill: Color, w: float = 220.0, h: float = 18.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(w, h)
	var bg := style(Color(0.1, 0.08, 0.1, 0.95), Color(0.3, 0.24, 0.2, 1), 3, 2)
	bg.content_margin_top = 0
	bg.content_margin_bottom = 0
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(2)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b


static func button(text: String, size: int = 16) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", fs(size))
	b.add_theme_color_override("font_color", COL_TEXT)
	b.add_theme_color_override("font_hover_color", COL_GOLD)
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.47, 0.45))
	b.add_theme_stylebox_override("normal", style(Color(0.2, 0.15, 0.12, 0.95), COL_BORDER, 4, 2))
	b.add_theme_stylebox_override("hover", style(Color(0.32, 0.23, 0.15, 0.98), COL_GOLD, 4, 2))
	b.add_theme_stylebox_override("pressed", style(Color(0.4, 0.28, 0.16, 1), COL_GOLD, 4, 2))
	b.add_theme_stylebox_override("disabled", style(Color(0.13, 0.11, 0.11, 0.9), Color(0.3, 0.26, 0.24), 4, 2))
	b.add_theme_stylebox_override("focus", style(Color(0, 0, 0, 0), COL_GOLD, 4, 2))
	b.custom_minimum_size = Vector2(0, 34)
	return b


static func key_cap(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	var s := style(Color(0.2, 0.18, 0.2, 0.95), Color(0.75, 0.7, 0.62), 3, 1)
	s.content_margin_left = 5
	s.content_margin_right = 5
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", s)
	p.add_child(label(text, 11, COL_TEXT))
	return p
