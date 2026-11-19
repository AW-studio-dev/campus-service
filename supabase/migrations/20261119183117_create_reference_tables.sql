-- ============================================================================
-- MIGRATION 1 : create_reference_tables
-- ----------------------------------------------------------------------------
-- Tables de référence (lecture publique, écriture admin uniquement) :
--   - wilayas        : 58 wilayas d'Algérie
--   - universities   : répertoire des établissements
--   - categories     : taxonomie hiérarchique
--   - interests      : centres d'intérêt
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. EXTENSIONS UTILES
-- ----------------------------------------------------------------------------
-- pg_trgm : recherche floue (similarité de texte) pour la recherche future
create extension if not exists pg_trgm;

-- ----------------------------------------------------------------------------
-- 1. TABLE WILAYAS
-- ----------------------------------------------------------------------------
create table public.wilayas (
  id         bigint generated always as identity primary key,
  code       text not null unique,
  name_fr    text not null,
  name_en    text not null,
  created_at timestamptz not null default now(),
  constraint wilayas_code_format check (code ~ '^[0-9]{2}$')
);

comment on table  public.wilayas          is 'Référentiel des 58 wilayas d''Algérie';
comment on column public.wilayas.code     is 'Code officiel à 2 chiffres (ex: 16 pour Alger)';
comment on column public.wilayas.name_fr  is 'Nom en français';
comment on column public.wilayas.name_en  is 'Nom en anglais';

-- Index pour recherche floue par nom
create index idx_wilayas_name_fr_trgm on public.wilayas using gin (name_fr gin_trgm_ops);
create index idx_wilayas_name_en_trgm on public.wilayas using gin (name_en gin_trgm_ops);

