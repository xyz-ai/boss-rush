from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parent.parent
ASSETS_ROOT = ROOT / "assets" / "ui"


@dataclass(frozen=True)
class OutputSpec:
    relative_path: str
    size: tuple[int, int]


OUTPUT_SPECS = (
    OutputSpec("buttons/button_primary.png", (320, 96)),
    OutputSpec("panels/panel_dark.png", (512, 256)),
    OutputSpec("badges/badge_hp.png", (160, 64)),
    OutputSpec("broadcast/broadcast_base.png", (720, 180)),
)


PALETTE = {
    "amber": (183, 145, 88, 255),
    "amber_soft": (214, 182, 122, 255),
    "charcoal": (24, 21, 20, 255),
    "charcoal_soft": (38, 33, 31, 255),
    "umber": (61, 46, 36, 255),
    "umber_deep": (34, 25, 21, 255),
    "burgundy": (82, 43, 35, 255),
    "burgundy_deep": (51, 25, 23, 255),
}


def main() -> int:
    target_paths = [ASSETS_ROOT / spec.relative_path for spec in OUTPUT_SPECS]
    existing = [path for path in target_paths if path.exists()]
    if existing:
        print("Refusing to overwrite existing files:", file=sys.stderr)
        for path in existing:
            print(f" - {path}", file=sys.stderr)
        return 1

    for path in target_paths:
        path.parent.mkdir(parents=True, exist_ok=True)

    images = {
        "buttons/button_primary.png": make_button_primary((320, 96)),
        "panels/panel_dark.png": make_panel_dark((512, 256)),
        "badges/badge_hp.png": make_badge_hp((160, 64)),
        "broadcast/broadcast_base.png": make_broadcast_base((720, 180)),
    }

    for spec in OUTPUT_SPECS:
        image = images[spec.relative_path]
        out_path = ASSETS_ROOT / spec.relative_path
        image.save(out_path, "PNG")
        validate_output(out_path, spec.size)

    print("Generated UI batch 01 assets:")
    for spec in OUTPUT_SPECS:
        print(f" - {ASSETS_ROOT / spec.relative_path} ({spec.size[0]}x{spec.size[1]})")
    return 0


def validate_output(path: Path, expected_size: tuple[int, int]) -> None:
    if not path.exists():
        raise RuntimeError(f"Missing output: {path}")
    with Image.open(path) as image:
        if image.size != expected_size:
            raise RuntimeError(f"Unexpected size for {path}: {image.size} != {expected_size}")
        if image.mode != "RGBA":
            raise RuntimeError(f"Unexpected mode for {path}: {image.mode}")
        if image.getchannel("A").getbbox() is None:
            raise RuntimeError(f"Alpha channel is empty for {path}")


def blank(size: tuple[int, int]) -> Image.Image:
    return Image.new("RGBA", size, (0, 0, 0, 0))


def rounded_mask(size: tuple[int, int], radius: int, inset: int = 0) -> Image.Image:
    width, height = size
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle(
        (inset, inset, width - 1 - inset, height - 1 - inset),
        radius=radius,
        fill=255,
    )
    return mask


def horizontal_gradient(size: tuple[int, int], left_rgba: tuple[int, int, int, int], right_rgba: tuple[int, int, int, int]) -> Image.Image:
    width, height = size
    base = Image.new("RGBA", size, (0, 0, 0, 0))
    pixels = base.load()
    for x in range(width):
        t = x / max(1, width - 1)
        rgba = tuple(int(left_rgba[i] * (1.0 - t) + right_rgba[i] * t) for i in range(4))
        for y in range(height):
            pixels[x, y] = rgba
    return base


def vertical_gradient(size: tuple[int, int], top_rgba: tuple[int, int, int, int], bottom_rgba: tuple[int, int, int, int]) -> Image.Image:
    width, height = size
    base = Image.new("RGBA", size, (0, 0, 0, 0))
    pixels = base.load()
    for y in range(height):
        t = y / max(1, height - 1)
        rgba = tuple(int(top_rgba[i] * (1.0 - t) + bottom_rgba[i] * t) for i in range(4))
        for x in range(width):
            pixels[x, y] = rgba
    return base


