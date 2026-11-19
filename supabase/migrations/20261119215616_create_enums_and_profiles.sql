-- ============================================================================
-- MIGRATION UNIQUE : create_enums_and_profiles
-- ----------------------------------------------------------------------------
-- Contient :
--   SECTION 1 : Tables d'études (study_levels, study_domains, study_fields)
--   SECTION 2 : 18 types ENUM
--   SECTION 3 : Table profiles + trigger auth
--   SECTION 4 : user_interests, user_blocks, notification_preferences
--   SECTION 5 : RLS sur toutes les tables
--   SECTION 6 : Vérification automatique (RAISE NOTICE)
-- ----------------------------------------------------------------------------
-- ⚠️ Idempotent : utilise "if not exists" / "drop ... if exists"
--    Peut être relancé sans casser l'existant.
-- ============================================================================

-- ============================================================================
-- SECTION 1 : TABLES D'ÉTUDES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1.1 study_levels
-- ----------------------------------------------------------------------------
create table if not exists public.study_levels (
  id         bigint generated always as identity primary key,
  code       text not null unique,
  name_fr    text not null,
  name_en    text not null,
  cycle      text check (cycle in ('prepa','licence','master','doctorat','ingenieur','professionnel','autre')),
  sort_order int not null default 0,
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);

comment on table  public.study_levels       is 'Niveaux d''études (système LMD algérien)';
comment on column public.study_levels.cycle is 'Cycle auquel appartient le niveau';

create index if not exists idx_study_levels_cycle on public.study_levels(cycle) where is_active = true;

insert into public.study_levels (code, name_fr, name_en, cycle, sort_order) values
  ('cp1',  'Classe préparatoire 1ère année', 'Preparatory class 1st year', 'prepa', 10),
  ('cp2',  'Classe préparatoire 2ème année', 'Preparatory class 2nd year', 'prepa', 20),
  ('l1',   'Licence 1ère année', 'Bachelor 1st year', 'licence', 30),
  ('l2',   'Licence 2ème année', 'Bachelor 2nd year', 'licence', 40),
  ('l3',   'Licence 3ème année', 'Bachelor 3rd year', 'licence', 50),
  ('m1',   'Master 1ère année', 'Master 1st year', 'master', 60),
  ('m2',   'Master 2ème année', 'Master 2nd year', 'master', 70),
  ('d1',   'Doctorat 1ère année', 'Doctorate 1st year', 'doctorat', 80),
  ('d2',   'Doctorat 2ème année', 'Doctorate 2nd year', 'doctorat', 90),
  ('d3',   'Doctorat 3ème année et +', 'Doctorate 3rd year and beyond', 'doctorat', 100),
  ('ing1', 'Ingénieur 1ère année', 'Engineer 1st year', 'ingenieur', 110),
  ('ing2', 'Ingénieur 2ème année', 'Engineer 2nd year', 'ingenieur', 120),
  ('ing3', 'Ingénieur 3ème année', 'Engineer 3rd year', 'ingenieur', 130),
  ('ing4', 'Ingénieur 4ème année', 'Engineer 4th year', 'ingenieur', 140),
  ('ing5', 'Ingénieur 5ème année', 'Engineer 5th year', 'ingenieur', 150),
  ('prof', 'Formation professionnelle', 'Professional training', 'professionnel', 160),
  ('autre','Autre', 'Other', 'autre', 999)
on conflict (code) do nothing;

-- ----------------------------------------------------------------------------
-- 1.2 study_domains
-- ----------------------------------------------------------------------------
create table if not exists public.study_domains (
  id         bigint generated always as identity primary key,
  code       text not null unique,
  name_fr    text not null,
  name_en    text not null,
  sort_order int not null default 0,
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);

comment on table public.study_domains is 'Domaines LMD officiels en Algérie';

