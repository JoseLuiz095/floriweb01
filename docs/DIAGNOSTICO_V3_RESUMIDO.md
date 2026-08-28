# Diagnostico V3 - o que enviar em uma unica rodada

## 1. Banco Supabase

Execute no SQL Editor:

```text
supabase/diagnostics/20260827_v3_preflight_readonly.sql
```

Copie o unico resultado `floriweb_v3_diagnostic` inteiro.

## 2. Supabase CLI

Na raiz do projeto, execute:

```text
COLETAR_DIAGNOSTICO_SUPABASE.bat
```

Envie o arquivo gerado:

```text
DIAGNOSTICO_SUPABASE_CLI.txt
```

## 3. Supabase Auth - apenas 3 prints

Envie prints, sem secrets/tokens, de:

```text
Authentication > URL Configuration
Authentication > Providers > Email
Authentication > Multi-Factor Authentication (se a tela existir)
```

## 4. Cloudflare - apenas 3 prints

Envie prints, escondendo valores secretos, de:

```text
Build / Deploy configuration
Variables and Secrets (preciso somente dos NOMES e ambientes Production/Preview)
Custom Domains / Routes
```

Com esses itens nao e necessario mandar consultas separadas de tabelas, RLS, funcoes, triggers, plans e platform_settings.
