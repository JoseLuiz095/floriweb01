-- FloriWeb V3 RC1 - Security baseline
-- Baseado no diagnostico remoto de 2026-08-27.
-- Objetivos:
--   1) corrigir isolamento multi-loja da leitura publica de produtos;
--   2) exigir MFA/AAL2 nas operacoes de Admin Master protegidas por is_platform_admin();
--   3) uniformizar disponibilidade publica por store_accessible();
--   4) restringir listagem/metadata e escrita do Storage por loja; os buckets de imagens continuam publicos por desenho;
--   5) manter bloqueio de novos pedidos no banco, independentemente do frontend.

begin;

do $$
begin
  if to_regclass('public.stores') is null
     or to_regclass('public.categories') is null
     or to_regclass('public.products') is null
     or to_regclass('public.product_images') is null
     or to_regclass('public.product_variants') is null
     or to_regclass('public.addons') is null
     or to_regclass('public.product_addons') is null
     or to_regclass('public.delivery_zones') is null
     or to_regclass('public.store_domains') is null
     or to_regclass('public.platform_admins') is null then
    raise exception 'Estrutura base do FloriWeb incompleta. Nao aplique esta migration antes das tabelas V2.9 existentes.';
  end if;

  if to_regprocedure('public.store_accessible(uuid)') is null then
    raise exception 'Funcao public.store_accessible(uuid) ausente. A base V2.9 precisa estar aplicada antes da V3.';
  end if;
end $$;

-- Admin Master: as policies que usam esta funcao passam a exigir sessao AAL2.
-- A policy platform_admins_self_read continua permitindo ao proprio usuario descobrir
-- que e Master em AAL1, para que a UI consiga encaminha-lo para o desafio MFA.
create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(auth.jwt()->>'aal','') = 'aal2'
     and exists (
       select 1
       from public.platform_admins pa
       where pa.user_id = auth.uid()
         and pa.active
     );
$$;

revoke all on function public.is_platform_admin() from public;
grant execute on function public.is_platform_admin() to authenticated;

-- Disponibilidade publica centralizada. O uso do nome da tabela no policy de produtos
-- e intencional: evita a ambiguidade que no banco remoto foi decompilada como
-- c.store_id = c.store_id.
drop policy if exists stores_public_read on public.stores;
create policy stores_public_read on public.stores
for select to anon, authenticated
using (public.store_accessible(stores.id));

drop policy if exists store_domains_public_read on public.store_domains;
create policy store_domains_public_read on public.store_domains
for select to anon, authenticated
using (active and public.store_accessible(store_domains.store_id));

drop policy if exists categories_public_read on public.categories;
create policy categories_public_read on public.categories
for select to anon, authenticated
using (active and public.store_accessible(categories.store_id));

drop policy if exists products_public_read on public.products;
create policy products_public_read on public.products
for select to anon, authenticated
using (
  products.active
  and public.store_accessible(products.store_id)
  and exists (
    select 1
    from public.categories c
    where c.id = products.category_id
      and c.store_id = products.store_id
      and c.active
  )
);

drop policy if exists addons_public_read on public.addons;
create policy addons_public_read on public.addons
for select to anon, authenticated
using (active and public.store_accessible(addons.store_id));

drop policy if exists delivery_zones_public_read on public.delivery_zones;
create policy delivery_zones_public_read on public.delivery_zones
for select to anon, authenticated
using (active and public.store_accessible(delivery_zones.store_id));

drop policy if exists product_images_public_read on public.product_images;
create policy product_images_public_read on public.product_images
for select to anon, authenticated
using (
  exists (
    select 1
    from public.products p
    join public.categories c
      on c.id = p.category_id
     and c.store_id = p.store_id
    where p.id = product_images.product_id
      and p.active
      and c.active
      and public.store_accessible(p.store_id)
  )
);

drop policy if exists product_variants_public_read on public.product_variants;
create policy product_variants_public_read on public.product_variants
for select to anon, authenticated
using (
  product_variants.active
  and exists (
    select 1
    from public.products p
    join public.categories c
      on c.id = p.category_id
     and c.store_id = p.store_id
    where p.id = product_variants.product_id
      and p.active
      and c.active
      and public.store_accessible(p.store_id)
  )
);