insert into public.study_domains (code, name_fr, name_en, sort_order) values
  ('ST',    'Sciences et Technologies', 'Sciences and Technologies', 10),
  ('MI',    'Mathématiques et Informatique', 'Mathematics and Computer Science', 20),
  ('SM',    'Sciences de la Matière', 'Material Sciences', 30),
  ('SNV',   'Sciences de la Nature et de la Vie', 'Nature and Life Sciences', 40),
  ('SMED',  'Sciences Médicales', 'Medical Sciences', 50),
  ('SHS',   'Sciences Humaines et Sociales', 'Human and Social Sciences', 60),
  ('LL',    'Lettres et Langues', 'Letters and Languages', 70),
  ('SEGC',  'Sciences Économiques, de Gestion et Commerciales', 'Economics, Management and Commerce', 80),
  ('DSP',   'Droit et Sciences Politiques', 'Law and Political Sciences', 90),
  ('SI',    'Sciences Islamiques', 'Islamic Sciences', 100),
  ('AC',    'Arts et Culture', 'Arts and Culture', 110),
  ('STAPS', 'Sciences et Techniques des Activités Physiques et Sportives', 'Sports Sciences', 120),
  ('AUTRE', 'Autre', 'Other', 999)
on conflict (code) do nothing;

-- ----------------------------------------------------------------------------
-- 1.3 study_fields
-- ----------------------------------------------------------------------------
create table if not exists public.study_fields (
  id         bigint generated always as identity primary key,
  domain_id  bigint not null references public.study_domains(id) on delete restrict,
  name_fr    text not null,
  name_en    text not null,
  slug       text not null unique,
  sort_order int not null default 0,
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  constraint study_fields_slug_format check (slug ~ '^[a-z0-9-]+$')
);

comment on table  public.study_fields           is 'Spécialités académiques, liées à un domaine LMD';
comment on column public.study_fields.domain_id is 'Domaine parent (ST, SNV, SHS...)';

create index if not exists idx_study_fields_domain on public.study_fields(domain_id) where is_active = true;
create index if not exists idx_study_fields_name_fr_trgm on public.study_fields using gin (name_fr gin_trgm_ops);