def alpha_composite_masked(base: Image.Image, layer: Image.Image, mask: Image.Image) -> Image.Image:
    masked = Image.new("RGBA", base.size, (0, 0, 0, 0))
    masked.paste(layer, (0, 0), mask)
    return Image.alpha_composite(base, masked)


def add_grain(base: Image.Image, mask: Image.Image, amount: int, alpha: int, seed: int) -> Image.Image:
    width, height = base.size
    rng = random.Random(seed)
    noise = Image.new("RGBA", base.size, (0, 0, 0, 0))
    pixels = noise.load()
    mask_pixels = mask.load()
    for y in range(height):
        for x in range(width):
            if mask_pixels[x, y] == 0:
                continue
            variation = rng.randint(-amount, amount)
            value = max(0, min(255, 128 + variation))
            pixels[x, y] = (value, value, value, alpha)
    softened = noise.filter(ImageFilter.GaussianBlur(0.35))
    return ImageChops.overlay(base, softened)


def add_inner_glow(base: Image.Image, mask: Image.Image, color: tuple[int, int, int, int], blur_radius: float, intensity: float) -> Image.Image:
    blurred = mask.filter(ImageFilter.GaussianBlur(blur_radius))
    edge = ImageChops.subtract(blurred, mask)
    glow = Image.new("RGBA", base.size, color)
    alpha = edge.point(lambda p: int(max(0, min(255, p * intensity))))
    glow.putalpha(alpha)
    return Image.alpha_composite(base, glow)


def draw_border(base: Image.Image, size: tuple[int, int], radius: int, inset: int, color: tuple[int, int, int, int], width: int) -> Image.Image:
    border = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(border)
    for index in range(width):
        alpha_scale = 1.0 - (index / max(1, width * 1.5))
        stroke = (
            color[0],
            color[1],
            color[2],
            int(color[3] * alpha_scale),
        )
        draw.rounded_rectangle(
            (inset + index, inset + index, size[0] - 1 - inset - index, size[1] - 1 - inset - index),
            radius=max(1, radius - index),
            outline=stroke,
            width=1,
        )
    return Image.alpha_composite(base, border)


def soften_side_shadows(base: Image.Image, mask: Image.Image, alpha: int) -> Image.Image:
    width, height = base.size
    shade = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(shade)
    draw.rectangle((0, 0, width * 0.18, height), fill=(0, 0, 0, alpha))
    draw.rectangle((width * 0.82, 0, width, height), fill=(0, 0, 0, alpha))
    shade = shade.filter(ImageFilter.GaussianBlur(height * 0.08))
    shade.putalpha(ImageChops.multiply(shade.getchannel("A"), mask))
    return Image.alpha_composite(base, shade)


def add_edge_wear(base: Image.Image, mask: Image.Image, seed: int, strength: int) -> Image.Image:
    width, height = base.size
    rng = random.Random(seed)
    wear = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(wear)
    edge_mask = ImageChops.subtract(mask.filter(ImageFilter.GaussianBlur(2.2)), mask.filter(ImageFilter.GaussianBlur(0.6)))
    edge_pixels = edge_mask.load()
    for _ in range(strength):
        x = rng.randint(6, width - 7)
        y = rng.choice((rng.randint(4, 12), rng.randint(height - 12, height - 4)))
        radius_x = rng.randint(3, 9)
        radius_y = rng.randint(1, 3)
        if edge_pixels[x, y] == 0:
            continue
        color = (160 + rng.randint(-12, 10), 127 + rng.randint(-8, 8), 86 + rng.randint(-10, 10), 28 + rng.randint(0, 16))
        draw.ellipse((x - radius_x, y - radius_y, x + radius_x, y + radius_y), fill=color)
    wear = wear.filter(ImageFilter.GaussianBlur(0.7))
    wear.putalpha(ImageChops.multiply(wear.getchannel("A"), edge_mask))
    return Image.alpha_composite(base, wear)


