-- FloriWeb 2.6.0
-- Áreas/taxas de entrega, PIX total com frete, pagamento em dinheiro,
-- ordem das formas de pagamento e confirmação obrigatória dos dados.

alter table public.stores
  add column if not exists confirmation_payment_enabled boolean not null default true,
  add column if not exists cash_payment_enabled boolean not null default false,
  add column if not exists payment_method_order jsonb not null default '["confirm","pix","card","cash"]'::jsonb;

alter table public.stores
  drop constraint if exists stores_payment_method_order_array_check;

alter table public.stores
  add constraint stores_payment_method_order_array_check
  check (jsonb_typeof(payment_method_order) = 'array');

create table if not exists public.delivery_zones (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  name text not null,
  aliases text[] not null default '{}',
  city text not null,
  state varchar(2) not null,
  fee numeric(12,2) not null default 0 check (fee >= 0),
  active boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint delivery_zones_store_name_city_state_key unique (store_id, name, city, state)
);

create index if not exists delivery_zones_store_active_sort_idx
  on public.delivery_zones(store_id, active, sort_order, name);

drop trigger if exists delivery_zones_set_updated_at on public.delivery_zones;
create trigger delivery_zones_set_updated_at
before update on public.delivery_zones
for each row execute function public.set_updated_at();

alter table public.delivery_zones enable row level security;

drop policy if exists delivery_zones_public_read on public.delivery_zones;
drop policy if exists delivery_zones_admin_all on public.delivery_zones;

create policy delivery_zones_public_read
on public.delivery_zones
for select
to anon, authenticated
using (
  active
  and exists (
    select 1 from public.stores s
    where s.id = store_id and s.active
  )
);

create policy delivery_zones_admin_all
on public.delivery_zones
for all
to authenticated
using (public.is_store_admin(store_id))
with check (public.is_store_admin(store_id));

alter table public.orders
  add column if not exists delivery_zone_id uuid references public.delivery_zones(id) on delete set null,
  add column if not exists delivery_zone_name text,
  add column if not exists delivery_fee numeric(12,2) not null default 0 check (delivery_fee >= 0),
  add column if not exists review_confirmed boolean not null default false;

alter table public.orders
  drop constraint if exists orders_payment_method_check;

alter table public.orders
  add constraint orders_payment_method_check
  check (payment_method in ('confirm','pix','card','cash'));

-- Bairros padrão de Linhares. Entram desativados para que a loja defina a taxa
-- conscientemente antes de oferecê-los no checkout.
insert into public.delivery_zones(store_id, name, aliases, city, state, fee, active, sort_order)
select
  s.id,
  z.name,
  z.aliases,
  'Linhares',
  'ES',
  0,
  false,
  z.sort_order
from public.stores s
cross join (
  values
    ('Alphaville', array[]::text[], 10),
    ('Araçá', array[]::text[], 20),
    ('Aviso', array[]::text[], 30),
    ('Bebedouro', array['Bebedouro (bairro/distrito integrado)']::text[], 40),
    ('Betânia', array['Vila Betânea','Vila Betania']::text[], 50),
    ('Boa Vista', array[]::text[], 60),
    ('Canivete', array[]::text[], 70),
    ('Centro', array[]::text[], 80),
    ('Colina', array[]::text[], 90),
    ('Conceição', array['Nossa Senhora da Conceição','Nossa Senhora da Conceicao']::text[], 100),
    ('Farias', array['Farias (área urbana)','Farias (area urbana)']::text[], 110),
    ('Gaivotas', array[]::text[], 120),
    ('Interlagos', array[]::text[], 130),
    ('Jardim Laguna', array['Jardim Laguna I','Jardim Laguna II','Jardim Laguna (I e II)']::text[], 140),
    ('Jocafe', array['Jocafe I','Jocafe II','Jocafe (I e II)']::text[], 150),
    ('José Rodrigues Maciel', array['Jose Rodrigues Maciel']::text[], 160),
    ('Juparanã', array['Juparana']::text[], 170),
    ('Lagoa do Meio', array[]::text[], 180),
    ('Linhares V', array[]::text[], 190),
    ('Movelar', array['Mobrasa','Movelar (incluindo Mobrasa)']::text[], 200),
    ('Nova Esperança', array['Nova Esperanca']::text[], 210),
    ('Novo Horizonte', array[]::text[], 220),
    ('Olaria', array[]::text[], 230),
    ('Palmital', array[]::text[], 240),
    ('Planalto', array[]::text[], 250),
    ('Residencial Rio Doce', array[]::text[], 260),
    ('Rio Quartel', array['Rio Quartel (área urbana)','Rio Quartel (area urbana)']::text[], 270),
    ('Santa Cruz', array[]::text[], 280),
    ('Shell', array['Pó do Shell','Po do Shell','Shell (incluindo Pó do Shell)']::text[], 290),
    ('Três Barras', array['Tres Barras']::text[], 300),
    ('Vila Isabel', array[]::text[], 310)
) as z(name, aliases, sort_order)
where lower(trim(s.city)) = 'linhares'
  and upper(trim(s.state)) = 'ES'
