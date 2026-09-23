-- Validacao FloriWeb RC6.19
select column_name,data_type from information_schema.columns where table_schema='public' and table_name='stores' and column_name in ('sales_recovery_window_hours','crm_come_back_days','repeat_order_max_age_days','upsell_enabled','upsell_limit','customer_message_templates') order by column_name;
