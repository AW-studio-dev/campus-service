-- ============================================================================
-- Correctifs : stockage business-media, notifications, avis, messages non lus
-- ----------------------------------------------------------------------------
-- 1. Consolidation des policies du bucket business-media (upload/loupe/delete)
-- 2. Notifications enrichies (nom + avatar de l'auteur de l'action)
-- 3. Avis : unicité par membre et suppression par le propriétaire
-- 4. Messages : last_message_at, compteur non lu et marquage comme lu
-- 5. Protection des colonnes sensibles (profils / statut business)
-- ============================================================================

-- ============================================================================
-- 1. STOCKAGE : BUCKET business-media
-- ============================================================================

-- S'assure que le bucket existe et reste public en lecture.
insert into storage.buckets (id, name, public)
values ('business-media', 'business-media', true)
on conflict (id) do update set public = true;

-- Supprime toutes les anciennes policies liées à business-media, quel que soit
-- leur nom (les essais précédents ont laissé plusieurs règles concurrentes).
do $$
declare
  policy_row record;
begin
  for policy_row in
    select policyname
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and (
        coalesce(qual, '') like '%business-media%'
        or coalesce(with_check, '') like '%business-media%'
        or policyname like '%business_media%'
        or policyname like '%business-media%'
      )
  loop
    execute format(
      'drop policy if exists %I on storage.objects',
      policy_row.policyname
    );
  end loop;
end $$;

-- Vérifie que le premier dossier du chemin est bien un business appartenant
-- à l'utilisateur connecté. La comparaison textuelle évite les erreurs de cast
-- si un chemin mal formé est envoyé.
create or replace function public.is_business_media_owner(p_object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.businesses b
    where b.id::text = split_part(p_object_name, '/', 1)
      and b.owner_id = (select auth.uid())
  );
$$;

revoke all on function public.is_business_media_owner(text) from public, anon;
grant execute on function public.is_business_media_owner(text) to authenticated;

-- Lecture publique des images (bucket public).
create policy "business_media_public_read"
  on storage.objects for select
  using (bucket_id = 'business-media');

-- Envoi : uniquement dans le dossier de son propre business.
create policy "business_media_owner_insert"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'business-media'
    and public.is_business_media_owner(name)
  );

-- Remplacement / suppression : même règle.
create policy "business_media_owner_update"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'business-media'
    and public.is_business_media_owner(name)
  )
  with check (
    bucket_id = 'business-media'
    and public.is_business_media_owner(name)
  );

create policy "business_media_owner_delete"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'business-media'
    and public.is_business_media_owner(name)
  );