drop policy if exists product_addons_public_read on public.product_addons;
create policy product_addons_public_read on public.product_addons
for select to anon, authenticated
using (
  exists (
    select 1
    from public.products p
    join public.categories c
      on c.id = p.category_id
     and c.store_id = p.store_id
    join public.addons a
      on a.id = product_addons.addon_id
     and a.store_id = p.store_id
    where p.id = product_addons.product_id
      and p.active
      and c.active
      and a.active
      and public.store_accessible(p.store_id)
  )
);

-- Storage: os uploads atuais do FloriWeb usam sempre stores/<store_id>/...
-- Os buckets de catalogo sao publicos, portanto URLs publicas conhecidas continuam acessiveis.
-- Esta policy restringe SELECT/listagem via API; as policies seguintes protegem toda escrita.
drop policy if exists floriweb_storage_public_read on storage.objects;
create policy floriweb_storage_public_read on storage.objects
for select to anon, authenticated
using (
  bucket_id in ('product-images','store-assets')
  and (storage.foldername(name))[1] = 'stores'
  and exists (
    select 1
    from public.stores s
    where s.id::text = (storage.foldername(name))[2]
      and public.store_accessible(s.id)
  )
);

-- Escrita no Storage tambem respeita o estado operacional da loja.
drop policy if exists floriweb_storage_member_insert on storage.objects;
create policy floriweb_storage_member_insert on storage.objects
for insert to authenticated
with check (
  bucket_id in ('product-images','store-assets')
  and (storage.foldername(name))[1] = 'stores'
  and exists (
    select 1
    from public.stores s
    where s.id::text = (storage.foldername(name))[2]
      and public.is_store_admin(s.id)
  )
);

drop policy if exists floriweb_storage_member_update on storage.objects;
create policy floriweb_storage_member_update on storage.objects
for update to authenticated
using (
  bucket_id in ('product-images','store-assets')
  and (storage.foldername(name))[1] = 'stores'
  and exists (
    select 1
    from public.stores s
    where s.id::text = (storage.foldername(name))[2]
      and public.is_store_admin(s.id)
  )
)
with check (
  bucket_id in ('product-images','store-assets')
  and (storage.foldername(name))[1] = 'stores'
  and exists (
    select 1
    from public.stores s
    where s.id::text = (storage.foldername(name))[2]
      and public.is_store_admin(s.id)
  )
);

drop policy if exists floriweb_storage_member_delete on storage.objects;
create policy floriweb_storage_member_delete on storage.objects
for delete to authenticated
using (
  bucket_id in ('product-images','store-assets')
  and (storage.foldername(name))[1] = 'stores'
  and exists (
    select 1
    from public.stores s
    where s.id::text = (storage.foldername(name))[2]
      and public.is_store_admin(s.id)
  )
);

-- Defesa em profundidade: qualquer INSERT em orders, inclusive por uma RPC antiga,
-- precisa passar pelo estado real da loja.
create or replace function public.enforce_order_store_access()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.store_accessible(new.store_id) then
    raise exception 'Floricultura temporariamente indisponivel.' using errcode='P0001';
  end if;
  return new;
end;
$$;

revoke all on function public.enforce_order_store_access() from public, anon, authenticated;

drop trigger if exists orders_store_access_trg on public.orders;
create trigger orders_store_access_trg
before insert on public.orders
for each row execute function public.enforce_order_store_access();

-- Grants minimos das funcoes de seguranca utilizadas por RLS/RPC.
revoke all on function public.store_accessible(uuid) from public;
grant execute on function public.store_accessible(uuid) to anon, authenticated, service_role;

revoke all on function public.is_store_member(uuid) from public;
grant execute on function public.is_store_member(uuid) to authenticated;

revoke all on function public.is_store_admin(uuid) from public;
grant execute on function public.is_store_admin(uuid) to authenticated;

commit;
-- FloriWeb V3 RC1 - Public storefront consolidated RPC
-- Substitui o fan-out de varias chamadas REST publicas por uma unica leitura segura.

begin;

do $$
begin
  if to_regprocedure('public.store_accessible(uuid)') is null then
    raise exception 'Funcao public.store_accessible(uuid) ausente.';
  end if;
end $$;

