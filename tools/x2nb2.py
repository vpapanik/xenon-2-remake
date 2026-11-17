"""ENHANCED : an improved picture made by hand (Nano Banana Pro or 2, or anything else) put
into the game in place of its xBRZ version.

In REA/Xenon 2/enhanced, next to an object's BMP_<name>.png and xBRZ_<name>.png, save the
improved version as NB2_<name>.png (any size, the same layout and proportions as the
xBRZ_ picture). This tool finds every NB2_ picture, scales it to the size of the xBRZ_ one and, by
enhanced/layout.json (written by x2enhanced.py), writes each frame into remake/assets_hd in
place of the xBRZ one. Where the xBRZ picture has transparency (sprites), its transparency
is kept, so a background the AI drew around the frames is cut away.

Run it after x2xbrz.py and x2enhanced.py (x2xbrz.py writes assets_hd again from the
originals). Then the project needs an import.

assets_hd names each picture by how it was enlarged : a picture written here becomes
<name>_NB2.png (a tile sheet with some NB2 tiles too), and at the end every picture still
without a suffix (as x2xbrz.py writes them) becomes <name>_xBRZ.png. Run again, it reads
whichever of <name>.png, <name>_NB2.png, <name>_xBRZ.png is there.

Usage : python x2nb2.py <remake folder> <enhanced folder>
"""

import json
import numpy as np
import os
import sys

from PIL import Image
from scipy import ndimage

def named(key, prefix):

    # an object's picture in enhanced : BMP_ (the original), xBRZ_ or NB2_ before its name

    folder, name = key.rsplit('/', 1)
    return folder + '/' + prefix + '_' + name + '.png'


REMAKE = sys.argv[1]
ENHANCED = sys.argv[2]
HD = os.path.join(REMAKE, 'assets_hd')
layout = json.load(open(os.path.join(ENHANCED, 'layout.json')))
done = 0
SUFFIXES = ('_NB2', '_xBRZ')


def variants(path):

    # a picture of assets_hd as x2xbrz.py writes it, and as named by how it was enlarged

    stem = path[:-len('.png')]
    return [path] + [stem + s + '.png' for s in SUFFIXES]


def resolve(path):
    for v in variants(path):
        if os.path.exists(v):
            return v

    return path


def remove(path):
    for p in (path, path + '.import'):
        if os.path.exists(p):
            os.remove(p)


def written(path):

    # where a picture redrawn by NB2 goes : <name>_NB2.png, the other versions removed

    out = path[:-len('.png')] + '_NB2.png'

    for v in variants(path):
        if v != out:
            remove(v)

    return out


def plain(name):
    return name.endswith('.png') and not name[:-len('.png')].endswith(SUFFIXES)


# a fresh x2xbrz.py output (pictures without a suffix) replaces the named ones of a run before

for folder, dirs, files in os.walk(HD):
    for file in files:
        if plain(file):
            for v in variants(os.path.join(folder, file))[1:]:
                remove(v)


def keep_alpha(new, old):

    # the frame from the improved picture, with the xBRZ frame's transparency

    new = new.convert('RGBA')

    if old.mode == 'RGBA' and old.getextrema()[3][0] < 255:
        new.putalpha(old.getchannel('A'))
    else:
        new = new.convert(old.mode)

    return new


# The NB2 sprites are drawn on black and may reach past the xBRZ outline (the rings of the
# orbiting sphere, X2WEAPS 012-019, were cut, in the shop too) : nothing of them is cut,
# their transparency is the xBRZ one joined with the NB2 picture's own (black is
# transparent), and where only the NB2 one shows, the colour is taken off the black so a
# glow lightens what is behind it. Not for frames drawn over a picture instead of black
# (the shopkeeper's eyes go on his face).

XBRZ_ALPHA = {'08 shop/frames 087-090'}


def own_alpha(new, old):
    new = keep_alpha(new, old)

    if new.mode != 'RGBA':
        return new

    rgba = np.asarray(new).astype(float)
    own = np.clip((rgba[..., :3].max(2) - 14) / 24, 0, 1)
    extra = own > rgba[..., 3] / 255
    rgba[extra, :3] = np.clip(rgba[extra, :3] / np.maximum(own[extra], 1 / 255)[:, None], 0, 255)
    rgba[extra, 3] = own[extra] * 255
    return Image.fromarray(rgba.round().astype('uint8'), 'RGBA')