def make_button_primary(size: tuple[int, int]) -> Image.Image:
    image = blank(size)
    mask = rounded_mask(size, radius=26, inset=4)
    base_fill = vertical_gradient(size, (56, 45, 38, 232), (27, 23, 22, 242))
    image = alpha_composite_masked(image, base_fill, mask)

    leather_band = vertical_gradient(size, (74, 57, 46, 68), (42, 31, 28, 36))
    band_mask = Image.new("L", size, 0)
    ImageDraw.Draw(band_mask).rounded_rectangle((18, 18, size[0] - 19, size[1] - 19), radius=18, fill=225)
    image = alpha_composite_masked(image, leather_band, band_mask)

    center_flat = Image.new("RGBA", size, (74, 61, 52, 24))
    center_mask = Image.new("L", size, 0)
    ImageDraw.Draw(center_mask).rounded_rectangle((84, 26, size[0] - 85, size[1] - 27), radius=12, fill=150)
    image = alpha_composite_masked(image, center_flat, center_mask)

    highlight = Image.new("RGBA", size, (221, 197, 156, 0))
    highlight_mask = Image.new("L", size, 0)
    ImageDraw.Draw(highlight_mask).rounded_rectangle((20, 10, size[0] - 21, 38), radius=16, fill=78)
    highlight_mask = highlight_mask.filter(ImageFilter.GaussianBlur(8))
    highlight.putalpha(highlight_mask)
    image = Image.alpha_composite(image, highlight)

    image = soften_side_shadows(image, mask, alpha=46)
    image = add_inner_glow(image, mask, (184, 146, 90, 255), blur_radius=6.0, intensity=0.45)
    image = draw_border(image, size, radius=26, inset=4, color=(196, 159, 97, 124), width=3)
    image = draw_border(image, size, radius=23, inset=8, color=(112, 83, 48, 84), width=1)
    image = add_edge_wear(image, mask, seed=101, strength=42)
    return add_grain(image, mask, amount=10, alpha=18, seed=77)


def make_panel_dark(size: tuple[int, int]) -> Image.Image:
    image = blank(size)
    mask = rounded_mask(size, radius=22, inset=6)

    fill = vertical_gradient(size, (30, 27, 27, 186), (16, 15, 16, 204))
    image = alpha_composite_masked(image, fill, mask)

    vignette = horizontal_gradient(size, (0, 0, 0, 22), (0, 0, 0, 0))
    vignette = Image.blend(vignette, vignette.transpose(Image.Transpose.FLIP_LEFT_RIGHT), 0.5)
    image = alpha_composite_masked(image, vignette, mask)

    center_clear = Image.new("RGBA", size, (52, 44, 40, 18))
    center_mask = Image.new("L", size, 0)
    ImageDraw.Draw(center_mask).rounded_rectangle((86, 50, size[0] - 87, size[1] - 51), radius=12, fill=92)
    center_mask = center_mask.filter(ImageFilter.GaussianBlur(14))
    image = alpha_composite_masked(image, center_clear, center_mask)

    top_haze = Image.new("RGBA", size, (204, 176, 128, 0))
    top_haze_mask = Image.new("L", size, 0)
    ImageDraw.Draw(top_haze_mask).rounded_rectangle((24, 14, size[0] - 25, 40), radius=10, fill=38)
    top_haze_mask = top_haze_mask.filter(ImageFilter.GaussianBlur(10))
    top_haze.putalpha(top_haze_mask)
    image = Image.alpha_composite(image, top_haze)

    image = draw_border(image, size, radius=22, inset=6, color=(189, 156, 103, 74), width=2)
    image = draw_border(image, size, radius=18, inset=10, color=(85, 72, 58, 62), width=1)
    return add_grain(image, mask, amount=6, alpha=12, seed=203)