-- ============================================================================
-- 2. NOTIFICATIONS ENRICHIES (nom + avatar de l'auteur)
-- ============================================================================

create or replace function public.notify_new_follower()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
  v_avatar text;
begin
  select display_name, avatar_path
    into v_name, v_avatar
  from public.profiles
  where id = new.follower_id;

  insert into public.notifications (user_id, type, payload)
  values (
    new.following_id,
    'new_follower',
    jsonb_build_object(
      'actor_id', new.follower_id,
      'actor_name', coalesce(v_name, 'Un étudiant'),
      'actor_avatar_path', v_avatar
    )
  );
  return new;
end;
$$;

create or replace function public.notify_new_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (user_id, type, payload)
  select
    cm.user_id,
    'new_message',
    jsonb_build_object(
      'conversation_id', new.conversation_id,
      'sender_id', new.sender_id,
      'message_id', new.id,
      'actor_id', new.sender_id,
      'actor_name', coalesce(p.display_name, 'Un étudiant'),
      'actor_avatar_path', p.avatar_path,
      'message_preview', left(new.body, 120)
    )
  from public.conversation_members cm
  join public.profiles p on p.id = new.sender_id
  where cm.conversation_id = new.conversation_id
    and cm.user_id <> new.sender_id;

  return new;
end;
$$;

create or replace function public.notify_new_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post_author uuid;
  v_name text;
  v_avatar text;
begin
  select author_id into v_post_author
  from public.posts
  where id = new.post_id;

  if v_post_author is not null and v_post_author <> new.author_id then
    select display_name, avatar_path
      into v_name, v_avatar
    from public.profiles
    where id = new.author_id;

    insert into public.notifications (user_id, type, payload)
    values (
      v_post_author,
      'new_comment',
      jsonb_build_object(
        'post_id', new.post_id,
        'comment_id', new.id,
        'actor_id', new.author_id,
        'actor_name', coalesce(v_name, 'Un étudiant'),
        'actor_avatar_path', v_avatar,
        'comment_preview', left(new.body, 120)
      )
    );
  end if;

  return new;
end;
$$;

create or replace function public.notify_new_reaction()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post_author uuid;
  v_name text;
  v_avatar text;
begin
  select author_id into v_post_author
  from public.posts
  where id = new.post_id;

  if v_post_author is not null and v_post_author <> new.user_id then
    select display_name, avatar_path
      into v_name, v_avatar
    from public.profiles
    where id = new.user_id;

    insert into public.notifications (user_id, type, payload)
    values (
      v_post_author,
      'new_reaction',
      jsonb_build_object(
        'post_id', new.post_id,
        'actor_id', new.user_id,
        'actor_name', coalesce(v_name, 'Un étudiant'),
        'actor_avatar_path', v_avatar,
        'reaction_type', new.reaction_type
      )
    );
  end if;

  return new;
end;
$$;

create or replace function public.notify_request_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_name text;
  v_avatar text;
begin
  -- L'auteur n'a pas besoin d'être notifié de sa propre action.
  if new.status is distinct from old.status
     and (v_actor is null or v_actor <> new.author_id) then
    if v_actor is not null then
      select display_name, avatar_path
        into v_name, v_avatar
      from public.profiles
      where id = v_actor;
    end if;

    insert into public.notifications (user_id, type, payload)
    values (
      new.author_id,
      'new_request_response',
      jsonb_build_object(
        'request_id', new.id,
        'old_status', old.status,
        'new_status', new.status,
        'actor_id', v_actor,
        'actor_name', coalesce(v_name, 'Un étudiant'),
        'actor_avatar_path', v_avatar
      )
    );
  end if;

  return new;
end;
$$;

create or replace function public.notify_new_post_to_followers()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
  v_avatar text;
begin
  select display_name, avatar_path
    into v_name, v_avatar
  from public.profiles
  where id = new.author_id;

  insert into public.notifications (user_id, type, payload)
  select
    f.follower_id,
    'system',
    jsonb_build_object(
      'post_id', new.id,
      'actor_id', new.author_id,
      'actor_name', coalesce(v_name, 'Un étudiant'),
      'actor_avatar_path', v_avatar,
      'kind', 'new_post'
    )
  from public.follows f
  where f.following_id = new.author_id;

  return new;
end;
$$;

-- Nouvel avis sur une vitrine.
create or replace function public.notify_new_review()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
  v_name text;
  v_avatar text;
begin
  select owner_id into v_owner
  from public.businesses
  where id = new.business_id;

  if v_owner is not null and v_owner <> new.reviewer_id then
    select display_name, avatar_path
      into v_name, v_avatar
    from public.profiles
    where id = new.reviewer_id;

    insert into public.notifications (user_id, type, payload)
    values (
      v_owner,
      'new_review',
      jsonb_build_object(
        'business_id', new.business_id,
        'review_id', new.id,
        'rating', new.rating,
        'actor_id', new.reviewer_id,
        'actor_name', coalesce(v_name, 'Un étudiant'),
        'actor_avatar_path', v_avatar,
        'comment_preview', left(coalesce(new.comment, ''), 120)
      )
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_notify_new_review on public.reviews;
create trigger trg_notify_new_review
after insert on public.reviews
for each row execute function public.notify_new_review();

-- ============================================================================
-- 3. AVIS : unicité + suppression par le propriétaire de la vitrine
-- ============================================================================

-- Nettoie les doublons éventuels avant de poser la contrainte.
delete from public.reviews r
using public.reviews r2
where r.reviewer_id = r2.reviewer_id
  and r.business_id = r2.business_id
  and (
    r.created_at > r2.created_at
    or (r.created_at = r2.created_at and r.id > r2.id)
  );

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'unique_review_per_business'
  ) then
    alter table public.reviews
      add constraint unique_review_per_business
      unique (reviewer_id, business_id);
  end if;
end $$;

drop policy if exists "reviews_business_owner_delete" on public.reviews;
create policy "reviews_business_owner_delete"
  on public.reviews for delete to authenticated
  using (
    exists (
      select 1
      from public.businesses b
      where b.id = reviews.business_id
        and b.owner_id = (select auth.uid())
    )
  );

-- ============================================================================
-- 4. MESSAGES : ordre de la boîte de réception + lecture
-- ============================================================================

create or replace function public.touch_conversation_last_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.conversations
  set last_message_at = new.created_at
  where id = new.conversation_id;

  return new;
end;
$$;

drop trigger if exists trg_touch_conversation_last_message on public.messages;
create trigger trg_touch_conversation_last_message
after insert on public.messages
for each row execute function public.touch_conversation_last_message();

-- Un membre peut mettre à jour sa propre date de lecture.
drop policy if exists "conversation_members_update_own_read" on public.conversation_members;
create policy "conversation_members_update_own_read"
  on public.conversation_members for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- Empêche un membre de déplacer sa ligne vers une autre conversation.
create or replace function public.protect_conversation_member_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    new.conversation_id := old.conversation_id;
    new.user_id := old.user_id;
    new.joined_at := old.joined_at;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_protect_conversation_member_update on public.conversation_members;
create trigger trg_protect_conversation_member_update
before update on public.conversation_members
for each row execute function public.protect_conversation_member_update();

-- ============================================================================
-- 5. PROTECTION DES COLONNES SENSIBLES
-- ============================================================================

-- Un membre ne peut pas se vérifier ni se réactiver lui-même.
create or replace function public.protect_profile_admin_columns()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    new.is_verified := old.is_verified;
    new.is_suspended := old.is_suspended;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_protect_profile_admin_columns on public.profiles;
create trigger trg_protect_profile_admin_columns
before update on public.profiles
for each row execute function public.protect_profile_admin_columns();

-- Le propriétaire peut publier/mettre en pause sa vitrine, mais pas contourner
-- une suspension ou un archivage décidé par la modération.
create or replace function public.protect_business_moderation_columns()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    if old.status in ('suspended', 'archived') then
      new.status := old.status;
    elsif new.status = 'suspended' then
      new.status := old.status;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_protect_business_moderation_columns on public.businesses;
create trigger trg_protect_business_moderation_columns
before update on public.businesses
for each row execute function public.protect_business_moderation_columns();

-- ============================================================================
-- FIN
-- ============================================================================