# What an NB2 frame draws past its box is kept in a margin of one original pixel (MARGIN
# large pixels) around it, read by hd_texture.gd and hd_mirror.gd : only what joins the
# frame's own drawing (not a neighbour's), and the margin only when something is in it.

MARGIN = 4


def framed(nb2, xbrz, x, y, w, h):
    m = MARGIN
    box = (x - m, y - m, x + w + m, y + h + m)
    frame = own_alpha(nb2.crop(box), xbrz.crop(box))

    if frame.mode != 'RGBA':
        return frame.crop((m, m, m + w, m + h))

    rgba = np.array(frame)
    seen = rgba[..., 3] > 25
    labels, count = ndimage.label(seen, structure=np.ones((3, 3)))
    inner = np.unique(labels[m:m + h, m:m + w])
    keep = np.isin(labels, inner[inner > 0])
    ring = np.ones(seen.shape, bool)
    ring[m:m + h, m:m + w] = False
    rgba[ring & ~keep] = 0

    if not rgba[ring, 3].any():
        return Image.fromarray(rgba[m:m + h, m:m + w], 'RGBA')

    return Image.fromarray(rgba, 'RGBA')


for folder, dirs, files in os.walk(ENHANCED):
    for file in files:
        if not (file.startswith('NB2_') and file.endswith('.png')):
            continue

        key = os.path.relpath(os.path.join(folder, file[len('NB2_'):-len('.png')]), ENHANCED).replace(os.sep, '/')

        if key not in layout:
            print('not in layout.json :', key)
            continue

        entry = layout[key]
        xbrz = Image.open(os.path.join(ENHANCED, named(key, 'xBRZ')))
        nb2 = Image.open(os.path.join(folder, file)).convert('RGBA').resize(xbrz.size, Image.LANCZOS)

        if 'single' in entry:
            target = os.path.join(HD, entry['single'])

            if target.endswith('_tiles.png') or key in XBRZ_ALPHA:
                picture = keep_alpha(nb2, Image.open(resolve(target)))
            else:
                picture = own_alpha(nb2, xbrz)

            picture.save(written(target))

            done += 1

            # a tile sheet : the tiles that changed also into its masked and Amiga sheets,
            # their colours with those sheets' own transparency

            if target.endswith('_tiles.png'):
                old = np.asarray(xbrz.convert('RGB')).astype(int)
                new = np.asarray(nb2.convert('RGB'))

                for extra in ('_tiles_masked.png', '_tiles_amiga.png'):
                    path = target.replace('_tiles.png', extra)
                    sheet = np.array(Image.open(resolve(path)).convert('RGBA'))

                    for ty in range(0, new.shape[0] - 64, 68):
                        for tx in range(0, new.shape[1] - 64, 68):
                            oy, ox = ty + 4, tx + 4

                            if not (old[oy:oy + 64, ox:ox + 64] != new[oy:oy + 64, ox:ox + 64]).any():
                                continue

                            part = sheet[oy:oy + 64, ox:ox + 64]
                            seen = part[..., 3] > 0
                            part[seen, :3] = new[oy:oy + 64, ox:ox + 64][seen]

                    Image.fromarray(sheet).save(written(path))
                    done += 1
        else:
            k = entry['factor']

            for path, x, y, w, h in entry['cells']:
                target = os.path.join(HD, path)
                frame = nb2.crop((x * k, y * k, (x + w) * k, (y + h) * k))
                if key in XBRZ_ALPHA:
                    picture = keep_alpha(frame, Image.open(resolve(target)))
                else:
                    picture = framed(nb2, xbrz, x * k, y * k, w * k, h * k)

                picture.save(written(target))
                done += 1

        print(key, ': in the game')

# every picture left without a suffix is as x2xbrz.py made it

named = 0

for folder, dirs, files in os.walk(HD):
    for file in files:
        if plain(file):
            path = os.path.join(folder, file)
            os.replace(path, path[:-len('.png')] + '_xBRZ.png')
            remove(path + '.import')
            named += 1

print('%d pictures of assets_hd replaced, %d named _xBRZ' % (done, named))
