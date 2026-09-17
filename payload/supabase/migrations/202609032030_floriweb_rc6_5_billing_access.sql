-- FloriWeb V3 RC6.5
-- 1) Admin Master pode negar renovacao/alteracao sem mover o vencimento.
-- 2) Vencimento respeita due_day (1..28) e nunca passa a seguir a data de pagamento atrasado.
-- 3) Painel do lojista recebe status da mensalidade e detalhes do ultimo pagamento.
-- 4) Dashboard Master recebe dia/proximo vencimento e motivo de negacao.
-- 5) Incremental sobre RC6.3/RC6.4. Nao altera objetos food_*.

begin;

do $$
begin
  if to_regclass('public.store_subscriptions') is null
     or to_regclass('public.subscription_payments') is null
     or to_regclass('public.platform_settings') is null then
    raise exception 'RC6.5 requer as migrations comerciais RC6.x do FloriWeb.';
  end if;
end $$;

alter table public.subscription_payments
  add column if not exists rejected_at timestamptz,
  add column if not exists rejection_reason text,
  add column if not exists reviewed_by uuid references auth.users(id) on delete set null;

alter table public.subscription_payments
  drop constraint if exists subscription_payments_status_check;

alter table public.subscription_payments
  add constraint subscription_payments_status_check
  check(status in('pending','proof_sent','paid','cancelled','rejected'));

comment on column public.subscription_payments.rejected_at is
  'Data/hora em que o Admin Master marcou a cobranca como nao renovada/negada.';
comment on column public.subscription_payments.rejection_reason is
  'Motivo interno/operacional informado pelo Admin Master ao negar a cobranca.';

-- Retorna a data de vencimento coerente com o dia definido pelo Admin Master.
-- Se ja existir uma referencia, preserva o MES/ANO e apenas corrige o dia.
-- Sem referencia, aponta para a proxima ocorrencia do due_day (hoje conta como em dia).
create or replace function public.subscription_reference_due_v1(
  p_due_day integer,
  p_reference date default null
)
returns date
language plpgsql
stable
set search_path=public,pg_temp
as $$
declare
  v_day integer := greatest(1,least(coalesce(p_due_day,10),28));
  v_due date;
begin
  if p_reference is not null then
    return make_date(
      extract(year from p_reference)::integer,
      extract(month from p_reference)::integer,
      v_day
    );
  end if;

  v_due := make_date(
    extract(year from current_date)::integer,
    extract(month from current_date)::integer,
    v_day
  );

  if v_due < current_date then
    v_due := (v_due + interval '1 month')::date;
  end if;

  return v_due;
end $$;

revoke all on function public.subscription_reference_due_v1(integer,date) from public;
grant execute on function public.subscription_reference_due_v1(integer,date) to authenticated;

-- Corrige assinaturas pagas existentes que ficaram com dia diferente de due_day
-- por causa da regra antiga baseada em current_date + 1 month.
update public.store_subscriptions ss
set due_day = coalesce(ss.due_day,10),
    next_due_date = public.subscription_reference_due_v1(
      coalesce(ss.due_day,10),
      ss.next_due_date
    )
from public.plans p
where p.id=ss.plan_id
  and p.code<>'DEMO'
  and ss.status<>'cancelled'
  and (
    ss.due_day is null
    or ss.next_due_date is null
    or extract(day from ss.next_due_date)::integer<>coalesce(ss.due_day,10)
  );

