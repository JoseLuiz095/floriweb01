-- FloriWeb RC6.17 - validacao simples
select column_name, data_type
from information_schema.columns
where table_schema='public'
  and table_name='products'
  and column_name in ('track_stock','stock_quantity','stock_minimum','estimated_cost','technical_sheet')
order by column_name;
