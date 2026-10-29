// Shared data layer. Talks to Supabase when configured, otherwise runs a browser-only demo.
(function () {
  const C = window.MU_CONFIG || {};
  const live = !!(C.SUPABASE_URL && C.SUPABASE_ANON_KEY && window.supabase);
  const sb = live ? window.supabase.createClient(C.SUPABASE_URL, C.SUPABASE_ANON_KEY) : null;
  const K = { p: 'mu_demo_products', s: 'mu_demo_settings', a: 'mu_demo_admin', o: 'mu_demo_orders' };

  const rd = (k, d) => { try { const v = JSON.parse(localStorage.getItem(k)); return v == null ? d : v; } catch (e) { return d; } };
  const wr = (k, v) => {
    try { localStorage.setItem(k, JSON.stringify(v)); }
    catch (e) { throw new Error('Demo storage is full. Connect Supabase (see README) to store real photos.'); }
  };

  const ph = (emoji, c1, c2) => 'data:image/svg+xml;utf8,' + encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">' +
    '<stop offset="0" stop-color="' + c1 + '"/><stop offset="1" stop-color="' + c2 + '"/></linearGradient></defs>' +
    '<rect width="400" height="400" fill="url(#g)"/><text x="200" y="245" font-size="150" text-anchor="middle">' + emoji + '</text></svg>');

  const sample = [
    { id: 's1', name: 'Personalised Photo Frame', category: 'Personalised', price: 599, description: 'Wooden frame with your favourite memory printed and engraved with a short message.', image_url: ph('🖼️', '#FFE7CC', '#FDBA74'), stock: 12 },
    { id: 's2', name: 'Birthday Surprise Box', category: 'Birthday', price: 1299, description: 'Chocolates, a handwritten card, balloons and a small plush toy in a gift box.', image_url: ph('🎂', '#FFE4E6', '#FDA4AF'), stock: 5 },
    { id: 's3', name: 'Anniversary Rose Hamper', category: 'Anniversary', price: 1799, description: 'Fresh roses with chocolates and a scented candle, wrapped with a green ribbon.', image_url: ph('🌹', '#FEE2E2', '#FCA5A5'), stock: 2 },
    { id: 's4', name: 'Festive Dry Fruit Hamper', category: 'Festival', price: 999, description: 'Premium almonds, cashews and raisins in a reusable decorative box.', image_url: ph('🎁', '#DCFCE7', '#86EFAC'), stock: 8 },
    { id: 's5', name: 'Baby Welcome Set', category: 'Baby & Kids', price: 1499, description: 'Soft blanket, rattle and a keepsake for the newest family member.', image_url: ph('🧸', '#E0F2FE', '#7DD3FC'), stock: 0 },
    { id: 's6', name: 'Handcrafted Table Lamp', category: 'Home Décor', price: 849, description: 'Warm ambient lamp that makes a lovely housewarming present.', image_url: ph('🪔', '#FEF9C3', '#FDE047'), stock: 6 }
  ];

  // Demo extras so the new features can be tried straight away
  sample[0].images = [sample[0].image_url, ph('🎁', '#E0F2FE', '#7DD3FC'), ph('✨', '#FEF9C3', '#FDE047')];
  sample[0].personalise = true; sample[0].personalise_label = 'Name or message to print on the frame';
  sample[1].featured = true; sample[2].featured = true; sample[5].created_at = new Date().toISOString();
  sample[1].personalise = true; sample[1].personalise_label = 'Name and age for the card';

  const defaults = { whatsapp: C.DEFAULT_WHATSAPP || '919999999999', note: 'Delivery and payment details will be confirmed with you on WhatsApp.' };

  async function compress(file, max) {
    max = max || 1000;
    const url = URL.createObjectURL(file);
    const img = await new Promise((res, rej) => {
      const i = new Image();
      i.onload = () => res(i);
      i.onerror = () => rej(new Error('Could not read that photo. Please use a JPG or PNG.'));
      i.src = url;
    });
    const s = Math.min(1, max / Math.max(img.width, img.height));
    const c = document.createElement('canvas');
    c.width = Math.round(img.width * s);
    c.height = Math.round(img.height * s);
    c.getContext('2d').drawImage(img, 0, 0, c.width, c.height);
    URL.revokeObjectURL(url);
    return new Promise(r => c.toBlob(r, 'image/jpeg', 0.82));
  }
  const toDataUrl = blob => new Promise(r => { const f = new FileReader(); f.onload = () => r(f.result); f.readAsDataURL(blob); });

  const MU = {
    live,
    esc: s => String(s == null ? '' : s).replace(/[&<>"']/g, ch => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch])),
    imagesOf: p => (p && p.images && p.images.length) ? p.images : (p && p.image_url ? [p.image_url] : []),
    genRef: () => 'MU-' + Math.random().toString(36).slice(2, 7).toUpperCase(),
    stockOf: p => Math.max(0, Number(p && p.stock != null ? p.stock : (p && p.in_stock === false ? 0 : 1)) || 0),
    money: n => '₹' + Number(n || 0).toLocaleString('en-IN'),

    // Shows logo.png if you add it to the folder; otherwise a text logo in the brand colours.
    logoHTML: function () {
      return '<img class="logo" src="logo-header.png" alt="ManaUpahar" onerror="MU.logoFail(this)">';
    },
    logoFail: function (img) {
      const s = document.createElement('span');
      s.className = 'wordmark';
      s.innerHTML = '<span class="m">Mana</span><span class="u">Upahar</span>';
      img.replaceWith(s);
    },

    async getProducts() {
      if (!live) return rd(K.p, sample);
      const { data, error } = await sb.from('products').select('*').order('created_at', { ascending: false });
      if (error) throw error;
      return data || [];
    },
    async getSettings() {
      if (!live) return Object.assign({}, defaults, rd(K.s, {}));
      const { data, error } = await sb.from('settings').select('*');
      if (error) throw error;
      const o = Object.assign({}, defaults);
      (data || []).forEach(r => { if (r.value != null && r.value !== '') o[r.key] = r.value; });
      return o;
    },
    async saveSettings(obj) {
      if (!live) { wr(K.s, obj); return; }
      const rows = Object.keys(obj).map(k => ({ key: k, value: obj[k] }));
      const { error } = await sb.from('settings').upsert(rows);
      if (error) throw error;
    },
    async saveProduct(p) {
      const keys = ['name', 'category', 'price', 'description', 'image_url', 'stock', 'images', 'personalise', 'personalise_label', 'featured'];
      const row = {};
      keys.forEach(k => { if (p[k] !== undefined) row[k] = p[k]; });
      if (!live) {
        const list = rd(K.p, sample).slice();
        if (p.id) { const i = list.findIndex(x => x.id === p.id); if (i >= 0) list[i] = Object.assign({}, list[i], row); }
        else list.unshift(Object.assign({ id: 'd' + Date.now(), created_at: new Date().toISOString() }, row));
        wr(K.p, list); return;
      }
      const q = p.id ? sb.from('products').update(row).eq('id', p.id) : sb.from('products').insert(row);
      const { error } = await q;
      if (error) throw error;
    },
    async deleteProduct(id) {
      if (!live) { wr(K.p, rd(K.p, sample).filter(x => x.id !== id)); return; }
      const { error } = await sb.from('products').delete().eq('id', id);
      if (error) throw error;
    },
    async uploadImage(file) {
      const blob = await compress(file);
      if (!live) return toDataUrl(blob);
      const name = Date.now() + '-' + Math.random().toString(36).slice(2, 8) + '.jpg';
      const { error } = await sb.storage.from('gifts').upload(name, blob, { contentType: 'image/jpeg', cacheControl: '31536000' });
      if (error) throw error;
      return sb.storage.from('gifts').getPublicUrl(name).data.publicUrl;
    },

    // ---- Orders ----
    async saveOrder(o) {
      if (!live) {
        const l = rd(K.o, []);
        l.unshift({ id: 'o' + Date.now() + Math.random().toString(36).slice(2, 5), ref: o.ref, items: o.items, total: o.total, delivery_date: o.delivery_date || null, status: 'new', created_at: new Date().toISOString() });
        wr(K.o, l); return;
      }
      let { error } = await sb.from('orders').insert({ ref: o.ref, items: o.items, total: o.total, delivery_date: o.delivery_date || null });
      if (error && /delivery_date/.test(error.message || '')) { // database not upgraded yet: save the order without the date
        ({ error } = await sb.from('orders').insert({ ref: o.ref, items: o.items, total: o.total }));
      }
      if (error) throw error;
    },
    async getOrders() {
      if (!live) return rd(K.o, []);
      const { data, error } = await sb.from('orders').select('*').order('created_at', { ascending: false }).limit(300);
      if (error) throw error;
      return data || [];
    },
    // Confirming or delivering takes items out of stock; cancelling or moving back to New puts them back.
    async setOrderStatus(id, status) {
      if (live) {
        const { error } = await sb.rpc('set_order_status', { order_id: id, new_status: status });
        if (error) throw error;
        return;
      }
      const orders = rd(K.o, []), o = orders.find(x => x.id === id);
      if (!o) throw new Error('Order not found');
      const active = s => s === 'confirmed' || s === 'delivered';
      if (active(status) !== active(o.status)) {
        const sign = active(status) ? -1 : 1;
        const list = rd(K.p, sample).slice();
        o.items.forEach(it => {
          const p = list.find(x => String(x.id) === String(it.id));
          if (p) p.stock = Math.max(0, MU.stockOf(p) + sign * (Number(it.qty) || 0));
        });
        wr(K.p, list);
      }
      o.status = status; wr(K.o, orders);
    },

    async session() {
      if (!live) return !!rd(K.a, false);
      const { data } = await sb.auth.getSession();
      return !!data.session;
    },
    async login(email, password) {
      if (!live) { wr(K.a, true); return; }
      const { error } = await sb.auth.signInWithPassword({ email, password });
      if (error) throw new Error('Wrong email or password.');
    },
    async logout() {
      if (!live) { localStorage.removeItem(K.a); return; }
      await sb.auth.signOut();
    }
  };
  window.MU = MU;
})();
