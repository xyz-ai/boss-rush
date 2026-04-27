from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import sys

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter


ROOT = Path(__file__).resolve().parent.parent
BUTTONS_DIR = ROOT / "assets" / "ui" / "buttons"
PRIMARY_PATH = BUTTONS_DIR / "button_primary.png"


@dataclass(frozen=True)
class OutputSpec:
    filename: str
    description: str


OUTPUT_SPECS = (
    OutputSpec("button_hover.png", "hover"),
    OutputSpec("button_pressed.png", "pressed"),
    OutputSpec("button_disabled.png", "disabled"),
    OutputSpec("button_secondary.png", "secondary"),
)

EXPECTED_SIZE = (320, 96)


def main() -> int:
    source = load_primary()

    output_paths = [BUTTONS_DIR / spec.filename for spec in OUTPUT_SPECS]
    existing = [path for path in output_paths if path.exists()]
    if existing:
        print("Refusing to overwrite existing files:", file=sys.stderr)
        for path in existing:
            print(f" - {path}", file=sys.stderr)
        return 1

    variants = {
        "button_hover.png": make_hover(source),
        "button_pressed.png": make_pressed(source),
        "button_disabled.png": make_disabled(source),
        "button_secondary.png": make_secondary(source),
    }

    for spec in OUTPUT_SPECS:
        out_path = BUTTONS_DIR / spec.filename
        variants[spec.filename].save(out_path, "PNG")
        validate_output(out_path)

    print("Generated UI batch 02 assets:")
    for spec in OUTPUT_SPECS:
        print(f" - {BUTTONS_DIR / spec.filename} ({EXPECTED_SIZE[0]}x{EXPECTED_SIZE[1]})")
    return 0


def load_primary() -> Image.Image:
    if not PRIMARY_PATH.exists():
        raise FileNotFoundError(f"Missing primary button source: {PRIMARY_PATH}")
    image = Image.open(PRIMARY_PATH).convert("RGBA")
    if image.size != EXPECTED_SIZE:
        raise RuntimeError(f"Unexpected primary button size: {image.size} != {EXPECTED_SIZE}")
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


def button_masks(alpha: Image.Image) -> tuple[Image.Image, Image.Image, Image.Image]:
    body_mask = alpha.point(lambda p: 255 if p > 0 else 0)
    outer_blur = body_mask.filter(ImageFilter.GaussianBlur(5.5))
    inner_blur = body_mask.filter(ImageFilter.GaussianBlur(1.2))
    edge_mask = ImageChops.subtract(outer_blur, inner_blur)

    center_mask = Image.new("L", alpha.size, 0)
    draw = ImageDraw.Draw(center_mask)
    draw.rounded_rectangle((84, 26, alpha.size[0] - 85, alpha.size[1] - 27), radius=12, fill=185)
    center_mask = center_mask.filter(ImageFilter.GaussianBlur(10))
    center_mask = ImageChops.multiply(center_mask, body_mask)
    return body_mask, edge_mask, center_mask


def preserve_alpha(base: Image.Image, source_alpha: Image.Image) -> Image.Image:
    result = base.convert("RGBA")
    result.putalpha(source_alpha)
    return result


def apply_enhancers(
    image: Image.Image,
    brightness: float = 1.0,
    contrast: float = 1.0,
    color: float = 1.0,
    sharpness: float = 1.0,
) -> Image.Image:
    result = image.convert("RGBA")
    alpha = result.getchannel("A")
    rgb = result.convert("RGB")
    rgb = ImageEnhance.Brightness(rgb).enhance(brightness)
    rgb = ImageEnhance.Contrast(rgb).enhance(contrast)
    rgb = ImageEnhance.Color(rgb).enhance(color)
    rgb = ImageEnhance.Sharpness(rgb).enhance(sharpness)
    result = rgb.convert("RGBA")
    result.putalpha(alpha)
    return result


def tint_masked(image: Image.Image, mask: Image.Image, color: tuple[int, int, int, int], strength: float) -> Image.Image:
    overlay = Image.new("RGBA", image.size, color)
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


