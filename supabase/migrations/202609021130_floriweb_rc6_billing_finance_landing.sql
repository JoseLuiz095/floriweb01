-- FloriWeb V3 RC6.1 - landing comercial + mensalidade PIX manual + financeiro gerencial
-- Correcao RC6.1: public.stores usa cover_url; a chave JSON publica continua hero_url para compatibilidade com o frontend.
-- Incremental sobre RC5.2. Nao altera tabelas food_*.
begin;

alter table public.platform_settings
  add column if not exists billing_pix_key_type text not null default 'cnpj',
  add column if not exists billing_pix_key text not null default '',
  add column if not exists billing_pix_holder_name text not null default '',
  add column if not exists billing_pix_city text not null default 'Linhares',
  add column if not exists billing_pix_copy_paste text not null default '',
  add column if not exists billing_whatsapp text not null default '',
  add column if not exists billing_proof_required boolean not null default true,
  add column if not exists billing_grace_days integer not null default 3;

create table if not exists public.subscription_payments(
 id uuid primary key default gen_random_uuid(),
 store_id uuid not null references public.stores(id) on delete cascade,
 subscription_id uuid references public.store_subscriptions(id) on delete set null,
 plan_id uuid not null references public.plans(id),
 previous_plan_id uuid references public.plans(id),
 requested_plan_id uuid references public.plans(id),
 payment_intent text not null default 'renewal' check(payment_intent in('renewal','plan_change')),
 amount numeric(12,2) not null check(amount>0), due_date date not null default current_date,
 status text not null default 'pending' check(status in('pending','proof_sent','paid','cancelled')),
 proof_required boolean not null default true, proof_sent_at timestamptz, paid_at timestamptz,
 created_by uuid default auth.uid(), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index if not exists subscription_payments_store_created_idx on public.subscription_payments(store_id,created_at desc);
create unique index if not exists subscription_payments_one_pending_idx on public.subscription_payments(store_id) where status in('pending','proof_sent');

drop trigger if exists subscription_payments_set_updated_at on public.subscription_payments;
create trigger subscription_payments_set_updated_at before update on public.subscription_payments for each row execute function public.set_updated_at();

create table if not exists public.financial_entries(
 id uuid primary key default gen_random_uuid(), store_id uuid not null references public.stores(id) on delete cascade,
 direction text not null check(direction in('income','expense')), description text not null, category text not null,
 amount numeric(12,2) not null check(amount>0), occurred_on date not null default current_date, due_on date,
 status text not null default 'paid' check(status in('pending','paid','cancelled')), counterparty text,
 document_type text not null default 'none', document_number text, notes text, created_by uuid default auth.uid(),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index if not exists financial_entries_store_date_idx on public.financial_entries(store_id,occurred_on desc);
drop trigger if exists financial_entries_set_updated_at on public.financial_entries;
create trigger financial_entries_set_updated_at before update on public.financial_entries for each row execute function public.set_updated_at();

create table if not exists public.financial_documents(
 id uuid primary key default gen_random_uuid(), store_id uuid not null references public.stores(id) on delete cascade,
 entry_id uuid references public.financial_entries(id) on delete set null, storage_path text not null unique, original_name text not null,
 mime_type text, extraction_status text not null default 'pending' check(extraction_status in('pending','processed','failed','manual')),
 extracted_json jsonb, confidence numeric(5,4), created_by uuid default auth.uid(), created_at timestamptz not null default now()
);

create or replace function public.store_finance_enabled(p_store_id uuid) returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select public.is_platform_admin() or exists(select 1 from public.store_subscriptions ss join public.plans p on p.id=ss.plan_id where ss.store_id=p_store_id and ss.status in('trial','active') and (ss.expires_at is null or ss.expires_at>=now()) and p.code in('DEMO','PRO','PREMIUM'));
$$;
revoke all on function public.store_finance_enabled(uuid) from public; grant execute on function public.store_finance_enabled(uuid) to authenticated;

alter table public.subscription_payments enable row level security;
alter table public.financial_entries enable row level security;
alter table public.financial_documents enable row level security;
drop policy if exists subscription_payments_store_select on public.subscription_payments;
create policy subscription_payments_store_select on public.subscription_payments for select to authenticated using(public.is_platform_admin() or public.is_store_admin(store_id));
drop policy if exists financial_entries_store_all on public.financial_entries;
create policy financial_entries_store_all on public.financial_entries for all to authenticated using((public.is_store_admin(store_id) and public.store_finance_enabled(store_id)) or public.is_platform_admin()) with check((public.is_store_admin(store_id) and public.store_finance_enabled(store_id)) or public.is_platform_admin());
drop policy if exists financial_documents_store_all on public.financial_documents;
create policy financial_documents_store_all on public.financial_documents for all to authenticated using((public.is_store_admin(store_id) and public.store_finance_enabled(store_id)) or public.is_platform_admin()) with check((public.is_store_admin(store_id) and public.store_finance_enabled(store_id)) or public.is_platform_admin());

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('flori-finance-documents','flori-finance-documents',false,10485760,array['image/jpeg','image/png','image/webp','application/pdf']) on conflict(id) do update set public=false,file_size_limit=10485760,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists flori_finance_storage_select on storage.objects;
create policy flori_finance_storage_select on storage.objects for select to authenticated using(bucket_id='flori-finance-documents' and exists(select 1 from public.store_users su where su.store_id::text=(storage.foldername(name))[1] and su.user_id=auth.uid() and su.active and public.store_finance_enabled(su.store_id)) or (bucket_id='flori-finance-documents' and public.is_platform_admin()));
drop policy if exists flori_finance_storage_insert on storage.objects;
create policy flori_finance_storage_insert on storage.objects for insert to authenticated with check(bucket_id='flori-finance-documents' and exists(select 1 from public.store_users su where su.store_id::text=(storage.foldername(name))[1] and su.user_id=auth.uid() and su.active and su.role in('owner','admin') and public.store_finance_enabled(su.store_id)));

create or replace function public.get_public_landing_v1() returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select jsonb_build_object('demo_store_slug',coalesce((select s.slug from public.stores s where s.active and s.access_status='online' and public.store_accessible(s.id) order by (s.slug='floriweb-demo') desc,s.created_at asc limit 1),'floriweb-demo'),'stores',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'slug',s.slug,'name',s.name,'description',s.description,'logo_url',s.logo_url,'hero_url',s.cover_url,'city',s.city,'state',s.state) order by s.created_at desc) from public.stores s where s.active and s.access_status='online' and public.store_accessible(s.id)),'[]'::jsonb),'plans',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'code',p.code,'name',p.name,'monthly_price',p.monthly_price) order by p.sort_order,p.monthly_price) from public.plans p where p.active and p.code<>'DEMO'),'[]'::jsonb));
$$;
revoke all on function public.get_public_landing_v1() from public;grant execute on function public.get_public_landing_v1() to anon,authenticated;