insert into public.study_fields (domain_id, name_fr, name_en, slug, sort_order)
select d.id, v.name_fr, v.name_en, v.slug, v.sort_order
from (values
  -- ST
  ('ST', 'Génie informatique', 'Computer Engineering', 'genie-informatique', 10),
  ('ST', 'Génie logiciel', 'Software Engineering', 'genie-logiciel', 20),
  ('ST', 'Génie civil', 'Civil Engineering', 'genie-civil', 30),
  ('ST', 'Génie mécanique', 'Mechanical Engineering', 'genie-mecanique', 40),
  ('ST', 'Génie électrique', 'Electrical Engineering', 'genie-electrique', 50),
  ('ST', 'Génie des procédés', 'Process Engineering', 'genie-procedes', 60),
  ('ST', 'Architecture', 'Architecture', 'architecture', 70),
  ('ST', 'Urbanisme', 'Urban Planning', 'urbanisme', 80),
  ('ST', 'Hydraulique', 'Hydraulics', 'hydraulique', 90),
  ('ST', 'Électronique', 'Electronics', 'electronique', 100),
  ('ST', 'Automatique', 'Automation', 'automatique', 110),
  ('ST', 'Télécommunications', 'Telecommunications', 'telecommunications', 120),
  ('ST', 'Génie industriel', 'Industrial Engineering', 'genie-industriel', 130),
  ('ST', 'Aéronautique', 'Aeronautics', 'aeronautique', 140),
  -- MI
  ('MI', 'Informatique', 'Computer Science', 'informatique', 10),
  ('MI', 'Mathématiques', 'Mathematics', 'mathematiques', 20),
  ('MI', 'Statistiques', 'Statistics', 'statistiques', 30),
  ('MI', 'Science des données', 'Data Science', 'science-des-donnees', 40),
  ('MI', 'Intelligence artificielle', 'Artificial Intelligence', 'intelligence-artificielle', 50),
  ('MI', 'Cybersécurité', 'Cybersecurity', 'cybersecurite', 60),
  ('MI', 'Recherche opérationnelle', 'Operations Research', 'recherche-operationnelle', 70),
  -- SM
  ('SM', 'Physique', 'Physics', 'physique', 10),
  ('SM', 'Chimie', 'Chemistry', 'chimie', 20),
  ('SM', 'Sciences des matériaux', 'Materials Science', 'sciences-materiaux', 30),
  -- SNV
  ('SNV', 'Biologie', 'Biology', 'biologie', 10),
  ('SNV', 'Agronomie', 'Agronomy', 'agronomie', 20),
  ('SNV', 'Sciences alimentaires', 'Food Sciences', 'sciences-alimentaires', 30),
  ('SNV', 'Écologie', 'Ecology', 'ecologie', 40),
  ('SNV', 'Biotechnologie', 'Biotechnology', 'biotechnologie', 50),
  ('SNV', 'Sciences vétérinaires', 'Veterinary Sciences', 'sciences-veterinaires', 60),
  -- SMED
  ('SMED', 'Médecine', 'Medicine', 'medecine', 10),
  ('SMED', 'Pharmacie', 'Pharmacy', 'pharmacie', 20),
  ('SMED', 'Chirurgie dentaire', 'Dental Surgery', 'chirurgie-dentaire', 30),
  ('SMED', 'Paramédical', 'Paramedical', 'paramedical', 40),
  -- SHS
  ('SHS', 'Psychologie', 'Psychology', 'psychologie', 10),
  ('SHS', 'Sociologie', 'Sociology', 'sociologie', 20),
  ('SHS', 'Histoire', 'History', 'histoire', 30),
  ('SHS', 'Géographie', 'Geography', 'geographie', 40),
  ('SHS', 'Philosophie', 'Philosophy', 'philosophie', 50),
  ('SHS', 'Sciences de l''éducation', 'Education Sciences', 'sciences-education', 60),
  ('SHS', 'Sciences de l''information et de la communication', 'Information and Communication Sciences', 'sciences-information-communication', 70),
  ('SHS', 'Anthropologie', 'Anthropology', 'anthropologie', 80),
  -- LL
  ('LL', 'Langue arabe', 'Arabic Language', 'langue-arabe', 10),
  ('LL', 'Langue française', 'French Language', 'langue-francaise', 20),
  ('LL', 'Langue anglaise', 'English Language', 'langue-anglaise', 30),
  ('LL', 'Langues étrangères appliquées', 'Applied Foreign Languages', 'langues-etrangeres-appliquees', 40),
  ('LL', 'Traduction', 'Translation', 'traduction', 50),
  ('LL', 'Linguistique', 'Linguistics', 'linguistique', 60),
  -- SEGC
  ('SEGC', 'Sciences commerciales', 'Commercial Sciences', 'sciences-commerciales', 10),
  ('SEGC', 'Sciences financières', 'Financial Sciences', 'sciences-financieres', 20),
  ('SEGC', 'Sciences de gestion', 'Management Sciences', 'sciences-gestion', 30),
  ('SEGC', 'Sciences économiques', 'Economics', 'sciences-economiques', 40),
  ('SEGC', 'Comptabilité', 'Accounting', 'comptabilite', 50),
  ('SEGC', 'Marketing', 'Marketing', 'marketing', 60),
  -- DSP
  ('DSP', 'Droit', 'Law', 'droit', 10),
  ('DSP', 'Sciences politiques', 'Political Sciences', 'sciences-politiques', 20),
  ('DSP', 'Relations internationales', 'International Relations', 'relations-internationales', 30),
  -- SI
  ('SI', 'Sciences islamiques', 'Islamic Sciences', 'sciences-islamiques', 10),
  ('SI', 'Charia', 'Sharia', 'charia', 20),
  -- AC
  ('AC', 'Arts visuels', 'Visual Arts', 'arts-visuels', 10),
  ('AC', 'Arts du spectacle', 'Performing Arts', 'arts-spectacle', 20),
  ('AC', 'Design', 'Design', 'design', 30),
  -- STAPS
  ('STAPS', 'Sciences et techniques des activités physiques et sportives', 'Sports Sciences', 'staps', 10)
) as v(domain_code, name_fr, name_en, slug, sort_order)
join public.study_domains d on d.code = v.domain_code
on conflict (slug) do nothing;

-- ----------------------------------------------------------------------------
-- 1.4 RLS sur les 3 tables d'études
-- ----------------------------------------------------------------------------
alter table public.study_levels  enable row level security;
alter table public.study_domains enable row level security;
alter table public.study_fields  enable row level security;

drop policy if exists "study_levels_public_read" on public.study_levels;
create policy "study_levels_public_read"
  on public.study_levels for select to anon, authenticated
  using (is_active = true);

drop policy if exists "study_domains_public_read" on public.study_domains;
create policy "study_domains_public_read"
  on public.study_domains for select to anon, authenticated
  using (is_active = true);

