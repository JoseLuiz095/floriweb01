# FloriWeb V2 — Roteiro completo de testes

Use este roteiro antes de considerar uma versão pronta para demonstração comercial.

## A. Teste imediato sem banco — modo demo

1. Extraia o projeto.
2. Não crie `.env` ainda.
3. Execute:

```bat
npm install
npm run dev
```

Ou use:

```text
INICIAR_PROJETO.bat
```

4. Abra `http://localhost:5173`.
5. Abra `http://localhost:5173/admin/login`.
6. No modo demo use:

```text
E-mail: admin@floriweb.demo
Senha:  Flori@2026
```

Resultado esperado: catálogo e painel funcionam com dados locais de validação. Uma faixa no catálogo informa que é demonstração local.

## B. Console do navegador

Abra F12 → Console.

Não devem existir erros vermelhos durante navegação normal. `304`, websocket do Vite e mensagens de HMR são normais.

## C. Loja pública

Validar:

- capa;
- logo;
- nome;
- cidade/UF;
- WhatsApp;
- Instagram;
- Entrega/Retirada;
- categorias;
- pesquisa;
- quantidade de produtos;
- preço normal;
- preço promocional;
- produto sob encomenda;
- produto indisponível.

## D. Pesquisa

Pesquisar:

```text
rosas
noiva
xyz123
```

Esperado: resultados coerentes e estado “Nenhum produto encontrado” no termo inexistente.

## E. Produto

Abrir `Buquê Aurora`.

Testar:

- galeria;
- Clássico;
- Premium;
- Luxo;
- Chocolate;
- Cartão;
- Mini pelúcia;
- quantidade 1, 2 e 3;
- total recalculado;
- adicionar ao carrinho.

## F. Produto sob encomenda

Abrir `Buquê de Noiva Clássico`.

Esperado: aviso de prazo e variações funcionando, inclusive variações com redução de preço.

## G. Carrinho

1. Adicione dois produtos.
2. Altere quantidade.
3. Exclua um item.
4. Recarregue a página.

Esperado: carrinho permanece no navegador (`floriweb_cart_v1`).

## H. Pedido mínimo

No admin, configure pedido mínimo maior que o subtotal atual. O carrinho deve impedir avanço e informar quanto falta.

Depois volte o pedido mínimo para zero.

## I. Checkout — entrega

Preencha:

```text
Nome: Teste FloriWeb
Telefone: (27) 99999-9999
Data: uma data futura
Período: Tarde
Destinatário: Maria Teste
Endereço: Rua Teste, 100 - Centro
Cartão: Feliz aniversário!
Observações: Entregar após 14h.
```

Selecione **PIX** e clique em **Finalizar pedido**.

Esperado:

- o pedido é registrado;
- o carrinho é limpo;
- o navegador vai para `/pedido/{id}`;
- aparece **Pedido Realizado!**;
- aparece um número como `#28624`;
- aparece o total;
- aparece a chave PIX;
- existe botão para copiar a chave;
- existe botão **Enviar Comprovante via WhatsApp**;
- o WhatsApp **não abre automaticamente** ao finalizar.

## J. Tela final PIX e WhatsApp

Na tela **Pedido Realizado!**:

1. clique no botão de copiar a chave PIX;
2. cole a chave em um editor de texto e confirme que é igual à configuração da loja;
3. clique em **Enviar Comprovante via WhatsApp**.

Esperado:

- WhatsApp abre somente depois do clique;
- mensagem contém o número do pedido;
- mensagem contém o total;
- mensagem informa que o comprovante será anexado;
- detalhes do pedido continuam na mensagem;
- o cliente pode anexar manualmente a imagem do comprovante.

Observação: navegadores não permitem que o site anexe automaticamente um arquivo local ao WhatsApp. O cliente precisa selecionar o comprovante na conversa.

## K. Checkout — retirada e pagamento após confirmação

Monte outro carrinho. Repita usando **Retirada** e **Após confirmação da floricultura**.

Esperado:

