import fs from 'node:fs';

const read = (file) => fs.readFileSync(file, 'utf8');
const fail = (message) => { console.error(`ERRO ${message}`); process.exitCode = 1; };
const ok = (message, condition) => condition ? console.log(`OK   ${message}`) : fail(message);

const pkg = JSON.parse(read('package.json'));
const stores = read('src/pages/master/Stores.tsx');
const payments = read('src/pages/master/Payments.tsx');
const adminBilling = read('src/pages/admin/Billing.tsx');
const adminLayout = read('src/layouts/AdminLayout.tsx');
const billingApi = read('src/services/billingFinanceApi.ts');
const platformApi = read('src/services/platformApi.ts');
const migration = read('supabase/migrations/202609032030_floriweb_rc6_5_billing_access.sql');
const edge = read('supabase/functions/platform-manage-store-user/index.ts');
const html = read('index.html');
const css = read('src/styles.css');
const reader = fs.existsSync('src/utils/localFinancialDocumentReader.ts') ? read('src/utils/localFinancialDocumentReader.ts') : '';

ok('FloriWeb V3 RC6.5 aplicado', pkg.version === '3.0.0-rc.6.5');
ok('Admin Master altera e-mail/senha', stores.includes('Atualizar e-mail / senha') && platformApi.includes('platform-manage-store-user'));
ok('Edge de credenciais usa Admin API e MFA AAL2', edge.includes('auth.admin.updateUserById') && edge.includes('MFA_AAL2_REQUIRED'));
ok('Tabela de lojas mostra vencimento', stores.includes('<th>Vencimento</th>') && stores.includes('master-due-cell-rc65'));
ok('Master pode registrar nao renovacao', payments.includes('Não confirmar renovação') && billingApi.includes('platform_reject_subscription_payment_v1'));
ok('Barra superior mostra mensalidade em dia/atrasada', adminLayout.includes('Mensalidade em dia') && adminLayout.includes('Mensalidade atrasada'));
ok('Lojista possui pagina com ultimo pagamento', adminBilling.includes('ÚLTIMO PAGAMENTO') && adminBilling.includes('Vencimento da referência'));
ok('Banco ancora vencimento no due_day', migration.includes('subscription_reference_due_v1') && migration.includes('next_due_date=v_next_due'));
ok('Negacao nao avanca vencimento', migration.includes("status='rejected'") && migration.includes('não muda next_due_date'));
ok('favicon RC6.5 referenciado', html.includes('/favicon-floriweb-rc65.svg') && fs.existsSync('public/favicon-floriweb-rc65.svg'));
ok('CSS RC6.5 aplicado', css.includes('FloriWeb V3 RC6.5: mensalidade, vencimento e gestao de acesso'));
if (reader) ok('Hotfix PDF.js preservado', reader.includes('firstPage.render({ canvas, canvasContext: context, viewport })'));

const hasEnv = ['.env','.env.local','.env.production'].some((file) => fs.existsSync(file));
ok('.env existente preservado', hasEnv);

if (!process.exitCode) console.log('\nRC6.5 conferido.');
