# FloriWeb V3.0.0 RC1 - handoff

A auditoria real do Supabase e do Cloudflare foi concluída. A RC1 deixa a fase de diagnóstico e passa para uma baseline comercial controlada.

## Implementado

- Supabase Auth oficial, logout real e acompanhamento de sessão.
- Multi-loja no Admin com seletor de loja.
- Carrinho isolado por loja.
- MFA TOTP/AAL2 no frontend do Admin Master.
- MFA/AAL2 também na Edge Function `platform-create-store`.
- **Novo:** `is_platform_admin()` exige AAL2 no banco para policies Master.
- **Novo:** correção do isolamento público de `products` por `products.store_id`.
- **Novo:** metadata/listagem e escrita do Storage respeitam isolamento por loja; os arquivos dos buckets públicos continuam públicos por desenho.
- **Novo:** RPC `get_public_storefront_v3` consolida o catálogo público em uma requisição.
- **Novo:** checkout público endurecido, com rate limit no banco e preço recalculado exclusivamente no servidor.
- **Novo:** recursos comerciais respeitam o plano: Analytics depende de `reports=true` e domínio próprio depende de `custom_domain=true`, com proteção também no banco/Edge Function.
- Code splitting das rotas com `React.lazy`.
- Analytics comercial inicial baseado nos pedidos existentes.
- Cloudflare SPA, CSP e headers de segurança versionados.
- Codex + Impeccable configurado apenas para refinamento visual.

## Aplicação no ambiente real

Como o banco remoto não possui `supabase_migrations.schema_migrations`, não reaplique as migrations históricas `001-010` e não use `db push` para tentar reconstruir o passado.

Para esta RC1 execute apenas:

```text
supabase/releases/20260827_v3_rc1_bundle.sql
```

Depois execute:

```text
supabase/tests/VALIDAR_V3_RC1.sql
```

Consulte `docs/V3_RC1_APLICACAO.md` para a ordem completa.

## Próximo bloco comercial

Depois de validar esta baseline, as prioridades são:

1. Turnstile complementar ao rate limit já aplicado no banco para criação pública de pedidos.
2. Telemetria anônima do funil `view -> product -> cart -> checkout -> order`.
3. Dashboard comercial com conversão, abandono e produtos vistos sem venda.
4. Provisionamento operacional de domínio personalizado do plano Premium.
5. Passes visuais por superfície com Codex + Impeccable.
