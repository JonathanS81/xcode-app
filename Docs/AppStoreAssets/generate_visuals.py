from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont


WIDTH = 1320
HEIGHT = 2868
ROOT = Path(__file__).resolve().parent
RAW = ROOT / "raw"
FINAL = ROOT / "final"
FINAL.mkdir(parents=True, exist_ok=True)

FONT_REGULAR = "/System/Library/Fonts/SFNS.ttf"
FONT_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
ICON = (
    ROOT.parent.parent
    / "YamSheet"
    / "Assets.xcassets"
    / "AppIcon.appiconset"
    / "icon_1024x1024@1x.png"
)


SCREENS = [
    {
        "output": "01-scorecard.png",
        "source": "06-scorecard.png",
        "line1": "Toute la feuille de score",
        "highlight": "dans votre poche",
        "top": (250, 235, 255),
        "bottom": (214, 245, 255),
        "accent": (126, 55, 218),
        "soft": (221, 198, 255),
    },
    {
        "output": "02-history.png",
        "source": "01-history.png",
        "line1": "Retrouvez chaque partie",
        "highlight": "en un instant",
        "top": (215, 250, 255),
        "bottom": (255, 244, 190),
        "accent": (0, 173, 211),
        "soft": (164, 237, 250),
    },
    {
        "output": "03-players.png",
        "source": "02-players.png",
        "line1": "Tous vos joueurs,",
        "highlight": "toujours prêts",
        "top": (238, 255, 202),
        "bottom": (206, 247, 244),
        "accent": (52, 188, 93),
        "soft": (184, 242, 166),
    },
    {
        "output": "04-player-stats.png",
        "source": "05-player-stats.png",
        "line1": "Suivez vos progrès",
        "highlight": "partie après partie",
        "top": (255, 220, 242),
        "bottom": (242, 222, 255),
        "accent": (220, 39, 196),
        "soft": (255, 173, 225),
    },
    {
        "output": "05-global-stats.png",
        "source": "04-global-stats.png",
        "line1": "Records, podiums",
        "highlight": "et victoires",
        "top": (255, 244, 175),
        "bottom": (255, 219, 189),
        "accent": (255, 159, 10),
        "soft": (255, 217, 117),
    },
    {
        "output": "06-notations.png",
        "source": "03-notations.png",
        "line1": "Vos règles.",
        "highlight": "Votre façon de jouer.",
        "top": (224, 205, 255),
        "bottom": (255, 216, 234),
        "accent": (255, 45, 125),
        "soft": (255, 167, 202),
    },
]


def vertical_gradient(top, bottom):
    canvas = Image.new("RGB", (WIDTH, HEIGHT), top)
    pixels = canvas.load()
    for y in range(HEIGHT):
        t = y / (HEIGHT - 1)
        easing = t * t * (3 - 2 * t)
        color = tuple(
            round(top[i] * (1 - easing) + bottom[i] * easing)
            for i in range(3)
        )
        for x in range(WIDTH):
            pixels[x, y] = color
    return canvas


def rounded_image(image, radius):
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, image.width - 1, image.height - 1),
        radius=radius,
        fill=255,
    )
    result = Image.new("RGBA", image.size, (0, 0, 0, 0))
    result.paste(image.convert("RGBA"), (0, 0), mask)
    return result


def add_background_details(canvas, accent):
    overlay = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    shapes = [
        (-180, 300, 420, 900, 35),
        (1010, 60, 1510, 560, 30),
        (960, 2140, 1520, 2700, 24),
    ]
    for x1, y1, x2, y2, alpha in shapes:
        draw.ellipse((x1, y1, x2, y2), fill=(*accent, alpha))

    pip = (255, 255, 255, 78)
    for x, y, r in [
        (104, 190, 10),
        (1175, 480, 13),
        (1238, 1820, 9),
        (84, 2390, 15),
        (1160, 2550, 8),
    ]:
        draw.ellipse((x - r, y - r, x + r, y + r), fill=pip)
    canvas.paste(overlay, (0, 0), overlay)


