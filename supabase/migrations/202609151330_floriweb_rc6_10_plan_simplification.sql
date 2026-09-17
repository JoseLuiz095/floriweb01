begin;

-- FloriWeb V3 RC6.10
-- Simplifica a oferta comercial: um acesso administrativo principal por loja.
-- O schema permanece preparado para multiusuario futuro, mas o recurso nao e vendido nem exposto agora.
update public.plans
set admin_user_limit = 1,
    updated_at = now()
where code in ('DEMO','BASIC','PRO','PREMIUM');

-- Garante que o Premium continue com dominio proprio habilitado.
update public.plans
set custom_domain = true,
    updated_at = now()
where code = 'PREMIUM';

commit;
