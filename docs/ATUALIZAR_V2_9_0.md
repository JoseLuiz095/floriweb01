# Atualizar FloriWeb para V2.9.0

Este guia parte de um banco já atualizado até:

```text
202608260009_platform_access_hardening.sql
```

## 1. Aplicar a migration 010

No Supabase:

```text
SQL Editor
→ New query
```

Execute:

```text
supabase/migrations/202608260010_demo_trial_credentials_storefront.sql
```

A migration cria/ajusta:

- `store_users.must_change_password`;
- `platform_settings`;
- configuração padrão Demo 30/7;
- disponibilidade central `store_accessible`;
- vitrine neutra `resolve_storefront_status`;
- expiração de Demo;
- tentativa de agendamento via `pg_cron`;
- políticas RLS públicas;
- diagnóstico V2.9.0.

A própria migration valida se as migrations anteriores estão presentes.

## 2. Validar a configuração Demo

Execute:

```sql
select *
from public.platform_settings;
```

Esperado inicialmente:

```text
id                  1
demo_duration_days  30
demo_warning_days   7
```

## 3. Validar o campo de primeira senha

```sql
select column_name, data_type
from information_schema.columns
where table_schema='public'
  and table_name='store_users'
  and column_name='must_change_password';
```

Esperado:

```text
must_change_password | boolean
```

## 4. Validar a expiração automática

Primeiro veja o diagnóstico pela aplicação:

```text
/admin-master/diagnostico
```

O item:

```text
Agendamento automático da Demo
```

deve ficar `Ativo`.

Também pode consultar diretamente, se `pg_cron` estiver habilitado:

```sql
select jobid, jobname, schedule, active
from cron.job
where jobname='floriweb-expire-demo-trials';
```

Esperado:

```text
schedule = 15 * * * *
active   = true
```

Mesmo se o cron não estiver disponível, `store_accessible()` bloqueia uma Demo imediatamente após `expires_at`; porém o cron é recomendado para persistir `status='suspended'` e `stores.access_status='suspended'` automaticamente.

## 5. Republicar a Edge Function

A função `platform-create-store` foi alterada e precisa ser publicada novamente.

```bash
npx supabase@latest login
npx supabase@latest functions deploy platform-create-store --project-ref elttryavkeartoxgdgse
```

Depois:

```bash
npx supabase@latest functions list --project-ref elttryavkeartoxgdgse
```

Confirme:

```text
platform-create-store
```

## 6. Subir o frontend

```bash
git add .
git commit -m "feat: atualiza FloriWeb para v2.9.0"
git push origin main
```

O Cloudflare deve executar o build e publicar a aplicação.

## 7. Configurar Demo pelo Admin Master

Acesse:

```text
/admin-master/planos
```

Configure inicialmente:

```text
Duração da Demo: 30 dias
Aviso antecipado: 7 dias
```

Esses valores passam a valer para novas lojas Demo.

## 8. Testar criação com convite

Em:

```text
/admin-master/lojas
→ Nova loja
```

Escolha:

```text
Enviar convite por e-mail
```

Use um endereço real que você possa abrir.

## 9. Testar criação com senha temporária

Crie outra loja de teste e selecione:

```text
Cadastrar senha temporária
```

Exemplo de senha válida:

```text
FloriTeste2026
```

Mantenha marcado:

```text
Exigir troca da senha no primeiro acesso
```

Ao entrar em `/admin`, o usuário deve ser enviado para:

```text
/admin/primeiro-acesso
```

Só depois da troca deve acessar o painel.

## 10. Testar e-mails inválidos

Devem ser rejeitados:

```text
teste@teste.com
usuario@mailinator.com
usuario@gmial.com
invalido
```

Devem passar na validação de formato/domínio:

```text
nome@gmail.com
cliente@outlook.com
usuario@empresa.com.br
```

Importante: validar domínio não prova que uma caixa postal específica existe. Para isso, o fluxo por convite é o mais seguro.

## 11. Testar suspensão pública

No Admin Master:

```text
Lojas
→ Acesso
→ Desativada
```

A loja não deve ser apagada.

A URL pública deve exibir somente uma mensagem neutra de indisponibilidade, sem citar cobrança, atraso ou mensalidade.

O `/admin` do cliente também deve ficar indisponível.

Ao voltar para `Online`, os dados e acessos anteriores devem retornar.

## 12. Testar Demo vencida

Use somente uma loja de teste.

Descubra o `store_id` e force o vencimento:

```sql
update public.store_subscriptions ss
set expires_at = now() - interval '1 minute'
from public.plans p
where p.id=ss.plan_id
  and p.code='DEMO'
  and ss.store_id='UUID_DA_LOJA_TESTE';
```

Valide:

```sql
select public.store_accessible('UUID_DA_LOJA_TESTE'::uuid);
```

Esperado:

```text
false
```

A vitrine e o `/admin` devem ficar indisponíveis imediatamente.

Para persistir a suspensão sem esperar o cron:

```sql
select public.platform_expire_demo_trials();
```

Depois:

```sql
select access_status, suspended_at, suspension_reason
from public.stores
where id='UUID_DA_LOJA_TESTE';
```

Esperado:

```text
access_status = suspended
```

## 13. Reativar a Demo

No Admin Master altere a loja para `Online`.

Quando a Demo já estiver vencida, a interface deve perguntar se deseja conceder um novo período de acordo com `demo_duration_days`.

## 14. Diagnóstico final

Abra:

```text
/admin-master/diagnostico
```

Confira:

- Banco V2.9.0;
- Admin Master reconhecido;
- Edge Function publicada;
- Demos em andamento;
- Demos próximas do vencimento;
- agendamento automático da Demo ativo.
