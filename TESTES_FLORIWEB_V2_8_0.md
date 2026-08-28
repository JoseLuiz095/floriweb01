# Testes FloriWeb V2.8.0

## A. Frontend

1. `npm run smoke` deve terminar sem falhas.
2. `npm run typecheck` deve terminar sem erros.
3. `npm run build` deve gerar `dist/`.
4. Testar F5 em `/`, `/admin/login`, `/admin-master/login` e `/{slug}/carrinho`.

## B. Admin Master

1. Entrar em `/admin-master/login` com usuário presente em `platform_admins`.
2. Abrir `/admin-master/diagnostico`.
3. Banco deve aparecer conectado.
4. Edge Function `platform-create-store` deve aparecer publicada e respondendo.
5. Se estiver vermelha, não prosseguir com Nova Loja antes do deploy.

## C. Criação de loja

1. Criar Loja B com e-mail novo.
2. Confirmar `stores`, `store_subscriptions`, `store_users` e categorias iniciais.
3. Confirmar convite no Auth.
4. Criar Loja C reutilizando e-mail que já existe no Auth.
5. Confirmar que nenhum segundo usuário Auth duplicado é criado.
6. Confirmar vínculo adicional em `store_users`.

## D. Suspensão

1. Suspender Loja B.
2. Confirmar que `stores.active` permanece `true`.
3. Confirmar `access_status='suspended'`.
4. Confirmar produtos, pedidos, imagens e `store_users` preservados.
5. Confirmar loja pública bloqueada.
6. Confirmar painel da loja bloqueado.
7. Reativar e confirmar que os mesmos dados reaparecem.

## E. Isolamento multi-loja

1. Criar pedido na Loja A.
2. Criar pedido diferente na Loja B.
3. Entrar no Admin da Loja A e confirmar que só vê pedidos A.
4. Entrar no Admin da Loja B e confirmar que só vê pedidos B.
5. Repetir com produtos e adicionais.

## F. Meu plano

1. Abrir `/admin/plano`.
2. Confirmar plano atual destacado.
3. Confirmar limites de produtos, categorias, fotos, adicionais e usuários.
4. Confirmar Profissional marcado como melhor custo-benefício.
5. Confirmar Business exibido apenas como projeto personalizado e referência de preço.
6. Confirmar que a tela não altera o plano diretamente.

## G. Loja e checkout

1. Produto → variação → adicional → carrinho.
2. Entrega → CEP → bairro → taxa.
3. Retirada sem endereço obrigatório.
4. PIX com total incluindo entrega.
5. Cartão por link manual.
6. Dinheiro.
7. Confirmação obrigatória de revisão.
8. Pedido registrado e carrinho limpo após sucesso.

## H. Senha

1. Esqueci minha senha.
2. Redefinição via e-mail.
3. Admin → Configurações → alteração de senha com senha atual.

## I. SQL de verificação

Execute também:

```text
supabase/tests/VALIDAR_V2_7_1.sql
```

Não há migration nova na 2.8.0.
