# CLAUDE.md — Orderly

Orderly je interni real-time analytics dashboard (Multi-Store Order Command Center). Agregira porudžbine sa svih prodajnih kanala (WooCommerce, Thinkific, kasnije druge platforme) na jedno mesto. Prikazuje se na TV-u u kancelariji, dostupan celom timu, sa zvučnim notifikacijama, multi-currency podrškom i analitikom (revenue, profit/COGS, kupci, pretplate, forecasting).

Tri stvari ga izdvajaju: **real-time WebSocket feed**, **multi-platform integracija** i **TV Mode** (javni full-screen prikaz za zid).

## Pravila rada (čitaj prvo)

1. **Next.js 16 ima breaking changes.** Pre pisanja koda koji dira routing, middleware, caching, server actions ili config, pročitaj relevantan vodič iz `node_modules/next/dist/docs/`. Ne oslanjaj se na zastarelo znanje o Next.js 13/14/15.
2. **Radi korak po korak** prema planu implementacije (Faza 0 → 1 → 2). Kasniji koraci zavise od ranijih. Ne preskači redosled i ne gradi stvari iz kasnijih faza unapred.
3. **Jedan korak = jedan ili više malih commit-ova.** Poruke commit-a na engleskom, kratke, imperativ (`feat: add woo webhook route`).
4. Pre većih izmena kratko izlisti šta ćeš uraditi; ne menjaj šemu baze bez nove migracije.
5. Komentari u kodu i nazivi promenljivih/fajlova na **engleskom**. UI tekstovi i komunikacija sa korisnikom na **srpskom (latinica)**.
6. Ne dodaji biblioteke koje nisu u stack-u bez pitanja. Nema ORM-a — direktno Supabase JS.
7. Nikad ne commit-uj `.env*` fajlove i ne ispisuj tajne u logovima.

## Stack

- **Next.js 16** (App Router, TypeScript, Turbopack)
- **Supabase** (Postgres + Realtime), region Frankfurt
- **Clerk** (`@clerk/nextjs`) sa Organizations, role: `admin` / `manager` / `viewer`
- **Tailwind v4** + **shadcn/ui** (style `base-nova`, baseColor neutral, ikone lucide, `@base-ui/react`)
- **Recharts** (grafici, lazy load), **SWR** (client fetching)
- **Resend** (email digest), **Vercel** (hosting + cron, Hobby plan)

## Struktura foldera

```
app/
  (auth)/sign-in/[[...sign-in]]/page.tsx   # catch-all, obavezno
  (dashboard)/                             # zaštićene stranice + layout (sidebar 220px + header)
  tv/                                      # javna TV ruta
  api/                                     # stats, analytics, sites, sync, webhook, digest...
components/ (ui/, dashboard/, dashboard/charts/)
lib/ (supabase/, sync/, hooks/, contexts/, utils/)
supabase/migrations/
proxy.ts                                   # Next.js 16 naziv za middleware
```

## Env varijable

`NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` (samo server!), Clerk publishable/secret + sign-in URL-ovi, `CRON_SECRET`, `RESEND_API_KEY` (Faza 2).

## Baza (Supabase)

9 tabela: `sites`, `customers`, `orders`, `order_items`, `products`, `subscriptions`, `settings` (KV store), `sync_log`, `sound_settings`.

- RLS uključen na svim tabelama; policy `authenticated_read_all` (SELECT) i `service_role_all` (ALL) na svakoj.
- `orders`: `UNIQUE(site_id, woo_order_id)` za idempotentan upsert; indeksi na `site_id`, `created_at DESC`, `status`, `customer_email`. `order_items(order_id)`, `customers(email)` (email UNIQUE).
- `orders.created_at` = **originalni datum sa izvora** (`order.date_created`), nikad `NOW()`. `updated_at` iz `date_modified`.
- `sites.platform` CHECK (`woocommerce` / `thinkific`); nova platforma = nova vrednost + `sync` i `webhook` ruta po istom obrascu.
- `settings` je generički KV (`key` UNIQUE, `value` JSONB): `base_currency`, `exchange_rates`, `goal_daily_global`, `tv_rotation_interval`...
- Kupci se deduplikuju **cross-platform po email-u**.
- `orders` mora biti u `supabase_realtime` publikaciji i imati policy `anon_read_orders` (SELECT, role `anon`).

## Supabase klijenti

