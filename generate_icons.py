import struct
import zlib
import math

def create_png(width, height, pixels):
    """Create a PNG file from RGBA pixel data."""
    def png_chunk(chunk_type, data):
        chunk_len = len(data)
        chunk_data = chunk_type + data
        crc = zlib.crc32(chunk_data) & 0xffffffff
        return struct.pack('>I', chunk_len) + chunk_data + struct.pack('>I', crc)

    # PNG signature
    signature = b'\x89PNG\r\n\x1a\n'
    
    # IHDR chunk
    ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    # 8 bit per channel, color type 2 = RGB, but we want RGBA so color type 6
    ihdr_data = struct.pack('>II', width, height) + bytes([8, 6, 0, 0, 0])
    ihdr = png_chunk(b'IHDR', ihdr_data)
    
    # IDAT chunk (image data)
    raw_data = b''
    for y in range(height):
        raw_data += b'\x00'  # filter type none
        for x in range(width):
            r, g, b, a = pixels[y * width + x]
            raw_data += bytes([r, g, b, a])
    
    compressed = zlib.compress(raw_data, 9)
    idat = png_chunk(b'IDAT', compressed)
    
    # IEND chunk
    iend = png_chunk(b'IEND', b'')
    
    return signature + ihdr + idat + iend

def draw_icon(size):
    """Draw the guardian icon at given size. Returns list of (r,g,b,a) tuples."""
    pixels = [(0, 0, 0, 0)] * (size * size)  # transparent
    cx, cy = size // 2, size // 2
    
    # Diamond: rotated square. Half-diagonal = size * 0.45
    half = size * 0.44
    
    # Glow effect: draw concentric diamonds from outside in
    glow_width = max(2, size // 30)
    
    def inside_diamond(x, y, margin=0):
        dx = abs(x - cx)
        dy = abs(y - cy)
        return (dx + dy) < (half - margin)
    
    def inside_diamond_border(x, y, w):
        return inside_diamond(x, y, 0) and not inside_diamond(x, y, w)
    
    def rounded_diamond(x, y, margin=0, corner=0.08):
        """Approximate rounded diamond"""
        dx = abs(x - cx) / (half - margin)
        dy = abs(y - cy) / (half - margin)
        d = dx + dy
        if d > 1.0:
            return False
        # Round the corners with a soft curve
        if dx > (1 - corner) and dy > (1 - corner):
            ndx = (dx - (1 - corner)) / corner
            ndy = (dy - (1 - corner)) / corner
            return (ndx * ndx + ndy * ndy) < 1.0
        return True
    
    for y in range(size):
        for x in range(size):
            # Check glow (outer ring)
            in_diamond = rounded_diamond(x, y)
            in_inner = rounded_diamond(x, y, glow_width * 2)
            
            if in_diamond and not in_inner:
                # Glow border: vibrant purple
                alpha = 255
                # Gradient from bright purple to darker
                dist = abs(x - cx) + abs(y - cy)
                t = 1.0 - (dist - (half - glow_width * 2)) / (glow_width * 2 + 1)
                t = max(0, min(1, t))
                r = int(156 * t + 100 * (1-t))
                g = int(20 * t)
                b = int(220 * t + 180 * (1-t))
                pixels[y * size + x] = (r, g, b, alpha)
            elif in_inner:
                # Inner dark purple fill
                r, g, b = 40, 5, 80
                pixels[y * size + x] = (r, g, b, 255)
    
    # Draw shield
    shield_size = half * 0.65
    sx, sy = cx, cy - shield_size * 0.05  # slightly above center
    
    shield_top = int(sy - shield_size * 0.5)
    shield_bottom = int(sy + shield_size * 0.6)
    shield_left = int(sx - shield_size * 0.45)
    shield_right = int(sx + shield_size * 0.45)
    
    for y in range(size):
        for x in range(size):
            if not rounded_diamond(x, y, glow_width * 2):
                continue
            
            px = (x - sx) / shield_size
            py = (y - sy) / shield_size
            
            # Shield shape: rectangular top, curved bottom
            in_shield = False
            if -0.45 <= px <= 0.45 and -0.5 <= py <= 0.0:
                # Top rectangular part
                in_shield = True
            elif -0.45 <= px <= 0.45 and 0.0 < py <= 0.6:
                # Bottom curved part: parabola-like
                max_width = 0.45 * (1.0 - py / 0.65)
                if abs(px) <= max_width:
                    in_shield = True
            
            if in_shield:
                # Shield divisions (cross)
                is_border = (abs(px) < 0.03 or abs(py) < 0.03)
                if is_border:
                    # Cross lines: purple
                    pixels[y * size + x] = (120, 30, 200, 220)
                else:
                    # Shield fill: white
                    pixels[y * size + x] = (240, 240, 255, 245)
    
    return pixels

# Icon sizes needed for Android
sizes = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
}

import os

base_path = r"g:\untitled1\android\app\src\main\res"

for density, size in sizes.items():
    pixels = draw_icon(size)
    png_data = create_png(size, size, pixels)
    out_path = os.path.join(base_path, f"mipmap-{density}", "ic_launcher.png")
    with open(out_path, 'wb') as f:
        f.write(png_data)
    print(f"Generated {density}: {size}x{size} -> {out_path}")

print("Done! All icons generated.")