drop policy if exists "study_fields_public_read" on public.study_fields;
create policy "study_fields_public_read"
  on public.study_fields for select to anon, authenticated
  using (is_active = true);

-- ============================================================================
-- SECTION 2 : 18 TYPES ENUM
-- ============================================================================

do $$ begin
  create type public.post_type as enum ('general','product_sale','service_offer','service_request','help_request','collaboration','opportunity','sponsored');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.post_status as enum ('draft','published','hidden','deleted','pending_review');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.business_status as enum ('draft','published','suspended','archived');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.offer_status as enum ('available','unavailable','reserved','closed','archived');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.request_type as enum ('academic_help','private_tutoring','partner_search','project_team','freelance_search','other');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.request_status as enum ('open','in_discussion','fulfilled','closed','expired');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.request_format as enum ('online','in_person','hybrid');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.reaction_type as enum ('like','love','support','insightful');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.saved_item_type as enum ('post','business','service','product','request');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.conversation_type as enum ('direct','group');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.notification_type as enum ('new_message','new_follower','new_comment','new_reaction','new_review','new_request_response','moderation_event','system');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.report_status as enum ('pending','reviewing','resolved','dismissed');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.report_target_type as enum ('post','comment','message','business','user','request');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.review_status as enum ('published','hidden','pending_review');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.campaign_status as enum ('draft','pending_review','approved','rejected','active','paused','completed');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.ad_event_type as enum ('impression','click');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.admin_role as enum ('admin','moderator','support');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.app_locale as enum ('fr','en');
exception when duplicate_object then null; end $$;

-- ============================================================================
-- SECTION 3 : TABLE PROFILES + TRIGGER
-- ============================================================================

create table if not exists public.profiles (
  id             uuid primary key references auth.users(id) on delete cascade,
  display_name   text not null,
  avatar_path    text,
  bio            text,
  wilaya_id      bigint references public.wilayas(id) on delete set null,
  university_id  bigint references public.universities(id) on delete set null,
  study_field_id bigint references public.study_fields(id) on delete set null,
  study_level_id bigint references public.study_levels(id) on delete set null,
  locale         public.app_locale not null default 'fr',
  is_verified    boolean not null default false,
  is_suspended   boolean not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint profiles_display_name_length check (char_length(display_name) between 2 and 80),
  constraint profiles_bio_length check (bio is null or char_length(bio) <= 500)
);

comment on table public.profiles is 'Profil public de chaque membre (1-1 avec auth.users)';

create index if not exists idx_profiles_wilaya          on public.profiles(wilaya_id);
create index if not exists idx_profiles_university      on public.profiles(university_id);
create index if not exists idx_profiles_study_field     on public.profiles(study_field_id);
create index if not exists idx_profiles_study_level     on public.profiles(study_level_id);
create index if not exists idx_profiles_display_name_trgm
  on public.profiles using gin (display_name gin_trgm_ops);

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Trigger de création automatique du profil
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_display_name text;
begin
  v_display_name := coalesce(
    nullif(trim(new.raw_user_meta_data->>'display_name'), ''),
    nullif(split_part(new.email, '@', 1), ''),
    'Étudiant'
  );
  insert into public.profiles (id, display_name) values (new.id, v_display_name);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================================
-- SECTION 4 : USER INTERESTS, BLOCKS, NOTIFICATION PREFERENCES
-- ============================================================================

create table if not exists public.user_interests (
  user_id     uuid   not null references public.profiles(id) on delete cascade,
  interest_id bigint not null references public.interests(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (user_id, interest_id)
);

create index if not exists idx_user_interests_user     on public.user_interests(user_id);
create index if not exists idx_user_interests_interest on public.user_interests(interest_id);

create table if not exists public.user_blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint user_blocks_no_self check (blocker_id != blocked_id)
);

create index if not exists idx_user_blocks_blocked on public.user_blocks(blocked_id);

create table if not exists public.notification_preferences (
  user_id         uuid primary key references public.profiles(id) on delete cascade,
  email_messages  boolean not null default true,
  email_follows   boolean not null default false,
  email_comments  boolean not null default true,
  email_reviews   boolean not null default true,
  email_marketing boolean not null default false,
  push_enabled    boolean not null default false,
  updated_at      timestamptz not null default now()
);

