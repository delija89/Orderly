# Orderly — Plan implementacije

**Proizvod:** Orderly — Multi-Store Order Command Center
**Stack:** Next.js 16 · Supabase · Clerk · Tailwind v4 · shadcn/ui · Recharts
**Verzija plana:** 1.0 · **Format:** za kopiranje i A4 štampu · za snimanje u AI Profit Lab zajednici

---

## Šta je Orderly

Orderly je interni real-time analytics dashboard koji agregira porudžbine sa svih prodajnih kanala (WooCommerce, Thinkific i druge platforme) na jedno mesto. Prikazuje se na TV-u u kancelariji, dostupan je celom timu, ima zvučne notifikacije za nove porudžbine, multi-currency podršku i kompletnu analitiku (revenue, profit/COGS, kupci, pretplate, forecasting).

Tri stvari ga izdvajaju od gotovih alata (npr. Metorik): **real-time WebSocket feed**, **multi-platform integracija** (WooCommerce + Thinkific u istom dashboardu) i **TV Mode** za office wall display.

---

## Kako koristiti ovaj plan

Plan je podeljen na tri faze: **Faza 0 (Postavka)**, **Faza 1 (MVP — ingest + real-time)** i **Faza 2 (Analitika i proširenja)**. Koraci su poređani po redosledu izrade — kasniji koraci zavise od ranijih. Svaki korak ima isti format:

- **Opis** — šta i zašto radimo.
- **Zadaci** — konkretni pod-koraci.
- **Rezultat** — šta postoji kada je korak gotov (definicija gotovog).
- **Napomena** — gde postoji, upozorenje na zamku koja je nas već koštala vremena.

Preporuka za snimanje: jedan korak = jedan segment/epizoda i jedan ili više Git commit-ova.

---

## Preduslovi (nalozi i pristupi pre Faze 0)

Otvoriti i pripremiti pre početka:

