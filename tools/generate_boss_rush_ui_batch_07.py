from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
import subprocess
import sys

from PIL import Image


ROOT = Path(__file__).resolve().parent.parent
OUTPUT_DIR = ROOT / "assets" / "battle" / "boss"
REMOVE_BG_SCRIPT = Path.home() / ".codex" / "skills" / ".system" / "imagegen" / "scripts" / "remove_chroma_key.py"


@dataclass(frozen=True)
class OutputSpec:
    key: str
    filename: str


OUTPUT_SPECS = (
    OutputSpec("idle", "boss_default_idle.png"),
    OutputSpec("pressure", "boss_default_pressure.png"),
    OutputSpec("hit", "boss_default_hit.png"),
    OutputSpec("low", "boss_default_low.png"),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Post-process Boss Rush batch 07 boss portraits.")
    parser.add_argument("--idle", required=True, help="Path to the idle chroma-key source image.")
    parser.add_argument("--pressure", required=True, help="Path to the pressure chroma-key source image.")
    parser.add_argument("--hit", required=True, help="Path to the hit chroma-key source image.")
    parser.add_argument("--low", required=True, help="Path to the low-state chroma-key source image.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    sources = {
        "idle": Path(args.idle).expanduser().resolve(),
        "pressure": Path(args.pressure).expanduser().resolve(),
        "hit": Path(args.hit).expanduser().resolve(),
        "low": Path(args.low).expanduser().resolve(),
    }

    if not REMOVE_BG_SCRIPT.exists():
        raise FileNotFoundError(f"Missing chroma-key helper: {REMOVE_BG_SCRIPT}")

    existing = [OUTPUT_DIR / spec.filename for spec in OUTPUT_SPECS if (OUTPUT_DIR / spec.filename).exists()]
    if existing:
        print("Refusing to overwrite existing files:", file=sys.stderr)
        for path in existing:
            print(f" - {path}", file=sys.stderr)
        return 1

    for spec in OUTPUT_SPECS:
        source = sources[spec.key]
        if not source.exists():
            raise FileNotFoundError(f"Missing source image for {spec.key}: {source}")
        out_path = OUTPUT_DIR / spec.filename
        run_remove_chroma(source, out_path)
        validate_output(out_path)

    print("Generated UI batch 07 assets:")
    for spec in OUTPUT_SPECS:
        print(f" - {OUTPUT_DIR / spec.filename}")
    return 0


def run_remove_chroma(source: Path, out_path: Path) -> None:
    command = [
        sys.executable,
        str(REMOVE_BG_SCRIPT),
        "--input",
        str(source),
        "--out",
        str(out_path),
        "--auto-key",
        "border",
        "--soft-matte",
        "--transparent-threshold",
        "12",
        "--opaque-threshold",
        "220",
        "--despill",
        "--edge-contract",
        "1",
    ]
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(
            f"Background removal failed for {source}\nstdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )


def validate_output(path: Path) -> None:
    if not path.exists():
        raise RuntimeError(f"Missing output: {path}")

    with Image.open(path) as image:
        if image.mode != "RGBA":
            raise RuntimeError(f"Unexpected image mode for {path}: {image.mode}")
        alpha = image.getchannel("A")
        top_corners = [
            alpha.getpixel((0, 0)),
            alpha.getpixel((image.width - 1, 0)),
        ]
        if any(value != 0 for value in top_corners):
            raise RuntimeError(f"Top-corner transparency check failed for {path}: {top_corners}")

        bbox = alpha.getbbox()
        if bbox is None:
            raise RuntimeError(f"Subject alpha is empty for {path}")

        rgb = image.convert("RGB")
        fringe_hits = 0
        sample_step = max(1, image.width // 192)
        for y in range(0, image.height, sample_step):
            for x in range(0, image.width, sample_step):
                a = alpha.getpixel((x, y))
                if 0 < a < 200:
                    r, g, b = rgb.getpixel((x, y))
                    if g > r + 45 and g > b + 45:
                        fringe_hits += 1
        if fringe_hits > 12:
            raise RuntimeError(f"Green fringe check failed for {path}: {fringe_hits} suspicious pixels")


if __name__ == "__main__":
    raise SystemExit(main())
