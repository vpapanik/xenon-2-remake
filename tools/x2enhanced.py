"""The ENHANCED graphics laid out to look at : one picture per object with all its frames,
as BMP_<name>.png next to the same picture in xBRZ (xBRZ_<name>.png), by category.

Reads remake/assets and remake/assets_hd (written by x2xbrz.py) and writes :

  01 ship and weapons, 02 ship, items and effects : X2WEAPS and X2SPR, runs of consecutive
     frames of similar size
  03 level 1 ... 07 level 5 : "enemy NN" for each enemy type of data/enemies.json (its
     frames in this set), the other frames in runs, the level's tiles and Amiga background
  08 shop : SHOP sprites in runs, the panels, pipes and shopkeeper, small font, shop digits
  09 screens : title logo, large and medium fonts, HUD, Amiga title pictures

The frames of an object are placed in a grid on a transparent background, the xBRZ picture
has the same grid FACTOR times larger.

Usage : python x2enhanced.py <remake folder> <output folder>
"""

import csv
import json
import math
import os
import shutil
import sys

from PIL import Image

REMAKE = sys.argv[1]
OUT = sys.argv[2]
SD = os.path.join(REMAKE, 'assets')
HD = os.path.join(REMAKE, 'assets_hd')
MAX_RUN = 20
GAP = 2
count = 0

# layout.json : for each object picture (its path under the output folder, without .png),
# the pictures of assets it holds and where, so that x2nb2.py can put an improved version
# (NB2_<name>.png) back into assets_hd

layout = {}


def hd_file(path):

    # the xBRZ picture of assets_hd : as x2xbrz.py writes it, or named _xBRZ by x2nb2.py (an
    # _NB2 one only when no xBRZ one is left, so run this right after x2xbrz.py)

    stem = os.path.join(HD, path)[:-len('.png')]

    for suffix in ('', '_xBRZ', '_NB2'):
        if os.path.exists(stem + suffix + '.png'):
            return stem + suffix + '.png'

    return os.path.join(HD, path)


def sheet(paths, folder, name):

    # the pictures (paths under assets) in a grid, and the same grid from assets_hd

    global count
    sd = [Image.open(os.path.join(SD, p)).convert('RGBA') for p in paths]
    hd = [Image.open(hd_file(p)).convert('RGBA') for p in paths]
    k = hd[0].width // sd[0].width
    columns = math.ceil(math.sqrt(len(sd)))
    rows = math.ceil(len(sd) / columns)
    cw = max(im.width for im in sd) + GAP
    ch = max(im.height for im in sd) + GAP
    out_sd = Image.new('RGBA', (columns * cw + GAP, rows * ch + GAP), (0, 0, 0, 0))
    out_hd = Image.new('RGBA', (out_sd.width * k, out_sd.height * k), (0, 0, 0, 0))

    cells = []

    for n, (a, b) in enumerate(zip(sd, hd)):
        x = GAP + (n % columns) * cw + (cw - GAP - a.width) // 2
        y = GAP + (n // columns) * ch + (ch - GAP - a.height) // 2
        out_sd.paste(a, (x, y))
        out_hd.paste(b, (x * k, y * k))
        cells.append([paths[n], x, y, a.width, a.height])

    layout[os.path.relpath(os.path.join(folder, name), OUT).replace(os.sep, '/')] = {'size': list(out_sd.size), 'factor': k, 'cells': cells}

    os.makedirs(folder, exist_ok=True)
    out_sd.save(os.path.join(folder, 'BMP_' + name + '.png'))
    out_hd.save(os.path.join(folder, 'xBRZ_' + name + '.png'))
    count += 1


def single(path, folder, name):

    # a picture that is already whole (background, panel, tile sheet)

    global count
    os.makedirs(folder, exist_ok=True)
    shutil.copyfile(os.path.join(SD, path), os.path.join(folder, 'BMP_' + name + '.png'))
    shutil.copyfile(hd_file(path), os.path.join(folder, 'xBRZ_' + name + '.png'))
    layout[os.path.relpath(os.path.join(folder, name), OUT).replace(os.sep, '/')] = {'single': path}
    count += 1


def frames_of(name):
    folder = os.path.join(SD, 'sprites', name)
    out = {}

    with open(os.path.join(folder, 'frames.csv')) as f:
        for row in csv.DictReader(f):
            i = int(row['frame'])

            if os.path.exists(os.path.join(folder, '%03d.png' % i)):
                size = Image.open(os.path.join(folder, '%03d.png' % i)).size

                if size[0] and size[1]:
                    out[i] = size

    return out


def runs(sizes, ids):

    # consecutive frames of similar size, at most MAX_RUN

    groups, run = [], []

    for i in ids:
        if run:
            a, b = max(sizes[run[0]]), max(sizes[i])

            if len(run) >= MAX_RUN or max(a, b) / max(1, min(a, b)) > 1.6 or i != run[-1] + 1:
                groups.append(run)
                run = []

        run.append(i)

    if run:
        groups.append(run)

    return groups


def sprites(name, folder, enemies=None):
    sizes = frames_of(name)
    used = set()

    if enemies:
        for key in sorted(enemies, key=int):
            ids = []

            for part in enemies[key]['parts']:
                for f in part['frames']:
                    if f['set'] == name and f['frame'] in sizes and f['frame'] not in ids:
                        ids.append(f['frame'])

            if ids:
                sheet(['sprites/%s/%03d.png' % (name, i) for i in ids], folder, 'enemy %02d' % int(key))
                used.update(ids)

    for run in runs(sizes, [i for i in sorted(sizes) if i not in used]):
        label = 'frames %03d-%03d' % (run[0], run[-1]) if len(run) > 1 else 'frame %03d' % run[0]
        sheet(['sprites/%s/%03d.png' % (name, i) for i in run], folder, label)


enemies = json.load(open(os.path.join(REMAKE, 'data', 'enemies.json')))

sprites('X2WEAPS', os.path.join(OUT, '01 ship and weapons'))
sprites('X2SPR', os.path.join(OUT, '02 ship, items and effects'))

for n in range(1, 6):
    level = 'S%d' % n
    folder = os.path.join(OUT, '%02d level %d' % (n + 2, n))
    sprites(level, folder, enemies[level])
    single('tiles/%s_tiles.png' % level, folder, 'tiles')
    single('amiga/%s_background.png' % level, folder, 'amiga background')

shop = os.path.join(OUT, '08 shop')
sprites('SHOP', shop)

for name in ('shop_side_panel', 'shop_bottom_panel', 'shopkeeper_strip'):
    single('gr/%s.png' % name, shop, name.replace('_', ' '))

sheet(['gr/pipes/%d.png' % i for i in range(5)], shop, 'pipes')
sheet(['gr/font_tiny/%02d.png' % i for i in range(60)], shop, 'font tiny')
sheet(['gr/hud_digits_shop/%02d.png' % i for i in range(20)], shop, 'digits')

screens = os.path.join(OUT, '09 screens')
single('gr/title_logo.png', screens, 'title logo')

for name in ('title_logo', 'title_large', 'title_small'):
    single('amiga/%s.png' % name, screens, 'amiga ' + name.replace('_', ' '))

sheet(['gr/font_large/%02d.png' % i for i in range(40)], screens, 'font large')
sheet(['gr/font_medium/%02d.png' % i for i in range(42)], screens, 'font medium')
sheet(['gr/hud_digits/%02d.png' % i for i in range(20)], screens, 'hud digits')
single('gr/hud_bar.png', screens, 'hud bar')
json.dump(layout, open(os.path.join(OUT, 'layout.json'), 'w'), indent=1)
print('%d objects' % count)