-- ----------------------------------------------------------------------------
-- 2. TABLE UNIVERSITIES
-- ----------------------------------------------------------------------------
create table public.universities (
  id          bigint generated always as identity primary key,
  name        text not null,
  short_name  text,
  wilaya_id   bigint not null references public.wilayas(id) on delete restrict,
  type        text check (type in ('university', 'school', 'institute', 'center')),
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table  public.universities             is 'Répertoire des universités, écoles et instituts';
comment on column public.universities.short_name  is 'Sigle ou nom abrégé (ex: USTHB, ESI)';
comment on column public.universities.type        is 'Type d''établissement';
comment on column public.universities.is_active   is 'Un établissement inactif n''apparaît plus dans les filtres';

create index idx_universities_wilaya on public.universities(wilaya_id) where is_active = true;
create index idx_universities_name_trgm on public.universities using gin (name gin_trgm_ops);

-- ----------------------------------------------------------------------------
-- 3. TABLE CATEGORIES (hiérarchique)
-- ----------------------------------------------------------------------------
create table public.categories (
  id          bigint generated always as identity primary key,
  parent_id   bigint references public.categories(id) on delete set null,
  name_fr     text not null,
  name_en     text not null,
  slug        text not null unique,
  kind        text not null check (kind in ('product', 'service', 'post', 'business')),
  sort_order  int not null default 0,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint categories_slug_format check (slug ~ '^[a-z0-9-]+$'),
  constraint categories_no_self_parent check (parent_id is null or parent_id != id)
);

comment on table  public.categories            is 'Taxonomie hiérarchique pour produits, services, posts et businesses';
comment on column public.categories.parent_id  is 'Catégorie parente (NULL = catégorie racine)';
comment on column public.categories.kind       is 'Domaine d''application de la catégorie';
comment on column public.categories.slug       is 'Identifiant URL-safe unique (kebab-case)';

create index idx_categories_parent on public.categories(parent_id);
create index idx_categories_kind on public.categories(kind) where is_active = true;
create index idx_categories_slug on public.categories(slug);
create index idx_categories_name_fr_trgm on public.categories using gin (name_fr gin_trgm_ops);

-- ----------------------------------------------------------------------------
-- 4. TABLE INTERESTS
-- ----------------------------------------------------------------------------
create table public.interests (
  id          bigint generated always as identity primary key,
  name_fr     text not null,
  name_en     text not null,
  slug        text not null unique,
  category_id bigint references public.categories(id) on delete set null,
  created_at  timestamptz not null default now(),
  constraint interests_slug_format check (slug ~ '^[a-z0-9-]+$')
);

comment on table  public.interests             is 'Centres d''intérêt pour personnaliser le fil et les recommandations';
comment on column public.interests.category_id is 'Catégorie associée (optionnelle)';

create index idx_interests_category on public.interests(category_id);
create index idx_interests_name_fr_trgm on public.interests using gin (name_fr gin_trgm_ops);

-- ----------------------------------------------------------------------------
-- 5. TRIGGER updated_at (pour universities et categories)
-- ----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

comment on function public.set_updated_at() is 'Met à jour automatiquement la colonne updated_at';

create trigger trg_universities_updated_at
  before update on public.universities
  for each row execute function public.set_updated_at();

create trigger trg_categories_updated_at
  before update on public.categories
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
-- 6. ROW LEVEL SECURITY
-- ----------------------------------------------------------------------------
alter table public.wilayas      enable row level security;
alter table public.universities enable row level security;
alter table public.categories   enable row level security;
alter table public.interests    enable row level security;

-- Lecture publique (visiteurs + membres connectés)
create policy "wilayas_public_read"
  on public.wilayas for select
  to anon, authenticated
  using (true);

create policy "universities_public_read"
  on public.universities for select
  to anon, authenticated
  using (is_active = true);

create policy "categories_public_read"
  on public.categories for select
  to anon, authenticated
  using (is_active = true);

create policy "interests_public_read"
  on public.interests for select
  to anon, authenticated
  using (true);

-- NOTE : Les politiques d'ÉCRITURE (insert/update/delete) seront ajoutées
-- dans une migration ultérieure, une fois la table admin_roles créée.
-- Aucune écriture n'est autorisée pour l'instant (refus par défaut).

-- ----------------------------------------------------------------------------
-- 7. SEED : Les 58 wilayas d'Algérie
-- ----------------------------------------------------------------------------
insert into public.wilayas (code, name_fr, name_en) values
  ('01', 'Adrar', 'Adrar'),
  ('02', 'Chlef', 'Chlef'),
  ('03', 'Laghouat', 'Laghouat'),
  ('04', 'Oum El Bouaghi', 'Oum El Bouaghi'),
  ('05', 'Batna', 'Batna'),
  ('06', 'Béjaïa', 'Bejaia'),
  ('07', 'Biskra', 'Biskra'),
  ('08', 'Béchar', 'Bechar'),
  ('09', 'Blida', 'Blida'),
  ('10', 'Bouira', 'Bouira'),
  ('11', 'Tamanrasset', 'Tamanrasset'),
  ('12', 'Tébessa', 'Tebessa'),
  ('13', 'Tlemcen', 'Tlemcen'),
  ('14', 'Tiaret', 'Tiaret'),
  ('15', 'Tizi Ouzou', 'Tizi Ouzou'),
  ('16', 'Alger', 'Algiers'),
  ('17', 'Djelfa', 'Djelfa'),
  ('18', 'Jijel', 'Jijel'),
  ('19', 'Sétif', 'Setif'),
  ('20', 'Saïda', 'Saida'),
  ('21', 'Skikda', 'Skikda'),
  ('22', 'Sidi Bel Abbès', 'Sidi Bel Abbes'),
  ('23', 'Annaba', 'Annaba'),
  ('24', 'Guelma', 'Guelma'),
  ('25', 'Constantine', 'Constantine'),
  ('26', 'Médéa', 'Medea'),
  ('27', 'Mostaganem', 'Mostaganem'),
  ('28', 'M''Sila', 'MSila'),
  ('29', 'Mascara', 'Mascara'),
  ('30', 'Ouargla', 'Ouargla'),
  ('31', 'Oran', 'Oran'),
  ('32', 'El Bayadh', 'El Bayadh'),
  ('33', 'Illizi', 'Illizi'),
  ('34', 'Bordj Bou Arreridj', 'Bordj Bou Arreridj'),
  ('35', 'Boumerdès', 'Boumerdes'),
  ('36', 'El Tarf', 'El Tarf'),
  ('37', 'Tindouf', 'Tindouf'),
  ('38', 'Tissemsilt', 'Tissemsilt'),
  ('39', 'El Oued', 'El Oued'),
  ('40', 'Khenchela', 'Khenchela'),
  ('41', 'Souk Ahras', 'Souk Ahras'),
  ('42', 'Tipaza', 'Tipaza'),
  ('43', 'Mila', 'Mila'),
  ('44', 'Aïn Defla', 'Ain Defla'),
  ('45', 'Naâma', 'Naama'),
  ('46', 'Aïn Témouchent', 'Ain Temouchent'),
  ('47', 'Ghardaïa', 'Ghardaia'),
  ('48', 'Relizane', 'Relizane'),
  ('49', 'Timimoun', 'Timimoun'),
  ('50', 'Bordj Badji Mokhtar', 'Bordj Badji Mokhtar'),
  ('51', 'Ouled Djellal', 'Ouled Djellal'),
  ('52', 'Béni Abbès', 'Beni Abbes'),
  ('53', 'In Salah', 'In Salah'),
  ('54', 'In Guezzam', 'In Guezzam'),
  ('55', 'Touggourt', 'Touggourt'),
  ('56', 'Djanet', 'Djanet'),
  ('57', 'El M''Ghair', 'El Mghair'),
  ('58', 'El Meniaa', 'El Meniaa');

-- ----------------------------------------------------------------------------
-- 8. SEED : Catégories de base
-- ----------------------------------------------------------------------------
-- Services
insert into public.categories (name_fr, name_en, slug, kind) values
  ('Services académiques', 'Academic services', 'services-academiques', 'service'),
  ('Services numériques', 'Digital services', 'services-numeriques', 'service'),
  ('Services créatifs', 'Creative services', 'services-creatifs', 'service'),
  ('Services pratiques', 'Practical services', 'services-pratiques', 'service');

-- Produits
insert into public.categories (name_fr, name_en, slug, kind) values
  ('Livres et supports', 'Books and materials', 'livres-supports', 'product'),
  ('Électronique', 'Electronics', 'electronique', 'product'),
  ('Fournitures', 'Supplies', 'fournitures', 'product');

-- Posts
insert into public.categories (name_fr, name_en, slug, kind) values
  ('Aide scolaire', 'Academic help', 'aide-scolaire', 'post'),
  ('Collaboration', 'Collaboration', 'collaboration', 'post'),
  ('Opportunités', 'Opportunities', 'opportunites', 'post');


-- ----------------------------------------------------------------------------
-- 9. SEED : Universités, écoles et instituts d'Algérie
-- ----------------------------------------------------------------------------
-- Source : MESRS (liste compilée, vérifiable sur mesrs.dz)
-- Le wilaya_id est résolu automatiquement via le code à 2 chiffres.
-- On utilise un JOIN pour garantir la cohérence, même si l'ordre change.

-- 9.1 Universités publiques
insert into public.universities (name, short_name, wilaya_id, type)
select v.name, v.short_name, w.id, 'university'::text
from (values
  -- Centre
  ('Université Ahmed Draya d''Adrar', null::text, '01'),
  ('Université Hassiba Benbouali de Chlef', null, '02'),
  ('Université Amar Telidji de Laghouat', null, '03'),
  ('Université Abderrahmane Mira de Béjaïa', null, '06'),
  ('Université Blida 1 – Saad Dahlab', 'Blida 1', '09'),
  ('Université Blida 2 – Lounici Ali', 'Blida 2', '09'),
  ('Université Akli Mohand Oulhadj de Bouira', null, '10'),
  ('Université Mouloud Mammeri de Tizi Ouzou', 'UMMTO', '15'),
  ('Université Alger 1 – Benyoucef Benkhedda', 'Alger 1', '16'),
  ('Université Alger 2 – Abou El Kacem Saâdallah', 'Alger 2', '16'),
  ('Université Alger 3 – Ibrahim Soltane Chaibout', 'Alger 3', '16'),
  ('Université des Sciences et de la Technologie Houari Boumediene', 'USTHB', '16'),
  ('Université de la Formation Continue', 'UFC', '16'),
  ('Université Ziane Achour de Djelfa', null, '17'),
  ('Université Yahia Farès de Médéa', null, '26'),
  ('Université M''hamed Bougara de Boumerdès', 'UMBB', '35'),
  ('Université Abdallah Morsli de Tipaza', null, '42'),
  -- Est
  ('Université Larbi Ben M''hidi d''Oum El Bouaghi', null, '04'),
  ('Université Batna 1 – Hadj Lakhder', 'Batna 1', '05'),
  ('Université Batna 2 – Mustapha Ben Boulaïd', 'Batna 2', '05'),
  ('Université Mohamed Khider de Biskra', null, '07'),
  ('Université Larbi Tébessi de Tébessa', null, '12'),
  ('Université Mohammed Seddik Ben Yahia de Jijel', null, '18'),
  ('Université Sétif 1 – Ferhat Abbas', 'Sétif 1', '19'),
  ('Université Sétif 2 – Mohamed Lamine Debaghine', 'Sétif 2', '19'),
  ('Université du 20 Août 1955 de Skikda', null, '21'),
  ('Université Badji Mokhtar d''Annaba', 'UBMA', '23'),
  ('Université 8 Mai 1945 de Guelma', null, '24'),
  ('Université Constantine 1 – Frères Mentouri', 'Constantine 1', '25'),
  ('Université Constantine 2 – Abdelhamid Mehri', 'Constantine 2', '25'),
  ('Université Constantine 3 – Salah Boubnider', 'Constantine 3', '25'),
  ('Université des Sciences Islamiques Emir Abdelkader', 'USIEA', '25'),
  ('Université Mohamed Boudiaf de M''Sila', null, '28'),
  ('Université Mohamed Bachir El Ibrahimi de Bordj Bou Arréridj', null, '34'),
  ('Université Chadli Bendjedid d''El Tarf', null, '36'),
  ('Université Hamma Lakhdar d''El Oued', null, '39'),
  ('Université Abbas Laghrour de Khenchela', null, '40'),
  ('Université Mohamed Cherif Messaadia de Souk Ahras', null, '41'),
  ('Université Abdelhafid Boussouf de Mila', null, '43'),
  -- Ouest
  ('Université Mohamed Tahri de Béchar', null, '08'),
  ('Université Abou Bekr Belkaïd de Tlemcen', null, '13'),
  ('Université Ibn Khaldoun de Tiaret', null, '14'),
  ('Université Tahar Moulay de Saïda', null, '20'),
  ('Université Djillali Liabes de Sidi Bel Abbès', 'UDL', '22'),
  ('Université Abdelhamid Ibn Badis de Mostaganem', 'UMAB', '27'),
  ('Université Mustapha Stambouli de Mascara', null, '29'),
  ('Université Oran 1 – Ahmed Ben Bella', 'Oran 1', '31'),
  ('Université Oran 2 – Mohamed Ben Ahmed', 'Oran 2', '31'),
  ('Université des Sciences et de la Technologie Mohamed Boudiaf d''Oran', 'USTO-MB', '31'),
  ('Université de Tissemsilt', null, '38'),
  ('Université Belhadj Bouchaib d''Aïn Témouchent', null, '46'),
  ('Université de Relizane', null, '48'),
  -- Sud
  ('Université de Tamanrasset', null, '11'),
  ('Université Kasdi Merbah de Ouargla', 'UKMO', '30'),
  ('Université de Ghardaïa', null, '47'),
  ('Université Nour Bachir d''El Bayadh', null, '32')
) as v(name, short_name, wilaya_code)
join public.wilayas w on w.code = v.wilaya_code;

-- 9.2 Écoles nationales supérieures et grandes écoles
insert into public.universities (name, short_name, wilaya_id, type)
select v.name, v.short_name, w.id, 'school'::text
from (values
  ('École Nationale Supérieure de l''Agriculture Saharienne d''Adrar', null::text, '01'),
  ('École Nationale Supérieure des Énergies Renouvelables, de l''Environnement et du Développement Durable', 'ENSEERDD', '05'),
  ('École Supérieure en Sciences et Technologies de l''Informatique et du Numérique', 'ESTIN', '06'),
  ('École Nationale Supérieure d''Hydraulique – Arbaoui Abdellah', 'ENSH', '09'),
  ('École Supérieure en Sciences Appliquées de Tlemcen', 'ESSAT', '13'),
  ('École Supérieure de Management de Tlemcen', 'ESMT', '13'),
  ('École Nationale Polytechnique', 'ENP', '16'),
  ('École Nationale Supérieure d''Informatique', 'ESI', '16'),
  ('École Nationale Supérieure d''Agronomie', 'ENSA', '16'),
  ('École Nationale Supérieure des Travaux Publics – Francis Jeanson', 'ENSTP', '16'),
  ('École Nationale Supérieure Vétérinaire – Rabie Bouchama', 'ENSV', '16'),
  ('École Polytechnique d''Architecture et d''Urbanisme – Hocine Aït Ahmed', 'EPAU', '16'),
  ('École Nationale Supérieure de Statistique et d''Économie Appliquée', 'ENSSEA', '16'),
  ('École des Hautes Études Commerciales', 'EHEC', '16'),
  ('École Supérieure de Commerce', 'ESC', '16'),
  ('École Nationale Supérieure des Sciences de la Mer et de l''Aménagement du Littoral', 'ENSSMAL', '16'),
  ('École Nationale Supérieure de Management', 'ENSM', '16'),
  ('École Nationale Supérieure de Journalisme et des Sciences de l''Information', 'ENSJSI', '16'),
  ('École Nationale Supérieure des Sciences Politiques', 'ENSSP', '16'),
  ('École Supérieure des Sciences de l''Aliment et des Industries Agroalimentaires', 'ESSAIA', '16'),
  ('École Supérieure de Gestion et d''Économie Numérique', 'ESGEN', '16'),
  ('École Nationale Supérieure en Intelligence Artificielle', 'ENSIA', '16'),
  ('École Nationale Supérieure en Mathématiques', 'ENSMath', '16'),
  ('École Nationale Supérieure des Technologies Avancées', 'ENTA', '16'),
  ('École Nationale Supérieure de Cybersécurité', 'ENSC', '16'),
  ('École Nationale Supérieure en Nanosciences et Nanotechnologies', 'ENSNN', '16'),
  ('École Nationale Supérieure de Technologie des Systèmes Autonomes', 'ENSTA', '16'),
  ('École Nationale Supérieure de Technologie et d''Ingénierie d''Annaba', 'ESTI Annaba', '23'),
  ('École Supérieure des Sciences de Gestion d''Annaba', 'ESSGA', '23'),
  ('École Nationale Polytechnique de Constantine – Malek Bennabi', 'ENPC', '25'),
  ('École Nationale Supérieure de Biotechnologie – Toufik Khaznadar', 'ENSB', '25'),
  ('École Supérieure de Comptabilité et de Finance de Constantine', 'ESCF', '25'),
  ('École Supérieure Agronomique de Mostaganem', 'ESAM', '27'),
  ('École Nationale Polytechnique d''Oran – Maurice Audin', 'ENPO', '31'),
  ('École Supérieure en Génie Électrique et Énergétique d''Oran', 'ESGEEO', '31'),
  ('École Supérieure des Sciences Biologiques d''Oran', 'ESSBO', '31'),
  ('École Supérieure d''Économie d''Oran', 'ESEO', '31'),
  ('École Nationale Supérieure des Forêts de Khenchela', 'ENSF', '40'),
  ('École Supérieure de l''Agriculture Saharienne d''El Oued', 'ESAS', '39'),
  ('École Supérieure d''Informatique de Sidi Bel Abbès', 'ESI-SBA', '22')
) as v(name, short_name, wilaya_code)
join public.wilayas w on w.code = v.wilaya_code;

-- 9.3 Écoles Normales Supérieures (ENS)
insert into public.universities (name, short_name, wilaya_id, type)
select v.name, v.short_name, w.id, 'school'::text
from (values
  ('École Normale Supérieure de Bouzaréah – Cheikh Mubarak Ben Mohamed Brahimi El Mili', 'ENS Bouzaréah', '16'),
  ('École Normale Supérieure de Kouba – Mohamed Bachir El Ibrahimi', 'ENS Kouba', '16'),
  ('École Normale Supérieure des Sourds-Muets', 'ENS Sourds-Muets', '16'),
  ('École Normale Supérieure de Laghouat – Taleb Abderrahmane', 'ENS Laghouat', '03'),
  ('École Normale Supérieure de Constantine – Assia Djebar', 'ENS Constantine', '25'),
  ('École Normale Supérieure d''Enseignement Technologique de Skikda', 'ENS Skikda', '21'),
  ('École Normale Supérieure de Sétif – Messaoud Zeghar', 'ENS Sétif', '19'),
  ('École Normale Supérieure de Bou Saâda', 'ENS Bou Saâda', '28'),
  ('École Normale Supérieure de Ouargla', 'ENS Ouargla', '30'),
  ('École Normale Supérieure de Mostaganem', 'ENS Mostaganem', '27'),
  ('École Normale Supérieure d''Oran', 'ENS Oran', '31'),
  ('École Normale Supérieure de Béchar', 'ENS Béchar', '08'),
  ('École Normale Supérieure de Saïda', 'ENS Saïda', '20')
) as v(name, short_name, wilaya_code)
join public.wilayas w on w.code = v.wilaya_code;

-- 9.4 Centres universitaires
insert into public.universities (name, short_name, wilaya_id, type)
select v.name, v.short_name, w.id, 'center'::text
from (values
  ('Centre universitaire d''Aflou', null::text, '03'),
  ('Centre universitaire de Barika – Si El Haouès', null, '05'),
  ('Centre universitaire de Maghnia', null, '13'),
  ('Centre universitaire Nour Bachir d''El Bayadh', null, '32'),
  ('Centre universitaire Cheikh Amoud Ben Mokhtar d''Illizi', null, '33'),
  ('Centre universitaire de Tindouf', null, '37'),
  ('Centre universitaire de Tipaza', null, '42'),
  ('Centre universitaire de Mila', null, '43'),
  ('Centre universitaire Ahmed Salhi de Naâma', null, '45')
) as v(name, short_name, wilaya_code)
join public.wilayas w on w.code = v.wilaya_code;

-- 9.5 Principaux établissements privés (agréés MESRS)
insert into public.universities (name, short_name, wilaya_id, type)
select v.name, v.short_name, w.id, 'institute'::text
from (values
  ('Institut de Management et de Développement', 'MDI', '16'),
  ('École Supérieure d''Hôtellerie et de Restauration d''Alger – Aïn Benian', 'ESHRA', '16'),
  ('Institut de Management d''Alger', 'IMA', '16'),
  ('Institut de Formation d''Assurances et de Gestion', 'IFAG', '16'),
  ('Institut de Management – INSIM SUP', 'INSIM SUP', '16'),
  ('École de Management de Tizi Ouzou', 'EMTO', '15'),
  ('École de Formation en Techniques de Gestion', 'EFTG', '16'),
  ('Institut d''Optométrie de Bordj Bou Arréridj', null, '34'),
  ('École de Management d''Alger', 'EMA', '16'),
  ('École Supérieure des Sciences et Technologie', 'ESST', '16'),
  ('Institut Supérieur des Sciences', 'ISS', '16'),
  ('Institut Supérieur de Commerce et de Gestion de Sétif', 'ISCG', '19'),
  ('Institut Supérieur de Gestion', 'ISG', '16'),
  ('Institut d''Optométrie d''Ouled Fayet', null, '16'),
  ('Institut de Technologie NUMIDIA', null, '16'),
  ('École Supérieure des Métiers du Bâtiment', 'ESMB', '16'),
  ('Institut Supérieur des Sciences et de la Technologie Ibn Rochd SUP', 'Ibn Rochd SUP', '16'),
  ('Institut Supérieur des Sciences Humaines et Sociales', 'ISSH', '16'),
  ('Higher Institute of Science & Technology', 'HIST', '16'),
  ('Institut Supérieur d''Optométrie et d''Optique de la Vision', 'ISOO', '16'),
  ('Institut Supérieur des Sciences et de l''Informatique', 'ISI', '16'),
  ('Institut Supérieur Méditerranéen des Affaires et des Sciences', 'ISMAS', '16'),
  ('École Supérieure des Sciences et Technologie Innovative', 'ESSTI', '16'),
  ('École Supérieure Algérienne des Affaires', 'ESAA', '16')
) as v(name, short_name, wilaya_code)
join public.wilayas w on w.code = v.wilaya_code;

-- Mise à jour du compteur d'établissements (vérification)
do $$
declare
  total int;
begin
  select count(*) into total from public.universities;
  raise notice 'Total établissements insérés : %', total;
end $$;


-- ============================================================================
-- FIN DE LA MIGRATION 1
-- ============================================================================