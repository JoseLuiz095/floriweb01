# RC4 - Codex + Impeccable

A RC4 funcional ja esta pronta para uma passada visual completa. Nao e mais necessario revisar tela por tela antes de avancar.

Use:

```text
RODAR_IMPECCABLE_VISUAL_COMPLETO.bat
```

Depois, no Codex:
1. aprove `/hooks` se solicitado;
2. cole `PROMPT_CODEX_IMPECCABLE_COMPLETO.txt`;
3. deixe a skill `$impeccable polish` executar a rodada completa do produto.

Contexto oficial:

```text
PRODUCT.md
DESIGN.md
.impeccable/surfaces/floriweb-completo.md
AGENTS.md
```

Superficies cobertas na mesma rodada:
- Admin e primeiros passos;
- catalogo administrativo e pedidos;
- analytics/configuracoes;
- Storefront, produto e carrinho;
- Checkout e sucesso;
- Admin Master, lojas, planos, diagnostico e MFA;
- login, recuperacao e primeiro acesso.

Viewports obrigatorios:

```text
1366x768
390x844
768-1024px
```

Escopo: somente frontend visual. Nao alterar Supabase, Auth/MFA, services, regras comerciais, Turnstile, analytics de coleta, Cloudflare ou Edge Functions.

Consulte `docs/IMPECCABLE_PASSADA_COMPLETA.md`.
