-- ============================================================================
-- MIGRATION 3 : create_admin_tables (VERSION CORRIGÉE)
-- ----------------------------------------------------------------------------
-- Gestion administrative et modération
-- ============================================================================

-- ============================================================================
-- 1. TABLES (On crée les tables en premier !)
-- ============================================================================

-- Table ADMIN_ROLES
create table if not exists public.admin_roles (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  role       public.admin_role not null,
  granted_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (user_id, role)
);

comment on table public.admin_roles is 'Attribution des rôles privilégiés (admin, moderator, support)';
create index if not exists idx_admin_roles_user on public.admin_roles(user_id);

-- Table AUDIT_LOGS
create table if not exists public.audit_logs (
  id          uuid primary key default gen_random_uuid(),
  actor_id    uuid references public.profiles(id) on delete set null,
  action      text not null,
  target_type text not null,
  target_id   text,
  metadata    jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);

comment on table public.audit_logs is 'Journal d''audit pour toutes les actions administratives';
create index if not exists idx_audit_logs_actor  on public.audit_logs(actor_id);
create index if not exists idx_audit_logs_action on public.audit_logs(action);
create index if not exists idx_audit_logs_date   on public.audit_logs(created_at desc);

-- Table PLATFORM_SETTINGS
create table if not exists public.platform_settings (
  key         text primary key,
  value       jsonb not null,
  description text,
  updated_by  uuid references public.profiles(id) on delete set null,
  updated_at  timestamptz not null default now()
);

comment on table public.platform_settings is 'Paramètres globaux de la plateforme';

insert into public.platform_settings (key, value, description) values
  ('maintenance_mode', 'false'::jsonb, 'Met le site en maintenance (true/false)'),
  ('max_upload_size_mb', '5'::jsonb, 'Taille maximale des fichiers en MB'),
  ('allow_registration', 'true'::jsonb, 'Autoriser ou non les nouvelles inscriptions')
on conflict (key) do nothing;

drop trigger if exists trg_platform_settings_updated_at on public.platform_settings;
create trigger trg_platform_settings_updated_at
  before update on public.platform_settings
  for each row execute function public.set_updated_at();

-- Table SEARCH_HISTORY
create table if not exists public.search_history (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  query      text not null,
  created_at timestamptz not null default now()
);

comment on table public.search_history is 'Historique des recherches (privé, effaçable)';
create index if not exists idx_search_history_user on public.search_history(user_id, created_at desc);

-- ============================================================================
-- 2. FONCTIONS DE SÉCURITÉ (Maintenant que les tables existent)
-- ============================================================================

create or replace function public.has_role(required_role public.admin_role)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.admin_roles
    where user_id = (select auth.uid())
      and role = required_role
  );
$$;

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select public.has_role('admin'::public.admin_role) 
      or public.has_role('moderator'::public.admin_role);
$$;

comment on function public.has_role is 'Vérifie si l''utilisateur connecté possède un rôle spécifique';
comment on function public.is_admin is 'Vérifie si l''utilisateur connecté est admin ou modérateur';

-- ============================================================================
-- 3. ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- ---------- admin_roles ----------
alter table public.admin_roles enable row level security;

drop policy if exists "admin_roles_self_read" on public.admin_roles;
create policy "admin_roles_self_read"
  on public.admin_roles for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "admin_roles_admin_all" on public.admin_roles;
create policy "admin_roles_admin_all"
  on public.admin_roles for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ---------- audit_logs ----------
alter table public.audit_logs enable row level security;

drop policy if exists "audit_logs_admin_read" on public.audit_logs;
create policy "audit_logs_admin_read"
  on public.audit_logs for select to authenticated
  using (public.is_admin());

-- ---------- platform_settings ----------
alter table public.platform_settings enable row level security;

drop policy if exists "platform_settings_public_read" on public.platform_settings;
create policy "platform_settings_public_read"
  on public.platform_settings for select to anon, authenticated
  using (true);

drop policy if exists "platform_settings_admin_write" on public.platform_settings;
create policy "platform_settings_admin_write"
  on public.platform_settings for all to authenticated
  using (public.has_role('admin'::public.admin_role))
  with check (public.has_role('admin'::public.admin_role));

-- ---------- search_history ----------
alter table public.search_history enable row level security;

drop policy if exists "search_history_own_all" on public.search_history;
create policy "search_history_own_all"
  on public.search_history for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- ============================================================================
-- 4. BOOTSTRAP : Attribution du rôle Admin
-- ============================================================================
do $$
declare
  v_test_user_id uuid;
begin
  -- Remplace l'email si nécessaire
  select id into v_test_user_id 
  from auth.users 
  where email = 'aw.studio.dz@gmail.com';

  if v_test_user_id is not null then
    insert into public.admin_roles (user_id, role)
    values (v_test_user_id, 'admin'::public.admin_role)
    on conflict (user_id, role) do nothing;
    
    raise notice 'Rôle ADMIN attribué à aw.studio.dz@gmail.com';
  else
    raise notice 'Compte introuvable. Assure-toi de l''avoir créé dans Authentication.';
  end if;
end $$;

-- ============================================================================
-- FIN DE LA MIGRATION 3
-- ============================================================================