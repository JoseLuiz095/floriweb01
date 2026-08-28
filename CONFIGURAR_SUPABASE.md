# FloriWeb — Configuração do Supabase

Este guia parte de uma instalação nova. O FloriWeb funciona sem Supabase em **modo demo local**, mas para autenticação, banco, Storage, RLS e múltiplas floriculturas reais é necessário concluir esta configuração.

## 1. Criar o projeto

1. Entre no painel do Supabase.
2. Crie um novo projeto.
3. Escolha organização, nome do projeto e região próxima dos usuários.
4. Defina uma senha forte para o banco e guarde-a fora do repositório.
5. Aguarde o provisionamento.

## 2. Obter URL e chave pública

No painel do projeto, abra a área de API/Project Settings e copie:

- **Project URL**;
- **anon/public key**.

Nunca coloque `service_role` no React. A chave `anon` é própria para frontend quando o banco está protegido por RLS.

## 3. Criar `.env`

Na raiz do projeto:

```bat
copy .env.example .env
```

Edite `.env`:

```env
VITE_SUPABASE_URL=https://SEU-PROJETO.supabase.co
VITE_SUPABASE_ANON_KEY=SUA_CHAVE_ANON
VITE_DEFAULT_STORE_SLUG=floriweb-demo
VITE_APP_ENV=development
```

Reinicie o Vite depois de alterar `.env`.

## 4. Criar o banco — opção recomendada para a primeira instalação

Abra **SQL Editor** no Supabase.

Execute as migrations **em ordem**:

```text
supabase/migrations/202608250001_initial_floriweb.sql
supabase/migrations/202608250002_order_confirmation.sql
supabase/migrations/202608250003_checkout_details.sql
supabase/migrations/202608250004_payment_methods.sql
supabase/migrations/202608260005_addon_images.sql
supabase/migrations/202608260006_plan_active_limits.sql
supabase/migrations/202608260007_delivery_zones_cash_checkout.sql
```

A segunda migration acrescenta o fluxo final da V2.1: `order_number`, retorno ampliado da RPC de criação do pedido e atualização do status quando o cliente abre o WhatsApp. A terceira migration amplia o checkout da V2.2 com dados do comprador, destinatário, endereço detalhado e cartão.

Se o banco já está na V2.5.0, execute somente `202608260007_delivery_zones_cash_checkout.sql`. Em instalações novas, execute todas as migrations em ordem antes do seed.

Esses scripts criam/atualizam:

- `stores`;
- `store_users`;
- `categories`;
- `products`;
- `product_images`;
- `product_variants`;
- `addons`;
- `product_addons`;
- `plans`;
- `store_subscriptions`;
- `orders`, incluindo `order_number`;
- `order_items`;
- índices;
- triggers de `updated_at`;
- validação de plano;
- limite de imagens;
- integridade multi-loja;
- funções de autorização;
- RLS;
- RPC de pedido público com recálculo de preços no banco;
- RPC para registrar a abertura do WhatsApp na tela final;
- buckets e policies do Storage.

A execução deve terminar sem erro.

## 5. Inserir os dados de demonstração

Depois da migration, execute no SQL Editor:

```text
supabase/seed/seed_demo.sql
```

Valide:

```sql
select id, slug, name, active from public.stores;
select code, name, product_limit, image_limit_per_product from public.plans order by product_limit nulls last;
select count(*) as categorias from public.categories;
select count(*) as produtos from public.products;
select count(*) as adicionais from public.addons;
```

Resultado esperado na instalação inicial:

- 1 loja demo;
- planos DEMO, BASIC, PRO e PREMIUM;
- 5 categorias;
- 8 produtos;
- 4 adicionais.

## 6. Criar o primeiro administrador

O seed **não cria senha**.

No painel Supabase:

1. Abra **Authentication**.
2. Abra **Users**.
3. Use a opção de criar/adicionar usuário.
4. Informe um e-mail real de teste.
5. Defina uma senha de teste forte.
6. Confirme/crie o usuário.
7. Copie o UUID desse usuário.

Também obtenha o UUID da loja:

