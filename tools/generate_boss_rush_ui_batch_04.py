from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parent.parent
FRAMES_DIR = ROOT / "assets" / "battle" / "cards" / "frames"
SIZE = (512, 768)


@dataclass(frozen=True)
class OutputSpec:
    filename: str
    role: str


OUTPUT_SPECS = (
    OutputSpec("frame_aggression.png", "aggression"),
    OutputSpec("frame_defense.png", "defense"),
    OutputSpec("frame_pressure.png", "pressure"),
    OutputSpec("frame_bet.png", "bet"),
)


def main() -> int:
    output_paths = [FRAMES_DIR / spec.filename for spec in OUTPUT_SPECS]
    existing = [path for path in output_paths if path.exists()]
    if existing:
        print("Refusing to overwrite existing files:", file=sys.stderr)
        for path in existing:
            print(f" - {path}", file=sys.stderr)
        return 1

    images = {
        "frame_aggression.png": make_frame_aggression(SIZE),
        "frame_defense.png": make_frame_defense(SIZE),
        "frame_pressure.png": make_frame_pressure(SIZE),
        "frame_bet.png": make_frame_bet(SIZE),
    }

    for spec in OUTPUT_SPECS:
        out_path = FRAMES_DIR / spec.filename
        images[spec.filename].save(out_path, "PNG")
        validate_output(out_path)

    print("Generated UI batch 04 assets:")
    for spec in OUTPUT_SPECS:
        print(f" - {FRAMES_DIR / spec.filename} ({SIZE[0]}x{SIZE[1]})")
    return 0


def validate_output(path: Path) -> None:
    if not path.exists():
        raise RuntimeError(f"Missing output: {path}")
    with Image.open(path) as image:
        if image.size != SIZE:
            raise RuntimeError(f"Unexpected output size for {path}: {image.size}")
        if image.mode != "RGBA":
            raise RuntimeError(f"Unexpected output mode for {path}: {image.mode}")
        if image.getchannel("A").getbbox() is None:
            raise RuntimeError(f"Alpha channel is empty for {path}")


def blank(size: tuple[int, int]) -> Image.Image:
    return Image.new("RGBA", size, (0, 0, 0, 0))


def rounded_mask(size: tuple[int, int], radius: int, inset: int = 0) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle(
        (inset, inset, size[0] - 1 - inset, size[1] - 1 - inset),
        radius=radius,
        fill=255,
    )
    return mask


def rect_mask(size: tuple[int, int], box: tuple[int, int, int, int], radius: int = 0, blur: float = 0.0, fill: int = 255) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    if radius > 0:
        draw.rounded_rectangle(box, radius=radius, fill=fill)
    else:
        draw.rectangle(box, fill=fill)
    if blur > 0:
        mask = mask.filter(ImageFilter.GaussianBlur(blur))
    return mask


def vertical_gradient(size: tuple[int, int], top: tuple[int, int, int, int], bottom: tuple[int, int, int, int]) -> Image.Image:
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    pixels = image.load()
    for y in range(size[1]):
        t = y / max(1, size[1] - 1)
        color = tuple(int(top[i] * (1.0 - t) + bottom[i] * t) for i in range(4))
        for x in range(size[0]):
            pixels[x, y] = color
    return image


def horizontal_gradient(size: tuple[int, int], left: tuple[int, int, int, int], right: tuple[int, int, int, int]) -> Image.Image:
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    pixels = image.load()
    for x in range(size[0]):
        t = x / max(1, size[0] - 1)
        color = tuple(int(left[i] * (1.0 - t) + right[i] * t) for i in range(4))
        for y in range(size[1]):
            pixels[x, y] = color
    return image


def alpha_composite_masked(base: Image.Image, layer: Image.Image, mask: Image.Image) -> Image.Image:
    masked = Image.new("RGBA", base.size, (0, 0, 0, 0))
    masked.paste(layer, (0, 0), mask)
    return Image.alpha_composite(base, masked)


def add_grain(base: Image.Image, mask: Image.Image, amount: int, alpha: int, seed: int) -> Image.Image:
    rng = random.Random(seed)
    noise = Image.new("RGBA", base.size, (0, 0, 0, 0))
    noise_px = noise.load()
    mask_px = mask.load()
    for y in range(base.size[1]):
        for x in range(base.size[0]):
            if mask_px[x, y] == 0:
                continue
            value = max(0, min(255, 128 + rng.randint(-amount, amount)))
            noise_px[x, y] = (value, value, value, alpha)
    softened = noise.filter(ImageFilter.GaussianBlur(0.45))
    return ImageChops.overlay(base, softened)


