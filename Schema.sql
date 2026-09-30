-- À coller dans Supabase > SQL Editor > Run
create table public.entitlements(
  user_id uuid primary key references auth.users on delete cascade,
  premium boolean not null default false,
  stripe_customer text,
  updated_at timestamptz default now());
create table public.backups(
  user_id uuid primary key references auth.users on delete cascade,
  data jsonb not null,
  updated_at timestamptz default now());
create table public.games(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  local_id text not null,
  data jsonb not null,
  created_at timestamptz default now(),
  unique(user_id, local_id));

alter table public.entitlements enable row level security;
alter table public.backups enable row level security;
alter table public.games enable row level security;

-- Le joueur lit son statut, mais ne peut PAS se donner Premium (seul le webhook Stripe le peut)
create policy "ent_select" on public.entitlements for select using (auth.uid() = user_id);

create policy "bk_select" on public.backups for select using (auth.uid() = user_id);
create policy "bk_insert" on public.backups for insert with check (auth.uid() = user_id);
create policy "bk_update" on public.backups for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "g_select" on public.games for select using (auth.uid() = user_id);
create policy "g_delete" on public.games for delete using (auth.uid() = user_id);
-- Limite de 25 parties côté serveur pour le plan gratuit (impossible à contourner depuis l'app)
create policy "g_insert" on public.games for insert with check (
  auth.uid() = user_id and (
    exists (select 1 from public.entitlements e where e.user_id = auth.uid() and e.premium)
    or (select count(*) from public.games g where g.user_id = auth.uid()) < 25));
