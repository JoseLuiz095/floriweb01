-- FloriWeb V3 RC1 - Entitlements comerciais de plano
-- Objetivos:
--   1) impedir dominio proprio ativo em plano sem custom_domain;
--   2) desativar dominios ativos ao trocar para plano sem o recurso;
--   3) manter a regra no banco, alem das validacoes de UI/Edge Function.

begin;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.store_plan_allows_custom_domain(p_store_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, private, pg_temp
as $$
  select coalesce((
    select p.custom_domain
    from public.store_subscriptions ss
    join public.plans p on p.id = ss.plan_id
    where ss.store_id = p_store_id
      and ss.status <> 'cancelled'
    order by ss.started_at desc, ss.created_at desc
    limit 1
  ), false);
$$;

revoke all on function private.store_plan_allows_custom_domain(uuid) from public, anon, authenticated;

create or replace function private.enforce_store_domain_plan()
returns trigger
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
begin
  if coalesce(new.active, true)
     and not private.store_plan_allows_custom_domain(new.store_id) then
    raise exception 'O plano ativo da floricultura nao inclui dominio proprio.';
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_store_domain_plan() from public, anon, authenticated;

drop trigger if exists store_domains_plan_entitlement_trg on public.store_domains;
create trigger store_domains_plan_entitlement_trg
before insert or update of store_id, domain, active on public.store_domains
for each row execute function private.enforce_store_domain_plan();

create or replace function private.sync_store_domain_entitlement()
returns trigger
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
begin
  if new.status = 'cancelled'
     or not exists (
       select 1
       from public.plans p
       where p.id = new.plan_id
         and p.custom_domain
     ) then
    update public.store_domains
       set active = false,
           updated_at = now()
     where store_id = new.store_id
       and active;
  end if;
  return new;
end;
$$;

revoke all on function private.sync_store_domain_entitlement() from public, anon, authenticated;

drop trigger if exists store_subscriptions_domain_entitlement_trg on public.store_subscriptions;
create trigger store_subscriptions_domain_entitlement_trg
after insert or update of store_id, plan_id, status on public.store_subscriptions
for each row execute function private.sync_store_domain_entitlement();

commit;
