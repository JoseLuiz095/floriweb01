-- FloriWeb V3 RC6.8 - validacao do recebimento automatico no Financeiro

select
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='orders' and column_name='payment_status') as orders_payment_status,
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='orders' and column_name='payment_received_at') as orders_payment_received_at,
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='financial_entries' and column_name='source') as financial_source,
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='financial_entries' and column_name='order_id') as financial_order_id,
  to_regprocedure('public.confirm_order_payment_v1(uuid)') is not null as rpc_confirmacao,
  exists(select 1 from pg_trigger where tgname='orders_financial_receipt_sync_trg' and not tgisinternal) as trigger_financeiro,
  to_regclass('public.financial_entries_order_uidx') is not null as indice_antiduplicidade;

-- Deve retornar zero linhas. Um pedido recebido nao pode ter mais de uma entrada automatica.
select store_id,order_id,count(*) as duplicados
from public.financial_entries
where source='order' and order_id is not null
group by store_id,order_id
having count(*)>1;

-- Diagnostico dos ultimos pedidos e respectivos lancamentos.
select
  o.order_number,
  o.customer_name,
  o.total,
  o.payment_status,
  o.payment_received_at,
  f.id as financial_entry_id,
  f.amount as financial_amount,
  f.status as financial_status,
  f.occurred_on
from public.orders o
left join public.financial_entries f
  on f.store_id=o.store_id and f.order_id=o.id and f.source='order'
order by o.created_at desc
limit 20;
