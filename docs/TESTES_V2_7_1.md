# FloriWeb V2.7.1 - validação do Admin Master

## 1. Pré-requisitos

Aplique as migrations até `202608260009_platform_access_hardening.sql` e faça novo deploy da Edge Function `platform-create-store`.

## 2. Validar Admin Master

No SQL Editor:

```sql
select pa.user_id, u.email, pa.name, pa.active
from public.platform_admins pa
join auth.users u on u.id=pa.user_id;
```

O e-mail usado em `/admin-master/login` deve aparecer com `active=true`.

Depois acesse:

```text
/admin-master/login
```

Se o usuário for apenas administrador de uma floricultura, o login Master deve recusar com mensagem específica. Se estiver em `platform_admins`, deve entrar em `/admin-master`.

## 3. Diagnóstico interno

Depois do login Master, abra:

```text
/admin-master/diagnostico
```

O card deve informar a versão `2.7.1` e retornar os contadores sem alterar dados.

## 4. Criar loja com e-mail novo

Crie uma loja de teste usando um e-mail que ainda não existe em `auth.users`.

Resultado esperado:

- nova linha em `stores`;
- nova assinatura em `store_subscriptions`;
- categorias padrão;
- 31 áreas de Linhares se a cidade for Linhares/ES;
- usuário convidado;
- vínculo `store_users` como `owner`.

Se o convite falhar, revise SMTP e Redirect URLs. O onboarding é revertido para não deixar uma loja incompleta.

## 5. Criar loja com usuário já existente

Crie outra loja usando um e-mail que já existe em `auth.users`.

Resultado esperado:

- não tentar reenviar convite para usuário confirmado;
- criar a nova loja;
- adicionar um segundo vínculo em `store_users` para o mesmo `user_id`;
- pedidos e produtos continuam separados por `store_id`.

## 6. Suspender sem apagar

Antes de suspender uma loja anote:

```sql
select id, name, access_status, active from public.stores where slug='SLUG';
select count(*) from public.store_users where store_id='UUID_DA_LOJA';
select count(*) from public.orders where store_id='UUID_DA_LOJA';
```

No Admin Master altere `Online` para `Desativada`.

Resultado esperado:

- a linha de `stores` continua existindo;
- `stores.active` permanece `true`;
- `stores.access_status='suspended'`;
- `suspended_at` é preenchido;
- `store_users` não é apagado nem desativado;
- `orders` permanece igual;
- `store_subscriptions.status='suspended'`;
- vitrine pública deixa de carregar;
- login `/admin` do cliente deixa de obter membership;
- novos pedidos são rejeitados pelo banco.

## 7. Reativar

Volte o acesso para `Online`.

Resultado esperado:

- mesmo `store.id`;
- mesmos produtos;
- mesmos pedidos;
- mesmos vínculos de usuários;
- `access_status='online'`;
- `suspended_at` e `suspension_reason` voltam a `null`;
- assinatura retorna ao status anterior (`trial` ou `active`);
- vitrine e painel voltam a funcionar.

## 8. Isolamento entre lojas

Crie pedido na Loja A e outro na Loja B. Confirme:

```sql
select store_id, count(*) from public.orders group by store_id;
```

Entre no `/admin` com um usuário da Loja A. Ele não pode listar ou alterar dados da Loja B. Repita invertendo os usuários.

## 9. Validação estrutural

Execute:

```text
supabase/tests/VALIDAR_V2_7_1.sql
```

## 10. Build

Execute localmente ou valide no Cloudflare:

```bash
npm run smoke
npm run build
```
