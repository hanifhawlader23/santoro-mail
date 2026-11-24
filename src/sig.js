/* ===== Santoro Mail · firmas (un solo diseño para la app web, la app nativa y el servidor) ===== */
const SIG_DEF = {
  santoro: { st: 'anim', n: 'Hanif Hawlader', r: 'Fundador', e: 'santoro@hanifhawlader.com', w: 'hanifhawlader.com', c: 'Santander · España', l: 'Elegancia, hecha a mano.',
    ph: '', ig: '', yt: '', tt: '', wa: '', li: '', cta: 'Descubre Santoro', cu: 'hanifhawlader.com',
    legal: '' },
  hanif: { st: 'anim', n: 'Hanif Hawlader', r: 'Producción y dirección creativa', e: 'contacto@hanifhawlader.com', w: 'hanifhawlader.com', c: 'Cantabria · España', l: '',
    ph: '', ig: '', yt: '', tt: '', wa: '', li: '', cta: '', cu: '',
    legal: '' }
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
  const soc = SOCIALS.filter(([f]) => s[f]).map(([f, n, label]) => `<a href="${E(sgUrl(f, s[f]))}" style="text-decoration:none;display:inline-block;margin:0 6px 0 0"><img src="${img('r-' + n + '.png')}" width="28" height="28" alt="${label}" style="display:block;width:28px;height:28px;border:0;border-radius:7px"></a>`).join('');
  const cta = s.cta && s.cu ? `<a href="${E(sgUrl('cu', s.cu))}" style="display:inline-block;background:${W};color:#F7F5E9;${FF};font-size:12px;letter-spacing:2px;text-decoration:none;padding:8px 16px;border-radius:6px">${E(s.cta).toUpperCase()} &rarr;</a>` : '';
  const socRow = soc || cta ? `<table cellpadding="0" cellspacing="0" role="presentation" style="border-collapse:collapse;width:100%;max-width:480px"><tr><td style="vertical-align:middle">${soc}</td><td style="vertical-align:middle;text-align:right">${cta}</td></tr></table>` : '';
  const foot = (s.l && st !== 'anim' ? `<div style="${FF};font-size:12px;color:${W};font-style:italic;margin-top:8px">${E(s.l)}</div>` : '')
    + (s.legal ? `<div style="${FF};font-size:10px;line-height:1.45;color:#9a948e;margin-top:10px;max-width:480px">${E(s.legal)}</div>` : '');
  const wrap = (inner) => `<table cellpadding="0" cellspacing="0" role="presentation" style="border-collapse:collapse;${FF};color:${INK};max-width:480px">${inner}</table>`;

  if (st === 'anim') {
    // Pequeña y centrada: logo animado, nombre, cargo, una línea fina, datos en 1-2 líneas, redes.
    const dot = `<span style="color:${W}">&nbsp;&nbsp;·&nbsp;&nbsp;</span>`;
    const l1 = [s.e && link('mailto:' + s.e, E(s.e)), s.w && link(sgUrl('w', s.w), E(s.w))].filter(Boolean).join(dot);
    const l2 = [s.ph && link('tel:' + String(s.ph).replace(/[^\d+]/g, ''), E(s.ph)), s.c && E(s.c)].filter(Boolean).join(dot);
    const rsoc = SOCIALS.filter(([f]) => s[f]).map(([f, n, label]) => `<a href="${E(sgUrl(f, s[f]))}" style="text-decoration:none;display:inline-block;margin:0 3px"><img src="${img('r-' + n + '.png')}" width="22" height="22" alt="${label}" style="display:block;width:22px;height:22px;border:0;border-radius:6px"></a>`).join('');
    const ctaLink = s.cta && s.cu ? `<a href="${E(sgUrl('cu', s.cu))}" style="${FF};font-size:9.5px;letter-spacing:2.5px;color:${W};text-decoration:none;border-bottom:1px solid ${W};padding-bottom:1px">${E(s.cta).toUpperCase()}&nbsp;&rarr;</a>` : '';
    const title = isS ? 'SANTORO' : E(s.n).toUpperCase();
    const sub = isS ? `${E(s.n).toUpperCase()} · ${E(s.r).toUpperCase()}` : E(s.r).toUpperCase();
    const C = 'align="center" style="text-align:center;padding-left:16px;padding-right:16px;';
    return `<table cellpadding="0" cellspacing="0" role="presentation" width="340" style="border-collapse:separate;width:340px;max-width:100%;background:#F7F5E9;border:3px double ${W};border-radius:4px;${FF};color:${INK}">
<tr><td ${C}padding-top:12px"><img src="${img('logo-' + k + '.gif')}" width="56" height="56" alt="${isS ? 'Santoro' : E(s.n)}" style="display:inline-block;width:56px;height:56px;border:0"></td></tr>
<tr><td ${C}padding-top:2px;font-size:13px;letter-spacing:4px;color:${INK}">${title}</td></tr>
<tr><td ${C}padding-top:3px;font-size:8.5px;letter-spacing:2px;color:${W}">${sub}</td></tr>
<tr><td align="center" style="padding:9px 0 0"><div style="width:36px;height:1px;line-height:1px;font-size:0;background:${W};margin:0 auto">&nbsp;</div></td></tr>
${l1 ? `<tr><td ${C}padding-top:9px;font-size:11px;line-height:1.5;color:${INK}">${l1}</td></tr>` : ''}
${l2 ? `<tr><td ${C}padding-top:1px;font-size:10.5px;line-height:1.5;color:${MUT}">${l2}</td></tr>` : ''}
${rsoc ? `<tr><td ${C}padding-top:9px">${rsoc}</td></tr>` : ''}
${ctaLink ? `<tr><td ${C}padding-top:9px">${ctaLink}</td></tr>` : ''}
${s.legal ? `<tr><td ${C}padding-top:8px;font-size:8.5px;line-height:1.4;color:#a39d97">${E(s.legal)}</td></tr>` : ''}
<tr><td style="height:12px;line-height:12px;font-size:0">&nbsp;</td></tr>
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