create or replace function public.get_public_storefront_v3(
  p_slug text default null,
  p_hostname text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_store public.stores%rowtype;
  v_store_id uuid;
begin
  -- Dominio personalizado tem prioridade quando estiver ativo.
  if nullif(trim(coalesce(p_hostname,'')),'') is not null then
    select sd.store_id
      into v_store_id
    from public.store_domains sd
    where sd.active
      and lower(sd.domain) = lower(trim(p_hostname))
    order by sd.is_primary desc, sd.created_at asc
    limit 1;
  end if;

  if v_store_id is not null then
    select s.*
      into v_store
    from public.stores s
    where s.id = v_store_id
      and s.archived_at is null
    limit 1;
  elsif nullif(trim(coalesce(p_slug,'')),'') is not null then
    select s.*
      into v_store
    from public.stores s
    where lower(s.slug) = lower(trim(p_slug))
      and s.archived_at is null
    limit 1;
  end if;

  if v_store.id is null then
    return jsonb_build_object('found', false);
  end if;

  if not public.store_accessible(v_store.id) then
    return jsonb_build_object(
      'found', true,
      'status', 'unavailable',
      'store', jsonb_build_object(
        'id', v_store.id,
        'slug', v_store.slug,
        'name', v_store.name
      )
    );
  end if;

  return jsonb_build_object(
    'found', true,
    'status', 'online',
    'store', jsonb_build_object(
      'id', v_store.id,
      'slug', v_store.slug,
      'name', v_store.name,
      'description', v_store.description,
      'logo_url', v_store.logo_url,
      'logo_storage_path', null,
      'cover_url', v_store.cover_url,
      'cover_storage_path', null,
      'whatsapp', v_store.whatsapp,
      'instagram', v_store.instagram,
      'address', v_store.address,
      'city', v_store.city,
      'state', v_store.state,
      'zip_code', v_store.zip_code,
      'delivery_enabled', v_store.delivery_enabled,
      'pickup_enabled', v_store.pickup_enabled,
      'pix_enabled', v_store.pix_enabled,
      'pix_receipt_mode', v_store.pix_receipt_mode,
      'pix_key_type', v_store.pix_key_type,
      'pix_key', v_store.pix_key,
      'pix_copy_paste', v_store.pix_copy_paste,
      'pix_holder_name', v_store.pix_holder_name,
      'show_pix_before_confirmation', v_store.show_pix_before_confirmation,
      'confirmation_payment_enabled', v_store.confirmation_payment_enabled,
      'card_payment_enabled', v_store.card_payment_enabled,
      'cash_payment_enabled', v_store.cash_payment_enabled,
      'payment_method_order', v_store.payment_method_order,
      'minimum_order', v_store.minimum_order,
      'opening_hours', v_store.opening_hours,
      'active', true,
      'access_status', 'online'
    ),
    'categories', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id,
        'store_id', c.store_id,
        'name', c.name,
        'slug', c.slug,
        'description', c.description,
        'active', c.active,
        'sort_order', c.sort_order
      ) order by c.sort_order, c.name)
      from public.categories c
      where c.store_id = v_store.id
        and c.active
    ), '[]'::jsonb),
    'products', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id,
        'store_id', p.store_id,
        'category_id', p.category_id,
        'name', p.name,
        'slug', p.slug,
        'description', p.description,
        'price', p.price,
        'promotional_price', p.promotional_price,
        'active', p.active,
        'featured', p.featured,
        'made_to_order', p.made_to_order,
        'production_days', p.production_days,
        'stock_status', p.stock_status
      ) order by p.featured desc, p.name)
      from public.products p
      join public.categories c
        on c.id = p.category_id
       and c.store_id = p.store_id
       and c.active
      where p.store_id = v_store.id
        and p.active
    ), '[]'::jsonb),
    'product_images', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', pi.id,
        'product_id', pi.product_id,
        'url', pi.url,
        'storage_path', null,
        'alt_text', pi.alt_text,
        'sort_order', pi.sort_order,
        'is_primary', pi.is_primary
      ) order by pi.sort_order, pi.created_at)
      from public.product_images pi
      join public.products p on p.id = pi.product_id
      join public.categories c
        on c.id = p.category_id
       and c.store_id = p.store_id
       and c.active
      where p.store_id = v_store.id
        and p.active
    ), '[]'::jsonb),
    'product_variants', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', pv.id,
        'product_id', pv.product_id,
        'name', pv.name,
        'price_delta', pv.price_delta,
        'active', pv.active,
        'sort_order', pv.sort_order
      ) order by pv.sort_order, pv.name)
      from public.product_variants pv
      join public.products p on p.id = pv.product_id
      join public.categories c
        on c.id = p.category_id
       and c.store_id = p.store_id
       and c.active
      where p.store_id = v_store.id
        and p.active
        and pv.active
    ), '[]'::jsonb),
    'addons', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id,
        'store_id', a.store_id,
        'name', a.name,
        'description', a.description,
        'price', a.price,
        'active', a.active,
        'image_url', a.image_url,
        'image_storage_path', null
      ) order by a.name)
      from public.addons a
      where a.store_id = v_store.id
        and a.active
    ), '[]'::jsonb),
    'product_addons', coalesce((
      select jsonb_agg(jsonb_build_object(
        'product_id', pa.product_id,
        'addon_id', pa.addon_id
      ) order by pa.product_id, pa.addon_id)
      from public.product_addons pa
      join public.products p on p.id = pa.product_id
      join public.categories c
        on c.id = p.category_id
       and c.store_id = p.store_id
       and c.active
      join public.addons a
        on a.id = pa.addon_id
       and a.store_id = p.store_id
       and a.active
      where p.store_id = v_store.id
        and p.active
    ), '[]'::jsonb),
    'delivery_zones', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', dz.id,
        'store_id', dz.store_id,
        'name', dz.name,
        'aliases', dz.aliases,
        'city', dz.city,
        'state', dz.state,
        'fee', dz.fee,
        'active', dz.active,
        'sort_order', dz.sort_order
      ) order by dz.sort_order, dz.name)
      from public.delivery_zones dz
      where dz.store_id = v_store.id
        and dz.active
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.get_public_storefront_v3(text,text) from public;
grant execute on function public.get_public_storefront_v3(text,text) to anon, authenticated;

