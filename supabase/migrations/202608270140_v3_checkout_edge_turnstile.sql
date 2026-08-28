-- FloriWeb V3 RC2 - Checkout somente pela Edge Function + fingerprint explicito
-- A validacao Turnstile ocorre em supabase/functions/public-checkout.
-- Depois desta migration, anon/authenticated nao executam create_public_order diretamente.

begin;

create or replace function public.enforce_public_order_rate_limit(p_store_id uuid)
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_headers jsonb := '{}'::jsonb;
  v_ip text := '';
  v_salt text := '';
  v_fingerprint text := '';
  v_explicit_fingerprint text := '';
  v_count integer := 0;
begin
  begin
    v_headers := coalesce(nullif(current_setting('request.headers', true), '')::jsonb, '{}'::jsonb);
  exception when others then
    v_headers := '{}'::jsonb;
  end;

  -- A Edge Function publica calcula SHA-256 do cliente e envia somente o hash.
  -- Como create_public_order deixa de ser executavel por anon/authenticated, este
  -- header nao pode ser usado pelo navegador para trocar de fingerprint e burlar o limite.
  v_explicit_fingerprint := lower(trim(coalesce(v_headers->>'x-floriweb-security-fingerprint','')));
  if v_explicit_fingerprint ~ '^[a-f0-9]{64}$' then
    v_fingerprint := v_explicit_fingerprint;
  else
    v_ip := nullif(trim(coalesce(v_headers->>'cf-connecting-ip','')), '');
    if v_ip is null then
      v_ip := nullif(trim(split_part(coalesce(v_headers->>'x-forwarded-for',''), ',', 1)), '');
    end if;

    -- Chamadas internas/SQL Editor nao devem ser bloqueadas por falta de contexto HTTP.
    if v_ip is null then return; end if;

    select value into v_salt
    from private.floriweb_security_settings
    where key='public_order_rate_limit_salt';

    if coalesce(v_salt,'') = '' then
      raise exception 'Configuracao interna de seguranca ausente.' using errcode='P0001';
    end if;
    v_fingerprint := md5(v_ip || ':' || v_salt);
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_store_id::text || ':' || v_fingerprint, 0));

  select count(*) into v_count
  from private.public_order_rate_limits rl
  where rl.store_id = p_store_id
    and rl.fingerprint = v_fingerprint
    and rl.request_at >= now() - interval '10 minutes';

  if v_count >= 8 then
    raise exception 'Muitas tentativas de pedido em pouco tempo. Aguarde alguns minutos e tente novamente.' using errcode='P0001';
  end if;

  insert into private.public_order_rate_limits(store_id,fingerprint)
  values (p_store_id,v_fingerprint);

  delete from private.public_order_rate_limits
  where request_at < now() - interval '24 hours';
end;
$$;

revoke all on function public.enforce_public_order_rate_limit(uuid) from public, anon, authenticated;

-- Impede bypass do Turnstile chamando a RPC diretamente pelo navegador.
revoke all on function public.create_public_order(jsonb) from public, anon, authenticated;
grant execute on function public.create_public_order(jsonb) to service_role;

-- Captura a abertura do WhatsApp usando a mesma sessao anonima ligada ao pedido.
create or replace function public.capture_whatsapp_analytics_v3()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_session_id uuid;
begin
  if new.whatsapp_clicked_at is null or old.whatsapp_clicked_at is not null then
    return new;
  end if;

  select ae.session_id into v_session_id
  from public.analytics_events ae
  where ae.order_id = new.id
    and ae.event_name = 'order_created'
  order by ae.occurred_at desc
  limit 1;

  if v_session_id is not null and not exists (
    select 1 from public.analytics_events ae
    where ae.order_id = new.id and ae.event_name='whatsapp_clicked'
  ) then
    insert into public.analytics_events(store_id,session_id,event_name,order_id,occurred_at)
    values(new.store_id,v_session_id,'whatsapp_clicked',new.id,coalesce(new.whatsapp_clicked_at,now()));
  end if;
  return new;
end;
$$;

revoke all on function public.capture_whatsapp_analytics_v3() from public, anon, authenticated;

drop trigger if exists orders_whatsapp_analytics_v3_trg on public.orders;
create trigger orders_whatsapp_analytics_v3_trg
after update of whatsapp_clicked_at on public.orders
for each row execute function public.capture_whatsapp_analytics_v3();

commit;
