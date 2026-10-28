"""Characters, crops, item icons, effects.  Called from make_assets.py."""
from art_common import *

FUR = {
    "wolf":  dict(body=(118, 118, 132, 255), dark=(78, 78, 96, 255), belly=(170, 170, 182, 255), eye=(230, 60, 60, 255), nose=(30, 24, 30, 255)),
    "boss":  dict(body=(122, 44, 56, 255), dark=(74, 24, 38, 255), belly=(176, 96, 84, 255), eye=(255, 226, 80, 255), nose=(30, 14, 20, 255)),
}


def wolf_frame(pose, phase, pal, spikes=False):
    """Draw one wolf facing RIGHT on a 32x32 canvas (feet near y=28)."""
    im = new(32, 32)
    d = ImageDraw.Draw(im)
    body, dark, belly, eye, nose = pal["body"], pal["dark"], pal["belly"], pal["eye"], pal["nose"]
    gy = 28
    dy = 0          # body vertical offset
    stretch = 0     # horizontal stretch for the lunge
    head_dy = 0
    if pose == "idle":
        dy = 1 if phase == 1 else 0
    elif pose == "walk":
        dy = 1 if phase % 2 == 1 else 0
    elif pose == "windup":
        dy = 3
        head_dy = 3
    elif pose == "lunge":
        stretch = 3
        dy = -1
    elif pose == "hurt":
        dy = 1
    by = 11 + dy

    # legs (drawn first, behind body) ---------------------------------
    def leg(x, y0, y1, col):
        d.rectangle([x, y0, x + 2, y1], fill=col)
        d.rectangle([x, y1, x + 3, y1 + 0], fill=col)

    if pose == "walk":
        off = [(-2, 2), (2, -2), (2, -2), (-2, 2)][phase % 4]
        # back legs
        leg(9 + off[0], by + 9, gy, dark)
        leg(13 - off[0], by + 9, gy, body)
        # front legs
        leg(19 + off[1], by + 9, gy, dark)
        leg(23 - off[1], by + 9, gy, body)
    elif pose == "windup":
        leg(9, by + 8, gy, dark); leg(13, by + 8, gy, body)
        leg(21, by + 8, gy - 1, dark); leg(25, by + 8, gy - 1, body)
    elif pose == "lunge":
        leg(4, by + 8, gy - 1, dark); leg(8, by + 9, gy - 2, body)
        leg(22, by + 8, gy - 2, dark); leg(26, by + 7, gy - 3, body)
    else:
        leg(9, by + 9, gy, dark); leg(13, by + 9, gy, body)
        leg(19, by + 9, gy, dark); leg(23, by + 9, gy, body)

    # tail -------------------------------------------------------------
    tail_up = 1 if (pose == "idle" and phase == 1) or pose == "lunge" else 0
    d.polygon([(7, by + 2), (2, by - 2 - tail_up * 2), (3, by + 1 - tail_up * 2), (4, by + 5), (8, by + 7)], fill=body)
    d.polygon([(2, by - 2 - tail_up * 2), (3, by - 1 - tail_up * 2), (5, by + 2)], fill=dark)

    # body -------------------------------------------------------------
    d.polygon([(6, by + 3), (10, by), (17, by - 1), (23, by + 1), (25, by + 4), (24, by + 8), (19, by + 10), (10, by + 10), (6, by + 7)], fill=body)
    d.polygon([(8, by + 1), (14, by - 1), (22, by + 1), (16, by + 3), (9, by + 4)], fill=dark)  # saddle
    d.polygon([(11, by + 7), (19, by + 7), (18, by + 9), (12, by + 9)], fill=belly)

    # spikes on the back for the boss ------------------------------------
    if spikes:
        for x in (9, 13, 17, 21):
            d.polygon([(x, by + 1), (x + 1, by - 3), (x + 3, by + 1)], fill=dark)
            d.point([(x + 1, by - 2)], fill=pal["belly"])

    # head -------------------------------------------------------------
    hy = by - 1 + head_dy
    hx = 22
    d.polygon([(hx, hy), (hx + 4, hy - 1), (hx + 8, hy + 2), (hx + 9, hy + 4), (hx + 7, hy + 6), (hx + 2, hy + 7), (hx - 1, hy + 5)], fill=body)
    d.polygon([(hx + 1, hy + 5), (hx + 7, hy + 5), (hx + 6, hy + 7), (hx + 2, hy + 7)], fill=belly)
    # ears
    d.polygon([(hx, hy), (hx + 1, hy - 4), (hx + 4, hy - 1)], fill=dark)
    d.polygon([(hx + 3, hy - 1), (hx + 5, hy - 4), (hx + 6, hy)], fill=body)
    # snout, nose, eye, mouth
    d.rectangle([hx + 8, hy + 2, hx + 9, hy + 3], fill=nose)
    d.point([(hx + 5, hy + 2), (hx + 6, hy + 2)], fill=eye)
    if pose in ("windup", "lunge"):
        d.line([(hx + 4, hy + 5), (hx + 8, hy + 5)], fill=(20, 10, 14, 255))
        d.point([(hx + 6, hy + 6), (hx + 8, hy + 6)], fill=(245, 245, 235, 255))  # fangs
    return add_outline(pad_to(im, 32, 32, "bottom"))


