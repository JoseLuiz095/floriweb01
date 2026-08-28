# FloriWeb — Design Direction

## Direção

Produto digital contemporâneo, acolhedor e comercial, com referências botânicas discretas. A interface deve parecer especializada para floriculturas sem depender de ornamentos florais literais em toda tela.

## Personalidade visual

- natural;
- confiável;
- organizada;
- premium acessível, não luxuosa ou elitista;
- clara para usuários pouco técnicos.

## Cor

Base atual: verde profundo com superfícies quentes/off-white.

- Verde principal: ações, estados positivos, foco e navegação ativa.
- Off-white: plano de fundo para reduzir aparência de dashboard genérico.
- Rose/âmbar: apenas para significado semântico, promoção ou atenção.
- Evitar gradientes decorativos fortes e excesso de cinza neutro.

## Tipografia

- Interface operacional: `Segoe UI Variable` / `Segoe UI` / Aptos fallback.
- Storefront e títulos de compra: serif editorial do sistema (`Iowan Old Style`, Palatino, Georgia) como contraste de marca.
- Não importar fontes externas apenas por estética; desempenho e CSP têm prioridade.

## Forma e espaçamento

- Raio moderado, geralmente 10–18 px.
- Cards somente quando agrupam informação ou ação; evitar card dentro de card.
- Elevação leve e rara.
- Separadores, whitespace e alinhamento devem fazer mais trabalho que sombras.

## Admin

- Sidebar agrupada por contexto: Operação, Catálogo e Conta.
- Mostrar estado da loja e plano sem competir com o conteúdo principal.
- Priorizar ações frequentes e sinais de prontidão.
- Em 1366x768, métricas principais devem aparecer acima da dobra sempre que possível.

## Storefront

- Produto e imagem são protagonistas.
- Filtros/categorias precisam funcionar com uma mão no celular.
- Carrinho deve permanecer fácil de reencontrar após adicionar itens.
- Não transformar a vitrine em uma landing page cheia de seções institucionais.

## Checkout

- Reduzir ansiedade e ambiguidade.
- Resumo e total sempre fáceis de localizar.
- No mobile, CTA de finalizar pode ficar persistente sem esconder conteúdo.
- Comunicação de privacidade deve ser curta e específica.

## Admin Master

- Deve funcionar como cockpit comercial.
- Priorizar demos, implantação, clientes pagantes, suspensões e atenção comercial.
- Filtros devem responder à pergunta “quem precisa de ação agora?”.

## Movimento

- Transições entre 120–220 ms.
- Sem bounce/elastic.
- Animação somente para feedback, foco, mudança de estado ou continuidade espacial.

## Anti-padrões

- não usar cards aninhados em excesso;
- não criar ícones dentro de quadrados arredondados por padrão em toda seção;
- não usar roxo/azul genérico de SaaS;
- não sacrificar contraste por estética;
- não aumentar bundle com bibliotecas visuais sem necessidade;
- não alterar comportamento funcional durante uma passada do Impeccable.
