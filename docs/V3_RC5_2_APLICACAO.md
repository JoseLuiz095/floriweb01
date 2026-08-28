# FloriWeb V3 RC5.2 — aplicação

Esta atualização adiciona controle global da oferta Demo e recupera/garante o módulo de Analytics de conversão.

## Ordem

1. No Supabase SQL Editor, execute `supabase/releases/20260828_v3_rc5_2_bundle.sql` uma única vez.
2. Execute `supabase/tests/VALIDAR_V3_RC5_2.sql`. O primeiro JSON deve retornar `"version":"3.0.0-rc.5.2"` e `"ok":true`.
3. No frontend, execute `npm ci`, `npm run validate` e `npx wrangler deploy`.
4. Não é necessário redeploy das Edge Functions para esta versão.

## Demo

Em Admin Master → Planos existe agora a configuração `Disponibilidade: Habilitada/Desabilitada`, além da duração e aviso antecipado.

Desabilitar a Demo impede novas atribuições ao plano Demo, mas não corta uma demonstração já ativa. Isso evita interromper clientes no meio de uma avaliação. Uma Demo existente pode ser gerenciada, encerrada ou migrada para plano pago normalmente.

## Analytics

O SQL recria de forma idempotente:

- `public.analytics_events`;
- `public.track_public_event_v3(...)`;
- `public.get_store_analytics_v3(...)`;
- grants necessários;
- atualização do diagnóstico Master;
- `NOTIFY pgrst, 'reload schema'` para atualizar o schema cache do PostgREST.

A mensagem técnica `Telemetria anônima · sem PII` foi substituída por uma explicação de privacidade mais precisa. O funil usa um identificador aleatório de navegação e eventos de uso da vitrine; não recebe nome, telefone, e-mail, endereço, mensagem do cartão ou observações. Os dados pessoais necessários ao pedido continuam armazenados na área de Pedidos.
