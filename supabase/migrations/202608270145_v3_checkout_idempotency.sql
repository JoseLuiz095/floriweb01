-- FloriWeb V3 RC2 - Idempotencia do checkout publico
-- Evita pedido duplicado quando o banco grava com sucesso, mas a resposta ao cliente se perde.

begin;

alter table public.orders
  add column if not exists public_request_id uuid null;

create unique index if not exists orders_store_public_request_uidx
  on public.orders(store_id, public_request_id)
  where public_request_id is not null;

create or replace function private.capture_public_order_request_id()
returns trigger
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_headers jsonb := '{}'::jsonb;
  v_request_id text := '';
begin
  begin
    v_headers := coalesce(nullif(current_setting('request.headers', true), '')::jsonb, '{}'::jsonb);
  exception when others then
    v_headers := '{}'::jsonb;
  end;

  v_request_id := lower(trim(coalesce(v_headers->>'x-floriweb-request-id','')));
  if v_request_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
    new.public_request_id := v_request_id::uuid;
  end if;
  return new;
end;
$$;

revoke all on function private.capture_public_order_request_id() from public, anon, authenticated;

drop trigger if exists orders_public_request_id_trg on public.orders;
create trigger orders_public_request_id_trg
before insert on public.orders
for each row execute function private.capture_public_order_request_id();

comment on column public.orders.public_request_id is 'UUID tecnico de idempotencia do checkout publico; nao contem dados pessoais.';

commit;