def top_highlight_mask(size: tuple[int, int], alpha: Image.Image, top: int, bottom: int, radius: int, blur: float, fill: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((20, top, size[0] - 21, bottom), radius=radius, fill=fill)
    mask = mask.filter(ImageFilter.GaussianBlur(blur))
    return ImageChops.multiply(mask, alpha.point(lambda p: 255 if p > 0 else 0))


def vertical_shadow_mask(size: tuple[int, int], top_alpha: int, bottom_alpha: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rectangle((0, 0, size[0], size[1] * 0.32), fill=top_alpha)
    draw.rectangle((0, size[1] * 0.68, size[0], size[1]), fill=bottom_alpha)
    return mask.filter(ImageFilter.GaussianBlur(10))


def make_hover(source: Image.Image) -> Image.Image:
    alpha = source.getchannel("A")
    body_mask, edge_mask, center_mask = button_masks(alpha)

    result = apply_enhancers(source, brightness=1.11, contrast=1.08, color=1.05, sharpness=1.04)
    result = tint_masked(result, edge_mask, (215, 180, 116, 255), 0.42)
    result = brighten_masked(result, center_mask, (154, 122, 84), 0.10)
    highlight = top_highlight_mask(result.size, alpha, 8, 38, 16, 8.0, 88)
    result = brighten_masked(result, highlight, (236, 214, 176), 0.34)
    glow_mask = edge_mask.filter(ImageFilter.GaussianBlur(2.0))
    result = tint_masked(result, glow_mask, (196, 158, 98, 255), 0.18)
    return preserve_alpha(result, alpha)


def make_pressed(source: Image.Image) -> Image.Image:
    alpha = source.getchannel("A")
    body_mask, edge_mask, center_mask = button_masks(alpha)

    result = apply_enhancers(source, brightness=0.88, contrast=1.05, color=0.96, sharpness=1.0)
    highlight_reduce = top_highlight_mask(result.size, alpha, 6, 34, 16, 8.0, 124)
    result = darken_masked(result, highlight_reduce, 0.32)

    shadow_mask = vertical_shadow_mask(result.size, top_alpha=72, bottom_alpha=92)
    shadow_mask = ImageChops.multiply(shadow_mask, body_mask)
    result = darken_masked(result, shadow_mask, 0.34)

    edge_tighten = ImageChops.multiply(edge_mask.filter(ImageFilter.GaussianBlur(0.8)), body_mask)
    result = darken_masked(result, edge_tighten, 0.18)
    result = brighten_masked(result, center_mask, (116, 92, 68), 0.05)
    return preserve_alpha(result, alpha)


def make_disabled(source: Image.Image) -> Image.Image:
    alpha = source.getchannel("A")
    body_mask, edge_mask, _center_mask = button_masks(alpha)

    result = apply_enhancers(source, brightness=0.93, contrast=0.82, color=0.18, sharpness=0.96)
    result = tint_masked(result, body_mask, (74, 79, 84, 255), 0.16)
    result = darken_masked(result, edge_mask, 0.08)

    suppress_highlight = top_highlight_mask(result.size, alpha, 6, 34, 16, 8.0, 160)
    result = darken_masked(result, suppress_highlight, 0.36)

    border_soften = edge_mask.filter(ImageFilter.GaussianBlur(1.5))
    result = tint_masked(result, border_soften, (96, 94, 92, 255), 0.14)
    return preserve_alpha(result, alpha)


def make_secondary(source: Image.Image) -> Image.Image:
    alpha = source.getchannel("A")
    body_mask, edge_mask, center_mask = button_masks(alpha)

    result = apply_enhancers(source, brightness=0.95, contrast=0.96, color=0.72, sharpness=1.0)
    result = tint_masked(result, body_mask, (52, 43, 37, 255), 0.16)
    result = darken_masked(result, edge_mask, 0.06)

    reduce_sheen = top_highlight_mask(result.size, alpha, 7, 35, 16, 8.0, 120)
    result = darken_masked(result, reduce_sheen, 0.16)
    result = tint_masked(result, edge_mask, (152, 120, 78, 255), 0.14)
    result = brighten_masked(result, center_mask, (103, 82, 65), 0.04)
    return preserve_alpha(result, alpha)


if __name__ == "__main__":
    raise SystemExit(main())