- endereço não é obrigatório;
- ao finalizar, o carrinho é limpo;
- a tela final mostra **Aguardando confirmação** em vez do quadro PIX;
- o botão muda para **Confirmar pedido via WhatsApp**;
- a mensagem do WhatsApp indica Retirada.

## K.1. Registro de pedido e status

No modo demo, depois de finalizar um pedido, entre no admin → Pedidos.

Esperado:

- pedido aparece imediatamente na lista;
- número amigável do pedido aparece;
- antes de abrir WhatsApp, status visual é **Pedido realizado**;
- após clicar no botão do WhatsApp, status passa a **WhatsApp aberto**.

No Supabase, valide também:

```sql
select order_number, id, customer_name, payment_method, total, status, whatsapp_clicked_at, created_at
from public.orders
order by created_at desc
limit 5;

select *
from public.order_items
order by created_at desc
limit 20;
```

Imediatamente após **Finalizar pedido**:

```text
status = draft
whatsapp_clicked_at = null
```

Depois de clicar no WhatsApp:

```text
status = sent_to_whatsapp
whatsapp_clicked_at preenchido
```

## K.2. Falha ao finalizar não pode perder o carrinho

No modo Supabase de teste, provoque uma rejeição controlada da RPC, por exemplo deixando o pedido abaixo do mínimo configurado no banco.

Esperado:

- mensagem de erro;
- não navegar para Pedido Realizado;
- carrinho continua com os itens;
- nenhum falso sucesso é exibido.

## L. Login

1. Tente senha errada.
2. Entre com senha correta.
3. Clique Sair.
4. Digite `/admin` manualmente.

Esperado: usuário deslogado volta para login.

## M. Dashboard

Validar cards:

- produtos cadastrados;
- ativos;
- ocultos;
- categorias;
- pedidos enviados;
- plano;
- limite.

## N. Produtos — CRUD

Criar produto:

```text
Nome: Orquídea Branca Premium
Categoria: Flores variadas
Preço: 139,90
Promocional: 119,90
Descrição: Orquídea branca em composição elegante.
```

Adicionar variações pela interface estruturada:

```text
Tradicional | 0
Premium     | 25
```

Marcar adicionais.

Salvar.

Esperado: produto aparece no catálogo.

Depois:

- editar nome;
- editar preço;
- ocultar;
- reativar;
- marcar sob encomenda;
- excluir.

## O. Imagens

No produto:

1. selecione JPG;
2. selecione PNG;
3. selecione WEBP;
4. tente arquivo maior que 5 MB;
5. tente formato não permitido;
6. defina imagem principal;
7. exclua uma imagem.

Esperado: validações claras e catálogo refletindo imagem principal.

## P. Categorias

Testar:

- criar;
- editar nome;
- alterar slug;
- ocultar;
- reativar;
- excluir categoria sem produtos;
- tentar excluir categoria com produto.

Esperado: categoria com produto não é excluída.

## Q. Adicionais

Testar:

- criar Chocolate Teste;
- preço 12,50;
- editar;
- ocultar;
- vincular a um produto;
- abrir produto público;
- selecionar adicional;
- confirmar cálculo.

## R. Configurações

Alterar temporariamente:

- nome;
- frase;
- cidade;
- UF;
- CEP;
- endereço;
- WhatsApp;
- Instagram;
- horário;
- pedido mínimo;
- logo;
- capa.

Salvar e conferir catálogo público.

## S. Entrega/Retirada

Cenários:

1. Entrega ON / Retirada ON;
2. Entrega ON / Retirada OFF;
3. Entrega OFF / Retirada ON;
4. ambas OFF.

Esperado no quarto cenário: sistema impede salvar.

## T. Pix

1. Pix habilitado;
2. chave preenchida;
3. recebedor preenchido;
4. “Exibir Pix antes da confirmação” ON.

Esperado: opção PIX aparece no checkout. Ao selecionar PIX e finalizar, a tela de Pedido Realizado deve exibir:

- total;
- tipo da chave;
- chave;
- recebedor;
- copiar chave;
- Enviar Comprovante via WhatsApp.

