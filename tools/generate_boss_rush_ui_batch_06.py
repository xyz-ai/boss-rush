from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import math
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parent.parent
PORTRAITS_DIR = ROOT / "assets" / "battle" / "cards" / "portraits"
SIZE = (512, 512)


@dataclass(frozen=True)
class OutputSpec:
    filename: str
    role: str


OUTPUT_SPECS = (
    OutputSpec("card_aggression_01.png", "aggression"),
    OutputSpec("card_defense_01.png", "defense"),
    OutputSpec("card_pressure_01.png", "pressure"),
    OutputSpec("bet_probe_01.png", "probe"),
)


def main() -> int:
    output_paths = [PORTRAITS_DIR / spec.filename for spec in OUTPUT_SPECS]
    existing = [path for path in output_paths if path.exists()]
    if existing:
        print("Refusing to overwrite existing files:", file=sys.stderr)
        for path in existing:
            print(f" - {path}", file=sys.stderr)
        return 1

    images = {
        "card_aggression_01.png": make_aggression(SIZE),
        "card_defense_01.png": make_defense(SIZE),
        "card_pressure_01.png": make_pressure(SIZE),
        "bet_probe_01.png": make_probe(SIZE),
    }

    for spec in OUTPUT_SPECS:
        out_path = PORTRAITS_DIR / spec.filename
        images[spec.filename].save(out_path, "PNG")
        validate_output(out_path)

    print("Generated UI batch 06 assets:")
    for spec in OUTPUT_SPECS:
        print(f" - {PORTRAITS_DIR / spec.filename} ({SIZE[0]}x{SIZE[1]})")
    return 0


def validate_output(path: Path) -> None:
    if not path.exists():
        raise RuntimeError(f"Missing output: {path}")
    with Image.open(path) as image:
        if image.size != SIZE:
            raise RuntimeError(f"Unexpected output size for {path}: {image.size}")
        if image.mode not in ("RGB", "RGBA"):
            raise RuntimeError(f"Unexpected output mode for {path}: {image.mode}")
        if image.mode == "RGBA":
            alpha = image.getchannel("A")
            if alpha.getbbox() != (0, 0, SIZE[0], SIZE[1]):
                raise RuntimeError(f"Image contains transparent border: {path}")
            if alpha.getextrema() != (255, 255):
                raise RuntimeError(f"Image is not fully opaque: {path}")


def blank(size: tuple[int, int], color: tuple[int, int, int, int]) -> Image.Image:
    return Image.new("RGBA", size, color)


