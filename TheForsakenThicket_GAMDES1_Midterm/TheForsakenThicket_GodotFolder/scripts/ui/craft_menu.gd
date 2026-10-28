extends PanelContainer
class_name CraftMenu
## Base Bench crafting menu.  W/S or arrows to choose, Enter / click Craft, Esc or E to close.

signal closed

var _list: VBoxContainer
var _detail_icon: TextureRect
var _detail_name: Label
var _detail_desc: Label
var _detail_cost: VBoxContainer
var _craft_btn: Button
var _buttons: Array[Button] = []
var _recipes: Array = []
var _sel := 0


func _init() -> void:
	add_theme_stylebox_override("panel", UIKit.style(Color(0.08, 0.065, 0.09, 0.97), UIKit.COL_BORDER, 6, 3))
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(640, 360)
	var root := VBoxContainer.new()
	add_child(root)
	var head := HBoxContainer.new()
	root.add_child(head)
	head.add_child(UIKit.label("Base Bench - Crafting", 22, UIKit.COL_GOLD))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var x := UIKit.button("Close [Esc]", 13)
	x.pressed.connect(close)
	head.add_child(x)
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 14)
	root.add_child(cols)
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", UIKit.style(Color(0.05, 0.04, 0.06, 0.8), Color(0.35, 0.28, 0.2), 4, 1))
	left.custom_minimum_size = Vector2(250, 280)
	cols.add_child(left)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	left.add_child(_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var top := HBoxContainer.new()
	right.add_child(top)
	_detail_icon = UIKit.icon("res://assets/generated/icons/wood.png", 48)
	top.add_child(_detail_icon)
	_detail_name = UIKit.label("", 20, UIKit.COL_TEXT)
	top.add_child(_detail_name)
	_detail_desc = UIKit.label("", 14, UIKit.COL_DIM)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_detail_desc)
	right.add_child(UIKit.label("Needs:", 14, UIKit.COL_DIM))
	_detail_cost = VBoxContainer.new()
	right.add_child(_detail_cost)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(fill)
	_craft_btn = UIKit.button("Craft  [Enter]", 18)
	_craft_btn.pressed.connect(_do_craft)
	right.add_child(_craft_btn)
	visible = false
	GameState.inventory_changed.connect(func(): if visible: _refresh_detail())
	GameState.recipes_changed.connect(func(): if visible: _rebuild())


func open() -> void:
	visible = true
	GameState.open_ui()
	_sel = 0
	_rebuild()
	Sfx.play("ui_click")


func close() -> void:
	if not visible:
		return
	visible = false
	GameState.close_ui()
	closed.emit()


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	_buttons.clear()
	_recipes.clear()
	for r in GameState.RECIPES:
		if GameState.recipe_visible(r):
			_recipes.append(r)
	for i in _recipes.size():
		var r: Dictionary = _recipes[i]
		var item: Dictionary = GameState.ITEMS[r["id"]]
		var b := UIKit.button("  " + item["name"], 15)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon = load(item["icon"])
		b.expand_icon = false
		b.pressed.connect(func(): _select(i))
		_list.add_child(b)
		_buttons.append(b)
	_sel = clampi(_sel, 0, maxi(0, _recipes.size() - 1))
	_refresh_detail()


func _select(i: int) -> void:
	_sel = i
	Sfx.play("ui_click", -6)
	_refresh_detail()


func _refresh_detail() -> void:
	if _recipes.is_empty():
		return
	for i in _buttons.size():
		var r: Dictionary = _recipes[i]
		var can: bool = GameState.can_afford(r["cost"])
		_buttons[i].add_theme_color_override("font_color", UIKit.COL_GOLD if i == _sel else (UIKit.COL_TEXT if can else UIKit.COL_DIM))
		_buttons[i].add_theme_stylebox_override("normal", UIKit.style(Color(0.35, 0.25, 0.14, 0.98) if i == _sel else Color(0.2, 0.15, 0.12, 0.95), UIKit.COL_GOLD if i == _sel else UIKit.COL_BORDER, 4, 2))
	var r: Dictionary = _recipes[_sel]
	var item: Dictionary = GameState.ITEMS[r["id"]]
	_detail_icon.texture = load(item["icon"])
	_detail_name.text = "  " + item["name"]
	_detail_desc.text = item.get("desc", "")
	for c in _detail_cost.get_children():
		c.queue_free()
	for id in r["cost"]:
		var need: int = r["cost"][id]
		var have := GameState.count(id)
		var row := HBoxContainer.new()
		row.add_child(UIKit.icon(GameState.ITEMS[id]["icon"], 22))
		row.add_child(UIKit.label("  %s   %d / %d" % [GameState.ITEMS[id]["name"], have, need], 15, UIKit.COL_GOOD if have >= need else UIKit.COL_BAD))
		_detail_cost.add_child(row)
	var note := _equip_note(r["id"])
	_craft_btn.disabled = note != "" or not GameState.can_afford(r["cost"])
	_craft_btn.text = note if note != "" else "Craft  [Enter]"


func _equip_note(id: String) -> String:
	var item: Dictionary = GameState.ITEMS[id]
	if item["type"] != "equip":
		return ""
	var cur: String = GameState.equipment[item["slot"]]
	if cur == id:
		return "Equipped"
	if cur != "":
		var a := 0
		var b := 0
		for k in item["bonus"]:
			a += int(item["bonus"][k])
		for k in GameState.ITEMS[cur]["bonus"]:
			b += int(GameState.ITEMS[cur]["bonus"][k])
		if b >= a:
			return "You have better gear"
	return ""


func _do_craft() -> void:
	if _recipes.is_empty():
		return
	var r: Dictionary = _recipes[_sel]
	if _equip_note(r["id"]) != "" or not GameState.can_afford(r["cost"]):
		Sfx.play("ui_deny")
		return
	if GameState.craft(r["id"]):
		Sfx.play("craft")
		if GameState.ITEMS[r["id"]]["type"] == "equip":
			Sfx.play("equip", -4)
		_refresh_detail()


func handle_key(event: InputEventKey) -> bool:
	if not visible or not event.pressed or event.echo:
		return false
	match event.keycode:
		KEY_ESCAPE, KEY_E, KEY_TAB:
			close()
		KEY_UP, KEY_W:
			_select(posmod(_sel - 1, maxi(1, _recipes.size())))
		KEY_DOWN, KEY_S:
			_select(posmod(_sel + 1, maxi(1, _recipes.size())))
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_do_craft()
		_:
			return true
	return true
