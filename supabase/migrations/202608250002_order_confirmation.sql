-- FloriWeb 2.1.0 - confirmação final e número amigável do pedido
-- Pode ser executada em bancos criados com a migration 2.0.0.

create sequence if not exists public.orders_order_number_seq start with 10001;

alter table public.orders
  add column if not exists order_number bigint;

alter table public.orders
  alter column order_number set default nextval('public.orders_order_number_seq');

update public.orders
set order_number = nextval('public.orders_order_number_seq')
where order_number is null;

alter table public.orders
  alter column order_number set not null;

create unique index if not exists orders_order_number_uidx
  on public.orders(order_number);

-- O retorno da função mudou na versão 2.1, portanto é necessário recriá-la.
drop function if exists public.create_public_order(jsonb);

create or replace function public.create_public_order(payload jsonb)
returns table(order_id uuid, order_number bigint, order_total numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_store public.stores%rowtype;
  v_product public.products%rowtype;
  v_order_id uuid := gen_random_uuid();
  v_order_number bigint;
  v_item jsonb;
  v_addon_input jsonb;
  v_addon_record record;
  v_items_calculated jsonb := '[]'::jsonb;
  v_addons_calculated jsonb;
  v_total numeric(12,2) := 0;
  v_product_id uuid;
  v_variant_id uuid;
  v_variant_name text;
  v_variant_delta numeric(12,2);
  v_quantity integer;
  v_unit_price numeric(12,2);
  v_item_total numeric(12,2);
  v_desired_date date;
begin
  begin
    select * into v_store from public.stores where id=(payload->>'store_id')::uuid and active;
  exception when invalid_text_representation then
    raise exception 'Floricultura inválida.';
  end;
  if not found then raise exception 'Floricultura indisponível.'; end if;

  if coalesce(trim(payload->>'customer_name'),'')='' then raise exception 'Nome do cliente é obrigatório.'; end if;
  if (payload->>'delivery_type') not in ('delivery','pickup') then raise exception 'Forma de recebimento inválida.'; end if;
  if coalesce(payload->>'payment_method','confirm') not in ('confirm','pix') then raise exception 'Forma de pagamento inválida.'; end if;
  if (payload->>'delivery_type')='delivery' and not v_store.delivery_enabled then raise exception 'Entrega está desativada.'; end if;
  if (payload->>'delivery_type')='pickup' and not v_store.pickup_enabled then raise exception 'Retirada está desativada.'; end if;
  if (payload->>'delivery_type')='delivery' and coalesce(trim(payload->>'delivery_address'),'')='' then raise exception 'Endereço é obrigatório para entrega.'; end if;
  if jsonb_typeof(payload->'items') <> 'array' or jsonb_array_length(payload->'items')=0 then raise exception 'Pedido sem itens.'; end if;

  begin
    v_desired_date := (payload->>'desired_date')::date;
  exception when others then
    raise exception 'Data desejada inválida.';
  end;
  if v_desired_date < current_date then raise exception 'A data desejada não pode estar no passado.'; end if;

  -- Calcula o pedido novamente no banco. Preços enviados pelo navegador são apenas informativos.
  for v_item in select * from jsonb_array_elements(payload->'items') loop
    begin
      v_product_id := (v_item->>'product_id')::uuid;
    exception when invalid_text_representation then
      raise exception 'Produto inválido no pedido.';
    end;

    select p.* into v_product
    from public.products p
    where p.id=v_product_id
      and p.store_id=v_store.id
      and p.active
      and p.stock_status <> 'unavailable'
      and exists (
        select 1 from public.categories c
        where c.id=p.category_id and c.store_id=p.store_id and c.active
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
      where pv.id=v_variant_id and pv.product_id=v_product.id and pv.active;
      if not found then raise exception 'Uma das variações não está mais disponível.'; end if;
    end if;

    v_unit_price := coalesce(v_product.promotional_price,v_product.price) + coalesce(v_variant_delta,0);
    if v_unit_price < 0 then raise exception 'Preço do produto inválido.'; end if;
    v_addons_calculated := '[]'::jsonb;

    if jsonb_typeof(coalesce(v_item->'addons','[]'::jsonb)) <> 'array' then raise exception 'Adicionais inválidos.'; end if;
    for v_addon_input in select * from jsonb_array_elements(coalesce(v_item->'addons','[]'::jsonb)) loop
      begin
        select a.id, a.name, a.price into v_addon_record
        from public.addons a
        join public.product_addons pa on pa.addon_id=a.id
        where pa.product_id=v_product.id
          and a.id=(v_addon_input->>'id')::uuid
          and a.store_id=v_store.id
          and a.active;
      exception when invalid_text_representation then
        raise exception 'Adicional inválido.';
      end;
      if not found then raise exception 'Um dos adicionais não está mais disponível.'; end if;
      v_addons_calculated := v_addons_calculated || jsonb_build_array(jsonb_build_object(
        'id',v_addon_record.id,
        'name',v_addon_record.name,
        'price',v_addon_record.price
      ));
    end loop;

    v_item_total := round((v_unit_price + coalesce((select sum((entry->>'price')::numeric) from jsonb_array_elements(v_addons_calculated) entry),0)) * v_quantity,2);
    v_total := v_total + v_item_total;
    v_items_calculated := v_items_calculated || jsonb_build_array(jsonb_build_object(
      'product_id',v_product.id,
      'product_name',v_product.name,
      'quantity',v_quantity,
      'unit_price',round(v_unit_price,2),
      'variant_name',v_variant_name,
      'variant_price_delta',coalesce(v_variant_delta,0),
      'addons',v_addons_calculated,
      'item_total',v_item_total
    ));
  end loop;

  v_total := round(v_total,2);
  if v_total < v_store.minimum_order then raise exception 'Pedido abaixo do mínimo da loja.'; end if;

  insert into public.orders as o(
    id,store_id,customer_name,customer_phone,delivery_type,desired_date,desired_period,
    recipient_name,delivery_address,card_message,notes,payment_method,subtotal,total,status,whatsapp_clicked_at
  ) values(
    v_order_id,v_store.id,trim(payload->>'customer_name'),nullif(trim(payload->>'customer_phone'),''),payload->>'delivery_type',v_desired_date,
    nullif(payload->>'desired_period',''),nullif(payload->>'recipient_name',''),
    case when payload->>'delivery_type'='delivery' then nullif(payload->>'delivery_address','') else null end,
    nullif(payload->>'card_message',''),nullif(payload->>'notes',''),coalesce(nullif(payload->>'payment_method',''),'confirm'),
    v_total,v_total,'draft',null
  )
  returning o.order_number into v_order_number;

  for v_item in select * from jsonb_array_elements(v_items_calculated) loop
    insert into public.order_items(order_id,product_id,product_name,quantity,unit_price,variant_name,variant_price_delta,addons,item_total)
    values(
      v_order_id,(v_item->>'product_id')::uuid,v_item->>'product_name',(v_item->>'quantity')::integer,
      (v_item->>'unit_price')::numeric,nullif(v_item->>'variant_name',''),(v_item->>'variant_price_delta')::numeric,
      coalesce(v_item->'addons','[]'::jsonb),(v_item->>'item_total')::numeric
    );
  end loop;

  return query select v_order_id, v_order_number, v_total;
end;
$$;

revoke all on function public.create_public_order(jsonb) from public;
grant execute on function public.create_public_order(jsonb) to anon, authenticated;

-- Marca que o cliente abriu o WhatsApp a partir da tela final do pedido.
create or replace function public.mark_public_order_whatsapp_clicked(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.orders
  set status='sent_to_whatsapp',
      whatsapp_clicked_at=coalesce(whatsapp_clicked_at,now())
  where id=p_order_id
    and status='draft';
end;
$$;

revoke all on function public.mark_public_order_whatsapp_clicked(uuid) from public;
grant execute on function public.mark_public_order_whatsapp_clicked(uuid) to anon, authenticated;
