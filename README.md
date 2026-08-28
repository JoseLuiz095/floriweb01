# FloriWeb V3.0.0 RC5.1

Candidato final de homologação comercial. Mantém o backend da RC2/RC4 e adiciona revisão final de UX, confiabilidade visual do fluxo de pedidos e testes críticos.

Para validar localmente:

```bat
npm install
npm run validate
```

A RC5.1 adiciona uma regra funcional para produtos **sob encomenda**. Ela exige aplicar **um SQL incremental** no Supabase e publicar o frontend; **não exige redeploy das Edge Functions**.

A data mínima do pedido passa a considerar o maior `production_days` entre os produtos sob encomenda do carrinho. O frontend bloqueia datas anteriores e o banco repete a validação para impedir bypass. Consulte `TESTES_MANUAIS_V3_RC5_1_ENCOMENDA.md` antes da liberação comercial.

# FloriWeb V3.0.0 RC4

RC4 comercial/visual, baseada na RC3 e sem alteracoes novas de banco. Consulte `docs/V3_RC4_APLICACAO.md` para atualizar e `docs/CODEX_IMPECCABLE_RC4.md` para a lapidacao visual.

# FloriWeb 3.0.0 RC3

Plataforma SaaS multi-loja para floriculturas com catálogo público, carrinho, checkout, envio do pedido por WhatsApp, painel administrativo da loja e administração central da plataforma.

## O que entra na RC3

### Segurança e isolamento

- Supabase Auth via `@supabase/supabase-js`.
- Logout real e sessão acompanhada por `onAuthStateChange`.
- Usuário pode administrar mais de uma floricultura.
- Carrinho público isolado por loja.
- Admin Master protegido por MFA TOTP/AAL2 no frontend, banco e Edge Function.
- RLS público revisado para impedir mistura de catálogo entre lojas.
- Escrita/listagem de Storage respeita isolamento e estado da loja; imagens de catálogo permanecem em buckets públicos.
- Checkout recalcula produtos, variações, adicionais, frete e total no PostgreSQL.
- Payload público do checkout possui limites de tamanho, itens e adicionais, além de rate limit por fingerprint com retenção curta.
- Checkout público protegido por Edge Function + Cloudflare Turnstile validado no servidor.
- A RPC de criação de pedido deixa de ser executável diretamente pelo navegador.
- Cada tentativa de checkout recebe UUID técnico de idempotência para evitar duplicação após falha de rede.

### Performance

A vitrine V3 usa a RPC:

```text
get_public_storefront_v3
```

Ela consolida loja, categorias, produtos, imagens, variações, adicionais e áreas de entrega em uma única requisição pública. O fluxo V2.9 permanece como fallback apenas durante o rollout da migration.

### Comercial

- planos Demo, Essencial, Profissional e Premium;
- período Demo configurável;
- criação/suspensão/reativação de lojas pelo Master;
- senha temporária ou convite do responsável;
- troca obrigatória de senha no primeiro acesso;
- cadastro de produtos, categorias, adicionais e áreas de entrega;
- PIX, confirmação manual, cartão e dinheiro conforme configuração da loja;
- entrega ou retirada;
- pedidos e indicadores comerciais básicos;
- domínio personalizado já modelado no banco para operação Premium.
- funil anônimo de conversão para planos com relatórios.
- dashboard da loja com checklist de prontidão para venda e Master com visão de MRR/onboarding.
- onboarding guiado em `/admin/primeiros-passos`, com pedido de teste e compartilhamento do link.
- rascunho de checkout em `sessionStorage`, sem persistir mensagem do cartão, assinatura ou observações.

## Arquitetura

```text
Cloudflare Workers Static Assets
            |
          React
            |
       Supabase APIs
      /     |      \
 PostgreSQL Auth  Storage
            |
      Edge Functions
```

## Rotas

### Loja

```text
/{slug}
/{slug}/produto/{produto}
/{slug}/carrinho
/{slug}/finalizar
/{slug}/pedido/{id}
```

### Administração da loja

```text
/admin/login
/admin/esqueci-senha
/admin/redefinir-senha
/admin/primeiro-acesso
/admin
/admin/primeiros-passos
/admin/analytics
/admin/produtos
/admin/categorias
/admin/adicionais
/admin/pedidos
/admin/entregas
/admin/plano
/admin/configuracoes
```

### Admin Master

```text
/admin-master/login
/admin-master/mfa
/admin-master
/admin-master/lojas
/admin-master/planos
/admin-master/diagnostico
```

## Banco/Edge Functions na RC3

A RC3 não adiciona migration nem Edge Function. Ela reutiliza integralmente o backend validado da RC2. Se o seu ambiente já passou no `VALIDAR_V3_RC2.sql`, não execute SQL adicional para instalar a RC3.

### Referência do backend atual


O banco remoto auditado possui a estrutura das migrations antigas, mas **não possui histórico em `supabase_migrations.schema_migrations`**. Portanto:

- não execute novamente `202608250001` até `202608260010`;
- não use `supabase db push` para tentar reconstruir esse histórico agora.

No Supabase SQL Editor execute apenas:

