begin;

-- RC6.8: recebimento do pedido confirmado manualmente e integrado ao Financeiro.
-- O pedido e a entrada financeira sao vinculados para impedir duplicidade.

alter table public.orders
  add column if not exists payment_status text not null default 'pending',
  add column if not exists payment_received_at timestamptz,
  add column if not exists payment_confirmed_by uuid references auth.users(id) on delete set null;

update public.orders set payment_status='pending' where payment_status is null;
alter table public.orders alter column payment_status set default 'pending';
alter table public.orders alter column payment_status set not null;
alter table public.orders drop constraint if exists orders_payment_status_check;
alter table public.orders add constraint orders_payment_status_check check(payment_status in ('pending','paid'));

alter table public.financial_entries
  add column if not exists source text not null default 'manual',
  add column if not exists order_id uuid references public.orders(id) on delete set null,
  add column if not exists paid_at timestamptz,
  add column if not exists payment_method text;

update public.financial_entries set source='manual' where source is null;
alter table public.financial_entries alter column source set default 'manual';
alter table public.financial_entries alter column source set not null;
alter table public.financial_entries drop constraint if exists financial_entries_source_check;
alter table public.financial_entries add constraint financial_entries_source_check check(source in ('manual','order','adjustment'));

create unique index if not exists financial_entries_order_uidx
  on public.financial_entries(store_id,order_id)
  where source='order' and order_id is not null;

create index if not exists orders_store_payment_status_idx
  on public.orders(store_id,payment_status,created_at desc);

create or replace function public.sync_order_financial_entry_v1()
returns trigger
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_received_at timestamptz;
  v_occurred_on date;
begin
  if new.status='cancelled' then
    update public.financial_entries
       set status='cancelled',updated_at=now()
     where store_id=new.store_id
       and order_id=new.id
       and source='order';
    return new;
  end if;

  if new.payment_status='paid' then
    if coalesce(new.total,0)<=0 then
      raise exception 'Pedido sem valor valido para lancamento financeiro.';
    end if;

    v_received_at:=coalesce(new.payment_received_at,now());
    v_occurred_on:=(v_received_at at time zone 'America/Sao_Paulo')::date;

    insert into public.financial_entries(
      store_id,direction,source,order_id,description,category,amount,
      occurred_on,paid_at,status,payment_method,counterparty,
      document_type,document_number,notes,created_by
    ) values(
      new.store_id,'income','order',new.id,
      'Pedido #'||new.order_number,'Vendas',new.total,
      v_occurred_on,v_received_at,'paid',new.payment_method,new.customer_name,
      'none',new.order_number::text,
      'Entrada gerada automaticamente apos confirmacao manual do recebimento do pedido.',
      new.payment_confirmed_by
    )
    on conflict(store_id,order_id) where source='order' and order_id is not null
    do update set
      description=excluded.description,
      category='Vendas',
      amount=excluded.amount,
      occurred_on=excluded.occurred_on,
      paid_at=excluded.paid_at,
      status='paid',
      payment_method=excluded.payment_method,
      counterparty=excluded.counterparty,
      document_number=excluded.document_number,
      notes=excluded.notes,
      updated_at=now();
  end if;

  return new;
end $$;

revoke all on function public.sync_order_financial_entry_v1() from public;

drop trigger if exists orders_financial_receipt_sync_trg on public.orders;
create trigger orders_financial_receipt_sync_trg
after insert or update of payment_status,payment_received_at,total,payment_method,status
on public.orders
for each row execute function public.sync_order_financial_entry_v1();

create or replace function public.confirm_order_payment_v1(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_order public.orders%rowtype;
  v_already_paid boolean;
begin
  select * into v_order
    from public.orders
   where id=p_order_id
   for update;

  if not found then
    raise exception 'Pedido nao encontrado.';
  end if;

  if not public.is_store_admin(v_order.store_id) and not public.is_platform_admin() then
    raise exception 'Acesso negado.' using errcode='42501';
  end if;

  if v_order.status='cancelled' then
    raise exception 'Nao e possivel confirmar o recebimento de um pedido cancelado.';
  end if;

  if coalesce(v_order.total,0)<=0 then
    raise exception 'O pedido nao possui valor valido para recebimento.';
  end if;

  v_already_paid:=v_order.payment_status='paid';

  update public.orders
     set payment_status='paid',
         payment_received_at=coalesce(payment_received_at,now()),
         payment_confirmed_by=coalesce(payment_confirmed_by,auth.uid())
   where id=p_order_id
   returning * into v_order;

  return jsonb_build_object(
    'ok',true,
    'alreadyPaid',v_already_paid,
    'orderId',v_order.id,
    'paymentReceivedAt',v_order.payment_received_at,
    'amount',v_order.total
  );
end $$;

revoke all on function public.confirm_order_payment_v1(uuid) from public;
grant execute on function public.confirm_order_payment_v1(uuid) to authenticated;

notify pgrst,'reload schema';
commit;