Depois desative a exibição antecipada. Esperado: só pagamento após confirmação e a tela final não deve revelar a chave PIX.

## U. Configuração do Supabase

Siga `CONFIGURAR_SUPABASE.md` integralmente.

Depois renomeie/remova qualquer banco demo local somente pelo botão Restaurar demo se necessário. Ao existir `.env` válido, o sistema passa a usar Supabase automaticamente.

## V. Testes de banco

```sql
select * from public.stores;
select * from public.plans;
select * from public.store_subscriptions;
select * from public.categories;
select * from public.products;
select * from public.product_images;
select * from public.product_variants;
select * from public.addons;
```

Validar FKs e checks tentando, em uma loja de teste:

- preço negativo;
- promocional maior que preço;
- categoria de outra loja;
- adicional de outra loja;
- delivery/pickup ambos falsos.

Esperado: banco bloqueia dados inválidos.

## W. Teste de RLS — duas lojas

Crie Loja A e Loja B. Crie Usuário A e Usuário B no Supabase Auth.

Vincule:

```text
Usuário A → Loja A
Usuário B → Loja B
```

Teste logado como A:

- vê administração da Loja A;
- não lista produtos ocultos da Loja B;
- não atualiza `stores` da Loja B;
- não insere produto com `store_id` da Loja B;
- não faz upload no caminho `stores/{LOJA_B}/...`.

Repita invertendo usuários.

O teste deve ser feito também fora da interface, usando REST/SQL com sessão de usuário quando possível. Esconder botão no React não conta como segurança.

## X. Teste de limite de produtos

Em loja de teste, associe plano com `product_limit=2`.

1. crie produto 1;
2. crie produto 2;
3. tente produto 3 pela interface;
4. tente produto 3 via API autenticada.

Esperado: ambos bloqueados.

Depois edite produto 1 com a loja já no limite.

Esperado: edição continua permitida.

## Y. Teste de limite de imagens

Associe plano com `image_limit_per_product=2`.

1. envie imagem 1;
2. envie imagem 2;
3. tente imagem 3.

Esperado: frontend e banco bloqueiam a terceira.

## Z. Storage/RLS

Logado como usuário da Loja A:

- upload em `stores/{LOJA_A}/...`: permitido;
- upload em `stores/{LOJA_B}/...`: negado;
- leitura pública de uma imagem válida: permitida.

## AA. RPC de pedido público

Sem login, checkout deve registrar pedido pela RPC `create_public_order`.

O visitante anônimo **não** deve poder listar `orders`.

## AB. Responsividade

Testar no DevTools:

```text
375 x 812
390 x 844
768 x 1024
1366 x 768
1920 x 1080
```

Prioridades:

- sem scroll horizontal indevido;
- cards legíveis;
- carrinho utilizável;
- checkout utilizável;
- admin 1366x768 sem botões escondidos;
- sidebar vira menu lateral no mobile.

## AC. Imagem quebrada

Cadastre temporariamente URL inválida ou remova um arquivo.

Esperado: aparece `Imagem indisponível`, não o ícone quebrado do navegador.

## AD. Navegação direta

Testar F5 em:

```text
/produto/buque-aurora
/carrinho
/admin
/admin/produtos
/admin/configuracoes
```

Em `npm run dev` e `npm run preview`, as páginas devem funcionar conforme configuração do servidor SPA.

## AE. Build

Execute:

```bat
npm run typecheck
npm run build
npm run preview
```

Resultado esperado:

- zero erros TypeScript;
- pasta `dist` criada;
- preview abre normalmente.

## AF. Relato de defeito

Ao encontrar problema, registre:

```text
Tela:
Ação executada:
Esperado:
Obtido:
Console:
Terminal:
Screenshot:
```

Agrupe vários defeitos em uma única rodada quando possível.

## Checkout detalhado — V2.2

Validar um pedido de **Entrega** preenchendo:

- nome do comprador;
- telefone/WhatsApp;
- e-mail;
- data e período;
- nome do destinatário;
- telefone do destinatário;
- CEP;
- rua/avenida;
- número;
- complemento;
- bairro;
- cidade;
- UF;
- ponto de referência;
- mensagem do cartão;
- assinatura;
- opção de envio anônimo;
- observações;
- forma de pagamento.

