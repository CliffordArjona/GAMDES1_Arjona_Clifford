"""Menu art: pixel logo + vignette.  Called from make_assets.py."""
from art_common import *
from PIL import ImageFont, ImageFilter

FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"


def _pixel_text(text, size, scale):
    """Render text, threshold it to hard pixels, then scale up with nearest-neighbour."""
    font = ImageFont.truetype(FONT_BOLD, size)
    w = int(font.getlength(text)) + 6
    h = size + 10
    im = Image.new("L", (w, h), 0)
    ImageDraw.Draw(im).text((3, 2), text, font=font, fill=255)
    im = im.point(lambda v: 255 if v > 110 else 0)
    bbox = im.getbbox()
    im = im.crop(bbox)
    return im.resize((im.width * scale, im.height * scale), Image.NEAREST)


def build_logo():
    S = 4
    big = _pixel_text("FORSAKEN THICKET", 20, S)
    top = _pixel_text("THE", 12, S)
    W = big.width + 150
    H = big.height + top.height + 70
    logo = new(W, H)
    # vertical gold gradient fill + outline + shadow for a text mask
    def paint(mask, x, y, colors):
        layer = new(W, H)
        grad = Image.new("RGBA", mask.size)
        gp = grad.load()
        for yy in range(mask.height):
            t = yy / max(1, mask.height - 1)
            c0, c1 = colors
            col = tuple(int(c0[i] + (c1[i] - c0[i]) * t) for i in range(3)) + (255,)
            for xx in range(mask.width):
                gp[xx, yy] = col
        layer.paste(grad, (x, y), mask)
        return layer
    def with_outline(layer, thick, color):
        a = np.array(layer)[:, :, 3] > 0
        grown = ndimage.binary_dilation(a, structure=np.ones((3, 3)), iterations=thick)
        o = np.zeros((H, W, 4), np.uint8)
        o[grown] = color
        return Image.fromarray(o)
    bx = (W - big.width) // 2
    by = top.height + 30
    tx = (W - top.width) // 2
    gold = paint(big, bx, by, ((255, 232, 130), (222, 140, 40)))
    thin = paint(top, tx, 12, ((250, 250, 235), (190, 200, 205)))
    body = new(W, H)
    body.alpha_composite(gold)
    body.alpha_composite(thin)
    outline = with_outline(body, 4, (39, 31, 27, 255))
    shadow = new(W, H)
    shadow.paste(outline, (0, 6), outline)
    sa = np.array(shadow)
    sa[:, :, :3] = 0
    sa[:, :, 3] = (sa[:, :, 3] * 0.45).astype(np.uint8)
    final = new(W, H)
    final.alpha_composite(Image.fromarray(sa))
    final.alpha_composite(outline)
    final.alpha_composite(body)
    # light highlight on the top edge of the big letters
    hl = np.array(final)
    # small gumamela flowers on both sides, like the game's flower
    flower = Image.open(os.path.join(GEN, "icons", "gumamela.png")).convert("RGBA")
    flower = flower.resize((flower.width * 3, flower.height * 3), Image.NEAREST)
    final.alpha_composite(flower, (4, by + big.height // 2 - flower.height // 2))
    final.alpha_composite(flower, (W - flower.width - 4, by + big.height // 2 - flower.height // 2))
    save(final, "ui", "logo.png")


def build_vignette():
    w, h = 256, 144
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt(((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2)
    a = np.clip((d - 0.55) / 0.75, 0, 1) ** 1.6
    img = np.zeros((h, w, 4), np.uint8)
    img[:, :, 0] = 6
    img[:, :, 1] = 4
    img[:, :, 2] = 12
    img[:, :, 3] = (a * 230).astype(np.uint8)
    save(Image.fromarray(img), "ui", "vignette.png")


def build_spark():
    im = new(4, 4)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 1, 2, 2], fill=(255, 235, 150, 255))
    im.putpixel((1, 0), (255, 235, 150, 120)); im.putpixel((0, 1), (255, 235, 150, 120))
    im.putpixel((2, 3), (255, 235, 150, 120)); im.putpixel((3, 2), (255, 235, 150, 120))
    save(im, "ui", "firefly.png")


def run():
    out_dir("ui")
    build_logo()
    build_vignette()
    build_spark()
