# Atualização FloriWeb 2.4.0

## 1. Banco Supabase

Se o banco já está na V2.3.x, execute somente:

```sql
-- conteúdo de supabase/migrations/202608260005_addon_images.sql
alter table public.addons
  add column if not exists image_url text,
  add column if not exists image_storage_path text;
```

Não é necessário recriar as tabelas.

## 2. Variáveis no Cloudflare

No projeto publicado, confirme no ambiente de produção:

```text
VITE_SUPABASE_URL=https://SEU-PROJETO.supabase.co
VITE_SUPABASE_ANON_KEY=SUA_CHAVE_PUBLICA
VITE_DEFAULT_STORE_SLUG=floriweb-demo
VITE_APP_ENV=production
```

As variáveis `VITE_*` são lidas no momento do build. Depois de alterar qualquer uma delas, faça um novo deploy.

Nunca coloque `service_role` no frontend.

## 3. Horários

Abra:

```text
Admin > Configurações > Horário de atendimento
```

Ative os dias, informe abertura e fechamento e selecione o fuso horário. Salve.

A loja pública passa a exibir `Aberto` ou `Fechado` automaticamente.

## 4. Imagens dos adicionais

Abra:

```text
Admin > Adicionais
```

Edite um adicional, selecione a imagem e salve. A imagem é enviada ao bucket `store-assets` no caminho:

```text
stores/{store_id}/addons/{addon_id}/...
```

As policies já existentes do bucket `store-assets` atendem esse caminho.

## 5. Testes rápidos após o deploy

1. Abra a home e confira se não aparece mensagem de demonstração.
2. Altere um horário no admin e salve; a aba pública deve atualizar automaticamente ou, no máximo, ao recarregar.
3. Teste `Aberto/Fechado` alterando temporariamente o horário para uma faixa que inclua/exclua a hora atual.
4. Entre em um produto e valide a imagem dos adicionais.
5. Adicione um produto ao carrinho.
6. Clique `Continuar comprando` e confirme retorno à home.
7. Volte ao carrinho e clique `Continuar`; deve carregar `/finalizar` imediatamente.
8. Finalize um pedido e confirme a tela `/pedido/{id}`.
9. Teste F5 em `/produto/...`, `/carrinho`, `/finalizar`, `/pedido/...` e `/admin/login`.
