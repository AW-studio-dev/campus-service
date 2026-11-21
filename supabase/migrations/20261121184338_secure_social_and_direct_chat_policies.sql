-- Align RLS with follow writes and create direct conversations atomically.

alter table public.follows enable row level security;
drop policy if exists "follows_own_write" on public.follows;
drop policy if exists "follows_public_read" on public.follows;
drop policy if exists "Users can follow others" on public.follows;
drop policy if exists "Users can view follows" on public.follows;
drop policy if exists "Users can unfollow" on public.follows;
drop policy if exists "follows_insert_own" on public.follows;
drop policy if exists "follows_delete_own" on public.follows;

create policy "follows_public_read"
  on public.follows for select to authenticated
  using (true);

create policy "follows_insert_own"
  on public.follows for insert to authenticated
  with check ((select auth.uid()) = follower_id);

create policy "follows_delete_own"
  on public.follows for delete to authenticated
  using ((select auth.uid()) = follower_id);


create or replace function public.is_conversation_member(p_conversation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.conversation_members cm
    where cm.conversation_id = p_conversation_id
      and cm.user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_conversation_member(uuid) from public, anon;
grant execute on function public.is_conversation_member(uuid) to authenticated;


create or replace function public.create_direct_conversation(
  p_other_user_id uuid
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

  insert into public.conversations (type)
  values ('direct')
  returning id into v_conversation_id;

  insert into public.conversation_members (conversation_id, user_id)
  values
    (v_conversation_id, v_current_user_id),
    (v_conversation_id, p_other_user_id);

  return v_conversation_id;
end;
$$;

revoke all on function public.create_direct_conversation(uuid) from public, anon;
grant execute on function public.create_direct_conversation(uuid) to authenticated;


alter table public.conversations enable row level security;
drop policy if exists "conversations_participant_read" on public.conversations;
drop policy if exists "conversations_insert" on public.conversations;
drop policy if exists "Users can create conversations" on public.conversations;
drop policy if exists "Users can view own conversations" on public.conversations;

create policy "conversations_participant_read"
  on public.conversations for select to authenticated
  using (public.is_conversation_member(id));


alter table public.conversation_members enable row level security;
drop policy if exists "conversation_members_read" on public.conversation_members;
drop policy if exists "conversation_members_insert" on public.conversation_members;
drop policy if exists "Users can add members to conversations" on public.conversation_members;

create policy "conversation_members_read"
  on public.conversation_members for select to authenticated
  using (public.is_conversation_member(conversation_id));


alter table public.messages enable row level security;
drop policy if exists "messages_participant_read" on public.messages;
drop policy if exists "messages_insert" on public.messages;
drop policy if exists "Users can send messages" on public.messages;

create policy "messages_participant_read"
  on public.messages for select to authenticated
  using (public.is_conversation_member(conversation_id));

create policy "messages_insert"
  on public.messages for insert to authenticated
  with check (
    (select auth.uid()) = sender_id
    and public.is_conversation_member(conversation_id)
  );
