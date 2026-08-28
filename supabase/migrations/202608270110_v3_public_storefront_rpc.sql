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
