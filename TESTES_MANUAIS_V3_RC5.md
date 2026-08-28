# FloriWeb V3 RC5 — Roteiro manual de homologação

Objetivo: validar o produto como se fosse um cliente real, com atenção especial ao fluxo **Registrar pedido → WhatsApp → painel Admin**.

## 1. Pré-condições

Use uma loja de teste ativa, com pelo menos 1 categoria, 2 produtos ativos, WhatsApp válido, entrega e retirada configuradas, ao menos 1 forma de pagamento ativa e Turnstile funcionando. Deixe o Admin aberto em outra aba ou outro navegador na tela `/admin/pedidos`.

## 2. Teste crítico — pedido e WhatsApp

1. Abra a vitrine em janela anônima.
2. Adicione um produto ao carrinho.
3. Vá ao checkout e preencha todos os campos obrigatórios.
4. Conclua o Turnstile e marque a confirmação de revisão.
5. Clique **Registrar pedido**.
6. Confirme que a próxima tela mostra **Pedido registrado!**, um número de pedido e o aviso **Salvo no FloriWeb**.
7. **Antes de clicar no WhatsApp**, volte ao Admin `/admin/pedidos` e aguarde até 15 segundos ou clique em **Atualizar**.
8. O pedido deve aparecer com status **Pedido realizado**.
9. Volte à tela do cliente e clique **Abrir WhatsApp...**.
10. Confirme que o WhatsApp abre com o número do pedido, produtos, total, entrega/retirada e forma de pagamento.
11. Volte ao Admin e aguarde até 15 segundos ou clique **Atualizar**.
12. O mesmo pedido deve mudar para **WhatsApp aberto**. Não deve existir um segundo pedido.

**Resultado obrigatório:** o pedido existe no Admin antes do clique do WhatsApp. O clique apenas altera o status do pedido já criado.

### Se falhar

Abra DevTools → Network e repita o fluxo. Verifique:

- `POST /functions/v1/public-checkout` deve retornar HTTP 200 com `orderId`, `orderNumber` e `total`;
- depois do clique no WhatsApp, `POST /rest/v1/rpc/mark_public_order_whatsapp_clicked` deve retornar HTTP 2xx;
- se o primeiro falhar, copie Response + Status;
- se apenas o segundo falhar, o pedido deve continuar visível como **Pedido realizado**.

## 3. Duplicidade / clique duplo

Clique rapidamente duas vezes em **Registrar pedido** ou simule conexão lenta pelo DevTools. Deve existir apenas 1 pedido. O botão precisa ficar desabilitado durante o envio e o requestId idempotente deve impedir duplicidade.

## 4. Turnstile

- sem concluir o Turnstile, o botão não deve finalizar;
- após expirar o desafio, deve pedir nova validação;
- o checkout não pode criar pedido se o backend rejeitar o token.

## 5. Entrega

Teste CEP válido, bairro atendido, taxa paga, taxa grátis e bairro não atendido. O total do Admin deve bater com o total do checkout. Endereço, cidade e UF precisam corresponder à área selecionada.

## 6. Retirada

Selecione retirada. Campos de entrega não devem bloquear a finalização e a taxa deve ser zero.

## 7. Pagamentos

Teste separadamente confirmação com a loja, PIX, cartão e dinheiro — somente os habilitados. Em PIX, valide chave/copia-e-cola; em cartão, confirme que o sistema não solicita dados do cartão; em dinheiro, confira o texto de troco.

## 8. Carrinho e loja

- atualize a página com itens no carrinho: eles devem permanecer;
- troque para outra loja: o carrinho não pode misturar itens;
- produto inativo/indisponível não deve ser comprável;
- pedido abaixo do mínimo deve ser bloqueado.

## 9. Loja suspensa / Demo vencida

Suspenda uma loja pelo Master. A vitrine deve ficar indisponível, o Admin da loja não deve operar e o checkout não pode criar novos pedidos. Reative e confirme retorno normal.

## 10. Admin

Teste Dashboard, Primeiros passos, Produtos, Categorias, Adicionais, Pedidos, Entregas, Analytics, Plano e Configurações. Em `/admin/pedidos`, confirme atualização automática a cada 15s e ao voltar para a aba.

## 11. Admin Master + MFA

- login Master sem AAL2 deve redirecionar ao MFA;
- após TOTP válido, Dashboard/lojas/planos/diagnóstico devem abrir;
- usuário comum não pode acessar `/admin-master`.

## 12. Multi-loja

Com um usuário vinculado a duas lojas, alterne pelo seletor. Produtos, pedidos, configurações e analytics não podem se misturar.

## 13. Analytics

Faça: vitrine → produto → carrinho → checkout → pedido → WhatsApp. Depois confira Analytics. Nenhuma telemetria deve armazenar nome, telefone, e-mail, endereço, mensagem do cartão ou observações.

## 14. Responsividade visual

Valide pelo menos:

- desktop 1366×768;
- notebook menor 1280×720;
- tablet 768×1024;
- celular 390×844;
- celular estreito 360×800.

Verifique especialmente: menu Admin, filtros Master, cards de produto, dock do carrinho, resumo/CTA fixo do checkout, Turnstile e tela de sucesso.

## 15. Acessibilidade básica

Percorra a interface usando apenas Tab/Shift+Tab. O foco deve estar visível. Teste Enter/Espaço em botões, zoom 200%, preferência do sistema por reduzir movimento e textos longos em produto/loja.

## 16. Recuperação de senha / primeiro acesso

Teste login, esqueci senha, redefinição e senha temporária. O primeiro acesso deve obrigar troca de senha e depois encaminhar para Primeiros passos.

## 17. Critério para liberar para venda

Liberar somente se: build passar; `npm run validate` passar; pedido crítico do item 2 passar em desktop e celular; não houver duplicidade; loja suspensa bloquear checkout; MFA Master estiver funcionando; e não houver mistura entre lojas.
