-- FloriWeb V3 RC6.2
-- 1) WhatsApp comercial e de suporte configuráveis no Admin Master.
-- 2) Landing comercial publica somente os contatos necessários para CTA/Ajuda.
-- 3) Home da plataforma usa a loja Demo, planos e período Demo reais.
-- 4) Plano DEMO herda a experiência funcional do PRO para o teste comercial.
-- Incremental sobre RC6.1. Nao altera tabelas food_*.

begin;

do $$
begin
  if to_regclass('public.platform_settings') is null
     or to_regclass('public.plans') is null
     or to_regclass('public.stores') is null then
    raise exception 'RC6.2 requer a estrutura FloriWeb existente.';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='platform_settings' and column_name='billing_whatsapp'
  ) then
    raise exception 'Aplique primeiro a migration RC6.1 de mensalidade PIX e Financeiro.';
  end if;
end $$;

alter table public.platform_settings
  add column if not exists marketing_whatsapp text,
  add column if not exists support_whatsapp text;

comment on column public.platform_settings.marketing_whatsapp is
  'WhatsApp comercial usado pelos CTAs da landing FloriWeb.';
comment on column public.platform_settings.support_whatsapp is
  'WhatsApp usado pelo botão público Ajuda. Se vazio, o frontend usa o comercial.';

-- O teste comercial deve representar o Profissional. Mantém o preço do DEMO em zero
-- e replica somente capacidades/limites do PRO quando ambos existem.
do $$
begin
  update public.plans demo
  set product_limit = pro.product_limit,
      image_limit_per_product = pro.image_limit_per_product,
      custom_domain = pro.custom_domain,
      reports = pro.reports,
      priority_support = pro.priority_support,
      category_limit = pro.category_limit,
      addon_limit = pro.addon_limit,
      admin_user_limit = pro.admin_user_limit,
      updated_at = now()
  from public.plans pro
  where demo.code='DEMO'
    and pro.code='PRO';
end $$;

create or replace function public.get_public_landing_v1()
returns jsonb
language sql
stable
security definer
set search_path=public,pg_temp
as $$
  select jsonb_build_object(
    'demo_store_slug', coalesce(
      (
        select s.slug
        from public.stores s
        where s.archived_at is null
          and s.active
          and s.access_status='online'
          and public.store_accessible(s.id)
        order by (s.slug='floriweb-demo') desc, s.created_at asc
        limit 1
      ),
      'floriweb-demo'
    ),
    'demo_enabled', coalesce(
      (select ps.demo_enabled from public.platform_settings ps where ps.id=1),
      true
    ),
    'demo_duration_days', coalesce(
      (select ps.demo_duration_days from public.platform_settings ps where ps.id=1),
      30
    ),
    'marketing_whatsapp', coalesce(
      (select regexp_replace(coalesce(ps.marketing_whatsapp,''),'\D','','g') from public.platform_settings ps where ps.id=1),
      ''
    ),
    'support_whatsapp', coalesce(
      (
        select regexp_replace(
          coalesce(nullif(ps.support_whatsapp,''),nullif(ps.marketing_whatsapp,''),''),
          '\D','','g'
        )
        from public.platform_settings ps
        where ps.id=1
      ),
      ''
    ),
    'stores', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id',s.id,
          'slug',s.slug,
          'name',s.name,
          'description',s.description,
          'logo_url',s.logo_url,
          'hero_url',s.cover_url,
          'city',s.city,
          'state',s.state
        )
        order by s.created_at desc
      )
      from public.stores s
      where s.archived_at is null
        and s.active
        and s.access_status='online'
        and public.store_accessible(s.id)
    ),'[]'::jsonb),
    'plans', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id',p.id,
          'code',p.code,
          'name',p.name,
          'monthly_price',p.monthly_price
        )
        order by p.sort_order,p.monthly_price,p.name
      )
      from public.plans p
      where p.active
        and p.code<>'DEMO'
    ),'[]'::jsonb)
  );
$$;

revoke all on function public.get_public_landing_v1() from public;
grant execute on function public.get_public_landing_v1() to anon,authenticated;

