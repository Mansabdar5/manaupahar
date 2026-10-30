// Shared data layer. Talks to Supabase when configured, otherwise runs a browser-only demo.
(function () {
  function getVisitorId() {
    try {
      let vid = localStorage.getItem('mu_visitor_id');
      if (!vid) {
        vid = 'v_' + Math.random().toString(36).substring(2, 11) + Date.now().toString(36);
        localStorage.setItem('mu_visitor_id', vid);
      }
      return vid;
    } catch (e) { return 'v_unknown'; }
  }

  const C = window.MU_CONFIG || {};
  const live = !!(C.SUPABASE_URL && C.SUPABASE_ANON_KEY && window.supabase);
  const sb = live ? window.supabase.createClient(C.SUPABASE_URL, C.SUPABASE_ANON_KEY) : null;
  const K = { p: 'mu_demo_products', s: 'mu_demo_settings', a: 'mu_demo_admin', o: 'mu_demo_orders', ad: 'mu_demo_addons', z: 'mu_demo_zones', r: 'mu_demo_reviews' };

  const rd = (k, d) => { try { const v = JSON.parse(localStorage.getItem(k)); return v == null ? d : v; } catch (e) { return d; } };
  const wr = (k, v) => {
    try { localStorage.setItem(k, JSON.stringify(v)); }
    catch (e) { throw new Error('Demo storage is full. Connect Supabase (see README) to store real photos.'); }
  };

  const ph = (emoji, c1, c2) => 'data:image/svg+xml;utf8,' + encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">' +
    '<stop offset="0" stop-color="' + c1 + '"/><stop offset="1" stop-color="' + c2 + '"/></linearGradient></defs>' +
    '<rect width="400" height="400" fill="url(#g)"/><text x="200" y="245" font-size="150" text-anchor="middle">' + emoji + '</text></svg>');

  // Sample handicrafts shown in demo mode only. Delete them in the admin page once you add your own.
  const sample = [
    { id: 's1', name: 'Hand-painted Terracotta Vase', category: 'Pottery & Terracotta', price: 699, description: 'Wheel-thrown and hand-painted by the potters, finished with a natural clay glaze.', image_url: ph('🏺', '#FFE7CC', '#FDBA74'), stock: 6, material: 'Terracotta', size: '9 in tall', care: 'Wipe with a dry cloth. Not for hot water.', prep_days: 0, occasions: ['Housewarming', 'Festival'] },
    { id: 's2', name: 'Carved Wooden Name Plate', category: 'Wood & Bamboo', price: 1299, description: 'Name or house number hand-carved in solid wood, finished with natural oil.', image_url: ph('🪵', '#FEF3C7', '#FCD34D'), stock: 5, material: 'Solid wood', made_by: 'Woodcraft artisans', size: '12 x 6 in', care: 'Keep dry. Wipe with a soft cloth.', prep_days: 5, occasions: ['Housewarming', 'Wedding'] },
    { id: 's3', name: 'Handwoven Cotton Table Runner', category: 'Textiles & Handloom', price: 899, description: 'Woven on a handloom in natural cotton with a hand-knotted fringe.', image_url: ph('🧶', '#FEE2E2', '#FCA5A5'), stock: 2, material: 'Cotton', made_by: 'Weavers collective', size: '14 x 60 in', care: 'Gentle hand wash in cold water.', prep_days: 0, occasions: ['Housewarming', 'Festival'] },
    { id: 's4', name: 'Brass Diya Set of 4', category: 'Metal & Brass', price: 999, description: 'Cast and hand-polished brass lamps in a reusable gift box.', image_url: ph('🪔', '#FEF9C3', '#FDE047'), stock: 8, material: 'Brass', size: '2.5 in each', care: 'Polish with a soft cloth.', prep_days: 0, occasions: ['Festival', 'Housewarming'] },
    { id: 's5', name: 'Folk Art Painting (A4)', category: 'Paintings & Folk Art', price: 1499, description: 'Original hand-painted folk art on handmade paper. One of a kind.', image_url: ph('🎨', '#E0F2FE', '#7DD3FC'), stock: 0, material: 'Natural colours on handmade paper', size: 'A4', prep_days: 0, occasions: ['Wedding', 'Thank you'] },
    { id: 's6', name: 'Bamboo Desk Pen Stand', category: 'Wood & Bamboo', price: 349, description: 'Cut, smoothed and joined by hand from sustainably grown bamboo.', image_url: ph('🎋', '#DCFCE7', '#86EFAC'), stock: 12, material: 'Bamboo', size: '4 in tall', care: 'Wipe clean with a dry cloth.', prep_days: 0, occasions: ['Thank you', 'Birthday'] }
  ];

  // Demo extras so the newer features can be tried straight away
  sample[0].images = [sample[0].image_url, ph('🌿', '#DCFCE7', '#86EFAC'), ph('✨', '#FEF9C3', '#FDE047')];
  sample[1].featured = true; sample[2].featured = true; sample[5].created_at = new Date().toISOString();
  sample[1].personalise = true; sample[1].personalise_label = 'Name or house number to carve';

  const sampleAddons = [
    { id: 'a1', name: 'Gift box packaging', price: 79, per_item: true, active: true },
    { id: 'a2', name: 'Handwritten message card (send your message on WhatsApp)', price: 29, per_item: false, active: true },
    { id: 'a3', name: 'Story card about the maker', price: 19, per_item: true, active: true }
  ];
  const sampleZones = [
    { id: 'z1', label: 'Local delivery', pincodes: '500', charge: 60, free_above: 1500, active: true },
    { id: 'z2', label: 'Nearby towns', pincodes: '501, 502, 503, 504, 505', charge: 120, free_above: null, active: true }
  ];

  // Small list manager used for add-ons and delivery areas
  const table = (name, key, sampleRows, cols) => ({
    async list() {
      if (!live) return rd(key, sampleRows);
      const { data, error } = await sb.from(name).select('*').order('created_at', { ascending: true });
      if (error) throw error;
      return data || [];
    },
    async save(r) {
      const row = {};
      cols.forEach(k => { if (r[k] !== undefined) row[k] = r[k]; });
      if (!live) {
        const l = rd(key, sampleRows).slice();
        if (r.id) { const i = l.findIndex(x => x.id === r.id); if (i >= 0) l[i] = Object.assign({}, l[i], row); }
        else l.push(Object.assign({ id: 'x' + Date.now() }, row));
        wr(key, l); return;
      }
      const { error } = await (r.id ? sb.from(name).update(row).eq('id', r.id) : sb.from(name).insert(row));
      if (error) throw error;
    },
    async remove(id) {
      if (!live) { wr(key, rd(key, sampleRows).filter(x => x.id !== id)); return; }
      const { error } = await sb.from(name).delete().eq('id', id);
      if (error) throw error;
    }
  });

  const defaults = { handmade_note: 'Each piece is handmade, so small variations are part of its charm.', whatsapp: C.DEFAULT_WHATSAPP || '919999999999', note: 'Delivery and payment details will be confirmed with you on WhatsApp.' };

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
    // Order stages in the order customers see them
    STAGES: [['new', 'Order placed'], ['confirmed', 'Confirmed'], ['packed', 'Packed'], ['shipped', 'Shipped'], ['delivered', 'Delivered']],
    ACTIVE: ['confirmed', 'packed', 'shipped', 'delivered'],
    // Orders placed on this device, so customers can find their reference again
    myOrders: () => { try { return JSON.parse(localStorage.getItem('mu_myorders') || '[]').filter(r => /^MU-/.test(r)); } catch (e) { return []; } },
    rememberOrder: ref => { try { localStorage.setItem('mu_myorders', JSON.stringify([ref].concat(MU.myOrders().filter(r => r !== ref)).slice(0, 8))); } catch (e) {} },
    genRef: () => 'MU-' + Math.random().toString(36).slice(2, 7).toUpperCase(),
    stockOf: p => Math.max(0, Number(p && p.stock != null ? p.stock : (p && p.in_stock === false ? 0 : 1)) || 0),
    money: n => '₹' + Number(n || 0).toLocaleString('en-IN'),
    // Recently viewed items helper
    getRecentlyViewed: () => {
      try { return JSON.parse(localStorage.getItem('mu_recently_viewed') || '[]'); } catch (e) { return []; }
    },
    addRecentlyViewed: (id) => {
      try {
        let list = MU.getRecentlyViewed().filter(x => String(x) !== String(id));
        list.unshift(String(id));
        localStorage.setItem('mu_recently_viewed', JSON.stringify(list.slice(0, 6)));
      } catch (e) {}
    },

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
      (data || []).forEach(r => { if (r.value != null && (r.value !== '' || r.key === 'handmade_note')) o[r.key] = r.value; });
      return o;
    },
    async saveSettings(obj) {
      if (!live) { wr(K.s, Object.assign({}, rd(K.s, {}), obj)); return; }
      const rows = Object.keys(obj).map(k => ({ key: k, value: obj[k] }));
      const { error } = await sb.from('settings').upsert(rows);
      if (error) throw error;
    },
    async saveProduct(p) {
      const keys = ['name', 'category', 'price', 'description', 'image_url', 'stock', 'images', 'personalise', 'personalise_label', 'featured', 'material', 'made_by', 'region', 'size', 'care', 'prep_days', 'occasions'];
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
      if (error && /column|schema cache/i.test(error.message || '')) throw new Error('The database needs the latest upgrade. Run upgrade-v6.sql in Supabase (see README), then try again.');
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

    addons: table('addons', K.ad, sampleAddons, ['name', 'price', 'per_item', 'active']),
    zones: table('delivery_zones', K.z, sampleZones, ['label', 'pincodes', 'charge', 'free_above', 'active']),

    // ---- Customer reviews (public submissions remain pending until an admin approves) ----
    reviews: {
      async list(productId, includePending) {
        if (!live) {
          const rows = rd(K.r, []);
          return rows.filter(r => (!productId || String(r.product_id) === String(productId)) && (includePending || r.status === 'approved'))
            .sort((a, b) => String(b.created_at).localeCompare(String(a.created_at)));
        }
        let q = sb.from('reviews').select('*').order('created_at', { ascending: false }).limit(300);
        if (productId) q = q.eq('product_id', productId);
        if (!includePending) q = q.eq('status', 'approved');
        const { data, error } = await q;
        if (error) throw error;
        // The review-photo bucket is private. Generate short-lived URLs only for
        // photos the current visitor is allowed to read (approved reviews publicly;
        // pending reviews for the signed-in admin).
        return await Promise.all((data || []).map(async row => {
          if (!row.photo_path) return row;
          try {
            const { data: signed, error: signError } = await sb.storage.from('review-photos').createSignedUrl(row.photo_path, 3600);
            if (signError) { console.warn('Review photo is not available:', signError.message); return row; }
            return Object.assign({}, row, { photo_url: signed && signed.signedUrl ? signed.signedUrl : '' });
          } catch (e) { console.warn('Review photo is not available:', e); return row; }
        }));
      },
      async submit(r) {
        const row = { product_id: r.product_id, customer_name: String(r.customer_name || '').trim().slice(0, 70), rating: Math.max(1, Math.min(5, Number(r.rating) || 5)), review_text: String(r.review_text || '').trim().slice(0, 500), status: 'pending' };
        if (!row.customer_name || row.review_text.length < 10) throw new Error('Please provide your name and a review of at least 10 characters.');
        if (r.photo_file) {
          if (!live) throw new Error('Photo reviews are available after the website is connected to Supabase.');
          const file = r.photo_file;
          if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) throw new Error('Please choose a JPG, PNG or WebP image.');
          if (file.size > 5 * 1024 * 1024) throw new Error('Please choose an image smaller than 5 MB.');
          const blob = await compress(file, 1200);
          if (!blob) throw new Error('The selected photo could not be processed. Please try another image.');
          const uuid = window.crypto && crypto.randomUUID ? crypto.randomUUID() : 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => { const r = Math.random() * 16 | 0; return (c === 'x' ? r : (r & 3 | 8)).toString(16); });
          const path = uuid + '.jpg';
          const { error: uploadError } = await sb.storage.from('review-photos').upload(path, blob, { contentType: 'image/jpeg', cacheControl: '3600', upsert: false });
          if (uploadError) throw new Error('Photo upload failed: ' + uploadError.message);
          row.photo_path = path;
        }
        if (!live) {
          const rows = rd(K.r, []); rows.unshift(Object.assign({ id: 'r' + Date.now(), created_at: new Date().toISOString() }, row)); wr(K.r, rows); return;
        }
        const { error } = await sb.from('reviews').insert(row);
        if (error) throw error;
      },
      async setStatus(id, status) {
        if (!['approved', 'rejected', 'pending'].includes(status)) throw new Error('Invalid review status.');
        if (!live) { const rows = rd(K.r, []); const r = rows.find(x => String(x.id) === String(id)); if (r) r.status = status; wr(K.r, rows); return; }
        const { error } = await sb.from('reviews').update({ status }).eq('id', id);
        if (error) throw error;
      }
    },

    // ---- Orders ----
    async saveOrder(o) {
      const vid = getVisitorId();
      if (!live) {
        const l = rd(K.o, []);
        const recent = l.filter(x => x.visitor_id === vid);
        if (recent.length >= 5) {
          throw new Error('Limit reached: Maximum 5 orders allowed per visitor.');
        }
        l.unshift({ id: 'o' + Date.now() + Math.random().toString(36).slice(2, 5), ref: o.ref, items: o.items, total: o.total, delivery_date: o.delivery_date || null, visitor_id: vid, status: 'new', created_at: new Date().toISOString(), status_log: [{ s: 'new', at: new Date().toISOString() }] });
        wr(K.o, l); return;
      }
      try {
        await sb.rpc('check_visitor_order_limit', { p_visitor_id: vid, p_max_orders: 5, p_window_hours: 24 });
      } catch (err) {}
      let { error } = await sb.from('orders').insert({ ref: o.ref, items: o.items, total: o.total, delivery_date: o.delivery_date || null, visitor_id: vid });
      if (error && /delivery_date|visitor_id/.test(error.message || '')) {
        ({ error } = await sb.from('orders').insert({ ref: o.ref, items: o.items, total: o.total }));
      }
      if (error) throw error;
    },
    async cleanupOrders(daysOld) {
      daysOld = daysOld || 30;
      if (!live) {
        const l = rd(K.o, []);
        const initLen = l.length;
        const filtered = l.filter(x => x.status !== 'cancelled' && x.status !== 'rejected');
        wr(K.o, filtered);
        return initLen - filtered.length;
      }
      const { data, error } = await sb.rpc('cleanup_spam_orders', { days_old: daysOld });
      if (error) throw error;
      return data || 0;
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
      const active = s => MU.ACTIVE.includes(s);
      if (active(status) !== active(o.status)) {
        const sign = active(status) ? -1 : 1;
        const list = rd(K.p, sample).slice();
        o.items.forEach(it => {
          const p = list.find(x => String(x.id) === String(it.id));
          if (p) p.stock = Math.max(0, MU.stockOf(p) + sign * (Number(it.qty) || 0));
        });
        wr(K.p, list);
      }
      if (o.status !== status) { o.status = status; o.status_log = (o.status_log || []).concat([{ s: status, at: new Date().toISOString() }]); }
      wr(K.o, orders);
    },
    // Courier / tracking details and the short note the customer sees
    async updateOrder(id, f) {
      const row = {};
      ['courier', 'tracking_no', 'tracking_url', 'customer_note'].forEach(k => { if (f[k] !== undefined) row[k] = f[k] ? String(f[k]).trim() : null; });
      if (row.tracking_url && !/^https?:\/\//i.test(row.tracking_url)) throw new Error('The tracking link must start with http:// or https://');
      if (!live) {
        const orders = rd(K.o, []), o = orders.find(x => x.id === id);
        if (!o) throw new Error('Order not found');
        Object.assign(o, row); wr(K.o, orders); return;
      }
      const { error } = await sb.from('orders').update(row).eq('id', id);
      if (error && /column|schema cache/i.test(error.message || '')) throw new Error('The database needs the order-tracking upgrade. Run upgrade-v9-order-tracking.sql in Supabase (see README), then try again.');
      if (error) throw error;
    },
    // Public lookup of ONE order by its reference. Returns null when not found.
    async trackOrder(ref) {
      ref = String(ref || '').trim().toUpperCase();
      if (!/^MU-[A-Z0-9]{3,12}$/.test(ref)) return null;
      if (!live) {
        const o = rd(K.o, []).find(x => String(x.ref).toUpperCase() === ref);
        if (!o) return null;
        return { ref: o.ref, status: o.status, created_at: o.created_at, delivery_date: o.delivery_date, courier: o.courier || null, tracking_no: o.tracking_no || null,
          tracking_url: o.tracking_url || null, customer_note: o.customer_note || null, log: o.status_log || [{ s: o.status, at: o.created_at }],
          items: (o.items || []).map(i => ({ name: i.name, qty: i.qty, kind: i.kind })) };
      }
      const { data, error } = await sb.rpc('track_order', { p_ref: ref });
      if (error) {
        if (/track_order|schema cache|function/i.test(error.message || '')) throw new Error('Order tracking is not switched on yet. Please message us on WhatsApp with your order reference.');
        throw error;
      }
      return data || null;
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
