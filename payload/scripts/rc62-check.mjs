import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');
const exists = (file) => fs.existsSync(path.join(root, file));
const failures = [];
const check = (label, condition) => {
  console.log(`${condition ? 'OK  ' : 'FAIL'} ${label}`);
  if (!condition) failures.push(label);
};

const app = read('src/App.tsx');
const landing = read('src/pages/store/Landing.tsx');
const layout = read('src/layouts/StoreLayout.tsx');
const masterBilling = read('src/pages/master/Billing.tsx');
const billingApi = read('src/services/billingFinanceApi.ts');
const styles = read('src/styles.css');
const migrationPath = 'supabase/migrations/202609021730_floriweb_rc6_2_marketing_whatsapp_landing.sql';
const migration = exists(migrationPath) ? read(migrationPath) : '';

check('Landing comercial roteada na raiz oficial', app.includes('RootEntry') && app.includes('isFloriWebMarketingRoot') && app.includes('<Landing />'));
check('Dominio proprio continua usando Home', app.includes("? <Landing /> : <Home />"));
check('CTA teste Profissional', landing.includes('Testar o Profissional') && landing.includes('trialDays'));
check('CTA comercial usa WhatsApp configurado', landing.includes('marketingWhatsapp') && landing.includes('waUrl'));
check('Landing mostra demonstracao visual', landing.includes('/assets/bouquet-aurora') && landing.includes('flori-tour-grid-v62'));
check('Landing mostra planos do banco', landing.includes('data.plans') && landing.includes('monthlyPrice'));
check('Ajuda existe na landing e loja', exists('src/components/PlatformHelpButton.tsx') && landing.includes('PlatformHelpButton') && layout.includes('PlatformHelpButton'));
check('Ajuda usa suporte com fallback comercial', read('src/components/PlatformHelpButton.tsx').includes('supportWhatsapp || data.marketingWhatsapp'));
check('Admin Master cadastra WhatsApp financeiro', masterBilling.includes('WhatsApp para comprovantes'));
check('Admin Master cadastra WhatsApp comercial', masterBilling.includes('WhatsApp comercial da página inicial'));
check('Admin Master cadastra WhatsApp suporte', masterBilling.includes('WhatsApp de suporte / Ajuda'));
check('RPC V2 grava contatos', billingApi.includes('platform_update_billing_settings_v2') && migration.includes('p_marketing_whatsapp') && migration.includes('p_support_whatsapp'));
const landingSql = migration.slice(migration.indexOf('create or replace function public.get_public_landing_v1'), migration.indexOf('revoke all on function public.get_public_landing_v1'));
check('Landing publica nao expoe chave PIX', landingSql.includes("'marketing_whatsapp'") && !landingSql.includes('billing_pix_key') && !landingSql.includes('billing_whatsapp'));
check('Demo herda experiencia PRO', migration.includes("demo.code='DEMO'") && migration.includes("pro.code='PRO'"));
check('CSS RC6.2 presente', styles.includes('FloriWeb V3 RC6.2: landing comercial') && styles.includes('.flori-help-fab'));

if (failures.length) {
  console.error(`\nRC6.2 falhou em ${failures.length} verificacao(oes).`);
  process.exit(1);
}
console.log('\nFloriWeb RC6.2: verificacoes adicionais concluidas.');