create or replace function public.get_store_billing_overview_v1(p_store_id uuid) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$ declare v jsonb; begin
 if not (public.is_store_admin(p_store_id) or public.is_platform_admin()) then raise exception 'Acesso negado.' using errcode='42501'; end if;
 select jsonb_build_object('currentPlan',(select jsonb_build_object('id',p.id,'code',p.code,'name',p.name,'monthlyPrice',p.monthly_price) from public.store_subscriptions ss join public.plans p on p.id=ss.plan_id where ss.store_id=p_store_id order by ss.started_at desc limit 1),'plans',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'code',p.code,'name',p.name,'monthlyPrice',p.monthly_price) order by p.sort_order) from public.plans p where p.active and p.code<>'DEMO'),'[]'::jsonb),'settings',(select jsonb_build_object('pixKeyType',ps.billing_pix_key_type,'pixKey',ps.billing_pix_key,'pixHolderName',ps.billing_pix_holder_name,'pixCity',ps.billing_pix_city,'pixCopyPaste',ps.billing_pix_copy_paste,'whatsapp',ps.billing_whatsapp,'proofRequired',ps.billing_proof_required,'graceDays',ps.billing_grace_days) from public.platform_settings ps where ps.id=1),'payments',coalesce((select jsonb_agg(jsonb_build_object('id',sp.id,'storeId',sp.store_id,'planId',sp.plan_id,'previousPlanId',sp.previous_plan_id,'requestedPlanId',sp.requested_plan_id,'paymentIntent',sp.payment_intent,'amount',sp.amount,'dueDate',sp.due_date,'status',sp.status,'proofRequired',sp.proof_required,'proofSentAt',sp.proof_sent_at,'paidAt',sp.paid_at,'createdAt',sp.created_at) order by sp.created_at desc) from public.subscription_payments sp where sp.store_id=p_store_id),'[]'::jsonb)) into v; return v; end $$;
