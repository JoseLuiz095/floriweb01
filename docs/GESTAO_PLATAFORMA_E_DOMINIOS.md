# Arquitetura SaaS, lojas e domínios

## Banco recomendado

A arquitetura padrão do FloriWeb deve continuar com **um projeto Supabase e um banco PostgreSQL multi-tenant**.

Todas as entidades de negócio são separadas por `store_id` e protegidas por RLS. Não é necessário criar um banco novo para cada floricultura pequena ou média.

Pedidos nunca são misturados no painel do cliente porque as consultas administrativas usam o `store_id` do vínculo em `store_users`. A V2.7 também separa o carrinho no navegador por loja.

### Quando considerar banco separado

Somente em projeto personalizado/Business quando existir requisito contratual de isolamento físico, grande volume, integração pesada, compliance específico ou infraestrutura dedicada.

## URL padrão

Para reduzir custo e manutenção, use uma aplicação e um domínio principal:

`https://floriweb.com.br/plantart`

`https://floriweb.com.br/flores-da-maria`

O domínio acima é apenas exemplo; registre um nome comercial disponível que represente o produto.

## Domínio próprio

Plano Premium pode permitir:

`https://www.floriculturacliente.com.br`

O domínio continua apontando para a mesma aplicação. `store_domains` identifica a floricultura pelo hostname. Para os primeiros clientes, a configuração DNS/Cloudflare deve ser manual para reduzir complexidade operacional.

## Administração

- `/admin`: proprietário/administrador da floricultura;
- `/admin-master`: administração da plataforma FloriWeb.

O Admin Master escolhe plano, valor mensal, vencimento e status da loja.

## Suspensão

Suspender não exclui dados. O cliente perde acesso e a loja pública fica indisponível até a reativação.

## Isolamento quando o administrador está logado

As rotas públicas sempre carregam a loja identificada pelo slug ou domínio. Uma sessão autenticada em `/admin` não altera a loja pública exibida em `/outra-loja`. O carrinho também utiliza uma chave separada por `store_id`.

## Limites comerciais

Os limites são dados do plano. A camada de banco bloqueia novas ativações acima dos limites configurados de produtos, categorias, adicionais e usuários administrativos. Isso evita depender apenas da interface React.