create or replace function public.get_store_billing_overview_v1(p_store_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=public,pg_temp
as $$
declare
  v_sub public.store_subscriptions%rowtype;
  v_plan public.plans%rowtype;
  v_state text := 'none';
  v_days_overdue integer := 0;
  v_last_paid jsonb := null;
begin
  if not (public.is_store_admin(p_store_id) or public.is_platform_admin()) then
    raise exception 'Acesso negado.' using errcode='42501';
  end if;

  select ss.* into v_sub
  from public.store_subscriptions ss
  where ss.store_id=p_store_id
  order by ss.started_at desc
  limit 1;

  if v_sub.id is not null then
    select p.* into v_plan from public.plans p where p.id=v_sub.plan_id;

    if v_plan.code='DEMO' or v_sub.status='trial' then
      v_state := 'trial';
    elsif v_sub.status='suspended' then
      v_state := 'suspended';
    elsif v_sub.status='cancelled' then
      v_state := 'cancelled';
    elsif v_sub.next_due_date is not null and v_sub.next_due_date < current_date then
      v_state := 'overdue';
      v_days_overdue := current_date-v_sub.next_due_date;
    else
      v_state := 'current';
    end if;
  end if;

  select jsonb_build_object(
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
    'rejectedAt',sp.rejected_at,
    'rejectionReason',sp.rejection_reason,
    'createdAt',sp.created_at,
    'planName',p.name,
    'previousPlanName',pp.name,
    'requestedPlanName',rp.name
  ) into v_last_paid
  from public.subscription_payments sp
  join public.plans p on p.id=sp.plan_id
  left join public.plans pp on pp.id=sp.previous_plan_id
  left join public.plans rp on rp.id=sp.requested_plan_id
  where sp.store_id=p_store_id
    and sp.status='paid'
  order by sp.paid_at desc nulls last,sp.created_at desc
  limit 1;

  return jsonb_build_object(
    'currentPlan',case when v_plan.id is null then null else jsonb_build_object(
      'id',v_plan.id,
      'code',v_plan.code,
      'name',v_plan.name,
      'monthlyPrice',v_plan.monthly_price
    ) end,
    'subscription',case when v_sub.id is null then null else jsonb_build_object(
      'id',v_sub.id,
      'status',v_sub.status,
      'billingAmount',coalesce(v_sub.billing_amount,v_plan.monthly_price,0),
      'dueDay',v_sub.due_day,
      'nextDueDate',v_sub.next_due_date,
      'billingState',v_state,
      'daysOverdue',v_days_overdue,
      'lastPayment',v_last_paid
    ) end,
    'plans',coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id',p.id,
          'code',p.code,
          'name',p.name,
          'monthlyPrice',p.monthly_price
        ) order by p.sort_order
      )
      from public.plans p
      where p.active and p.code<>'DEMO'
    ),'[]'::jsonb),
    'settings',(
      select jsonb_build_object(
        'pixKeyType',ps.billing_pix_key_type,
        'pixKey',ps.billing_pix_key,
        'pixHolderName',ps.billing_pix_holder_name,
        'pixCity',ps.billing_pix_city,
        'pixCopyPaste',ps.billing_pix_copy_paste,
        'whatsapp',ps.billing_whatsapp,
        'marketingWhatsapp',coalesce(ps.marketing_whatsapp,''),
        'supportWhatsapp',coalesce(ps.support_whatsapp,''),
        'proofRequired',ps.billing_proof_required,
        'graceDays',ps.billing_grace_days
      )
      from public.platform_settings ps
      where ps.id=1
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
          'rejectedAt',sp.rejected_at,
          'rejectionReason',sp.rejection_reason,
          'createdAt',sp.created_at,
          'planName',p.name,
          'previousPlanName',pp.name,
          'requestedPlanName',rp.name
        ) order by sp.created_at desc
      )
      from public.subscription_payments sp
      join public.plans p on p.id=sp.plan_id
      left join public.plans pp on pp.id=sp.previous_plan_id
      left join public.plans rp on rp.id=sp.requested_plan_id
      where sp.store_id=p_store_id
    ),'[]'::jsonb)
  );
end $$;

revoke all on function public.get_store_billing_overview_v1(uuid) from public;
grant execute on function public.get_store_billing_overview_v1(uuid) to authenticated;

create or replace function public.create_manual_subscription_charge_v1(
  p_store_id uuid,
  p_plan_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_plan public.plans%rowtype;
  v_sub public.store_subscriptions%rowtype;
  v_proof boolean;
  v_due date;
begin
  if not public.is_store_admin(p_store_id) then
    raise exception 'Acesso negado.' using errcode='42501';
  end if;

  select * into v_plan
  from public.plans
  where id=p_plan_id and active and code<>'DEMO';
  if not found then raise exception 'Plano inválido.'; end if;

  select * into v_sub
  from public.store_subscriptions
  where store_id=p_store_id
  order by started_at desc
  limit 1;
  if not found then raise exception 'Assinatura da loja não encontrada.'; end if;

  if exists(
    select 1 from public.subscription_payments
    where store_id=p_store_id and status='proof_sent'
  ) then
    raise exception 'Já existe um comprovante aguardando análise do Admin Master.';
  end if;

  select billing_proof_required into v_proof
  from public.platform_settings
  where id=1;

  update public.subscription_payments
  set status='cancelled'
  where store_id=p_store_id and status='pending';

  v_due := public.subscription_reference_due_v1(
    coalesce(v_sub.due_day,10),
    v_sub.next_due_date
  );

  insert into public.subscription_payments(
    store_id,subscription_id,plan_id,previous_plan_id,requested_plan_id,
    payment_intent,amount,due_date,proof_required
  ) values(
    p_store_id,v_sub.id,p_plan_id,v_sub.plan_id,p_plan_id,
    case when v_sub.plan_id=p_plan_id then 'renewal' else 'plan_change' end,
    v_plan.monthly_price,v_due,coalesce(v_proof,true)
  );

  return public.get_store_billing_overview_v1(p_store_id);
end $$;

revoke all on function public.create_manual_subscription_charge_v1(uuid,uuid) from public;
grant execute on function public.create_manual_subscription_charge_v1(uuid,uuid) to authenticated;

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
          'rejectedAt',sp.rejected_at,
          'rejectionReason',sp.rejection_reason,
          'createdAt',sp.created_at,
          'storeName',s.name,
          'planName',p.name,
          'previousPlanName',pp.name,
          'requestedPlanName',rp.name,
          'dueDay',ss.due_day,
          'nextDueDate',ss.next_due_date,
          'billingState',case
            when pl.code='DEMO' or ss.status='trial' then 'trial'
            when ss.status='suspended' then 'suspended'
            when ss.next_due_date is not null and ss.next_due_date<current_date then 'overdue'
            else 'current'
          end
        ) order by sp.created_at desc
      )
      from public.subscription_payments sp
      join public.stores s on s.id=sp.store_id
      join public.plans p on p.id=sp.plan_id
      left join public.plans pp on pp.id=sp.previous_plan_id
      left join public.plans rp on rp.id=sp.requested_plan_id
      left join lateral (
        select x.* from public.store_subscriptions x
        where x.store_id=sp.store_id
        order by x.started_at desc
        limit 1
      ) ss on true
      left join public.plans pl on pl.id=ss.plan_id
    ),'[]'::jsonb)
  );