```text
supabase/releases/20260827_v3_rc2_bundle.sql
```

Depois valide com:

```text
supabase/tests/VALIDAR_V3_RC2.sql
```

Leia `docs/V3_RC2_APLICACAO.md` antes do deploy.

## Edge Function

Depois do SQL RC2, publique as Edge Functions `platform-create-store` e `public-checkout`:

```text
DEPLOY_SUPABASE_FUNCTIONS.bat
```

A `platform-create-store` exige sessão do Admin Master com `aal2`. A `public-checkout` é pública no gateway, mas valida origem, Turnstile, rate limit e o pedido no servidor antes de gravar.

## Auth esperado em produção

```text
Site URL
https://floriweb.joseluizacama.workers.dev

Redirect URL
https://floriweb.joseluizacama.workers.dev/admin/redefinir-senha
```

Para desenvolvimento local:

```text
http://localhost:5173/admin/redefinir-senha
```

MFA TOTP deve permanecer habilitado.

## Turnstile em produção

No Cloudflare crie um widget **Managed** para `floriweb.joseluizacama.workers.dev`. Coloque a Site Key em `VITE_TURNSTILE_SITE_KEY`. O Secret fica somente no Supabase Edge Functions.

Secrets esperados no Supabase:

```text
TURNSTILE_SECRET_KEY=<privado>
TURNSTILE_REQUIRED=true
PUBLIC_APP_ORIGINS=https://floriweb.joseluizacama.workers.dev
CHECKOUT_FINGERPRINT_SALT=<segredo aleatorio>
```

Domínios Premium ativos em `store_domains` são aceitos pela Edge Function, mas também precisam estar autorizados no widget Turnstile. No plano Free do Turnstile cada widget possui limite de hostnames; consulte `docs/V3_RC2_APLICACAO.md` para a estratégia operacional inicial.

## Desenvolvimento

Use Node `22.18.0` ou superior.

```bash
npm install
npm run dev
npm run smoke
npm run typecheck
npm run build
npm run preview
```

Variáveis públicas do frontend:

```env
VITE_SUPABASE_URL=
VITE_SUPABASE_ANON_KEY=
VITE_DEFAULT_STORE_SLUG=floriweb-demo
VITE_APP_ENV=production
VITE_ANALYTICS_ENABLED=true
VITE_TURNSTILE_SITE_KEY=
```

Nunca coloque `service_role`, secret key ou token privado no frontend.

## Codex + Impeccable

O Impeccable e usado somente para refinamento visual. Para preparar a rodada completa, execute:

```text
RODAR_IMPECCABLE_VISUAL_COMPLETO.bat
```

O script instala/atualiza o Impeccable para Codex, valida o hook e copia o prompt completo para a area de transferencia. No Codex, aprove `/hooks` quando solicitado e cole `PROMPT_CODEX_IMPECCABLE_COMPLETO.txt`.

No Codex a skill usa `$`, nao `/`:

```text
$impeccable polish ...
```

A rodada usa `PRODUCT.md`, `DESIGN.md` e `.impeccable/surfaces/floriweb-completo.md` e cobre Admin, Storefront, Checkout e Master juntos. As restricoes para nao alterar Supabase, Auth, regras de negocio ou APIs durante a passada visual estao em `AGENTS.md`.

Consulte `docs/IMPECCABLE_PASSADA_COMPLETA.md`.

## Proteção do checkout e Analytics RC2

- O checkout público passa exclusivamente pela Edge Function `public-checkout`; `anon` e `authenticated` não executam mais `create_public_order(jsonb)` diretamente.
- Cloudflare Turnstile é validado no servidor por `siteverify`; o token nunca substitui as validações de preço/loja no PostgreSQL.
- Analytics registra somente `store_id`, UUID de sessão anônima, evento, produto/pedido opcional e horário.
- Eventos: vitrine, produto, carrinho, checkout, pedido e abertura do WhatsApp.
- Nome, telefone, e-mail, endereço, mensagem de cartão, observações e IP não entram na tabela de Analytics.

## Próximas prioridades

1. Testes E2E do fluxo comercial em desktop/mobile.
2. Operação de domínios Premium e estratégia de Turnstile para escala multi-domínio.
3. Lapidação visual de Admin, Storefront e Checkout com Impeccable.
4. Preparação da V3 estável e onboarding comercial.

## Entitlements comerciais do RC2

- Analytics exige plano com `reports=true`.
- Domínio próprio exige `custom_domain=true` e é validado no frontend, Edge Function e banco.


## V3.0.0 RC5.2 — Demo global e Analytics

A RC5.2 adiciona no Admin Master → Planos a opção de habilitar/desabilitar novas Demos e mantém configurável a duração do acesso e o aviso antecipado. Desabilitar a oferta não interrompe Demos já existentes.

Também inclui um reparo idempotente do Analytics de conversão (`analytics_events`, `track_public_event_v3` e `get_store_analytics_v3`) e força a recarga do schema cache do PostgREST. A aplicação deve ser feita pelo arquivo `supabase/releases/20260828_v3_rc5_2_bundle.sql`, seguida de `supabase/tests/VALIDAR_V3_RC5_2.sql`.