def build_wolves():
    pal = FUR["wolf"]
    poses = [("idle", 0), ("idle", 1), ("walk", 0), ("walk", 1), ("walk", 2), ("walk", 3),
             ("windup", 0), ("lunge", 0), ("hurt", 0)]
    sheet = new(32 * len(poses), 32)
    for i, (p, ph) in enumerate(poses):
        sheet.paste(wolf_frame(p, ph, pal), (i * 32, 0))
    save(sheet, "sprites", "wolf.png")

    palb = FUR["boss"]
    big = new(64 * len(poses), 64)
    for i, (p, ph) in enumerate(poses):
        f = wolf_frame(p, ph, palb, spikes=True).resize((64, 64), Image.NEAREST)
        # redo the outline at the new scale for crisp 1px edges
        a = np.array(f)
        a[:, :, 3] = np.where(a[:, :, 3] > 0, 255, 0)
        f = Image.fromarray(a)
        big.paste(f, (i * 64, 0))
    save(big, "sprites", "boss.png")


def build_npc():
    src = Image.open(os.path.join(WORLD, "Player", "Idle", "IdleDown.png")).convert("RGBA")
    out = new(128, 32)
    for i in range(4):
        fr = src.crop((i * 32, 0, (i + 1) * 32, 32))
        a = np.array(fr)
        h, w = a.shape[:2]
        for y in range(h):
            for x in range(w):
                r, g, b, al = a[y, x]
                if al == 0:
                    continue
                if (int(r), int(g), int(b)) == (114, 75, 44) and y < 14:      # hair -> silver
                    a[y, x, :3] = (205, 205, 215)
                elif (int(r), int(g), int(b)) == (79, 52, 47) and y < 14:     # hair shadow
                    a[y, x, :3] = (150, 150, 168)
                elif (int(r), int(g), int(b)) == (94, 113, 142):              # shirt -> purple
                    a[y, x, :3] = (140, 80, 170)
                elif (int(r), int(g), int(b)) == (72, 82, 98):
                    a[y, x, :3] = (96, 56, 126)
                elif (int(r), int(g), int(b)) == (180, 117, 56) and y >= 14:  # pants -> teal robe
                    a[y, x, :3] = (60, 150, 140)
                elif (int(r), int(g), int(b)) == (114, 75, 44) and y >= 14:
                    a[y, x, :3] = (40, 108, 104)
        out.paste(Image.fromarray(a), (i * 32, 0))
    save(out, "sprites", "npc_idle.png")
    # quest marker "!" and "?" (8x14)
    for name, col in (("quest_mark", (255, 226, 80, 255)), ("quest_done", (120, 230, 120, 255))):
        im = new(10, 16)
        d = ImageDraw.Draw(im)
        if name == "quest_mark":
            d.rectangle([3, 2, 5, 9], fill=col)
            d.rectangle([3, 11, 5, 13], fill=col)
        else:
            d.arc([1, 1, 8, 8], 180, 400, fill=col, width=2)
            d.line([(5, 7), (5, 9)], fill=col, width=2)
            d.rectangle([4, 11, 6, 13], fill=col)
        save(add_outline(im), "sprites", name + ".png")


