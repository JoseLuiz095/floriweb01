-- FloriWeb RC6.18 - preferencias leves de relacionamento
alter table public.stores add column if not exists sales_recovery_enabled boolean not null default true;
alter table public.stores add column if not exists sales_recovery_minutes integer not null default 30 check (sales_recovery_minutes between 5 and 1440);
alter table public.stores add column if not exists crm_enabled boolean not null default true;
alter table public.stores add column if not exists repeat_order_enabled boolean not null default true;