end $$;

revoke all on function public.platform_get_billing_dashboard_v1() from public;
grant execute on function public.platform_get_billing_dashboard_v1() to authenticated;

create or replace function public.platform_reject_subscription_payment_v1(
  p_payment_id uuid,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_payment public.subscription_payments%rowtype;
  v_reason text;
begin
  if not public.is_platform_admin() then
    raise exception 'Acesso negado.' using errcode='42501';
  end if;

  select * into v_payment
  from public.subscription_payments
  where id=p_payment_id
  for update;

  if not found then raise exception 'Cobrança não encontrada.'; end if;
  if v_payment.status='paid' then raise exception 'Pagamento já confirmado não pode ser negado.'; end if;
  if v_payment.status in('cancelled','rejected') then
    return jsonb_build_object('ok',true,'alreadyRejected',true);
  end if;

  v_reason := nullif(trim(coalesce(p_reason,'')),'');

  update public.subscription_payments
  set status='rejected',
      rejected_at=now(),
      rejection_reason=coalesce(v_reason,'Pagamento/renovação não confirmado pelo Admin Master.'),
      reviewed_by=auth.uid()
  where id=p_payment_id;

  -- Importante: não muda next_due_date. Se a data vencer, o painel do lojista
  -- ficará vermelho até que uma mensalidade válida seja confirmada.
  return jsonb_build_object('ok',true);
end $$;

revoke all on function public.platform_reject_subscription_payment_v1(uuid,text) from public;
grant execute on function public.platform_reject_subscription_payment_v1(uuid,text) to authenticated;

create or replace function public.platform_confirm_subscription_payment_v1(p_payment_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  pmt public.subscription_payments%rowtype;
  sub public.store_subscriptions%rowtype;
  v_reference_due date;
  v_next_due date;
begin
  if not public.is_platform_admin() then
    raise exception 'Acesso negado.' using errcode='42501';
  end if;

  select * into pmt
  from public.subscription_payments
  where id=p_payment_id
  for update;

  if not found then raise exception 'Cobrança não encontrada.'; end if;
  if pmt.status='paid' then return jsonb_build_object('ok',true,'alreadyPaid',true); end if;
  if pmt.status in('rejected','cancelled') then raise exception 'Esta cobrança foi negada/cancelada e não pode ser confirmada.'; end if;
  if pmt.proof_required and pmt.status<>'proof_sent' then
    raise exception 'O comprovante ainda não foi informado.';
  end if;

  select * into sub
  from public.store_subscriptions
  where store_id=pmt.store_id
  order by started_at desc
  limit 1
  for update;

  if not found then raise exception 'Assinatura da loja não encontrada.'; end if;

  -- A referencia e a data de vencimento da cobranca, alinhada ao due_day.
  -- Pagamento atrasado NÃO desloca o vencimento para o dia em que foi pago.
  v_reference_due := public.subscription_reference_due_v1(
    coalesce(sub.due_day,extract(day from pmt.due_date)::integer,10),
    coalesce(pmt.due_date,sub.next_due_date,current_date)
  );
  v_next_due := (v_reference_due + interval '1 month')::date;

  update public.store_subscriptions
  set plan_id=pmt.requested_plan_id,
      billing_amount=pmt.amount,
      status='active',
      status_before_suspension=null,
      expires_at=null,
      due_day=coalesce(due_day,extract(day from v_reference_due)::integer),
      next_due_date=v_next_due,
      notes=concat_ws(E'\n',notes,
        'Pagamento PIX confirmado em '||to_char(now(),'DD/MM/YYYY HH24:MI')||
        ' | referência '||to_char(v_reference_due,'DD/MM/YYYY')||
        ' | próximo vencimento '||to_char(v_next_due,'DD/MM/YYYY')
      )
  where id=sub.id;

  update public.stores
  set access_status='online',active=true,suspended_at=null,suspension_reason=null
  where id=pmt.store_id;

  update public.subscription_payments
  set status='paid',
      paid_at=now(),
      rejected_at=null,
      rejection_reason=null,
      reviewed_by=auth.uid(),
      due_date=v_reference_due
  where id=pmt.id;

  return jsonb_build_object(
    'ok',true,
    'paidAt',now(),
    'referenceDueDate',v_reference_due,
    'nextDueDate',v_next_due
  );
end $$;

revoke all on function public.platform_confirm_subscription_payment_v1(uuid) from public;
grant execute on function public.platform_confirm_subscription_payment_v1(uuid) to authenticated;

notify pgrst,'reload schema';
commit;