```sql
select id, slug, name
from public.stores
where slug = 'floriweb-demo';
```

Vincule o usuário:

```sql
insert into public.store_users (
  store_id,
  user_id,
  role,
  active
)
values (
  'UUID_DA_LOJA',
  'UUID_DO_USUARIO_AUTH',
  'owner',
  true
)
on conflict (store_id, user_id)
do update set role = excluded.role, active = true;
```

Não copie os textos `UUID_DA_LOJA` e `UUID_DO_USUARIO_AUTH` literalmente. Substitua pelos valores reais.

## 7. Testar o login

Com Vite reiniciado:

```text
http://localhost:5173/admin/login
```

Use o usuário criado no Supabase. Quando `.env` estiver preenchido, as credenciais demo `admin@floriweb.demo / Flori@2026` deixam de ser o mecanismo de autenticação.

## 8. Validar os buckets

A migration cria:

```text
product-images
store-assets
```

No painel Storage, confirme que os dois existem.

Estrutura esperada:

```text
product-images/
└── stores/{store_id}/products/{product_id}/arquivo.webp

store-assets/
└── stores/{store_id}/logo/arquivo.webp
└── stores/{store_id}/cover/arquivo.webp
```

O público pode visualizar imagens, mas somente owner/admin vinculado à loja consegue gravar ou excluir dentro da pasta da própria loja.

## 9. Testar RLS rapidamente

### Anônimo pode ler catálogo ativo

Abra a loja sem autenticação. Produtos ativos devem aparecer.

### Anônimo não deve conseguir listar pedidos

Uma chamada anônima a `orders` deve retornar vazio/erro de permissão de acordo com a API, nunca os pedidos da loja.

### Admin deve enxergar sua loja

Após login, `/admin` deve carregar produtos, categorias, adicionais, pedidos e plano.

### Admin não pode editar outra loja

Use o cenário completo em `ROTEIRO_DE_TESTES.md`.

## 10. Testar limite de plano

A regra existe em dois níveis:

1. React desabilita criação quando atinge o limite;
2. trigger PostgreSQL `enforce_product_plan_limit()` bloqueia INSERT direto.

Para teste controlado, crie um plano temporário com limite 2 ou altere a assinatura de uma loja de teste. Não use a loja de produção para esse teste.


## 10.1. Validar o fluxo de confirmação da V2.1

Depois de finalizar um pedido no site, valide:

```sql
select
  order_number,
  customer_name,
  payment_method,
  total,
  status,
  whatsapp_clicked_at
from public.orders
order by created_at desc
limit 5;
```

Imediatamente após clicar em **Finalizar pedido**, o esperado é:

```text
status = draft
whatsapp_clicked_at = null
```

Depois de clicar em **Enviar Comprovante via WhatsApp** ou **Confirmar pedido via WhatsApp**, atualize a consulta. O esperado é:

```text
status = sent_to_whatsapp
whatsapp_clicked_at preenchido
```

O carrinho é limpo somente quando a RPC `create_public_order` retorna sucesso.

## 11. Supabase CLI — alternativa

Se preferir migrations por CLI, instale a Supabase CLI de acordo com a documentação oficial da versão em uso. Depois, na raiz do projeto, associe o projeto e aplique as migrations.

O fluxo conceitual é:

```text
supabase login
supabase link --project-ref SEU_PROJECT_REF
supabase db push
```

Como a forma de instalação da CLI pode mudar entre versões, use o método de instalação recomendado pela documentação oficial no momento da implantação.

O seed deste projeto está em:

```text
supabase/seed/seed_demo.sql
```

## 12. Verificações SQL úteis

```sql
select * from public.stores order by name;
select * from public.store_users order by created_at;
select * from public.plans order by code;
select * from public.store_subscriptions order by started_at desc;
select * from public.categories order by store_id, sort_order;
select * from public.products order by store_id, name;
select * from public.product_images order by product_id, sort_order;
select * from public.product_variants order by product_id, sort_order;
select * from public.addons order by store_id, name;
select order_number, id, customer_name, payment_method, total, status, whatsapp_clicked_at, created_at
from public.orders
order by created_at desc
limit 20;
```

