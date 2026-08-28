# Analytics V3 — escopo comercial e privacidade

## Indicadores desejados

A V3 foi desenhada para suportar: visualizações, visitantes/sessões anônimas, produtos vistos, adições ao carrinho, carrinhos abandonados, checkouts iniciados, pedidos concluídos, conversão, ticket médio, receita, produtos que mais vendem, produtos vistos que não vendem, forma de pagamento, entrega × retirada, bairros/zonas, dias da semana e horários.

## Dados proibidos na telemetria

Não registrar: nome do visitante, telefone, e-mail, endereço, mensagem do cartão, observações do pedido, assinatura do cartão ou qualquer conteúdo livre/pessoal.

## Identificador de sessão

Usar UUID aleatório de curta duração no navegador, sem fingerprinting. O ID serve apenas para agregar o funil de uma visita e deve ter retenção definida antes da migration definitiva.

## Estado deste pacote

A tela `/admin/analytics` usa apenas `orders`, que já existe. A telemetria de navegação está propositalmente desligada. O arquivo `supabase/drafts/202608270110_v3_analytics_blueprint_DRAFT.sql` é somente um blueprint e não contém policies de produção.
