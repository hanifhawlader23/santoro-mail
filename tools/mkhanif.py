"""Hanif Hawlader monogram: animated profile GIF + animated signature banner (loops)."""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math
from mkgif import deco, rider, font, spaced, width, ease, shimmer, fadeout, CREAM, WINE, INK, GREY, W, H
MASK = Image.open('mono-mask.png')           # alpha = lines (1260x1989)
LENS = [(165, 915, 515, 1195), (690, 915, 1045, 1195)]
DARK = (28, 26, 23)

def face(h, line, glint=None, glint_col=(255, 255, 255), reveal=1.0, band=None):
    """render monogram at height h. glint: 0..1 position of lens reflection. reveal: top->bottom draw-in. band: 0..1 light band"""
    s = h / MASK.height
    m = MASK.resize((round(MASK.width * s), h), Image.LANCZOS)
    lay = Image.new('RGBA', m.size, (0, 0, 0, 0))
    if glint is not None and 0 <= glint <= 1:
        g = Image.new('L', m.size, 0); d = ImageDraw.Draw(g)
        for (x0, y0, x1, y1) in LENS:
            x0, y0, x1, y1 = [v * s for v in (x0, y0, x1, y1)]
            cx = x0 - (x1 - x0) * .6 + (x1 - x0) * 2.2 * glint
            wdt = (x1 - x0) * .16
            clip = Image.new('L', m.size, 0); ImageDraw.Draw(clip).rectangle((x0, y0, x1, y1), fill=255)
            st = Image.new('L', m.size, 0); sd = ImageDraw.Draw(st)
            sd.polygon([(cx, y0), (cx + wdt, y0), (cx + wdt - (y1 - y0) * .5, y1), (cx - (y1 - y0) * .5, y1)], fill=150)
            sd.polygon([(cx + wdt * 1.6, y0), (cx + wdt * 2.0, y0), (cx + wdt * 2.0 - (y1 - y0) * .5, y1), (cx + wdt * 1.6 - (y1 - y0) * .5, y1)], fill=90)
            st = st.filter(ImageFilter.GaussianBlur(max(1, wdt * .15)))
            g.paste(st, (0, 0), clip)
        lay.paste(glint_col + (255,), (0, 0), g)
    col = Image.new('RGBA', m.size, line + (255,))
    if band is not None and 0 <= band <= 1:          # soft light band travelling down the lines
        b = Image.new('L', m.size, 0); d = ImageDraw.Draw(b); yc = -80 * s * 10 + (m.height + 160 * s * 10) * band
        for k in range(60):
            v = int(150 * math.sin(math.pi * k / 60)); y = yc - 30 + k * (m.height / 400)
            d.rectangle((0, y, m.width, y + m.height / 400 + 1), fill=v)
        b = b.filter(ImageFilter.GaussianBlur(6))
        col = Image.composite(Image.new('RGBA', m.size, (255, 255, 255, 255)), col, b)
    a = m
    if reveal < 1:
        rv = Image.new('L', m.size, 0); ImageDraw.Draw(rv).rectangle((0, 0, m.width, int(m.height * reveal)), fill=255)
        rv = rv.filter(ImageFilter.GaussianBlur(10))
        a = Image.composite(m, Image.new('L', m.size, 0), rv)
    lay.paste(col, (0, 0), a)
    return lay

def avatar(path, S=240, n=52):
    frames = []
    for i in range(n):
        p = i / n
        im = Image.new('RGBA', (S, S), DARK + (255,))
        gl = (p - .12) / .28
        bd = (p - .5) / .42
        f = face(int(S * .9), CREAM, glint=gl if 0 <= gl <= 1 else None, band=bd if 0 <= bd <= 1 else None)
        im.alpha_composite(f, ((S - f.width) // 2, int(S * .06)))
        frames.append(im.convert('RGB'))
    pal = frames[0].quantize(colors=24, method=Image.MEDIANCUT)
    q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
    q[0].save(path, save_all=True, append_images=q[1:], duration=[1400] + [85] * (n - 1), loop=0, optimize=True, disposal=1)

def sig(path, name='Hanif Hawlader', role='Producción y dirección creativa', tag='FUNDADOR DE SANTORO'):
    big, mid, small = font(500, 48), font(400, 23), font(500, 18)
    sp = 11; X = 250
    t_name = Image.new('RGBA', (W, H)); spaced(ImageDraw.Draw(t_name), (X, 34), name.upper(), big, INK, sp)
    t_role = Image.new('RGBA', (W, H)); ImageDraw.Draw(t_role).text((X + 2, 122), role, font=mid, fill=GREY)
    t_tag = Image.new('RGBA', (W, H)); spaced(ImageDraw.Draw(t_tag), (X + 2, 166), tag, small, WINE, 6)
    nw = width(name.upper(), big, sp)
    def frame(p, glint=None):
        im = Image.new('RGBA', (W, H), CREAM + (255,))
        f = face(184, INK, glint=glint, glint_col=(150, 120, 110), reveal=ease(p / .55) if p < 1 else 1)
        im.alpha_composite(f, (80, 18))
        d = ImageDraw.Draw(im)
        g = ease((p - .2) / .3)
        if g > 0: d.rectangle((222, 110 - int(86 * g), 223, 110 + int(86 * g)), fill=WINE)
        wv = ease((p - .3) / .4)
        if wv > 0:
            m = Image.new('L', (W, H), 0); ImageDraw.Draw(m).rectangle((0, 0, X + int((nw + 10) * wv), H), fill=255)
            im.paste(t_name, (0, 0), Image.composite(t_name, Image.new('RGBA', (W, H)), m).getchannel('A'))
        u = ease((p - .5) / .3)
        if u > 0: d.rectangle((X + 2, 103, X + 2 + int(60 * u), 104), fill=WINE)
        for lay, st in ((t_role, .55), (t_tag, .72)):
            v = ease((p - st) / .28)
            if v > 0:
                l2 = lay.copy(); l2.putalpha(l2.getchannel('A').point(lambda a: int(a * v))); im.alpha_composite(l2, (0, int((1 - v) * 7)))
        a2 = ease((p - .75) / .25)
        if a2 > 0:
            lg = rider.resize((86, 80), Image.LANCZOS); lg.putalpha(lg.getchannel('A').point(lambda v: int(v * a2 * .9)))
            im.alpha_composite(lg, (W - 130, 40))
        return deco(im.convert('RGB'))
    build = [frame(i / 30) for i in range(31)]
    final = build[-1]
    glints = [frame(1, glint=i / 10) for i in range(11)]
    fo = fadeout(final, frame(0))
    seq = [final] + fo + build[1:] + glints + [final]
    dur = [2600] + [60] * len(fo) + [70] * 30 + [55] * len(glints) + [400]
    pal = final.quantize(colors=80, method=Image.MEDIANCUT)
    q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in seq]
    q[0].save(path, save_all=True, append_images=q[1:], duration=dur, loop=0, optimize=True, disposal=1)
    final.save('prev-hanif2.png')

if __name__ == '__main__':
    avatar('av-hanif.gif'); sig('sig-hanif.gif')
