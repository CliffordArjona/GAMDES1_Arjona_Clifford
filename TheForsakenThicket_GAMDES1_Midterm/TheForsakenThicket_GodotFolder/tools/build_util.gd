extends RefCounted
## Helpers shared by the build_*.gd tool scripts.

static func tex(path: String) -> Texture2D:
	return load(path) as Texture2D


## Add an animation made of consecutive cells in a sprite sheet row.
static func add_anim(sf: SpriteFrames, name: String, texture: Texture2D, cell: Vector2i, row: int,
		start: int, count: int, fps: float, loop: bool) -> void:
	sf.add_animation(name)
	sf.set_animation_speed(name, fps)
	sf.set_animation_loop(name, loop)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = texture
		at.region = Rect2((start + i) * cell.x, row * cell.y, cell.x, cell.y)
		sf.add_frame(name, at)


static func new_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	return sf


## Set the owner of every node below 'root' so PackedScene.pack() saves them.
## (Children of instanced scenes are left alone.)
static func own_all(root: Node, node: Node) -> void:
	for c in node.get_children():
		c.owner = root
		if c.scene_file_path == "":
			own_all(root, c)


static func save_scene(root: Node, path: String) -> int:
	own_all(root, root)
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		push_error("pack failed for %s: %d" % [path, err])
		return err
	err = ResourceSaver.save(ps, path)
	if err != OK:
		push_error("save failed for %s: %d" % [path, err])
	else:
		print("saved ", path)
	return err


static func circle(r: float) -> CircleShape2D:
	var c := CircleShape2D.new()
	c.radius = r
	return c


static func rect(w: float, h: float) -> RectangleShape2D:
	var r := RectangleShape2D.new()
	r.size = Vector2(w, h)
	return r


static func shape_node(shape: Shape2D, pos: Vector2 = Vector2.ZERO, name: String = "CollisionShape2D") -> CollisionShape2D:
	var c := CollisionShape2D.new()
	c.name = name
	c.shape = shape
	c.position = pos
	return c


static func area(name: String, layer_bits: Array, mask_bits: Array, monitoring: bool = true, monitorable: bool = true) -> Area2D:
	var a := Area2D.new()
	a.name = name
	a.collision_layer = bits(layer_bits)
	a.collision_mask = bits(mask_bits)
	a.monitoring = monitoring
	a.monitorable = monitorable
	return a


## bits([1, 3]) -> layer 1 and 3 -> 5
static func bits(layers: Array) -> int:
	var v := 0
	for l in layers:
		v |= 1 << (int(l) - 1)
	return v


static func sprite(path: String, offset: Vector2 = Vector2.ZERO, name: String = "Sprite") -> Sprite2D:
	var s := Sprite2D.new()
	s.name = name
	s.texture = load(path)
	s.offset = offset
	return s
