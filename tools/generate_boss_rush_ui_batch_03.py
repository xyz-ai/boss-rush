from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import sys

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter


ROOT = Path(__file__).resolve().parent.parent
BADGES_DIR = ROOT / "assets" / "ui" / "badges"
SOURCE_PATH = BADGES_DIR / "badge_hp.png"
EXPECTED_SIZE = (160, 64)


@dataclass(frozen=True)
class OutputSpec:
    filename: str
    meaning: str


OUTPUT_SPECS = (
    OutputSpec("badge_bod.png", "bod"),
    OutputSpec("badge_spr.png", "spr"),
    OutputSpec("badge_rep.png", "rep"),
    OutputSpec("badge_life.png", "life"),
)


def main() -> int:
    source = load_source()
    output_paths = [BADGES_DIR / spec.filename for spec in OUTPUT_SPECS]
    existing = [path for path in output_paths if path.exists()]
    if existing:
        print("Refusing to overwrite existing files:", file=sys.stderr)
        for path in existing:
            print(f" - {path}", file=sys.stderr)
        return 1

    variants = {
        "badge_bod.png": make_bod(source),
        "badge_spr.png": make_spr(source),
        "badge_rep.png": make_rep(source),
        "badge_life.png": make_life(source),
    }

    for spec in OUTPUT_SPECS:
        out_path = BADGES_DIR / spec.filename
        variants[spec.filename].save(out_path, "PNG")
        validate_output(out_path)

    print("Generated UI batch 03 assets:")
    for spec in OUTPUT_SPECS:
        print(f" - {BADGES_DIR / spec.filename} ({EXPECTED_SIZE[0]}x{EXPECTED_SIZE[1]})")
    return 0


def load_source() -> Image.Image:
    if not SOURCE_PATH.exists():
        raise FileNotFoundError(f"Missing badge source: {SOURCE_PATH}")
    image = Image.open(SOURCE_PATH).convert("RGBA")
    if image.size != EXPECTED_SIZE:
        raise RuntimeError(f"Unexpected badge source size: {image.size} != {EXPECTED_SIZE}")
    return image


def validate_output(path: Path) -> None:
    if not path.exists():
        raise RuntimeError(f"Missing output: {path}")
    with Image.open(path) as image:
        if image.size != EXPECTED_SIZE:
            raise RuntimeError(f"Unexpected output size for {path}: {image.size}")
        if image.mode != "RGBA":
            raise RuntimeError(f"Unexpected mode for {path}: {image.mode}")
        if image.getchannel("A").getbbox() is None:
            raise RuntimeError(f"Alpha channel is empty for {path}")


def badge_masks(alpha: Image.Image) -> tuple[Image.Image, Image.Image, Image.Image, Image.Image]:
    body_mask = alpha.point(lambda p: 255 if p > 0 else 0)
    outer_blur = body_mask.filter(ImageFilter.GaussianBlur(4.2))
    inner_blur = body_mask.filter(ImageFilter.GaussianBlur(0.9))
    edge_mask = ImageChops.subtract(outer_blur, inner_blur)

    center_mask = Image.new("L", alpha.size, 0)
    draw = ImageDraw.Draw(center_mask)
    draw.rounded_rectangle((48, 16, alpha.size[0] - 49, alpha.size[1] - 17), radius=10, fill=180)
    center_mask = center_mask.filter(ImageFilter.GaussianBlur(6))
    center_mask = ImageChops.multiply(center_mask, body_mask)

    top_highlight = Image.new("L", alpha.size, 0)
    ImageDraw.Draw(top_highlight).rounded_rectangle((18, 8, alpha.size[0] - 19, 24), radius=10, fill=120)
    top_highlight = top_highlight.filter(ImageFilter.GaussianBlur(5.5))
    top_highlight = ImageChops.multiply(top_highlight, body_mask)
    return body_mask, edge_mask, center_mask, top_highlight


def preserve_alpha(image: Image.Image, alpha: Image.Image) -> Image.Image:
    result = image.convert("RGBA")
    result.putalpha(alpha)
    return result


def apply_enhancers(
    image: Image.Image,
    brightness: float = 1.0,
    contrast: float = 1.0,
    color: float = 1.0,
    sharpness: float = 1.0,
) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    rgb = rgba.convert("RGB")
    rgb = ImageEnhance.Brightness(rgb).enhance(brightness)
    rgb = ImageEnhance.Contrast(rgb).enhance(contrast)
    rgb = ImageEnhance.Color(rgb).enhance(color)
    rgb = ImageEnhance.Sharpness(rgb).enhance(sharpness)
    result = rgb.convert("RGBA")
    result.putalpha(alpha)
    return result


def tint_masked(image: Image.Image, mask: Image.Image, color: tuple[int, int, int], strength: float) -> Image.Image:
    overlay = Image.new("RGBA", image.size, (color[0], color[1], color[2], 255))
    alpha = mask.point(lambda p: int(max(0, min(255, p * strength))))
    overlay.putalpha(alpha)
    return Image.alpha_composite(image, overlay)


