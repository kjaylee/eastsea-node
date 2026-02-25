#!/usr/bin/env python3
import math
import struct
import zlib
import sys


def clamp(value: float) -> float:
    return max(0.0, min(1.0, value))


def png_chunk(tag: bytes, payload: bytes) -> bytes:
    crc = zlib.crc32(tag + payload) & 0xFFFFFFFF
    return struct.pack(">I", len(payload)) + tag + payload + struct.pack(">I", crc)


def compose_png(raw: bytes, w: int, h: int, path: str) -> None:
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
        f.write(png_chunk(b"IHDR", ihdr))
        f.write(png_chunk(b"IDAT", zlib.compress(raw)))
        f.write(png_chunk(b"IEND", b""))


def to_byte(color: float) -> int:
    return int(round(clamp(color) * 255))


def blend(base: tuple[int, int, int, int], top: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    br, bg, bb, ba = base
    tr, tg, tb, ta = top
    alpha = ta / 255.0
    out_a = alpha + (ba / 255.0) * (1.0 - alpha)
    if out_a == 0:
        return (0, 0, 0, 0)
    out_r = (tr * alpha + br * (ba / 255.0) * (1.0 - alpha)) / out_a
    out_g = (tg * alpha + bg * (ba / 255.0) * (1.0 - alpha)) / out_a
    out_b = (tb * alpha + bb * (ba / 255.0) * (1.0 - alpha)) / out_a
    return (to_byte(out_r), to_byte(out_g), to_byte(out_b), to_byte(out_a))


def draw_pixel(buf, x, y, color, w):
    if x < 0 or y < 0 or x >= w or y >= w:
        return
    idx = (y * w + x) * 4
    base = (buf[idx], buf[idx + 1], buf[idx + 2], buf[idx + 3])
    over = blend(base, color)
    buf[idx : idx + 4] = over


def draw_circle(buf, cx, cy, r, color, w, aa_steps=1, filled=True):
    rr = int(r)
    for yy in range(int(cy - r - 2), int(cy + r + 3)):
        for xx in range(int(cx - r - 2), int(cx + r + 3)):
            dx = xx + 0.5 - cx
            dy = yy + 0.5 - cy
            d = math.sqrt(dx * dx + dy * dy)
            if filled:
                if d <= r + 0.75:
                    edge = clamp(1.0 - abs(d - r))
                    draw_pixel(buf, xx, yy, (color[0], color[1], color[2], to_byte(color[3] * edge)), w)
            else:
                if r - aa_steps <= d <= r + aa_steps:
                    edge = clamp((aa_steps - abs(d - r)) / aa_steps)
                    draw_pixel(buf, xx, yy, (color[0], color[1], color[2], to_byte(color[3] * edge)), w)


def draw_line(buf, x1, y1, x2, y2, color, w, thickness=1.0):
    dx = x2 - x1
    dy = y2 - y1
    steps = int(max(abs(dx), abs(dy)) + 1)
    if steps <= 0:
        return
    for i in range(steps + 1):
        t = i / steps
        x = x1 + dx * t
        y = y1 + dy * t
        draw_circle(buf, x, y, thickness, color, w)


def build_icon(path: str, size: int = 1024) -> None:
    w = size
    h = size
    cx = w / 2.0
    cy = h / 2.0
    data = bytearray([0] * (w * h * 4))

    # Deep ocean gradient background with subtle texture
    for y in range(h):
        for x in range(w):
            nx = (x - cx) / (w / 2.2)
            ny = (y - cy) / (h / 2.2)
            d = math.sqrt(nx * nx + ny * ny)
            t = clamp(1.0 - d)
            r = 10 + 20 * t
            g = 24 + 40 * t
            b = 48 + 90 * t

            # light vignette
            v = 1.0 - 0.35 * (d ** 1.05)
            r = r * v + 14
            g = g * v + 20
            b = b * v + 35
            data[(y * w + x) * 4 : (y * w + x + 1) * 4] = bytes([
                int(clamp(r / 255.0) * 255),
                int(clamp(g / 255.0) * 255),
                int(clamp(b / 255.0) * 255),
                255,
            ])

    # Ambient halo
    draw_circle(data, cx, cy, w * 0.52, (26, 130, 255, 60), w, filled=False)
    draw_circle(data, cx, cy, w * 0.52, (60, 180, 255, 30), w, filled=False)
    draw_circle(data, cx, cy, w * 0.33, (70, 190, 255, 45), w, filled=False)

    # Node rings (Transmission-like distributed system style)
    ring_radius = w * 0.30
    count = 7
    nodes = []
    for i in range(count):
        theta = (2 * math.pi * i / count) + 0.25
        nx = cx + math.cos(theta) * ring_radius
        ny = cy + math.sin(theta) * ring_radius
        nodes.append((nx, ny))

    node_core = (30, 210, 255, 255)
    node_edge = (145, 225, 255, 255)

    # Ring chain links
    for i in range(count):
        x1, y1 = nodes[i]
        x2, y2 = nodes[(i + 1) % count]
        draw_line(data, x1, y1, x2, y2, (130, 210, 255, 80), w, thickness=2.6)

    # Nodes
    for x, y in nodes:
        draw_circle(data, x, y, w * 0.055, (18, 32, 64, 255), w, filled=True)
        draw_circle(data, x, y, w * 0.062, node_edge, w, filled=False)
        draw_circle(data, x, y, w * 0.034, node_core, w, filled=True)

    # Center block icon
    center_size = w * 0.18
    for y in range(int(cy - center_size / 1.8), int(cy + center_size / 1.8)):
        for x in range(int(cx - center_size / 1.6), int(cx + center_size / 1.6)):
            if x < 0 or x >= w or y < 0 or y >= h:
                continue
            local_x = (x - cx) / (center_size / 1.6)
            local_y = (y - cy) / (center_size / 1.8)
            inside = abs(local_x) < 1.0 and abs(local_y) < 1.0
            if not inside:
                continue
            rx = 0.08 if abs(local_x) > 0.7 else 0.0
            ry = 0.07 if abs(local_y) > 0.7 else 0.0
            radius_x = 1.0 - max(abs(local_x), abs(local_y))
            radius_y = 1.0 - abs(local_y)
            shade = clamp(0.15 + 0.8 * min(radius_x, radius_y))
            glow = 1.0 - (abs(local_x) ** 2 + abs(local_y) ** 2) ** 0.5
            r = int(140 + 35 * shade + 30 * glow)
            g = int(190 + 35 * glow + 20 * shade)
            b = int(255 - 15 * shade)
            alpha = 95 + int(100 * shade) + int(20 * glow)
            if rx > 0:
                alpha = int(alpha * 0.75)
            if ry > 0:
                alpha = int(alpha * 0.75)
            if radius_x > 0:
                draw_pixel(data, x, y, (r, g, b, alpha), w)

    # Subtle chain sparkles
    for i in range(130):
        t = i / 130.0 * 2.0 * math.pi
        nx = cx + math.cos(t * 2.7) * (w * 0.44)
        ny = cy + math.sin(t * 1.8) * (h * 0.44)
        draw_circle(data, nx, ny, w * 0.004, (220, 245, 255, 70), w)

    # Export
    raw_rows = bytearray()
    for y in range(h):
        row = bytes([0])
        start = y * w * 4
        row += data[start : start + w * 4]
        raw_rows.extend(row)

    compose_png(bytes(raw_rows), w, h, path)


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: generate-app-icon.py <output_path>")
        return 1
    build_icon(sys.argv[1], 1024)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
