import fs from 'node:fs';

let failures = 0;
const check = (label, condition) => {
  if (condition) console.log(`OK   ${label}`);
  else { console.log(`FAIL ${label}`); failures += 1; }
};

const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
const css = fs.readFileSync('src/styles.css', 'utf8');
const lock = fs.existsSync('package-lock.json') ? JSON.parse(fs.readFileSync('package-lock.json', 'utf8')) : null;
const diagnostics = fs.readFileSync('src/pages/master/Diagnostics.tsx', 'utf8');

check('Projeto FloriWeb', pkg.name === 'floriweb');
check('Versao 3.0.0-rc.6.11', pkg.version === '3.0.0-rc.6.11');
if (lock) check('package-lock alinhado', lock.version === '3.0.0-rc.6.11' && (!lock.packages?.[''] || lock.packages[''].version === '3.0.0-rc.6.11'));
check('Avatar Admin com fundo solido', css.includes('FloriWeb RC6.11 - avatar de usuario com fundo solido') && css.includes('.admin-user>span'));
check('Avatar Master com fundo solido', css.includes('.master-admin-mini>span'));
check('Filtro de cobranca pendente existe', diagnostics.includes('isExpectedSubscriptionPending'));
check('Diagnostico aplica o filtro', diagnostics.includes('setResult(sanitizeDiagnosticResult(databaseResult.value))'));
check('Mensagem esperada reconhecida', diagnostics.includes("ja existe um comprovante aguardando analise do admin master"));

if (failures) {
  console.log(`\n${failures} falha(s) na validacao.`);
  process.exit(1);
}

console.log('\nValidacao estrutural concluida sem falhas.');
