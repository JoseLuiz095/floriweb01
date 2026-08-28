-- FloriWeb V3 - diagnostico consolidado, seguro e somente leitura
-- Revisao: preflight.2 / 2026-08-27
-- Execute TODO este arquivo no Supabase SQL Editor e copie o unico resultado retornado.
-- Nao cria tabelas, funcoes, policies, triggers ou migrations.
-- Nao consulta diretamente supabase_migrations.schema_migrations, pois essa relacao
-- nao existe em todos os projetos Supabase.

select jsonb_pretty(
  jsonb_build_object(
    'database', current_database(),
    'migration_history_relation', to_regclass('supabase_migrations.schema_migrations')::text,

    'public_tables', coalesce((
      select jsonb_agg(t.table_name order by t.table_name)
      from information_schema.tables t
      where t.table_schema = 'public'
        and t.table_type = 'BASE TABLE'
    ), '[]'::jsonb),

    'storage_tables', coalesce((
      select jsonb_agg(t.table_name order by t.table_name)
      from information_schema.tables t
      where t.table_schema = 'storage'
        and t.table_type = 'BASE TABLE'
    ), '[]'::jsonb),

    'key_columns', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'table', c.table_name,
          'column', c.column_name,
          'data_type', c.data_type,
          'udt_name', c.udt_name,
          'nullable', c.is_nullable,
          'default', c.column_default
        ) order by c.table_name, c.ordinal_position
      )
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name in (
          'stores',
          'store_users',
          'plans',
          'store_subscriptions',
          'products',
          'categories',
          'addons',
          'orders',
          'order_items',
          'delivery_zones',
          'platform_admins',
          'platform_settings',
          'store_domains'
        )
    ), '[]'::jsonb),

    'rls_status', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'schema', n.nspname,
          'table', c.relname,
          'rls_enabled', c.relrowsecurity,
          'rls_forced', c.relforcerowsecurity
        ) order by n.nspname, c.relname
      )
      from pg_catalog.pg_class c
      join pg_catalog.pg_namespace n on n.oid = c.relnamespace
      where n.nspname in ('public', 'storage')
        and c.relkind in ('r', 'p')
    ), '[]'::jsonb),

    'policies', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'schema', p.schemaname,
          'table', p.tablename,
          'policy', p.policyname,
          'roles', p.roles,
          'command', p.cmd,
          'using', p.qual,
          'with_check', p.with_check
        ) order by p.schemaname, p.tablename, p.policyname
      )
      from pg_catalog.pg_policies p
      where p.schemaname in ('public', 'storage')
    ), '[]'::jsonb),

    'key_constraints', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'table', c.relname,
          'name', con.conname,
          'type', con.contype,
          'definition', pg_catalog.pg_get_constraintdef(con.oid, true)
        ) order by c.relname, con.conname
      )
      from pg_catalog.pg_constraint con
      join pg_catalog.pg_class c on c.oid = con.conrelid
      join pg_catalog.pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname in (
          'stores', 'store_users', 'plans', 'store_subscriptions',
          'products', 'categories', 'addons', 'orders', 'order_items',
          'delivery_zones', 'platform_admins', 'platform_settings', 'store_domains'
        )
    ), '[]'::jsonb),

    'public_functions', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'name', r.routine_name,
          'type', r.routine_type,
          'return_type', r.data_type
        ) order by r.routine_name
      )
      from information_schema.routines r
      where r.routine_schema = 'public'
    ), '[]'::jsonb),

    'security_function_definitions', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'name', p.proname,
          'arguments', pg_catalog.pg_get_function_identity_arguments(p.oid),
          'security_definer', p.prosecdef,
          'definition', pg_catalog.pg_get_functiondef(p.oid)
        ) order by p.proname, pg_catalog.pg_get_function_identity_arguments(p.oid)
      )
      from pg_catalog.pg_proc p
      join pg_catalog.pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and (
          p.proname in (
            'create_public_order',
            'is_store_admin',
            'is_store_member',
            'store_accessible',
            'platform_expire_demo_trials',
            'resolve_storefront_status',
            'is_platform_admin'
          )
          or p.proname like 'is_store_%'
        )
    ), '[]'::jsonb),

    'triggers', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'table', c.relname,
          'trigger', t.tgname,
          'definition', pg_catalog.pg_get_triggerdef(t.oid, true)
        ) order by c.relname, t.tgname
      )
      from pg_catalog.pg_trigger t
      join pg_catalog.pg_class c on c.oid = t.tgrelid
      join pg_catalog.pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and not t.tgisinternal
    ), '[]'::jsonb),

    'plans_exists', to_regclass('public.plans') is not null,
    'plans_snapshot_xml', case
      when to_regclass('public.plans') is not null
        then pg_catalog.table_to_xml(to_regclass('public.plans'), true, false, '')::text
      else null
    end,

    'platform_settings_exists', to_regclass('public.platform_settings') is not null,
    'platform_settings_snapshot_xml', case
      when to_regclass('public.platform_settings') is not null
        then pg_catalog.table_to_xml(to_regclass('public.platform_settings'), true, false, '')::text
      else null
    end
  )
) as floriweb_v3_diagnostic;