Depois clique em **Finalizar pedido**. O resultado esperado é:

1. pedido gravado;
2. carrinho limpo somente após sucesso;
3. redirecionamento para `/pedido/{id}`;
4. número amigável do pedido exibido;
5. PIX exibido quando selecionado e configurado;
6. mensagem de WhatsApp com os novos dados.

Repita usando **Retirada**. Os campos de endereço não devem ser exigidos.

### Banco

Após configurar Supabase, valide os novos campos:

```sql
select
  order_number, customer_name, customer_phone, customer_email,
  recipient_name, recipient_phone, delivery_zip_code, delivery_street,
  delivery_number, delivery_complement, delivery_neighborhood,
  delivery_city, delivery_state, reference_point, card_message,
  card_signature, anonymous_sender
from public.orders
order by created_at desc
limit 10;
```



## Testes V2.3 — formas de pagamento

### PIX Copia e Cola recomendado

1. Entre em **Admin > Configurações > PIX**.
2. Habilite PIX e pagamento direto por PIX.
3. Selecione **PIX Copia e Cola — Recomendado**.
4. No banco, gere um PIX/QR estático sem valor fixo e copie o código Copia e Cola.
5. Cole o código no painel e salve.
6. Monte um carrinho com um total fácil de conferir, por exemplo R$ 189,90.
7. No checkout selecione PIX e finalize.
8. A tela final deve mostrar **PIX Copia e Cola · valor automático**.
9. Copie o código e cole no aplicativo do banco, sem concluir o pagamento de teste.
10. Confira se o banco reconhece exatamente o total do pedido.

Resultado esperado: o cliente não precisa digitar o valor manualmente.

> Se o banco fornecer um PIX dinâmico, com cobrança/expiração controlada pelo próprio banco, o painel deve recusar esse código para alteração automática de valor. Use Chave PIX nesta versão ou uma futura integração bancária/API.

### Chave PIX

1. Troque o modo para **Chave PIX**.
2. Informe tipo, chave e recebedor.
3. Finalize um pedido por PIX.
4. A tela final deve mostrar a chave e o total separadamente.

### Cartão por link manual

1. Em **Admin > Configurações**, habilite **Pagamento por cartão**.
2. Monte e finalize um pedido escolhendo **Cartão**.
3. A tela final deve informar que o link será enviado manualmente.
4. Clique em **Solicitar link de pagamento**.
5. O WhatsApp deve abrir com o número do pedido, total e pedido explícito do link.
6. A loja gera o link na adquirente/banco e o envia manualmente.

Resultado esperado: o FloriWeb não solicita nem armazena número de cartão, validade, CVV ou senha.


# Testes específicos da V2.6.0

## Áreas de entrega
1. Abra Admin > Entregas.
2. Confirme a lista padrão de Linhares.
3. Defina taxas diferentes para Centro e Interlagos.
4. Ative as duas áreas e salve.
5. Crie uma área de outra cidade e confirme que ela pode ser ativada.
6. Oculte uma área e confirme que ela desaparece do checkout público.

## CEP e associação de bairro
1. No checkout selecione Entrega.
2. Digite um CEP completo.
3. Aguarde a consulta automática.
4. Confirme rua, cidade e UF.
5. Se o bairro retornado corresponder ao nome/apelido de uma área ativa, ela deve ser selecionada.
6. Confira o card de confirmação da taxa.
7. Teste um CEP cujo bairro não esteja ativo: o pedido não pode ser finalizado até uma área válida ser escolhida.

## Segurança da taxa
No frontend, selecione uma área com taxa conhecida. O total deve incluir essa taxa. Depois valide no banco:

```sql
select order_number, delivery_zone_name, delivery_fee, subtotal, total
from orders
order by created_at desc
limit 5;
```

O `delivery_fee` deve ser o valor cadastrado em `delivery_zones`, e `total = subtotal + delivery_fee`.

