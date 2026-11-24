"""Firma v7: cabecera compacta 300x120 (2x), logo SIEMPRE en movimiento, texto fijo, fondo vino opaco."""
from PIL import Image, ImageDraw
import math
from mkgif import font, rider, CREAM, WINE
from mkhanif import face
W, H = 600, 240
ROSE = (217, 184, 191)

def spaced_center(d, y, txt, f, fill, sp):
    ws = [d.textlength(c, font=f) for c in txt]; x = (W - (sum(ws) + sp * (len(txt) - 1))) / 2
    for c, w in zip(txt, ws): d.text((x, y), c, font=f, fill=fill); x += w + sp

def build(kind, name, sub, n=40):
    nf, sf = font(500, 27), font(500, 13)
    frames = []
    for i in range(n):
        t = i / n; ph = 2 * math.pi * t
        im = Image.new('RGBA', (W, H), WINE + (255,))
        if kind == 'hanif':
            gl = (t - .5) / .3
            f = face(112, CREAM, glint=gl if 0 <= gl <= 1 else None, glint_col=(255, 255, 255))
            pad = 18; big = Image.new('RGBA', (f.width + 2 * pad, f.height + 2 * pad), (0, 0, 0, 0)); big.alpha_composite(f, (pad, pad))
            big = big.rotate(2.6 * math.sin(ph), resample=Image.BICUBIC, center=(big.width / 2, pad + f.height * .96))
            im.alpha_composite(big, ((W - big.width) // 2, 14 - pad + int(1.2 * math.sin(2 * ph))))
        else:
            a = rider.getchannel('A'); cr = Image.new('RGBA', rider.size, CREAM + (255,)); cr.putalpha(a)
            cr = cr.resize((130, int(130 * cr.height / cr.width)), Image.LANCZOS)
            pad = 18; big = Image.new('RGBA', (cr.width + 2 * pad, cr.height + 2 * pad), (0, 0, 0, 0)); big.alpha_composite(cr, (pad, pad))
            big = big.rotate(4 * math.sin(ph), resample=Image.BICUBIC, center=(big.width * .45, pad + cr.height * .95))
            im.alpha_composite(big, ((W - big.width) // 2, 16 - pad + int(1.5 * math.sin(2 * ph))))
        d = ImageDraw.Draw(im)
        spaced_center(d, 146, name, nf, CREAM, 10)
        spaced_center(d, 194, sub, sf, ROSE, 6)
        frames.append(im.convert('RGB'))
    pal = frames[0].quantize(colors=32, method=Image.MEDIANCUT)
    p_ = pal.getpalette()
    for i in range(len(p_) // 3):
        if all(abs(p_[i*3+c] - WINE[c]) <= 6 for c in range(3)): p_[i*3:i*3+3] = list(WINE)
    pal.putpalette(p_)
    q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
    q[0].save(f'head-{kind}.gif', save_all=True, append_images=q[1:], duration=95, loop=0, optimize=True, disposal=1)
    frames[0].save(f'head-{kind}.png')

if __name__ == '__main__':
    build('hanif', 'HANIF HAWLADER', 'FUNDADOR DE SANTORO')
    build('santoro', 'SANTORO', 'HANIF HAWLADER · FUNDADOR')