-- O dashboard Master ganha os contatos comercial e de suporte.
create or replace function public.platform_get_billing_dashboard_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path=public,pg_temp
as $$
begin
  if not public.is_platform_admin() then
    raise exception 'Acesso negado.' using errcode='42501';
  end if;

  return jsonb_build_object(
    'settings',(
      select jsonb_build_object(
        'pixKeyType',billing_pix_key_type,
        'pixKey',billing_pix_key,
        'pixHolderName',billing_pix_holder_name,
        'pixCity',billing_pix_city,
        'pixCopyPaste',billing_pix_copy_paste,
        'whatsapp',billing_whatsapp,
        'marketingWhatsapp',coalesce(marketing_whatsapp,''),
        'supportWhatsapp',coalesce(support_whatsapp,''),
        'proofRequired',billing_proof_required,
        'graceDays',billing_grace_days
      )
      from public.platform_settings
      where id=1
    ),
    'payments',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id',sp.id,
          'storeId',sp.store_id,
          'planId',sp.plan_id,
          'previousPlanId',sp.previous_plan_id,
          'requestedPlanId',sp.requested_plan_id,
          'paymentIntent',sp.payment_intent,
          'amount',sp.amount,
          'dueDate',sp.due_date,
          'status',sp.status,
          'proofRequired',sp.proof_required,
          'proofSentAt',sp.proof_sent_at,
          'paidAt',sp.paid_at,
          'createdAt',sp.created_at,
          'storeName',s.name,
          'planName',p.name,
          'previousPlanName',pp.name,
          'requestedPlanName',rp.name
        )
        order by sp.created_at desc
      )
      from public.subscription_payments sp
      join public.stores s on s.id=sp.store_id
      join public.plans p on p.id=sp.plan_id
      left join public.plans pp on pp.id=sp.previous_plan_id
      left join public.plans rp on rp.id=sp.requested_plan_id
    ),'[]'::jsonb)
  );
end $$;

revoke all on function public.platform_get_billing_dashboard_v1() from public;
grant execute on function public.platform_get_billing_dashboard_v1() to authenticated;

-- V2 preserva a RPC V1 para clientes antigos e adiciona os novos contatos.
create or replace function public.platform_update_billing_settings_v2(
  p_pix_key_type text,
  p_pix_key text,
  p_pix_holder_name text,
  p_pix_city text,
  p_pix_copy_paste text,
  p_whatsapp text,
  p_marketing_whatsapp text,
  p_support_whatsapp text,
  p_proof_required boolean,
  p_grace_days integer
)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
begin
  if not public.is_platform_admin() then
    raise exception 'Acesso negado.' using errcode='42501';
  end if;

  update public.platform_settings
  set billing_pix_key_type=coalesce(nullif(trim(p_pix_key_type),''),'cnpj'),
      billing_pix_key=trim(coalesce(p_pix_key,'')),
      billing_pix_holder_name=trim(coalesce(p_pix_holder_name,'')),
      billing_pix_city=trim(coalesce(p_pix_city,'')),
      billing_pix_copy_paste=trim(coalesce(p_pix_copy_paste,'')),
      billing_whatsapp=regexp_replace(coalesce(p_whatsapp,''),'\D','','g'),
      marketing_whatsapp=regexp_replace(coalesce(p_marketing_whatsapp,''),'\D','','g'),
      support_whatsapp=regexp_replace(coalesce(p_support_whatsapp,''),'\D','','g'),
      billing_proof_required=coalesce(p_proof_required,true),
      billing_grace_days=greatest(0,least(coalesce(p_grace_days,3),30)),
      updated_at=now()
  where id=1;

  return (
    select jsonb_build_object(
      'pixKeyType',billing_pix_key_type,
      'pixKey',billing_pix_key,
      'pixHolderName',billing_pix_holder_name,
      'pixCity',billing_pix_city,
      'pixCopyPaste',billing_pix_copy_paste,
      'whatsapp',billing_whatsapp,
      'marketingWhatsapp',coalesce(marketing_whatsapp,''),
      'supportWhatsapp',coalesce(support_whatsapp,''),
      'proofRequired',billing_proof_required,
      'graceDays',billing_grace_days
    )
    from public.platform_settings
    where id=1
  );
end $$;

revoke all on function public.platform_update_billing_settings_v2(text,text,text,text,text,text,text,text,boolean,integer) from public;
grant execute on function public.platform_update_billing_settings_v2(text,text,text,text,text,text,text,text,boolean,integer) to authenticated;

notify pgrst,'reload schema';
commit;
