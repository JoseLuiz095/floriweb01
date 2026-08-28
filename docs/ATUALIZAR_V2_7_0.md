# Atualização FloriWeb V2.7.0

## O que entra nesta versão

- alteração de senha pelo próprio administrador da floricultura;
- Admin Master em `/admin-master`;
- gestão central de lojas, planos, mensalidades, vencimentos e status Online/Desativada;
- seletores rápidos de plano e status diretamente na tabela de clientes;
- criação assistida de nova loja com convite do proprietário por e-mail;
- isolamento do carrinho por `store_id`;
- URLs multi-loja no padrão `https://seu-dominio.com.br/slug-da-loja`;
- preparação para domínio próprio por cliente;
- suspensão sem exclusão dos dados;
- tabelas `platform_admins` e `store_domains`;
- campos comerciais dos planos.

## 1. Atualize o código

Suba a V2.7.0 para o mesmo repositório usado pelo Cloudflare.

## 2. Execute apenas a migration nova

No Supabase > SQL Editor execute:

`supabase/migrations/202608260008_platform_management.sql`

Não reaplique migrations antigas em um banco já atualizado até a V2.6.0.

## 3. Cadastre seu usuário como Admin Master

Localize seu UUID:

```sql
select id,email from auth.users order by created_at;
```

Depois execute, trocando o UUID:

```sql
insert into public.platform_admins(user_id,name,active)
values ('SEU-UUID-AQUI','Administrador FloriWeb',true)
on conflict(user_id) do update set name=excluded.name,active=true;
```

Valide:

```sql
select pa.*,u.email
from public.platform_admins pa
join auth.users u on u.id=pa.user_id;
```

## 4. Deploy da Edge Function de criação de lojas

A criação automática de loja + convite de proprietário depende da função:

`supabase/functions/platform-create-store/index.ts`

Com a Supabase CLI ligada ao projeto:

```bash
supabase functions deploy platform-create-store
```

A função utiliza automaticamente os secrets padrão `SUPABASE_URL`, `SUPABASE_ANON_KEY` e `SUPABASE_SERVICE_ROLE_KEY` disponibilizados no ambiente da Edge Function. A service role nunca vai para o React ou Cloudflare.

## 5. Acesse o Admin Master

Abra:

`https://SEU-DOMINIO/admin-master/login`

Use o mesmo e-mail/senha do Supabase Auth que foi cadastrado em `platform_admins`.

## 6. Crie uma loja

Admin Master > Lojas e clientes > Nova loja.

Informe:

- nome;
- slug;
- cidade/UF;
- responsável;
- e-mail;
- plano;
- vencimento;
- Online ou Desativada;
- domínio próprio, se já houver.

A Edge Function cria um `store_id` novo, assinatura e vínculo do proprietário e envia convite para o e-mail informado.

## 7. URLs padrão

Sem domínio próprio:

`https://SEU-DOMINIO/plantart`

`https://SEU-DOMINIO/floricultura-maria`

Produtos e carrinhos respeitam a mesma base:

`/plantart/produto/buque-aurora`

`/plantart/carrinho`

`/plantart/finalizar`

## 8. Domínio próprio

O campo no Admin Master faz o mapeamento lógico do hostname para a loja, mas o hostname também precisa apontar para o mesmo Cloudflare Worker.

Para os primeiros clientes, faça essa etapa manualmente no Cloudflare. Não crie outro frontend nem outro banco por loja.

## 9. Suspensão por inadimplência

Ao trocar uma loja para `Desativada`:

- `stores.access_status = suspended`;
- `stores.active = false`;
- assinatura fica `suspended`;
- catálogo público deixa de responder;
- proprietário perde acesso administrativo;
- produtos, pedidos, imagens e configurações permanecem no banco.

Ao voltar para `Online`, o acesso retorna sem recriar dados.

## 10. Teste da alteração de senha

Admin da floricultura > Configurações > Segurança > Alterar minha senha.

Informe senha atual, nova senha e confirmação. Saia e entre novamente usando a nova senha.

## Limites adicionais dos planos

A migration também adiciona proteção no PostgreSQL para categorias ativas, adicionais ativos e usuários administrativos ativos, além dos limites de produtos/imagens já existentes. Registros ocultos/inativos não consomem as vagas de categoria/adicional.