commit;
-- FloriWeb V3 RC1 - rate limit de pedidos publicos
-- Mantem somente um hash efemero do IP para finalidade de seguranca/anti-abuso.
-- Nenhum IP bruto, nome, telefone, endereco ou conteudo do pedido e gravado nesta tabela.

begin;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table if not exists private.floriweb_security_settings (
  key text primary key,
  value text not null,
  created_at timestamptz not null default now()
);

insert into private.floriweb_security_settings(key,value)
values ('public_order_rate_limit_salt', gen_random_uuid()::text)
on conflict(key) do nothing;

create table if not exists private.public_order_rate_limits (
  id bigint generated by default as identity primary key,
  store_id uuid not null references public.stores(id) on delete cascade,
  fingerprint text not null,
  request_at timestamptz not null default now()
);

create index if not exists public_order_rate_limits_lookup_idx
  on private.public_order_rate_limits(store_id,fingerprint,request_at desc);

revoke all on all tables in schema private from public, anon, authenticated;
revoke all on all sequences in schema private from public, anon, authenticated;

create or replace function public.enforce_public_order_rate_limit(p_store_id uuid)
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_headers jsonb := '{}'::jsonb;
  v_ip text := '';
  v_salt text := '';
  v_fingerprint text;
  v_count integer := 0;
begin
  -- current_setting(..., true) e o contexto HTTP oficial disponibilizado pelo PostgREST.
  begin
    v_headers := coalesce(nullif(current_setting('request.headers', true), '')::jsonb, '{}'::jsonb);
  exception when others then
    v_headers := '{}'::jsonb;
  end;

  v_ip := nullif(trim(coalesce(v_headers->>'cf-connecting-ip','')), '');
  if v_ip is null then
    v_ip := nullif(trim(split_part(coalesce(v_headers->>'x-forwarded-for',''), ',', 1)), '');
  end if;

  -- Chamadas internas/SQL Editor podem nao possuir contexto HTTP; nesse caso o helper
  -- nao interfere na operacao. O checkout publico via PostgREST possui request.headers.
  if v_ip is null then
    return;
  end if;

  select value into v_salt
  from private.floriweb_security_settings
  where key='public_order_rate_limit_salt';

  if coalesce(v_salt,'') = '' then
    raise exception 'Configuracao interna de seguranca ausente.' using errcode='P0001';
  end if;

  -- Salt privado evita armazenar ou expor o IP original. O hash existe apenas para
  -- agrupar tentativas no curto periodo de protecao.
  v_fingerprint := md5(v_ip || ':' || v_salt);

  -- Serializa tentativas simultaneas do mesmo fingerprint/loja.
  perform pg_advisory_xact_lock(hashtextextended(p_store_id::text || ':' || v_fingerprint, 0));

  select count(*) into v_count
  from private.public_order_rate_limits rl
  where rl.store_id = p_store_id
    and rl.fingerprint = v_fingerprint
    and rl.request_at >= now() - interval '10 minutes';

  if v_count >= 8 then
    raise exception 'Muitas tentativas de pedido em pouco tempo. Aguarde alguns minutos e tente novamente.' using errcode='P0001';
  end if;

  insert into private.public_order_rate_limits(store_id,fingerprint)
  values (p_store_id,v_fingerprint);

  -- Retencao curta: registros servem somente ao anti-abuso e sao descartados apos 24 h.
  delete from private.public_order_rate_limits
  where request_at < now() - interval '24 hours';
