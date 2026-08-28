# FloriWeb 2.0 — Relatório técnico

## Situação da entrega

A aplicação foi estruturada para funcionar em dois modos.

### Demo local

Sem `.env`, o frontend utiliza uma base de demonstração no navegador. Serve para validar UX, catálogo, carrinho, checkout, WhatsApp e painel sem depender de infraestrutura externa.

### Supabase

Com `VITE_SUPABASE_URL` e `VITE_SUPABASE_ANON_KEY`, o sistema utiliza:

- PostgreSQL;
- Supabase Auth;
- PostgREST;
- RPC para pedido público;
- Supabase Storage;
- Row Level Security.

## Fluxo público

```text
Catálogo
→ Produto
→ Variações/adicionais
→ Carrinho
→ Checkout
→ Registro do pedido
→ WhatsApp
```

O WhatsApp continua sendo o canal de confirmação. O banco registra a solicitação para gerar histórico administrativo.

## Fluxo administrativo

```text
Supabase Auth
→ store_users
→ store_id
→ RLS
→ Dashboard/CRUD/Storage
```

Owner e admin podem administrar a loja vinculada. `employee` fica preparado no modelo, mas não possui acesso administrativo nesta versão.

## Multi-tenant

As tabelas de negócio utilizam `store_id`, direta ou indiretamente. As policies e triggers evitam cruzamento de dados entre lojas.

## Planos

A migration cria DEMO, BASIC, PRO e PREMIUM via seed. Os limites são aplicados no frontend e também no PostgreSQL, para que não seja possível contornar a regra apenas chamando a API.

Cobrança automática ainda não faz parte da V2.

## Segurança

- nenhuma `service_role` é usada no React;
- senhas reais ficam no Supabase Auth;
- pedidos não possuem SELECT anônimo;
- a RPC do pedido não confia nos preços enviados pelo navegador: os valores são recalculados no PostgreSQL;
- inserts de pedidos passam por RPC pública controlada;
- Storage é separado por `stores/{store_id}`;
- RLS protege os dados administrativos.

## Limitações deliberadas

- sem gateway de pagamento;
- sem WhatsApp Business API;
- sem cobrança de assinatura;
- sem domínio customizado automatizado;
- sem painel master;
- sem anti-spam/captcha na RPC pública de pedidos;
- sem cálculo automático de frete;
- sem controle de estoque quantitativo.

Esses itens foram deixados para etapas posteriores porque não são necessários para validar o produto principal.


## Evolução 2.3

Foram adicionados PIX Copia e Cola com total automático, seleção entre Copia e Cola/Chave PIX, cartão opcional via link manual de WhatsApp e migration `202608250004_payment_methods.sql`.

### Migration V2.3

A migration `202608250004_payment_methods.sql` adiciona `pix_receipt_mode`, `pix_copy_paste` e `card_payment_enabled` em `stores`, além de permitir `card` em `orders.payment_method`.

# Complemento técnico V2.9.0

## Segurança de identidade
- validação de e-mail no frontend e novamente na Edge Function;
- bloqueio de domínios de teste/temporários;
- checagem MX do domínio antes do provisionamento;
- opção de convite ou senha temporária;
- senha temporária não é persistida nas tabelas da aplicação;
- usuário Auth existente nunca tem senha sobrescrita;
- troca obrigatória no primeiro acesso controlada por `store_users.must_change_password`.

## Ciclo da Demo
- `platform_settings` concentra duração e antecedência do aviso;
- `store_subscriptions.expires_at` define o fim individual;
- `store_accessible()` aplica o bloqueio imediatamente, mesmo antes do cron persistir a suspensão;
- `platform_expire_demo_trials()` persiste `suspended` sem remover dados;
- `pg_cron` tenta executar a expiração a cada hora;
- `platform_system_check()` informa se o job de expiração está agendado.

## Privacidade comercial
A vitrine pública usa `resolve_storefront_status` e recebe apenas nome/slug/status técnico. Motivos internos de suspensão e informações de cobrança não são retornados ao visitante.
