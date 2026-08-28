-- FloriWeb V3 RC2 - Diagnostico da plataforma atualizado
-- Mantem o diagnostico somente para Admin Master AAL2 e inclui telemetria anonima.

begin;

create or replace function public.platform_system_check()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  result jsonb;
  v_duration integer := 30;
  v_warning integer := 7;
  v_cron_scheduled boolean := false;
begin
  if not public.is_platform_admin() then
    raise exception 'Acesso restrito ao Admin Master.' using errcode='42501';
  end if;

  select demo_duration_days,demo_warning_days into v_duration,v_warning
  from public.platform_settings where id=1;

  if to_regnamespace('cron') is not null then
    begin
      execute 'select exists(select 1 from cron.job where jobname = ''floriweb-expire-demo-trials'')' into v_cron_scheduled;
    exception when others then
      v_cron_scheduled := false;
    end;
  end if;

  select jsonb_build_object(
    'version', '3.0.0-rc.2',
    'platformAdmin', true,
    'stores', (select count(*) from public.stores where archived_at is null),
    'storesOnline', (select count(*) from public.stores where archived_at is null and public.store_accessible(id)),
    'storesSuspended', (select count(*) from public.stores where archived_at is null and not public.store_accessible(id)),
    'plans', (select count(*) from public.plans),
    'subscriptions', (select count(*) from public.store_subscriptions),
    'users', (select count(*) from public.store_users),
    'products', (select count(*) from public.products),
    'orders', (select count(*) from public.orders),
    'deliveryZones', (select count(*) from public.delivery_zones),
    'domains', (select count(*) from public.store_domains),
    'analyticsEvents', (select count(*) from public.analytics_events),
    'demoTrials', (
      select count(*) from public.store_subscriptions ss
      join public.plans p on p.id=ss.plan_id
      where p.code='DEMO' and ss.status='trial'
    ),
    'demoTrialsExpiringSoon', (
      select count(*) from public.store_subscriptions ss
      join public.plans p on p.id=ss.plan_id
      where p.code='DEMO' and ss.status='trial' and ss.expires_at is not null
        and ss.expires_at > now()
        and ss.expires_at <= now() + make_interval(days => v_warning)
    ),
    'demoDurationDays', v_duration,
    'demoWarningDays', v_warning,
    'demoCronScheduled', v_cron_scheduled
  ) into result;

  return result;
end;
$$;

revoke all on function public.platform_system_check() from public;
grant execute on function public.platform_system_check() to authenticated;

commit;
