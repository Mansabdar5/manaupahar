# ManaUpahar – handicraft gift shop with WhatsApp ordering

- **Shop (customers):** `yoursite.vercel.app`
- **Admin (you):** `yoursite.vercel.app/admin` – add gifts, photos, prices, change WhatsApp number

No coding needed. Do the 3 steps below once (about 20 minutes). Everything is free.

## Try it first (optional)
Double-click `index.html`. It opens in **demo mode** with sample gifts. Open `admin.html` and log in with any email/password to try adding a gift. Demo changes stay only on your computer.

## Step 1 – Create the online database (Supabase)
1. Go to **supabase.com**, sign up, click **New project**. Choose any name and a password, pick the region nearest you (Mumbai/Singapore), wait until it finishes.
2. Left menu → **SQL Editor** → **New query**. Open `setup.sql` from this folder, copy everything, paste it, click **Run**. It should say "Success".
3. Left menu → **Authentication** → **Users** → **Add user** → *Create new user*. Enter **your email and a strong password**, tick *Auto confirm user*. This is your admin login.
4. **Authentication** → **Sign In / Providers** (or *Settings*) → switch **OFF** "Allow new users to sign up". This keeps strangers out of your admin.
5. **Project Settings** (gear icon) → **API**. Copy the **Project URL** and the **anon public** key.
6. Open `config.js`, paste them between the quotes, and save:
   ```
   SUPABASE_URL: "https://xxxx.supabase.co",
   SUPABASE_ANON_KEY: "eyJ...",
   ```
   (The anon key is meant to be public. Only your logged-in admin account can change things.)

## Step 2 – Put the files on GitHub
1. Sign up at **github.com**, click **New repository**, name it `manaupahar`, create it.
2. Click **uploading an existing file**, drag in **all files from this folder** (including `config.js` and the logo files), click **Commit changes**.

## Step 3 – Publish with Vercel
1. Go to **vercel.com**, sign up with your GitHub account.
2. **Add New → Project** → pick `manaupahar` → **Deploy**. Leave all settings as they are.
3. In a minute you get a link like `manaupahar.vercel.app`. Shop is at that link; admin is at `/admin`.

## Your logo
Your logo is already included (`logo-header.png` appears in the page header, `favicon.png` is the browser tab icon). To change it later, replace those files and keep the same names. File names are case-sensitive on Vercel, so keep them lowercase.

## Upgrading an existing site
New installs skip this, because `setup.sql` already includes everything.

Already live? In Supabase → **SQL Editor** → **New query**, paste and **Run** these files **one at a time, once each**:
1. `upgrade-stock.sql` (only if you have not run it before)
2. `upgrade-v3.sql` (multiple photos, personalisation, orders)
3. `upgrade-v4.sql` (best sellers, delivery dates)
4. `upgrade-v5.sql` (add-ons, delivery charges by pincode)
5. `upgrade-v6.sql` (handicraft details and occasions)

Run the SQL **before** uploading the new files to GitHub. Then upload the changed files and Vercel republishes by itself. Keep your own `config.js`.

## Daily use
1. Open `yoursite.vercel.app/admin` and log in.
2. **Gifts → Add a gift:** name, price, **category (the craft)**, stock and **up to 6 photos**. Then fill the handicraft details: material, size, who made it and where, care instructions, and **days to make**. Leave days at 0 for ready-to-ship pieces. If you make it after the order, enter the days: customers see "Made to order" and cannot pick an earlier delivery date. Tick the occasions it suits (Birthday, Wedding, Festival ...) so customers can filter by occasion.
   Categories are now crafts, for example Pottery & Terracotta, Wood & Bamboo, Textiles & Handloom, Metal & Brass, Paintings & Folk Art. Type any new one you need. Use **Make cover** to choose the main photo. It appears on the shop immediately.
   Tick **Customers can personalise** to show a box where the customer types a name or message (you choose the question, for example "Name to print on the frame"). It is added to their WhatsApp order.
3. **Stock:** every gift has a stock number. Use **−** when you sell one and **+** when you restock, or type the exact number under **Edit**. At **0** the shop shows **SOLD OUT** on the photo and the order buttons are disabled. With 3 or fewer left, customers see "Only N left", and they cannot add more to the cart than you have.
4. **Orders tab:** when a customer taps the WhatsApp button, the order appears here as **New** with a reference such as `MU-AB12C` (the same reference is in their WhatsApp message). After you agree the order on WhatsApp, press **Confirm**: the stock goes down automatically. Then **Mark delivered** when done. **Cancel** puts the stock back.
5. **Best sellers:** tick "Show as Best seller" on a gift to give it a ⭐ badge and show it first in the shop. Gifts added in the last 14 days get a "New" badge automatically.
6. **Summary tab:** new orders waiting, orders and sales this month, all-time sales, your top 5 sellers, and gifts running low. It counts only orders you have confirmed.
7. **Add-ons & Delivery tab:**
   - **Add-ons** are optional extras customers can tick, like gift wrapping (₹49) or a greeting card (₹29). Tick "Charge for every gift" for things like wrapping, so 2 gifts cost 2 × ₹49. Use **Hide** to switch one off without deleting it.
   - **Delivery charges by pincode:** add one area for each charge, for example "Within the city, ₹60, free above ₹1,500". List pincodes separated by commas. A full 6-digit pincode matches exactly. 3 to 5 digits (like `500`) cover every pincode starting with them, and the longest match wins.
   - Tick **Only deliver to the pincodes listed** if you do not want orders from elsewhere. Otherwise, unlisted pincodes see "we will confirm the delivery charge on WhatsApp".
8. **Edit / Delete** gifts from the list below.
9. **Settings:** WhatsApp number, the handmade note shown on every gift page (clear it to hide it), how many days you need to prepare an order (customers cannot pick an earlier delivery date), and the About us, Delivery and returns and Instagram details shown in the shop footer.

## How customers order
Customers browse by category, tap a gift to see all its photos, type their personalisation if offered, tap **Order now** (one gift) or **Add to cart** for several, then **Send order on WhatsApp**. WhatsApp opens with the gift list and total already typed; they add name, address and delivery date and send. You confirm payment and delivery in the chat.

## Moving an existing shop to handicrafts
After running `upgrade-v6.sql`, gifts that used Birthday, Anniversary, Wedding, Festival or Baby & Kids as their category keep that as an **occasion**. Open each gift in admin and change its category to its craft. Delete gifts that are not handicrafts.

## Extras customers get
- A green **Chat with us** button on every page for questions that are not orders.
- **Sort** (recommended, newest, price) and **budget** filters. Sold-out gifts always go to the end.
- A **Share** button on each gift. It sends a link like `yoursite.com/?gift=...` that opens that gift directly. The link preview shows the shop name, not the gift photo.
- Optional **extras** and a **pincode check** in the cart and on each gift page, with the total broken down into gifts, extras and delivery. The same lines go into the WhatsApp message and the order in admin.
- An optional **delivery date** in the cart and gift pages. It is added to the WhatsApp message and shown on the order in admin.

## Changing things later
- Updated a file on GitHub (for example `config.js` or `logo.png`)? Vercel republishes automatically.
- Custom domain (like manaupahar.in): Vercel → your project → **Settings → Domains**.
