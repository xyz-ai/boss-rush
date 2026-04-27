from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parent.parent
OVERLAYS_DIR = ROOT / "assets" / "battle" / "cards" / "overlays"
SIZE = (512, 768)


@dataclass(frozen=True)
class OutputSpec:
    filename: str
    role: str


OUTPUT_SPECS = (
    OutputSpec("overlay_hover.png", "hover"),
    OutputSpec("overlay_selected.png", "selected"),
    OutputSpec("overlay_used.png", "used"),
    OutputSpec("overlay_locked.png", "locked"),
)


def main() -> int:
    output_paths = [OVERLAYS_DIR / spec.filename for spec in OUTPUT_SPECS]
    existing = [path for path in output_paths if path.exists()]
    if existing:
        print("Refusing to overwrite existing files:", file=sys.stderr)
        for path in existing:
            print(f" - {path}", file=sys.stderr)
        return 1

    images = {
        "overlay_hover.png": make_overlay_hover(SIZE),
        "overlay_selected.png": make_overlay_selected(SIZE),
        "overlay_used.png": make_overlay_used(SIZE),
        "overlay_locked.png": make_overlay_locked(SIZE),
    }

    for spec in OUTPUT_SPECS:
        out_path = OVERLAYS_DIR / spec.filename
        images[spec.filename].save(out_path, "PNG")
        validate_output(out_path)

    print("Generated UI batch 05 assets:")
    for spec in OUTPUT_SPECS:
        print(f" - {OVERLAYS_DIR / spec.filename} ({SIZE[0]}x{SIZE[1]})")
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


def alpha_composite_masked(base: Image.Image, layer: Image.Image, mask: Image.Image) -> Image.Image:
    masked = Image.new("RGBA", base.size, (0, 0, 0, 0))
    masked.paste(layer, (0, 0), mask)
    return Image.alpha_composite(base, masked)


def build_masks(size: tuple[int, int]) -> dict[str, Image.Image]:
    card_mask = rounded_mask(size, radius=24, inset=10)
    portrait_mask = ImageChops.multiply(rect_mask(size, (42, 36, size[0] - 43, 426), radius=20, blur=5.0, fill=165), card_mask)
    text_mask = ImageChops.multiply(rect_mask(size, (40, 444, size[0] - 41, size[1] - 40), radius=18, blur=6.0, fill=150), card_mask)
    center_clear = ImageChops.multiply(rect_mask(size, (94, 118, size[0] - 95, 620), radius=28, blur=28.0, fill=120), card_mask)
    top_band = ImageChops.multiply(rect_mask(size, (30, 22, size[0] - 31, 132), radius=18, blur=20.0, fill=120), card_mask)
    edge_mask = ImageChops.multiply(
        ImageChops.subtract(card_mask.filter(ImageFilter.GaussianBlur(8.0)), card_mask.filter(ImageFilter.GaussianBlur(2.2))),
        card_mask,
    )
    global_soft = ImageChops.multiply(rect_mask(size, (18, 18, size[0] - 19, size[1] - 19), radius=22, blur=12.0, fill=170), card_mask)
    return {
        "card": card_mask,
        "portrait": portrait_mask,
        "text": text_mask,
        "center_clear": center_clear,
        "top_band": top_band,
        "edge": edge_mask,
        "global_soft": global_soft,
    }


def make_overlay_hover(size: tuple[int, int]) -> Image.Image:
    masks = build_masks(size)
    image = blank(size)

    edge_glow = Image.new("RGBA", size, (205, 168, 112, 0))
    edge_glow.putalpha(masks["edge"].point(lambda p: int(p * 0.07)))
    image = Image.alpha_composite(image, edge_glow)

    soft_lift = vertical_gradient(size, (236, 224, 196, 5), (255, 255, 255, 0))
    image = alpha_composite_masked(image, soft_lift, masks["global_soft"])

    return image


def make_overlay_selected(size: tuple[int, int]) -> Image.Image:
    masks = build_masks(size)
    image = blank(size)

    amber_wash = vertical_gradient(size, (214, 172, 98, 24), (160, 112, 58, 14))
    image = alpha_composite_masked(image, amber_wash, masks["card"])

    inner_glow = Image.new("RGBA", size, (224, 184, 118, 0))
    inner_glow.putalpha(masks["edge"].point(lambda p: int(p * 0.16)))
    image = Image.alpha_composite(image, inner_glow)

    text_relief = Image.new("RGBA", size, (0, 0, 0, 0))
    text_relief.putalpha(masks["text"].point(lambda p: int(p * 0.03)))
    image = Image.alpha_composite(image, text_relief)

    portrait_soft = Image.new("RGBA", size, (240, 214, 164, 0))
    portrait_soft.putalpha(masks["portrait"].point(lambda p: int(p * 0.03)))
    return Image.alpha_composite(image, portrait_soft)


def make_overlay_used(size: tuple[int, int]) -> Image.Image:
    masks = build_masks(size)
    image = blank(size)

    gray_veil = vertical_gradient(size, (126, 126, 126, 26), (92, 92, 92, 38))
    image = alpha_composite_masked(image, gray_veil, masks["card"])

    contrast_fade = Image.new("RGBA", size, (54, 54, 54, 0))
    contrast_fade.putalpha(masks["global_soft"].point(lambda p: int(p * 0.06)))
    image = Image.alpha_composite(image, contrast_fade)

    edge_soften = Image.new("RGBA", size, (108, 108, 108, 0))
    edge_soften.putalpha(masks["edge"].point(lambda p: int(p * 0.04)))
    image = Image.alpha_composite(image, edge_soften)

    return image


def make_overlay_locked(size: tuple[int, int]) -> Image.Image:
    masks = build_masks(size)
    image = blank(size)

    cool_shadow = vertical_gradient(size, (46, 54, 68, 34), (24, 30, 40, 58))
    image = alpha_composite_masked(image, cool_shadow, masks["card"])

    top_pressure = Image.new("RGBA", size, (36, 44, 58, 0))
    top_pressure.putalpha(masks["top_band"].point(lambda p: int(p * 0.12)))
    image = Image.alpha_composite(image, top_pressure)

    edge_weight = Image.new("RGBA", size, (18, 24, 34, 0))
    edge_weight.putalpha(masks["edge"].point(lambda p: int(p * 0.10)))
    image = Image.alpha_composite(image, edge_weight)

    text_relief = Image.new("RGBA", size, (112, 118, 126, 0))
    text_relief.putalpha(masks["text"].point(lambda p: int(p * 0.02)))
    return Image.alpha_composite(image, text_relief)


if __name__ == "__main__":
    raise SystemExit(main())
