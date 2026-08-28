-- FLORIWEB V3 - RASCUNHO DE TELEMETRIA COMERCIAL
-- NAO APLICAR EM PRODUCAO SEM DIAGNOSTICO DE TABELAS, RLS E FUNCOES.
-- Nenhum campo de PII deve ser adicionado a esta tabela.

begin;

create table if not exists public.analytics_events_v3_draft (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  session_id uuid not null,
  event_name text not null check (event_name in (
    'store_view','product_view','add_to_cart','remove_from_cart',
    'checkout_started','checkout_completed','whatsapp_clicked'
  )),
  product_id uuid null references public.products(id) on delete set null,
  order_id uuid null references public.orders(id) on delete set null,
  fulfillment text null check (fulfillment is null or fulfillment in ('delivery','pickup')),
  payment_method text null check (payment_method is null or payment_method in ('confirm','pix','card','cash')),
  occurred_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  constraint analytics_events_v3_draft_metadata_object check (jsonb_typeof(metadata)='object')
);

comment on table public.analytics_events_v3_draft is
  'RASCUNHO V3. Telemetria comercial anonima; proibido gravar nome, telefone, endereco, mensagem ou texto livre do cliente.';

-- RLS/policies deliberadamente NAO definidas neste blueprint: dependem do
-- resultado real de pg_policies e do desenho final do endpoint anti-abuso.

rollback;
