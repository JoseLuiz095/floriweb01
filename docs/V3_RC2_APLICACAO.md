# FloriWeb V3 RC2 — aplicação controlada

A RC2 é incremental sobre a RC1 já validada. Não reaplique as migrations antigas.

## 1. Banco

No Supabase SQL Editor execute:

```text
supabase/releases/20260827_v3_rc2_bundle.sql
```

Depois execute:

```text
supabase/tests/VALIDAR_V3_RC2.sql
```

O JSON deve retornar `"ok": true`.

A RC2 cria `analytics_events`, o funil agregado, idempotência para evitar pedidos duplicados por repetição de rede e fecha o bypass do checkout: `anon` e `authenticated` deixam de executar `create_public_order(jsonb)` diretamente.

## 2. Cloudflare Turnstile

Crie um widget do tipo **Managed** no Cloudflare Turnstile.

Hostname inicial:

```text
floriweb.joseluizacama.workers.dev
```

Copie a **Site Key** para a variável pública do Worker/Build:

```text
VITE_TURNSTILE_SITE_KEY=<site key>
```

Ative também:

```text
VITE_ANALYTICS_ENABLED=true
```

Não coloque a Secret Key do Turnstile em variável `VITE_*`.

## 3. Secrets das Edge Functions

No Supabase, em Edge Functions / Secrets, configure:

```text
TURNSTILE_SECRET_KEY=<secret key privada do widget>
TURNSTILE_REQUIRED=true
PUBLIC_APP_ORIGINS=https://floriweb.joseluizacama.workers.dev
CHECKOUT_FINGERPRINT_SALT=<texto aleatório longo e privado>
```

`CHECKOUT_FINGERPRINT_SALT` serve somente para gerar o hash de rate limit. Não use CNPJ, nome da empresa ou outro valor previsível.

## 4. Deploy das Edge Functions

Execute na raiz do projeto:

```text
DEPLOY_SUPABASE_FUNCTIONS.bat
```

Ele publica:

- `platform-create-store` — exige JWT do Master + AAL2;
- `public-checkout` — endpoint público no gateway, protegido dentro do handler por origem, Turnstile, rate limit e validação integral do pedido no banco.

O arquivo `supabase/config.toml` define `verify_jwt=false` somente para `public-checkout`. Isso é necessário porque publishable keys não são JWTs e o checkout é acessado por visitantes não autenticados.

## 5. Build e Cloudflare

```text
npm install
npm run validate
npm run build
```

Depois publique normalmente no Cloudflare.

## 6. Teste mínimo de produção

1. Entre no Master com MFA.
2. Abra `/admin-master/diagnostico` e confirme as duas Edge Functions.
3. Confirme `Turnstile: configurado` e `proteção obrigatória: sim`.
4. Abra uma vitrine pública.
5. Visualize um produto e adicione ao carrinho.
6. Inicie o checkout.
7. Conclua o Turnstile e gere um pedido.
8. Abra o WhatsApp na tela final.
9. No admin da loja, abra Análises e confirme que o funil começou a registrar eventos.

## Domínios Premium

A Edge Function aceita automaticamente um hostname que esteja ativo em `store_domains` para a loja do pedido. O widget Turnstile também precisa autorizar esse hostname.

Na configuração Free atual do Turnstile, um widget possui limite de hostnames. Para a fase inicial, o mesmo widget pode atender o domínio principal e os primeiros domínios Premium autorizados. Antes de atingir esse limite, o FloriWeb deverá evoluir para provisionamento de múltiplos widgets/site keys ou uma estratégia Enterprise. Isso não bloqueia o lançamento inicial, mas é uma dependência operacional a acompanhar conforme a base Premium crescer.

## Privacidade do Analytics

`analytics_events` possui apenas:

- `store_id`;
- UUID de sessão anônima;
- nome técnico do evento;
- `product_id` opcional;
- `order_id` opcional;
- horário.

Não entram na telemetria nome, telefone, e-mail, endereço, mensagem do cartão, observações ou IP.
