# Atualizar FloriWeb para V2.5.0

## 1. Código
Atualize o repositório com os arquivos desta versão e faça novo deploy no Cloudflare.

## 2. Banco de dados
Se seu Supabase já possui as migrations até `202608260005_addon_images.sql`, execute apenas:

```text
supabase/migrations/202608260006_plan_active_limits.sql
```

No Supabase: **SQL Editor > New query**, cole o conteúdo da migration e execute.

### O que muda
- BASIC/Essencial: 15 produtos ativos, 3 imagens/produto.
- PRO/Profissional: 40 produtos ativos, 6 imagens/produto.
- PREMIUM: 100 produtos ativos, 10 imagens/produto.
- Produtos ocultos deixam de consumir o limite do plano.

## 3. Recuperação de senha no Supabase
Em **Authentication > URL Configuration** configure:

- Site URL: a URL de produção da aplicação.
- Redirect URL permitida: `https://SEU-DOMINIO/admin/redefinir-senha`

Exemplo:

```text
https://floriweb.joseluizacama.workers.dev/admin/redefinir-senha
```

Em produção, configure também um SMTP próprio no Supabase para envio confiável dos e-mails de recuperação.

## 4. Cloudflare
Esta versão não usa `public/_redirects` porque o deploy atual é feito via Cloudflare Worker/Static Assets. Mantenha o fallback SPA do Wrangler (`not_found_handling: single-page-application`).

## 5. Testes mínimos
1. Login > Esqueceu sua senha.
2. Solicitar recuperação para um e-mail de administrador.
3. Abrir o link recebido e definir nova senha.
4. Fazer login com a nova senha.
5. Criar produtos ocultos acima do limite do plano: deve permitir.
6. Tentar ativar produto acima do limite: deve bloquear.
7. Desativar um ativo e ativar outro: deve permitir.
8. Abrir Admin > Categorias em desktop e mobile.
9. Fazer um pedido com 3 produtos e verificar o resumo no checkout.
10. Recarregar `/finalizar` e `/admin/login` no domínio Cloudflare.
