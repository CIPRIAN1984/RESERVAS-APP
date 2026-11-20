"""Genera los iconos de la app con el logotipo nuevo (misma geometría que src/components/BrandMark.tsx)."""
import struct, sys, zlib

HOLE = (-0.03, -0.03, 0.225)
TOP = (0.14, 0.056)       # x, ancho: de arriba hasta el centro del hueco
BOTTOM = (-0.255, 0.056)  # x, ancho: del centro del hueco hacia abajo
CREAM = (0xF3, 0xEA, 0xDB)
BLACK = (0x08, 0x08, 0x08)

def inside(u, v):
    if u * u + v * v > 1: return False
    hx, hy, hr = HOLE
    if (u - hx) ** 2 + (v - hy) ** 2 < hr * hr: return False
    if TOP[0] <= u <= TOP[0] + TOP[1] and v <= hy: return False
    if BOTTOM[0] <= u <= BOTTOM[0] + BOTTOM[1] and v >= hy: return False
    return True

def render(size, scale, ss=4):
    """scale: radio del logotipo respecto a la mitad del lado"""
    rows = []
    half = size / 2
    for y in range(size):
        row = bytearray([0])
        for x in range(size):
            n = 0
            for sy in range(ss):
                for sx in range(ss):
                    u = ((x + (sx + 0.5) / ss) - half) / (half * scale)
                    v = ((y + (sy + 0.5) / ss) - half) / (half * scale)
                    n += inside(u, v)
            a = n / (ss * ss)
            row += bytes(round(BLACK[i] + (CREAM[i] - BLACK[i]) * a) for i in range(3))
        rows.append(bytes(row))
    return rows

def png(path, size, rows):
    def chunk(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    data = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 2, 0, 0, 0))
    data += chunk(b'IDAT', zlib.compress(b''.join(rows), 9)) + chunk(b'IEND', b'')
    open(path, 'wb').write(data)

out = sys.argv[1]
# 0.62 del lado: dentro de la zona segura de los iconos "maskable" (círculo del 80 %)
for name, size in [('icon-192.png', 192), ('icon-512.png', 512), ('apple-touch-icon.png', 180), ('favicon-32.png', 32)]:
    png(f'{out}/{name}', size, render(size, 0.62 if size > 64 else 0.82, 3 if size > 256 else 4))
    print('ok', name)

# favicon.ico con PNG dentro (16 y 32 px): lo buscan Safari y los navegadores antiguos
def png_bytes(size, scale):
    import io
    tmp = f'{out}/.tmp.png'
    png(tmp, size, render(size, scale, 4))
    b = open(tmp, 'rb').read()
    import os; os.remove(tmp)
    return b
imgs = [(16, png_bytes(16, 0.86)), (32, png_bytes(32, 0.82))]
header = struct.pack('<HHH', 0, 1, len(imgs))
offset = 6 + 16 * len(imgs)
entries = b''
body = b''
for size, b in imgs:
    entries += struct.pack('<BBBBHHII', size, size, 0, 0, 1, 32, len(b), offset + len(body))
    body += b
open(f'{out}/favicon.ico', 'wb').write(header + entries + body)
print('ok favicon.ico')
