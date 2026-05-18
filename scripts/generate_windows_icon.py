from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


ICON_SIZES = [16, 20, 24, 32, 40, 48, 64, 128, 256]


def _trim_bottom_text(alpha: Image.Image, bbox: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    left, top, right, bottom = bbox
    width = right - left
    height = bottom - top
    search_start = top + int(height * 0.65)
    zero_run = 0

    for y in range(search_start, bottom):
        row_has_alpha = False
        for x in range(left, right):
            if alpha.getpixel((x, y)) > 0:
                row_has_alpha = True
                break
        if row_has_alpha:
            zero_run = 0
            continue

        zero_run += 1
        if zero_run >= 20:
            cropped_bottom = y - zero_run + 1
            if cropped_bottom > top + int(height * 0.6):
                return left, top, right, cropped_bottom

    return bbox


def _build_square_canvas(image: Image.Image, padding_ratio: float = 0.1) -> Image.Image:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("The source image is fully transparent.")

    bbox = _trim_bottom_text(image.getchannel("A"), bbox)
    cropped = image.crop(bbox)
    cropped_width, cropped_height = cropped.size

    subject_size = max(cropped_width, cropped_height)
    padding = max(24, int(subject_size * padding_ratio))
    canvas_size = subject_size + padding * 2

    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    offset_x = (canvas_size - cropped_width) // 2
    offset_y = (canvas_size - cropped_height) // 2
    canvas.alpha_composite(cropped, (offset_x, offset_y))
    return canvas


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate a Windows ICO from a PNG logo.")
    parser.add_argument("source", type=Path)
    parser.add_argument("icon_output", type=Path)
    parser.add_argument("--preview-output", type=Path)
    args = parser.parse_args()

    source_image = Image.open(args.source).convert("RGBA")
    square_canvas = _build_square_canvas(source_image)

    args.icon_output.parent.mkdir(parents=True, exist_ok=True)
    square_canvas.save(args.icon_output, format="ICO", sizes=[(size, size) for size in ICON_SIZES])

    if args.preview_output is not None:
        args.preview_output.parent.mkdir(parents=True, exist_ok=True)
        preview = square_canvas.resize((512, 512), Image.Resampling.LANCZOS)
        preview.save(args.preview_output, format="PNG")


if __name__ == "__main__":
    main()