- `lib/supabase/browser-client.ts` — **singleton** `createBrowserClient` (modul-level eksport). Nikad ga ne kreiraj unutar komponente/hooka.
- `lib/supabase/server.ts` — `createServerClient` sa `cookies()` (server komponente/akcije).
- `lib/supabase/admin.ts` — service role (webhook i sync rute). **Samo server, nikad u frontend kodu.**

## Auth (Clerk)

- `proxy.ts` sa `clerkMiddleware` + `createRouteMatcher`. Javne rute: `/sign-in(.*)`, `/sign-up(.*)`, `/tv(.*)`, `/api/webhook/woo/(.*)`, `/api/webhook/thinkific/(.*)`. Sve ostalo `auth.protect()`.
- Svaka zaštićena API ruta proverava Clerk sesiju + rolu. Webhook i TV ostaju javni.
- Cron rute (`/api/digest/*`) štiti `CRON_SECRET`.

## Dizajn sistem

- Tailwind v4 **nema `tailwind.config.ts`** — sva konfiguracija u `app/globals.css` (`@theme inline`).
- Font Geist preko `next/font/google`; na `<body>` koristi `geist.className` (ne `geist.variable`).
- Boje: accent `#1B6EF3` (hover `#1558CC`, bg `#EBF2FF`), success `#16A34A`, warning `#D97706`, danger `#DC2626`, neutral `#6366F1` (svaka ima `-bg` varijantu). Uvek koristi CSS tokene, ne hardkodirane hex vrednosti.
- Tipografija: KPI brojevi 28–32px/700 (−0.03em); H1 24px/700; naslovi kartica 13px/600; body 13px/400; labele uppercase 11px/500 (+0.04em).
- Animacije: `--transition` 180ms `cubic-bezier(0.4,0,0.2,1)`; `--transition-spring` 300ms `cubic-bezier(0.34,1.56,0.64,1)`; hover kartice `translateY(-1px)` + `shadow-md`; klik dugmeta `scale(0.98)`; nova porudžbina = slide-down + fade-in + accent flash.

## Ključna arhitektonska pravila

- **Real-time preko webhook-ova.** Vercel Hobby dozvoljava samo **dnevni** cron — nikad ne dodaji intra-dnevni cron u `vercel.json` (samo dnevne/nedeljne/mesečne digest rute). Sync je ručni + dnevni.
- **Normalizacija je jedan izvor istine:** `lib/sync/normalize-woo-order.ts` + `lib/sync/db.ts` (`upsertWooOrder`, `upsertCustomer`, `logSync`) koriste i webhook i sync.
- **net_profit** se računa pri ulazu: `products.cost_percent`/`cost_fixed`, fallback na `default_margin_percent` sajta; ~5% odbitak za kartična plaćanja (`stripe`).
- **Tip proizvoda:** `digital` ako stavka nema težinu/dimenzije, inače `physical`. Thinkific je uvek `source='thinkific'`, `digital`.
- **Multi-currency:** svi iznosi se konvertuju u base valutu preko `lib/utils/fx.ts` (`toBase`) i formatiraju preko `lib/utils/currency.ts`.
- **Webhook ruta uvek vraća `200`** (i na grešci), da Woo ne gomila retry-jeve. WooCommerce HMAC: `x-wc-webhook-signature` vs `HMAC-SHA256(rawBody, consumer_secret)` u base64.
- **Realtime:** jedan kanal na nivou layout-a (`RealtimeOrdersProvider`), stranice se pretplaćuju preko `subscribeToNewOrders`. Page Visibility refetch + reconnect/heartbeat (30s) su obavezni (TV).
- **Zvuk:** Web Audio se otključava prvim klikom (`unlockAudio()`). Dashboard `SoundProvider` (mute u `localStorage`), TV `TVSoundProvider` (uvek odzvonjen).

## Česte greške (ne ponavljati)

