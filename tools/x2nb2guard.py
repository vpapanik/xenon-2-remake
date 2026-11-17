"""ENHANCED : a level guardian drawn from tiles, redrawn by NB2, back into the level's tile sheet.

The guardians of levels 1, 2, 4 and 5 are grids of tiles (main.gd _draw_boss, _draw_grid,
level 5 written into the map). A test run records which tile is drawn where on the screen
(cells.json : [tile, x, y, masked] in 320 x 200 pixels, map cells as -tile - 100000), the
ENHANCED screenshot of that frame (1280 x 800, 4 pixels a game pixel) is cropped, redrawn by
NB2 and pasted back. Each recorded tile wholly inside the crop takes its 64 x 64 square from
there (its first place) : the opaque pixels of the tile in the base sheet (a masked tile keeps
black where it is transparent), so the background seen through it is not taken.

Writes enhanced/<level>/NB2_tiles.png (the xBRZ tile sheet with those tiles replaced), which
x2nb2.py puts into assets_hd, also into the masked and Amiga sheets.

Usage : python x2nb2guard.py <enhanced> <level folder> <cells.json> <screenshot> <nb2 crop>
        <x0> <y0> <x1> <y1> [tile ...]   (the crop box in screenshot pixels ; the optional
        tiles keep only those, for a guardian written into the map)"""
import json, os, sys
import numpy as np
from PIL import Image

E, FOLDER, CELLS, SHOT, CROP = sys.argv[1:6]
x0, y0, x1, y1 = map(int, sys.argv[6:10])
ONLY = {int(t) for t in sys.argv[10:]}
K = 4
level = FOLDER.split()[-1]
sheet_path = os.path.join(E, FOLDER, 'xBRZ_tiles.png')
sheet = Image.open(sheet_path).convert('RGBA')
remake = os.path.join(E, '..', 'remake', 'assets_hd', 'tiles')

# the masked sheet as named in assets_hd (_NB2 or _xBRZ by how it was enlarged)

masked_path = next(p for p in (os.path.join(remake, 'S%s_tiles_masked%s.png' % (level, s)) for s in ('', '_NB2', '_xBRZ')) if os.path.exists(p))
masked = Image.open(masked_path).convert('RGBA')
screen = Image.open(SHOT).convert('RGB')
crop = Image.open(CROP).convert('RGB').resize((x1 - x0, y1 - y0), Image.LANCZOS)
screen.paste(crop, (x0, y0))
out = np.array(sheet)
mask_a = np.array(masked)[..., 3]
done = set()

for tile, x, y, is_masked in json.load(open(CELLS)):
    if tile <= -100000:
        tile = -tile - 100000

    if ONLY and tile not in ONLY or tile in done:
        continue

    sx, sy = x * K, y * K

    if sx < x0 or sy < y0 or sx + 64 > x1 or sy + 64 > y1:
        continue

    patch = np.array(screen.crop((sx, sy, sx + 64, sy + 64)).convert('RGBA'))
    ox, oy = (1 + (tile % 20) * 17) * K, (1 + (tile // 20) * 17) * K
    cell = out[oy:oy + 64, ox:ox + 64]
    keep = mask_a[oy:oy + 64, ox:ox + 64] > 0 if is_masked or ONLY else np.ones((64, 64), bool)
    cell[keep, :3] = patch[keep, :3]
    done.add(tile)

Image.fromarray(out).save(os.path.join(E, FOLDER, 'NB2_tiles.png'))
print('%s : %d tiles from NB2' % (FOLDER, len(done)))
