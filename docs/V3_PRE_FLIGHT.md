# FloriWeb V3 - preflight concluído

O preflight de banco, Auth e Cloudflare foi concluído em 27/08/2026. O projeto avançou para `3.0.0-rc.1`.

## Estado confirmado do ambiente

- tabelas públicas e colunas principais auditadas;
- RLS de `public` e `storage` auditado;
- triggers e funções PostgreSQL auditados;
- planos e `platform_settings` auditados;
- Edge Function `platform-create-store` identificada no ambiente;
- Auth URL/Email/MFA revisados;
- build/deploy/variáveis/domínio do Cloudflare revisados;
- histórico remoto do Supabase CLI ausente, apesar da estrutura V2.9 existir no banco.

## Decisão de migração

Não reaplicar `202608250001` até `202608260010` no banco real. As alterações novas começam em `202608270100` e foram empacotadas para aplicação manual controlada na RC1.

## RC1

A documentação operacional está em `docs/V3_RC1_APLICACAO.md`.
