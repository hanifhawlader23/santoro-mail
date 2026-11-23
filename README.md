# Santoro Mail

Correo de Hanif Hawlader / Santoro sobre Microsoft 365, con seguimiento de aperturas, alias, plantillas, automatizaciones y emails de marca.

- `src/` — código fuente (interfaz `app.html`, modo real `live.js`, servidor `worker.tpl.js`).
- `python3 build.py` — genera `worker.js`.
- Cloudflare despliega `worker.js` automáticamente con cada cambio en `main` (`wrangler.jsonc`).
- Secretos (en Cloudflare, nunca en el repositorio): `CLIENT_SECRET`, `ANTHROPIC_API_KEY` (opcional), `WEBHOOK_KEY` (opcional).
