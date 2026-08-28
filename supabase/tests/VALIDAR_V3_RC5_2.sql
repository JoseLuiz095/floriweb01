with checks as (
  select
    exists(
      select 1 from information_schema.columns
      where table_schema='public' and table_name='platform_settings' and column_name='demo_enabled'
    ) as demo_enabled_column,
    exists(
      select 1 from pg_trigger
      where tgname='store_subscriptions_demo_availability_trg' and not tgisinternal
    ) as demo_guard_trigger,
    to_regclass('public.analytics_events') is not null as analytics_table,
    to_regprocedure('public.track_public_event_v3(uuid,uuid,text,uuid)') is not null as analytics_track_rpc,
    to_regprocedure('public.get_store_analytics_v3(uuid,timestamptz,timestamptz)') is not null as analytics_report_rpc,
    has_function_privilege('anon','public.track_public_event_v3(uuid,uuid,text,uuid)','EXECUTE') as anon_can_track,
    has_function_privilege('authenticated','public.get_store_analytics_v3(uuid,timestamptz,timestamptz)','EXECUTE') as admin_can_read_report,
    to_regprocedure('public.platform_system_check()') is not null as diagnostics_rpc,
    coalesce((select demo_enabled from public.platform_settings where id=1),true) as demo_enabled,
    coalesce((select demo_duration_days from public.platform_settings where id=1),30) as demo_duration_days,
    coalesce((select demo_warning_days from public.platform_settings where id=1),7) as demo_warning_days
)
select jsonb_build_object(
  'version','3.0.0-rc.5.2',
  'ok', demo_enabled_column
        and demo_guard_trigger
        and analytics_table
        and analytics_track_rpc
        and analytics_report_rpc
        and anon_can_track
        and admin_can_read_report
        and diagnostics_rpc,
  'demoEnabledColumn',demo_enabled_column,
  'demoGuardTrigger',demo_guard_trigger,
  'demoEnabled',demo_enabled,
  'demoDurationDays',demo_duration_days,
  'demoWarningDays',demo_warning_days,
  'analyticsTable',analytics_table,
  'analyticsTrackRpc',analytics_track_rpc,
  'analyticsReportRpc',analytics_report_rpc,
  'anonCanTrack',anon_can_track,
  'authenticatedCanReadAnalytics',admin_can_read_report,
  'diagnosticsRpc',diagnostics_rpc
)
from checks;

-- Confirmacao adicional da assinatura que o PostgREST precisa enxergar.
select
  p.oid::regprocedure::text as function_signature,
  pg_get_function_arguments(p.oid) as arguments
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public'
  and p.proname in ('track_public_event_v3','get_store_analytics_v3','platform_system_check')
order by p.proname;

-- Estado real do cron da Demo, sem alterar o agendamento.
select jobid,jobname,schedule,command,active
from cron.job
where jobname='floriweb-expire-demo-trials'
order by jobid desc;