revoke all on function public.get_store_billing_overview_v1(uuid) from public;grant execute on function public.get_store_billing_overview_v1(uuid) to authenticated;

create or replace function public.create_manual_subscription_charge_v1(p_store_id uuid,p_plan_id uuid) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$ declare v_plan public.plans%rowtype;v_sub public.store_subscriptions%rowtype;v_proof boolean; begin
 if not public.is_store_admin(p_store_id) then raise exception 'Acesso negado.' using errcode='42501'; end if; select * into v_plan from public.plans where id=p_plan_id and active and code<>'DEMO';if not found then raise exception 'Plano inválido.';end if;select * into v_sub from public.store_subscriptions where store_id=p_store_id order by started_at desc limit 1;select billing_proof_required into v_proof from public.platform_settings where id=1;
 delete from public.subscription_payments where store_id=p_store_id and status='pending';
 insert into public.subscription_payments(store_id,subscription_id,plan_id,previous_plan_id,requested_plan_id,payment_intent,amount,due_date,proof_required) values(p_store_id,v_sub.id,p_plan_id,v_sub.plan_id,p_plan_id,case when v_sub.plan_id=p_plan_id then 'renewal' else 'plan_change' end,v_plan.monthly_price,current_date,coalesce(v_proof,true));return public.get_store_billing_overview_v1(p_store_id);end $$;
revoke all on function public.create_manual_subscription_charge_v1(uuid,uuid) from public;grant execute on function public.create_manual_subscription_charge_v1(uuid,uuid) to authenticated;

create or replace function public.mark_subscription_proof_sent_v1(p_payment_id uuid) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$ declare v_store uuid;begin select store_id into v_store from public.subscription_payments where id=p_payment_id;if v_store is null or not public.is_store_admin(v_store) then raise exception 'Acesso negado.' using errcode='42501';end if;update public.subscription_payments set status='proof_sent',proof_sent_at=now() where id=p_payment_id and status='pending';return public.get_store_billing_overview_v1(v_store);end $$;
revoke all on function public.mark_subscription_proof_sent_v1(uuid) from public;grant execute on function public.mark_subscription_proof_sent_v1(uuid) to authenticated;

create or replace function public.platform_get_billing_dashboard_v1() returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$ begin if not public.is_platform_admin() then raise exception 'Acesso negado.' using errcode='42501';end if;return jsonb_build_object('settings',(select jsonb_build_object('pixKeyType',billing_pix_key_type,'pixKey',billing_pix_key,'pixHolderName',billing_pix_holder_name,'pixCity',billing_pix_city,'pixCopyPaste',billing_pix_copy_paste,'whatsapp',billing_whatsapp,'proofRequired',billing_proof_required,'graceDays',billing_grace_days) from public.platform_settings where id=1),'payments',coalesce((select jsonb_agg(jsonb_build_object('id',sp.id,'storeId',sp.store_id,'planId',sp.plan_id,'previousPlanId',sp.previous_plan_id,'requestedPlanId',sp.requested_plan_id,'paymentIntent',sp.payment_intent,'amount',sp.amount,'dueDate',sp.due_date,'status',sp.status,'proofRequired',sp.proof_required,'proofSentAt',sp.proof_sent_at,'paidAt',sp.paid_at,'createdAt',sp.created_at,'storeName',s.name,'planName',p.name,'previousPlanName',pp.name,'requestedPlanName',rp.name) order by sp.created_at desc) from public.subscription_payments sp join public.stores s on s.id=sp.store_id join public.plans p on p.id=sp.plan_id left join public.plans pp on pp.id=sp.previous_plan_id left join public.plans rp on rp.id=sp.requested_plan_id),'[]'::jsonb));end $$;
revoke all on function public.platform_get_billing_dashboard_v1() from public;grant execute on function public.platform_get_billing_dashboard_v1() to authenticated;