def add_edge_wear(base: Image.Image, mask: Image.Image, seed: int, count: int, tint: tuple[int, int, int]) -> Image.Image:
    rng = random.Random(seed)
    edge = ImageChops.subtract(mask.filter(ImageFilter.GaussianBlur(4.0)), mask.filter(ImageFilter.GaussianBlur(1.4)))
    wear = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(wear)
    edge_px = edge.load()
    for _ in range(count):
        x = rng.randint(16, base.size[0] - 17)
        y = rng.randint(16, base.size[1] - 17)
        if edge_px[x, y] == 0:
            continue
        rx = rng.randint(3, 10)
        ry = rng.randint(1, 4)
        color = (
            max(0, min(255, tint[0] + rng.randint(-12, 12))),
            max(0, min(255, tint[1] + rng.randint(-10, 10))),
            max(0, min(255, tint[2] + rng.randint(-8, 8))),
            16 + rng.randint(0, 18),
        )
        draw.ellipse((x - rx, y - ry, x + rx, y + ry), fill=color)
    wear = wear.filter(ImageFilter.GaussianBlur(0.75))
    wear.putalpha(ImageChops.multiply(wear.getchannel("A"), edge))
    return Image.alpha_composite(base, wear)


def draw_outline(base: Image.Image, box: tuple[int, int, int, int], radius: int, color: tuple[int, int, int, int], width: int) -> Image.Image:
    outline = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(outline)
    for i in range(width):
        alpha_scale = 1.0 - (i / max(1, width * 1.6))
        stroke = (color[0], color[1], color[2], int(color[3] * alpha_scale))
        draw.rounded_rectangle(
            (box[0] + i, box[1] + i, box[2] - i, box[3] - i),
            radius=max(1, radius - i),
            outline=stroke,
            width=1,
        )
    return Image.alpha_composite(base, outline)


def make_text_zone_mask(size: tuple[int, int]) -> Image.Image:
    return rect_mask(size, (44, 446, size[0] - 45, size[1] - 48), radius=18, blur=6.0, fill=220)


def make_portrait_zone_mask(size: tuple[int, int]) -> Image.Image:
    return rect_mask(size, (42, 36, size[0] - 43, 426), radius=20, blur=4.0, fill=200)


def make_divider_mask(size: tuple[int, int]) -> Image.Image:
    return rect_mask(size, (56, 420, size[0] - 57, 460), blur=12.0, fill=150)


def make_frame_base(
    size: tuple[int, int],
    fill_top: tuple[int, int, int, int],
    fill_bottom: tuple[int, int, int, int],
    border_color: tuple[int, int, int, int],
    trim_color: tuple[int, int, int, int],
    text_fill: tuple[int, int, int, int],
    portrait_haze: tuple[int, int, int, int],
    seed: int,
) -> tuple[Image.Image, Image.Image]:
    image = blank(size)
    card_mask = rounded_mask(size, radius=24, inset=10)

    base_fill = vertical_gradient(size, fill_top, fill_bottom)
    image = alpha_composite_masked(image, base_fill, card_mask)

    portrait_mask = ImageChops.multiply(make_portrait_zone_mask(size), card_mask)
    portrait_clean = Image.new("RGBA", size, portrait_haze)
    image = alpha_composite_masked(image, portrait_clean, portrait_mask)

    divider_mask = ImageChops.multiply(make_divider_mask(size), card_mask)
    divider = vertical_gradient(size, (0, 0, 0, 40), (80, 68, 58, 0))
    image = alpha_composite_masked(image, divider, divider_mask)

    text_zone_mask = ImageChops.multiply(make_text_zone_mask(size), card_mask)
    text_fill_image = Image.new("RGBA", size, text_fill)
    image = alpha_composite_masked(image, text_fill_image, text_zone_mask)

    side_shadows = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(side_shadows)
    draw.rectangle((0, 0, int(size[0] * 0.14), size[1]), fill=(0, 0, 0, 36))
    draw.rectangle((int(size[0] * 0.86), 0, size[0], size[1]), fill=(0, 0, 0, 36))
    side_shadows = side_shadows.filter(ImageFilter.GaussianBlur(28))
    side_shadows.putalpha(ImageChops.multiply(side_shadows.getchannel("A"), card_mask))
    image = Image.alpha_composite(image, side_shadows)

    image = draw_outline(image, (10, 10, size[0] - 11, size[1] - 11), 24, border_color, width=3)
    image = draw_outline(image, (22, 22, size[0] - 23, size[1] - 23), 18, trim_color, width=2)
    image = draw_outline(image, (34, 34, size[0] - 35, 430), 16, (trim_color[0], trim_color[1], trim_color[2], int(trim_color[3] * 0.55)), width=1)
    image = draw_outline(image, (34, 444, size[0] - 35, size[1] - 36), 16, (trim_color[0], trim_color[1], trim_color[2], int(trim_color[3] * 0.45)), width=1)

    image = add_edge_wear(image, card_mask, seed=seed, count=160, tint=(border_color[0], border_color[1], border_color[2]))
    image = add_grain(image, card_mask, amount=7, alpha=12, seed=seed + 1)
    return image, card_mask


