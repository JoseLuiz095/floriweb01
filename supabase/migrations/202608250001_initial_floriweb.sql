-- FloriWeb V2 - estrutura inicial multi-floricultura
-- PostgreSQL / Supabase

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.stores (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text,
  logo_url text,
  logo_storage_path text,
  cover_url text,
  cover_storage_path text,
  whatsapp text,
  instagram text,
  address text,
  city text,
  state varchar(2),
  zip_code text,
  delivery_enabled boolean not null default true,
  pickup_enabled boolean not null default true,
  pix_enabled boolean not null default false,
  pix_key_type text,
  pix_key text,
  pix_holder_name text,
  show_pix_before_confirmation boolean not null default false,
  minimum_order numeric(12,2) not null default 0 check (minimum_order >= 0),
  opening_hours jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint stores_fulfillment_ck check (delivery_enabled or pickup_enabled)
);

create table if not exists public.store_users (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'admin' check (role in ('owner','admin','employee')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (store_id, user_id)
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  name text not null,
  slug text not null,
  description text,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (store_id, slug)
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete restrict,
  name text not null,
  slug text not null,
  description text not null default '',
  price numeric(12,2) not null default 0 check (price >= 0),
  promotional_price numeric(12,2) check (promotional_price is null or promotional_price >= 0),
  active boolean not null default true,
  featured boolean not null default false,
  made_to_order boolean not null default false,
  production_days integer not null default 0 check (production_days >= 0),
  stock_status text not null default 'available' check (stock_status in ('available','low_stock','unavailable')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (store_id, slug),
  constraint products_promo_ck check (promotional_price is null or promotional_price <= price)
);

create table if not exists public.product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  url text not null,
  storage_path text,
  alt_text text,
  sort_order integer not null default 0,
  is_primary boolean not null default false,
  created_at timestamptz not null default now()
);

create unique index if not exists product_images_one_primary_idx
on public.product_images(product_id)
where is_primary;

create table if not exists public.product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  name text not null,
  price_delta numeric(12,2) not null default 0,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.addons (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  name text not null,
  description text,
  price numeric(12,2) not null default 0 check (price >= 0),
  image_url text,
  image_storage_path text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.product_addons (
  product_id uuid not null references public.products(id) on delete cascade,
  addon_id uuid not null references public.addons(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (product_id, addon_id)
);

create table if not exists public.plans (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  product_limit integer check (product_limit is null or product_limit >= 0),
  image_limit_per_product integer check (image_limit_per_product is null or image_limit_per_product >= 0),
  custom_domain boolean not null default false,
  reports boolean not null default false,
  priority_support boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.store_subscriptions (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  plan_id uuid not null references public.plans(id) on delete restrict,
  status text not null default 'trial' check (status in ('trial','active','suspended','cancelled')),
  started_at timestamptz not null default now(),
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists store_subscriptions_one_current_idx
on public.store_subscriptions(store_id)
where status in ('trial','active');

create sequence if not exists public.orders_order_number_seq start with 10001;

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number bigint not null default nextval('public.orders_order_number_seq'),
  store_id uuid not null references public.stores(id) on delete cascade,
  customer_name text not null,
  customer_phone text,
  delivery_type text not null check (delivery_type in ('delivery','pickup')),
  desired_date date not null,
  desired_period text,
  recipient_name text,
  delivery_address text,
  card_message text,
  notes text,
  payment_method text not null default 'confirm' check (payment_method in ('confirm','pix')),
  subtotal numeric(12,2) not null default 0 check (subtotal >= 0),
  total numeric(12,2) not null default 0 check (total >= 0),
  status text not null default 'draft' check (status in ('draft','sent_to_whatsapp','cancelled')),
  whatsapp_clicked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  product_name text not null,
  quantity integer not null check (quantity > 0),
  unit_price numeric(12,2) not null check (unit_price >= 0),
  variant_name text,
  variant_price_delta numeric(12,2) not null default 0,
  addons jsonb not null default '[]'::jsonb,
  item_total numeric(12,2) not null check (item_total >= 0),
  created_at timestamptz not null default now()
);

create index if not exists categories_store_idx on public.categories(store_id, active, sort_order);
create index if not exists products_store_idx on public.products(store_id, active, featured);
create index if not exists products_category_idx on public.products(category_id);
create index if not exists product_images_product_idx on public.product_images(product_id, sort_order);
create index if not exists product_variants_product_idx on public.product_variants(product_id, active, sort_order);
create index if not exists addons_store_idx on public.addons(store_id, active);
create index if not exists orders_store_created_idx on public.orders(store_id, created_at desc);
create unique index if not exists orders_order_number_uidx on public.orders(order_number);
create index if not exists order_items_order_idx on public.order_items(order_id);
create index if not exists store_users_user_idx on public.store_users(user_id, active);

-- updated_at
DO $$
declare t text;
begin
  foreach t in array array['stores','store_users','categories','products','product_variants','addons','plans','store_subscriptions','orders']
  loop
    execute format('drop trigger if exists %I_set_updated_at on public.%I', t, t);
    execute format('create trigger %I_set_updated_at before update on public.%I for each row execute function public.set_updated_at()', t, t);
  end loop;
end $$;

-- Funções de autorização. SECURITY DEFINER evita recursão de RLS em store_users.
create or replace function public.is_store_member(p_store_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.store_users su
    where su.store_id = p_store_id
      and su.user_id = auth.uid()
      and su.active
  );
$$;

create or replace function public.is_store_admin(p_store_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.store_users su
    where su.store_id = p_store_id
      and su.user_id = auth.uid()
      and su.active
      and su.role in ('owner','admin')
  );
$$;

revoke all on function public.is_store_member(uuid) from public;
revoke all on function public.is_store_admin(uuid) from public;
grant execute on function public.is_store_member(uuid) to anon, authenticated;
grant execute on function public.is_store_admin(uuid) to anon, authenticated;


-- Integridade multi-tenant: categoria e adicionais precisam pertencer à mesma loja do produto.
create or replace function public.enforce_product_category_store()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (
    select 1 from public.categories c
    where c.id = new.category_id and c.store_id = new.store_id
  ) then
    raise exception 'A categoria não pertence à mesma floricultura do produto.' using errcode = '23514';
  end if;
  return new;
end;
$$;

drop trigger if exists products_category_store_trg on public.products;
create trigger products_category_store_trg
before insert or update of store_id, category_id on public.products
for each row execute function public.enforce_product_category_store();

create or replace function public.enforce_product_addon_store()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (
    select 1
    from public.products p
    join public.addons a on a.id = new.addon_id
    where p.id = new.product_id and p.store_id = a.store_id
  ) then
    raise exception 'Produto e adicional pertencem a floriculturas diferentes.' using errcode = '23514';
  end if;
  return new;
end;
$$;

drop trigger if exists product_addons_same_store_trg on public.product_addons;
create trigger product_addons_same_store_trg
before insert or update on public.product_addons
for each row execute function public.enforce_product_addon_store();

-- Uma variação pode reduzir o preço, mas nunca tornar o valor final negativo.
create or replace function public.enforce_variant_final_price()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_base numeric(12,2);
begin
  select coalesce(promotional_price,price) into v_base from public.products where id=new.product_id;
  if v_base is null then raise exception 'Produto da variação não encontrado.'; end if;
  if v_base + new.price_delta < 0 then
    raise exception 'A variação não pode deixar o preço final negativo.' using errcode = '23514';
  end if;
  return new;
end;
$$;

drop trigger if exists product_variants_final_price_trg on public.product_variants;
create trigger product_variants_final_price_trg
before insert or update of product_id, price_delta on public.product_variants
for each row execute function public.enforce_variant_final_price();

create or replace function public.enforce_product_price_against_variants()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if exists (
    select 1 from public.product_variants pv
    where pv.product_id=new.id
      and coalesce(new.promotional_price,new.price) + pv.price_delta < 0
  ) then
    raise exception 'O novo preço deixa uma variação com valor final negativo.' using errcode = '23514';
  end if;
  return new;
end;
$$;

drop trigger if exists products_price_variants_trg on public.products;
create trigger products_price_variants_trg
before update of price, promotional_price on public.products
for each row execute function public.enforce_product_price_against_variants();

-- Limite de produtos ATIVOS por plano. Cadastros ocultos não consomem limite.
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
  if not new.active then
    return new;
  end if;

  -- Upserts de produtos existentes executam BEFORE INSERT antes do conflito.
  -- Liberamos esse passo; a fase UPDATE fará a validação quando necessário.
  if tg_op = 'INSERT' and exists (select 1 from public.products where id = new.id) then
    return new;
  end if;

  -- Atualizações que já estavam ativas não consomem uma nova vaga.
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
    select product_limit into v_limit from public.plans where code = 'DEMO' and active limit 1;
  end if;
  if v_limit is null then return new; end if;

  select count(*) into v_count
  from public.products
  where store_id = new.store_id
    and active
    and id <> new.id;

  if v_count >= v_limit then
    raise exception 'Limite de produtos ativos do plano atingido (%). Desative um produto antes de publicar outro.', v_limit using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists products_plan_limit_trg on public.products;
create trigger products_plan_limit_trg
before insert or update of active on public.products
for each row execute function public.enforce_product_plan_limit();

-- Limite de imagens por produto/plano.
create or replace function public.enforce_product_image_plan_limit()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_store_id uuid;
  v_limit integer;
  v_count integer;
begin
  select store_id into v_store_id from public.products where id = new.product_id;
  if v_store_id is null then raise exception 'Produto não encontrado.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(new.product_id::text, 0));

  select p.image_limit_per_product into v_limit
  from public.store_subscriptions ss
  join public.plans p on p.id = ss.plan_id
  where ss.store_id = v_store_id
    and ss.status in ('trial','active')
    and (ss.expires_at is null or ss.expires_at >= now())
  order by ss.started_at desc
  limit 1;

  if not found then
    select image_limit_per_product into v_limit from public.plans where code = 'DEMO' and active limit 1;
  end if;
  if v_limit is null then return new; end if;
  select count(*) into v_count from public.product_images where product_id = new.product_id;
  if v_count >= v_limit then
    raise exception 'Limite de imagens por produto atingido (%).', v_limit using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists product_images_plan_limit_trg on public.product_images;
create trigger product_images_plan_limit_trg
before insert on public.product_images
for each row execute function public.enforce_product_image_plan_limit();

-- RLS
alter table public.stores enable row level security;
alter table public.store_users enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.product_images enable row level security;
alter table public.product_variants enable row level security;
alter table public.addons enable row level security;
alter table public.product_addons enable row level security;
alter table public.plans enable row level security;
alter table public.store_subscriptions enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

-- Limpa policies com nomes conhecidos para migration reaplicável em ambiente de desenvolvimento.
drop policy if exists stores_public_read on public.stores;
drop policy if exists stores_member_read on public.stores;
drop policy if exists stores_admin_update on public.stores;
create policy stores_public_read on public.stores for select to anon, authenticated using (active);
create policy stores_member_read on public.stores for select to authenticated using (public.is_store_member(id));
create policy stores_admin_update on public.stores for update to authenticated using (public.is_store_admin(id)) with check (public.is_store_admin(id));

drop policy if exists store_users_self_read on public.store_users;
drop policy if exists store_users_admin_manage on public.store_users;
create policy store_users_self_read on public.store_users for select to authenticated using (user_id = auth.uid());
create policy store_users_admin_manage on public.store_users for all to authenticated using (public.is_store_admin(store_id)) with check (public.is_store_admin(store_id));

drop policy if exists categories_public_read on public.categories;
drop policy if exists categories_admin_all on public.categories;
create policy categories_public_read on public.categories for select to anon, authenticated using (active and exists(select 1 from public.stores s where s.id=store_id and s.active));
create policy categories_admin_all on public.categories for all to authenticated using (public.is_store_admin(store_id)) with check (public.is_store_admin(store_id));

drop policy if exists products_public_read on public.products;
drop policy if exists products_admin_all on public.products;
create policy products_public_read on public.products for select to anon, authenticated using (
  active
  and exists(select 1 from public.stores s where s.id=store_id and s.active)
  and exists(select 1 from public.categories c where c.id=category_id and c.store_id=store_id and c.active)
);
create policy products_admin_all on public.products for all to authenticated using (public.is_store_admin(store_id)) with check (public.is_store_admin(store_id));

drop policy if exists product_images_public_read on public.product_images;
drop policy if exists product_images_admin_all on public.product_images;
create policy product_images_public_read on public.product_images for select to anon, authenticated using (exists(select 1 from public.products p join public.stores s on s.id=p.store_id where p.id=product_id and p.active and s.active));
create policy product_images_admin_all on public.product_images for all to authenticated using (exists(select 1 from public.products p where p.id=product_id and public.is_store_admin(p.store_id))) with check (exists(select 1 from public.products p where p.id=product_id and public.is_store_admin(p.store_id)));

drop policy if exists product_variants_public_read on public.product_variants;
drop policy if exists product_variants_admin_all on public.product_variants;
create policy product_variants_public_read on public.product_variants for select to anon, authenticated using (active and exists(select 1 from public.products p join public.stores s on s.id=p.store_id where p.id=product_id and p.active and s.active));
create policy product_variants_admin_all on public.product_variants for all to authenticated using (exists(select 1 from public.products p where p.id=product_id and public.is_store_admin(p.store_id))) with check (exists(select 1 from public.products p where p.id=product_id and public.is_store_admin(p.store_id)));

drop policy if exists addons_public_read on public.addons;
drop policy if exists addons_admin_all on public.addons;
create policy addons_public_read on public.addons for select to anon, authenticated using (active and exists(select 1 from public.stores s where s.id=store_id and s.active));
create policy addons_admin_all on public.addons for all to authenticated using (public.is_store_admin(store_id)) with check (public.is_store_admin(store_id));

drop policy if exists product_addons_public_read on public.product_addons;
drop policy if exists product_addons_admin_all on public.product_addons;
create policy product_addons_public_read on public.product_addons for select to anon, authenticated using (exists(select 1 from public.products p join public.stores s on s.id=p.store_id where p.id=product_id and p.active and s.active));
create policy product_addons_admin_all on public.product_addons for all to authenticated using (exists(select 1 from public.products p where p.id=product_id and public.is_store_admin(p.store_id))) with check (exists(select 1 from public.products p where p.id=product_id and public.is_store_admin(p.store_id)));

drop policy if exists plans_authenticated_read on public.plans;
create policy plans_authenticated_read on public.plans for select to authenticated using (active);

drop policy if exists subscriptions_member_read on public.store_subscriptions;
create policy subscriptions_member_read on public.store_subscriptions for select to authenticated using (public.is_store_member(store_id));

drop policy if exists orders_admin_all on public.orders;
create policy orders_admin_all on public.orders for all to authenticated using (public.is_store_admin(store_id)) with check (public.is_store_admin(store_id));

drop policy if exists order_items_admin_all on public.order_items;
create policy order_items_admin_all on public.order_items for all to authenticated using (exists(select 1 from public.orders o where o.id=order_id and public.is_store_admin(o.store_id))) with check (exists(select 1 from public.orders o where o.id=order_id and public.is_store_admin(o.store_id)));

-- RPC pública: registra o pedido sem liberar SELECT de pedidos para anon.
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

-- Storage
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values
  ('product-images','product-images',true,5242880,array['image/jpeg','image/png','image/webp']),
  ('store-assets','store-assets',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=excluded.public,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists floriweb_storage_public_read on storage.objects;
drop policy if exists floriweb_storage_member_insert on storage.objects;
drop policy if exists floriweb_storage_member_update on storage.objects;
drop policy if exists floriweb_storage_member_delete on storage.objects;
create policy floriweb_storage_public_read on storage.objects for select to anon, authenticated using (bucket_id in ('product-images','store-assets'));
create policy floriweb_storage_member_insert on storage.objects for insert to authenticated with check (
  bucket_id in ('product-images','store-assets')
  and (storage.foldername(name))[1]='stores'
  and exists(select 1 from public.store_users su where su.user_id=auth.uid() and su.active and su.role in ('owner','admin') and su.store_id::text=(storage.foldername(name))[2])
);
create policy floriweb_storage_member_update on storage.objects for update to authenticated using (
  bucket_id in ('product-images','store-assets')
  and exists(select 1 from public.store_users su where su.user_id=auth.uid() and su.active and su.role in ('owner','admin') and su.store_id::text=(storage.foldername(name))[2])
) with check (
  bucket_id in ('product-images','store-assets')
  and exists(select 1 from public.store_users su where su.user_id=auth.uid() and su.active and su.role in ('owner','admin') and su.store_id::text=(storage.foldername(name))[2])
);
create policy floriweb_storage_member_delete on storage.objects for delete to authenticated using (
  bucket_id in ('product-images','store-assets')
  and exists(select 1 from public.store_users su where su.user_id=auth.uid() and su.active and su.role in ('owner','admin') and su.store_id::text=(storage.foldername(name))[2])
);