end;
$$;

revoke all on function public.enforce_public_order_rate_limit(uuid) from public, anon, authenticated;

commit;
-- FloriWeb V3 RC1 - Checkout hardening
-- Mantem o contrato create_public_order(jsonb), mas valida tamanho/formato dos dados,
-- limita fan-out do payload, elimina adicionais duplicados e valida a loja antes do processamento.

begin;

do $$
begin
  if to_regprocedure('public.enforce_public_order_rate_limit(uuid)') is null then
    raise exception 'Aplique primeiro 202608270115_v3_public_order_rate_limit.sql.';
  end if;
end $$;

create or replace function public.create_public_order(payload jsonb)
returns table(order_id uuid, order_number bigint, order_total numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_store public.stores%rowtype;
  v_product public.products%rowtype;
  v_zone public.delivery_zones%rowtype;
  v_order_id uuid := gen_random_uuid();
  v_order_number bigint;
  v_item jsonb;
  v_addon_input jsonb;
  v_addon_record record;
  v_items_calculated jsonb := '[]'::jsonb;
  v_addons_calculated jsonb;
  v_subtotal numeric(12,2) := 0;
  v_delivery_fee numeric(12,2) := 0;
  v_total numeric(12,2) := 0;
  v_product_id uuid;
  v_variant_id uuid;
  v_variant_name text;
  v_variant_delta numeric(12,2);
  v_addon_id uuid;
  v_seen_addon_ids uuid[];
  v_quantity integer;
  v_unit_price numeric(12,2);
  v_item_total numeric(12,2);
  v_desired_date date;
  v_payment_method text;
  v_review_confirmed boolean;
  v_anonymous_sender boolean := false;
  v_customer_phone_digits text;
  v_recipient_phone_digits text;
begin
  if payload is null or jsonb_typeof(payload) <> 'object' then
    raise exception 'Pedido invalido.';
  end if;

  if octet_length(payload::text) > 60000 then
    raise exception 'Pedido excede o tamanho permitido.';
  end if;

  begin
    select s.*
      into v_store
    from public.stores s
    where s.id = (payload->>'store_id')::uuid
      and public.store_accessible(s.id);
  exception when invalid_text_representation then
    raise exception 'Floricultura invalida.';
  end;
  if not found then raise exception 'Floricultura indisponivel.'; end if;

  -- Anti-abuso no servidor antes de processar PII/itens. O helper guarda somente
  -- fingerprint hash com retencao curta e nunca grava o IP bruto.
  perform public.enforce_public_order_rate_limit(v_store.id);

  if char_length(trim(coalesce(payload->>'customer_name',''))) < 2
     or char_length(trim(coalesce(payload->>'customer_name',''))) > 120 then
    raise exception 'Nome do cliente invalido.';
  end if;

  v_customer_phone_digits := regexp_replace(coalesce(payload->>'customer_phone',''), '[^0-9]', '', 'g');
  if char_length(v_customer_phone_digits) < 10 or char_length(v_customer_phone_digits) > 15 then
    raise exception 'Telefone do cliente invalido.';
  end if;

  if nullif(trim(coalesce(payload->>'customer_email','')),'') is not null then
    if char_length(trim(payload->>'customer_email')) > 254
       or trim(payload->>'customer_email') !~* '^[^@[:space:]]+@[^@[:space:]]+[.][^@[:space:]]+$' then
      raise exception 'E-mail do cliente invalido.';
    end if;
  end if;

  if (payload->>'delivery_type') not in ('delivery','pickup') then
    raise exception 'Forma de recebimento invalida.';
  end if;

  if char_length(coalesce(payload->>'desired_period','')) > 80 then raise exception 'Periodo de entrega invalido.'; end if;
  if char_length(coalesce(payload->>'card_message','')) > 500 then raise exception 'Mensagem do cartao excede o limite permitido.'; end if;
  if char_length(coalesce(payload->>'card_signature','')) > 120 then raise exception 'Assinatura do cartao excede o limite permitido.'; end if;
  if char_length(coalesce(payload->>'notes','')) > 500 then raise exception 'Observacoes excedem o limite permitido.'; end if;

  v_payment_method := coalesce(nullif(payload->>'payment_method',''),'confirm');
  if v_payment_method not in ('confirm','pix','card','cash') then raise exception 'Forma de pagamento invalida.'; end if;
  if v_payment_method = 'confirm' and not v_store.confirmation_payment_enabled then raise exception 'Confirmacao manual nao esta disponivel nesta loja.'; end if;
  if v_payment_method = 'pix' and not (v_store.pix_enabled and v_store.show_pix_before_confirmation) then raise exception 'PIX nao esta disponivel nesta loja.'; end if;
  if v_payment_method = 'card' and not v_store.card_payment_enabled then raise exception 'Pagamento por cartao nao esta disponivel nesta loja.'; end if;
  if v_payment_method = 'cash' and not v_store.cash_payment_enabled then raise exception 'Pagamento em dinheiro nao esta disponivel nesta loja.'; end if;

  begin
    v_review_confirmed := coalesce((payload->>'review_confirmed')::boolean, false);
  exception when others then
    v_review_confirmed := false;
  end;
  if not v_review_confirmed then raise exception 'Confirme que revisou os dados do pedido.'; end if;

  begin
    v_anonymous_sender := coalesce((payload->>'anonymous_sender')::boolean, false);
  exception when others then
    raise exception 'Opcao de remetente anonimo invalida.';
  end;

  if (payload->>'delivery_type') = 'delivery' and not v_store.delivery_enabled then raise exception 'Entrega esta desativada.'; end if;
  if (payload->>'delivery_type') = 'pickup' and not v_store.pickup_enabled then raise exception 'Retirada esta desativada.'; end if;

  if (payload->>'delivery_type') = 'delivery' then
    if char_length(trim(coalesce(payload->>'recipient_name',''))) < 2
       or char_length(trim(coalesce(payload->>'recipient_name',''))) > 120 then
      raise exception 'Nome do destinatario invalido.';
    end if;

    v_recipient_phone_digits := regexp_replace(coalesce(payload->>'recipient_phone',''), '[^0-9]', '', 'g');
    if char_length(v_recipient_phone_digits) < 10 or char_length(v_recipient_phone_digits) > 15 then
      raise exception 'Telefone do destinatario invalido.';
    end if;

    if char_length(trim(coalesce(payload->>'delivery_address',''))) < 3
       or char_length(trim(coalesce(payload->>'delivery_address',''))) > 600 then raise exception 'Endereco de entrega invalido.'; end if;
    if char_length(trim(coalesce(payload->>'delivery_street',''))) < 2
       or char_length(trim(coalesce(payload->>'delivery_street',''))) > 180 then raise exception 'Rua de entrega invalida.'; end if;
    if char_length(trim(coalesce(payload->>'delivery_number',''))) < 1
       or char_length(trim(coalesce(payload->>'delivery_number',''))) > 30 then raise exception 'Numero do endereco invalido.'; end if;
    if char_length(coalesce(payload->>'delivery_complement','')) > 120 then raise exception 'Complemento excede o limite permitido.'; end if;
    if char_length(coalesce(payload->>'delivery_zip_code','')) > 20 then raise exception 'CEP invalido.'; end if;
    if char_length(coalesce(payload->>'reference_point','')) > 160 then raise exception 'Ponto de referencia excede o limite permitido.'; end if;
    if coalesce(trim(payload->>'delivery_zone_id'),'') = '' then raise exception 'Selecione o bairro/area de entrega.'; end if;

    begin
      select dz.*
        into v_zone
      from public.delivery_zones dz
      where dz.id = (payload->>'delivery_zone_id')::uuid
        and dz.store_id = v_store.id
        and dz.active;
    exception when invalid_text_representation then
      raise exception 'Area de entrega invalida.';
    end;
    if not found then raise exception 'A area de entrega selecionada nao esta disponivel.'; end if;
    v_delivery_fee := round(v_zone.fee, 2);
  else
    v_delivery_fee := 0;
  end if;

  if jsonb_typeof(payload->'items') <> 'array' or jsonb_array_length(payload->'items') = 0 then
    raise exception 'Pedido sem itens.';
  end if;
  if jsonb_array_length(payload->'items') > 50 then
    raise exception 'O pedido excede o limite de 50 itens distintos.';
  end if;

  begin
    v_desired_date := (payload->>'desired_date')::date;
  exception when others then
    raise exception 'Data desejada invalida.';
  end;
  if v_desired_date is null then raise exception 'Data desejada invalida.'; end if;
  if v_desired_date < current_date then raise exception 'A data desejada nao pode estar no passado.'; end if;

  -- Valores enviados pelo navegador sao ignorados. Precos e totais sao recalculados no banco.
  for v_item in select * from jsonb_array_elements(payload->'items') loop
    if jsonb_typeof(v_item) <> 'object' then raise exception 'Item invalido no pedido.'; end if;

    begin
      v_product_id := (v_item->>'product_id')::uuid;
    exception when invalid_text_representation then
      raise exception 'Produto invalido no pedido.';
    end;

    select p.*
      into v_product
    from public.products p
    where p.id = v_product_id
      and p.store_id = v_store.id
      and p.active
      and p.stock_status <> 'unavailable'
      and exists (
        select 1
        from public.categories c
        where c.id = p.category_id
          and c.store_id = p.store_id
          and c.active
      );
    if not found then raise exception 'Um dos produtos nao esta mais disponivel.'; end if;

    begin
      v_quantity := (v_item->>'quantity')::integer;
    exception when others then
      raise exception 'Quantidade invalida.';
    end;
    if coalesce(v_quantity,0) <= 0 or v_quantity > 99 then raise exception 'Quantidade invalida.'; end if;

    v_variant_id := null;
    v_variant_name := null;
    v_variant_delta := 0;
    if nullif(v_item->>'variant_id','') is not null then
      begin
        v_variant_id := (v_item->>'variant_id')::uuid;
      exception when invalid_text_representation then
        raise exception 'Variacao invalida.';
      end;
      select pv.name, pv.price_delta
        into v_variant_name, v_variant_delta
      from public.product_variants pv
      where pv.id = v_variant_id
        and pv.product_id = v_product.id
        and pv.active;
      if not found then raise exception 'Uma das variacoes nao esta mais disponivel.'; end if;
    end if;

    v_unit_price := coalesce(v_product.promotional_price, v_product.price) + coalesce(v_variant_delta,0);
    if v_unit_price < 0 then raise exception 'Preco do produto invalido.'; end if;

    v_addons_calculated := '[]'::jsonb;
    v_seen_addon_ids := array[]::uuid[];

    if jsonb_typeof(coalesce(v_item->'addons','[]'::jsonb)) <> 'array' then raise exception 'Adicionais invalidos.'; end if;
    if jsonb_array_length(coalesce(v_item->'addons','[]'::jsonb)) > 20 then raise exception 'Quantidade de adicionais excede o limite permitido.'; end if;

    for v_addon_input in select * from jsonb_array_elements(coalesce(v_item->'addons','[]'::jsonb)) loop
      if jsonb_typeof(v_addon_input) <> 'object' then raise exception 'Adicional invalido.'; end if;
      begin
        v_addon_id := (v_addon_input->>'id')::uuid;
      exception when invalid_text_representation then
        raise exception 'Adicional invalido.';
      end;

      if v_addon_id = any(v_seen_addon_ids) then
        raise exception 'O mesmo adicional nao pode ser enviado mais de uma vez no mesmo item.';
      end if;
      v_seen_addon_ids := array_append(v_seen_addon_ids, v_addon_id);

      select a.id, a.name, a.price
        into v_addon_record
      from public.addons a
      join public.product_addons pa on pa.addon_id = a.id
      where pa.product_id = v_product.id
        and a.id = v_addon_id
        and a.store_id = v_store.id
        and a.active;
      if not found then raise exception 'Um dos adicionais nao esta mais disponivel.'; end if;

      v_addons_calculated := v_addons_calculated || jsonb_build_array(jsonb_build_object(
        'id', v_addon_record.id,
        'name', v_addon_record.name,
        'price', v_addon_record.price
      ));
    end loop;

    v_item_total := round((
      v_unit_price
      + coalesce((
          select sum((entry->>'price')::numeric)
          from jsonb_array_elements(v_addons_calculated) entry
        ),0)
    ) * v_quantity, 2);

    v_subtotal := v_subtotal + v_item_total;
    v_items_calculated := v_items_calculated || jsonb_build_array(jsonb_build_object(
      'product_id', v_product.id,
      'product_name', v_product.name,
      'quantity', v_quantity,
      'unit_price', round(v_unit_price,2),
      'variant_name', v_variant_name,
      'variant_price_delta', coalesce(v_variant_delta,0),
      'addons', v_addons_calculated,
      'item_total', v_item_total
    ));
  end loop;

  v_subtotal := round(v_subtotal, 2);
  if v_subtotal < v_store.minimum_order then raise exception 'Pedido abaixo do minimo da loja.'; end if;
  v_total := round(v_subtotal + v_delivery_fee, 2);

  insert into public.orders as o(
    id, store_id, customer_name, customer_phone, customer_email, delivery_type, desired_date, desired_period,
    recipient_name, recipient_phone, delivery_address, delivery_zip_code, delivery_street, delivery_number,
    delivery_complement, delivery_neighborhood, delivery_zone_id, delivery_zone_name, delivery_fee,
    delivery_city, delivery_state, reference_point,
    card_message, card_signature, anonymous_sender, notes, payment_method, review_confirmed,
    subtotal, total, status, whatsapp_clicked_at
  ) values(
    v_order_id,
    v_store.id,
    trim(payload->>'customer_name'),
    trim(payload->>'customer_phone'),
    nullif(trim(payload->>'customer_email'),''),
    payload->>'delivery_type',
    v_desired_date,
    nullif(trim(payload->>'desired_period'),''),
    case when payload->>'delivery_type'='delivery' then nullif(trim(payload->>'recipient_name'),'') else null end,
    case when payload->>'delivery_type'='delivery' then nullif(trim(payload->>'recipient_phone'),'') else null end,
    case when payload->>'delivery_type'='delivery' then nullif(trim(payload->>'delivery_address'),'') else null end,
    case when payload->>'delivery_type'='delivery' then nullif(trim(payload->>'delivery_zip_code'),'') else null end,
    case when payload->>'delivery_type'='delivery' then nullif(trim(payload->>'delivery_street'),'') else null end,
    case when payload->>'delivery_type'='delivery' then nullif(trim(payload->>'delivery_number'),'') else null end,
    case when payload->>'delivery_type'='delivery' then nullif(trim(payload->>'delivery_complement'),'') else null end,
    case when payload->>'delivery_type'='delivery' then v_zone.name else null end,
    case when payload->>'delivery_type'='delivery' then v_zone.id else null end,
    case when payload->>'delivery_type'='delivery' then v_zone.name else null end,
    v_delivery_fee,
    case when payload->>'delivery_type'='delivery' then v_zone.city else null end,
    case when payload->>'delivery_type'='delivery' then upper(v_zone.state) else null end,
    case when payload->>'delivery_type'='delivery' then nullif(trim(payload->>'reference_point'),'') else null end,
    nullif(trim(payload->>'card_message'),''),
    case when v_anonymous_sender then null else nullif(trim(payload->>'card_signature'),'') end,
    v_anonymous_sender,
    nullif(trim(payload->>'notes'),''),
    v_payment_method,
    v_review_confirmed,
    v_subtotal,
    v_total,
    'draft',
    null
  )
  returning o.order_number into v_order_number;

  for v_item in select * from jsonb_array_elements(v_items_calculated) loop
    insert into public.order_items(
      order_id, product_id, product_name, quantity, unit_price,
      variant_name, variant_price_delta, addons, item_total
    ) values(
      v_order_id,
      (v_item->>'product_id')::uuid,
      v_item->>'product_name',
      (v_item->>'quantity')::integer,
      (v_item->>'unit_price')::numeric,
      nullif(v_item->>'variant_name',''),
      (v_item->>'variant_price_delta')::numeric,
      coalesce(v_item->'addons','[]'::jsonb),
      (v_item->>'item_total')::numeric
    );
  end loop;

  return query select v_order_id, v_order_number, v_total;
end;
$$;

revoke all on function public.create_public_order(jsonb) from public;
grant execute on function public.create_public_order(jsonb) to anon, authenticated;

commit;
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
