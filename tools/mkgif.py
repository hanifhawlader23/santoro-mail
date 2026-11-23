"""Animated Santoro / Hanif Hawlader signature banners (GIF, 2x for retina).
Usage: python3 mkgif.py  -> sig-santoro.gif, sig-hanif.gif"""
from PIL import Image, ImageDraw, ImageFont
import math

F = '/home/claude/fonts/'
CREAM = (247, 245, 233); WINE = (91, 26, 44); INK = (20, 18, 16); GREY = (110, 104, 98)
W, H = 960, 220
rider = Image.open('rider150.png').convert('RGBA')


def font(w, s):
    return ImageFont.truetype(F + f'EM{w}.ttf', s)


def spaced(d, xy, txt, f, fill, sp):
    x, y = xy
    for ch in txt:
        d.text((x, y), ch, font=f, fill=fill)
        x += d.textlength(ch, font=f) + sp
    return x


def width(txt, f, sp):
    d = ImageDraw.Draw(Image.new('RGB', (1, 1)))
    return sum(d.textlength(c, font=f) for c in txt) + sp * (len(txt) - 1)


def ease(t):
    t = max(0.0, min(1.0, t))
    return 1 - (1 - t) ** 3


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def layer_text(draw_fn):
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(im))
    return im


def frames_santoro(name, role, line):
    big, mid, small = font(500, 46), font(500, 22), font(400, 21)
    # static layers
    t_name = layer_text(lambda d: spaced(d, (250, 34), name, big, INK, 1))
    t_role = layer_text(lambda d: spaced(d, (252, 104), role.upper() + ' · SANTORO', mid, WINE, 7))
    t_line = layer_text(lambda d: d.text((252, 150), line, font=small, fill=GREY))
    n = 30
    out = []
    for i in range(n + 1):
        p = i / n
        im = Image.new('RGBA', (W, H), CREAM + (255,))
        # logo: rise + fade
        a = ease(p / .35)
        lg = rider.copy()
        lg.putalpha(lg.getchannel('A').point(lambda v: int(v * a)))
        im.alpha_composite(lg, (40, 35 + int((1 - a) * 18)))
        # vertical wine rule grows
        g = ease((p - .15) / .3)
        d = ImageDraw.Draw(im)
        if g > 0:
            d.rectangle((222, 110 - int(80 * g), 224, 110 + int(80 * g)), fill=WINE)
        # name wipes in left->right
        wv = ease((p - .25) / .4)
        if wv > 0:
            m = Image.new('L', (W, H), 0)
            ImageDraw.Draw(m).rectangle((0, 0, 250 + int(620 * wv), H), fill=255)
            im.paste(t_name, (0, 0), Image.composite(t_name, Image.new('RGBA', (W, H)), m).getchannel('A'))
        # role fades up
        rv = ease((p - .55) / .3)
        if rv > 0:
            lay = t_role.copy(); lay.putalpha(lay.getchannel('A').point(lambda v: int(v * rv)))
            im.alpha_composite(lay, (0, int((1 - rv) * 8)))
        # underline sweep
        uv = ease((p - .6) / .35)
        if uv > 0:
            d.rectangle((252, 140, 252 + int(64 * uv), 141), fill=WINE)
        lv = ease((p - .75) / .25)
        if lv > 0 and line:
            lay = t_line.copy(); lay.putalpha(lay.getchannel('A').point(lambda v: int(v * lv)))
            im.alpha_composite(lay)
        out.append(im.convert('RGB'))
    return out


def frames_hanif(name, role, line):
    big, mid, small = font(500, 50), font(400, 23), font(500, 19)
    sp = 12
    nw = width(name.upper(), big, sp)
    t_name = layer_text(lambda d: spaced(d, (60, 30), name.upper(), big, INK, sp))
    t_role = layer_text(lambda d: d.text((62, 122), role, font=mid, fill=GREY))
    t_tag = layer_text(lambda d: spaced(d, (62, 168), 'FUNDADOR DE SANTORO', small, WINE, 6))
    n = 30
    out = []
    for i in range(n + 1):
        p = i / n
        im = Image.new('RGBA', (W, H), CREAM + (255,))
        d = ImageDraw.Draw(im)
        # letters drop in one by one (letter-spaced reveal)
        wv = ease(p / .55)
        m = Image.new('L', (W, H), 0)
        ImageDraw.Draw(m).rectangle((0, 0, 60 + int((nw + 10) * wv), H), fill=255)
        im.paste(t_name, (0, 0), Image.composite(t_name, Image.new('RGBA', (W, H)), m).getchannel('A'))
        # wine rule grows
        g = ease((p - .35) / .35)
        if g > 0:
            d.rectangle((62, 104, 62 + int(56 * g), 105), fill=WINE)
        rv = ease((p - .5) / .3)
        if rv > 0:
            lay = t_role.copy(); lay.putalpha(lay.getchannel('A').point(lambda v: int(v * rv)))
            im.alpha_composite(lay, (0, int((1 - rv) * 8)))
        tv = ease((p - .7) / .3)
        if tv > 0:
            lay = t_tag.copy(); lay.putalpha(lay.getchannel('A').point(lambda v: int(v * tv)))
            im.alpha_composite(lay)
        # small rider at right
        a = ease((p - .6) / .4)
        if a > 0:
            lg = rider.resize((97, 90), Image.LANCZOS)
            lg.putalpha(lg.getchannel('A').point(lambda v: int(v * a)))
            im.alpha_composite(lg, (W - 140, 65))
        out.append(im.convert('RGB'))
    return out


def shimmer(final, n=9):
    """soft light band sweeping over the finished signature"""
    out = []
    for i in range(n + 1):
        x0 = -200 + (W + 400) * i / n
        band = Image.new('L', (W, H), 0)
        d = ImageDraw.Draw(band)
        for k in range(120):
            a = int(70 * math.sin(math.pi * k / 120))
            d.line((x0 + k, 0, x0 + k - 60, H), fill=a)
        out.append(Image.composite(Image.new('RGB', (W, H), (255, 255, 250)), final, band))
    out.append(final)
    return out


def save(frames, path):
    final = frames[-1]
    sh = shimmer(final)
    seq = [final] + frames + sh          # frame 0 complete -> Outlook desktop shows full signature
    dur = [20] + [55] * len(frames) + [45] * len(sh)
    dur[len(frames)] = 700                           # pause on the built signature before the shimmer
    dur[-1] = 1000
    pal = final.quantize(colors=80, method=Image.MEDIANCUT)
    q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in seq]
    q[0].save(path, save_all=True, append_images=q[1:], duration=dur, optimize=True, disposal=1)  # no loop: plays once, ends complete


if __name__ == '__main__':
    import sys
    save(frames_santoro('Hanif Hawlader', 'Fundador', 'Elegancia, hecha a mano.'), 'sig-santoro.gif')
    save(frames_hanif('Hanif Hawlader', 'Producción y dirección creativa', ''), 'sig-hanif.gif')
    frames_santoro('Hanif Hawlader', 'Fundador', 'Elegancia, hecha a mano.')[-1].save('prev-santoro.png')
    frames_hanif('Hanif Hawlader', 'Producción y dirección creativa', '')[-1].save('prev-hanif.png')
