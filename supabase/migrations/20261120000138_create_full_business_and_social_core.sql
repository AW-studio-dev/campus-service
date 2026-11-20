-- ============================================================================
-- MIGRATION UNIQUE : Business, Réseau Social & Catégories
-- ----------------------------------------------------------------------------
-- Ce fichier contient tout le cœur de Campus Service :
--   1. Catégories enrichies (Beauté, Digital, E-commerce, etc.)
--   2. Tables Business (Vitrines, Services, Produits avec 1 seule image)
--   3. Tables Réseau Social (Posts, Commentaires, Likes, Tags)
--   4. RLS (Sécurité) complètes pour toutes les tables
-- ============================================================================

-- ============================================================================
-- PARTIE 1 : ENRICHISSEMENT DES CATÉGORIES
-- ============================================================================

-- 1.1 Catégories principales
insert into public.categories (name_fr, name_en, slug, kind) values
  ('Beauté & Bien-être', 'Beauty & Wellness', 'beaute-bien-etre', 'service'),
  ('Digital & Tech', 'Digital & Tech', 'digital-tech', 'service'),
  ('E-commerce & Intermédiation', 'E-commerce', 'ecommerce-intermediation', 'service'),
  ('Nourriture & Pâtisserie', 'Food & Bakery', 'nourriture-patisserie', 'product'),
  ('Cadeaux & Personnalisation', 'Gifts & Customization', 'cadeaux-personnalisation', 'product'),
  ('Soins & Cosmétiques', 'Care & Cosmetics', 'soins-cosmetiques', 'product'),
  ('Cours & Éducation', 'Tutoring & Education', 'cours-education', 'service')
on conflict (slug) do nothing;

-- 1.2 Sous-catégories
insert into public.categories (parent_id, name_fr, name_en, slug, kind)
select p.id, v.name_fr, v.name_en, v.slug, v.kind
from (values
  ('beaute-bien-etre', 'Makeup Artist', 'Makeup Artist', 'makeup-artist', 'service'),
  ('beaute-bien-etre', 'Hair Artist (Coiffure)', 'Hair Artist', 'hair-artist', 'service'),
  ('beaute-bien-etre', 'Nail Artist (Onglerie)', 'Nail Artist', 'nail-artist', 'service'),
  ('digital-tech', 'Création de sites web', 'Website Creation', 'creation-site-web', 'service'),
  ('digital-tech', 'Création de comptes & Abonnements', 'Accounts & Subscriptions', 'comptes-abonnements', 'service'),
  ('digital-tech', 'Vente de PDF & E-books', 'PDF & E-books', 'vente-pdf-ebooks', 'product'),
  ('ecommerce-intermediation', 'Intermédiaire Shein / Temu', 'Shein / Temu Intermediary', 'intermediaire-shein-temu', 'service'),
  ('ecommerce-intermediation', 'Vêtements', 'Clothing', 'vetements', 'product'),
  ('ecommerce-intermediation', 'Sacs & Accessoires', 'Bags & Accessories', 'sacs-accessoires', 'product'),
  ('ecommerce-intermediation', 'Accessoires PC & Téléphone', 'PC & Phone Accessories', 'accessoires-pc-telephone', 'product'),
  ('ecommerce-intermediation', 'Bijoux & Bijouterie', 'Jewelry', 'bijoux-bijouterie', 'product'),
  ('nourriture-patisserie', 'Pâtisserie (Sucré)', 'Pastry (Sweet)', 'patisserie-sucre', 'product'),
  ('nourriture-patisserie', 'Snacking (Salé)', 'Snacking (Savory)', 'snacking-sale', 'product'),
  ('cadeaux-personnalisation', 'Tasses & Verres personnalisés', 'Custom Cups & Glasses', 'tasses-verres-personnalises', 'product'),
  ('cadeaux-personnalisation', 'Cartes de visite', 'Business Cards', 'cartes-de-visite', 'product'),
  ('soins-cosmetiques', 'Soins capillaires (Hair Care)', 'Hair Care', 'soins-capillaires', 'product'),
  ('soins-cosmetiques', 'Soins de la peau (Skin Care)', 'Skin Care', 'soins-peau', 'product'),
  ('cours-education', 'Cours particuliers', 'Private Tutoring', 'cours-particuliers', 'service')
) as v(parent_slug, name_fr, name_en, slug, kind)
join public.categories p on p.slug = v.parent_slug
on conflict (slug) do nothing;

-- ============================================================================
-- PARTIE 2 : TABLES BUSINESS (Vitrines)
-- ============================================================================

create table if not exists public.businesses (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null unique references public.profiles(id) on delete cascade,
  slug        text not null unique,
  name        text not null,
  description text,
  logo_path   text,
  cover_path  text,
  category_id bigint references public.categories(id) on delete set null,
  wilaya_id   bigint references public.wilayas(id) on delete set null,
  status      public.business_status not null default 'draft',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint business_slug_format check (slug ~ '^[a-z0-9-]+$')
);

