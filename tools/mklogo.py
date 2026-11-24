"""v4: logos animados pequeños para la firma + avatares (cabeza que se balancea, moneda Santoro <-> Hanif)."""
from PIL import Image, ImageDraw
import math
from mkgif import rider, CREAM, WINE, INK
from mkhanif import face, DARK

def q_save(frames, path, dur, colors=40, bg=None):
    m = Image.new('RGB', (frames[0].width * 2, frames[0].height)); m.paste(frames[0], (0, 0)); m.paste(frames[len(frames) // 2], (frames[0].width, 0))
    pal = m.quantize(colors=colors, method=Image.MEDIANCUT)
    if bg:
        p = pal.getpalette()
        for i in range(len(p) // 3):
            if all(abs(p[i*3+c] - bg[c]) <= 6 for c in range(3)): p[i*3:i*3+3] = list(bg)
        pal.putpalette(p)
    q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
    q[0].save(path, save_all=True, append_images=q[1:], duration=dur, loop=0, optimize=True, disposal=1)

AMP = 3.2
def sway_face(S, bg, line, n=44, glint_col=(255, 255, 255), scale=.86):
    fr = []
    for i in range(n):
        ph = 2 * math.pi * i / n
        ang = AMP * math.sin(ph)                       # gentle head sway
        gl = (i / n - .55) / .3
        f = face(int(S * scale), line, glint=gl if 0 <= gl <= 1 else None, glint_col=glint_col)
        pad = int(f.height * .12)                      # room so the hair is never cut while it sways
        big = Image.new('RGBA', (f.width + 2 * pad, f.height + 2 * pad), (0, 0, 0, 0)); big.alpha_composite(f, (pad, pad))
        big = big.rotate(ang, resample=Image.BICUBIC, center=(big.width / 2, pad + f.height * .96))
        im = Image.new('RGBA', (S, S), bg + (255,))
        im.alpha_composite(big, ((S - big.width) // 2, int(S * (1 - scale) / 2) - pad + int(1.5 * math.sin(2 * ph))))
        fr.append(im.convert('RGB'))
    return fr

def rock_rider(S, bg, n=40, size=.78, col=None):
    fr = []
    src = rider
    if col:
        a = rider.getchannel('A'); src = Image.new('RGBA', rider.size, col + (255,)); src.putalpha(a)
    base = src.resize((int(S * size), int(S * size * src.height / src.width)), Image.LANCZOS)
    for i in range(n):
        ph = 2 * math.pi * i / n
        r = base.rotate(4 * math.sin(ph), resample=Image.BICUBIC, center=(base.width * .45, base.height * .95))
        im = Image.new('RGBA', (S, S), bg + (255,))
        im.alpha_composite(r, ((S - r.width) // 2, (S - r.height) // 2 + int(2 * math.sin(2 * ph))))
        fr.append(im.convert('RGB'))
    return fr

def coin(S=240, flip=9):
    """moneda: monograma Hanif (negro) <-> jinete Santoro (vino), girando como una ficha"""
    A = Image.new('RGBA', (S, S), DARK + (255,)); f = face(int(S * .86), CREAM); A.alpha_composite(f, ((S - f.width) // 2, int(S * .07)))
    B = Image.new('RGBA', (S, S), WINE + (255,))
    cr = rider.copy(); a = cr.getchannel('A'); cr = Image.new('RGBA', cr.size, CREAM + (255,)); cr.putalpha(a)
    cr = cr.resize((int(S * .74), int(S * .74 * cr.height / cr.width)), Image.LANCZOS); B.alpha_composite(cr, ((S - cr.width) // 2, (S - cr.height) // 2 + 6))
    A, B = A.convert('RGB'), B.convert('RGB')
    def squeeze(img, k, shade):
        w = max(2, int(S * k)); s = img.resize((w, S), Image.LANCZOS)
        if shade: s = Image.blend(s, Image.new('RGB', s.size, (0, 0, 0)), shade)
        out = Image.new('RGB', (S, S), (247, 245, 233)); out.paste(s, ((S - w) // 2, 0)); return out
    frames, dur = [A], [2200]
    for side_from, side_to in ((A, B), (B, A)):
        for i in range(1, flip + 1):
            t = i / flip; k = abs(math.cos(t * math.pi)); img = side_from if t < .5 else side_to
            frames.append(squeeze(img, k, .25 * (1 - k))); dur.append(45)
        frames.append(side_to); dur.append(2200)
    frames.pop(); dur.pop()                                # last = A again, loop continues
    return frames, dur

if __name__ == '__main__':
    # avatares
    fr = sway_face(200, DARK, CREAM, n=26); q_save(fr, 'av-hanif.gif', [120] * len(fr), 12)
    fr, d = coin(); q_save(fr, 'av-flip.gif', d, 48)
    # logos de la firma (2x: 180px -> se ve a 90px), fondo crema exacto
    globals()['AMP'] = 2.2
    fr = sway_face(160, WINE, CREAM, n=26, glint_col=(255, 255, 255), scale=.74); q_save(fr, 'logo-hanif.gif', [120] * len(fr), 12)
    globals()['AMP'] = 3.2
    fr = rock_rider(160, WINE, n=26, size=.70, col=CREAM); q_save(fr, 'logo-santoro.gif', [120] * len(fr), 12)
