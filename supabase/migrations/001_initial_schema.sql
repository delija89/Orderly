-- Orderly — initial schema (migration 001)
-- Multi-Store Order Command Center: 9 tables, RLS, indexes, realtime.
-- Safe to re-run: extensions guarded, policies dropped before create,
-- settings seeded with ON CONFLICT DO NOTHING, publication add guarded.

-- Needed for gen_random_uuid()
create extension if not exists pgcrypto;

-- Shared trigger: bump updated_at on UPDATE
create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 1. sites — sales channels
-- ---------------------------------------------------------------------------
create table if not exists sites (
  id                     uuid primary key default gen_random_uuid(),
  name                   text not null,
  platform               text not null check (platform in ('woocommerce', 'thinkific')),
  url                    text,
  consumer_key           text,            -- WooCommerce REST key
  consumer_secret        text,            -- WooCommerce REST secret + HMAC webhook secret
  api_key                text,            -- Thinkific API key
  subdomain              text,            -- Thinkific subdomain
  color_hex              text not null default '#1B6EF3',
  project_type           text,
  default_margin_percent numeric(5,2),
  is_active              boolean not null default true,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 2. customers — deduplicated cross-platform by email
-- ---------------------------------------------------------------------------
create table if not exists customers (
  id             uuid primary key default gen_random_uuid(),
  email          text not null unique,
  name           text,
  total_spent    numeric(12,2) not null default 0,
  order_count    integer not null default 0,
  first_order_at timestamptz,
  last_order_at  timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 5. products — defined before orders/order_items reference it
-- ---------------------------------------------------------------------------
create table if not exists products (
  id             uuid primary key default gen_random_uuid(),
  site_id        uuid references sites(id) on delete cascade,
  woo_product_id text,
  name           text,
  sku            text,
  product_type   text check (product_type in ('digital', 'physical')),
  cost_percent   numeric(5,2),
  cost_fixed     numeric(12,2),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (site_id, woo_product_id)
);

-- ---------------------------------------------------------------------------
-- 3. orders — created_at holds the ORIGINAL source date, never NOW()
-- ---------------------------------------------------------------------------
create table if not exists orders (
  id             uuid primary key default gen_random_uuid(),
  site_id        uuid not null references sites(id) on delete cascade,
  woo_order_id   text not null,                     -- external order id (Woo + Thinkific)
  customer_id    uuid references customers(id),
  customer_email text,
  source         text not null check (source in ('woocommerce', 'thinkific')),
  status         text not null,
  currency       text not null default 'EUR',
  total          numeric(12,2) not null default 0,  -- gross, in source currency
  net_profit     numeric(12,2),
  payment_method text,                              -- 'stripe' => ~5% card deduction (step 1.2)
  created_at     timestamptz not null,              -- source order.date_created (NO default: fail loud)
  updated_at     timestamptz,                       -- source order.date_modified
  synced_at      timestamptz not null default now(),
  unique (site_id, woo_order_id)
);

create index if not exists orders_site_id_idx        on orders (site_id);
create index if not exists orders_created_at_idx      on orders (created_at desc);
create index if not exists orders_status_idx          on orders (status);
create index if not exists orders_customer_email_idx  on orders (customer_email);

-- ---------------------------------------------------------------------------
-- 4. order_items
-- ---------------------------------------------------------------------------
create table if not exists order_items (
  id             uuid primary key default gen_random_uuid(),
  order_id       uuid not null references orders(id) on delete cascade,
  product_id     uuid references products(id),
  woo_product_id text,
  name           text,
  sku            text,
  quantity       integer not null default 1,
  unit_price     numeric(12,2),
  total          numeric(12,2),
  product_type   text check (product_type in ('digital', 'physical')),
  net_profit     numeric(12,2)
);

create index if not exists order_items_order_id_idx on order_items (order_id);

-- ---------------------------------------------------------------------------
-- 6. subscriptions
-- ---------------------------------------------------------------------------
create table if not exists subscriptions (
  id              uuid primary key default gen_random_uuid(),
  site_id         uuid references sites(id) on delete cascade,
  customer_id     uuid references customers(id),
  external_id     text,
  status          text check (status in ('active', 'paused', 'cancelled', 'trial')),
  amount          numeric(12,2),
  currency        text,
  interval        text,
  started_at      timestamptz,
  next_payment_at timestamptz,
  cancelled_at    timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (site_id, external_id)
);

-- ---------------------------------------------------------------------------
-- 7. settings — generic KV store
-- ---------------------------------------------------------------------------
create table if not exists settings (
  key        text primary key,
  value      jsonb not null,
  updated_at timestamptz not null default now()
);

insert into settings (key, value) values
  ('base_currency',       '"EUR"'::jsonb),
  ('exchange_rates',      '{"EUR": 1, "RSD": 117.5, "USD": 0.92}'::jsonb),
  ('goal_daily_global',   '0'::jsonb),
  ('tv_rotation_interval','15'::jsonb)
on conflict (key) do nothing;

-- ---------------------------------------------------------------------------
-- 8. sync_log
-- ---------------------------------------------------------------------------
create table if not exists sync_log (
  id               uuid primary key default gen_random_uuid(),
  site_id          uuid references sites(id) on delete cascade,  -- nullable for sync/all
  sync_type        text,   -- 'webhook' | 'manual' | 'cron'
  status           text,   -- 'success' | 'error' | 'partial'
  orders_processed integer not null default 0,
  orders_created   integer not null default 0,
  orders_updated   integer not null default 0,
  message          text,
  duration_ms      integer,
  created_at       timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 9. sound_settings — per site (NULL site_id = global default)
-- ---------------------------------------------------------------------------
create table if not exists sound_settings (
  id               uuid primary key default gen_random_uuid(),
  site_id          uuid references sites(id) on delete cascade,
  enabled          boolean not null default true,
  volume           numeric(3,2) not null default 0.80,
  sound_url        text,
  trigger_statuses text[] not null default array['processing', 'completed'],
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (site_id)
);

-- ---------------------------------------------------------------------------
-- updated_at triggers (NOT on orders: its updated_at = source date_modified)
-- ---------------------------------------------------------------------------
drop trigger if exists set_updated_at on sites;
create trigger set_updated_at before update on sites
  for each row execute function set_updated_at();

drop trigger if exists set_updated_at on customers;
create trigger set_updated_at before update on customers
  for each row execute function set_updated_at();

drop trigger if exists set_updated_at on products;
create trigger set_updated_at before update on products
  for each row execute function set_updated_at();

drop trigger if exists set_updated_at on subscriptions;
create trigger set_updated_at before update on subscriptions
  for each row execute function set_updated_at();

drop trigger if exists set_updated_at on settings;
create trigger set_updated_at before update on settings
  for each row execute function set_updated_at();

drop trigger if exists set_updated_at on sound_settings;
create trigger set_updated_at before update on sound_settings
  for each row execute function set_updated_at();

-- ---------------------------------------------------------------------------
-- Row Level Security — enable on all tables
-- ---------------------------------------------------------------------------
alter table sites          enable row level security;
alter table customers      enable row level security;
alter table products       enable row level security;
alter table orders         enable row level security;
alter table order_items    enable row level security;
alter table subscriptions  enable row level security;
alter table settings       enable row level security;
alter table sync_log       enable row level security;
alter table sound_settings enable row level security;

-- Policies: authenticated SELECT + service_role ALL on every table.
-- Applied per table via DO block so a re-run stays clean.
do $$
declare
  t text;
begin
  foreach t in array array[
    'sites', 'customers', 'products', 'orders', 'order_items',
    'subscriptions', 'settings', 'sync_log', 'sound_settings'
  ]
  loop
    execute format('drop policy if exists authenticated_read_all on %I;', t);
    execute format(
      'create policy authenticated_read_all on %I for select to authenticated using (true);', t
    );

    execute format('drop policy if exists service_role_all on %I;', t);
    execute format(
      'create policy service_role_all on %I for all to service_role using (true) with check (true);', t
    );
  end loop;
end;
$$;

-- Realtime sends events over the anon role: orders needs an anon SELECT policy.
drop policy if exists anon_read_orders on orders;
create policy anon_read_orders on orders for select to anon using (true);

-- ---------------------------------------------------------------------------
-- Realtime publication — add orders (guarded so re-run does not fail)
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'orders'
  ) then
    alter publication supabase_realtime add table orders;
  end if;
end;
$$;
