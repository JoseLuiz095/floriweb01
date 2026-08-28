# FloriWeb 3.0.0-rc.5

- Revisão visual final antes da homologação comercial.
- Checkout deixa explícito que o pedido é salvo antes da abertura do WhatsApp.
- Tela de sucesso mostra prova visual de registro e número do pedido.
- Marcação de abertura do WhatsApp usa `fetch keepalive`, reduzindo perda da atualização ao abrir o app no mobile.
- Tela de pedidos ganhou atualização silenciosa a cada 15s, ao voltar para a aba e por botão manual.
- Estados de foco, reduced-motion e cursores de botões desabilitados foram refinados.
- Impeccable corrigido para a versão publicada `3.6.0`.
- Novo teste `npm run test:critical` cobre ordem de gravação, idempotência, Turnstile e vínculo com WhatsApp.
- RC5 não adiciona migration nem Edge Function nova.

# FloriWeb 3.0.0-rc.4

- RC4 frontend-only, sem migration ou Edge Function nova.
- Admin reorganizado em Operacao, Catalogo e Conta, com status da loja e acesso rapido a vitrine.
- Master ganhou filtros comerciais: Pagantes, Demos, Implantacao, Atencao e Suspensas.
- Vitrine mobile ganhou dock persistente de carrinho com quantidade e subtotal.
- Categorias/pesquisa da vitrine ficam mais acessiveis no mobile.
- Checkout mobile ganhou CTA persistente com total e comunicacao explicita sobre o rascunho local.
- `PRODUCT.md` e `DESIGN.md` adicionados como contexto oficial para Codex + Impeccable.
- Guia `docs/CODEX_IMPECCABLE_RC4.md` e helper `PREPARAR_LAPIDACAO_VISUAL_RC4.bat`.
- Preparacao visual consolidada: Impeccable CLI 3.6.0, instalacao oficial `install`, verificacao de hook, surface brief unica e prompt de polish para toda a aplicacao.

# 3.0.0 RC3 — 2026-08-27

## Onboarding comercial
- Nova rota `/admin/primeiros-passos` com implantação guiada da floricultura.
- Checklist único de identidade, WhatsApp, categoria, produto, pagamento e entrega/retirada.
- Primeiro acesso com senha temporária direciona diretamente ao roteiro de implantação.
- Etapa específica para pedido de teste antes de divulgar a loja.
- Link público pode ser aberto e copiado diretamente pelo onboarding.

## Conversão da vitrine
- Vitrine passa a explicar de forma objetiva como o pedido funciona: WhatsApp, entrega/retirada, pedido mínimo e formas de pagamento.
- Checkout preserva um rascunho operacional apenas em `sessionStorage` para reduzir perda de dados ao navegar/atualizar a página.
- Mensagem do cartão, assinatura e observações não são persistidas no rascunho.
- Rascunho é removido automaticamente após pedido concluído.

## Operação
- RC3 é somente frontend/UX e reutiliza o banco e Edge Functions já validados na RC2.
- Nenhuma migration nova é necessária para atualizar de RC2 para RC3.

# 3.0.0 RC2 — 2026-08-27

## Checkout e anti-spam
- Novo endpoint público `public-checkout` no Supabase Edge Functions.
- Cloudflare Turnstile validado server-side via Siteverify, com `action=checkout` e conferência de hostname.
- RPC `create_public_order(jsonb)` deixa de ser executável diretamente por `anon`/`authenticated`; somente `service_role` pode chamá-la.
- Fingerprint SHA-256 calculado na Edge Function alimenta o rate limit sem persistir IP bruto.
- UUID técnico de idempotência evita pedido duplicado quando uma resposta de rede se perde após a gravação.
- Domínios Premium ativos podem ser validados contra `store_domains` no checkout.
- CSP do Cloudflare permite exclusivamente o host oficial do Turnstile para script/frame.

