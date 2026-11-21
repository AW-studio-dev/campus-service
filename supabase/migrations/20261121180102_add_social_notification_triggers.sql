-- ============================================================================
-- Notifications automatiques pour les actions sociales CampusServices.
-- ============================================================================

-- 1. Notification : Nouvel abonné (Follow)
create or replace function public.notify_new_follower()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (user_id, type, payload)
  values (
    new.following_id,
    'new_follower',
    jsonb_build_object('actor_id', new.follower_id)
  );
  return new;
end;
$$;

drop trigger if exists trg_notify_new_follower on public.follows;
create trigger trg_notify_new_follower
after insert on public.follows
for each row execute function public.notify_new_follower();

-- ============================================================================

-- 2. Notification : Nouveau message
create or replace function public.notify_new_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (user_id, type, payload)
  select cm.user_id,
         'new_message',
         jsonb_build_object(
           'conversation_id', new.conversation_id,
           'sender_id', new.sender_id,
           'message_id', new.id
         )
  from public.conversation_members cm
  where cm.conversation_id = new.conversation_id
    and cm.user_id <> new.sender_id;

  return new;
end;
$$;

drop trigger if exists trg_notify_new_message on public.messages;
create trigger trg_notify_new_message
after insert on public.messages
for each row execute function public.notify_new_message();

-- ============================================================================

-- 3. Notification : Nouveau commentaire
create or replace function public.notify_new_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post_author uuid;
begin
  select author_id into v_post_author
  from public.posts
  where id = new.post_id;

  if v_post_author is not null and v_post_author <> new.author_id then
    insert into public.notifications (user_id, type, payload)
    values (
      v_post_author,
      'new_comment',
      jsonb_build_object(
        'post_id', new.post_id,
        'comment_id', new.id,
        'actor_id', new.author_id
      )
    );
  end if; -- ✅ CORRIGÉ ICI

  return new;
end;
$$;

drop trigger if exists trg_notify_new_comment on public.comments;
create trigger trg_notify_new_comment
after insert on public.comments
for each row execute function public.notify_new_comment();

-- ============================================================================

-- 4. Notification : Nouvelle réaction (Like)
create or replace function public.notify_new_reaction()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post_author uuid;
begin
  select author_id into v_post_author
  from public.posts
  where id = new.post_id;

  if v_post_author is not null and v_post_author <> new.user_id then
    insert into public.notifications (user_id, type, payload)
    values (
      v_post_author,
      'new_reaction',
      jsonb_build_object(
        'post_id', new.post_id,
        'actor_id', new.user_id,
        'reaction_type', new.reaction_type
      )
    );
  end if; -- ✅ CORRIGÉ ICI

  return new;
end;
$$;

drop trigger if exists trg_notify_new_reaction on public.reactions;
create trigger trg_notify_new_reaction
after insert on public.reactions
for each row execute function public.notify_new_reaction();

-- ============================================================================

-- 5. Notification : Changement de statut d'une demande (Service Request)
create or replace function public.notify_request_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status is distinct from old.status then
    insert into public.notifications (user_id, type, payload)
    values (
      new.author_id,
      'new_request_response',
      jsonb_build_object(
        'request_id', new.id,
        'old_status', old.status,
        'new_status', new.status
      )
    );
  end if; -- ✅ CORRIGÉ ICI

  return new;
end;
$$;

drop trigger if exists trg_notify_request_status_change on public.service_requests;
create trigger trg_notify_request_status_change
after update of status on public.service_requests
for each row execute function public.notify_request_status_change();

-- ============================================================================

-- 6. Notification : Nouveau post pour les abonnés
create or replace function public.notify_new_post_to_followers()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (user_id, type, payload)
  select f.follower_id,
         'system',
         jsonb_build_object(
           'post_id', new.id,
           'actor_id', new.author_id,
           'kind', 'new_post'
         )
  from public.follows f
  where f.following_id = new.author_id;

  return new;
end;
$$;

drop trigger if exists trg_notify_new_post_to_followers on public.posts;
create trigger trg_notify_new_post_to_followers
after insert on public.posts
for each row execute function public.notify_new_post_to_followers();