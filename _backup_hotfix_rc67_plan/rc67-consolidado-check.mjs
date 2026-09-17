import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const read = (p) => fs.readFileSync(path.join(root, p), 'utf8');
const exists = (p) => fs.existsSync(path.join(root, p));
let failures = 0;
const ok = (label, condition) => {
  console.log(`${condition ? 'OK  ' : 'ERRO'} ${label}`);
  if (!condition) failures += 1;
};

const pkg = JSON.parse(read('package.json'));
const app = read('src/App.tsx');
const layout = read('src/layouts/AdminLayout.tsx');
const plan = read('src/pages/admin/Plan.tsx');
const finance = read('src/pages/admin/Finance.tsx');
const reader = read('src/utils/localFinancialDocumentReader.ts');
const styles = read('src/styles.css');
const html = read('index.html');

ok('FloriWeb RC6.7 consolidado aplicado', pkg.name === 'floriweb' && pkg.version === '3.0.0-rc.6.7');
ok('Base RC6.5 de mensalidade preservada', exists('supabase/migrations/202609032030_floriweb_rc6_5_billing_access.sql'));
ok('Backend de gestao do lojista preservado', exists('supabase/functions/platform-manage-store-user/index.ts'));
ok('RC6.6 status mensalidade possui verde/amarelo/vermelho', layout.includes('admin-billing-status-rc66') && layout.includes('is-current') && layout.includes('is-warning') && layout.includes('is-overdue'));
ok('RC6.6 status direciona para Meu plano', layout.includes('/admin/plano#vencimento'));
ok('RC6.6 Meu plano unificado', plan.includes('Meu plano e mensalidade') && plan.includes('id="vencimento"') && plan.includes('PAGAMENTO PENDENTE') && plan.includes('ULTIMO PAGAMENTO'));
ok('RC6.6 rota antiga converge para Meu plano', app.includes('<Navigate to="/admin/plano#vencimento" replace />'));
ok('RC6.6 OCR reforcado presente', reader.includes('MAX_UPSCALE') && reader.includes('LEITURA REFORCADA') && reader.includes('otsuThreshold') && reader.includes('scoreAmountContext'));
ok('PDF.js com parametro canvas corrigido', reader.includes('render({ canvas, canvasContext: context, viewport })'));
ok('RC6.7 Financeiro possui apenas acoes visiveis desejadas', finance.includes('flori-document-actions-rc67') && finance.includes('Tirar foto') && finance.includes('Escolher arquivo'));
ok('RC6.7 inputs nativos de arquivo ocultos', finance.includes('hidden type="file"') && !finance.includes('className="sr-only" type="file"'));
ok('CSS RC6.6 aplicado', styles.includes('FloriWeb V3 RC6.6: Meu plano unificado, status de vencimento e OCR reforcado'));
ok('CSS RC6.7 aplicado', styles.includes('FloriWeb V3 RC6.7: leitura financeira compacta') && styles.includes('.flori-document-reader-rc67'));
ok('Favicon RC6.7 referenciado', html.includes('favicon-floriweb-rc67.svg') && exists('public/favicon-floriweb-rc67.svg'));

const envs = ['.env', '.env.local', '.env.production'].filter(exists);
ok('Arquivo de ambiente existente preservado', envs.length > 0);

if (failures) {
  console.error(`\n${failures} falha(s) encontradas. Nao publique.`);
  process.exit(1);
}

console.log('\nRC6.7 consolidado pronto para instalacao, validacao e build.');
