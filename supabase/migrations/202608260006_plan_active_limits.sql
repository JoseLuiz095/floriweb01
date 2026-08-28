-- FloriWeb 2.5.0
-- Ajusta os planos para o público de micro/pequenas floriculturas e faz o limite
-- considerar somente produtos ATIVOS. Produtos ocultos podem permanecer cadastrados.

update public.plans set name='Demo', product_limit=15, image_limit_per_product=3, custom_domain=false, reports=false, priority_support=false where code='DEMO';
update public.plans set name='Essencial', product_limit=15, image_limit_per_product=3, custom_domain=false, reports=false, priority_support=false where code='BASIC';
update public.plans set name='Profissional', product_limit=40, image_limit_per_product=6, custom_domain=false, reports=true, priority_support=true where code='PRO';
update public.plans set name='Premium', product_limit=100, image_limit_per_product=10, custom_domain=true, reports=true, priority_support=true where code='PREMIUM';

create or replace function public.enforce_product_plan_limit()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_limit integer;
  v_count integer;
begin
  -- Produto oculto não consome vaga do catálogo publicado.
  if not new.active then
    return new;
  end if;

  -- Upserts de produtos existentes executam BEFORE INSERT antes do conflito.
  -- Liberamos esse passo; a fase UPDATE fará a validação quando necessário.
  if tg_op = 'INSERT' and exists (select 1 from public.products where id = new.id) then
    return new;
  end if;

  -- Se já estava ativo, editar outros campos não consome outra vaga.
  if tg_op = 'UPDATE' then
    if old.active then
      return new;
    end if;
  end if;

  perform pg_advisory_xact_lock(hashtextextended(new.store_id::text, 0));

  select p.product_limit
    into v_limit
  from public.store_subscriptions ss
  join public.plans p on p.id = ss.plan_id
  where ss.store_id = new.store_id
    and ss.status in ('trial','active')
    and (ss.expires_at is null or ss.expires_at >= now())
  order by ss.started_at desc
  limit 1;

  if not found then
    select product_limit into v_limit
    from public.plans
    where code='DEMO' and active
    limit 1;
  end if;

  if v_limit is null then return new; end if;

  select count(*) into v_count
  from public.products
  where store_id = new.store_id
    and active
    and id <> new.id;

  if v_count >= v_limit then
    raise exception 'Limite de produtos ativos do plano atingido (%). Desative um produto antes de publicar outro.', v_limit
      using errcode='P0001';
  end if;

  return new;
end;
$$;

drop trigger if exists products_plan_limit_trg on public.products;
create trigger products_plan_limit_trg
before insert or update of active on public.products
for each row execute function public.enforce_product_plan_limit();
