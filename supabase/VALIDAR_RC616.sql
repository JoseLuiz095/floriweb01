-- FloriWeb RC6.16 - validacao de visual por emoji
select
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='products' and column_name='visual_emoji') as products_visual_emoji_ok,
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='addons' and column_name='visual_emoji') as addons_visual_emoji_ok,
  position('visual_emoji' in pg_get_functiondef('public.get_public_storefront_v3(text,text)'::regprocedure)) > 0 as storefront_rpc_visual_emoji_ok;