## Analytics comercial sem PII
- Nova tabela `analytics_events` com sessão anônima e eventos de vitrine, produto, carrinho, checkout, pedido e WhatsApp.
- Nova RPC pública `track_public_event_v3` com deduplicação de eventos de navegação.
- Nova RPC `get_store_analytics_v3` restrita a admin da loja e planos `reports=true`.
- Funil de conversão, abandono de carrinho/checkout, produtos vistos e não vendidos, receita e ticket médio.
- Telemetria não armazena nome, telefone, e-mail, endereço, conteúdo do cartão/observações ou IP.

## Gestão comercial
- Dashboard da loja ganha checklist de prontidão para venda.
- Dashboard Master ganha clientes pagantes, ticket médio, ARR, distribuição por plano, onboarding e próximos vencimentos.
- Diagnóstico Master passa a validar `public-checkout`, estado do Turnstile e quantidade de eventos anônimos.

## Operação
- Bundle incremental `supabase/releases/20260827_v3_rc2_bundle.sql`; não reaplica RC1.
- Validador somente leitura `supabase/tests/VALIDAR_V3_RC2.sql`.
- `supabase/config.toml` define `verify_jwt=false` somente para `public-checkout`; a segurança do endpoint é feita no handler.
- Deploy manual publica as duas Edge Functions com Supabase CLI 2.116.0.

# 3.0.0 RC1 — 2026-08-27

## Segurança
- `is_platform_admin()` passa a exigir MFA/AAL2 no banco para policies do Admin Master.
- Corrigida a policy pública de `products` para comparar `categories.store_id` com `products.store_id`, eliminando a ambiguidade que no banco remoto resultava em `c.store_id = c.store_id`.
- Policies públicas de catálogo passam por `store_accessible()` de forma uniforme.
- Listagem/metadata e escrita do Storage passam a respeitar isolamento/estado da loja. Os buckets de imagens seguem públicos por desenho para o catálogo.
- Upload/update/delete no Storage exige `is_store_admin()` para a loja da pasta `stores/<store_id>/...`.
- Trigger de pedidos mantém bloqueio independente do frontend para loja indisponível.

## Performance
- Nova RPC `get_public_storefront_v3` carrega loja, categorias, produtos, imagens, variações, adicionais, vínculos e áreas de entrega em uma única chamada.
- Frontend usa a RPC V3 e mantém fallback V2.9 somente enquanto a migration ainda não estiver aplicada.

## Checkout
- Novo rate limit de pedidos por fingerprint derivado do IP, sem armazenar IP bruto e com retenção máxima de 24 h.
- `create_public_order(jsonb)` valida a loja e aplica o rate limit antes de processar o pedido.
- Payload limitado a 60 KB, até 50 linhas de item e até 20 adicionais por item.
- Telefones/e-mail/textos recebem validações de tamanho/formato no servidor.
- Adicional duplicado no mesmo item é rejeitado.
- Preços enviados pelo navegador continuam ignorados; banco recalcula produto, variação, adicionais, frete, subtotal e total.
- Dados de entrega não são persistidos para pedidos de retirada.

## Planos e recursos comerciais
- Analytics passa a aparecer somente quando o plano possui `reports=true`.
- Criação/edição de loja desabilita domínio próprio em planos sem `custom_domain`.
- Edge Function rejeita domínio próprio incompatível com o plano selecionado.
- Nova proteção no banco impede domínio ativo sem entitlement e desativa domínios ao fazer downgrade.

## Operação
- Novo bundle `supabase/releases/20260827_v3_rc1_bundle.sql` para aplicação manual controlada no banco auditado.
- Novo `supabase/tests/VALIDAR_V3_RC1.sql` para validação somente leitura pós-migration.
- Documentação do Codex corrigida para usar `$impeccable`.
- Versão da Edge Function atualizada para `3.0.0-rc.1`.

# 2.9.0 — 2026-08-26

## Criação de lojas e e-mail
- `teste@teste.com` e outros domínios de teste/temporários passam a ser rejeitados.
- Erros comuns de provedor, como `gmial.com`, recebem sugestão de correção.
- A Edge Function valida se o domínio possui registro MX antes de criar o usuário.
- Gmail, Outlook/Hotmail e domínios corporativos continuam permitidos.
- O convite por e-mail permanece a confirmação recomendada da caixa postal específica.

