# FloriWeb - passada visual completa com Codex + Impeccable

Esta etapa deve ser feita sobre a RC4 funcional ja publicada. Nao ha SQL, Edge Function ou mudanca de backend nesta preparacao.

## 1. Preparar tudo

Na raiz do projeto execute:

```text
RODAR_IMPECCABLE_VISUAL_COMPLETO.bat
```

O script:
- verifica Node >= 22.18;
- instala ou atualiza Impeccable para Codex no escopo do projeto;
- valida skill e hook;
- copia o prompt completo para a area de transferencia;
- deixa o projeto pronto para abrir no Codex.

## 2. Codex

Abra o Codex na raiz do projeto. Se necessario execute:

```text
/hooks
```

Aprove o hook do Impeccable.

Depois cole o conteudo de `PROMPT_CODEX_IMPECCABLE_COMPLETO.txt` no Codex. O prompt ja comeca com `$impeccable polish` e cobre toda a aplicacao em uma unica passada.

Nao use `/impeccable`. No Codex, a skill e `$impeccable`.

## 3. Depois que o Codex terminar

Execute:

```text
npm run validate
npm run build
```

Teste pelo menos:
- Admin em 1366x768;
- Storefront em 390x844;
- Checkout em 390x844 com Turnstile;
- Master em 1366x768;
- login, primeiro acesso e MFA.

Se estiver correto, publique normalmente no Cloudflare.

## Regra de escopo

A passada e visual. O Codex nao deve editar backend, Supabase, Auth/MFA, services, regras de preco/pedido, analytics de coleta, Turnstile ou Cloudflare.
