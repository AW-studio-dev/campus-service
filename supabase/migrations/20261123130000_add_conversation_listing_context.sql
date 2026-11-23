-- ============================================================================
-- Contexte d'offre dans les conversations + réutilisation des fils directs
-- ----------------------------------------------------------------------------
-- 1. Ajoute l'offre concernée (produit/service) à une conversation.
-- 2. Réutilise la conversation directe existante entre deux membres au lieu
--    d'en créer une nouvelle à chaque clic sur « Contacter le vendeur ».
-- 3. Conserve l'ancienne signature de l'API pour la compatibilité.
-- ============================================================================

alter table public.conversations
  add column if not exists listing_id uuid,
  add column if not exists listing_title text,
  add column if not exists listing_type text;

-- Nouvelle signature : le vendeur voit « À propos de : <offre> » dans le chat.
create or replace function public.create_direct_conversation(
  p_other_user_id uuid,
  p_listing_id uuid,
  p_listing_title text,
  p_listing_type text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current_user_id uuid := auth.uid();
  v_conversation_id uuid;
begin
  if v_current_user_id is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  if p_other_user_id is null or p_other_user_id = v_current_user_id then
    raise exception 'Invalid conversation participant'
      using errcode = '22023';
  end if;

  -- Réutilise le fil direct existant (le plus récent) entre les deux membres.
  select c.id into v_conversation_id
  from public.conversations c
  join public.conversation_members m1
    on m1.conversation_id = c.id
   and m1.user_id = v_current_user_id
  join public.conversation_members m2
    on m2.conversation_id = c.id
   and m2.user_id = p_other_user_id
  where c.type = 'direct'
  order by c.last_message_at desc
  limit 1;

  if v_conversation_id is not null then
    if p_listing_title is not null and btrim(p_listing_title) <> '' then
      update public.conversations
      set listing_id = p_listing_id,
          listing_title = btrim(p_listing_title),
          listing_type = p_listing_type
      where id = v_conversation_id;
    end if;
    return v_conversation_id;
  end if;

  insert into public.conversations (type, listing_id, listing_title, listing_type)
  values (
    'direct',
    p_listing_id,
    nullif(btrim(coalesce(p_listing_title, '')), ''),
    p_listing_type
  )
  returning id into v_conversation_id;

  insert into public.conversation_members (conversation_id, user_id)
  values
    (v_conversation_id, v_current_user_id),
    (v_conversation_id, p_other_user_id);

  return v_conversation_id;
end;
$$;

revoke all on function public.create_direct_conversation(uuid, uuid, text, text)
  from public, anon;
grant execute on function public.create_direct_conversation(uuid, uuid, text, text)
  to authenticated;

-- Ancienne signature conservée pour les appels sans contexte d'offre.
create or replace function public.create_direct_conversation(
  p_other_user_id uuid
)
returns uuid
language sql
security definer
set search_path = ''
as $$
  select public.create_direct_conversation(p_other_user_id, null, null, null);
$$;

revoke all on function public.create_direct_conversation(uuid) from public, anon;
grant execute on function public.create_direct_conversation(uuid) to authenticated;

-- Marque la conversation comme lue avec l'horodatage serveur du dernier
-- message. Fonctionne même si la policy d'update n'a pas encore été appliquée.
create or replace function public.mark_conversation_read(p_conversation_id uuid)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_last_read timestamptz;
begin
  if v_user_id is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.conversation_members cm
    where cm.conversation_id = p_conversation_id
      and cm.user_id = v_user_id
  ) then
    raise exception 'Not a conversation member'
      using errcode = '42501';
  end if;

  select max(m.created_at) into v_last_read
  from public.messages m
  where m.conversation_id = p_conversation_id;

  if v_last_read is null then
    return null;
  end if;

  update public.conversation_members
  set last_read_at = v_last_read
  where conversation_id = p_conversation_id
    and user_id = v_user_id;

  return v_last_read;
end;
$$;

revoke all on function public.mark_conversation_read(uuid) from public, anon;
grant execute on function public.mark_conversation_read(uuid) to authenticated;

-- ============================================================================
-- FIN
-- ============================================================================
