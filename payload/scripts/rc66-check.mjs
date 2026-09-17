import fs from 'node:fs';

const read = (path) => fs.readFileSync(path, 'utf8');
const exists = (path) => fs.existsSync(path);
let failures = 0;

function ok(label, condition) {
  if (condition) console.log(`OK   ${label}`);
  else { console.log(`FAIL ${label}`); failures += 1; }
}

const pkg = JSON.parse(read('package.json'));
const layout = read('src/layouts/AdminLayout.tsx');
const plan = read('src/pages/admin/Plan.tsx');
const app = read('src/App.tsx');
const reader = read('src/utils/localFinancialDocumentReader.ts');
const html = read('index.html');

ok('FloriWeb V3 RC6.6 aplicado', pkg.version === '3.0.0-rc.6.6');
ok('Indicador mensalidade possui 3 estados', layout.includes('admin-billing-status-rc66') && layout.includes('is-current') && layout.includes('is-warning') && layout.includes('is-overdue'));
ok('Indicador abre Meu plano no vencimento', layout.includes('/admin/plano#vencimento'));
ok('Meu plano concentra mensalidade e PIX', plan.includes('Meu plano e mensalidade') && plan.includes('id="vencimento"') && plan.includes('PAGAMENTO PENDENTE') && plan.includes('ULTIMO PAGAMENTO'));
ok('Rota antiga de mensalidade converge para Meu plano', app.includes('<Navigate to="/admin/plano#vencimento" replace />'));
ok('OCR local possui upscale e segunda leitura', reader.includes('MAX_UPSCALE') && reader.includes('LEITURA REFORCADA') && reader.includes('otsuThreshold'));
ok('OCR prioriza valor por contexto', reader.includes('scoreAmountContext') && reader.includes('VALOR\\s+DO\\s+DOCUMENTO') && reader.includes('VALOR\\s+COBRADO'));
ok('PDF.js recebe canvas no render', reader.includes('render({ canvas, canvasContext: context, viewport })'));
ok('Favicon RC6.6 referenciado', html.includes('favicon-floriweb-rc66.svg') && exists('public/favicon-floriweb-rc66.svg'));
ok('Backend RC6.5 preservado', exists('supabase/migrations/202609032030_floriweb_rc6_5_billing_access.sql') && exists('supabase/functions/platform-manage-store-user/index.ts'));

const envPaths = ['.env', '.env.local', '.env.production'].filter(exists);
ok('Configuracao existente preservada', envPaths.length > 0);

if (failures) {
  console.error(`\n${failures} falha(s) na verificacao RC6.6.`);
  process.exit(1);
}
console.log('\nFloriWeb RC6.6 pronto para validar/build.');
