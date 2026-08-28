# Impeccable + Codex no FloriWeb

O Impeccable e usado somente para refinamento visual/UX do frontend. Arquitetura, regras de negocio, Supabase, seguranca, APIs e migrations ficam fora do escopo.

## Instalacao oficial atual

Na raiz do projeto:

```text
INSTALAR_IMPECCABLE_CODEX.bat
```

Ou:

```text
npm run design:setup
```

O projeto usa o CLI Impeccable 3.6.0 e o comando oficial atual:

```text
npx impeccable@3.6.0 skills install -y --providers=codex --scope=project
```

A instalacao local do Codex deve produzir:

```text
.agents/skills/impeccable/...
.codex/hooks.json
```

O instalador oficial reescreve o hook do Codex para apontar para a skill em `.agents/skills/impeccable/scripts/hook.mjs`.

Depois da instalacao:
1. feche e reabra o Codex na raiz do FloriWeb;
2. execute `/hooks`;
3. aprove o hook Impeccable se solicitado;
4. use `$impeccable` no Codex, nunca `/impeccable`.

## Passada completa recomendada agora

Nao e necessario trabalhar tela por tela nesta etapa. Execute:

```text
RODAR_IMPECCABLE_VISUAL_COMPLETO.bat
```

O script prepara/atualiza a skill, verifica o hook e copia para a area de transferencia o arquivo:

```text
PROMPT_CODEX_IMPECCABLE_COMPLETO.txt
```

Cole o prompt no Codex. Ele inicia com `$impeccable polish` e trata Admin, Storefront, Checkout e Master como uma unica rodada de shipping quality.

Contexto oficial da rodada:

```text
PRODUCT.md
DESIGN.md
.impeccable/surfaces/floriweb-completo.md
docs/IMPECCABLE_PASSADA_COMPLETA.md
```

## Escopo permitido

Pode ajustar:
- layout;
- espacamento;
- tipografia;
- cores e contraste;
- classes e estrutura visual de TSX;
- componentes de apresentacao;
- responsividade;
- acessibilidade;
- estados visuais;
- labels e UX copy factual;
- CSS redundante ou inconsistente.

Nao pode alterar:

```text
supabase/**
src/services/**
src/lib/**
Auth / MFA
RLS / migrations
Edge Functions
rotas e contratos
regras de preco ou pedido
analytics de coleta
Turnstile / rate limit
planos e multi-loja
wrangler / Cloudflare
variaveis de ambiente
```

## Viewports obrigatorios

```text
1366x768
390x844
intermediario 768-1024px
```

## Atualizacao futura

```text
npm run design:update
npm run design:verify
```

Depois de qualquer atualizacao de hook, o Codex pode solicitar nova aprovacao em `/hooks`.