create or replace function public.platform_update_billing_settings_v1(p_pix_key_type text,p_pix_key text,p_pix_holder_name text,p_pix_city text,p_pix_copy_paste text,p_whatsapp text,p_proof_required boolean,p_grace_days integer) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$ begin if not public.is_platform_admin() then raise exception 'Acesso negado.' using errcode='42501';end if;update public.platform_settings set billing_pix_key_type=coalesce(nullif(trim(p_pix_key_type),''),'cnpj'),billing_pix_key=trim(coalesce(p_pix_key,'')),billing_pix_holder_name=trim(coalesce(p_pix_holder_name,'')),billing_pix_city=trim(coalesce(p_pix_city,'')),billing_pix_copy_paste=trim(coalesce(p_pix_copy_paste,'')),billing_whatsapp=regexp_replace(coalesce(p_whatsapp,''),'\D','','g'),billing_proof_required=coalesce(p_proof_required,true),billing_grace_days=greatest(0,least(coalesce(p_grace_days,3),30)) where id=1;return (select jsonb_build_object('pixKeyType',billing_pix_key_type,'pixKey',billing_pix_key,'pixHolderName',billing_pix_holder_name,'pixCity',billing_pix_city,'pixCopyPaste',billing_pix_copy_paste,'whatsapp',billing_whatsapp,'proofRequired',billing_proof_required,'graceDays',billing_grace_days) from public.platform_settings where id=1);end $$;
revoke all on function public.platform_update_billing_settings_v1(text,text,text,text,text,text,boolean,integer) from public;grant execute on function public.platform_update_billing_settings_v1(text,text,text,text,text,text,boolean,integer) to authenticated;

create or replace function public.platform_confirm_subscription_payment_v1(p_payment_id uuid) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$ declare pmt public.subscription_payments%rowtype;sub public.store_subscriptions%rowtype;begin if not public.is_platform_admin() then raise exception 'Acesso negado.' using errcode='42501';end if;select * into pmt from public.subscription_payments where id=p_payment_id for update;if not found then raise exception 'Cobrança não encontrada.';end if;if pmt.status='paid' then return jsonb_build_object('ok',true,'alreadyPaid',true);end if;if pmt.proof_required and pmt.status<>'proof_sent' then raise exception 'O comprovante ainda não foi informado.';end if;select * into sub from public.store_subscriptions where store_id=pmt.store_id order by started_at desc limit 1 for update;update public.store_subscriptions set plan_id=pmt.requested_plan_id,billing_amount=pmt.amount,status='active',expires_at=null,next_due_date=greatest(coalesce(next_due_date,current_date),current_date)+interval '1 month',notes=concat_ws(E'\n',notes,'Pagamento PIX confirmado em '||to_char(now(),'DD/MM/YYYY HH24:MI')) where id=sub.id;update public.stores set access_status='online',active=true where id=pmt.store_id;update public.subscription_payments set status='paid',paid_at=now() where id=pmt.id;return jsonb_build_object('ok',true);end $$;
revoke all on function public.platform_confirm_subscription_payment_v1(uuid) from public;grant execute on function public.platform_confirm_subscription_payment_v1(uuid) to authenticated;

