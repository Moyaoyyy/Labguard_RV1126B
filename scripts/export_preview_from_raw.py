#!/usr/bin/env python3

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert a saved raw preview frame into a corrected PPM preview."
    )
    parser.add_argument("--input", required=True, help="Path to the saved raw frame.")
    parser.add_argument("--output", required=True, help="Path to the output PPM file.")
    parser.add_argument("--width", required=True, type=int, help="Frame width in pixels.")
    parser.add_argument("--height", required=True, type=int, help="Frame height in pixels.")
    parser.add_argument(
        "--pixfmt",
        required=True,
        choices=("NV12",),
        help="Pixel format of the saved raw frame.",
    )
    return parser.parse_args()


def load_nv12(path: Path, width: int, height: int) -> tuple[np.ndarray, np.ndarray]:
    expected_size = width * height * 3 // 2
    data = path.read_bytes()
    if len(data) != expected_size:
        raise ValueError(
            f"unexpected NV12 frame size: got {len(data)}, expected {expected_size}"
        )

    array = np.frombuffer(data, dtype=np.uint8)
    y_plane = array[: width * height].reshape(height, width).astype(np.float32)
    uv_plane = array[width * height :].reshape(height // 2, width // 2, 2).astype(np.float32)
    return y_plane, uv_plane


def central_roi_means(uv_plane: np.ndarray, width: int, height: int) -> tuple[float, float]:
    x0 = int(width * 0.20)
    x1 = int(width * 0.80)
    y0 = int(height * 0.22)
    y1 = int(height * 0.72)

    ux0 = max(0, min(uv_plane.shape[1] - 1, x0 // 2))
    ux1 = max(ux0 + 1, min(uv_plane.shape[1], x1 // 2))
    uy0 = max(0, min(uv_plane.shape[0] - 1, y0 // 2))
    uy1 = max(uy0 + 1, min(uv_plane.shape[0], y1 // 2))

    roi = uv_plane[uy0:uy1, ux0:ux1]
    return float(roi[:, :, 0].mean()), float(roi[:, :, 1].mean())


def convert_nv12_to_rgb(
    y_plane: np.ndarray, uv_plane: np.ndarray, width: int, height: int
) -> np.ndarray:
    u_mean, v_mean = central_roi_means(uv_plane, width, height)

    corrected_u = np.clip(uv_plane[:, :, 0] - (u_mean - 128.0), 0.0, 255.0)
    corrected_v = np.clip(uv_plane[:, :, 1] + (128.0 - v_mean), 0.0, 255.0)

    u = np.repeat(np.repeat(corrected_u, 2, axis=0), 2, axis=1)
    v = np.repeat(np.repeat(corrected_v, 2, axis=0), 2, axis=1)

    c = y_plane - 16.0
    d = u - 128.0
    e = v - 128.0

    r = 1.164 * c + 1.793 * e
    g = 1.164 * c - 0.213 * d - 0.534 * e
    b = 1.164 * c + 2.115 * d

    rgb = np.stack([r, g, b], axis=-1)
    return np.clip(rgb, 0.0, 255.0).astype(np.uint8)


def write_ppm(path: Path, rgb: np.ndarray) -> None:
    height, width, _ = rgb.shape
    with path.open("wb") as handle:
        handle.write(f"P6\n{width} {height}\n255\n".encode("ascii"))
        handle.write(rgb.tobytes())


def main() -> int:
    args = parse_args()
    input_path = Path(args.input)
    output_path = Path(args.output)

    if args.pixfmt != "NV12":
        raise ValueError(f"unsupported pixel format: {args.pixfmt}")

    y_plane, uv_plane = load_nv12(input_path, args.width, args.height)
    rgb = convert_nv12_to_rgb(y_plane, uv_plane, args.width, args.height)
    write_ppm(output_path, rgb)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
