# FloriWeb V3.0.0 RC1 - aplicação rápida

Esta RC1 foi preparada depois da auditoria real do Supabase/Cloudflare de 27/08/2026. Ela deixa de ser apenas preflight: existem alterações SQL novas, mas elas ficam versionadas e precisam ser aplicadas explicitamente.

## 1. Banco - executar uma vez

No Supabase Dashboard, abra **SQL Editor** e execute o arquivo inteiro:

```text
supabase/releases/20260827_v3_rc1_bundle.sql
```

O bundle contém, nesta ordem:

1. `202608270100_v3_security_baseline.sql`
2. `202608270110_v3_public_storefront_rpc.sql`
3. `202608270115_v3_public_order_rate_limit.sql`
4. `202608270120_v3_checkout_hardening.sql`
5. `202608270125_v3_plan_entitlements.sql`

Cada bloco usa sua própria transação. Não execute as migrations antigas `001` a `010` novamente neste banco.

### O que o bundle altera

- Admin Master passa a exigir `aal2` também em `public.is_platform_admin()`;
- corrige `products_public_read` para validar `categories.store_id = products.store_id`;
- leitura/listagem de metadata do Storage é isolada por loja;
- escrita no Storage passa por `is_store_admin()` e pelo estado real da loja;
- os buckets de imagens continuam públicos por desenho: arquivos de catálogo não são tratados como conteúdo privado;
- pedidos públicos recebem rate limit por fingerprint com retenção máxima de 24 h, sem armazenar IP bruto;
- mantém trigger que bloqueia novos pedidos em loja suspensa/arquivada/Demo vencida;
- cria `get_public_storefront_v3`, RPC consolidada da vitrine;
- endurece `create_public_order`: tamanho de payload, quantidade de itens, formatos, adicionais duplicados e recálculo integral do preço no banco;
- domínio próprio passa a ser validado pelo plano também no banco; downgrade para plano sem o recurso desativa o domínio ativo;
- Analytics aparece somente em planos com `reports=true`.

## 2. Validar o banco

Depois do bundle, execute:

```text
supabase/tests/VALIDAR_V3_RC1.sql
```

O resultado deve retornar:

```json
{
  "version": "3.0.0-rc.1",
  "ok": true
}
```

Se `ok` vier `false`, não faça o deploy do frontend ainda; envie o JSON completo da validação.

## 3. Publicar a Edge Function do Master

A Edge Function local agora também exige MFA/AAL2 e está identificada como `3.0.0-rc.1`.

Execute:

```text
DEPLOY_SUPABASE_FUNCTIONS.bat
```

Depois confira `/admin-master/diagnostico`.

## 4. Auth no Supabase

Configuração esperada para produção:

```text
Site URL
https://floriweb.joseluizacama.workers.dev

Redirect URL
https://floriweb.joseluizacama.workers.dev/admin/redefinir-senha
```

Para desenvolvimento local, adicione também:

```text
http://localhost:5173/admin/redefinir-senha
```

MFA TOTP deve permanecer habilitado.

## 5. Build e Cloudflare

Na raiz do projeto:

```text
npm install
npm run validate
npm run build
npx wrangler deploy
```

O Cloudflare já está configurado para `npm run build`, branch `main` e Worker Static Assets.

## 6. Teste comercial mínimo da RC1

Antes de apresentar para um cliente, valide estes cenários:

1. Master entra com senha e é obrigado a concluir MFA antes do painel Master.
2. Master cria uma nova floricultura.
3. Responsável entra e troca senha temporária quando aplicável.
4. Usuário com duas lojas consegue alternar entre elas sem misturar dados.
5. Produto da Loja A nunca aparece na Loja B.
6. Loja suspensa não abre catálogo, não aceita pedido e não permite upload administrativo.
7. Catálogo online carrega normalmente depois da RPC consolidada.
8. Alterar preço/total no payload do navegador não altera o valor gravado; o banco recalcula.
9. Pedido com adicional duplicado ou payload excessivo é rejeitado.
10. Pedido válido é registrado e segue para WhatsApp.
11. Demo/Essencial não exibem Analytics; Profissional/Premium exibem.
12. Apenas plano com `custom_domain=true` aceita domínio próprio; downgrade remove/desativa o domínio.

## Impeccable + Codex

Use o Impeccable somente depois de cada superfície funcional estar estável. No Codex o comando correto é com `$`:

```text
$impeccable init
$impeccable critique admin
$impeccable adapt admin
$impeccable polish admin
```

As limitações de alteração visual estão em `AGENTS.md`.