def make_badge_hp(size: tuple[int, int]) -> Image.Image:
    image = blank(size)
    mask = rounded_mask(size, radius=30, inset=3)

    base = vertical_gradient(size, (92, 50, 42, 240), (54, 29, 27, 248))
    image = alpha_composite_masked(image, base, mask)

    inner_band = horizontal_gradient(size, (110, 63, 48, 44), (73, 39, 34, 18))
    image = alpha_composite_masked(image, inner_band, mask)

    side_shade = Image.new("RGBA", size, (0, 0, 0, 0))
    side_draw = ImageDraw.Draw(side_shade)
    side_draw.ellipse((2, 6, 44, size[1] - 7), fill=(0, 0, 0, 64))
    side_draw.ellipse((size[0] - 45, 6, size[0] - 3, size[1] - 7), fill=(0, 0, 0, 54))
    side_shade = side_shade.filter(ImageFilter.GaussianBlur(8))
    side_shade.putalpha(ImageChops.multiply(side_shade.getchannel("A"), mask))
    image = Image.alpha_composite(image, side_shade)

    gloss = Image.new("RGBA", size, (225, 204, 182, 0))
    gloss_mask = Image.new("L", size, 0)
    ImageDraw.Draw(gloss_mask).rounded_rectangle((18, 8, size[0] - 19, 24), radius=10, fill=84)
    gloss_mask = gloss_mask.filter(ImageFilter.GaussianBlur(6))
    gloss.putalpha(gloss_mask)
    image = Image.alpha_composite(image, gloss)

    clean_center = Image.new("RGBA", size, (121, 76, 61, 18))
    clean_center_mask = Image.new("L", size, 0)
    ImageDraw.Draw(clean_center_mask).rounded_rectangle((48, 16, size[0] - 49, size[1] - 17), radius=10, fill=110)
    image = alpha_composite_masked(image, clean_center, clean_center_mask)

    image = add_inner_glow(image, mask, (190, 153, 98, 255), blur_radius=4.5, intensity=0.4)
    image = draw_border(image, size, radius=30, inset=3, color=(201, 164, 102, 146), width=3)
    return add_grain(image, mask, amount=5, alpha=10, seed=309)


def make_broadcast_base(size: tuple[int, int]) -> Image.Image:
    image = blank(size)
    mask = rounded_mask(size, radius=28, inset=5)

    fill = vertical_gradient(size, (26, 23, 22, 182), (12, 12, 13, 210))
    image = alpha_composite_masked(image, fill, mask)

    side_weight = horizontal_gradient(size, (52, 42, 34, 36), (22, 19, 18, 0))
    side_weight = Image.blend(side_weight, side_weight.transpose(Image.Transpose.FLIP_LEFT_RIGHT), 0.5)
    image = alpha_composite_masked(image, side_weight, mask)

    edge_glow = Image.new("RGBA", size, (187, 148, 91, 0))
    edge_glow_mask = ImageChops.subtract(mask.filter(ImageFilter.GaussianBlur(10)), mask.filter(ImageFilter.GaussianBlur(2)))
    edge_glow.putalpha(edge_glow_mask.point(lambda p: int(p * 0.72)))
    image = Image.alpha_composite(image, edge_glow)

    top_sheen = Image.new("RGBA", size, (214, 188, 136, 0))
    top_sheen_mask = Image.new("L", size, 0)
    ImageDraw.Draw(top_sheen_mask).rounded_rectangle((28, 16, size[0] - 29, 42), radius=14, fill=52)
    top_sheen_mask = top_sheen_mask.filter(ImageFilter.GaussianBlur(10))
    top_sheen.putalpha(top_sheen_mask)
    image = Image.alpha_composite(image, top_sheen)

    image = draw_border(image, size, radius=28, inset=5, color=(199, 160, 99, 108), width=2)
    image = draw_border(image, size, radius=24, inset=9, color=(98, 78, 52, 72), width=1)
    return add_grain(image, mask, amount=5, alpha=10, seed=407)


if __name__ == "__main__":
    raise SystemExit(main())