## Credenciais do responsável
- Nova opção `Cadastrar senha temporária` no Admin Master.
- Senha com mínimo de 10 caracteres, maiúscula, minúscula e número.
- Opção `Exigir troca da senha no primeiro acesso`.
- Nova rota `/admin/primeiro-acesso`.
- Usuário existente no Auth nunca tem sua senha sobrescrita ao receber vínculo com outra loja.
- Regra de senha alinhada também à recuperação e alteração manual de senha.

## Plano Demo
- Nova configuração global `platform_settings`.
- Duração inicial padrão: 30 dias.
- Aviso inicial padrão: 7 dias antes.
- Dashboard Master destaca Demos próximas do vencimento.
- Tabela de lojas mostra data/contagem de vencimento.
- Demo vencida perde vitrine, painel administrativo e novos pedidos sem excluir nenhum dado.
- `pg_cron` é tentado automaticamente para persistir a suspensão após o vencimento.
- Diagnóstico informa se o agendamento da expiração está ativo.
- Reativar uma Demo vencida pode conceder um novo período configurado.

## Suspensão e vitrine
- Nova RPC pública segura `resolve_storefront_status`.
- Loja suspensa ou Demo expirada exibe página neutra de indisponibilidade.
- Motivo interno/financeiro nunca é enviado à vitrine pública.
- RLS público passa por `store_accessible`.

## Banco
- Nova migration `202608260010_demo_trial_credentials_storefront.sql`.
- Novo campo `store_users.must_change_password`.
- Nova tabela `platform_settings`.
- Funções `store_accessible`, `resolve_storefront_status` e `platform_expire_demo_trials`.
- Índice para expirações de assinatura.
- Pré-validação explícita das migrations anteriores.

## Estabilidade
- Corrigido import ausente de `useCallback` em `StoreContext` identificado durante a validação final.
- Corrigida a lógica de Demo vencida no mesmo dia, evitando reativação com data já expirada.
- Smoke test ampliado para 32 verificações estruturais.

# 2.8.0 — 2026-08-26

## Criação de lojas
- Diagnóstico da Edge Function `platform-create-store` diretamente no Admin Master.
- Tela de Lojas mostra aviso claro quando a função não está publicada.
- Erros HTTP das Edge Functions agora preservam o campo `error` retornado pelo Supabase.
- HTTP 404 da função recebe mensagem específica `EDGE_FUNCTION_NOT_DEPLOYED`.
- `platform-create-store` ganhou health check GET com versão e status de configuração.
- Novo `DEPLOY_SUPABASE_FUNCTIONS.bat`.
- Novo workflow opcional `.github/workflows/deploy-supabase-functions.yml`.
- Novo guia `docs/DEPLOY_EDGE_FUNCTIONS.md`.

## Planos
- Nova rota `/admin/plano` para o administrador da floricultura.
- Exibe plano atual, mensalidade, implantação, limites e vantagens.
- Profissional destacado como melhor custo-benefício.
- Referência Business a partir de R$ 349,90/mês para projetos personalizados.
- Comparação usa preço âncora real, sem preço riscado ou desconto fictício.
- Mapeamento completo de `monthly_price`, `setup_price`, `category_limit`, `addon_limit`, `admin_user_limit` e `sort_order` no plano carregado pelo painel da loja.

## Segurança e estabilidade mantidas
- suspensão preserva loja, pedidos, produtos, usuários e configurações;
- acesso é bloqueado por `access_status`;
- pedidos e catálogo permanecem isolados por `store_id`/RLS;
- criação de loja continua restrita ao Admin Master;
- Cloudflare continua sem `_redirects` conflitante.

## Banco
- Nenhuma migration nova obrigatória na 2.8.0.
- Banco esperado: migrations aplicadas até `202608260009_platform_access_hardening.sql`.

# 2.7.1 — estabilização do Admin Master
- Login Master com diagnóstico explícito de permissão.
- Suspensão preserva dados e vínculos.
- Reativação restaura o status anterior da assinatura.
- Edge Function reutiliza usuários existentes no Auth.
- Trigger bloqueia pedidos para lojas suspensas.
- RLS público endurecido para lojas suspensas.