## 13. Erros comuns

### Tela informa “Supabase não configurado”

Confira se `.env` existe na raiz e reinicie `npm run dev`.

### Login funciona no Auth, mas painel diz que não há vínculo

Falta `store_users` ou `active=false`.

### Upload retorna 403

Confira:

- usuário autenticado;
- role `owner` ou `admin`;
- `store_users.active=true`;
- caminho inicia por `stores/{store_id}/...`;
- buckets foram criados pela migration.

### Produto não pode ser criado

Verifique assinatura e limite:

```sql
select
  s.name as loja,
  p.name as plano,
  p.product_limit,
  (select count(*) from public.products pr where pr.store_id=s.id) as produtos
from public.stores s
left join public.store_subscriptions ss on ss.store_id=s.id and ss.status in ('trial','active')
left join public.plans p on p.id=ss.plan_id;
```

### Produto pode ser editado mesmo no limite

Isso é intencional. O limite bloqueia **novos** produtos; produtos já existentes continuam editáveis.

## 14. Segurança mínima antes de publicar

- não versionar `.env`;
- nunca usar `service_role` no React;
- manter RLS habilitado;
- testar isolamento entre duas lojas;
- usar senha forte no usuário administrador;
- desativar usuários que saírem da operação;
- revisar CORS/domínios do projeto antes da produção;
- considerar anti-spam/rate limiting para a RPC pública de pedidos antes de alto volume.


## V2.6.0 — áreas de entrega e dinheiro

A migration `202608260007_delivery_zones_cash_checkout.sql` cria `delivery_zones`, adiciona Dinheiro e a configuração da ordem dos pagamentos, além de exigir confirmação de revisão do pedido. Em lojas de Linhares já existentes, os bairros padrão são criados **desativados e com taxa R$ 0,00**. Entre em **Admin > Entregas**, informe as taxas corretas e ative somente as áreas realmente atendidas.

O autocomplete de CEP usa ViaCEP no navegador. O valor da entrega não é confiado ao frontend: a RPC `create_public_order` busca novamente a área ativa e a taxa no PostgreSQL antes de gravar o pedido.

## V2.7.0 — Admin Master e múltiplas lojas

Se seu banco já está na V2.6.0, execute somente:

```text
supabase/migrations/202608260008_platform_management.sql
```

Depois cadastre seu usuário do Supabase Auth em `platform_admins` e faça deploy da Edge Function `platform-create-store`.

O passo a passo completo está em `docs/ATUALIZAR_V2_7_0.md`.

---

# Complemento V2.8.0 - Edge Function de criação de lojas

O frontend hospedado no Cloudflare **não publica** automaticamente a função:

```text
supabase/functions/platform-create-store/index.ts
```

Depois de configurar o Admin Master, publique-a com:

```bash
npx supabase@latest login
npx supabase@latest functions deploy platform-create-store --project-ref SEU_PROJECT_REF
```

Ou use no Windows:

```text
DEPLOY_SUPABASE_FUNCTIONS.bat
```

Valide em:

```text
/admin-master/diagnostico
```

A V2.8.0 não possui migration nova obrigatória; o banco deve estar atualizado até `202608260009_platform_access_hardening.sql`.

# Complemento V2.9.0 — Demo, e-mail e credenciais temporárias

Se o banco já está atualizado até `202608260009_platform_access_hardening.sql`, execute somente:

```text
supabase/migrations/202608260010_demo_trial_credentials_storefront.sql
```

Depois publique novamente a Edge Function:

```bash
npx supabase@latest functions deploy platform-create-store --project-ref elttryavkeartoxgdgse
```

No Admin Master acesse:

```text
/admin-master/planos
```

Configuração inicial recomendada:

```text
Demo: 30 dias
Aviso: 7 dias antes
```

Valide em:

```text
/admin-master/diagnostico
```

principalmente:

```text
Banco 2.9.0
Edge Function 2.9.0
Agendamento automático da Demo: Ativo
```

Para detalhes completos veja `docs/ATUALIZAR_V2_9_0.md`.
