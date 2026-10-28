"""
Shared helpers for the art generator (The Forsaken Thicket).
Run via tools/make_assets.py  (needs: pip install pillow numpy scipy)
Everything is generated from code so the team can tweak palettes and re-run.
"""
import os
import random
from PIL import Image, ImageDraw
import numpy as np
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
WORLD = os.path.join(ROOT, "assets", "world")
GEN = os.path.join(ROOT, "assets", "generated")

# ---- palette sampled from the "Asset Pack Free" art so everything matches ----
OUT = (39, 31, 27, 255)          # dark outline
WOOD_D = (69, 42, 27, 255)
WOOD_M = (114, 75, 44, 255)
WOOD_L = (140, 91, 62, 255)
WOOD_B = (180, 117, 56, 255)
GRASS_D = (26, 122, 63, 255)
GRASS = (51, 152, 75, 255)
GRASS_L = (96, 193, 53, 255)
GRASS_DEEP = (36, 82, 62, 255)
LEAF_DARK = (43, 68, 39, 255)
SAND = (214, 168, 81, 255)
SAND_D = (187, 117, 71, 255)
GOLD = (248, 197, 58, 255)
STONE_L = (166, 158, 154, 255)
STONE_M = (120, 116, 118, 255)
STONE_D = (89, 87, 87, 255)
STONE_DD = (60, 58, 62, 255)
SHADOW = (0, 0, 0, 70)


def out_dir(*parts):
    p = os.path.join(GEN, *parts)
    os.makedirs(p, exist_ok=True)
    return p


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def save(img, folder, name):
    p = os.path.join(out_dir(folder), name)
    img.save(p)
    return p


def add_outline(img, color=OUT, diagonal=False):
    """Return a copy of img with a 1px outline around all opaque pixels.
    The image must have 1px of transparent margin for the outline to fit."""
    a = np.array(img)
    alpha = a[:, :, 3] > 0
    k = np.ones((3, 3), bool) if diagonal else ndimage.generate_binary_structure(2, 1)
    grown = ndimage.binary_dilation(alpha, structure=k)
    edge = grown & ~alpha
    res = a.copy()
    res[edge] = color
    return Image.fromarray(res)


def tint(img, rgb_mul=(1, 1, 1), add=(0, 0, 0)):
    a = np.array(img).astype(float)
    for i in range(3):
        a[:, :, i] = np.clip(a[:, :, i] * rgb_mul[i] + add[i], 0, 255)
    return Image.fromarray(a.astype(np.uint8))


def recolor_map(img, mapping):
    a = np.array(img)
    for src, dst in mapping.items():
        m = (a[:, :, 0] == src[0]) & (a[:, :, 1] == src[1]) & (a[:, :, 2] == src[2]) & (a[:, :, 3] > 0)
        a[m, 0], a[m, 1], a[m, 2] = dst[0], dst[1], dst[2]
    return Image.fromarray(a)


def shift_hue(img, hue_shift=0.0, sat=1.0, val=1.0):
    rgba = img.convert("RGBA")
    a = np.array(rgba)
    hsv = np.array(rgba.convert("RGB").convert("HSV")).astype(float)
    hsv[:, :, 0] = (hsv[:, :, 0] + hue_shift * 255) % 256
    hsv[:, :, 1] = np.clip(hsv[:, :, 1] * sat, 0, 255)
    hsv[:, :, 2] = np.clip(hsv[:, :, 2] * val, 0, 255)
    rgb = Image.fromarray(hsv.astype(np.uint8), "HSV").convert("RGB")
    out = np.array(rgb)
    res = np.dstack([out, a[:, :, 3]])
    return Image.fromarray(res.astype(np.uint8), "RGBA")


def crop_component(src_img, seed, dilate=0, min_x=0, max_x=None, min_y=0, max_y=None):
    """Crop the 8-connected opaque component that contains pixel 'seed' (x,y)."""
    a = np.array(src_img.convert("RGBA"))
    alpha = a[:, :, 3] > 0
    if max_x is None:
        max_x = a.shape[1]
    if max_y is None:
        max_y = a.shape[0]
    mask = np.zeros_like(alpha)
    mask[min_y:max_y, min_x:max_x] = alpha[min_y:max_y, min_x:max_x]
    lab, _ = ndimage.label(mask, structure=np.ones((3, 3)))
    l = lab[seed[1], seed[0]]
    if l == 0:
        raise ValueError(f"seed {seed} not on an opaque pixel")
    sel = lab == l
    ys, xs = np.where(sel)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    res = a.copy()
    res[~sel] = 0
    return Image.fromarray(res[y0:y1, x0:x1]), (x0, y0, x1, y1)


def pad_to(img, w, h, anchor="bottom"):
    c = new(w, h)
    x = (w - img.width) // 2
    y = h - img.height if anchor == "bottom" else (h - img.height) // 2
    c.paste(img, (x, y), img)
    return c


def noise_tile(base, rng, dots=((-14, 0.06), (12, 0.05)), size=16):
    """Flat color tile with a few lighter/darker specks for texture."""
    t = Image.new("RGBA", (size, size), base)
    px = t.load()
    for delta, density in dots:
        for y in range(size):
            for x in range(size):
                if rng.random() < density:
                    r, g, b, a = px[x, y]
                    px[x, y] = (max(0, min(255, r + delta)), max(0, min(255, g + delta)), max(0, min(255, b + delta)), 255)
    return t
