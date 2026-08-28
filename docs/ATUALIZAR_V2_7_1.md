# Atualização FloriWeb V2.7.1

## 1. Banco

Execute somente a migration nova:

```text
supabase/migrations/202608260009_platform_access_hardening.sql
```

Ela pressupõe que a `202608260008_platform_management.sql` já foi aplicada com sucesso.

## 2. Edge Function

Faça novo deploy:

```bash
supabase functions deploy platform-create-store
```

## 3. Conferir Admin Master

```sql
select pa.user_id, u.email, pa.name, pa.active
from public.platform_admins pa
join auth.users u on u.id=pa.user_id;
```

O usuário usado em `/admin-master/login` precisa estar nessa consulta com `active=true`.

## 4. Deploy frontend

```bash
git add .
git commit -m "fix: hardening do admin master e suspensao reversivel"
git push origin main
```

## 5. Teste

Entre em:

```text
/admin-master/diagnostico
```

Depois siga `docs/TESTES_V2_7_1.md`.
