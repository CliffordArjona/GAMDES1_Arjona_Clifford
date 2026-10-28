"""World art: ground atlas, decor atlas, props cut from the pack, cabin pieces,
resource nodes, gates, shrine, ruins.  Called from make_assets.py."""
from art_common import *

rng = random.Random(7)

# ------------------------------------------------------------------ ground atlas
# 8 columns x 4 rows of 16x16 tiles.  The index list below is mirrored in
# tools/build_world.gd (TILE dictionary) - keep them in sync if you edit it.
TILE_NAMES = [
    "grass_a", "grass_b", "grass_c", "grass_d", "meadow_a", "meadow_b", "path_a", "path_b",
    "plot_dirt", "tilled_dry", "tilled_wet", "rock_a", "rock_b", "cursed_a", "cursed_b", "cursed_c",
    "arena_a", "arena_b", "arena_rune", "shrine_floor", "canopy_a", "canopy_b", "canopy_c", "wood_floor",
    "ruin_path", "grove_a", "grove_b", "wall_shadow", "unused28", "unused29", "unused30", "unused31",
]


def tile_grass(variant):
    t = noise_tile(GRASS, rng, dots=((-12, 0.05), (10, 0.03)))
    px = t.load()
    if variant >= 1:
        for _ in range(2 + variant):
            x, y = rng.randrange(1, 14), rng.randrange(2, 15)
            px[x, y] = GRASS_L
            px[x, y - 1] = GRASS_L
    if variant == 3:
        for _ in range(3):
            x, y = rng.randrange(1, 14), rng.randrange(2, 15)
            px[x, y] = GRASS_D
            px[x + 1, y] = GRASS_D
    return t


def tile_meadow(variant):
    t = tile_grass(1)
    px = t.load()
    cols = [(250, 250, 240, 255), (255, 226, 90, 255), (255, 140, 170, 255), (190, 160, 255, 255)]
    for _ in range(3 + variant):
        x, y = rng.randrange(2, 14), rng.randrange(2, 14)
        c = rng.choice(cols)
        px[x, y] = c
        px[x - 1, y] = GRASS_D
        px[x + 1, y] = GRASS_D
        px[x, y + 1] = GRASS_D
    return t


def tile_path(variant):
    base = (170, 128, 78, 255)
    t = noise_tile(base, rng, dots=((-20, 0.07), (14, 0.05)))
    px = t.load()
    for _ in range(2 + variant):
        x, y = rng.randrange(1, 14), rng.randrange(1, 14)
        px[x, y] = (120, 88, 56, 255)
        px[x + 1, y] = (120, 88, 56, 255)
    return t


def tile_plot_dirt():
    t = noise_tile((150, 104, 62, 255), rng, dots=((-16, 0.08), (12, 0.05)))
    d = ImageDraw.Draw(t)
    d.rectangle([0, 0, 15, 15], outline=(120, 80, 48, 255))
    return t


def tile_tilled(wet):
    base = (96, 62, 38, 255) if wet else (150, 104, 62, 255)
    furrow = (62, 38, 26, 255) if wet else (116, 76, 46, 255)
    hi = (130, 88, 56, 255) if wet else (176, 128, 80, 255)
    t = Image.new("RGBA", (16, 16), base)
    d = ImageDraw.Draw(t)
    for y in (3, 7, 11, 15):
        d.line([(0, y), (15, y)], fill=furrow)
        d.line([(0, y - 1), (15, y - 1)], fill=hi if not wet else base)
    d.rectangle([0, 0, 15, 15], outline=(62, 38, 26, 255) if wet else (110, 72, 44, 255))
    return t


def tile_rock(variant):
    t = noise_tile((124, 120, 120, 255), rng, dots=((-22, 0.08), (16, 0.06)))
    px = t.load()
    for _ in range(3):
        x, y = rng.randrange(1, 13), rng.randrange(1, 13)
        for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
            px[x + dx, y + dy] = (150 + variant * 6, 146, 142, 255)
        px[x, y + 2] = (84, 82, 84, 255)
        px[x + 1, y + 2] = (84, 82, 84, 255)
    return t


