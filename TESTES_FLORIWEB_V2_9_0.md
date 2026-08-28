# Testes FloriWeb V2.9.0

## Objetivo

Validar as mudanças de e-mail, credenciais, suspensão pública e plano Demo, além de garantir que as funções existentes continuem operacionais.

## A. Validação local automatizada

Execute:

```bash
npm run smoke
npm run typecheck
npm run build
```

O smoke da V2.9.0 contém mais de 30 verificações estruturais.

## B. Banco

### B1. Configuração Demo

```sql
select id, demo_duration_days, demo_warning_days
from public.platform_settings;
```

### B2. Campo de senha temporária

```sql
select column_name
from information_schema.columns
where table_schema='public'
  and table_name='store_users'
  and column_name='must_change_password';
```

### B3. Funções

```sql
select
  to_regprocedure('public.store_accessible(uuid)') as store_accessible,
  to_regprocedure('public.resolve_storefront_status(text,text)') as storefront_status,
  to_regprocedure('public.platform_expire_demo_trials()') as expire_demo,
  to_regprocedure('public.platform_system_check()') as system_check;
```

Todos devem retornar o nome da função.

### B4. Cron

```sql
select jobid, jobname, schedule, active
from cron.job
where jobname='floriweb-expire-demo-trials';
```

Esperado: um job ativo.

## C. Edge Function

```bash
npx supabase@latest functions list --project-ref elttryavkeartoxgdgse
```

Deve conter:

```text
platform-create-store
```

Depois abra `/admin-master/diagnostico` e confira a versão 2.9.0.

## D. Validação de e-mail

Na criação da loja:

| E-mail | Esperado |
|---|---|
| `teste@teste.com` | Bloquear |
| `teste@mailinator.com` | Bloquear |
| `usuario@gmial.com` | Sugerir `gmail.com` |
| `nome@gmail.com` | Aceitar |
| `nome@outlook.com` | Aceitar |
| endereço corporativo real | Aceitar se o domínio possuir MX |

## E. Criação por convite

1. Nova loja.
2. Plano Essencial.
3. E-mail real novo.
4. `Enviar convite por e-mail`.
5. Criar.

Validar:

```sql
select s.name, s.slug, u.email, su.role, su.active
from public.store_users su
join public.stores s on s.id=su.store_id
join auth.users u on u.id=su.user_id
where s.slug='SLUG_TESTE';
```

## F. Criação com senha temporária

1. Nova loja.
2. Escolha `Cadastrar senha temporária`.
3. Senha `FloriTeste2026`.
4. Marque troca obrigatória.
5. Crie.

Valide:

```sql
select u.email, su.must_change_password
from public.store_users su
join auth.users u on u.id=su.user_id
join public.stores s on s.id=su.store_id
where s.slug='SLUG_TESTE';
```

Esperado:

```text
must_change_password = true
```

No primeiro login:

```text
/admin/login
→ /admin/primeiro-acesso
```

Depois da troca:

```sql
select must_change_password
from public.store_users
where store_id='UUID_DA_LOJA';
```

Esperado:

```text
false
```

## G. Usuário existente

Crie nova loja usando um e-mail que já esteja em `auth.users`.

Resultado esperado:

- nenhuma duplicação de Auth;
- senha atual não é modificada;
- novo `store_users` é criado para a nova loja.

## H. Suspensão manual

Antes:

```sql
select count(*) from public.products where store_id='UUID';
select count(*) from public.orders where store_id='UUID';
select count(*) from public.store_users where store_id='UUID';
```

Suspenda a loja.

Depois execute os mesmos counts. Devem permanecer iguais.

Teste:

- URL pública → página neutra de indisponibilidade;
- `/admin` → acesso bloqueado;
- Admin Master → continua vendo a loja;
- reativar → vitrine e painel retornam.

## I. Demo 30 dias

No Admin Master configure:

```text
30 dias
7 dias de aviso
```

Crie uma loja Demo.

```sql
select s.name, ss.status, ss.started_at, ss.expires_at, ss.billing_amount
from public.store_subscriptions ss
join public.stores s on s.id=ss.store_id
join public.plans p on p.id=ss.plan_id
where p.code='DEMO'
order by ss.started_at desc
limit 5;
```

Esperado:

```text
status = trial
billing_amount = 0
expires_at ≈ started_at + 30 dias
```

## J. Aviso com 7 dias

Em uma loja Demo de teste:

```sql
update public.store_subscriptions
set expires_at=now()+interval '7 days'
where store_id='UUID';
```

Abra `/admin-master`.

A loja deve aparecer em `Demonstrações próximas do vencimento`.

Com 8 dias restantes, não deve aparecer usando a configuração 7.

## K. Vencimento

```sql
update public.store_subscriptions
set expires_at=now()-interval '1 minute', status='trial'
where store_id='UUID';
```

Confira:

```sql
select public.store_accessible('UUID'::uuid);
```

Esperado `false`.

A vitrine pública deve ficar indisponível imediatamente.

Depois:

```sql
select public.platform_expire_demo_trials();
```

Valide:

```sql
select access_status from public.stores where id='UUID';
select status from public.store_subscriptions where store_id='UUID' order by started_at desc limit 1;
```

Esperado:

```text
stores.access_status = suspended
subscription.status = suspended
```

## L. Reativação

No Admin Master altere para Online.

Se a Demo estava expirada, conceda novo período.

Valide novo `expires_at` futuro e acesso público novamente disponível.

## M. Regressão do produto

Depois das funções novas, valide ainda:

1. Home pública.
2. Categorias.
3. Produto.
4. Variações.
5. Adicionais com imagem.
6. Carrinho.
7. Checkout.
8. CEP e bairro.
9. Taxa de entrega.
10. PIX.
11. Cartão por link.
12. Dinheiro.
13. Confirmação obrigatória.
14. Pedido no banco.
15. Limpeza do carrinho.
16. Produtos no admin.
17. Categorias.
18. Adicionais.
19. Entregas.
20. Configurações.
21. Alteração de senha.
22. Esqueci minha senha.
23. Meu plano.
24. Admin Master.
25. Segunda loja e isolamento por `store_id`.

## N. Isolamento multi-loja

Crie Loja A e Loja B e um pedido em cada uma.

```sql
select store_id, count(*)
from public.orders
where store_id in ('UUID_A','UUID_B')
group by store_id;
```

Entre como administrador da Loja A: nenhum dado da Loja B pode ser retornado pela interface/API autenticada.

## O. Build Cloudflare

O build deve completar:

```text
npm run typecheck
vite build
wrangler deploy
```

Depois teste F5 diretamente em:

```text
/slug-da-loja
/slug-da-loja/carrinho
/slug-da-loja/finalizar
/admin/login
/admin-master/login
```
