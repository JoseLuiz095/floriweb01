# FloriWeb — Product Context

FloriWeb é uma plataforma SaaS multiempresa para floriculturas publicarem catálogo, receberem pedidos e administrarem sua operação digital sem depender de um e-commerce complexo.

## Público principal

- dono(a) de floricultura que precisa publicar produtos rapidamente;
- equipe administrativa da floricultura;
- cliente final que acessa a vitrine pelo celular e conclui o pedido pelo WhatsApp;
- Admin Master responsável por criar lojas, planos, demos, suspensão e acompanhamento comercial.

## Proposta de valor

A experiência deve transmitir que a floricultura consegue começar a vender online com baixa fricção, mantendo identidade própria, catálogo organizado e checkout simples. O produto não deve parecer um ERP genérico nem um marketplace impessoal.

## Superfícies prioritárias

1. Admin da floricultura: clareza operacional, onboarding e manutenção rápida do catálogo.
2. Storefront: foco em descoberta de produtos, confiança e conversão mobile.
3. Checkout: baixa ansiedade, revisão clara e CTA de finalização sempre evidente.
4. Admin Master: gestão comercial das lojas, demos, implantação, clientes pagantes e atenção comercial.

## Regras funcionais que o design não pode alterar

- isolamento por loja e regras de plano;
- Auth/MFA/AAL2;
- regras de preço, pedido, Turnstile e rate limit;
- analytics e privacidade;
- chamadas de API, Supabase e Edge Functions;
- lógica de domínio, pagamento, entrega e checkout.

## Critérios de sucesso visual

- usável em 1366x768 sem excesso de scroll ou cartões desnecessários;
- excelente em mobile próximo de 390x844;
- hierarquia visual óbvia em até 3 segundos;
- CTAs comerciais claros sem aparência agressiva;
- acessibilidade, contraste e estados de foco preservados;
- sensação de produto profissional, confiável e específico para floricultura.