def darken_masked(image: Image.Image, mask: Image.Image, strength: float) -> Image.Image:
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 255))
    alpha = mask.point(lambda p: int(max(0, min(255, p * strength))))
    overlay.putalpha(alpha)
    return Image.alpha_composite(image, overlay)


def brighten_masked(image: Image.Image, mask: Image.Image, color: tuple[int, int, int], strength: float) -> Image.Image:
    overlay = Image.new("RGBA", image.size, (color[0], color[1], color[2], 255))
    alpha = mask.point(lambda p: int(max(0, min(255, p * strength))))
    overlay.putalpha(alpha)
    return Image.alpha_composite(image, overlay)


def side_weight_mask(size: tuple[int, int], left_alpha: int, right_alpha: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse((0, 5, 44, size[1] - 6), fill=left_alpha)
    draw.ellipse((size[0] - 45, 5, size[0] - 1, size[1] - 6), fill=right_alpha)
    return mask.filter(ImageFilter.GaussianBlur(7.5))


def top_haze_mask(size: tuple[int, int], fill: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((20, 8, size[0] - 21, 22), radius=10, fill=fill)
    return mask.filter(ImageFilter.GaussianBlur(7.0))


def horizontal_drift(size: tuple[int, int], left: tuple[int, int, int], right: tuple[int, int, int], alpha_strength: int) -> Image.Image:
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    pixels = image.load()
    for x in range(size[0]):
        t = x / max(1, size[0] - 1)
        color = tuple(int(left[i] * (1.0 - t) + right[i] * t) for i in range(3))
        for y in range(size[1]):
            pixels[x, y] = (color[0], color[1], color[2], alpha_strength)
    return image


def make_bod(source: Image.Image) -> Image.Image:
    alpha = source.getchannel("A")
    body_mask, edge_mask, center_mask, top_highlight = badge_masks(alpha)

    result = apply_enhancers(source, brightness=0.95, contrast=1.10, color=1.06, sharpness=1.02)
    result = tint_masked(result, body_mask, (100, 44, 38), 0.24)
    weight_mask = ImageChops.multiply(side_weight_mask(result.size, 78, 68), body_mask)
    result = darken_masked(result, weight_mask, 0.28)
    result = darken_masked(result, top_highlight, 0.10)
    result = brighten_masked(result, center_mask, (130, 74, 64), 0.05)
    result = tint_masked(result, edge_mask, (162, 110, 82), 0.08)
    return preserve_alpha(result, alpha)


def make_spr(source: Image.Image) -> Image.Image:
    alpha = source.getchannel("A")
    body_mask, edge_mask, center_mask, top_highlight = badge_masks(alpha)

    result = apply_enhancers(source, brightness=0.94, contrast=0.90, color=0.58, sharpness=0.98)
    result = tint_masked(result, body_mask, (47, 72, 82), 0.34)
    mist_mask = ImageChops.multiply(top_haze_mask(result.size, 112), body_mask)
    result = brighten_masked(result, mist_mask, (120, 145, 154), 0.12)
    result = darken_masked(result, top_highlight, 0.18)
    result = brighten_masked(result, center_mask, (82, 102, 108), 0.04)
    result = tint_masked(result, edge_mask, (112, 126, 131), 0.05)
    return preserve_alpha(result, alpha)


def make_rep(source: Image.Image) -> Image.Image:
    alpha = source.getchannel("A")
    body_mask, edge_mask, center_mask, top_highlight = badge_masks(alpha)

    result = apply_enhancers(source, brightness=1.00, contrast=1.02, color=0.92, sharpness=1.04)
    result = tint_masked(result, body_mask, (132, 104, 58), 0.24)
    result = brighten_masked(result, top_highlight, (208, 178, 122), 0.16)
    result = brighten_masked(result, edge_mask, (194, 162, 106), 0.18)
    result = darken_masked(result, side_weight_mask(result.size, 38, 34), 0.10)
    result = brighten_masked(result, center_mask, (150, 120, 76), 0.05)
    return preserve_alpha(result, alpha)


def make_life(source: Image.Image) -> Image.Image:
    alpha = source.getchannel("A")
    body_mask, edge_mask, center_mask, top_highlight = badge_masks(alpha)

    result = apply_enhancers(source, brightness=1.04, contrast=1.00, color=1.02, sharpness=1.0)
    result = tint_masked(result, body_mask, (138, 82, 34), 0.22)
    drift = horizontal_drift(result.size, (162, 88, 34), (124, 78, 46), 62)
    drift.putalpha(ImageChops.multiply(drift.getchannel("A"), body_mask))
    result = Image.alpha_composite(result, drift)
    result = brighten_masked(result, top_highlight, (220, 174, 112), 0.08)
    result = brighten_masked(result, center_mask, (164, 106, 52), 0.06)
    result = tint_masked(result, edge_mask, (184, 138, 82), 0.08)
    return preserve_alpha(result, alpha)


if __name__ == "__main__":
    raise SystemExit(main())
