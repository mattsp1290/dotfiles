#!/usr/bin/env python3
"""Convert an XWD (version 7, ZPixmap, 24/32 bpp) dump to PNG. Stdlib only."""
from __future__ import annotations

import struct
import sys
import zlib


class XwdError(ValueError):
    pass


def _shift(mask: int) -> int:
    shift = 0
    while mask and not mask & 1:
        mask >>= 1
        shift += 1
    return shift


def xwd_to_png(data: bytes) -> bytes:
    if len(data) < 100:
        raise XwdError("truncated XWD header")
    fields = struct.unpack(">25I", data[:100])
    (header_size, version, pixmap_format, _depth, width, height, _xoffset,
     byte_order, _bitmap_unit, _bitmap_bit_order, _bitmap_pad, bits_per_pixel,
     bytes_per_line, _visual_class, red_mask, green_mask, blue_mask,
     _bits_per_rgb, _colormap_entries, ncolors) = fields[:20]
    if version != 7:
        raise XwdError("unsupported XWD version %d" % version)
    if pixmap_format != 2 or bits_per_pixel not in (24, 32):
        raise XwdError("unsupported XWD pixmap format")
    bpp = bits_per_pixel // 8
    offset = header_size + ncolors * 12
    if len(data) < offset + bytes_per_line * height:
        raise XwdError("truncated XWD pixel data")
    order = "big" if byte_order == 1 else "little"
    shifts = [_shift(m) for m in (red_mask, green_mask, blue_mask)]
    rows = []
    for y in range(height):
        line = data[offset + y * bytes_per_line: offset + y * bytes_per_line + width * bpp]
        out = bytearray(1 + width * 3)
        if bpp == 4 and order == "little" and (red_mask, green_mask, blue_mask) == (0xFF0000, 0xFF00, 0xFF):
            out[1::3] = line[2::4]
            out[2::3] = line[1::4]
            out[3::3] = line[0::4]
        else:
            for x in range(width):
                pixel = int.from_bytes(line[x * bpp:(x + 1) * bpp], order)
                out[1 + x * 3] = (pixel & red_mask) >> shifts[0] & 0xFF
                out[2 + x * 3] = (pixel & green_mask) >> shifts[1] & 0xFF
                out[3 + x * 3] = (pixel & blue_mask) >> shifts[2] & 0xFF
        rows.append(bytes(out))

    def chunk(kind: bytes, body: bytes) -> bytes:
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
            + chunk(b"IDAT", zlib.compress(b"".join(rows), 6)) + chunk(b"IEND", b""))


if __name__ == "__main__":
    with open(sys.argv[1], "rb") as handle:
        png = xwd_to_png(handle.read())
    with open(sys.argv[2], "wb") as handle:
        handle.write(png)
