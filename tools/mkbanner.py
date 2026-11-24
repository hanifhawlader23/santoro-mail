"""Santoro Mail · banners de firma v3: aireados, elegantes, sin marco (el marco lo pone el HTML para TODA la firma)."""
from PIL import Image, ImageDraw
import math
from mkgif import font, ease, rider, CREAM, WINE, INK, GREY
from mkhanif import face
W, H = 880, 184
LIGHTW = (176, 140, 148)

def letters(d, xy, txt, f, fill, sp, prog, bg=CREAM):
    """letter-by-letter fade-in; prog 0..1"""
    x, y = xy; n = len(txt)
    for i, ch in enumerate(txt):
        a = max(0.0, min(1.0, prog * (n + 6) / 6 - i / 6))
        col = tuple(round(bg[k] + (fill[k] - bg[k]) * a) for k in range(3))
        d.text((x, y - (1 - a) * 6), ch, font=f, fill=col)
        x += d.textlength(ch, font=f) + sp

def build(kind):
    if kind == 'hanif':
        name, nf, nsp, ny = 'HANIF HAWLADER', font(400, 42), 13, 50
        sub, sf, ssp, sy = 'FUNDADOR DE SANTORO', font(500, 14), 7, 126
    else:
        name, nf, nsp, ny = 'SANTORO', font(500, 50), 22, 42
        sub, sf, ssp, sy = 'ELEGANCIA, HECHA A MANO', font(500, 14), 7, 126
    X = 214
    def frame(p, glint=None):
        im = Image.new('RGBA', (W, H), CREAM + (255,))
        if kind == 'hanif':
            f = face(160, INK, glint=glint, glint_col=(160, 132, 124), reveal=ease(p / .5) if p < 1 else 1)
            im.alpha_composite(f, (54, 12))
        else:
            a = ease(p / .4)
            lg = rider.resize((128, 119), Image.LANCZOS)
            lg.putalpha(lg.getchannel('A').point(lambda v: int(v * a)))
            ang = 0 if p >= 1 else 3 * math.sin(p * math.pi * 2) * (1 - p)
            lg = lg.rotate(ang, resample=Image.BICUBIC, center=(60, 112))
            im.alpha_composite(lg, (44, 32 + int((1 - a) * 10)))
            if glint is not None:   # soft light passing over the rider
                band = Image.new('L', (W, H), 0); d2 = ImageDraw.Draw(band); x0 = 20 + 200 * glint
                for k in range(40): d2.line((x0 + k, 20, x0 + k - 40, 170), fill=int(90 * math.sin(math.pi * k / 40)))
                im = Image.composite(Image.new('RGBA', (W, H), (255, 252, 246, 255)), im, band)
        d = ImageDraw.Draw(im)
        g = ease((p - .15) / .3)
        if g > 0: d.line((X - 26, 92 - int(56 * g), X - 26, 92 + int(56 * g)), fill=LIGHTW, width=2)
        letters(d, (X, ny), name, nf, INK, nsp, ease((p - .25) / .45))
        u = ease((p - .55) / .3)
        if u > 0: d.line((X + 2, 112, X + 2 + int(44 * u), 112), fill=WINE, width=2)
        v = ease((p - .65) / .3)
        if v > 0: letters(d, (X + 2, sy), sub, sf, WINE, ssp, v)
        return im.convert('RGB')
    build_ = [frame(i / 34) for i in range(35)]
    final = build_[-1]
    glints = [frame(1, glint=i / 11) for i in range(12)]
    fade = [Image.blend(final, frame(0), (i + 1) / 5) for i in range(5)]
    seq = [final] + fade + build_[1:] + glints + [final]
    dur = [3000] + [70] * 5 + [75] * 34 + [55] * 12 + [300]
    pal = final.quantize(colors=72, method=Image.MEDIANCUT)
    # make sure the background is EXACTLY the HTML cream, so the banner melts into the card
    p = pal.getpalette()
    for i in range(len(p) // 3):
        if all(abs(p[i * 3 + c] - CREAM[c]) <= 6 for c in range(3)): p[i * 3:i * 3 + 3] = list(CREAM)
    pal.putpalette(p)
    q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in seq]
    q[0].save(f'sig-{kind}.gif', save_all=True, append_images=q[1:], duration=dur, loop=0, optimize=True, disposal=1)
    final.save(f'prev3-{kind}.png')

if __name__ == '__main__':
    build('hanif'); build('santoro')