def vertical_gradient(size: tuple[int, int], top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    image = Image.new("RGBA", size, (0, 0, 0, 255))
    pixels = image.load()
    for y in range(size[1]):
        t = y / max(1, size[1] - 1)
        color = tuple(int(top[i] * (1.0 - t) + bottom[i] * t) for i in range(3))
        for x in range(size[0]):
            pixels[x, y] = (color[0], color[1], color[2], 255)
    return image


def radial_mask(size: tuple[int, int], center: tuple[float, float], radius: float, power: float = 1.8) -> Image.Image:
    mask = Image.new("L", size, 0)
    pixels = mask.load()
    cx, cy = center
    for y in range(size[1]):
        for x in range(size[0]):
            dx = x - cx
            dy = y - cy
            d = math.sqrt(dx * dx + dy * dy) / max(1.0, radius)
            value = max(0.0, 1.0 - d)
            pixels[x, y] = int((value ** power) * 255)
    return mask


def alpha_composite_masked(base: Image.Image, layer: Image.Image, mask: Image.Image) -> Image.Image:
    masked = Image.new("RGBA", base.size, (0, 0, 0, 0))
    masked.paste(layer, (0, 0), mask)
    return Image.alpha_composite(base, masked)


def soft_vignette(base: Image.Image, alpha: int) -> Image.Image:
    mask = Image.new("L", base.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rectangle((0, 0, base.size[0], base.size[1]), fill=255)
    inner = Image.new("L", base.size, 0)
    inner_draw = ImageDraw.Draw(inner)
    inner_draw.rounded_rectangle((38, 34, base.size[0] - 39, base.size[1] - 35), radius=50, fill=255)
    inner = inner.filter(ImageFilter.GaussianBlur(34))
    vignette = ImageChops.subtract(mask, inner)
    overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    overlay.putalpha(vignette.point(lambda p: int(p * (alpha / 255.0))))
    return Image.alpha_composite(base, overlay)


def add_grain(base: Image.Image, amount: int, alpha: int, seed: int) -> Image.Image:
    rng = random.Random(seed)
    noise = Image.new("RGBA", base.size, (0, 0, 0, 0))
    pixels = noise.load()
    for y in range(base.size[1]):
        for x in range(base.size[0]):
            value = max(0, min(255, 128 + rng.randint(-amount, amount)))
            pixels[x, y] = (value, value, value, alpha)
    softened = noise.filter(ImageFilter.GaussianBlur(0.55))
    return ImageChops.overlay(base, softened)


def add_fog(base: Image.Image, center: tuple[float, float], radius: float, color: tuple[int, int, int], alpha: int, blur: float) -> Image.Image:
    fog = Image.new("RGBA", base.size, (color[0], color[1], color[2], 0))
    mask = radial_mask(base.size, center, radius)
    mask = mask.filter(ImageFilter.GaussianBlur(blur))
    fog.putalpha(mask.point(lambda p: int(p * (alpha / 255.0))))
    return Image.alpha_composite(base, fog)


def stroke_path(points: list[tuple[float, float]], width: int, color: tuple[int, int, int, int], blur: float = 0.0) -> Image.Image:
    layer = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.line(points, fill=color, width=width, joint="curve")
    if blur > 0:
        layer = layer.filter(ImageFilter.GaussianBlur(blur))
    return layer


def polygon_layer(points: list[tuple[float, float]], color: tuple[int, int, int, int], blur: float = 0.0) -> Image.Image:
    layer = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.polygon(points, fill=color)
    if blur > 0:
        layer = layer.filter(ImageFilter.GaussianBlur(blur))
    return layer


def ellipse_layer(box: tuple[int, int, int, int], color: tuple[int, int, int, int], blur: float = 0.0) -> Image.Image:
    layer = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.ellipse(box, fill=color)
    if blur > 0:
        layer = layer.filter(ImageFilter.GaussianBlur(blur))
    return layer


def make_base(top: tuple[int, int, int], bottom: tuple[int, int, int], glow: tuple[int, int, int], seed: int) -> Image.Image:
    image = vertical_gradient(SIZE, top, bottom)
    image = add_fog(image, (256, 120), 210, glow, 40, 22)
    image = add_fog(image, (256, 392), 250, (30, 26, 24), 52, 28)
    image = soft_vignette(image, 74)
    return add_grain(image, amount=9, alpha=16, seed=seed)


def make_aggression(size: tuple[int, int]) -> Image.Image:
    image = make_base((78, 42, 30), (25, 15, 14), (146, 84, 46), seed=6101)

    motion_back = polygon_layer(
        [(120, 362), (206, 278), (292, 224), (344, 208), (302, 286), (240, 344), (162, 398)],
        (40, 20, 18, 180),
        blur=16,
    )
    image = Image.alpha_composite(image, motion_back)

    drive_mass = polygon_layer(
        [(170, 350), (222, 244), (306, 176), (368, 166), (342, 246), (266, 332), (198, 392)],
        (18, 12, 12, 230),
        blur=5,
    )
    image = Image.alpha_composite(image, drive_mass)

    forearm = stroke_path(
        [(166, 356), (226, 300), (288, 238), (356, 192), (420, 160)],
        width=46,
        color=(22, 14, 14, 230),
        blur=3,
    )
    image = Image.alpha_composite(image, forearm)

    head = ellipse_layer((248, 118, 316, 188), (28, 16, 14, 220), blur=2)
    torso = polygon_layer([(206, 214), (248, 174), (304, 176), (338, 262), (308, 360), (216, 354), (182, 280)], (20, 14, 14, 215), blur=4)
    image = Image.alpha_composite(image, head)
    image = Image.alpha_composite(image, torso)

    streak = stroke_path([(136, 388), (218, 314), (310, 238), (398, 176), (462, 138)], width=18, color=(204, 116, 58, 110), blur=8)
    image = Image.alpha_composite(image, streak)
    image = add_fog(image, (300, 230), 150, (206, 108, 52), 36, 12)
    return image.convert("RGB")


def make_defense(size: tuple[int, int]) -> Image.Image:
    image = make_base((54, 66, 78), (16, 22, 30), (94, 116, 136), seed=6201)

    barrier = polygon_layer(
        [(176, 142), (336, 142), (382, 238), (382, 360), (336, 418), (176, 418), (130, 360), (130, 238)],
        (20, 26, 34, 228),
        blur=4,
    )
    image = Image.alpha_composite(image, barrier)

    shoulders = polygon_layer(
        [(118, 300), (176, 228), (214, 252), (196, 366), (136, 388)],
        (22, 28, 38, 210),
        blur=5,
    )
    shoulders_r = polygon_layer(
        [(394, 300), (336, 228), (298, 252), (316, 366), (376, 388)],
        (22, 28, 38, 210),
        blur=5,
    )
    image = Image.alpha_composite(image, shoulders)
    image = Image.alpha_composite(image, shoulders_r)

    head = ellipse_layer((224, 112, 288, 180), (26, 32, 40, 220), blur=2)
    hands = stroke_path([(132, 274), (188, 256), (248, 252), (324, 254), (380, 274)], width=34, color=(28, 34, 42, 214), blur=2)
    image = Image.alpha_composite(image, head)
    image = Image.alpha_composite(image, hands)

    seam = stroke_path([(152, 164), (256, 182), (360, 164)], width=10, color=(126, 146, 168, 52), blur=10)
    image = Image.alpha_composite(image, seam)
    image = add_fog(image, (256, 186), 110, (112, 130, 148), 28, 10)
    return image.convert("RGB")


def make_pressure(size: tuple[int, int]) -> Image.Image:
    image = make_base((62, 42, 66), (20, 14, 24), (116, 72, 122), seed=6301)

    ceiling = polygon_layer(
        [(84, 48), (428, 48), (390, 164), (326, 210), (186, 210), (122, 164)],
        (22, 14, 28, 226),
        blur=6,
    )
    image = Image.alpha_composite(image, ceiling)

    squeeze_left = polygon_layer([(96, 148), (162, 224), (178, 360), (148, 468), (92, 430), (70, 286)], (24, 16, 28, 188), blur=10)
    squeeze_right = polygon_layer([(416, 148), (350, 224), (334, 360), (364, 468), (420, 430), (442, 286)], (24, 16, 28, 188), blur=10)
    image = Image.alpha_composite(image, squeeze_left)
    image = Image.alpha_composite(image, squeeze_right)

    figure = polygon_layer([(212, 262), (246, 212), (286, 214), (310, 292), (286, 380), (224, 380), (194, 306)], (18, 10, 22, 214), blur=5)
    head = ellipse_layer((228, 156, 282, 214), (24, 14, 28, 220), blur=2)
    image = Image.alpha_composite(image, figure)
    image = Image.alpha_composite(image, head)

    down_shadow = stroke_path([(128, 88), (196, 120), (256, 138), (320, 122), (388, 90)], width=84, color=(12, 8, 16, 120), blur=22)
    image = Image.alpha_composite(image, down_shadow)
    image = add_fog(image, (256, 284), 110, (154, 104, 164), 18, 12)
    return image.convert("RGB")


def make_probe(size: tuple[int, int]) -> Image.Image:
    image = make_base((88, 66, 42), (24, 18, 16), (158, 122, 74), seed=6401)

    hesitant_core = polygon_layer(
        [(196, 244), (232, 212), (266, 206), (286, 248), (272, 328), (220, 336), (192, 292)],
        (24, 18, 14, 205),
        blur=4,
    )
    head = ellipse_layer((220, 162, 276, 220), (34, 22, 16, 208), blur=2)
    image = Image.alpha_composite(image, hesitant_core)
    image = Image.alpha_composite(image, head)

    reaching_hand = stroke_path(
        [(244, 276), (282, 250), (318, 228), (348, 222), (378, 234)],
        width=24,
        color=(28, 20, 16, 188),
        blur=2,
    )
    image = Image.alpha_composite(image, reaching_hand)

    partial_light = stroke_path([(250, 276), (300, 246), (342, 226), (386, 226)], width=10, color=(194, 148, 88, 88), blur=8)
    image = Image.alpha_composite(image, partial_light)

    side_fog = add_fog(image, (164, 268), 150, (42, 30, 22), 42, 20)
    image = side_fog
    image = add_fog(image, (334, 236), 96, (174, 132, 82), 26, 10)
    return image.convert("RGB")


if __name__ == "__main__":
    raise SystemExit(main())