create or replace function public.get_store_financial_overview_v1(p_store_id uuid) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$ declare i numeric:=0;e numeric:=0;ar numeric:=0;ap numeric:=0;begin if not public.is_store_admin(p_store_id) then raise exception 'Acesso negado.' using errcode='42501';end if;if not public.store_finance_enabled(p_store_id) then raise exception 'O plano atual não inclui o módulo Financeiro.' using errcode='42501';end if;select coalesce(sum(amount) filter(where direction='income' and status='paid'),0),coalesce(sum(amount) filter(where direction='expense' and status='paid'),0),coalesce(sum(amount) filter(where direction='income' and status='pending'),0),coalesce(sum(amount) filter(where direction='expense' and status='pending'),0) into i,e,ar,ap from public.financial_entries where store_id=p_store_id and status<>'cancelled';return jsonb_build_object('income',i,'expense',e,'result',i-e,'receivable',ar,'payable',ap,'entries',coalesce((select jsonb_agg(jsonb_build_object('id',f.id,'storeId',f.store_id,'direction',f.direction,'description',f.description,'category',f.category,'amount',f.amount,'occurredOn',f.occurred_on,'dueOn',f.due_on,'status',f.status,'counterparty',f.counterparty,'documentType',f.document_type,'documentNumber',f.document_number,'notes',f.notes,'createdAt',f.created_at) order by f.occurred_on desc,f.created_at desc) from (select * from public.financial_entries where store_id=p_store_id and status<>'cancelled' order by occurred_on desc,created_at desc limit 100) f),'[]'::jsonb),'expenseByCategory',coalesce((select jsonb_agg(jsonb_build_object('category',x.category,'amount',x.amount) order by x.amount desc) from (select category,sum(amount) amount from public.financial_entries where store_id=p_store_id and direction='expense' and status='paid' group by category)x),'[]'::jsonb),'monthly',coalesce((select jsonb_agg(jsonb_build_object('month',to_char(m.month_start,'YYYY-MM'),'income',coalesce(x.income,0),'expense',coalesce(x.expense,0)) order by m.month_start) from (select generate_series(date_trunc('month',current_date)-interval '5 months',date_trunc('month',current_date),interval '1 month')::date month_start)m left join (select date_trunc('month',occurred_on)::date month_start,sum(amount) filter(where direction='income' and status='paid') income,sum(amount) filter(where direction='expense' and status='paid') expense from public.financial_entries where store_id=p_store_id and occurred_on>=date_trunc('month',current_date)-interval '5 months' group by 1)x using(month_start)),'[]'::jsonb));end $$;
revoke all on function public.get_store_financial_overview_v1(uuid) from public;grant execute on function public.get_store_financial_overview_v1(uuid) to authenticated;

create or replace function public.create_financial_entry_v1(p_store_id uuid,p_direction text,p_description text,p_category text,p_amount numeric,p_occurred_on date,p_due_on date,p_status text,p_counterparty text,p_document_type text,p_document_number text,p_notes text) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$ declare f public.financial_entries%rowtype;begin if not public.is_store_admin(p_store_id) or not public.store_finance_enabled(p_store_id) then raise exception 'Acesso negado ao Financeiro.' using errcode='42501';end if;if p_direction not in('income','expense') or p_status not in('paid','pending') or p_amount<=0 then raise exception 'Dados financeiros inválidos.';end if;insert into public.financial_entries(store_id,direction,description,category,amount,occurred_on,due_on,status,counterparty,document_type,document_number,notes) values(p_store_id,p_direction,trim(p_description),trim(p_category),p_amount,coalesce(p_occurred_on,current_date),p_due_on,p_status,nullif(trim(p_counterparty),''),coalesce(nullif(trim(p_document_type),''),'none'),nullif(trim(p_document_number),''),nullif(trim(p_notes),'')) returning * into f;return jsonb_build_object('id',f.id,'storeId',f.store_id,'direction',f.direction,'description',f.description,'category',f.category,'amount',f.amount,'occurredOn',f.occurred_on,'dueOn',f.due_on,'status',f.status,'counterparty',f.counterparty,'documentType',f.document_type,'documentNumber',f.document_number,'notes',f.notes,'createdAt',f.created_at);end $$;
revoke all on function public.create_financial_entry_v1(uuid,text,text,text,numeric,date,date,text,text,text,text,text) from public;grant execute on function public.create_financial_entry_v1(uuid,text,text,text,numeric,date,date,text,text,text,text,text) to authenticated;

notify pgrst,'reload schema';commit;
