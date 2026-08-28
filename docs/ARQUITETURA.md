# FloriWeb — Arquitetura V2

## Objetivo

Uma aplicação única atende várias floriculturas. Cada registro comercial relevante possui vínculo com `store_id`, e o isolamento é aplicado no PostgreSQL por RLS.

## Camadas

```text
Cliente / Administrador
        ↓
React + TypeScript + Vite
        ↓
storeApi / Supabase REST
        ↓
PostgREST + Auth + Storage
        ↓
PostgreSQL + RLS
```

O frontend usa as APIs HTTP oficiais expostas pelo Supabase diretamente, sem `service_role` e sem backend próprio nesta V2.

## Modo demo

Sem `.env`, `storeApi` utiliza uma base local de demonstração para permitir validar o produto imediatamente. Esse modo não é o armazenamento de produção.

## Modo Supabase

Com `VITE_SUPABASE_URL` e `VITE_SUPABASE_ANON_KEY`, o mesmo frontend passa a usar:

- Auth REST para login;
- PostgREST para CRUD;
- Storage REST para imagens;
- RPC `create_public_order` para pedidos anônimos.

## Multi-tenant

Tabelas com `store_id`:

- stores;
- store_users;
- categories;
- products;
- addons;
- store_subscriptions;
- orders.

Tabelas dependentes obtêm tenant via pai:

- product_images → products;
- product_variants → products;
- product_addons → products/addons;
- order_items → orders.

Triggers impedem relacionar categoria/adicional de lojas diferentes.

## Segurança

`store_users` liga `auth.users` à loja. Funções `is_store_member` e `is_store_admin` são usadas nas policies. Usuários anônimos recebem somente leitura do catálogo ativo. Pedidos públicos são criados por RPC SECURITY DEFINER que valida a loja e não expõe SELECT de pedidos ao público.

## Planos

`plans` + `store_subscriptions` controlam limites. O frontend comunica o limite, mas triggers do banco são a proteção definitiva.

## Evoluções previstas

Fora da V2:

- cobrança recorrente;
- painel master;
- domínio customizado automatizado;
- analytics avançado;
- WhatsApp Business API;
- gateway de pagamento;
- frete automático;
- ERP.


## Pagamentos V2.3

O checkout suporta `confirm`, `pix` e `card`. No PIX, cada loja escolhe `key` ou `copy_paste`. O modo `copy_paste` usa um BR Code estático fornecido pelo banco e injeta o total do pedido no campo 54, recalculando CRC16. PIX dinâmico controlado por URL bancária não é alterado.

O modo `card` não processa cartão: apenas registra a preferência e abre o WhatsApp para que a loja envie manualmente um link da sua adquirente/banco. Dados sensíveis de cartão não entram no FloriWeb.

## V2.6 — Entregas por área

A taxa de entrega é modelada em `delivery_zones`, sempre vinculada a `store_id`.

```text
stores 1 ─── N delivery_zones
                ├─ name
                ├─ aliases[]
                ├─ city/state
                ├─ fee
                ├─ active
                └─ sort_order
```

O navegador usa o CEP apenas para facilitar preenchimento e sugerir a área. O valor financeiro efetivo não vem do browser: `create_public_order` carrega novamente a `delivery_zone` ativa da mesma loja, aplica a taxa do PostgreSQL e grava snapshots (`delivery_zone_name` e `delivery_fee`) no pedido.

As formas de pagamento disponíveis e sua ordem são configurações da loja. `PIX`, `Cartão`, `Dinheiro` e `Confirmar com a floricultura` podem ser controlados no Admin; pelo menos uma opção deve permanecer disponível.
