# Testes manuais — FloriWeb V3 RC5.2

## 1. Configuração global da Demo

1. Entre no Admin Master com MFA.
2. Vá em **Planos**.
3. Confirme o bloco **Plano Demo → Período de avaliação**.
4. Defina `Disponibilidade = Habilitada`, `Duração = 15` e um aviso menor, por exemplo `5`.
5. Salve e recarregue a página. Os valores devem permanecer.
6. Vá em **Lojas → Nova loja**. O plano Demo deve aparecer.
7. Volte a **Planos**, altere para `Disponibilidade = Desabilitada` e salve.
8. Volte a **Lojas → Nova loja**. O plano Demo não deve mais aparecer e deve existir um aviso explicando que novas Demos estão desabilitadas.
9. Se já existir uma loja em Demo, ela deve continuar visível e acessível até o vencimento configurado.
10. Na loja Demo existente, **Gerenciar** deve continuar permitindo alterar o fim da demonstração ou migrar para plano pago.
11. Em uma loja paga, o plano Demo não deve aparecer como opção de downgrade enquanto a oferta estiver desabilitada.

## 2. Analytics de conversão

1. Depois de aplicar o SQL RC5.2, abra **Admin → Análises** em uma loja cujo plano tenha Relatórios habilitado.
2. A mensagem `Could not find the function public.get_store_analytics_v3...` não deve aparecer.
3. O bloco de funil deve carregar, mesmo que todos os valores estejam inicialmente em zero.
4. Abra a vitrine em janela anônima e navegue por pelo menos um produto.
5. Adicione um produto ao carrinho e abra o checkout.
6. Finalize um pedido de teste e, na tela de sucesso, abra o WhatsApp.
7. Volte a **Análises** e recarregue. O funil deve começar a refletir sessão, visualização de produto, carrinho, checkout, pedido e WhatsApp.
8. Abra **Admin Master → Diagnóstico**. `Analytics de conversão` deve aparecer como **Ativo**.

## 3. Privacidade do funil

1. Em **Análises**, abra **Privacidade das métricas**.
2. O texto deve explicar que o funil usa identificador aleatório de navegação e eventos de uso da vitrine.
3. Não deve usar a sigla técnica `PII` na interface do cliente.
4. Confirme no SQL Editor, se desejar, que `public.analytics_events` contém apenas IDs técnicos, evento e horário:

```sql
select * from public.analytics_events order by occurred_at desc limit 20;
```

A tabela não deve conter nome, telefone, e-mail, endereço, mensagem do cartão ou observações.

## 4. Cron da Demo

Em **Admin Master → Diagnóstico**, o item **Agendamento automático da Demo** deve mostrar `Ativo · 15 * * * *` quando o job estiver ativo.

Confirmação direta:

```sql
select jobid,jobname,schedule,command,active
from cron.job
where jobname='floriweb-expire-demo-trials';
```
