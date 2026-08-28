# FloriWeb 3.0.0 RC3 — aplicação

A RC3 é uma atualização **somente de frontend/UX** sobre a RC2.

## Pré-requisito

O ambiente deve estar com a RC2 já validada:

- `public-checkout` publicada;
- Turnstile configurado;
- `platform-create-store` publicada;
- `VALIDAR_V3_RC2.sql` retornando `ok=true`;
- build/deploy Cloudflare funcionando.

## Atualização

1. Substitua o projeto local pela pasta da RC3.
2. Preserve suas variáveis de ambiente locais, se houver.
3. Execute:

```bat
npm install
npm run validate
npm run build
npx wrangler deploy
```

Não é necessário executar migration, bundle SQL ou redeploy das Edge Functions apenas para instalar a RC3.

## O que testar

### Primeiro acesso
1. Entre com um usuário marcado para troca de senha.
2. Defina a senha definitiva.
3. Confirme que o sistema direciona para `/admin/primeiros-passos`.

### Onboarding
1. Confira o percentual de implantação.
2. Valide os seis atalhos: identidade, WhatsApp, categoria, produto, pagamento e entrega/retirada.
3. Confirme que “Fazer pedido de teste” é liberado após concluir os requisitos.
4. Teste “Copiar link” e “Abrir vitrine”.

### Vitrine
1. Confirme a faixa comercial abaixo das categorias.
2. Confira entrega/retirada, pedido mínimo e formas de pagamento.

### Checkout
1. Preencha parte do checkout.
2. Atualize a página.
3. Confirme que dados operacionais retornam.
4. Confirme que mensagem do cartão, assinatura e observações não são restauradas.
5. Finalize o pedido e confirme que o rascunho é removido.

## Banco

A versão de backend permanece RC2. Não execute novamente `20260827_v3_rc2_bundle.sql` em um ambiente onde ele já foi aplicado.
