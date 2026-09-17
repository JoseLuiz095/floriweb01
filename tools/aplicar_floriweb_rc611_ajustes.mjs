import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const pkgPath = path.join(root, 'package.json');
const lockPath = path.join(root, 'package-lock.json');
const stylesPath = path.join(root, 'src', 'styles.css');
const diagnosticsPath = path.join(root, 'src', 'pages', 'master', 'Diagnostics.tsx');

const fail = (message) => {
  console.error(`FAIL ${message}`);
  process.exit(1);
};

const ok = (message) => console.log(`OK   ${message}`);

if (!fs.existsSync(pkgPath)) fail('package.json nao encontrado. Execute na raiz do FloriWeb.');
if (!fs.existsSync(stylesPath)) fail('src/styles.css nao encontrado.');
if (!fs.existsSync(diagnosticsPath)) fail('src/pages/master/Diagnostics.tsx nao encontrado.');

const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
if (pkg.name !== 'floriweb') fail(`Projeto incorreto: package name = ${pkg.name || '(vazio)'}`);

const stamp = new Date().toISOString().replace(/[-:TZ.]/g, '').slice(0, 14);
const backupRoot = path.join(root, `_backup_rc611_usuario_interacoes_${stamp}`);

const backupFile = (absolutePath) => {
  const relative = path.relative(root, absolutePath);
  const target = path.join(backupRoot, relative);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.copyFileSync(absolutePath, target);
};

backupFile(pkgPath);
if (fs.existsSync(lockPath)) backupFile(lockPath);
backupFile(stylesPath);
backupFile(diagnosticsPath);
ok(`Backup criado: ${path.basename(backupRoot)}`);

// Version alignment.
pkg.version = '3.0.0-rc.6.11';
fs.writeFileSync(pkgPath, `${JSON.stringify(pkg, null, 2)}\n`, 'utf8');
ok('package.json ajustado para 3.0.0-rc.6.11');

if (fs.existsSync(lockPath)) {
  const lock = JSON.parse(fs.readFileSync(lockPath, 'utf8'));
  lock.version = '3.0.0-rc.6.11';
  if (lock.packages && lock.packages['']) lock.packages[''].version = '3.0.0-rc.6.11';
  fs.writeFileSync(lockPath, `${JSON.stringify(lock, null, 2)}\n`, 'utf8');
  ok('package-lock.json alinhado para 3.0.0-rc.6.11');
}

// Visual hotfix: solid user avatar background in Admin and Admin Master.
let css = fs.readFileSync(stylesPath, 'utf8');
const visualStart = '/* FloriWeb RC6.11 - avatar de usuario com fundo solido */';
const visualEnd = '/* fim FloriWeb RC6.11 - avatar de usuario */';
const visualRegex = new RegExp(`${visualStart.replace(/[.*+?^${}()|[\\]\\]/g, '\\$&')}[\\s\\S]*?${visualEnd.replace(/[.*+?^${}()|[\\]\\]/g, '\\$&')}\\s*`, 'g');
css = css.replace(visualRegex, '');
css = `${css.trimEnd()}\n\n${visualStart}\n.admin-user>span,\n.master-admin-mini>span {\n  background: var(--green) !important;\n  color: #fff !important;\n}\n${visualEnd}\n`;
fs.writeFileSync(stylesPath, css, 'utf8');
ok('Fundo do usuario ajustado no Admin e Admin Master');

// Diagnostics hotfix: the business-state message below is expected and must not
// be shown as a critical failure. The database event remains untouched.
let diagnostics = fs.readFileSync(diagnosticsPath, 'utf8');
const helperMarker = '// FloriWeb RC6.11 - cobranca pendente nao e falha critica';

if (!diagnostics.includes(helperMarker)) {
  const helper = `\n${helperMarker}\nconst isExpectedSubscriptionPending = (item: unknown) => {\n  const text = JSON.stringify(item ?? {})\n    .normalize('NFD')\n    .replace(/[\\u0300-\\u036f]/g, '')\n    .toLowerCase();\n  return text.includes('subscription charge create')\n    && text.includes('ja existe um comprovante aguardando analise do admin master');\n};\n\nconst sanitizeDiagnosticResult = (value: PlatformSystemCheck): PlatformSystemCheck => {\n  const clone = { ...value } as PlatformSystemCheck & Record<string, unknown>;\n  for (const key of Object.keys(clone)) {\n    if (!/(fail|error)/i.test(key)) continue;\n    const current = clone[key];\n    if (Array.isArray(current)) {\n      clone[key] = current.filter((item) => !isExpectedSubscriptionPending(item));\n    }\n  }\n  return clone;\n};\n`;

  const exportToken = 'export default function MasterDiagnostics';
  const exportIndex = diagnostics.indexOf(exportToken);
  if (exportIndex < 0) fail('Nao encontrei MasterDiagnostics para inserir o filtro de falhas.');
  diagnostics = `${diagnostics.slice(0, exportIndex)}${helper}\n${diagnostics.slice(exportIndex)}`;
}

if (!diagnostics.includes('setResult(sanitizeDiagnosticResult(databaseResult.value))')) {
  const before = diagnostics;
  diagnostics = diagnostics.replace(
    /setResult\(\s*databaseResult\.value\s*\)/g,
    'setResult(sanitizeDiagnosticResult(databaseResult.value))',
  );
  if (diagnostics === before) {
    fail('Nao encontrei o carregamento do diagnostico esperado. O arquivo foi preservado no backup; nenhum filtro incompleto sera gravado.');
  }
}

fs.writeFileSync(diagnosticsPath, diagnostics, 'utf8');
ok('Estado de cobranca pendente removido da lista de falhas criticas');

console.log('');
console.log('FloriWeb RC6.11 ajustado com sucesso.');
console.log(`Backup: ${path.basename(backupRoot)}`);
