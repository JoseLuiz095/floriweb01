# FloriWeb V3 RC1 - validação de build

Data: 2026-08-27

## Validado neste pacote

- `npm run smoke`: 66 verificações estruturais aprovadas.
- Imports relativos: 61 arquivos TS/TSX verificados.
- Transpilação sintática: 60 arquivos TS/TSX aprovados.
- CSS com chaves balanceadas.
- O build completo da versão imediatamente anterior (`3.0.0-preflight.2`) foi executado pelo usuário com Vite 8.2.1 e 1912 módulos transformados sem erro.
- As alterações RC1 adicionam RPC consolidada, hardening do checkout, rate limit, MFA/AAL2 no banco e entitlements comerciais de plano; a sintaxe TS/TSX foi revalidada.

## Limitação deste ambiente

O `registry.npmjs.org` continua indisponível por DNS (`EAI_AGAIN`) neste ambiente de geração. Por isso não foi possível instalar `node_modules`, gerar o `package-lock.json` nem repetir o typecheck/build completo da RC1. A tentativa offline também falhou porque o cache não contém todas as dependências.

Na máquina de desenvolvimento, que já conseguiu compilar o preflight.2, execute antes do deploy:

```text
npm install
npm run validate
npm run build
```

Depois do `npm install`, mantenha o `package-lock.json` gerado no repositório para builds comerciais reproduzíveis.

## Banco

Antes do frontend RC1 em produção, aplique e valide o bundle conforme `docs/V3_RC1_APLICACAO.md`.
