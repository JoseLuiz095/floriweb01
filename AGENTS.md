# FloriWeb V3 — instruções para agentes/Codex

## Regra de produção
Nunca aplique migrations, altere RLS ou publique Edge Functions no projeto Supabase de produção sem o pacote de diagnóstico do banco e revisão explícita. SQL experimental deve ficar em `supabase/drafts/`.

## Frontend e Impeccable
O Impeccable e exclusivo para refinamento visual/UX. Instale com `INSTALAR_IMPECCABLE_CODEX.bat` ou `npm run design:setup` e valide com `npm run design:verify`.

Limite obrigatorio para sessoes que usam `$impeccable`:

- pode ajustar layout, espacamento, tipografia, cores, responsividade, acessibilidade, estados visuais, componentes de apresentacao e copy de interface;
- pode editar TSX apenas na camada de apresentacao, sem alterar fluxo de dados ou comportamento funcional;
- nao pode alterar `supabase/**`, migrations, RLS, Edge Functions, Auth, MFA, services, chamadas de API, contratos, regras de negocio, analytics de coleta, `wrangler.jsonc` ou variaveis de ambiente;
- se uma melhoria visual depender de mudanca funcional, apenas reporte a necessidade e pare nesse limite.

Fluxo preferido na RC4: use `PRODUCT.md` e `DESIGN.md` existentes como contexto; depois `critique` -> `audit` -> `layout/typeset/adapt` conforme necessario -> `polish`. Nao regenere os arquivos de contexto nesta rodada sem solicitacao explicita.

Priorize 1366x768 e mobile aproximadamente 390x844. Preserve os tokens existentes e evite efeitos que aumentem peso sem ganho de UX.

## Segurança
- Auth do navegador deve passar pelo cliente oficial `@supabase/supabase-js`.
- Nunca expor `service_role`, JWTs, cookies ou tokens em logs e commits.
- Toda leitura/escrita de dados continua dependente de RLS do Supabase.
- Admin Master exige MFA/AAL2 no frontend, na Edge Function e nas policies Master após a migration `202608270100_v3_security_baseline.sql`.

## Multi-loja
O usuário pode possuir mais de uma associação administrativa. Toda operação de painel deve usar a loja selecionada no `AuthContext`. O carrinho público permanece isolado por loja.

## Analytics
Registrar apenas telemetria comercial anônima. Não registrar nome, telefone, endereço, mensagem de cartão ou conteúdo livre do cliente.


## RC4 visual
A RC4 adiciona hierarquia de navegacao no Admin, funil comercial no Master, dock mobile do carrinho e CTA persistente no checkout. O Codex deve lapidar esses componentes sem alterar seus comportamentos funcionais. Consulte `docs/CODEX_IMPECCABLE_RC4.md`.

## Passada visual completa
Quando o usuario pedir a rodada visual completa, use o Impeccable como uma unica passada de refinamento do produto inteiro, seguindo `PROMPT_CODEX_IMPECCABLE_COMPLETO.txt` e `.impeccable/surfaces/floriweb-completo.md`.

A passada proprietaria e `polish`, porque deve preservar o mundo visual atual e elevar consistencia, responsividade, acessibilidade e qualidade de shipping sem redesenhar regras ou arquitetura. O objetivo e terminar Admin, Storefront, Checkout e Master juntos antes de uma nova rodada funcional.

Arquivos de contexto que devem ser lidos antes de editar:
- `PRODUCT.md`;
- `DESIGN.md`;
- `.impeccable/surfaces/floriweb-completo.md`;
- `docs/IMPECCABLE_PASSADA_COMPLETA.md`.

Durante a passada completa, mantenha congelados handlers, rotas, contratos, services, Auth/MFA, Turnstile, analytics de coleta, regras de preco/pedido, plano e multi-loja. A alteracao de TSX deve ser apenas estrutural/apresentacional.
