-- ============================================================================
-- MIGRATION 6 : create_messaging_and_requests
-- ----------------------------------------------------------------------------
-- 1. Messagerie privée (Conversations, Membres, Messages)
-- 2. Demandes étudiantes (Service Requests)
-- ============================================================================

-- ============================================================================
-- 1. TABLES MESSAGERIE
-- ============================================================================

-- Conteneur de conversation (Direct ou Groupe)
create table if not exists public.conversations (
  id              uuid primary key default gen_random_uuid(),
  type            public.conversation_type not null default 'direct',
  created_at      timestamptz not null default now(),
  last_message_at timestamptz not null default now()
);

-- Participants à la conversation
create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id         uuid not null references public.profiles(id) on delete cascade,
  last_read_at    timestamptz default now(),
  joined_at       timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create index if not exists idx_conversation_members_user on public.conversation_members(user_id);

-- Les messages
create table if not exists public.messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id       uuid not null references public.profiles(id) on delete cascade,
  body            text not null,
  attachment_path text,
  created_at      timestamptz not null default now(),
  edited_at       timestamptz,
  constraint message_body_length check (char_length(body) <= 5000)
);

create index if not exists idx_messages_conversation on public.messages(conversation_id, created_at desc);

-- ============================================================================
-- 2. TABLE DEMANDES ÉTUDIANTES
-- ============================================================================

create table if not exists public.service_requests (
  id            uuid primary key default gen_random_uuid(),
  author_id     uuid not null references public.profiles(id) on delete cascade,
  request_type  public.request_type not null default 'academic_help',
  title         text not null,
  description   text,
  subject       text, -- Ex: Mathématiques, Physique...
  level_id      bigint references public.study_levels(id) on delete set null, -- Utilise tes niveaux LMD
  format        public.request_format not null default 'online',
  wilaya_id     bigint references public.wilayas(id) on delete set null,
  budget_amount numeric(10,2),
  status        public.request_status not null default 'open',
  deadline      timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists idx_service_requests_author on public.service_requests(author_id);
create index if not exists idx_service_requests_status on public.service_requests(status) where status = 'open';

drop trigger if exists trg_service_requests_updated_at on public.service_requests;
create trigger trg_service_requests_updated_at before update on public.service_requests for each row execute function public.set_updated_at();

-- ============================================================================
-- 3. ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- ----- CONVERSATIONS -----
alter table public.conversations enable row level security;

-- Un utilisateur ne voit que les conversations auxquelles il participe
drop policy if exists "conversations_participant_read" on public.conversations;
create policy "conversations_participant_read" on public.conversations for select to authenticated
  using (exists (select 1 from public.conversation_members cm where cm.conversation_id = id and cm.user_id = (select auth.uid())));

-- Création de conversation autorisée
drop policy if exists "conversations_insert" on public.conversations;
create policy "conversations_insert" on public.conversations for insert to authenticated with check (true);

-- ----- CONVERSATION MEMBERS -----
alter table public.conversation_members enable row level security;

-- Voir les membres de ses propres conversations
drop policy if exists "conversation_members_read" on public.conversation_members;
create policy "conversation_members_read" on public.conversation_members for select to authenticated
  using (exists (select 1 from public.conversation_members cm where cm.conversation_id = conversation_id and cm.user_id = (select auth.uid())));

-- Ajouter des membres (si on est déjà membre)
drop policy if exists "conversation_members_insert" on public.conversation_members;
create policy "conversation_members_insert" on public.conversation_members for insert to authenticated with check (true);

-- ----- MESSAGES -----
alter table public.messages enable row level security;

-- ⚠️ RÈGLE CRUCIALE : Lecture uniquement par les participants de la conversation
drop policy if exists "messages_participant_read" on public.messages;
create policy "messages_participant_read" on public.messages for select to authenticated
  using (exists (select 1 from public.conversation_members cm where cm.conversation_id = conversation_id and cm.user_id = (select auth.uid())));

-- Écriture : seulement si on est l'expéditeur ET qu'on est dans la conversation
drop policy if exists "messages_insert" on public.messages;
create policy "messages_insert" on public.messages for insert to authenticated
  with check (
    (select auth.uid()) = sender_id 
    and exists (select 1 from public.conversation_members cm where cm.conversation_id = conversation_id and cm.user_id = (select auth.uid()))
  );

-- ----- SERVICE REQUESTS -----
alter table public.service_requests enable row level security;

-- Tout le monde peut voir les demandes "ouvertes"
drop policy if exists "requests_public_read" on public.service_requests;
create policy "requests_public_read" on public.service_requests for select to anon, authenticated
  using (status = 'open' or (select auth.uid()) = author_id);

-- L'auteur gère ses propres demandes
drop policy if exists "requests_author_all" on public.service_requests;
create policy "requests_author_all" on public.service_requests for all to authenticated
  using ((select auth.uid()) = author_id) with check ((select auth.uid()) = author_id);

-- ============================================================================
-- FIN DE LA MIGRATION 6
-- ============================================================================