def build_crops():
    # 16x24 sprites, bottom aligned (the soil tile is drawn separately)
    def canvas():
        return new(18, 26)
    leaf = (60, 170, 70, 255); leaf_d = (30, 120, 60, 255); leaf_l = (120, 210, 70, 255)
    stages = []
    # 0 seed
    im = canvas(); d = ImageDraw.Draw(im)
    d.ellipse([6, 19, 11, 23], fill=(96, 62, 38, 255))
    d.point([(8, 20), (9, 21)], fill=(30, 20, 16, 255))
    stages.append(im)
    # 1 sprout
    im = canvas(); d = ImageDraw.Draw(im)
    d.line([(9, 22), (9, 17)], fill=leaf_d)
    d.polygon([(9, 18), (5, 15), (4, 18), (8, 20)], fill=leaf)
    d.polygon([(9, 18), (13, 15), (14, 18), (10, 20)], fill=leaf_l)
    stages.append(im)
    # 2 growing
    im = canvas(); d = ImageDraw.Draw(im)
    d.line([(9, 23), (9, 11)], fill=leaf_d, width=2)
    for (x, y, dx) in ((9, 20, -1), (9, 16, 1), (9, 13, -1)):
        d.polygon([(x, y), (x + dx * 6, y - 3), (x + dx * 7, y), (x + dx * 2, y + 2)], fill=leaf if dx < 0 else leaf_l)
    d.ellipse([7, 6, 11, 10], fill=(190, 40, 60, 255))  # bud
    stages.append(im)
    # 3 mature - gumamela (hibiscus) flower
    im = canvas(); d = ImageDraw.Draw(im)
    d.line([(9, 24), (9, 12)], fill=leaf_d, width=2)
    for (x, y, dx) in ((9, 22, -1), (9, 18, 1), (9, 15, -1)):
        d.polygon([(x, y), (x + dx * 6, y - 3), (x + dx * 7, y), (x + dx * 2, y + 2)], fill=leaf if dx < 0 else leaf_l)
    petals = (232, 40, 70, 255); petals_l = (255, 110, 130, 255)
    for (cx, cy) in ((9, 4), (4, 7), (14, 7), (6, 11), (12, 11)):
        d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=petals)
    d.ellipse([5, 3, 12, 10], fill=petals_l)
    d.ellipse([7, 5, 10, 8], fill=(150, 20, 50, 255))
    d.line([(9, 6), (13, 1)], fill=(255, 226, 90, 255))
    d.point([(13, 1), (14, 1), (13, 0)], fill=(255, 240, 150, 255))
    stages.append(im)
    # 4 wilted
    im = canvas(); d = ImageDraw.Draw(im)
    brown = (130, 94, 60, 255); dry = (176, 140, 80, 255)
    d.line([(9, 24), (9, 15), (13, 13), (14, 17)], fill=brown, width=1)
    d.polygon([(9, 20), (4, 22), (3, 24), (8, 23)], fill=dry)
    d.polygon([(10, 18), (15, 21), (16, 23), (11, 21)], fill=dry)
    d.ellipse([12, 15, 16, 19], fill=(120, 80, 70, 255))
    stages.append(im)
    # 5 droop (dry warning): mature plant but leaves sagging, pale flower
    im = canvas(); d = ImageDraw.Draw(im)
    d.line([(9, 24), (9, 14), (12, 11), (13, 14)], fill=(110, 130, 60, 255), width=2)
    d.polygon([(9, 21), (3, 23), (3, 25), (8, 24)], fill=(110, 150, 70, 255))
    d.polygon([(10, 18), (16, 21), (16, 23), (10, 21)], fill=(110, 150, 70, 255))
    d.ellipse([10, 11, 16, 17], fill=(200, 110, 120, 255))
    d.ellipse([11, 12, 14, 15], fill=(140, 60, 80, 255))
    stages.append(im)
    sheet = new(18 * len(stages), 26)
    for i, s in enumerate(stages):
        sheet.paste(add_outline(pad_to(s, 18, 26, "bottom")) if False else s, (i * 18, 0))
    # outline each stage individually
    out = new(20 * len(stages), 28)
    for i, s in enumerate(stages):
        padded = new(20, 28)
        padded.paste(s, (1, 1), s)
        out.paste(add_outline(padded), (i * 20, 0))
    save(out, "sprites", "crops.png")


