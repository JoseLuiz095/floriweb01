-- FLORIWEB V3 - RASCUNHO, NAO APLICAR EM PRODUCAO SEM DIAGNOSTICO
-- Objetivo: transformar MFA/AAL2 em requisito de banco para o Admin Master.
-- A policy platform_admins_self_read permanece sem AAL2 para permitir que o
-- usuario autenticado descubra que e Admin Master e conclua o desafio MFA.

begin;

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    coalesce(auth.jwt() ->> 'aal', '') = 'aal2'
    and exists (
      select 1
      from public.platform_admins pa
      where pa.user_id = auth.uid()
        and pa.active
    );
$$;

revoke all on function public.is_platform_admin() from public;
grant execute on function public.is_platform_admin() to authenticated;

-- Somente validacao manual durante homologacao. Remova o rollback e transforme
-- em migration numerada apenas depois de revisar pg_policies e funcoes reais.
rollback;
