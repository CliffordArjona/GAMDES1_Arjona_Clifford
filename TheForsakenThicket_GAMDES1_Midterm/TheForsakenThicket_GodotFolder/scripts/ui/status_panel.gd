extends PanelContainer
class_name StatusPanel
## TAB / C status window: STR, AGI, INT, derived numbers, equipment and items.
## (GDD 1.4: the stat window is only visible when pressing TAB or C.)

var _grid: GridContainer
var _equip: VBoxContainer
var _items: VBoxContainer


func _init() -> void:
	add_theme_stylebox_override("panel", UIKit.style(Color(0.08, 0.065, 0.09, 0.97), UIKit.COL_BORDER, 6, 3))
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(620, 340)
	var root := VBoxContainer.new()
	add_child(root)
	root.add_child(UIKit.label("Status", 22, UIKit.COL_GOLD))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 26)
	root.add_child(cols)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 6)
	cols.add_child(_grid)
	var right := VBoxContainer.new()
	cols.add_child(right)
	right.add_child(UIKit.label("Equipment", 16, UIKit.COL_GOLD))
	_equip = VBoxContainer.new()
	right.add_child(_equip)
	right.add_child(UIKit.label("Potions", 16, UIKit.COL_GOLD))
	_items = VBoxContainer.new()
	right.add_child(_items)
	root.add_child(UIKit.label("[TAB] / [C] / [Esc] to close", 12, UIKit.COL_DIM))
	visible = false


func open() -> void:
	visible = true
	GameState.open_ui()
	_refresh()
	Sfx.play("ui_click", -6)


func close() -> void:
	if visible:
		visible = false
		GameState.close_ui()
		Sfx.play("ui_click", -6)


func _row(name_: String, base: int, bonus: int, color: Color) -> void:
	_grid.add_child(UIKit.label(name_, 20, color))
	_grid.add_child(UIKit.label(str(base + bonus), 22, UIKit.COL_TEXT))
	_grid.add_child(UIKit.label("(base %d%s)" % [base, " +%d gear" % bonus if bonus > 0 else ""], 13, UIKit.COL_DIM))


func _line(label_: String, value: String) -> void:
	_grid.add_child(UIKit.label(label_, 14, UIKit.COL_DIM))
	_grid.add_child(UIKit.label(value, 14, UIKit.COL_TEXT))
	_grid.add_child(Control.new())


func _refresh() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_row("STR", GameState.BASE_STR, GameState.bonus("str"), Color(1, 0.55, 0.45))
	_row("AGI", GameState.BASE_AGI, GameState.bonus("agi"), Color(0.55, 1, 0.6))
	_row("INT", GameState.BASE_INT, GameState.bonus("int"), Color(0.55, 0.75, 1))
	_line("HP", "%d / %d" % [GameState.hp, GameState.max_hp()])
	_line("MP", "%d / %d" % [int(GameState.mp), int(GameState.max_mp())])
	_line("Sword damage", str(GameState.melee_damage()) if GameState.has_weapon() else "no weapon")
	_line("Bolt damage", str(GameState.skill_damage()))
	_line("Move speed", str(int(GameState.move_speed())))
	for c in _equip.get_children():
		c.queue_free()
	for slot in ["weapon", "boots", "charm"]:
		var id: String = GameState.equipment[slot]
		var row := HBoxContainer.new()
		if id != "":
			row.add_child(UIKit.icon(GameState.ITEMS[id]["icon"], 24))
			row.add_child(UIKit.label(" %s  (%s)" % [GameState.ITEMS[id]["name"], GameState.ITEMS[id]["desc"]], 14, UIKit.COL_TEXT))
		else:
			row.add_child(UIKit.label("%s: empty" % slot.capitalize(), 14, UIKit.COL_DIM))
		_equip.add_child(row)
	for c in _items.get_children():
		c.queue_free()
	for id in ["health_potion", "mana_potion"]:
		var row := HBoxContainer.new()
		row.add_child(UIKit.icon(GameState.ITEMS[id]["icon"], 24))
		row.add_child(UIKit.label(" %s x%d" % [GameState.ITEMS[id]["name"], GameState.count(id)], 14, UIKit.COL_TEXT))
		_items.add_child(row)
