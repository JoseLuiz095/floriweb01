-- FloriWeb RC6.17 - estoque simples e ficha tecnica sem transformar o produto em ERP.

alter table public.products
  add column if not exists track_stock boolean not null default false,
  add column if not exists stock_quantity integer,
  add column if not exists stock_minimum integer,
  add column if not exists estimated_cost numeric(12,2),
  add column if not exists technical_sheet text;

comment on column public.products.technical_sheet is
  'Composicao/observacoes internas da ficha tecnica. Nao e exibida ao cliente.';
