# FloriWeb - Deploy das Edge Functions do Supabase

## Por que isto existe

O Cloudflare publica o frontend React. Ele **nao publica** automaticamente as Edge Functions do Supabase.

A criacao automatica de uma nova floricultura depende de:

```text
supabase/functions/platform-create-store/index.ts
```

Se essa funcao nao estiver publicada, o navegador recebe HTTP `404 NOT_FOUND` em:

```text
/functions/v1/platform-create-store
```

## Metodo 1 - Windows

Na raiz do projeto execute:

```text
DEPLOY_SUPABASE_FUNCTIONS.bat
```

Informe o `Project Ref` quando solicitado.

Se o CLI solicitar autenticacao, execute antes:

```bash
npx supabase@latest login
```

Depois rode novamente o BAT.

## Metodo 2 - Terminal

```bash
npx supabase@latest login
npx supabase@latest functions deploy platform-create-store --project-ref SEU_PROJECT_REF
npx supabase@latest functions list --project-ref SEU_PROJECT_REF
```

No projeto atualmente usado em producao, o Project Ref pode ser encontrado em:

```text
Supabase > Project Settings > General > Reference ID
```

## Metodo 3 - GitHub Actions

O repositorio contem:

```text
.github/workflows/deploy-supabase-functions.yml
```

Cadastre no GitHub:

```text
Settings > Secrets and variables > Actions
```

Secrets:

```text
SUPABASE_ACCESS_TOKEN
SUPABASE_PROJECT_REF
```

O `SUPABASE_ACCESS_TOKEN` e obtido na sua conta Supabase em Access Tokens.

Depois disso, alteracoes em `supabase/functions/**` podem publicar a funcao automaticamente no push da branch `main`.

## Validacao

Depois do deploy entre em:

```text
/admin-master/diagnostico
```

A verificacao deve mostrar:

```text
Edge Function platform-create-store
Publicada e respondendo
```

Somente depois faça o teste de `Nova loja`.
