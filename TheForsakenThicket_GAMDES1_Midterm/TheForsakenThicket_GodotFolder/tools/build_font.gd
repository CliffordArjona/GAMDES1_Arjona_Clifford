extends SceneTree
## Builds resources/pixel_font.res from the Jersey 10 TTF with anti-aliasing and hinting OFF,
## so the text keeps hard pixel edges.   godot --headless --path . -s tools/build_font.gd

func _init() -> void:
	var f := FontFile.new()
	var err := f.load_dynamic_font("res://assets/fonts/Jersey10-Regular.ttf")
	print("load font: ", err)
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.generate_mipmaps = false
	DirAccess.make_dir_recursive_absolute("res://resources")
	print("save font: ", ResourceSaver.save(f, "res://resources/pixel_font.res"))
	quit()