on conflict (store_id, name, city, state) do nothing;

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
  v_quantity integer;
  v_unit_price numeric(12,2);
  v_item_total numeric(12,2);
  v_desired_date date;
  v_payment_method text;
  v_review_confirmed boolean;
begin
  begin
    select * into v_store
    from public.stores
    where id = (payload->>'store_id')::uuid
      and active;
  exception when invalid_text_representation then
    raise exception 'Floricultura inválida.';
  end;
  if not found then raise exception 'Floricultura indisponível.'; end if;

  if coalesce(trim(payload->>'customer_name'),'') = '' then raise exception 'Nome do cliente é obrigatório.'; end if;
  if coalesce(trim(payload->>'customer_phone'),'') = '' then raise exception 'Telefone do cliente é obrigatório.'; end if;
  if (payload->>'delivery_type') not in ('delivery','pickup') then raise exception 'Forma de recebimento inválida.'; end if;

  v_payment_method := coalesce(nullif(payload->>'payment_method',''),'confirm');
  if v_payment_method not in ('confirm','pix','card','cash') then raise exception 'Forma de pagamento inválida.'; end if;
  if v_payment_method = 'confirm' and not v_store.confirmation_payment_enabled then raise exception 'Confirmação manual não está disponível nesta loja.'; end if;
  if v_payment_method = 'pix' and not (v_store.pix_enabled and v_store.show_pix_before_confirmation) then raise exception 'PIX não está disponível nesta loja.'; end if;
  if v_payment_method = 'card' and not v_store.card_payment_enabled then raise exception 'Pagamento por cartão não está disponível nesta loja.'; end if;
  if v_payment_method = 'cash' and not v_store.cash_payment_enabled then raise exception 'Pagamento em dinheiro não está disponível nesta loja.'; end if;

  begin
    v_review_confirmed := coalesce((payload->>'review_confirmed')::boolean, false);
  exception when others then
    v_review_confirmed := false;
  end;
  if not v_review_confirmed then raise exception 'Confirme que revisou os dados do pedido.'; end if;

  if (payload->>'delivery_type') = 'delivery' and not v_store.delivery_enabled then raise exception 'Entrega está desativada.'; end if;
  if (payload->>'delivery_type') = 'pickup' and not v_store.pickup_enabled then raise exception 'Retirada está desativada.'; end if;

  if (payload->>'delivery_type') = 'delivery' then
    if coalesce(trim(payload->>'recipient_name'),'') = '' then raise exception 'Nome do destinatário é obrigatório.'; end if;
    if coalesce(trim(payload->>'recipient_phone'),'') = '' then raise exception 'Telefone do destinatário é obrigatório.'; end if;
    if coalesce(trim(payload->>'delivery_address'),'') = '' then raise exception 'Endereço é obrigatório para entrega.'; end if;
    if coalesce(trim(payload->>'delivery_street'),'') = '' then raise exception 'Rua é obrigatória para entrega.'; end if;
    if coalesce(trim(payload->>'delivery_number'),'') = '' then raise exception 'Número é obrigatório para entrega.'; end if;
    if coalesce(trim(payload->>'delivery_zone_id'),'') = '' then raise exception 'Selecione o bairro/área de entrega.'; end if;

    begin
      select * into v_zone
      from public.delivery_zones dz
      where dz.id = (payload->>'delivery_zone_id')::uuid
        and dz.store_id = v_store.id
        and dz.active;
    exception when invalid_text_representation then
      raise exception 'Área de entrega inválida.';
    end;
    if not found then raise exception 'A área de entrega selecionada não está disponível.'; end if;
    v_delivery_fee := round(v_zone.fee, 2);
  else
    v_delivery_fee := 0;
  end if;

  if jsonb_typeof(payload->'items') <> 'array' or jsonb_array_length(payload->'items') = 0 then raise exception 'Pedido sem itens.'; end if;

  begin
    v_desired_date := (payload->>'desired_date')::date;
  exception when others then
    raise exception 'Data desejada inválida.';
  end;
  if v_desired_date < current_date then raise exception 'A data desejada não pode estar no passado.'; end if;

  -- Recalcula preços exclusivamente a partir do banco.
  for v_item in select * from jsonb_array_elements(payload->'items') loop
    begin
      v_product_id := (v_item->>'product_id')::uuid;
    exception when invalid_text_representation then
      raise exception 'Produto inválido no pedido.';
    end;

    select p.* into v_product
    from public.products p
    where p.id = v_product_id
      and p.store_id = v_store.id
      and p.active
      and p.stock_status <> 'unavailable'
      and exists (
        select 1 from public.categories c
        where c.id = p.category_id and c.store_id = p.store_id and c.active
      );
    if not found then raise exception 'Um dos produtos não está mais disponível.'; end if;

    begin
      v_quantity := (v_item->>'quantity')::integer;
    exception when others then
      raise exception 'Quantidade inválida.';
    end;
    if coalesce(v_quantity,0) <= 0 or v_quantity > 99 then raise exception 'Quantidade inválida.'; end if;

    v_variant_id := null;
    v_variant_name := null;
    v_variant_delta := 0;
    if nullif(v_item->>'variant_id','') is not null then
      begin
        v_variant_id := (v_item->>'variant_id')::uuid;
      exception when invalid_text_representation then
        raise exception 'Variação inválida.';
      end;
      select pv.name, pv.price_delta into v_variant_name, v_variant_delta
      from public.product_variants pv
      where pv.id = v_variant_id and pv.product_id = v_product.id and pv.active;
      if not found then raise exception 'Uma das variações não está mais disponível.'; end if;
    end if;

    v_unit_price := coalesce(v_product.promotional_price, v_product.price) + coalesce(v_variant_delta,0);
    if v_unit_price < 0 then raise exception 'Preço do produto inválido.'; end if;
    v_addons_calculated := '[]'::jsonb;

    if jsonb_typeof(coalesce(v_item->'addons','[]'::jsonb)) <> 'array' then raise exception 'Adicionais inválidos.'; end if;
    for v_addon_input in select * from jsonb_array_elements(coalesce(v_item->'addons','[]'::jsonb)) loop
      begin
        select a.id, a.name, a.price into v_addon_record
        from public.addons a
        join public.product_addons pa on pa.addon_id = a.id
        where pa.product_id = v_product.id
          and a.id = (v_addon_input->>'id')::uuid
          and a.store_id = v_store.id
          and a.active;
      exception when invalid_text_representation then
        raise exception 'Adicional inválido.';
      end;
      if not found then raise exception 'Um dos adicionais não está mais disponível.'; end if;
      v_addons_calculated := v_addons_calculated || jsonb_build_array(jsonb_build_object(
        'id', v_addon_record.id,
        'name', v_addon_record.name,
        'price', v_addon_record.price
      ));
    end loop;

    v_item_total := round((v_unit_price + coalesce((select sum((entry->>'price')::numeric) from jsonb_array_elements(v_addons_calculated) entry),0)) * v_quantity, 2);
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
  if v_subtotal < v_store.minimum_order then raise exception 'Pedido abaixo do mínimo da loja.'; end if;
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
    nullif(trim(payload->>'customer_phone'),''),
    nullif(trim(payload->>'customer_email'),''),
    payload->>'delivery_type',
    v_desired_date,
    nullif(payload->>'desired_period',''),
    nullif(payload->>'recipient_name',''),
    nullif(payload->>'recipient_phone',''),
    case when payload->>'delivery_type'='delivery' then nullif(payload->>'delivery_address','') else null end,
    case when payload->>'delivery_type'='delivery' then nullif(payload->>'delivery_zip_code','') else null end,
    case when payload->>'delivery_type'='delivery' then nullif(payload->>'delivery_street','') else null end,
    case when payload->>'delivery_type'='delivery' then nullif(payload->>'delivery_number','') else null end,
    case when payload->>'delivery_type'='delivery' then nullif(payload->>'delivery_complement','') else null end,
    case when payload->>'delivery_type'='delivery' then v_zone.name else null end,
    case when payload->>'delivery_type'='delivery' then v_zone.id else null end,
    case when payload->>'delivery_type'='delivery' then v_zone.name else null end,
    v_delivery_fee,
    case when payload->>'delivery_type'='delivery' then v_zone.city else null end,
    case when payload->>'delivery_type'='delivery' then upper(v_zone.state) else null end,
    case when payload->>'delivery_type'='delivery' then nullif(payload->>'reference_point','') else null end,
    nullif(payload->>'card_message',''),
    case when coalesce((payload->>'anonymous_sender')::boolean,false) then null else nullif(payload->>'card_signature','') end,
    coalesce((payload->>'anonymous_sender')::boolean,false),
    nullif(payload->>'notes',''),
    v_payment_method,
    v_review_confirmed,
    v_subtotal,
    v_total,
    'draft',
    null
  )
  returning o.order_number into v_order_number;

  for v_item in select * from jsonb_array_elements(v_items_calculated) loop
    insert into public.order_items(order_id,product_id,product_name,quantity,unit_price,variant_name,variant_price_delta,addons,item_total)
    values(
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
