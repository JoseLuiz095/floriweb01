# Teste comercial ponta a ponta — RC3

Use este roteiro antes de apresentar o FloriWeb a um cliente.

## Fluxo Master → cliente

1. Admin Master entra com MFA.
2. Cria uma floricultura Demo com responsável.
3. Responsável recebe convite ou senha temporária.
4. Primeiro acesso obriga definição da senha definitiva quando aplicável.
5. Usuário entra em `Primeiros passos`.

## Implantação da floricultura

6. Configura identidade, cidade/UF e WhatsApp.
7. Cria categoria.
8. Cria e publica produto com imagem/preço.
9. Configura pagamento.
10. Configura retirada ou área de entrega.
11. Checklist deve alcançar 100%.

## Compra

12. Abra a vitrine em janela anônima.
13. Abra produto e adicione ao carrinho.
14. Avance para checkout.
15. Preencha parcialmente e atualize a página: dados operacionais devem permanecer.
16. Finalize com Turnstile.
17. Banco deve gerar apenas um pedido para a tentativa.
18. Tela final deve apresentar total e instrução da forma de pagamento.
19. Botão WhatsApp deve abrir mensagem pronta.
20. Pedido deve aparecer no Admin.

## Analytics — planos com reports

21. Confirme eventos de vitrine/produto/carrinho/checkout/pedido/WhatsApp.
22. Confirme ausência de nome, telefone, e-mail, endereço e conteúdo pessoal na telemetria.

## Critério para demonstração comercial

A loja está pronta para demonstração quando:

- checklist = 100%;
- um pedido ponta a ponta foi concluído;
- WhatsApp abriu corretamente;
- pedido apareceu no Admin;
- troca de loja não mistura dados;
- loja suspensa deixa de aceitar vitrine/pedidos;
- Master continua exigindo MFA.
