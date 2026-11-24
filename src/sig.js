/* ===== Santoro Mail · firmas (un solo diseño para la app web, la app nativa y el servidor) ===== */
const SIG_DEF = {
  santoro: { st: 'anim', n: 'Hanif Hawlader', r: 'Fundador', e: 'santoro@hanifhawlader.com', w: 'hanifhawlader.com', c: 'Santander · España', l: 'Elegancia, hecha a mano.',
    ph: '', ig: '', yt: '', tt: '', wa: '', li: '', cta: 'Descubre Santoro', cu: 'hanifhawlader.com',
    legal: 'Este mensaje y sus adjuntos son confidenciales. Si lo has recibido por error, avísanos y elimínalo.' },
  hanif: { st: 'anim', n: 'Hanif Hawlader', r: 'Producción y dirección creativa', e: 'contacto@hanifhawlader.com', w: 'hanifhawlader.com', c: 'Cantabria · España', l: '',
    ph: '', ig: '', yt: '', tt: '', wa: '', li: '', cta: '', cu: '',
    legal: 'Este mensaje y sus adjuntos son confidenciales. Si lo has recibido por error, avísame y elimínalo.' }
};
const BRANDV = __BRANDV_JSON__;   // versión de cada imagen: los móviles no se quedan con la vieja
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
  const soc = SOCIALS.filter(([f]) => s[f]).map(([f, n, label]) => `<a href="${E(sgUrl(f, s[f]))}" style="text-decoration:none;display:inline-block;margin:0 6px 0 0"><img src="${img('s-' + n + '.png')}" width="28" height="28" alt="${label}" style="display:block;width:28px;height:28px;border:0"></a>`).join('');
  const cta = s.cta && s.cu ? `<a href="${E(sgUrl('cu', s.cu))}" style="display:inline-block;background:${W};color:#F7F5E9;${FF};font-size:12px;letter-spacing:2px;text-decoration:none;padding:8px 16px;border-radius:6px">${E(s.cta).toUpperCase()} &rarr;</a>` : '';
  const socRow = soc || cta ? `<table cellpadding="0" cellspacing="0" role="presentation" style="border-collapse:collapse;width:100%;max-width:480px"><tr><td style="vertical-align:middle">${soc}</td><td style="vertical-align:middle;text-align:right">${cta}</td></tr></table>` : '';
  const foot = (s.l && st !== 'anim' ? `<div style="${FF};font-size:12px;color:${W};font-style:italic;margin-top:8px">${E(s.l)}</div>` : '')
    + (s.legal ? `<div style="${FF};font-size:10px;line-height:1.45;color:#9a948e;margin-top:10px;max-width:480px">${E(s.legal)}</div>` : '');
  const wrap = (inner) => `<table cellpadding="0" cellspacing="0" role="presentation" style="border-collapse:collapse;${FF};color:${INK};max-width:480px">${inner}</table>`;

  if (st === 'anim') {
    // Toda la firma dentro de un único marco: banner animado + datos + redes + aviso, con mucho aire.
    const line = (n, h) => `<tr><td style="padding:0 0 7px 0;${FF};font-size:12px;letter-spacing:.3px;color:${INK};white-space:nowrap">${ico(n, 13)}&nbsp;&nbsp;&nbsp;${h}</td></tr>`;
    const osoc = SOCIALS.filter(([f]) => s[f]).map(([f, n, label]) => `<a href="${E(sgUrl(f, s[f]))}" style="text-decoration:none;display:inline-block;margin:0 8px 0 0"><img src="${img('o-' + n + '.png')}" width="24" height="24" alt="${label}" style="display:block;width:24px;height:24px;border:0"></a>`).join('');
    const ctaLink = s.cta && s.cu ? `<a href="${E(sgUrl('cu', s.cu))}" style="${FF};font-size:10.5px;letter-spacing:3px;color:${W};text-decoration:none;border-bottom:1px solid ${W};padding-bottom:2px;white-space:nowrap">${E(s.cta).toUpperCase()}&nbsp;&rarr;</a>` : '';
    const who = isS ? `<span style="font-size:14px;color:${INK}">${E(s.n)}</span><span style="font-size:12px;color:${MUT}">&nbsp;&nbsp;·&nbsp;&nbsp;${E(s.r)}</span>`
                    : `<span style="font-size:12.5px;color:${MUT};letter-spacing:.3px">${E(s.r)}</span>`;
    const row = (inner, pt) => `<tr><td width="24%" style="width:24%;padding:0"></td><td style="padding:${pt}px 22px 0 0">${inner}</td></tr>`;
    return `<table cellpadding="0" cellspacing="0" role="presentation" width="480" style="border-collapse:separate;width:480px;max-width:100%;background:#F7F5E9;border:3px double ${W};border-radius:3px;${FF};color:${INK}">
<tr><td style="padding:14px 18px 0 18px"><img src="${img('sig-' + k + '.gif')}" width="440" alt="${E(s.n)} · ${isS ? 'Santoro' : 'Hanif Hawlader'}" style="display:block;width:440px;max-width:100%;height:auto;border:0"></td></tr>
<tr><td style="padding:0 18px"><table cellpadding="0" cellspacing="0" role="presentation" width="100%" style="border-collapse:collapse;width:100%">
${row(who, 4)}
${row(`<table cellpadding="0" cellspacing="0" role="presentation" style="border-collapse:collapse">${items.map(([n, h]) => line(n, h)).join('')}</table>`, 16)}
${osoc ? row(`<div style="white-space:nowrap">${osoc}</div>`, 10) : ''}
${ctaLink ? row(ctaLink, osoc ? 14 : 10) : ''}
</table></td></tr>
${s.legal ? `<tr><td style="padding:18px 22px 16px 22px"><div style="border-top:1px solid #e2d8d0;padding-top:10px;${FF};font-size:9.5px;line-height:1.5;color:#a39d97">${E(s.legal)}</div></td></tr>` : '<tr><td style="height:16px"></td></tr>'}
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