def icon(draw_fn, name):
    im = new(16, 16)
    draw_fn(ImageDraw.Draw(im), im)
    save(add_outline(pad_to(im, 18, 18, "center")), "icons", name + ".png")


def build_icons():
    out_dir("icons")

    def wood(d, im):
        d.polygon([(2, 11), (11, 2), (14, 5), (5, 14)], fill=WOOD_M)
        d.line([(3, 12), (12, 3)], fill=WOOD_L)
        d.ellipse([10, 1, 14, 5], fill=WOOD_B)
        d.line([(5, 11), (9, 7)], fill=WOOD_D)
    icon(wood, "wood")

    def stone(d, im):
        d.polygon([(2, 12), (4, 6), (9, 3), (14, 7), (14, 12), (8, 14)], fill=STONE_M)
        d.polygon([(4, 6), (9, 3), (13, 6), (8, 8)], fill=STONE_L)
        d.line([(8, 8), (8, 13)], fill=STONE_D)
    icon(stone, "stone")

    def gumamela(d, im):
        for (cx, cy) in ((8, 4), (4, 7), (12, 7), (6, 11), (10, 11)):
            d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=(232, 40, 70, 255))
        d.ellipse([5, 4, 11, 10], fill=(255, 110, 130, 255))
        d.ellipse([7, 6, 9, 8], fill=(150, 20, 50, 255))
        d.line([(8, 6), (12, 1)], fill=(255, 226, 90, 255))
    icon(gumamela, "gumamela")

    def gel(d, im):
        d.ellipse([2, 5, 13, 14], fill=(90, 200, 90, 255))
        d.ellipse([3, 3, 10, 9], fill=(130, 230, 120, 255))
        d.ellipse([4, 5, 7, 8], fill=(220, 255, 220, 255))
    icon(gel, "slime_gel")

    def fang(d, im):
        d.polygon([(4, 2), (12, 3), (9, 9), (8, 14), (6, 8)], fill=(235, 230, 215, 255))
        d.polygon([(5, 3), (8, 3), (7, 9)], fill=(255, 255, 250, 255))
        d.line([(9, 4), (8, 12)], fill=(190, 184, 170, 255))
    icon(fang, "wolf_fang")

    def potion(col_a, col_b):
        def f(d, im):
            d.rectangle([6, 1, 9, 4], fill=(180, 150, 110, 255))
            d.rectangle([5, 4, 10, 5], fill=(210, 220, 230, 255))
            d.ellipse([2, 5, 13, 15], fill=(210, 225, 235, 255))
            d.ellipse([3, 8, 12, 14], fill=col_a)
            d.ellipse([4, 9, 8, 12], fill=col_b)
        return f
    icon(potion((220, 40, 70, 255), (255, 120, 130, 255)), "potion_health")
    icon(potion((50, 100, 230, 255), (130, 180, 255, 255)), "potion_mana")

    # sword icons: wooden (pack icon, recoloured wood) and fang (bone-white)
    sw = Image.open(os.path.join(WORLD, "Itens", "SwordIcon.png")).convert("RGBA")
    wood_sword = recolor_map(sw, {})
    a = np.array(sw)
    # blade grey -> wood tones
    for y in range(a.shape[0]):
        for x in range(a.shape[1]):
            r, g, b, al = a[y, x]
            if al and abs(int(r) - int(g)) < 14 and abs(int(g) - int(b)) < 14 and r > 70:
                v = int(r)
                a[y, x, :3] = (min(255, int(v * 1.25) + 30), min(255, int(v * 0.85) + 20), int(v * 0.5) + 10)
    save(Image.fromarray(a), "icons", "sword_wooden.png")
    a = np.array(sw)
    for y in range(a.shape[0]):
        for x in range(a.shape[1]):
            r, g, b, al = a[y, x]
            if al and abs(int(r) - int(g)) < 14 and abs(int(g) - int(b)) < 14 and r > 70:
                v = min(255, int(r) + 70)
                a[y, x, :3] = (v, min(255, v + 4), min(255, v - 8))
            elif al and int(r) > int(b) + 20:
                a[y, x, :3] = (190, 150, 60)
    save(Image.fromarray(a), "icons", "sword_fang.png")

    def boots(d, im):
        d.polygon([(4, 2), (9, 2), (9, 9), (14, 10), (14, 14), (3, 14), (3, 8)], fill=(100, 200, 100, 255))
        d.polygon([(4, 2), (7, 2), (7, 8), (4, 8)], fill=(150, 235, 130, 255))
        d.rectangle([3, 13, 14, 14], fill=(50, 120, 60, 255))
        d.line([(4, 5), (8, 5)], fill=(50, 120, 60, 255))
    icon(boots, "gel_boots")

    def charm(d, im):
        d.arc([3, 0, 12, 8], 200, 340, fill=(200, 190, 170, 255), width=1)
        d.line([(4, 3), (8, 7)], fill=(200, 190, 170, 255))
        d.line([(11, 3), (8, 7)], fill=(200, 190, 170, 255))
        for (cx, cy) in ((8, 11), (5, 10), (11, 10), (6, 13), (10, 13)):
            d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=(232, 40, 70, 255))
        d.ellipse([6, 9, 10, 13], fill=(255, 226, 90, 255))
    icon(charm, "gumamela_charm")

    # HUD icons
    def heart(d, im):
        d.ellipse([1, 2, 8, 9], fill=(230, 50, 70, 255)); d.ellipse([7, 2, 14, 9], fill=(230, 50, 70, 255))
        d.polygon([(1, 7), (14, 7), (8, 14)], fill=(230, 50, 70, 255))
        d.point([(4, 4), (3, 5)], fill=(255, 170, 180, 255))
    icon(heart, "hud_hp")

    def drop(d, im):
        d.polygon([(8, 1), (13, 9), (11, 13), (5, 13), (3, 9)], fill=(60, 120, 240, 255))
        d.ellipse([4, 7, 12, 14], fill=(60, 120, 240, 255))
        d.point([(6, 9), (6, 10)], fill=(190, 220, 255, 255))
    icon(drop, "hud_mp")

    def bolt(d, im):
        d.ellipse([3, 3, 12, 12], fill=(100, 180, 255, 255))
        d.ellipse([5, 5, 10, 10], fill=(220, 245, 255, 255))
        d.point([(1, 8), (14, 8), (8, 1), (8, 14)], fill=(150, 210, 255, 255))
    icon(bolt, "hud_skill")

    def sword_hud(d, im):
        d.polygon([(11, 1), (14, 2), (13, 5), (6, 12), (4, 10)], fill=(200, 205, 215, 255))
        d.line([(3, 9), (7, 13)], fill=(200, 160, 70, 255), width=2)
        d.line([(3, 13), (1, 15)], fill=WOOD_M, width=2)
    icon(sword_hud, "hud_attack")

    def dodge(d, im):
        d.polygon([(2, 8), (8, 3), (8, 6), (14, 6), (14, 10), (8, 10), (8, 13)], fill=(240, 220, 150, 255))
    icon(dodge, "hud_dodge")