| Problem | Rešenje |
| --- | --- |
| Clerk SignIn greška | Sign-in mora biti catch-all `[[...sign-in]]`; `/sign-in(.*)` u public rutama |
| Geist se ne primenjuje | Font u `globals.css @theme` kao `"Geist"`; `geist.className` na `<body>` |
| `useSearchParams` build greška | Omotati komponentu (FilterBar) u `<Suspense>` |
| Webhook 200 ali prazna tabela | Ne testirati lokalno (Woo ne vidi `localhost`) — koristiti Vercel URL ili tunel |
| Realtime eventi ne stižu | Dodati RLS policy `anon_read_orders` (Realtime šalje preko `anon` role) |
| Realtime petlja CLOSED → SUBSCRIBED | Browser klijent mora biti singleton, ne u hooku |
| Stare porudžbine dobijaju današnji datum | `created_at: order.date_created`, nikad `NOW()` |
| Live feed prikazuje „duhove" | Bez `sessionStorage`; fetch sveže za današnji dan na mount |
| Feed zamrzne na neaktivnom tabu | Page Visibility refetch + reconnect/heartbeat |
| Vercel cron greška | Hobby = samo dnevni cron |
| AOV pogrešan | Deliti **sumom prihoda**, ne brojem porudžbina, kako je definisano u planu |
| FilterBar prikazuje `__all` | Labela treba da piše „Sve" |

## Plan implementacije (redosled)

**Faza 0 — Postavka:** 0.1 init Next.js 16 · 0.2 Tailwind v4 + tokeni · 0.3 shadcn komponente · 0.4 Supabase šema (migracija `001_initial_schema.sql`) · 0.5 Supabase klijenti · 0.6 Clerk auth + `proxy.ts` · 0.7 Vercel deploy · 0.8 layout (sidebar/header, mesta za providere).

**Faza 1 — MVP:** 1.1 Sites CRUD · 1.2 normalizacija + DB helperi · 1.3 Woo webhook · 1.4 Woo backfill sync · 1.5 Thinkific · 1.6 Realtime jezgro · 1.7 KPI · 1.8 live feed · 1.9 orders tabela + FilterBar · 1.10 multi-currency · 1.11 zvučne notifikacije.

**Faza 2 — Analitika:** 2.1 analitika stranica · 2.2 per-site dashboard · 2.3 profit/COGS · 2.4 top products · 2.5 kupci · 2.6 pretplate · 2.7 forecasting · 2.8 cohort · 2.9 goal tracker · 2.10 TV Mode · 2.11 email digest (Resend) · 2.12 QA, bezbednost, lansiranje.

**Zavisnosti:** 1.3 i 1.4 → 1.1 + 1.2 · 1.6 → 0.5 + 0.4 · 1.7/1.8/1.9 → 1.6 · 1.10 pre Faze 2 · 2.11 → Resend nalog + verifikovan domen.

## Mapa ruta

**Stranice (zaštićene osim `/tv`):** `/dashboard` · `/dashboard/[siteId]` · `/analytics` · `/customers` · `/customers/[id]` · `/subscriptions` · `/profit` · `/settings/general` · `/settings/sites` · `/settings/sound` · `/tv` (javna)

**API:** `/api/stats/{kpi,sparklines}` · `/api/kpi` · `/api/kpi-products` · `/api/analytics/{daily-revenue,status-breakdown,top-products,forecast,cohort}` · `/api/customers[/id]` · `/api/profit/{kpi,products,recalculate}` · `/api/subscriptions` · `/api/settings` · `/api/sites[/id]` · `/api/sound-settings[/upload]` · `/api/sync/{all,woo/[siteId],thinkific/[siteId]}` · `/api/webhook/{woo/[siteId],thinkific/[siteId]}` (javne) · `/api/digest/{daily,weekly,monthly}` (cron)

## Status implementacije

Ažuriraj ovu listu kad se korak završi (označi `[x]`).

- [ ] Faza 0 (0.1–0.8)
- [ ] Faza 1 (1.1–1.11)
- [ ] Faza 2 (2.1–2.12)

**Trenutni korak:** 0.3 (0.2 završen — Tailwind v4 + brend tokeni + Geist font, test stranica radi)

## Definicija gotovog

- **Faza 0:** app se deploy-uje, login radi, baza (9 tabela + RLS + indeksi) i Supabase/Clerk povezani, sidebar postoji.
- **Faza 1:** porudžbine sa WooCommerce + Thinkific ulaze (webhook + sync), žive na real-time dashboardu sa 5 KPI-jeva, live feed-om, tabelom sa filterima, multi-currency i zvukom.
- **Faza 2:** analitika, per-site dashboard, profit/COGS, kupci, pretplate, forecasting, cohort, goal tracker, TV Mode i email digest uživo; produkcija ispolirana.
