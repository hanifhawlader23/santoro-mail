/* ===== Santoro Mail · firmas (un solo diseño para la app web, la app nativa y el servidor) ===== */
const SIG_DEF = {
  santoro: { st: 'anim', n: 'Hanif Hawlader', r: 'Fundador', e: 'santoro@hanifhawlader.com', w: 'hanifhawlader.com', c: 'Santander · España', l: 'Elegancia, hecha a mano.',
    ph: '', ig: '', yt: '', tt: '', wa: '', li: '', cta: 'Descubre Santoro', cu: 'hanifhawlader.com',
    legal: '' },
  hanif: { st: 'anim', n: 'Hanif Hawlader', r: 'Producción y dirección creativa', e: 'contacto@hanifhawlader.com', w: 'hanifhawlader.com', c: 'Cantabria · España', l: '',
    ph: '', ig: '', yt: '', tt: '', wa: '', li: '', cta: '', cu: '',
    legal: '' }
};
const BRANDV = __BRANDV_JSON__;
if (typeof window !== 'undefined') window.BRANDV = BRANDV;   // versión de cada imagen: los móviles no se quedan con la vieja
const SOCIALS = [['ig', 'instagram', 'Instagram'], ['yt', 'youtube', 'YouTube'], ['tt', 'tiktok', 'TikTok'], ['wa', 'whatsapp', 'WhatsApp'], ['li', 'linkedin', 'LinkedIn']];
function sgEsc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])); }
function sgUrl(f, v) {
  v = String(v || '').trim(); if (!v) return '';
  if (/^https?:\/\//i.test(v)) return v;
  const h = v.replace(/^@/, '');
  return f === 'ig' ? 'https://instagram.com/' + h : f === 'yt' ? 'https://youtube.com/@' + h : f === 'tt' ? 'https://www.tiktok.com/@' + h
    : f === 'wa' ? 'https://wa.me/' + h.replace(/[^\d]/g, '') : f === 'li' ? 'https://www.linkedin.com/in/' + h : f === 'w' || f === 'cu' ? 'https://' + h.replace(/^\/+/, '') : v;
}
/* s = datos, k = 'santoro' | 'hanif', img(nombre) = URL de /brand/<nombre>, av = URL de la foto de perfil (o null) */
function sigMarkup(s0, k, img, av) {
  const s = Object.assign({}, SIG_DEF[k] || SIG_DEF.santoro, s0 || {}), st = s.st || 'anim', E = sgEsc;
  const W = '#5B1A2C', INK = '#1C1A17', MUT = '#6b6560', FF = "font-family:'El Messiri',Georgia,'Times New Roman',serif";
  const isS = k === 'santoro';
  const link = (u, txt) => `<a href="${E(u)}" style="color:${INK};text-decoration:none">${txt}</a>`;
  const ico = (n, sz) => `<img src="${img('c-' + n + '.png')}" width="${sz}" height="${sz}" alt="" style="display:inline-block;width:${sz}px;height:${sz}px;border:0;vertical-align:-3px">`;
  const items = [
    s.e && ['mail', link('mailto:' + s.e, E(s.e))],
    s.w && ['web', link(sgUrl('w', s.w), E(s.w))],
    s.ph && ['phone', link('tel:' + String(s.ph).replace(/[^\d+]/g, ''), E(s.ph))],
    s.c && ['pin', `<span style="color:${MUT}">${E(s.c)}</span>`]
  ].filter(Boolean);
  const contactGrid = items.length ? `<table cellpadding="0" cellspacing="0" role="presentation" style="border-collapse:collapse;${FF};font-size:12.5px;color:${INK}">${
    items.reduce((rows, it, i) => { if (i % 2 === 0) rows.push([]); rows[rows.length - 1].push(it); return rows; }, []).map(r =>
      `<tr>${r.map(([n, h]) => `<td style="padding:3px 18px 3px 0;white-space:nowrap">${ico(n, 16)}&nbsp;&nbsp;${h}</td>`).join('')}</tr>`).join('')}</table>` : '';
  const soc = SOCIALS.filter(([f]) => s[f]).map(([f, n, label]) => `<a href="${E(sgUrl(f, s[f]))}" style="text-decoration:none;display:inline-block;margin:0 6px 0 0"><img src="${img('r-' + n + '.png')}" width="28" height="28" alt="${label}" style="display:block;width:28px;height:28px;border:0;border-radius:7px"></a>`).join('');
  const cta = s.cta && s.cu ? `<a href="${E(sgUrl('cu', s.cu))}" style="display:inline-block;background:${W};color:#F7F5E9;${FF};font-size:12px;letter-spacing:2px;text-decoration:none;padding:8px 16px;border-radius:6px">${E(s.cta).toUpperCase()} &rarr;</a>` : '';
  const socRow = soc || cta ? `<table cellpadding="0" cellspacing="0" role="presentation" style="border-collapse:collapse;width:100%;max-width:480px"><tr><td style="vertical-align:middle">${soc}</td><td style="vertical-align:middle;text-align:right">${cta}</td></tr></table>` : '';
  const foot = (s.l && st !== 'anim' ? `<div style="${FF};font-size:12px;color:${W};font-style:italic;margin-top:8px">${E(s.l)}</div>` : '')
    + (s.legal ? `<div style="${FF};font-size:10px;line-height:1.45;color:#9a948e;margin-top:10px;max-width:480px">${E(s.legal)}</div>` : '');
  const wrap = (inner) => `<table cellpadding="0" cellspacing="0" role="presentation" style="border-collapse:collapse;${FF};color:${INK};max-width:480px">${inner}</table>`;

  if (st === 'anim') {
    // Tarjeta vino: igual en modo claro y oscuro. Cabecera animada (logo + nombre + cargo, en El Messiri) que lleva a la web.
    const CR = '#F7F5E9', RO = '#D9B8BF', web = s.w ? sgUrl('w', s.w) : '';
    const rows = s.rows && s.rows.v ? s.rows : null;                    // filas en imagen El Messiri (las genera la app)
    const rowImg = (r, href, alt) => `<tr><td align="center" style="padding:2px 0 0;text-align:center">${href ? `<a href="${E(href)}" style="text-decoration:none">` : ''}<img src="${img('sigimg-' + k + '-' + r + '.png')}&r=${rows.v}" width="350" height="26" alt="${E(alt)}" style="display:block;width:350px;max-width:100%;height:auto;border:0">${href ? '</a>' : ''}</td></tr>`;
    const rowTxt = (href, txt, col) => `<tr><td align="center" style="padding:3px 16px 0;text-align:center;${FF};font-size:12px;letter-spacing:1px;color:${col}">${href ? `<a href="${E(href)}" style="color:${col};text-decoration:none">${txt}</a>` : txt}</td></tr>`;
    const loc = [s.c, s.ph].filter(Boolean).join('  ·  ');
    const info = rows
      ? (s.e ? rowImg('mail', 'mailto:' + s.e, s.e) : '') + (s.w ? rowImg('web', web, s.w) : '') + (loc ? rowImg('loc', s.ph ? 'tel:' + String(s.ph).replace(/[^\d+]/g, '') : '', loc) : '')
      : (s.e ? rowTxt('mailto:' + s.e, E(s.e), CR) : '') + (s.w ? rowTxt(web, E(s.w), CR) : '') + (loc ? rowTxt('', E(loc), RO) : '');
    const wsoc = SOCIALS.filter(([f]) => s[f]).map(([f, n, label]) => `<a href="${E(sgUrl(f, s[f]))}" style="text-decoration:none;display:inline-block;margin:0 4px"><img src="${img('w-' + n + '.png')}" width="26" height="26" alt="${label}" style="display:block;width:26px;height:26px;border:0"></a>`).join('');
    const ctaLink = s.cta && s.cu ? `<a href="${E(sgUrl('cu', s.cu))}" style="${FF};font-size:10px;letter-spacing:3px;color:${CR};text-decoration:none;border-bottom:1px solid ${RO};padding-bottom:2px">${E(s.cta).toUpperCase()}&nbsp;&rarr;</a>` : '';
    return `<table cellpadding="0" cellspacing="0" role="presentation" width="350" bgcolor="#5B1A2C" style="border-collapse:separate;width:350px;max-width:100%;background:#5B1A2C;border-radius:14px;${FF};color:${CR}">
<tr><td align="center" style="padding:0;text-align:center">${web ? `<a href="${E(web)}" style="text-decoration:none">` : ''}<img src="${img('head-' + k + '.gif')}" width="350" height="150" alt="${isS ? 'Santoro' : E(s.n)} · ${E(s.r)}" style="display:block;width:350px;max-width:100%;height:auto;border:0;border-radius:14px 14px 0 0">${web ? '</a>' : ''}</td></tr>
${info}
${wsoc ? `<tr><td align="center" style="padding:14px 0 0;text-align:center">${wsoc}</td></tr>` : ''}
${ctaLink ? `<tr><td align="center" style="padding:14px 0 0;text-align:center">${ctaLink}</td></tr>` : ''}
${s.legal ? `<tr><td align="center" style="padding:10px 18px 0;text-align:center;font-size:8.5px;line-height:1.4;color:${RO}">${E(s.legal)}</td></tr>` : ''}
<tr><td style="height:16px;line-height:16px;font-size:0">&nbsp;</td></tr>
</table>`;
  }
  const pic = av ? `<img src="${E(av)}" width="76" height="76" alt="" style="display:block;width:76px;height:76px;border-radius:14px;object-fit:cover;border:0">`
    : `<img src="${img(isS ? 'av-santoro.gif' : 'av-hanif.gif')}" width="76" height="76" alt="" style="display:block;width:76px;height:76px;border-radius:14px;border:0">`;
  const head = isS
    ? `<div style="font-size:17px;color:${INK}">${E(s.n)}</div><div style="font-size:10.5px;letter-spacing:3px;color:${W};margin:3px 0 8px">${E(s.r).toUpperCase()} · SANTORO</div>`
    : `<div style="font-size:16px;letter-spacing:3px;color:${INK}">${E(s.n).toUpperCase()}</div><div style="width:34px;height:1px;background:${W};margin:6px 0"></div><div style="font-size:12.5px;color:${MUT};margin-bottom:6px">${E(s.r)}</div>`;

  if (st === 'card') return wrap(
    `<tr><td style="background:#F7F5E9;border:1px solid #e4dcd2;border-left:4px solid ${W};border-radius:12px;padding:16px 18px">
      <table cellpadding="0" cellspacing="0" role="presentation" style="border-collapse:collapse"><tr>
       <td style="vertical-align:top;padding-right:16px">${pic}</td>
       <td style="vertical-align:top">${head}${contactGrid}</td></tr></table>
      ${socRow ? `<div style="margin-top:12px">${socRow}</div>` : ''}</td></tr>`
    + (foot ? `<tr><td style="padding:0 4px">${foot}</td></tr>` : ''));

  if (st === 'min') return `<div style="${FF};color:${INK};font-size:13px;line-height:1.55"><b style="font-weight:500">${E(s.n)}</b> <span style="color:${W}">—</span> ${E(s.r)}${isS ? ' · Santoro' : ''}<br><span style="font-size:12px;color:${MUT}">${E(s.e)}${s.w ? ' · ' + E(s.w) : ''}${s.ph ? ' · ' + E(s.ph) : ''}</span>${soc ? `<div style="margin-top:8px">${soc}</div>` : ''}${s.legal ? `<div style="font-size:10px;color:#9a948e;margin-top:8px">${E(s.legal)}</div>` : ''}</div>`;

  // clásica
  const mark = isS ? `<img src="${img('rider-wine.png')}" width="58" alt="Santoro" style="display:block;border:0">` : pic.replace(/76/g, '62');
  return wrap(`<tr><td style="padding-right:18px;border-right:1px solid ${W};vertical-align:middle">${mark}</td><td style="padding-left:18px;vertical-align:middle">${head}${contactGrid}</td></tr>`
    + (socRow ? `<tr><td colspan="2" style="padding-top:12px">${socRow}</td></tr>` : '')
    + (foot ? `<tr><td colspan="2">${foot}</td></tr>` : ''));
}
