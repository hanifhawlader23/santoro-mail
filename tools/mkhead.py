"""Firma v6: cabecera animada sobre vino (igual en modo claro y oscuro), todo en El Messiri."""
from PIL import Image, ImageDraw
import math
from mkgif import font, ease, rider, CREAM, WINE
from mkhanif import face
W, H = 700, 300
ROSE = (217, 184, 191)

def spaced_center(d, y, txt, f, fill, sp, prog=1.0, bg=WINE):
    widths = [d.textlength(c, font=f) for c in txt]; tw = sum(widths) + sp * (len(txt) - 1)
    x = (W - tw) / 2; n = len(txt)
    for i, ch in enumerate(txt):
        a = max(0.0, min(1.0, prog * (n + 5) / 5 - i / 5))
        col = tuple(round(bg[k] + (fill[k] - bg[k]) * a) for k in range(3))
        d.text((x, y + (1 - a) * 8), ch, font=f, fill=col); x += widths[i] + sp

def build(kind, name, sub):
    nf, sf = font(500, 31), font(500, 15)
    def frame(p, t):
        im = Image.new('RGBA', (W, H), WINE + (255,))
        ph = 2 * math.pi * t
        if kind == 'hanif':
            gl = (t - .55) / .3
            f = face(128, CREAM, glint=gl if 0 <= gl <= 1 else None, glint_col=(255, 255, 255))
            pad = 20; big = Image.new('RGBA', (f.width + 2 * pad, f.height + 2 * pad), (0, 0, 0, 0)); big.alpha_composite(f, (pad, pad))
            big = big.rotate(2.4 * math.sin(ph), resample=Image.BICUBIC, center=(big.width / 2, pad + f.height * .96))
            im.alpha_composite(big, ((W - big.width) // 2, 14 - pad))
        else:
            a = rider.getchannel('A'); cr = Image.new('RGBA', rider.size, CREAM + (255,)); cr.putalpha(a)
            cr = cr.resize((150, int(150 * cr.height / cr.width)), Image.LANCZOS)
            pad = 20; big = Image.new('RGBA', (cr.width + 2 * pad, cr.height + 2 * pad), (0, 0, 0, 0)); big.alpha_composite(cr, (pad, pad))
            big = big.rotate(3.5 * math.sin(ph), resample=Image.BICUBIC, center=(big.width * .45, pad + cr.height * .95))
            im.alpha_composite(big, ((W - big.width) // 2, 18 - pad))
        d = ImageDraw.Draw(im)
        spaced_center(d, 158, name, nf, CREAM, 11, ease(p / .55))
        spaced_center(d, 212, sub, sf, ROSE, 6, ease((p - .45) / .4))
        g = ease((p - .6) / .35)
        if g > 0: d.line((W / 2 - 34 * g, 254, W / 2 + 34 * g, 254), fill=ROSE, width=2)
        return im.convert('RGB')
    n = 46
    frames = [frame(1, 0)] + [frame(min(1, i / 30), i / n) for i in range(1, n)]
    dur = [2400] + [85] * (n - 1)
    pal = frames[0].quantize(colors=40, method=Image.MEDIANCUT)
    p_ = pal.getpalette()
    for i in range(len(p_) // 3):
        if all(abs(p_[i*3+c] - WINE[c]) <= 6 for c in range(3)): p_[i*3:i*3+3] = list(WINE)
    pal.putpalette(p_)
    q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
    q[0].save(f'head-{kind}.gif', save_all=True, append_images=q[1:], duration=dur, loop=0, optimize=True, disposal=1)
    frames[0].save(f'head-{kind}.png')

if __name__ == '__main__':
    build('hanif', 'HANIF HAWLADER', 'PRODUCCIÓN Y DIRECCIÓN CREATIVA')
    build('santoro', 'SANTORO', 'HANIF HAWLADER · FUNDADOR')
