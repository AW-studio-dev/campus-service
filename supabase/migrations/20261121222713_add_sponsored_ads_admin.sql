-- Campaign placement, destination and optional sponsored post relationship.
alter table public.ad_campaigns
  add column if not exists placement text not null default 'banner',
  add column if not exists destination_url text,
  add column if not exists post_id uuid references public.posts(id) on delete set null;

alter table public.ad_campaigns
  drop constraint if exists ad_campaigns_placement_check,
  add constraint ad_campaigns_placement_check
    check (placement in ('banner', 'sponsored_post')),
  drop constraint if exists ad_campaigns_dates_check,
  add constraint ad_campaigns_dates_check
    check (starts_at is null or ends_at is null or ends_at > starts_at);

create index if not exists idx_ad_campaigns_active_placement
  on public.ad_campaigns (placement, starts_at, ends_at)
  where status = 'active';
create index if not exists idx_ad_campaigns_post
  on public.ad_campaigns (post_id)
  where post_id is not null;
create index if not exists idx_ad_campaigns_business
  on public.ad_campaigns (business_id)
  where business_id is not null;
create index if not exists idx_ad_events_campaign_type
  on public.ad_events (campaign_id, event_type, occurred_at desc);

-- Use the admin role only; the general is_admin() helper also permits moderators.
create or replace function public.is_campaign_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.has_role('admin'::public.admin_role);
$$;

revoke all on function public.is_campaign_admin() from public, anon;
grant execute on function public.is_campaign_admin() to authenticated;

