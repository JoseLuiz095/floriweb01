# Atualizar FloriWeb para V2.8.0

## 1. Banco

A V2.8.0 não exige nova migration.

Confirme que a `202608260009_platform_access_hardening.sql` já foi aplicada.

## 2. Problema 404 ao criar loja

Se o navegador mostrar `404 NOT_FOUND` em:

```text
/functions/v1/platform-create-store
```

isso significa que a Edge Function existe no repositório, mas ainda não foi publicada no projeto Supabase.

O deploy do Cloudflare não publica funções do Supabase.

## 3. Publicar a função

Windows:

```text
DEPLOY_SUPABASE_FUNCTIONS.bat
```

Ou terminal:

```bash
npx supabase@latest login
npx supabase@latest functions deploy platform-create-store --project-ref SEU_PROJECT_REF
npx supabase@latest functions list --project-ref SEU_PROJECT_REF
```

## 4. Validar

Abra:

```text
/admin-master/diagnostico
```

Deve aparecer:

```text
Edge Function platform-create-store
Publicada e respondendo
```

Somente então faça:

```text
/admin-master/lojas
→ Nova loja
```

## 5. GitHub Actions opcional

Configure no repositório GitHub:

```text
SUPABASE_ACCESS_TOKEN
SUPABASE_PROJECT_REF
```

O workflow `deploy-supabase-functions.yml` passa a publicar alterações da Edge Function quando houver push em `main`.

## 6. Plano do cliente

Nova rota:

```text
/admin/plano
```

Ela mostra vantagens, limites e comparação comercial dos planos.

## 7. Testes

Execute:

```bash
npm run smoke
npm run build
```

Depois siga `docs/TESTES_V2_8_0.md`.
