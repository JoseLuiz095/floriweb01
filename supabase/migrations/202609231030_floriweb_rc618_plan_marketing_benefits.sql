-- FloriWeb RC6.18 - beneficios comerciais editaveis por plano
begin;
alter table public.plans add column if not exists marketing_benefits text[] not null default '{}'::text[];
create or replace function public.get_public_landing_v1() returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
  select jsonb_build_object(
    'demo_store_slug',coalesce((select s.slug from public.stores s where s.archived_at is null and s.active and s.access_status='online' and public.store_accessible(s.id) order by (s.slug='floriweb-demo') desc,s.created_at asc limit 1),'floriweb-demo'),
    'demo_enabled',coalesce((select ps.demo_enabled from public.platform_settings ps where ps.id=1),true),
    'demo_duration_days',coalesce((select ps.demo_duration_days from public.platform_settings ps where ps.id=1),14),
    'contact_protected',true,
    'stores',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'slug',s.slug,'name',s.name,'description',s.description,'logo_url',s.logo_url,'hero_url',s.cover_url,'city',s.city,'state',s.state) order by s.created_at desc) from public.stores s where s.archived_at is null and s.active and s.access_status='online' and public.store_accessible(s.id)),'[]'::jsonb),
    'plans',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'code',p.code,'name',p.name,'monthly_price',p.monthly_price,'product_limit',p.product_limit,'image_limit_per_product',p.image_limit_per_product,'category_limit',p.category_limit,'addon_limit',p.addon_limit,'custom_domain',p.custom_domain,'reports',p.reports,'priority_support',p.priority_support,'marketing_benefits',coalesce(p.marketing_benefits,'{}'::text[])) order by p.sort_order,p.monthly_price,p.name) from public.plans p where p.active and p.code<>'DEMO'),'[]'::jsonb)
  );
$$;
revoke all on function public.get_public_landing_v1() from public;
grant execute on function public.get_public_landing_v1() to anon,authenticated;
notify pgrst,'reload schema';
commit;
