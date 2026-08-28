# Atualização FloriWeb V2.6.0

Este guia é para quem já está com a V2.5.0 publicada no Supabase/Cloudflare.

## 1. Faça backup

No Supabase, confirme que o projeto está saudável e, antes de alterações críticas, mantenha um backup/export conforme sua política operacional.

## 2. Execute somente a migration nova

No Supabase: **SQL Editor > New query**. Execute o conteúdo de:

```text
supabase/migrations/202608260007_delivery_zones_cash_checkout.sql
```

Não reaplique as migrations anteriores em uma instalação já atualizada.

## 3. Valide o banco

```sql
select column_name
from information_schema.columns
where table_schema='public' and table_name='stores'
  and column_name in ('cash_payment_enabled','confirmation_payment_enabled','payment_method_order');

select count(*) as areas_linhares
from public.delivery_zones
where lower(city)='linhares' and upper(state)='ES';

select column_name
from information_schema.columns
where table_schema='public' and table_name='orders'
  and column_name in ('delivery_zone_id','delivery_zone_name','delivery_fee','review_confirmed');
```

Para uma loja de Linhares existente, a lista padrão deve conter 31 áreas. Elas entram desativadas e com taxa zero para que nenhum valor incorreto seja oferecido ao cliente.

## 4. Configure as taxas

Entre em:

```text
Admin > Entregas
```

Para cada bairro realmente atendido:
1. informe a taxa;
2. ajuste a ordem se necessário;
3. marque **Ativa**;
4. clique em **Salvar alterações**.

Você pode adicionar bairros, distritos ou cidades fora de Linhares no painel lateral. Use **Apelidos** para nomes alternativos que o retorno do CEP possa trazer.

## 5. Configure pagamentos

Em `Admin > Configurações`:
- ative/desative **Confirmar com a floricultura**;
- configure PIX;
- ative/desative Cartão;
- ative/desative **Dinheiro**;
- em **Ordem no checkout**, use as setas para definir a sequência.

O sistema não permite salvar sem pelo menos uma forma de pagamento disponível.

## 6. Publique o código

```bash
git add .
git commit -m "feat: atualiza FloriWeb para v2.6.0"
git push origin main
```

O Cloudflare Worker deve executar `npm run build` e `wrangler deploy`.

## 7. Teste em produção

### CEP
- monte um carrinho;
- escolha Entrega;
- informe um CEP válido;
- confira rua/cidade/UF preenchidos;
- confirme se o bairro foi associado;
- confira o card com a taxa.

Se o bairro retornado não estiver ativo, o sistema deve pedir seleção manual e não permitir finalizar sem uma área válida.

### Taxa
- selecione um bairro com taxa conhecida;
- confira `Produtos + Entrega = Total`;
- finalize;
- valide no banco:

```sql
select order_number, delivery_zone_name, delivery_fee, subtotal, total, review_confirmed, payment_method
from orders
order by created_at desc
limit 10;
```

### Dinheiro e ordem
- altere a ordem no Admin;
- recarregue o checkout;
- confira a mesma ordem;
- desative Dinheiro e confirme que desaparece;
- ative e faça um pedido de teste.

### Revisão obrigatória
Tente finalizar sem marcar a confirmação. O botão deve permanecer indisponível e a RPC também rejeita requisições sem `review_confirmed=true`.
