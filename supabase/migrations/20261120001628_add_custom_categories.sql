-- ============================================================================
-- MIGRATION 5 : add_custom_categories
-- ----------------------------------------------------------------------------
-- Permet aux utilisateurs de créer leur propre catégorie s'ils choisissent "Autre"
-- ============================================================================

-- 1. Ajouter la catégorie "Autre" pour les Business
insert into public.categories (name_fr, name_en, slug, kind) values
  ('Autre', 'Other', 'autre-business', 'business'),
  ('Autre', 'Other', 'autre-service', 'service'),
  ('Autre', 'Other', 'autre-produit', 'product')
on conflict (slug) do nothing;

-- 2. Ajouter la colonne pour le texte libre dans la table businesses
alter table public.businesses 
  add column if not exists custom_category_name text;

comment on column public.businesses.custom_category_name is 
  'Si category_id pointe vers "Autre", ce champ contient le nom écrit par l''utilisateur';

-- 3. Ajouter la colonne dans les services et produits (au cas où ils choisissent "Autre")
alter table public.business_services 
  add column if not exists custom_category_name text;

alter table public.business_products 
  add column if not exists custom_category_name text;

-- ============================================================================
-- FIN DE LA MIGRATION 5
-- ============================================================================