def tile_cursed(variant):
    t = noise_tile((66, 54, 92, 255), rng, dots=((-16, 0.1), (10, 0.05)))
    px = t.load()
    d = ImageDraw.Draw(t)
    if variant == 2:
        x, y = rng.randrange(3, 9), rng.randrange(3, 9)
        pts = [(x, y), (x + 2, y + 2), (x + 3, y + 4), (x + 6, y + 5), (x + 7, y + 8)]
        d.line(pts, fill=(30, 22, 48, 255))
    for _ in range(1 + variant):
        x, y = rng.randrange(1, 15), rng.randrange(1, 15)
        px[x, y] = (150, 96, 210, 255)
    return t


def tile_arena(variant):
    t = Image.new("RGBA", (16, 16), (82, 58, 64, 255))
    d = ImageDraw.Draw(t)
    d.rectangle([0, 0, 15, 15], outline=(46, 32, 38, 255))
    d.line([(0, 8), (15, 8)], fill=(56, 40, 46, 255))
    d.line([(8 if variant == 0 else 4, 0), (8 if variant == 0 else 4, 7)], fill=(56, 40, 46, 255))
    d.line([(12 if variant == 0 else 10, 9), (12 if variant == 0 else 10, 15)], fill=(56, 40, 46, 255))
    px = t.load()
    for _ in range(6):
        x, y = rng.randrange(1, 15), rng.randrange(1, 15)
        r, g, b, a = px[x, y]
        px[x, y] = (r - 12, g - 10, b - 10, 255)
    return t


def tile_arena_rune():
    t = tile_arena(0)
    d = ImageDraw.Draw(t)
    d.ellipse([3, 3, 12, 12], outline=(200, 60, 70, 255))
    d.point([(8, 8), (7, 7), (9, 9)], fill=(255, 120, 110, 255))
    return t


def tile_shrine_floor():
    t = noise_tile((158, 152, 150, 255), rng, dots=((-14, 0.05), (10, 0.04)))
    d = ImageDraw.Draw(t)
    d.rectangle([0, 0, 15, 15], outline=(120, 116, 118, 255))
    d.line([(0, 8), (15, 8)], fill=(130, 126, 128, 255))
    px = t.load()
    px[4, 4] = (120, 200, 235, 255)
    px[11, 11] = (120, 200, 235, 255)
    return t


def tile_canopy(variant):
    """Top-down treetops - drawn with wrap-around so the tiles repeat seamlessly."""
    r = random.Random(100 + variant)
    t = Image.new("RGBA", (16, 16), (30, 70, 52, 255))
    d = ImageDraw.Draw(t)
    shades = [(26, 100, 58, 255), (36, 82, 62, 255), (51, 140, 70, 255), (20, 56, 44, 255)]
    for _ in range(7):
        cx, cy, rad = r.randrange(0, 16), r.randrange(0, 16), r.choice([3, 4, 4])
        col = r.choice(shades)
        for ox in (-16, 0, 16):
            for oy in (-16, 0, 16):
                d.ellipse([cx - rad + ox, cy - rad + oy, cx + rad + ox, cy + rad + oy], fill=col)
    for _ in range(9):
        x, y = r.randrange(0, 16), r.randrange(0, 16)
        t.putpixel((x, y), (96, 193, 53, 255) if r.random() < 0.5 else (20, 50, 40, 255))
    return t


def tile_wood_floor():
    src = Image.open(os.path.join(WORLD, "Tileset", "House.png")).convert("RGBA")
    return src.crop((48, 128, 64, 144))