1. **GitHub** repo (privatni ili javni) za kod.
2. **Vercel** nalog povezan sa GitHub repo-om (hosting + cron).
3. **Supabase** nalog i projekat — region **Frankfurt** (najbliži, najmanja latencija za EU).
4. **Clerk** nalog — sa uključenim **Organizations** (role: admin / manager / viewer).
5. **Resend** nalog (email digest) + verifikovan domen za slanje (potreban tek u Fazi 2).
6. **WooCommerce** pristup za svaki shop: admin + generisani REST API ključevi (consumer key/secret) i mogućnost dodavanja webhook-a.
7. **Thinkific** pristup: API ključ (i mogućnost webhook-a) za kurseve.
8. **Domen/subdomen** za produkciju (DNS pristup radi povezivanja na Vercel).
9. **Brend materijali** — boje, Geist font, logo (dizajn tokeni su navedeni u dodatku „Dizajn sistem").

> **Napomena o platformama:** Referentne integracije u ovom planu su WooCommerce i Thinkific. Baza ima `platform` kolonu na `sites` tabeli, pa se dodatne platforme (Circle i sl.) dodaju po istom obrascu: nova vrednost u `platform` CHECK-u + odgovarajuća `sync` i `webhook` ruta.

---

# FAZA 0 — Postavka projekta

Cilj: spreman skelet aplikacije, deploy radi, sve osnovne integracije (baza, auth, hosting) povezane.

### Korak 0.1 — Inicijalizacija projekta
- **Opis:** Postaviti Next.js 16 (App Router) projekat sa TypeScript-om i Turbopack-om.
- **Zadaci:**
  - `create-next-app` sa TypeScript, App Router, ESLint, Turbopack.
  - Postaviti strukturu foldera: `app/`, `components/`, `lib/`, `supabase/migrations/`.
  - Dodati `AGENTS.md` / `CLAUDE.md` sa pravilima projekta i `.gitignore`, `README`.
  - Inicijalni commit i push na GitHub.
- **Rezultat:** Prazan Next.js 16 app se pokreće lokalno (`npm run dev`).
- **Napomena:** Next.js 16 ima breaking changes u odnosu na ranije verzije (drugačije konvencije, čak i naziv middleware fajla — vidi 0.6). U `AGENTS.md` upiši pravilo da se pre pisanja koda pročita relevantan vodič iz `node_modules/next/dist/docs/` — to čuva AI asistenta od oslanjanja na zastarelo znanje.

### Korak 0.2 — Dizajn sistem i Tailwind v4
- **Opis:** Tailwind v4 sa Orderly brend tokenima i Geist fontom — temelj celog vizuelnog identiteta.
- **Zadaci:**
  - Instalirati Tailwind v4 (`@tailwindcss/postcss`), `tw-animate-css`.
  - U `app/globals.css`: `@import "tailwindcss"`, `@import "tw-animate-css"`, `@import "shadcn/tailwind.css"`.
  - U `@theme inline` bloku mapirati boje, radijuse i `--font-sans: "Geist"`.
  - U `:root` definisati brend tokene: `--brand-accent #1B6EF3`, success/warning/danger/neutral + njihove `-bg` varijante, senke (`--shadow-sm/md/lg`), tranzicije (`--transition`, `--transition-spring`), shadcn tokeni (oklch) za light i `.dark`.
  - Učitati Geist preko `next/font/google` u `layout.tsx`.
- **Rezultat:** Test stranica prikazuje brend boje, font i osnovne stilove ispravno.
- **Napomena:** Tailwind v4 **nema** `tailwind.config.ts` — sva konfiguracija ide u `globals.css` (`@theme` blok). Geist se primenjuje preko `geist.className` na `<body>` (ne `geist.variable`); inače se font „ne hvata".

### Korak 0.3 — UI komponente (shadcn/ui)
- **Opis:** Bazne shadcn komponente u Orderly stilu radi bržeg razvoja.
- **Zadaci:**
  - Inicijalizovati shadcn (`components.json`, style: `base-nova`, baseColor: neutral, ikone: lucide).
  - Dodati `@base-ui/react`, `class-variance-authority`, `clsx`, `tailwind-merge` i `lib/utils.ts` (`cn`).
  - Pripremiti komponente: Button, Card, Input, Dialog, Sheet, Table, Tabs, Select, Popover, Dropdown-menu, Badge, Switch, Avatar, Separator, Tooltip.
- **Rezultat:** Biblioteka komponenti u brendu, spremna za korišćenje.

### Korak 0.4 — Baza i šema (Supabase)
- **Opis:** Postgres baza na Supabase-u sa kompletnom šemom, RLS-om i indeksima.
- **Zadaci:**
  - Kreirati Supabase projekat (Frankfurt), dodati `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` u env.
  - SQL migracija `001_initial_schema.sql` — 9 tabela: `sites`, `customers`, `orders`, `order_items`, `products`, `subscriptions`, `settings` (KV store), `sync_log`, `sound_settings`.
  - Uključiti RLS na svim tabelama; dodati policy `authenticated_read_all` (SELECT) i `service_role_all` (ALL) na svaku.
  - Indeksi na `orders` (`site_id`, `created_at DESC`, `status`, `customer_email`), `order_items(order_id)`, `customers(email)`.
  - `orders` ima `UNIQUE(site_id, woo_order_id)` radi idempotentnog upsert-a.
- **Rezultat:** Sve tabele postoje; RLS i indeksi rade.
- **Napomena:** `created_at` na `orders` čuva **originalni datum sa izvora**, ne datum sinka — biće presudno u 1.4. `settings` je generički KV store (`key` UNIQUE, `value` JSONB): tu žive `base_currency`, `exchange_rates`, `goal_daily_global`, `tv_rotation_interval` itd.

### Korak 0.5 — Supabase klijenti
- **Opis:** Tri tipa klijenta za tri konteksta — bez ORM-a, direktno Supabase JS.
- **Zadaci:**
  - `lib/supabase/browser-client.ts` — **singleton** `createBrowserClient` (modul-level eksport).
  - `lib/supabase/server.ts` — `createServerClient` sa `cookies()` iz `next/headers` (za server komponente i akcije).
  - `lib/supabase/admin.ts` — `createClient` sa `SUPABASE_SERVICE_ROLE_KEY` (za webhook i sync rute).
- **Rezultat:** Klijenti dostupni za browser, server i admin kontekst.
- **Napomena:** Browser klijent **mora** biti singleton. Ako se `createBrowserClient()` poziva unutar komponente/hooka, kreira se novi Realtime kanal na svaki render (CLOSED → SUBSCRIBED petlja). Service role ključ se koristi **isključivo** na serveru — nikad u frontend kodu.

### Korak 0.6 — Autentifikacija (Clerk)
- **Opis:** Login/registracija, role i zaštita ruta.
- **Zadaci:**
  - Integrisati Clerk (`@clerk/nextjs`), `ClerkProvider` u root `layout.tsx`.
  - Uključiti **Organizations** u Clerk dashboard-u; role: `admin` / `manager` / `viewer`.
  - Sign-in stranica kao **catch-all**: `app/(auth)/sign-in/[[...sign-in]]/page.tsx`.
  - **`proxy.ts`** (u Next.js 16 ovo je middleware) — `clerkMiddleware` + `createRouteMatcher`; public rute: `/sign-in(.*)`, `/sign-up(.*)`, `/tv(.*)`, `/api/webhook/woo/(.*)`, `/api/webhook/thinkific/(.*)`. Sve ostalo `auth.protect()`.
- **Rezultat:** Korisnik mora da se prijavi; webhook i TV rute ostaju javne.
- **Napomena:** Dve klasične greške ovde: (1) sign-in mora biti catch-all `[[...sign-in]]`, inače Clerk baca grešku; (2) webhook rute **moraju** biti javne — ako ih Clerk štiti, WooCommerce/Thinkific dobijaju 401 i porudžbine se ne upisuju.

### Korak 0.7 — Deploy i okruženje
- **Opis:** Aplikacija živi na Vercelu, povezana na domen.
- **Zadaci:**
  - Povezati GitHub repo sa Vercelom (auto-deploy na `main`).
  - Uneti sve env varijable (Supabase ×3, Clerk publishable/secret + sign-in URL-ovi, `CRON_SECRET`, kasnije `RESEND_API_KEY`).
  - Povezati domen/subdomen (DNS) na Vercel.
- **Rezultat:** Produkcioni URL radi, login funkcioniše online.
- **Napomena:** Vercel **Hobby** plan dozvoljava samo **dnevni** cron. Ovo diktira arhitekturu: oslanjamo se na webhook-ove za real-time, a sync je ručni + dnevni cron (vidi 1.4 i Fazu 2). `vercel.json` drži samo dnevne/nedeljne/mesečne digest rute.

### Korak 0.8 — App skelet i layout
- **Opis:** Zajednički dashboard layout (sidebar, header) i provideri.
- **Zadaci:**
  - `app/(dashboard)/layout.tsx` — sidebar (220px) + header + `<main>`.
  - `components/dashboard/sidebar.tsx` — navigacija: Dashboard, Analitika, Kupci, Pretplate, Profit, Opšte, Sajtovi, Zvuk, TV prikaz; aktivno stanje po `usePathname`; `UserButton` u dnu.
  - `components/dashboard/header.tsx` — gornja traka (mesto za hamburger na mobilnom, sound toggle, notifikacije).
  - Pripremiti mesto za `SoundProvider` i `RealtimeOrdersProvider` (puniće se u Fazi 1).
- **Rezultat:** Postoji navigacioni skelet kroz koji se kreće kroz (još prazne) ekrane.

---

# FAZA 1 — MVP (jezgro: ingest + real-time dashboard)

Cilj: porudžbine sa svih sajtova ulaze u bazu (webhook + sync), žive na real-time dashboardu sa KPI-jem, live feed-om, tabelom, multi-currency i zvukom. Funkcionalan command center za tim.

### Korak 1.1 — Upravljanje sajtovima (Sites CRUD)
- **Opis:** UI i API za dodavanje/uređivanje prodajnih kanala — sve počinje odavde.
- **Zadaci:**
  - `app/(dashboard)/settings/sites/page.tsx` + `sites-manager.tsx` — forma: ime, platforma (`woocommerce`/`thinkific`), URL, ključevi (consumer key/secret ili Thinkific API ključ), boja (`color_hex`), tip projekta, podrazumevana marža.
  - API rute: `app/api/sites/route.ts` (GET/POST) i `app/api/sites/[id]/route.ts` (PATCH/DELETE).
- **Rezultat:** Tim može da doda sajt; sajt postoji u `sites` tabeli sa svojom bojom i konfiguracijom.

### Korak 1.2 — Normalizacija i DB helperi
- **Opis:** Jedan izvor istine za pretvaranje sirove porudžbine u red u bazi — koristi ga i webhook i sync.
- **Zadaci:**
  - `lib/sync/normalize-woo-order.ts` — mapiranje WooCommerce porudžbine u `orderRow` + `itemRows`.
  - Detekcija tipa proizvoda: `digital` ako stavka nema težinu/dimenzije, inače `physical`.
  - Izračun `net_profit` pri ulazu: po `products.cost_percent` ili `cost_fixed`, fallback na `default_margin_percent` sajta; oduzimanje ~5% za kartična plaćanja (`stripe`).
  - `created_at` iz `order.date_created` (ne `NOW()`); `updated_at` iz `date_modified`.
  - `lib/sync/db.ts` — `upsertWooOrder` (idempotentno po `UNIQUE(site_id, woo_order_id)`), `upsertCustomer` (dedup po email-u, ažurira `total_spent`/`order_count`), `logSync`.
- **Rezultat:** Pozivom jedne funkcije porudžbina i kupac završe u bazi, sa izračunatim profitom.
- **Napomena:** Kupci se dedupliciraju **cross-platform po email-u** (`customers.email` UNIQUE) — isti čovek koji je kupio na WooCommerce-u i Thinkific-u je jedan kupac.

### Korak 1.3 — WooCommerce webhook
- **Opis:** Nova porudžbina stiže u realnom vremenu sa shop-a.
- **Zadaci:**
  - `app/api/webhook/woo/[siteId]/route.ts` (POST, javna ruta).
  - Provera HMAC potpisa: `x-wc-webhook-signature` vs `HMAC-SHA256(rawBody, consumer_secret)` u base64.
  - Pozvati `normalizeWooOrder` → `upsertWooOrder` → `upsertCustomer` → `logSync`; **uvek vratiti `200`** (čak i na grešci, da Woo ne gomila retry-jeve).
  - U WooCommerce-u registrovati webhook (`order.created`/`order.updated`) ka produkcionoj ruti.
- **Rezultat:** Nova porudžbina automatski ulazi u bazu kroz nekoliko sekundi.
- **Napomena:** Webhook se **ne sme** testirati lokalno — WooCommerce ne može da dosegne `localhost`. Koristi Vercel produkcioni URL (ili tunel) u konfiguraciji webhook-a.

### Korak 1.4 — WooCommerce initial sync (backfill)
- **Opis:** Učitavanje istorijskih porudžbina iz WooCommerce REST API-ja.
- **Zadaci:**
  - `lib/sync/sync-woo-site.ts` — paginacija (`per_page=100`, `orderby=date&order=asc`), Basic auth, opcioni `after` datum.
  - `app/api/sync/woo/[siteId]/route.ts` i `app/api/sync/all/route.ts`.
  - Sync dijalog u UI (`sync-button.tsx`): opcije perioda (od početka godine, 90 dana, sve).
- **Rezultat:** Sve istorijske porudžbine učitane sa tačnim originalnim datumima.
- **Napomena:** Klasičan bug — normalizacija je nekad koristila `NOW()` pa su sve stare porudžbine dobijale današnji datum i grafici su bili „spljošteni". Uvek `created_at: order.date_created`.

### Korak 1.5 — Thinkific integracija
- **Opis:** Drugi prodajni kanal — online kursevi — po istom obrascu kao WooCommerce.
- **Zadaci:**
  - `lib/sync/sync-thinkific-site.ts` (Thinkific REST API).
  - `app/api/webhook/thinkific/[siteId]/route.ts` (javna ruta) i `app/api/sync/thinkific/[siteId]/route.ts`.
  - `source = 'thinkific'`, `product_type = 'digital'`.
- **Rezultat:** Kursevi i njihove prodaje ulaze u isti `orders` tok kao WooCommerce.

### Korak 1.6 — Real-time jezgro
- **Opis:** Srce Orderlyja — jedan WebSocket kanal koji feed-uje ceo dashboard bez refresh-a.
- **Zadaci:**
  - U Supabase-u dodati `orders` u `supabase_realtime` publikaciju.
  - Dodati RLS policy `anon_read_orders` (SELECT, role `anon`, USING true) na `orders`.
  - `lib/hooks/use-realtime-orders.ts` — pretplata na INSERT/UPDATE; reconnect logika; heartbeat (30s); refetch današnjih porudžbina na fokus taba (Page Visibility API); enrich iz cache-a sajtova; limit 50.
  - `lib/contexts/realtime-orders-context.tsx` — jedan kanal montiran na nivou layout-a; SWR `mutate` za KPI + debounce `router.refresh()`; `subscribeToNewOrders` za page-level callback-ove (animacija live feed-a).
  - Umotati dashboard layout u `RealtimeOrdersProvider`.
- **Rezultat:** Svaka nova porudžbina trenutno stiže u browser; KPI i tabela se sami osvežavaju.
- **Napomena:** Supabase Realtime koristi **`anon`** role za slanje event-a u browser čak i za prijavljene korisnike — bez `anon_read_orders` policy-a event-i ne stižu. Browser mora throttle-ovati WebSocket kad tab nije fokusiran; zato je Page Visibility refetch obavezan, inače feed „zamrzne" na neaktivnom tabu (kritično za TV).

### Korak 1.7 — KPI i statistika
- **Opis:** Pet ključnih metrika sa trendom — gornji red dashboard-a.
- **Zadaci:**
  - `app/api/stats/kpi/route.ts` (i `kpi`, `kpi-products`) — agregacije iz `orders`, konverzija u base currency.
  - `lib/hooks/use-kpi-stats.ts` — SWR sa `refreshInterval: 60000`.
  - `app/api/stats/sparklines/route.ts` + `lib/hooks/use-sparklines.ts` + `components/dashboard/sparkline.tsx`.
  - `components/dashboard/kpi-card.tsx`, `kpi-section.tsx`, `kpi-filters.tsx` — 5 kartica, trend indikatori, poređenje vs prethodni period.
- **Rezultat:** Dashboard prikazuje 5 KPI-jeva sa mini-grafom i % promenom.

### Korak 1.8 — Live feed
- **Opis:** Vertikalni tok porudžbina koji se animira na svaku novu.
- **Zadaci:**
  - `components/dashboard/live-feed.tsx` — na mount fetch današnjih porudžbina direktno iz Supabase; prati novi INSERT iz konteksta.
  - Prikaz naziva proizvoda (iz `order_items`) umesto imena sajta; boja po sajtu.
  - Animacija ulaska (slide-down + fade-in + accent flash).
- **Rezultat:** Live feed prikazuje današnje porudžbine i animira svaku novu.
- **Napomena:** Ne koristiti `sessionStorage` za feed — pravi „duhove" starih porudžbina. Uvek fetch sveže za današnji dan na mount.

### Korak 1.9 — Orders tabela + FilterBar
- **Opis:** Kompletna tabela porudžbina sa filtriranjem i detaljima.
- **Zadaci:**
  - `components/dashboard/orders-table.tsx` (server) + `orders-table-client.tsx` — paginacija (25/str), Sheet drawer za detalje porudžbine.
  - `components/dashboard/filter-bar.tsx` — filteri preko URL `searchParams` (sajt, status, period).
  - Glavni `app/(dashboard)/dashboard/page.tsx` spaja KPI + live feed + tabelu.
- **Rezultat:** Tim može da filtrira i pregleda sve porudžbine; klik otvara detalje.
- **Napomena:** Komponenta koja koristi `useSearchParams` (FilterBar) mora biti omotana u `<Suspense>` — inače build puca. Filter labela treba da prikazuje „Sve", ne interni `__all` ključ.

### Korak 1.10 — Multi-currency
- **Opis:** Svi iznosi se prikazuju u jednoj base valuti, bez obzira na valutu izvora.
- **Zadaci:**
  - `lib/utils/fx.ts` — `loadFxSettings` (čita `base_currency` i `exchange_rates` iz `settings`), `toBase(amount, currency, rates)`; default rates EUR/RSD/USD.
  - `lib/utils/currency.ts` — `formatCurrency` (RSD/EUR/USD lokalizovano).
  - `app/(dashboard)/settings/general/page.tsx` + `app/api/settings/route.ts` — UI za base valutu i kurseve.
- **Rezultat:** Svaki KPI, grafik i tabela konvertuju u izabranu base valutu.

### Korak 1.11 — Zvučne notifikacije
- **Opis:** Custom zvuk po sajtu kad stigne nova porudžbina — team motivacija u kancelariji.
- **Zadaci:**
  - `lib/hooks/use-sound-notification.ts` (Web Audio API) + `lib/contexts/sound-context.tsx` (`SoundProvider` za dashboard sa mute u `localStorage`; `TVSoundProvider` uvek odzvonjen).
  - `components/dashboard/sound-subscriber.tsx` — sluša nove porudžbine i pušta zvuk po `trigger_statuses`.
  - `app/(dashboard)/settings/sound/page.tsx` + `app/api/sound-settings/route.ts` + `upload/route.ts` — upload zvuka, volume, enabled, statusi okidači (`sound_settings` tabela).
- **Rezultat:** Nova porudžbina pušta izabrani zvuk; podešavanja po sajtu.
- **Napomena:** Web Audio mora da se „otključa" prvom korisničkom interakcijom (browser autoplay politika) — zato `unlockAudio()` na prvi klik.

---

# FAZA 2 — Analitika i proširenja

Cilj: dubinska analitika (grafici, profit, kupci, pretplate, forecasting), TV Mode, email digesti i produkcijsko poliranje.

### Korak 2.1 — Analitika stranica
- **Opis:** Grafici koji pretvaraju listu u pravi analytics alat.
- **Zadaci:**
  - `app/(dashboard)/analytics/page.tsx`.
  - `app/api/analytics/daily-revenue/route.ts` + `components/dashboard/charts/daily-revenue-chart.tsx` (Recharts linija, daily/weekly/monthly granularnost).
  - `app/api/analytics/status-breakdown/route.ts` + `charts/status-breakdown-chart.tsx`.
  - `charts/monthly-comparison-card.tsx` — poređenje vs prethodni period.
- **Rezultat:** Analitika stranica sa revenue grafikom, breakdown-om po statusu i poređenjem perioda.

### Korak 2.2 — Per-site dashboard
- **Opis:** Isti dashboard, ali filtriran na jedan sajt.
- **Zadaci:**
  - `app/(dashboard)/dashboard/[siteId]/page.tsx` + `sync-button.tsx`.
  - Site-specific boja iz baze; KPI i grafici filtrirani po `site_id`.
- **Rezultat:** Klik na sajt otvara njegov pojedinačni dashboard sa ručnim sync dugmetom.

### Korak 2.3 — Profit i COGS
- **Opis:** Pravi neto profit po proizvodu i ukupno — killer feature za e-commerce.
- **Zadaci:**
  - `app/(dashboard)/profit/page.tsx`.
  - `app/api/profit/kpi/route.ts`, `profit/products/route.ts` (COGS po SKU iz `products`), `profit/recalculate/route.ts` (retroaktivni preračun `net_profit`).
  - UI za unos `cost_percent`/`cost_fixed` po proizvodu.
- **Rezultat:** Dashboard prikazuje gross vs net, profit po proizvodu i omogućava preračun istorije.

### Korak 2.4 — Top products
- **Opis:** Najprodavaniji proizvodi po prihodu i količini.
- **Zadaci:**
  - `app/api/analytics/top-products/route.ts` + `charts/top-products-chart.tsx` (agregacija iz `order_items`).
- **Rezultat:** Tabela/grafik top proizvoda sa trend indikatorom.

### Korak 2.5 — Kupci (Customers)
- **Opis:** Lista kupaca sa LTV-jem i pojedinačni profili.
- **Zadaci:**
  - `app/(dashboard)/customers/page.tsx` (lista, sort po LTV/AOV/broju porudžbina) + `customers/[id]/page.tsx` (profil sa svim porudžbinama).
  - `app/api/customers/route.ts` + `customers/[id]/route.ts`.
- **Rezultat:** Pregled kupaca i timeline njihovih porudžbina.

### Korak 2.6 — Pretplate (Subscriptions)
- **Opis:** MRR, churn i status pretplata za subscription projekte.
- **Zadaci:**
  - `app/(dashboard)/subscriptions/page.tsx` + `app/api/subscriptions/route.ts`.
  - MRR trend, churn rate, broj aktivnih, breakdown po statusu (`active`/`paused`/`cancelled`/`trial`).
- **Rezultat:** Subscription dashboard sa MRR-om i churn-om.

### Korak 2.7 — Forecasting
- **Opis:** Predviđanje prihoda na osnovu istorije.
- **Zadaci:**
  - `app/api/analytics/forecast/route.ts` + `components/dashboard/forecasting-section.tsx`.
  - Početi sa jednostavnom linearnom regresijom; 1-click toggle na revenue grafiku.
- **Rezultat:** Forecast linija na grafiku prihoda.

### Korak 2.8 — Cohort analiza
- **Opis:** Zadržavanje kupaca po mesecu prve kupovine.
- **Zadaci:**
  - `app/api/analytics/cohort/route.ts` — mesečni cohort sa retained revenue matricom.
- **Rezultat:** Cohort prikaz LTV-ja po akvizicionom mesecu.

### Korak 2.9 — Goal tracker
- **Opis:** Dnevni/mesečni ciljevi sa progresom.
- **Zadaci:**
  - `components/dashboard/daily-goal-tracker.tsx` — cilj iz `settings` (`goal_daily_global`), progress bar, % do cilja.
- **Rezultat:** Dashboard prikazuje napredak ka dnevnom cilju.

### Korak 2.10 — TV Mode
- **Opis:** Public full-screen dashboard za TV u kancelariji — jedinstveni feature.
- **Zadaci:**
  - `app/tv/page.tsx` + `tv/tv-content.tsx` (javna ruta, bez auth).
  - Full-screen layout, auto-rotacija (interval iz `settings`), live feed + KPI, TV animacije (`tv-fade-in`, `tv-marquee`, `tv-row-in`).
  - `TVSoundProvider` (uvek odzvonjen).
- **Rezultat:** `/tv` radi kao samostalan ekran za zid; rotira prikaze i zvuči na nove porudžbine.

### Korak 2.11 — Email digest (Resend)
- **Opis:** Dnevni/nedeljni/mesečni email rezime sa ključnim metrikama.
- **Zadaci:**
  - Integrisati Resend, verifikovati domen, brendirani HTML template.
  - Rute `app/api/digest/daily|weekly|monthly/route.ts`, zaštićene `CRON_SECRET`-om.
  - `vercel.json` cron: `0 8 * * *` (dnevno), `0 8 * * 1` (nedeljno), `0 8 1 * *` (mesečno).
- **Rezultat:** Tim dobija automatski email rezime po rasporedu.
- **Napomena:** Na Hobby planu cron je dnevni — gornji rasporedi su u redu jer su svi „jednom dnevno ili ređe"; intra-dnevni sync se ne radi cron-om već webhook-ovima + ručno.

### Korak 2.12 — QA, bezbednost i lansiranje
- **Opis:** Provera kvaliteta i puštanje u produkciju.
- **Zadaci:**
  - Autorizacija na svakoj zaštićenoj API ruti (Clerk sesija + role); webhook/TV ostaju javni.
  - Rešiti otvorene bugove (npr. AOV kalkulacija — deliti sumom, ne brojem; FilterBar `__all` label; hydration warning na Clerk `UserButton`).
  - Performance: lazy load Recharts, SWR cache tuning, indeks na `orders.created_at`.
  - QA na realnim uređajima (desktop/mobilni/TV); test webhook-ova i cron-a.
  - Fizički TV setup (kiosk mode, auto-start) i onboarding tima (Clerk invite, walkthrough).
- **Rezultat:** Orderly je u produkciji, bezbedan, testiran i pušten timu.

---

## Definicija gotovog po fazama

- **Faza 0:** App se deplojuje, login radi, baza (9 tabela + RLS + indeksi) i Supabase/Clerk integracije povezane, sidebar navigacija postoji.
- **Faza 1 (MVP):** Porudžbine sa WooCommerce + Thinkific ulaze (webhook + sync), žive na real-time dashboardu sa 5 KPI-jeva, live feed-om, tabelom sa filterima, multi-currency i zvukom.
- **Faza 2:** Analitika (grafici), per-site dashboard, profit/COGS, kupci, pretplate, forecasting, cohort, goal tracker, TV Mode i email digest su uživo; produkcija ispolirana.

---

## Mapa stranica i ruta (referenca)

**Stranice (zaštićene osim `/tv`):**
`/dashboard` · `/dashboard/[siteId]` · `/analytics` · `/customers` · `/customers/[id]` · `/subscriptions` · `/profit` · `/settings/general` · `/settings/sites` · `/settings/sound` · `/tv` (javna)

**API rute:**
`/api/stats/kpi` · `/api/stats/sparklines` · `/api/kpi` · `/api/kpi-products` · `/api/analytics/{daily-revenue, status-breakdown, top-products, forecast, cohort}` · `/api/customers` · `/api/customers/[id]` · `/api/profit/{kpi, products, recalculate}` · `/api/subscriptions` · `/api/settings` · `/api/sites` · `/api/sites/[id]` · `/api/sound-settings` · `/api/sound-settings/upload` · `/api/sync/{all, woo/[siteId], thinkific/[siteId]}` · `/api/webhook/{woo/[siteId], thinkific/[siteId]}` (javne) · `/api/digest/{daily, weekly, monthly}` (cron)

---

## Dizajn sistem (referenca tokena)

**Boje (`:root` u `globals.css`):** accent `#1B6EF3`, accent-hover `#1558CC`, accent-bg `#EBF2FF`, success `#16A34A`, warning `#D97706`, danger `#DC2626`, neutral `#6366F1` (svaka ima i `-bg` svetlu varijantu).

**Tipografija (Geist):** KPI brojevi 28–32px / 700 (letter-spacing −0.03em); H1 24px / 700 (−0.02em); naslovi kartica 13px / 600; body 13px / 400; labels (uppercase) 11px / 500 (+0.04em).

**Senke:** `--shadow-sm` (kartica), `--shadow-md` (hover), `--shadow-lg`.

**Animacije:** `--transition` 180ms `cubic-bezier(0.4,0,0.2,1)` (hover); `--transition-spring` 300ms `cubic-bezier(0.34,1.56,0.64,1)` (progress/goal); hover kartica `translateY(-1px)` + shadow-md; klik dugme `scale(0.98)`; nova porudžbina slide-down + fade-in + accent flash.

---

## Česte greške i rešenja (zlato za snimanje)

| Problem | Rešenje |
| --- | --- |
| Clerk SignIn greška | Sign-in mora biti catch-all: `app/(auth)/sign-in/[[...sign-in]]/page.tsx`; `/sign-in(.*)` u public rutama. |
| Geist font se ne primenjuje | Tailwind v4 nema config — font ide u `globals.css @theme` kao `"Geist"`; na `<body>` koristi `geist.className`, ne `geist.variable`. |
| `useSearchParams` build greška | Komponentu (FilterBar) omotati u `<Suspense>`. |
| Webhook 200 ali prazna tabela | Webhook testiran lokalno — Woo ne može do `localhost`. Koristi produkcioni Vercel URL. |
| Realtime eventi ne stižu u browser | Dodati RLS policy `anon_read_orders` (Supabase Realtime šalje event-e preko `anon` role). |
| Realtime petlja CLOSED → SUBSCRIBED | Supabase browser klijent mora biti **singleton** (modul-level), ne kreiran u hooku. |
| Stare porudžbine dobijaju današnji datum | `created_at: order.date_created`, nikad `NOW()`. |
| Live feed prikazuje „duhove" | Bez `sessionStorage`; fetch sveže za današnji dan na mount. |
| Feed zamrzne na neaktivnom tabu | Page Visibility API refetch + Realtime reconnect/heartbeat. |
| Vercel cron greška | Hobby plan = samo dnevni cron; nema intra-dnevnog sync-a u `vercel.json`. |
| AOV pogrešan | Deliti **sumom** prihoda, ne brojem porudžbina. |

---

## Napomene o zavisnostima

- 1.3 i 1.4 zavise od 1.1 (sajt mora postojati) i 1.2 (normalizacija + DB helperi).
- 1.6 (Realtime) zavisi od 0.5 (singleton browser klijent) i 0.4 (`orders` u publikaciji + `anon` policy).
- 1.7, 1.8 i 1.9 zavise od 1.6 (čitaju iz Realtime konteksta).
- 1.10 (multi-currency) treba da bude gotov pre Faze 2 — svi grafici i KPI konvertuju u base valutu preko `fx.ts`/`currency.ts`.
- 2.11 (digest) zavisi od Resend naloga i verifikovanog domena.

---
