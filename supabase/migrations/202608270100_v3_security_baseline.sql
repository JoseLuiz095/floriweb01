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
