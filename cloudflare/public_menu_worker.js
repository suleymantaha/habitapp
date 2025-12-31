function jsonResponse(data, init = {}) {
  const headers = new Headers(init.headers);
  headers.set('content-type', 'application/json; charset=utf-8');
  headers.set('access-control-allow-origin', '*');
  headers.set('access-control-allow-methods', 'GET,POST,PUT,OPTIONS');
  headers.set('access-control-allow-headers', 'content-type,x-edit-token');
  return new Response(JSON.stringify(data), { ...init, headers });
}

function textResponse(text, init = {}) {
  const headers = new Headers(init.headers);
  headers.set('content-type', 'text/html; charset=utf-8');
  return new Response(text, { ...init, headers });
}

function badRequest(message) {
  return jsonResponse({ error: message }, { status: 400 });
}

function notFound() {
  return jsonResponse({ error: 'Not found' }, { status: 404 });
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function randomToken() {
  const bytes = new Uint8Array(18);
  crypto.getRandomValues(bytes);
  return btoa(String.fromCharCode(...bytes)).replaceAll('=', '').replaceAll('+', '-').replaceAll('/', '_');
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const pathname = url.pathname;

    if (request.method === 'OPTIONS') {
      return jsonResponse({ ok: true });
    }

    if (request.method === 'POST' && pathname === '/api/menus') {
      let body;
      try {
        body = await request.json();
      } catch (_) {
        return badRequest('Invalid JSON');
      }
      if (!body || typeof body !== 'object') return badRequest('Invalid body');

      const id = crypto.randomUUID().replaceAll('-', '');
      const editToken = randomToken();
      const key = `menu:${id}`;
      await env.MENUS.put(key, JSON.stringify({ editToken, data: body }));
      return jsonResponse({ id, editToken });
    }

    if (request.method === 'PUT' && pathname.startsWith('/api/menus/')) {
      const id = pathname.substring('/api/menus/'.length);
      if (!id) return notFound();

      const key = `menu:${id}`;
      const existingRaw = await env.MENUS.get(key);
      if (!existingRaw) return notFound();
      let existing;
      try {
        existing = JSON.parse(existingRaw);
      } catch (_) {
        return notFound();
      }

      const token = request.headers.get('x-edit-token');
      if (!token || token !== existing.editToken) {
        return jsonResponse({ error: 'Unauthorized' }, { status: 401 });
      }

      let body;
      try {
        body = await request.json();
      } catch (_) {
        return badRequest('Invalid JSON');
      }
      if (!body || typeof body !== 'object') return badRequest('Invalid body');

      await env.MENUS.put(key, JSON.stringify({ editToken: existing.editToken, data: body }));
      return jsonResponse({ ok: true });
    }

    if (request.method === 'GET' && pathname.startsWith('/api/menus/')) {
      const id = pathname.substring('/api/menus/'.length);
      if (!id) return notFound();
      const key = `menu:${id}`;
      const raw = await env.MENUS.get(key);
      if (!raw) return notFound();
      let parsed;
      try {
        parsed = JSON.parse(raw);
      } catch (_) {
        return notFound();
      }
      return jsonResponse(parsed.data ?? {});
    }

    if (request.method === 'GET' && pathname.startsWith('/m/')) {
      const id = pathname.substring('/m/'.length);
      if (!id) return textResponse('Not found', { status: 404 });
      const key = `menu:${id}`;
      const raw = await env.MENUS.get(key);
      if (!raw) return textResponse('Not found', { status: 404 });
      let parsed;
      try {
        parsed = JSON.parse(raw);
      } catch (_) {
        return textResponse('Not found', { status: 404 });
      }
      const data = parsed.data ?? {};
      const title = escapeHtml(data.name ?? 'Menü');
      const dataJson = JSON.stringify(data).replaceAll('</', '<\\/');

      const html = `
        <!doctype html>
        <html>
          <head>
            <meta charset="utf-8" />
            <meta name="viewport" content="width=device-width, initial-scale=1" />
            <title>${title}</title>
            <style>
              :root { color-scheme: dark; --bg0:#070b14; --bg1:#0b1220; --card:#0f1a30; --card2:#111f3a; --line:rgba(255,255,255,0.08); --txt:#eaf1ff; --mut:rgba(234,241,255,0.72); --pri:#7aa7ff; --pri2:#60e0c2; --shadow: 0 18px 40px rgba(0,0,0,0.35); }
              * { box-sizing: border-box; }
              body { font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial; margin: 0; background: radial-gradient(900px 500px at 20% -10%, rgba(122,167,255,0.20), transparent 60%), radial-gradient(900px 500px at 80% 0%, rgba(96,224,194,0.16), transparent 55%), linear-gradient(180deg, var(--bg0), var(--bg1)); color: var(--txt); }
              a { color: inherit; text-decoration: none; }
              .wrap { max-width: 760px; margin: 0 auto; padding: 14px 14px 28px; }
              .top { position: sticky; top: 0; z-index: 10; backdrop-filter: blur(10px); background: rgba(7,11,20,0.62); border-bottom: 1px solid rgba(255,255,255,0.06); }
              .topInner { max-width: 760px; margin: 0 auto; padding: 10px 14px; display: flex; align-items: center; gap: 10px; }
              .iconBtn { width: 40px; height: 40px; border-radius: 14px; border: 1px solid rgba(255,255,255,0.10); background: rgba(255,255,255,0.06); color: var(--txt); display: inline-flex; align-items: center; justify-content: center; cursor: pointer; }
              .iconBtn:active { transform: translateY(1px); }
              .titleBox { min-width: 0; display: flex; flex-direction: column; gap: 2px; }
              .h1 { font-size: 16px; font-weight: 900; letter-spacing: 0.2px; margin: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
              .sub { font-size: 12px; color: var(--mut); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
              .badge { margin-left: auto; font-size: 12px; color: rgba(234,241,255,0.82); padding: 7px 10px; border-radius: 999px; background: linear-gradient(90deg, rgba(122,167,255,0.18), rgba(96,224,194,0.14)); border: 1px solid rgba(255,255,255,0.10); }
              .grid { display: grid; grid-template-columns: 1fr; gap: 12px; padding-top: 14px; }
              @media (min-width: 560px) { .grid { grid-template-columns: 1fr 1fr; } }
              .card { background: linear-gradient(180deg, var(--card), var(--card2)); border: 1px solid rgba(255,255,255,0.10); border-radius: 18px; padding: 14px; box-shadow: var(--shadow); }
              .tile { display: flex; align-items: center; gap: 12px; cursor: pointer; }
              .glyph { width: 44px; height: 44px; border-radius: 16px; background: rgba(122,167,255,0.12); border: 1px solid rgba(255,255,255,0.10); display:flex; align-items:center; justify-content:center; color: var(--pri); font-weight: 900; }
              .tileMain { min-width: 0; flex: 1; }
              .tileTitle { font-weight: 950; letter-spacing: 0.2px; margin: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
              .tileMeta { margin-top: 4px; color: var(--mut); font-size: 12px; }
              .chev { color: rgba(234,241,255,0.7); font-size: 20px; }
              .listCard { background: linear-gradient(180deg, rgba(15,26,48,0.85), rgba(17,31,58,0.85)); border: 1px solid rgba(255,255,255,0.10); border-radius: 18px; overflow: hidden; box-shadow: var(--shadow); }
              .item { padding: 14px; border-bottom: 1px solid rgba(255,255,255,0.08); }
              .item:last-child { border-bottom: 0; }
              .itemHead { display: flex; gap: 12px; align-items: flex-start; }
              .thumb { width: 56px; height: 56px; border-radius: 16px; object-fit: cover; flex: 0 0 auto; border: 1px solid rgba(255,255,255,0.10); background: rgba(255,255,255,0.06); }
              .thumb.ph { display: inline-flex; align-items: center; justify-content: center; color: rgba(234,241,255,0.55); font-weight: 900; }
              .itemBody { min-width: 0; flex: 1; }
              .row { display: flex; gap: 10px; justify-content: space-between; align-items: baseline; }
              .name { font-weight: 950; letter-spacing: 0.2px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
              .price { color: #b9d2ff; font-weight: 950; white-space: nowrap; }
              .desc { margin-top: 6px; color: rgba(234,241,255,0.78); line-height: 1.35; }
              .empty { padding: 16px; color: rgba(234,241,255,0.78); text-align: center; }
              .foot { margin-top: 16px; font-size: 12px; opacity: 0.7; text-align: center; }
              #outlet { position: relative; }
              #outlet { perspective: 1200px; }
              .view { position: relative; transform-style: preserve-3d; backface-visibility: hidden; opacity: 0; transition: transform 340ms cubic-bezier(0.2, 0.9, 0.2, 1), opacity 340ms ease; will-change: transform, opacity; }
              .view.fwd { transform-origin: 0% 50%; transform: translateX(18px) rotateY(-10deg) translateY(8px) scale(0.995); }
              .view.back { transform-origin: 100% 50%; transform: translateX(-18px) rotateY(10deg) translateY(8px) scale(0.995); }
              .view.in { transform: translateX(0) rotateY(0) translateY(0) scale(1); opacity: 1; }
              .view.out.fwd { transform: translateX(-18px) rotateY(10deg) translateY(-6px) scale(0.995); opacity: 0; }
              .view.out.back { transform: translateX(18px) rotateY(-10deg) translateY(-6px) scale(0.995); opacity: 0; }
              @media (prefers-reduced-motion: reduce) { .view { transition: none; transform: none; opacity: 1; } .iconBtn:active { transform: none; } }
            </style>
          </head>
          <body>
            <div class="top">
              <div class="topInner">
                <button id="backBtn" class="iconBtn" aria-label="Geri" style="display:none">←</button>
                <div class="titleBox">
                  <div id="topTitle" class="h1">${title}</div>
                  <div id="topSub" class="sub">Menü</div>
                </div>
                <div id="topBadge" class="badge">Hazır</div>
              </div>
            </div>
            <div class="wrap">
              <div id="outlet"></div>
              <div class="foot">whatsapp_catalog ile oluşturuldu</div>
            </div>
            <script>
              const DATA = ${dataJson};

              function esc(v) {
                return String(v ?? '')
                  .replaceAll('&', '&amp;')
                  .replaceAll('<', '&lt;')
                  .replaceAll('>', '&gt;')
                  .replaceAll('"', '&quot;')
                  .replaceAll("'", '&#39;');
              }

              function normalizeText(v) {
                return typeof v === 'string' ? v.trim() : '';
              }

              function photoSrcOf(it) {
                const raw = normalizeText(it?.photoDataUrl);
                if (!raw) return '';
                if (!raw.startsWith('data:image/')) return '';
                if (raw.length > 900_000) return '';
                return raw;
              }

              function sectionOf(it) {
                const s = normalizeText(it?.section);
                return s ? s : 'Menü';
              }

              function subsectionOf(it) {
                return normalizeText(it?.subsection);
              }

              function buildTree(items) {
                const tree = new Map();
                for (const it of items) {
                  const sec = sectionOf(it);
                  const sub = subsectionOf(it);
                  if (!tree.has(sec)) tree.set(sec, new Map());
                  const subs = tree.get(sec);
                  const key = sub || '';
                  if (!subs.has(key)) subs.set(key, []);
                  subs.get(key).push(it);
                }
                return tree;
              }

              const currency = normalizeText(DATA?.currencyCode);
              const items = Array.isArray(DATA?.items) ? DATA.items : [];
              const tree = buildTree(items);

              const outlet = document.getElementById('outlet');
              const backBtn = document.getElementById('backBtn');
              const topTitle = document.getElementById('topTitle');
              const topSub = document.getElementById('topSub');
              const topBadge = document.getElementById('topBadge');
              const VIEW_MS = 340;
              let NAV_DIR = 'fwd';
              const navStack = [];

              function setHeader({ title, sub, badge, canBack }) {
                topTitle.textContent = title;
                topSub.textContent = sub;
                topBadge.textContent = badge;
                backBtn.style.display = canBack ? 'inline-flex' : 'none';
              }

              function setView(html) {
                const next = document.createElement('div');
                next.className = 'view ' + (NAV_DIR === 'back' ? 'back' : 'fwd');
                next.innerHTML = html;
                const prev = outlet.firstElementChild;
                outlet.appendChild(next);
                requestAnimationFrame(() => next.classList.add('in'));
                if (prev) {
                  prev.classList.remove('in');
                  prev.classList.add('out');
                  window.setTimeout(() => prev.remove(), VIEW_MS + 40);
                }
              }

              function sectionListView() {
                const entries = Array.from(tree.entries());
                const totalCount = items.length;
                setHeader({
                  title: normalizeText(DATA?.name) || 'Menü',
                  sub: 'Kategoriler',
                  badge: totalCount ? (totalCount + ' öğe') : 'Boş',
                  canBack: false,
                });
                if (!entries.length) {
                  setView('<div class="listCard"><div class="empty">Henüz ürün yok.</div></div>');
                  return;
                }
                const cards = entries
                  .map(([sec, subs]) => {
                    let count = 0;
                    for (const arr of subs.values()) count += arr.length;
                    const subCount = Array.from(subs.keys()).filter((k) => k && k.length).length;
                    const meta = subCount > 0 ? (subCount + ' alt menü • ' + count + ' öğe') : (count + ' öğe');
                    return \`
                      <a class="card tile" href="#/s/\${encodeURIComponent(sec)}">
                        <div class="glyph">\${esc(sec).slice(0, 1).toUpperCase()}</div>
                        <div class="tileMain">
                          <div class="tileTitle">\${esc(sec)}</div>
                          <div class="tileMeta">\${esc(meta)}</div>
                        </div>
                        <div class="chev">›</div>
                      </a>
                    \`;
                  })
                  .join('');
                setView(\`<div class="grid">\${cards}</div>\`);
              }

              function subsectionListView(sec) {
                const subs = tree.get(sec);
                if (!subs) {
                  location.hash = '';
                  return;
                }
                const keys = Array.from(subs.keys()).filter((k) => k && k.length);
                if (!keys.length) {
                  itemsListView(sec, '');
                  return;
                }
                if (keys.length === 1) {
                  itemsListView(sec, keys[0]);
                  return;
                }
                let total = 0;
                for (const arr of subs.values()) total += arr.length;
                setHeader({
                  title: sec,
                  sub: 'Alt menüler',
                  badge: total + ' öğe',
                  canBack: true,
                });
                const cards = keys
                  .map((sub) => {
                    const count = (subs.get(sub) || []).length;
                    return \`
                      <a class="card tile" href="#/s/\${encodeURIComponent(sec)}/ss/\${encodeURIComponent(sub)}">
                        <div class="glyph" style="background:rgba(96,224,194,0.10); color:var(--pri2)">\${esc(sub).slice(0, 1).toUpperCase()}</div>
                        <div class="tileMain">
                          <div class="tileTitle">\${esc(sub)}</div>
                          <div class="tileMeta">\${count} öğe</div>
                        </div>
                        <div class="chev">›</div>
                      </a>
                    \`;
                  })
                  .join('');
                setView(\`<div class="grid">\${cards}</div>\`);
              }

              function itemsListView(sec, sub) {
                const subs = tree.get(sec);
                if (!subs) {
                  location.hash = '';
                  return;
                }
                const key = sub || '';
                const arr = subs.get(key) || [];
                const title = sub ? sub : sec;
                setHeader({
                  title: title,
                  sub: sub ? sec : 'Menü',
                  badge: arr.length ? (arr.length + ' öğe') : 'Boş',
                  canBack: true,
                });
                if (!arr.length) {
                  setView('<div class="listCard"><div class="empty">Bu kategoride ürün yok.</div></div>');
                  return;
                }
                const rows = arr
                  .map((it) => {
                    const name = esc(it?.title ?? '');
                    const desc = esc(it?.description ?? '');
                    const price = it?.price;
                    const priceText = typeof price === 'number' ? esc((price + ' ' + currency).trim()) : '';
                    const photo = photoSrcOf(it);
                    const thumb = photo ? \`<img class="thumb" src="\${esc(photo)}" alt="" loading="lazy" />\` : \`<div class="thumb ph">•</div>\`;
                    return \`
                      <div class="item">
                        <div class="itemHead">
                          \${thumb}
                          <div class="itemBody">
                            <div class="row">
                              <div class="name">\${name}</div>
                              <div class="price">\${priceText}</div>
                            </div>
                            \${desc ? \`<div class="desc">\${desc}</div>\` : ''}
                          </div>
                        </div>
                      </div>
                    \`;
                  })
                  .join('');
                setView(\`<div class="listCard">\${rows}</div>\`);
              }

              function parseRoute() {
                const raw = location.hash || '';
                const h = raw.startsWith('#') ? raw.slice(1) : raw;
                const parts = h.split('/').filter(Boolean);
                if (parts.length === 0) return { kind: 'root' };
                if (parts[0] !== 's') return { kind: 'root' };
                const sec = decodeURIComponent(parts[1] || '');
                if (!sec) return { kind: 'root' };
                if (parts.length >= 4 && parts[2] === 'ss') {
                  const sub = decodeURIComponent(parts.slice(3).join('/') || '');
                  return { kind: 'items', sec, sub };
                }
                return { kind: 'subsections', sec };
              }

              function render() {
                const h = location.hash || '';
                if (navStack.length === 0) {
                  navStack.push(h);
                  NAV_DIR = 'fwd';
                } else if (navStack.length >= 2 && h === navStack[navStack.length - 2]) {
                  navStack.pop();
                  NAV_DIR = 'back';
                } else if (h !== navStack[navStack.length - 1]) {
                  navStack.push(h);
                  NAV_DIR = 'fwd';
                }
                const r = parseRoute();
                if (r.kind === 'root') return sectionListView();
                if (r.kind === 'subsections') return subsectionListView(r.sec);
                if (r.kind === 'items') return itemsListView(r.sec, r.sub);
                return sectionListView();
              }

              backBtn.addEventListener('click', () => history.back());
              window.addEventListener('hashchange', render);
              render();
            </script>
          </body>
        </html>
      `;
      return textResponse(html);
    }

    return notFound();
  },
};
