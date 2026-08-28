# Aplicação da V3.0.0 RC4

A RC4 é **frontend-only**. Não execute SQL e não republique Edge Functions apenas por causa desta versão.

## Atualização

Na raiz do projeto:

```text
npm install
npm run validate
npm run build
npx wrangler deploy
```

## Teste funcional mínimo

1. Admin: conferir grupos da sidebar, status da loja e abertura da vitrine.
2. Master > Lojas: testar todos os filtros comerciais e busca.
3. Storefront mobile: adicionar item e confirmar o dock do carrinho.
4. Checkout mobile: confirmar total + CTA fixo e submissão normal com Turnstile.
5. Desktop 1366x768: confirmar que os novos elementos não comprimem conteúdo.

## Codex + Impeccable

Depois do build funcional:

```text
PREPARAR_LAPIDACAO_VISUAL_RC4.bat
```

Siga `docs/CODEX_IMPECCABLE_RC4.md`.