def build_ground_atlas():
    atlas = new(8 * 16, 4 * 16)
    tiles = {
        "grass_a": tile_grass(0), "grass_b": tile_grass(1), "grass_c": tile_grass(2), "grass_d": tile_grass(3),
        "meadow_a": tile_meadow(0), "meadow_b": tile_meadow(2), "path_a": tile_path(0), "path_b": tile_path(2),
        "plot_dirt": tile_plot_dirt(), "tilled_dry": tile_tilled(False), "tilled_wet": tile_tilled(True),
        "rock_a": tile_rock(0), "rock_b": tile_rock(1),
        "cursed_a": tile_cursed(0), "cursed_b": tile_cursed(1), "cursed_c": tile_cursed(2),
        "arena_a": tile_arena(0), "arena_b": tile_arena(1), "arena_rune": tile_arena_rune(),
        "shrine_floor": tile_shrine_floor(),
        "canopy_a": tile_canopy(0), "canopy_b": tile_canopy(1), "canopy_c": tile_canopy(2),
        "wood_floor": tile_wood_floor(),
        "ruin_path": tile_cursed(1), "grove_a": tile_grass(3), "grove_b": tile_grass(2),
        "wall_shadow": tile_canopy(1),
    }
    for i, name in enumerate(TILE_NAMES):
        if name in tiles:
            atlas.paste(tiles[name], ((i % 8) * 16, (i // 8) * 16))
    save(atlas, "tiles", "ground_atlas.png")
    return atlas


# ------------------------------------------------------------------ decor atlas
DECOR_NAMES = ["flower_a", "flower_b", "flower_c", "mushroom_r", "mushroom_b", "tuft_a", "tuft_b", "pebble",
               "leaf_a", "bone", "skull", "glow_a", "glow_b", "rubble", "weed_dead", "crack"]


def build_decor_and_props():
    ts = Image.open(os.path.join(WORLD, "Tileset", "TilesetForest.png")).convert("RGBA")
    out_dir("props")
    # ---- cut the pack props (verified boxes) ----
    def cut(box, name, w=None, h=None, anchor="bottom"):
        im = ts.crop(box)
        a = np.array(im)
        ys, xs = np.where(a[:, :, 3] > 0)
        im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
        if w:
            im = pad_to(im, w, h or im.height, anchor)
        save(im, "props", name + ".png")
        return im

    tree, _ = crop_component(ts, (210, 30), min_x=192, max_y=95)
    save(tree, "props", "tree.png")
    bush, _ = crop_component(ts, (208, 80), min_x=192, max_y=98)
    save(bush, "props", "bush.png")
    crate = cut((230, 16, 250, 33), "crate")
    crates = cut((227, 35, 254, 57), "crate_stack")
    jar = cut((256, 63, 272, 80), "jar")
    sign = cut((256, 81, 272, 96), "signpost")
    sign2 = cut((256, 97, 272, 112), "signpost_arrow")
    log_v = cut((274, 65, 287, 95), "log_vertical")
    log_h = cut((257, 116, 287, 128), "log_horizontal")
    rocks_small = cut((161, 129, 174, 141), "rocks_small")

    # ---- decor atlas ----
    decor_src = {
        "flower_a": (160, 100, 174, 110), "flower_b": (178, 100, 189, 110), "flower_c": (177, 116, 188, 126),
        "mushroom_r": (212, 100, 220, 110), "mushroom_b": (228, 100, 236, 110),
        "tuft_a": (244, 101, 253, 108), "tuft_b": (245, 118, 252, 123), "pebble": (179, 129, 188, 138),
        "leaf_a": (161, 118, 174, 126),
    }
    atlas = new(8 * 16, 2 * 16)
    for i, name in enumerate(DECOR_NAMES):
        tile = new(16, 16)
        if name in decor_src:
            im = ts.crop(decor_src[name])
            a = np.array(im)
            ys, xs = np.where(a[:, :, 3] > 0)
            im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
            tile.paste(im, ((16 - im.width) // 2, 15 - im.height), im)
        elif name == "bone":
            d = ImageDraw.Draw(tile)
            d.line([(3, 11), (12, 8)], fill=(225, 220, 205, 255), width=2)
            tile.putpixel((2, 10), (225, 220, 205, 255)); tile.putpixel((2, 12), (225, 220, 205, 255))
            tile.putpixel((13, 7), (225, 220, 205, 255)); tile.putpixel((13, 9), (225, 220, 205, 255))
        elif name == "skull":
            d = ImageDraw.Draw(tile)
            d.ellipse([4, 5, 11, 12], fill=(225, 220, 205, 255))
            tile.putpixel((6, 8), OUT); tile.putpixel((9, 8), OUT); tile.putpixel((7, 11), OUT); tile.putpixel((8, 11), OUT)
        elif name in ("glow_a", "glow_b"):
            col = (170, 110, 230, 255) if name == "glow_a" else (110, 220, 235, 255)
            for (x, y) in ((6, 8), (9, 6), (10, 10)):
                tile.putpixel((x, y), col)
            tile.putpixel((6, 9), (col[0] - 60, col[1] - 40, col[2] - 30, 255))
        elif name == "rubble":
            d = ImageDraw.Draw(tile)
            for (x, y, r) in ((4, 11, 2), (9, 10, 2), (7, 13, 1), (12, 12, 1)):
                d.ellipse([x - r, y - r, x + r, y + r], fill=STONE_M, outline=STONE_D)
        elif name == "weed_dead":
            d = ImageDraw.Draw(tile)
            col = (112, 84, 60, 255)
            d.line([(8, 14), (8, 8)], fill=col); d.line([(8, 11), (5, 8)], fill=col); d.line([(8, 10), (11, 7)], fill=col)
        elif name == "crack":
            d = ImageDraw.Draw(tile)
            d.line([(3, 4), (7, 7), (8, 11), (12, 13)], fill=(28, 20, 40, 255))
        atlas.paste(tile, ((i % 8) * 16, (i // 8) * 16))
    save(atlas, "tiles", "decor_atlas.png")

    # ---- cursed (dead) tree: hue-swap of the pack tree ----
    mapping = {GRASS_L[:3]: (126, 98, 132), GRASS[:3]: (96, 72, 108), GRASS_D[:3]: (70, 52, 88), GRASS_DEEP[:3]: (46, 36, 64),
               LEAF_DARK[:3]: (36, 28, 50)}
    dead = recolor_map(tree, mapping)
    save(dead, "props", "tree_cursed.png")
    save(recolor_map(bush, mapping), "props", "bush_cursed.png")

    # ---- stump (tree depleted) ----
    st = new(20, 16)
    d = ImageDraw.Draw(st)
    d.rectangle([3, 7, 16, 13], fill=WOOD_M)
    d.ellipse([3, 3, 16, 10], fill=WOOD_L)
    d.ellipse([6, 5, 13, 8], outline=WOOD_B)
    d.line([(4, 11), (15, 11)], fill=WOOD_D)
    st = add_outline(st)
    sh = new(22, 18)
    sh.paste(st, (1, 1), st)
    save(sh, "props", "stump.png")

    # ---- stone nodes (full + depleted) ----
    def boulder(w, h, seed):
        r = random.Random(seed)
        im = new(w, h)
        d = ImageDraw.Draw(im)
        d.ellipse([1, 4, w - 3, h - 2], fill=STONE_M)
        d.ellipse([3, 2, w - 6, h - 6], fill=STONE_L)
        d.ellipse([w // 2 - 1, h // 2 - 2, w - 4, h - 4], fill=STONE_M)
        for _ in range(6):
            x, y = r.randrange(3, w - 5), r.randrange(5, h - 4)
            im.putpixel((x, y), STONE_D)
        d.line([(4, h - 5), (w - 6, h - 4)], fill=STONE_D)
        # highlight
        d.point([(5, 6), (6, 5), (7, 5)], fill=(210, 204, 200, 255))
        im = add_outline(pad_to(im, w + 2, h + 2, "center"))
        return im
    save(boulder(24, 20, 1), "props", "stone_node.png")
    rub = new(22, 12)
    d = ImageDraw.Draw(rub)
    for (x, y, r_) in ((6, 7, 3), (13, 8, 3), (10, 5, 2), (17, 8, 2)):
        d.ellipse([x - r_, y - r_, x + r_, y + r_], fill=STONE_M)
    save(add_outline(pad_to(rub, 24, 14, "center")), "props", "stone_rubble.png")
    # bigger decorative boulders (cursed ruins etc.)
    save(boulder(32, 26, 3), "props", "boulder_big.png")

    # ---- fence pieces (matched to the pack fence colours) ----
    fh = new(18, 16)
    d = ImageDraw.Draw(fh)
    d.rectangle([0, 6, 17, 8], fill=WOOD_M)
    d.line([(0, 6), (17, 6)], fill=WOOD_B)
    d.line([(0, 9), (17, 9)], fill=WOOD_D)
    d.rectangle([0, 2, 3, 14], fill=WOOD_M)
    d.rectangle([1, 2, 1, 13], fill=WOOD_B)
    fh = add_outline(pad_to(fh, 20, 18, "center"))
    save(fh, "props", "fence_h.png")
    fv = new(8, 18)
    d = ImageDraw.Draw(fv)
    d.rectangle([2, 0, 5, 17], fill=WOOD_M)
    d.line([(2, 0), (2, 17)], fill=WOOD_B)
    d.rectangle([1, 6, 6, 9], fill=WOOD_M)
    save(add_outline(pad_to(fv, 10, 20, "center")), "props", "fence_v.png")

    # ---- ruined stone pillars ----
    def pillar(h, broken, mossy=True):
        im = new(14, h)
        d = ImageDraw.Draw(im)
        d.rectangle([2, 4, 11, h - 3], fill=STONE_M)
        d.rectangle([2, 4, 4, h - 3], fill=STONE_L)
        d.rectangle([9, 4, 11, h - 3], fill=STONE_D)
        d.rectangle([0, h - 5, 13, h - 1], fill=STONE_M)
        d.rectangle([0, h - 5, 13, h - 4], fill=STONE_L)
        if not broken:
            d.rectangle([0, 0, 13, 5], fill=STONE_M)
            d.rectangle([0, 0, 13, 1], fill=STONE_L)
        else:
            d.polygon([(2, 4), (6, 2), (8, 5), (11, 3), (11, 6), (2, 6)], fill=STONE_D)
        if mossy:
            for (x, y) in ((3, h - 9), (4, h - 8), (10, h - 14), (3, h - 15)):
                if 0 < y < h:
                    im.putpixel((x, y), (60, 140, 90, 255))
        for y in range(8, h - 6, 6):
            d.line([(2, y), (11, y)], fill=STONE_D)
        return add_outline(pad_to(im, 16, h + 2, "bottom"))
    save(pillar(34, False), "props", "pillar_tall.png")
    save(pillar(24, True), "props", "pillar_broken.png")
    # purple-lit ruin variant
    ruin_map = {STONE_L[:3]: (150, 130, 190), STONE_M[:3]: (110, 94, 150), STONE_D[:3]: (76, 62, 110)}
    save(recolor_map(Image.open(os.path.join(GEN, "props", "pillar_tall.png")), ruin_map), "props", "pillar_cursed.png")
    save(recolor_map(Image.open(os.path.join(GEN, "props", "pillar_broken.png")), ruin_map), "props", "pillar_cursed_broken.png")

    # ---- Arena columns (red) ----
    arena_map = {STONE_L[:3]: (170, 110, 110), STONE_M[:3]: (130, 78, 84), STONE_D[:3]: (92, 52, 62)}
    save(recolor_map(Image.open(os.path.join(GEN, "props", "pillar_tall.png")), arena_map), "props", "pillar_arena.png")

    # ---- pack bits used by the cabin & bench ----
    house = Image.open(os.path.join(WORLD, "Tileset", "House.png")).convert("RGBA")
    save(house.crop((48, 96, 64, 128)), "props", "bed.png")
    bk = house.crop((80, 144, 96, 160))
    save(bk, "props", "bookshelf.png")
    save(house.crop((97, 113, 143, 159)), "props", "rug.png")
    for i, (x, y) in enumerate(((148, 106), (163, 106), (148, 135), (163, 135))):
        save(house.crop((x, y, x + 10, y + 20)), "props", f"plant_pot_{i}.png")
    save(house.crop((65, 146, 79, 157)), "props", "stool.png")
    table = house.crop((96, 96, 144, 112))
    a = np.array(table); ys, xs = np.where(a[:, :, 3] > 0)
    table = table.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    save(table, "props", "table.png")
    # Base Bench = the pack's wooden counter + a hammer and a gear drawn on top
    bench = new(52, 28)
    bench.paste(table, (2, 10), table)
    d = ImageDraw.Draw(bench)
    d.rectangle([10, 5, 22, 9], fill=STONE_M)
    d.rectangle([10, 5, 22, 6], fill=STONE_L)
    d.rectangle([13, 9, 19, 10], fill=STONE_D)  # little anvil
    d.line([(32, 9), (40, 4)], fill=WOOD_M, width=2)
    d.rectangle([38, 1, 43, 5], fill=STONE_M)
    d.rectangle([38, 1, 43, 2], fill=STONE_L)
    for (x, y) in ((28, 8), (29, 8)):
        bench.putpixel((x, y), GOLD)
    save(add_outline(pad_to(bench, 54, 30, "center")), "props", "bench.png")


# ------------------------------------------------------------------ cabin
def build_cabin():
    house = Image.open(os.path.join(WORLD, "Tileset", "House.png")).convert("RGBA")
    floor_tile = house.crop((48, 128, 64, 144))
    W, H = 160, 112
    floor = new(W, H)
    for ty in range(2, 6):
        for tx in range(1, 9):
            floor.paste(floor_tile, (tx * 16, ty * 16))
    # a darker shadow strip under the back wall
    sh = new(W, H)
    d = ImageDraw.Draw(sh)
    d.rectangle([16, 32, 143, 38], fill=(0, 0, 0, 60))
    floor.alpha_composite(sh)
    rug = house.crop((97, 113, 143, 159))
    floor.paste(rug, (58, 38), rug)
    save(floor, "cabin", "cabin_floor.png")

    def logs(w, h, vertical=False):
        im = new(w, h)
        d = ImageDraw.Draw(im)
        if not vertical:
            for y in range(0, h, 8):
                d.rectangle([0, y, w - 1, y + 7], fill=WOOD_M)
                d.line([(0, y), (w - 1, y)], fill=WOOD_L)
                d.line([(0, y + 7), (w - 1, y + 7)], fill=OUT)
                d.line([(0, y + 6), (w - 1, y + 6)], fill=WOOD_D)
                for x in range((y * 3) % 17, w, 24):
                    d.point([(x, y + 3), (x + 1, y + 3)], fill=WOOD_D)
        else:
            for x in range(0, w, 8):
                d.rectangle([x, 0, x + 7, h - 1], fill=WOOD_M)
                d.line([(x, 0), (x, h - 1)], fill=WOOD_L)
                d.line([(x + 7, 0), (x + 7, h - 1)], fill=OUT)
                d.line([(x + 6, 0), (x + 6, h - 1)], fill=WOOD_D)
        return im

    back = logs(W, 32)
    d = ImageDraw.Draw(back)
    d.rectangle([0, 0, W - 1, 3], fill=WOOD_D)
    d.line([(0, 4), (W - 1, 4)], fill=WOOD_B)
    d.line([(0, 31), (W - 1, 31)], fill=OUT)
    # small window in the back wall
    d.rectangle([108, 10, 125, 23], fill=(110, 170, 210, 255), outline=OUT)
    d.line([(116, 10), (116, 23)], fill=OUT)
    d.line([(108, 16), (125, 16)], fill=OUT)
    d.point([(110, 12), (111, 12)], fill=(220, 240, 255, 255))
    save(back, "cabin", "cabin_back_wall.png")

    side = logs(16, 112, vertical=True)
    d = ImageDraw.Draw(side)
    d.rectangle([0, 0, 15, 3], fill=WOOD_D)
    save(side, "cabin", "cabin_side_wall.png")

    front_l = logs(64, 16)
    front_r = logs(64, 16)
    save(front_l, "cabin", "cabin_front_left.png")
    save(front_r, "cabin", "cabin_front_right.png")
    # door frame posts (draw on top of the doorway edges)
    door = new(32, 22)
    d = ImageDraw.Draw(door)
    d.rectangle([0, 0, 3, 21], fill=WOOD_D)
    d.rectangle([28, 0, 31, 21], fill=WOOD_D)
    d.rectangle([0, 0, 31, 3], fill=WOOD_D)
    d.line([(1, 4), (1, 20)], fill=WOOD_B)
    d.line([(29, 4), (29, 20)], fill=WOOD_B)
    save(add_outline(pad_to(door, 34, 24, "center")), "cabin", "cabin_door_frame.png")


# ------------------------------------------------------------------ gates & shrine
def build_gates_and_shrine():
    # --- Thorn barrier: 16 wide x 64 tall bramble wall (blocks a 4-tile corridor)
    r = random.Random(11)
    th = new(24, 72)
    d = ImageDraw.Draw(th)
    for i in range(0, 64, 5):
        x = 6 + (i * 7) % 9
        d.ellipse([x - 3, i + 3, x + 9, i + 14], fill=GRASS_DEEP)
        d.ellipse([x - 1, i + 4, x + 7, i + 11], fill=(66, 98, 52, 255))
    for i in range(14):
        y = r.randrange(4, 66)
        d.line([(r.randrange(2, 10), y), (r.randrange(12, 22), y + r.randrange(-6, 7))], fill=WOOD_D, width=1)
    for i in range(26):
        x, y = r.randrange(3, 21), r.randrange(4, 68)
        th.putpixel((x, y), (214, 70, 70, 255))
        th.putpixel((x + 1, y - 1), (255, 150, 140, 255))
    th = add_outline(th)
    save(th, "gates", "thorn_barrier.png")

    # --- Ruin gate: stone doors with a purple rune
    ru = new(24, 72)
    d = ImageDraw.Draw(ru)
    d.rectangle([2, 4, 21, 67], fill=STONE_M)
    d.rectangle([2, 4, 5, 67], fill=STONE_L)
    d.rectangle([18, 4, 21, 67], fill=STONE_D)
    for y in range(10, 66, 10):
        d.line([(2, y), (21, y)], fill=STONE_D)
    d.rectangle([2, 0, 21, 6], fill=STONE_L)
    d.rectangle([2, 66, 21, 71], fill=STONE_L)
    d.ellipse([7, 28, 16, 40], outline=(190, 130, 255, 255))
    d.line([(11, 29), (11, 39)], fill=(190, 130, 255, 255))
    d.line([(8, 34), (15, 34)], fill=(190, 130, 255, 255))
    save(add_outline(ru), "gates", "ruin_gate.png")

    # --- Arena seal: dark metal bars + glowing red sigil
    se = new(24, 72)
    d = ImageDraw.Draw(se)
    d.rectangle([2, 2, 21, 69], fill=(58, 44, 52, 255))
    for x in (5, 11, 17):
        d.rectangle([x, 4, x + 2, 67], fill=(98, 82, 92, 255))
    d.rectangle([2, 2, 21, 5], fill=(110, 90, 100, 255))
    d.rectangle([2, 66, 21, 69], fill=(110, 90, 100, 255))
    d.ellipse([6, 28, 17, 41], fill=(150, 24, 40, 255), outline=(255, 90, 90, 255))
    d.line([(11, 30), (11, 39)], fill=(255, 200, 150, 255))
    d.line([(8, 34), (14, 34)], fill=(255, 200, 150, 255))
    save(add_outline(se), "gates", "arena_seal.png")

    # --- Escape gate (closed + open), 40x56 arch
    def arch(open_):
        im = new(44, 60)
        d = ImageDraw.Draw(im)
        d.rectangle([2, 8, 9, 57], fill=STONE_M)
        d.rectangle([34, 8, 41, 57], fill=STONE_M)
        d.rectangle([2, 8, 4, 57], fill=STONE_L)
        d.rectangle([34, 8, 36, 57], fill=STONE_L)
        d.pieslice([2, 0, 41, 30], 180, 360, fill=STONE_M)
        d.arc([8, 6, 35, 30], 180, 360, fill=STONE_DD, width=3)
        d.rectangle([2, 54, 41, 59], fill=STONE_L)
        for y in range(14, 52, 9):
            d.line([(2, y), (9, y)], fill=STONE_D); d.line([(34, y), (41, y)], fill=STONE_D)
        inner = (255, 240, 170, 255) if open_ else (40, 28, 36, 255)
        d.rectangle([10, 16, 33, 53], fill=inner)
        d.pieslice([10, 6, 33, 28], 180, 360, fill=inner)
        if open_:
            d.rectangle([14, 20, 29, 53], fill=(255, 252, 220, 255))
            d.rectangle([18, 26, 25, 53], fill=(255, 255, 255, 255))
        else:
            for x in (14, 20, 26, 31):
                d.line([(x, 14), (x, 53)], fill=(98, 82, 92, 255), width=2)
            d.ellipse([17, 24, 27, 34], fill=(150, 24, 40, 255), outline=(255, 90, 90, 255))
        return add_outline(im)
    save(arch(False), "gates", "escape_gate_closed.png")
    save(arch(True), "gates", "escape_gate_open.png")

    # --- Checkpoint shrine (inactive + active crystal)
    def shrine(active):
        im = new(32, 44)
        d = ImageDraw.Draw(im)
        d.ellipse([2, 30, 29, 43], fill=STONE_M)
        d.ellipse([2, 28, 29, 40], fill=STONE_L)
        d.rectangle([9, 22, 22, 34], fill=STONE_M)
        d.rectangle([9, 22, 12, 34], fill=STONE_L)
        d.rectangle([7, 20, 24, 24], fill=STONE_L)
        base = (120, 220, 245, 255) if active else (90, 112, 130, 255)
        hi = (230, 255, 255, 255) if active else (150, 170, 190, 255)
        d.polygon([(16, 0), (22, 8), (20, 19), (12, 19), (10, 8)], fill=base)
        d.polygon([(16, 2), (18, 8), (16, 18), (13, 18)], fill=hi)
        if active:
            for (x, y) in ((4, 8), (27, 10), (6, 18), (26, 20)):
                im.putpixel((x, y), (200, 250, 255, 255))
                im.putpixel((x + 1, y), (120, 220, 245, 255))
        return add_outline(im)
    save(shrine(False), "gates", "shrine_off.png")
    save(shrine(True), "gates", "shrine_on.png")


def run():
    build_ground_atlas()
    build_decor_and_props()
    build_cabin()
    build_gates_and_shrine()