## Formas de pagamento
1. Ative PIX, Cartão e Dinheiro.
2. Ative/desative também a Confirmação manual.
3. Reordene as opções no Admin.
4. Abra o checkout e confira a ordem.
5. Desative Dinheiro e confirme que ele desaparece.
6. Faça um pedido em Dinheiro e valide `orders.payment_method = 'cash'`.

## Confirmação de revisão
1. Preencha o checkout.
2. Não marque a caixa de revisão.
3. O botão Finalizar deve permanecer desabilitado.
4. Marque a caixa e finalize.
5. Confira `orders.review_confirmed = true`.

# Testes adicionais V2.7.0 — Admin Master e multi-loja

## Alteração de senha no painel da loja

1. Entre em `/admin`.
2. Abra Configurações.
3. Em Segurança, informe a senha atual.
4. Informe nova senha com 8+ caracteres e confirme.
5. Salve.
6. Saia do painel.
7. A senha antiga deve falhar.
8. A senha nova deve entrar normalmente.

## Admin Master

1. Execute a migration V2.7.
2. Cadastre seu UUID em `platform_admins`.
3. Abra `/admin-master/login`.
4. Confirme dashboard, Lojas e Planos.

## Criação de nova loja

1. Faça deploy da Edge Function `platform-create-store`.
2. Admin Master > Lojas > Nova loja.
3. Crie `Floricultura Teste A`, slug `floricultura-teste-a`.
4. Use um e-mail de teste válido.
5. Confirme no banco:

```sql
select id,slug,name,access_status,owner_email from stores where slug='floricultura-teste-a';
```

6. Confirme assinatura:

```sql
select ss.*,p.name
from store_subscriptions ss join plans p on p.id=ss.plan_id
where ss.store_id=(select id from stores where slug='floricultura-teste-a');
```

7. Confirme vínculo em `store_users`.
8. Abra `https://SEU-DOMINIO/floricultura-teste-a`.

## Isolamento de pedidos e carrinho

1. Abra Loja A e adicione um produto ao carrinho.
2. Abra Loja B no mesmo navegador.
3. O carrinho da Loja B deve estar vazio.
4. Gere um pedido na Loja A e outro na Loja B.
5. Usuário da Loja A não pode listar pedido da Loja B.
6. Usuário da Loja B não pode listar pedido da Loja A.

## Suspensão

1. Admin Master > Lojas > Gerenciar.
2. Mude Loja A para `Desativada`.
3. A URL pública deve ficar indisponível.
4. O usuário da loja não deve entrar em `/admin`.
5. Confirme que produtos e pedidos continuam no banco.
6. Reative como `Online`.
7. O acesso deve retornar com os mesmos dados.

## Troca de plano

1. Troque uma loja de Essencial para Profissional.
2. Confira `store_subscriptions.plan_id`.
3. Confira a mensalidade aplicada.
4. A loja deve continuar com o mesmo `store_id`; nenhum pedido deve ser movido ou copiado.

## URL por slug

Teste diretamente e com F5:

- `/floricultura-teste-a`
- `/floricultura-teste-a/produto/SLUG`
- `/floricultura-teste-a/carrinho`
- `/floricultura-teste-a/finalizar`

## Domínio próprio

1. Cadastre o hostname no Admin Master.
2. Configure o mesmo hostname para chegar ao Worker no Cloudflare.
3. Abra a raiz do domínio próprio.
4. O catálogo deve resolver a loja por `store_domains`.
5. `/produto`, `/carrinho` e `/finalizar` devem permanecer no domínio próprio.

# Complemento V2.9.0

A V2.9.0 adiciona testes obrigatórios para:

- e-mails de teste/temporários;
- erros de domínio de e-mail;
- criação por convite;
- criação com senha temporária;
- troca obrigatória no primeiro acesso;
- suspensão pública neutra;
- configuração Demo 30/7;
- aviso de Demo;
- vencimento e bloqueio automático;
- agendamento `pg_cron`;
- reativação de Demo;
- regressão multi-loja.

Siga `docs/TESTES_V2_9_0.md`.
