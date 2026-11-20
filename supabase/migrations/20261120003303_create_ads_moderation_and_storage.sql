-- ============================================================================
-- MIGRATION 7 : create_ads_moderation_and_storage (LA MIGRATION FINALE)
-- ----------------------------------------------------------------------------
-- 1. Signalements (reports)
-- 2. Notifications (notifications)
-- 3. Publicités (ad_campaigns, ad_events)
-- 4. Storage (Buckets pour les images) + Politiques de sécurité RLS
-- ============================================================================

-- ============================================================================
-- 1. TABLE REPORTS (Signalements)
-- ============================================================================
create table if not exists public.reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_type public.report_target_type not null,
  target_id   uuid not null, -- Polymorphe (peut être un post, commentaire, user, etc.)
  reason      text not null,
  details     text,
  status      public.report_status not null default 'pending',
  assigned_to uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.reports enable row level security;

-- N'importe quel utilisateur connecté peut signaler
drop policy if exists "reports_insert_own" on public.reports;
create policy "reports_insert_own" on public.reports for insert to authenticated
  with check ((select auth.uid()) = reporter_id);

-- Seuls les admins/modos peuvent voir et traiter les signalements
drop policy if exists "reports_admin_all" on public.reports;
create policy "reports_admin_all" on public.reports for all to authenticated
  using (public.is_admin());

-- ============================================================================
-- 2. TABLE NOTIFICATIONS
-- ============================================================================
create table if not exists public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  type       public.notification_type not null,
  payload    jsonb not null default '{}'::jsonb,
  read_at    timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_notifications_user on public.notifications(user_id, created_at desc);

alter table public.notifications enable row level security;

-- L'utilisateur voit ses propres notifications
drop policy if exists "notifications_own_read" on public.notifications;
create policy "notifications_own_read" on public.notifications for select to authenticated
  using ((select auth.uid()) = user_id);

-- L'utilisateur peut marquer comme lu (update)
drop policy if exists "notifications_own_update" on public.notifications;
create policy "notifications_own_update" on public.notifications for update to authenticated
  using ((select auth.uid()) = user_id);

-- (L'insertion se fera via des Edge Functions ou des Triggers en service_role)

-- ============================================================================
-- 3. TABLES PUBLICITÉS (Ads)
-- ============================================================================
create table if not exists public.ad_campaigns (
  id            uuid primary key default gen_random_uuid(),
  owner_id      uuid not null references public.profiles(id) on delete cascade,
  business_id   uuid references public.businesses(id) on delete cascade,
  title         text not null,
  creative_path text,
  target_rules  jsonb not null default '{}'::jsonb,
  budget        numeric(10,2),
  starts_at     timestamptz,
  ends_at       timestamptz,
  status        public.campaign_status not null default 'draft',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create table if not exists public.ad_events (
  id          uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.ad_campaigns(id) on delete cascade,
  user_id     uuid references public.profiles(id) on delete set null,
  event_type  public.ad_event_type not null,
  occurred_at timestamptz not null default now()
);

-- RLS Publicités
alter table public.ad_campaigns enable row level security;
alter table public.ad_events enable row level security;

-- Tout le monde peut voir les campagnes actives
drop policy if exists "campaigns_public_read" on public.ad_campaigns;
create policy "campaigns_public_read" on public.ad_campaigns for select to anon, authenticated
  using (status = 'active');

-- Le propriétaire gère ses campagnes
drop policy if exists "campaigns_owner_all" on public.ad_campaigns;
create policy "campaigns_owner_all" on public.ad_campaigns for all to authenticated
  using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);

-- Les admins peuvent valider/rejeter les campagnes
drop policy if exists "campaigns_admin_all" on public.ad_campaigns;
create policy "campaigns_admin_all" on public.ad_campaigns for all to authenticated
  using (public.is_admin());

-- Tout le monde (même anonyme) peut générer un événement (vue/clic)
drop policy if exists "ad_events_insert" on public.ad_events;
create policy "ad_events_insert" on public.ad_events for insert to anon, authenticated with check (true);

-- Seuls les propriétaires de la campagne et les admins peuvent lire les stats
drop policy if exists "ad_events_read" on public.ad_events;
create policy "ad_events_read" on public.ad_events for select to authenticated
  using (
    exists (select 1 from public.ad_campaigns c where c.id = campaign_id and c.owner_id = (select auth.uid()))
    or public.is_admin()
  );

-- ============================================================================
-- 4. STORAGE : CRÉATION DES BUCKETS
-- ============================================================================
-- On crée les compartiments (publics ou privés)
insert into storage.buckets (id, name, public) values 
  ('avatars', 'avatars', true),
  ('business-media', 'business-media', true),
  ('post-media', 'post-media', true),
  ('message-media', 'message-media', false),
  ('documents', 'documents', false)
on conflict (id) do nothing;

-- ============================================================================
-- 5. STORAGE : POLITIQUES DE SÉCURITÉ (RLS)
-- ============================================================================

-- --- AVATARS (Public en lecture, Écriture privée) ---
drop policy if exists "avatars_public_read" on storage.objects;
create policy "avatars_public_read" on storage.objects for select
  using (bucket_id = 'avatars');

drop policy if exists "avatars_own_write" on storage.objects;
create policy "avatars_own_write" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid()::text));

drop policy if exists "avatars_own_update" on storage.objects;
create policy "avatars_own_update" on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid()::text));

drop policy if exists "avatars_own_delete" on storage.objects;
create policy "avatars_own_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid()::text));

-- --- BUSINESS-MEDIA (Public en lecture, Écriture par le propriétaire du business) ---
drop policy if exists "business_media_public_read" on storage.objects;
create policy "business_media_public_read" on storage.objects for select
  using (bucket_id = 'business-media');

drop policy if exists "business_media_own_write" on storage.objects;
create policy "business_media_own_write" on storage.objects for insert to authenticated
  with check (
    bucket_id = 'business-media' 
    and exists (select 1 from public.businesses b where b.id::text = (storage.foldername(name))[1] and b.owner_id = (select auth.uid()))
  );

-- --- POST-MEDIA (Public en lecture) ---
drop policy if exists "post_media_public_read" on storage.objects;
create policy "post_media_public_read" on storage.objects for select
  using (bucket_id = 'post-media');

drop policy if exists "post_media_own_write" on storage.objects;
create policy "post_media_own_write" on storage.objects for insert to authenticated
  with check (bucket_id = 'post-media' and (storage.foldername(name))[1] = (select auth.uid()::text));

-- --- MESSAGE-MEDIA (Privé, accessible uniquement aux participants de la conversation) ---
-- Pour simplifier, on stocke dans un dossier par utilisateur : /user_id/fichier
drop policy if exists "message_media_own_read" on storage.objects;
create policy "message_media_own_read" on storage.objects for select to authenticated
  using (bucket_id = 'message-media' and (storage.foldername(name))[1] = (select auth.uid()::text));

drop policy if exists "message_media_own_write" on storage.objects;
create policy "message_media_own_write" on storage.objects for insert to authenticated
  with check (bucket_id = 'message-media' and (storage.foldername(name))[1] = (select auth.uid()::text));

-- ============================================================================
-- FIN DE LA MIGRATION 7 - BACKEND TERMINÉ 🎉
-- ============================================================================