def build_fx():
    out_dir("fx")
    # magic bolt: 4 frames 16x16
    sheet = new(64, 16)
    for i in range(4):
        fr = new(16, 16)
        d = ImageDraw.Draw(fr)
        r = 4 + (i % 2)
        d.ellipse([8 - r - 3, 8 - r + 0, 8 + r - 3, 8 + r], fill=(60, 120, 240, 120))   # trail
        d.ellipse([8 - r, 8 - r, 8 + r, 8 + r], fill=(90, 170, 255, 255))
        d.ellipse([8 - r + 2, 8 - r + 2, 8 + r - 2, 8 + r - 2], fill=(210, 240, 255, 255))
        for (x, y) in ((2 + i, 6), (3 + i, 10)):
            fr.putpixel((x % 16, y), (170, 220, 255, 255))
        sheet.paste(fr, (i * 16, 0))
    save(sheet, "fx", "bolt.png")
    # impact burst: 4 frames 16x16
    sheet = new(64, 16)
    for i in range(4):
        fr = new(16, 16)
        d = ImageDraw.Draw(fr)
        r = 2 + i * 2
        d.ellipse([8 - r, 8 - r, 8 + r, 8 + r], outline=(180, 225, 255, 255 - i * 50))
        if i < 3:
            d.ellipse([8 - 2, 8 - 2, 8 + 2, 8 + 2], fill=(255, 255, 255, 255 - i * 80))
        sheet.paste(fr, (i * 16, 0))
    save(sheet, "fx", "burst.png")
    # sparkle / hit spark 3 frames 12x12 (white)
    sheet = new(36, 12)
    for i in range(3):
        fr = new(12, 12)
        d = ImageDraw.Draw(fr)
        L = 2 + i * 2
        d.line([(6, 6 - L), (6, 6 + L)], fill=(255, 255, 255, 255 - i * 60))
        d.line([(6 - L, 6), (6 + L, 6)], fill=(255, 255, 255, 255 - i * 60))
        sheet.paste(fr, (i * 12, 0))
    save(sheet, "fx", "spark.png")
    # soft round shadow (24x10)
    sh = new(24, 10)
    ImageDraw.Draw(sh).ellipse([1, 1, 22, 8], fill=(0, 0, 0, 70))
    save(sh, "fx", "shadow.png")
    sh2 = new(48, 18)
    ImageDraw.Draw(sh2).ellipse([1, 1, 46, 16], fill=(0, 0, 0, 80))
    save(sh2, "fx", "shadow_big.png")
    # telegraph ring (for boss slam): 96x96 red ring
    ring = new(96, 96)
    d = ImageDraw.Draw(ring)
    d.ellipse([2, 2, 93, 93], fill=(255, 60, 60, 60), outline=(255, 90, 90, 220), width=2)
    save(ring, "fx", "telegraph.png")
    # warning "!" over enemy before attack
    ex = new(8, 16)
    d = ImageDraw.Draw(ex)
    d.rectangle([3, 1, 4, 9], fill=(255, 70, 70, 255))
    d.rectangle([3, 12, 4, 14], fill=(255, 70, 70, 255))
    save(add_outline(pad_to(ex, 10, 18, "center")), "fx", "alert.png")
    # sleeping Zs / generic heal sparkle
    z = new(24, 12)
    d = ImageDraw.Draw(z)
    for i in range(3):
        d.line([(i * 8, 1), (i * 8 + 5, 1), (i * 8, 9), (i * 8 + 5, 9)], fill=(220, 230, 255, 255))
    save(z, "fx", "zzz.png")


def build_pit():
    im = new(64, 44)
    d = ImageDraw.Draw(im)
    d.ellipse([1, 4, 62, 42], fill=(70, 66, 70, 255))
    d.ellipse([5, 8, 58, 38], fill=(36, 32, 40, 255))
    d.ellipse([9, 12, 54, 35], fill=(22, 20, 28, 255))
    d.arc([5, 8, 58, 38], 200, 340, fill=(90, 86, 92, 255), width=2)
    save(im, "props", "pit.png")


def run():
    build_pit()
    build_wolves()
    build_npc()
    build_crops()
    build_icons()
    build_fx()