def draw_headline(canvas, line1, highlight, accent, soft):
    draw = ImageDraw.Draw(canvas)
    label_font = ImageFont.truetype(FONT_REGULAR, 34)
    headline_font = ImageFont.truetype(FONT_BOLD, 78)
    headline_bold = ImageFont.truetype(FONT_BOLD, 84)

    icon = Image.open(ICON).convert("RGB").resize((82, 82), Image.Resampling.LANCZOS)
    icon = rounded_image(icon, 19)
    icon_x, icon_y = 92, 68
    canvas.paste(icon, (icon_x, icon_y), icon)
    draw.text(
        (194, 87),
        "YAMSHEET",
        font=label_font,
        fill=(49, 29, 91),
        anchor="la",
        stroke_width=0,
    )

    center = WIDTH // 2
    first_y = 238
    draw.text(
        (center, first_y),
        line1,
        font=headline_font,
        fill=(33, 26, 42),
        anchor="ma",
    )

    text_bbox = draw.textbbox((0, 0), highlight, font=headline_bold)
    text_w = text_bbox[2] - text_bbox[0]
    text_h = text_bbox[3] - text_bbox[1]
    pill_w = min(text_w + 76, WIDTH - 150)
    pill_h = text_h + 46
    pill_x = (WIDTH - pill_w) // 2
    pill_y = 342

    highlight_layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    highlight_draw = ImageDraw.Draw(highlight_layer)
    highlight_draw.rounded_rectangle(
        (pill_x, pill_y, pill_x + pill_w, pill_y + pill_h),
        radius=pill_h // 2,
        fill=(*soft, 245),
        outline=(*accent, 95),
        width=3,
    )
    canvas.paste(highlight_layer, (0, 0), highlight_layer)
    draw = ImageDraw.Draw(canvas)
    draw.text(
        (center, pill_y + pill_h / 2 - 3),
        highlight,
        font=headline_bold,
        fill=(35, 26, 45),
        anchor="mm",
    )


def place_screenshot(canvas, path):
    screenshot = Image.open(path).convert("RGB")
    target_width = 1120
    scale = target_width / screenshot.width
    target_height = round(screenshot.height * scale)
    screenshot = screenshot.resize(
        (target_width, target_height),
        Image.Resampling.LANCZOS,
    )
    screenshot = rounded_image(screenshot, 74)

    x = (WIDTH - target_width) // 2
    y = 570
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        (x - 10, y + 24, x + target_width + 10, y + target_height + 42),
        radius=86,
        fill=(35, 19, 69, 92),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(34))
    canvas.paste(shadow, (0, 0), shadow)

    border = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    border_draw = ImageDraw.Draw(border)
    border_draw.rounded_rectangle(
        (x - 3, y - 3, x + target_width + 3, y + target_height + 3),
        radius=78,
        fill=(255, 255, 255, 190),
    )
    canvas.paste(border, (0, 0), border)
    canvas.paste(screenshot, (x, y), screenshot)


def make_visual(config):
    canvas = vertical_gradient(config["top"], config["bottom"])
    add_background_details(canvas, config["accent"])
    draw_headline(
        canvas,
        config["line1"],
        config["highlight"],
        config["accent"],
        config["soft"],
    )
    place_screenshot(canvas, RAW / config["source"])
    output = FINAL / config["output"]
    canvas.save(output, "PNG", optimize=True)
    return output


def make_contact_sheet(outputs):
    thumb_width = 330
    thumb_height = 717
    gap = 28
    sheet = Image.new(
        "RGB",
        (thumb_width * 3 + gap * 4, thumb_height * 2 + gap * 3),
        (245, 245, 248),
    )
    for index, output in enumerate(outputs):
        image = Image.open(output).convert("RGB")
        image.thumbnail((thumb_width, thumb_height), Image.Resampling.LANCZOS)
        x = gap + (index % 3) * (thumb_width + gap)
        y = gap + (index // 3) * (thumb_height + gap)
        sheet.paste(image, (x, y))
    sheet.save(ROOT / "preview-series.png", "PNG", optimize=True)


if __name__ == "__main__":
    generated = [make_visual(config) for config in SCREENS]
    make_contact_sheet(generated)
    for path in generated:
        image = Image.open(path)
        print(f"{path.name}: {image.width}×{image.height} {image.mode}")