create index if not exists idx_businesses_owner on public.businesses(owner_id);
create index if not exists idx_businesses_status on public.businesses(status) where status = 'published';
drop trigger if exists trg_businesses_updated_at on public.businesses;
create trigger trg_businesses_updated_at before update on public.businesses for each row execute function public.set_updated_at();

create table if not exists public.business_services (
  id           uuid primary key default gen_random_uuid(),
  business_id  uuid not null references public.businesses(id) on delete cascade,
  title        text not null,
  description  text,
  price_amount numeric(10,2),
  currency     text default 'DZD',
  cover_image_path text, -- Ajouté directement ici
  status       public.offer_status not null default 'available',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table if not exists public.business_products (
  id           uuid primary key default gen_random_uuid(),
  business_id  uuid not null references public.businesses(id) on delete cascade,
  title        text not null,
  description  text,
  price_amount numeric(10,2),
  currency     text default 'DZD',
  condition    text check (condition in ('new', 'used', 'refurbished')),
  cover_image_path text, -- Ajouté directement ici
  status       public.offer_status not null default 'available',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table if not exists public.business_media (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  storage_path text not null,
  media_type  text check (media_type in ('image', 'video')),
  sort_order  int default 0,
  created_at  timestamptz not null default now()
);

create table if not exists public.reviews (
  id          uuid primary key default gen_random_uuid(),
  reviewer_id uuid not null references public.profiles(id) on delete cascade,
  business_id uuid not null references public.businesses(id) on delete cascade,
  rating      int not null check (rating between 1 and 5),
  comment     text,
  status      public.review_status not null default 'published',
  created_at  timestamptz not null default now()
);

-- ============================================================================
-- PARTIE 3 : TABLES RÉSEAU SOCIAL
-- ============================================================================

create table if not exists public.follows (
  follower_id  uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  created_at   timestamptz not null default now(),
  primary key (follower_id, following_id),
  constraint no_self_follow check (follower_id != following_id)
);

create table if not exists public.posts (
  id          uuid primary key default gen_random_uuid(),
  author_id   uuid not null references public.profiles(id) on delete cascade,
  business_id uuid references public.businesses(id) on delete cascade,
  category_id bigint references public.categories(id) on delete set null,
  post_type   public.post_type not null default 'general',
  body        text not null,
  status      public.post_status not null default 'published',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint body_length check (char_length(body) <= 5000)
);

create index if not exists idx_posts_author on public.posts(author_id);
create index if not exists idx_posts_business on public.posts(business_id);
create index if not exists idx_posts_status on public.posts(status) where status = 'published';
drop trigger if exists trg_posts_updated_at on public.posts;
create trigger trg_posts_updated_at before update on public.posts for each row execute function public.set_updated_at();

create table if not exists public.post_media (
  id          uuid primary key default gen_random_uuid(),
  post_id     uuid not null references public.posts(id) on delete cascade,
  storage_path text not null,
  media_type  text check (media_type in ('image', 'video')),
  sort_order  int default 0,
  created_at  timestamptz not null default now()
);

create table if not exists public.comments (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.posts(id) on delete cascade,
  author_id  uuid not null references public.profiles(id) on delete cascade,
  parent_id  uuid references public.comments(id) on delete cascade,
  body       text not null,
  status     public.post_status not null default 'published',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint comment_body_length check (char_length(body) <= 1000)
);

drop trigger if exists trg_comments_updated_at on public.comments;
create trigger trg_comments_updated_at before update on public.comments for each row execute function public.set_updated_at();

create table if not exists public.reactions (
  id            uuid primary key default gen_random_uuid(),
  post_id       uuid not null references public.posts(id) on delete cascade,
  user_id       uuid not null references public.profiles(id) on delete cascade,
  reaction_type public.reaction_type not null default 'like',
  created_at    timestamptz not null default now(),
  constraint unique_reaction_per_post unique (post_id, user_id)
);

create table if not exists public.tags (
  id      bigint generated always as identity primary key,
  slug    text not null unique,
  name_fr text not null,
  name_en text not null
);

create table if not exists public.post_tags (
  post_id uuid not null references public.posts(id) on delete cascade,
  tag_id  bigint not null references public.tags(id) on delete cascade,
  primary key (post_id, tag_id)
);

create table if not exists public.saved_items (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  item_type  public.saved_item_type not null,
  item_id    uuid not null,
  created_at timestamptz not null default now(),
  constraint unique_saved_item unique (user_id, item_type, item_id)
);

-- ============================================================================
-- PARTIE 4 : ROW LEVEL SECURITY (RLS) COMPLET
-- ============================================================================

-- ----- BUSINESSES -----
alter table public.businesses enable row level security;
drop policy if exists "businesses_public_read" on public.businesses;
create policy "businesses_public_read" on public.businesses for select to anon, authenticated using (status = 'published');
drop policy if exists "businesses_owner_all" on public.businesses;
create policy "businesses_owner_all" on public.businesses for all to authenticated using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);

-- ----- BUSINESS SERVICES & PRODUCTS -----
alter table public.business_services enable row level security;
drop policy if exists "services_public_read" on public.business_services;
create policy "services_public_read" on public.business_services for select to anon, authenticated using (true);
drop policy if exists "services_owner_write" on public.business_services;
create policy "services_owner_write" on public.business_services for all to authenticated 
  using (exists (select 1 from public.businesses b where b.id = business_id and b.owner_id = (select auth.uid())))
  with check (exists (select 1 from public.businesses b where b.id = business_id and b.owner_id = (select auth.uid())));

alter table public.business_products enable row level security;
drop policy if exists "products_public_read" on public.business_products;
create policy "products_public_read" on public.business_products for select to anon, authenticated using (true);
drop policy if exists "products_owner_write" on public.business_products;
create policy "products_owner_write" on public.business_products for all to authenticated 
  using (exists (select 1 from public.businesses b where b.id = business_id and b.owner_id = (select auth.uid())))
  with check (exists (select 1 from public.businesses b where b.id = business_id and b.owner_id = (select auth.uid())));

-- ----- BUSINESS MEDIA -----
alter table public.business_media enable row level security;
drop policy if exists "business_media_public_read" on public.business_media;
create policy "business_media_public_read" on public.business_media for select to anon, authenticated using (true);
drop policy if exists "business_media_owner_write" on public.business_media;
create policy "business_media_owner_write" on public.business_media for all to authenticated 
  using (exists (select 1 from public.businesses b where b.id = business_id and b.owner_id = (select auth.uid())));

-- ----- REVIEWS -----
alter table public.reviews enable row level security;
drop policy if exists "reviews_public_read" on public.reviews;
create policy "reviews_public_read" on public.reviews for select to anon, authenticated using (status = 'published');
drop policy if exists "reviews_user_insert" on public.reviews;
create policy "reviews_user_insert" on public.reviews for insert to authenticated with check ((select auth.uid()) = reviewer_id);
drop policy if exists "reviews_user_update" on public.reviews;
create policy "reviews_user_update" on public.reviews for update to authenticated using ((select auth.uid()) = reviewer_id);

-- ----- POSTS -----
alter table public.posts enable row level security;
drop policy if exists "posts_public_read" on public.posts;
create policy "posts_public_read" on public.posts for select to anon, authenticated using (status = 'published');
drop policy if exists "posts_author_all" on public.posts;
create policy "posts_author_all" on public.posts for all to authenticated using ((select auth.uid()) = author_id) with check ((select auth.uid()) = author_id);

-- ----- POST MEDIA -----
alter table public.post_media enable row level security;
drop policy if exists "post_media_public_read" on public.post_media;
create policy "post_media_public_read" on public.post_media for select to anon, authenticated using (true);
drop policy if exists "post_media_author_write" on public.post_media;
create policy "post_media_author_write" on public.post_media for all to authenticated 
  using (exists (select 1 from public.posts p where p.id = post_id and p.author_id = (select auth.uid())));

-- ----- COMMENTS -----
alter table public.comments enable row level security;
drop policy if exists "comments_public_read" on public.comments;
create policy "comments_public_read" on public.comments for select to anon, authenticated using (status = 'published');
drop policy if exists "comments_author_all" on public.comments;
create policy "comments_author_all" on public.comments for all to authenticated using ((select auth.uid()) = author_id) with check ((select auth.uid()) = author_id);

-- ----- REACTIONS -----
alter table public.reactions enable row level security;
drop policy if exists "reactions_public_read" on public.reactions;
create policy "reactions_public_read" on public.reactions for select to authenticated using (true);
drop policy if exists "reactions_own_write" on public.reactions;
create policy "reactions_own_write" on public.reactions for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- ----- FOLLOWS -----
alter table public.follows enable row level security;
drop policy if exists "follows_public_read" on public.follows;
create policy "follows_public_read" on public.follows for select to authenticated using (true);
drop policy if exists "follows_own_write" on public.follows;
create policy "follows_own_write" on public.follows for all to authenticated using ((select auth.uid()) = follower_id) with check ((select auth.uid()) = follower_id);

-- ----- SAVED ITEMS -----
alter table public.saved_items enable row level security;
drop policy if exists "saved_items_own_all" on public.saved_items;
create policy "saved_items_own_all" on public.saved_items for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- ----- TAGS & POST TAGS -----
alter table public.tags enable row level security;
drop policy if exists "tags_public_read" on public.tags;
create policy "tags_public_read" on public.tags for select to anon, authenticated using (true);

alter table public.post_tags enable row level security;
drop policy if exists "post_tags_public_read" on public.post_tags;
create policy "post_tags_public_read" on public.post_tags for select to anon, authenticated using (true);

-- ============================================================================
-- FIN DE LA MIGRATION UNIQUE
-- ============================================================================