drop trigger if exists trg_notification_preferences_updated_at on public.notification_preferences;
create trigger trg_notification_preferences_updated_at
  before update on public.notification_preferences
  for each row execute function public.set_updated_at();

-- ============================================================================
-- SECTION 5 : RLS
-- ============================================================================

-- profiles
alter table public.profiles enable row level security;
drop policy if exists "profiles_public_read" on public.profiles;
create policy "profiles_public_read"
  on public.profiles for select to anon, authenticated using (true);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- user_interests
alter table public.user_interests enable row level security;
drop policy if exists "user_interests_public_read" on public.user_interests;
create policy "user_interests_public_read"
  on public.user_interests for select to anon, authenticated using (true);

drop policy if exists "user_interests_own_write" on public.user_interests;
create policy "user_interests_own_write"
  on public.user_interests for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- user_blocks
alter table public.user_blocks enable row level security;
drop policy if exists "user_blocks_own_all" on public.user_blocks;
create policy "user_blocks_own_all"
  on public.user_blocks for all to authenticated
  using ((select auth.uid()) = blocker_id)
  with check ((select auth.uid()) = blocker_id);

-- notification_preferences
alter table public.notification_preferences enable row level security;
drop policy if exists "notification_preferences_own_all" on public.notification_preferences;
create policy "notification_preferences_own_all"
  on public.notification_preferences for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- ============================================================================
-- SECTION 6 : VÉRIFICATION AUTOMATIQUE (dans la sortie du push)
-- ============================================================================
do $$
declare
  v_levels int;
  v_domains int;
  v_fields int;
  v_enums int;
  v_tables int;
begin
  select count(*) into v_levels  from public.study_levels;
  select count(*) into v_domains from public.study_domains;
  select count(*) into v_fields  from public.study_fields;
  select count(*) into v_enums   from pg_type
    where typname in ('post_type','post_status','business_status','offer_status',
      'request_type','request_status','request_format','reaction_type','saved_item_type',
      'conversation_type','notification_type','report_status','report_target_type',
      'review_status','campaign_status','ad_event_type','admin_role','app_locale');
  select count(*) into v_tables from information_schema.tables
    where table_schema='public'
      and table_name in ('profiles','user_interests','user_blocks','notification_preferences');

  raise notice '=== MIGRATION OK ===';
  raise notice 'study_levels   : %', v_levels;
  raise notice 'study_domains  : %', v_domains;
  raise notice 'study_fields   : %', v_fields;
  raise notice 'enums          : %', v_enums;
  raise notice 'tables user    : %', v_tables;
end $$;

-- ============================================================================
-- FIN DE LA MIGRATION
-- ============================================================================

-- ============================================================================
-- REQUÊTES DE VÉRIFICATION (à exécuter dans SQL Editor APRÈS le push)
-- ============================================================================
-- Copiez ces requêtes dans le SQL Editor du Dashboard pour vérifier :
--
-- 1. Tables d'études
-- select count(*) from public.study_levels;   -- attendu : 17
-- select count(*) from public.study_domains;  -- attendu : 13
-- select count(*) from public.study_fields;   -- attendu : ~63
--
-- 2. 4 nouvelles tables
-- select table_name from information_schema.tables
-- where table_schema='public'
--   and table_name in ('profiles','user_interests','user_blocks','notification_preferences');
--
-- 3. 18 ENUM
-- select count(*) from pg_type where typname in (
--   'post_type','post_status','business_status','offer_status',
--   'request_type','request_status','request_format','reaction_type','saved_item_type',
--   'conversation_type','notification_type','report_status','report_target_type',
--   'review_status','campaign_status','ad_event_type','admin_role','app_locale');
-- -- attendu : 18
--
-- 4. RLS activée
-- select tablename, rowsecurity from pg_tables
-- where schemaname='public'
--   and tablename in ('profiles','user_interests','user_blocks','notification_preferences',
--                     'study_levels','study_domains','study_fields');
-- -- attendu : 7 lignes, toutes true
--
-- 5. Trigger auth
-- select tgname from pg_trigger where tgname='on_auth_user_created';
-- -- attendu : 1 ligne
--
-- 6. Structure profiles
-- select column_name, data_type from information_schema.columns
-- where table_schema='public' and table_name='profiles'
-- order by ordinal_position;
-- ============================================================================