def make_frame_aggression(size: tuple[int, int]) -> Image.Image:
    image, card_mask = make_frame_base(
        size=size,
        fill_top=(60, 31, 28, 245),
        fill_bottom=(27, 17, 17, 252),
        border_color=(178, 112, 86, 132),
        trim_color=(108, 66, 50, 92),
        text_fill=(38, 23, 22, 164),
        portrait_haze=(82, 46, 40, 18),
        seed=4101,
    )
    edge_emphasis = ImageChops.subtract(card_mask.filter(ImageFilter.GaussianBlur(6.0)), card_mask.filter(ImageFilter.GaussianBlur(1.6)))
    edge_emphasis = ImageChops.multiply(edge_emphasis, card_mask)
    sharp_tint = Image.new("RGBA", size, (132, 74, 56, 0))
    sharp_tint.putalpha(edge_emphasis.point(lambda p: int(p * 0.28)))
    image = Image.alpha_composite(image, sharp_tint)
    center_darken = rect_mask(size, (96, 210, size[0] - 97, 538), radius=24, blur=28.0, fill=110)
    shadow = Image.new("RGBA", size, (0, 0, 0, 0))
    shadow.putalpha(ImageChops.multiply(center_darken.point(lambda p: int(p * 0.16)), card_mask))
    return Image.alpha_composite(image, shadow)


def make_frame_defense(size: tuple[int, int]) -> Image.Image:
    image, card_mask = make_frame_base(
        size=size,
        fill_top=(36, 42, 48, 244),
        fill_bottom=(22, 26, 31, 252),
        border_color=(120, 130, 142, 118),
        trim_color=(74, 84, 94, 78),
        text_fill=(28, 32, 38, 156),
        portrait_haze=(50, 60, 70, 14),
        seed=4201,
    )
    stabilizer = vertical_gradient(size, (86, 96, 106, 16), (0, 0, 0, 0))
    return alpha_composite_masked(image, stabilizer, card_mask)


def make_frame_pressure(size: tuple[int, int]) -> Image.Image:
    image, _ = make_frame_base(
        size=size,
        fill_top=(50, 36, 50, 246),
        fill_bottom=(25, 19, 27, 252),
        border_color=(142, 110, 126, 122),
        trim_color=(92, 68, 82, 84),
        text_fill=(33, 24, 34, 164),
        portrait_haze=(74, 54, 74, 16),
        seed=4301,
    )
    depressed_center = rect_mask(size, (90, 176, size[0] - 91, 580), radius=28, blur=40.0, fill=150)
    center_shadow = Image.new("RGBA", size, (0, 0, 0, 0))
    center_shadow.putalpha(depressed_center.point(lambda p: int(p * 0.18)))
    return Image.alpha_composite(image, center_shadow)


def make_frame_bet(size: tuple[int, int]) -> Image.Image:
    image, card_mask = make_frame_base(
        size=size,
        fill_top=(66, 48, 28, 245),
        fill_bottom=(31, 24, 18, 252),
        border_color=(186, 146, 92, 134),
        trim_color=(118, 92, 58, 88),
        text_fill=(40, 30, 22, 160),
        portrait_haze=(98, 72, 42, 18),
        seed=4401,
    )
    sheen_mask = ImageChops.multiply(rect_mask(size, (22, 18, size[0] - 23, 120), radius=18, blur=16.0, fill=120), card_mask)
    sheen = Image.new("RGBA", size, (215, 180, 120, 0))
    sheen.putalpha(sheen_mask.point(lambda p: int(p * 0.20)))
    return Image.alpha_composite(image, sheen)


if __name__ == "__main__":
    raise SystemExit(main())