create table if not exists public.ad_campaign_stats (
  campaign_id uuid primary key
    references public.ad_campaigns(id) on delete cascade,
  impressions bigint not null default 0,
  clicks bigint not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.ad_campaign_stats enable row level security;
drop policy if exists "ad_campaign_stats_admin_read" on public.ad_campaign_stats;
create policy "ad_campaign_stats_admin_read"
  on public.ad_campaign_stats for select to authenticated
  using (public.is_campaign_admin());

insert into public.ad_campaign_stats (campaign_id, impressions, clicks)
select campaign_id,
       count(*) filter (where event_type = 'impression'),
       count(*) filter (where event_type = 'click')
from public.ad_events
group by campaign_id
on conflict (campaign_id) do update
set impressions = excluded.impressions,
    clicks = excluded.clicks,
    updated_at = now();

create or replace function public.update_ad_campaign_stats()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.ad_campaign_stats as current_stats (
    campaign_id, impressions, clicks, updated_at
  )
  values (
    new.campaign_id,
    case when new.event_type = 'impression'::public.ad_event_type then 1 else 0 end,
    case when new.event_type = 'click'::public.ad_event_type then 1 else 0 end,
    now()
  )
  on conflict (campaign_id) do update
  set impressions = current_stats.impressions + excluded.impressions,
      clicks = current_stats.clicks + excluded.clicks,
      updated_at = now();

  return new;
end;
$$;

drop trigger if exists trg_update_ad_campaign_stats on public.ad_events;
create trigger trg_update_ad_campaign_stats
after insert on public.ad_events
for each row execute function public.update_ad_campaign_stats();


-- Only administrators can create or change campaigns. Everyone can read
-- currently active campaigns, which are further date-filtered in the client.
alter table public.ad_campaigns enable row level security;
drop policy if exists "campaigns_public_read" on public.ad_campaigns;
drop policy if exists "campaigns_owner_all" on public.ad_campaigns;
drop policy if exists "campaigns_admin_all" on public.ad_campaigns;
drop policy if exists "campaigns_admin_read" on public.ad_campaigns;
drop policy if exists "campaigns_admin_insert" on public.ad_campaigns;
drop policy if exists "campaigns_admin_update" on public.ad_campaigns;

create policy "campaigns_public_read"
  on public.ad_campaigns for select to anon, authenticated
  using (status = 'active');

create policy "campaigns_admin_read"
  on public.ad_campaigns for select to authenticated
  using (public.is_campaign_admin());

create policy "campaigns_admin_insert"
  on public.ad_campaigns for insert to authenticated
  with check (public.is_campaign_admin() and owner_id = (select auth.uid()));

create policy "campaigns_admin_update"
  on public.ad_campaigns for update to authenticated
  using (public.is_campaign_admin())
  with check (public.is_campaign_admin());


-- Event writes are public, but event identity and target are validated.
alter table public.ad_events enable row level security;
drop policy if exists "ad_events_insert" on public.ad_events;
create policy "ad_events_insert"
  on public.ad_events for insert to anon, authenticated
  with check (
    (user_id is null or user_id = (select auth.uid()))
    and exists (
      select 1
      from public.ad_campaigns c
      where c.id = campaign_id
        and c.status = 'active'
        and (c.starts_at is null or c.starts_at <= now())
        and (c.ends_at is null or c.ends_at > now())
    )
  );

drop policy if exists "ad_events_read" on public.ad_events;
create policy "ad_events_read"
  on public.ad_events for select to authenticated
  using (public.is_campaign_admin());


-- The create RPC makes a sponsored post and its campaign atomically.
create or replace function public.create_ad_campaign(
  p_title text,
  p_creative_path text,
  p_destination_url text,
  p_placement text,
  p_starts_at timestamptz,
  p_ends_at timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner_id uuid := auth.uid();
  v_post_id uuid;
  v_campaign_id uuid;
begin
  if v_owner_id is null or not public.is_campaign_admin() then
    raise exception 'Administrator access required'
      using errcode = '42501';
  end if;

  if length(trim(coalesce(p_title, ''))) not between 2 and 120 then
    raise exception 'Campaign title must contain 2 to 120 characters'
      using errcode = '22023';
  end if;

  if p_placement not in ('banner', 'sponsored_post') then
    raise exception 'Invalid campaign placement'
      using errcode = '22023';
  end if;

  if coalesce(p_destination_url, '') !~* '^https?://' then
    raise exception 'Destination URL must use HTTP or HTTPS'
      using errcode = '22023';
  end if;

  if p_starts_at is not null and p_ends_at is not null
      and p_ends_at <= p_starts_at then
    raise exception 'Campaign end must be after its start'
      using errcode = '22023';
  end if;

  if p_placement = 'sponsored_post' then
    insert into public.posts (author_id, body, post_type, status)
    values (
      v_owner_id,
      trim(p_title),
      'sponsored'::public.post_type,
      'published'::public.post_status
    )
    returning id into v_post_id;
  end if;

  insert into public.ad_campaigns (
    owner_id, title, creative_path, destination_url, placement,
    post_id, starts_at, ends_at, status
  )
  values (
    v_owner_id, trim(p_title), p_creative_path, p_destination_url,
    p_placement, v_post_id, p_starts_at, p_ends_at, 'pending_review'
  )
  returning id into v_campaign_id;

  return v_campaign_id;
end;
$$;

revoke all on function public.create_ad_campaign(text, text, text, text, timestamptz, timestamptz)
  from public, anon;
grant execute on function public.create_ad_campaign(text, text, text, text, timestamptz, timestamptz)
  to authenticated;


-- Public creatives; only admins can upload or manage objects in this bucket.
insert into storage.buckets (id, name, public)
values ('ads-media', 'ads-media', true)
on conflict (id) do update set public = true;

drop policy if exists "ads_media_public_read" on storage.objects;
create policy "ads_media_public_read"
  on storage.objects for select
  using (bucket_id = 'ads-media');

drop policy if exists "ads_media_admin_insert" on storage.objects;
create policy "ads_media_admin_insert"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'ads-media' and public.is_campaign_admin());

drop policy if exists "ads_media_admin_update" on storage.objects;
create policy "ads_media_admin_update"
  on storage.objects for update to authenticated
  using (bucket_id = 'ads-media' and public.is_campaign_admin())
  with check (bucket_id = 'ads-media' and public.is_campaign_admin());

drop policy if exists "ads_media_admin_delete" on storage.objects;
create policy "ads_media_admin_delete"
  on storage.objects for delete to authenticated
  using (bucket_id = 'ads-media' and public.is_campaign_admin());
