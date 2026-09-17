-- FloriWeb V3 RC6.3 - contato publico protegido + suporte interno
begin;

create or replace function public.get_public_landing_v1()
returns jsonb
language sql
stable
security definer
set search_path=public,pg_temp
as $$
  select jsonb_build_object(
    'demo_store_slug',coalesce((select s.slug from public.stores s where s.archived_at is null and s.active and s.access_status='online' and public.store_accessible(s.id) order by (s.slug='floriweb-demo') desc,s.created_at asc limit 1),'floriweb-demo'),
    'demo_enabled',coalesce((select ps.demo_enabled from public.platform_settings ps where ps.id=1),true),
    'demo_duration_days',coalesce((select ps.demo_duration_days from public.platform_settings ps where ps.id=1),30),
    'contact_protected',true,
    'stores',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'slug',s.slug,'name',s.name,'description',s.description,'logo_url',s.logo_url,'hero_url',s.cover_url,'city',s.city,'state',s.state) order by s.created_at desc) from public.stores s where s.archived_at is null and s.active and s.access_status='online' and public.store_accessible(s.id)),'[]'::jsonb),
    'plans',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'code',p.code,'name',p.name,'monthly_price',p.monthly_price) order by p.sort_order,p.monthly_price,p.name) from public.plans p where p.active and p.code<>'DEMO'),'[]'::jsonb)
  );
$$;
revoke all on function public.get_public_landing_v1() from public;
grant execute on function public.get_public_landing_v1() to anon,authenticated;

create or replace function public.get_admin_support_contact_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path=public,pg_temp
as $$
declare v_uid uuid:=auth.uid(); v_phone text:='';
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
  if not exists(select 1 from public.platform_admins pa where pa.user_id=v_uid and pa.active)
     and not exists(select 1 from public.store_users su where su.user_id=v_uid and su.active and su.role in ('owner','admin')) then
    raise exception 'SUPPORT_FOR_ADMINS_ONLY' using errcode='42501';
  end if;
  select regexp_replace(coalesce(nullif(ps.support_whatsapp,''),nullif(ps.billing_whatsapp,''),''),'[^0-9]','','g') into v_phone from public.platform_settings ps where ps.id=1;
  return jsonb_build_object('support_whatsapp',coalesce(v_phone,''));
end;
$$;
revoke all on function public.get_admin_support_contact_v1() from public,anon;
grant execute on function public.get_admin_support_contact_v1() to authenticated;

create table if not exists public.platform_public_contact_rate_limits(
  fingerprint_hash text primary key,
  window_started_at timestamptz not null default now(),
  attempts integer not null default 0,
  last_attempt_at timestamptz not null default now()
);
alter table public.platform_public_contact_rate_limits enable row level security;
revoke all on public.platform_public_contact_rate_limits from public,anon,authenticated;

create or replace function public.enforce_public_contact_rate_limit_v1(p_fingerprint text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_row public.platform_public_contact_rate_limits%rowtype;
begin
  if coalesce(length(p_fingerprint),0)<32 then raise exception 'INVALID_CONTACT_FINGERPRINT' using errcode='22023'; end if;
  delete from public.platform_public_contact_rate_limits where last_attempt_at<now()-interval '24 hours';
  select * into v_row from public.platform_public_contact_rate_limits where fingerprint_hash=p_fingerprint for update;
  if not found then insert into public.platform_public_contact_rate_limits(fingerprint_hash,attempts) values(p_fingerprint,1); return; end if;
  if v_row.window_started_at<now()-interval '10 minutes' then update public.platform_public_contact_rate_limits set window_started_at=now(),attempts=1,last_attempt_at=now() where fingerprint_hash=p_fingerprint; return; end if;
  if v_row.attempts>=5 then raise exception 'TOO_MANY_CONTACT_ATTEMPTS' using errcode='P0001'; end if;
  update public.platform_public_contact_rate_limits set attempts=attempts+1,last_attempt_at=now() where fingerprint_hash=p_fingerprint;
end;$$;
revoke all on function public.enforce_public_contact_rate_limit_v1(text) from public,anon,authenticated;
grant execute on function public.enforce_public_contact_rate_limit_v1(text) to service_role;

notify pgrst,'reload schema';
commit;
