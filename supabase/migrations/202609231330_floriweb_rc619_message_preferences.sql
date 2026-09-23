-- FloriWeb RC6.19 - preferencias de relacionamento, upsell e mensagens
alter table public.stores add column if not exists sales_recovery_window_hours integer not null default 72 check (sales_recovery_window_hours between 1 and 168);
alter table public.stores add column if not exists crm_come_back_days integer not null default 30 check (crm_come_back_days between 1 and 365);
alter table public.stores add column if not exists repeat_order_max_age_days integer not null default 120 check (repeat_order_max_age_days between 1 and 365);
alter table public.stores add column if not exists upsell_enabled boolean not null default true;
alter table public.stores add column if not exists upsell_limit integer not null default 3 check (upsell_limit between 1 and 6);
alter table public.stores add column if not exists customer_message_templates jsonb not null default '{}'::jsonb;
