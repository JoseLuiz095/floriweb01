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
