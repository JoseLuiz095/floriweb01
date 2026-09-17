import fs from 'node:fs';
import path from 'node:path';

const root=process.cwd();
const read=(file)=>fs.readFileSync(path.join(root,file),'utf8');
const exists=(file)=>fs.existsSync(path.join(root,file));
const checks=[];
const ok=(label,value)=>checks.push([label,Boolean(value)]);

const pkg=JSON.parse(read('package.json'));
const adminPlan=read('src/pages/admin/Plan.tsx');
const masterPlans=read('src/pages/master/Plans.tsx');
const stores=read('src/pages/master/Stores.tsx');
const landing=read('src/pages/store/Landing.tsx');
const platformApi=read('src/services/platformApi.ts');
const index=read('index.html');

ok('FloriWeb RC6.10 aplicado',pkg.version==='3.0.0-rc.6.10');
ok('Usuarios administrativos removidos da oferta',!adminPlan.includes('usuario administrativo')&&!masterPlans.includes('value={plan.adminUserLimit'));
ok('Business sem preco fixo',adminPlan.includes('Sob consulta')&&!adminPlan.includes('R$ 349,90'));
ok('Business inclui dominio proprio',adminPlan.includes('Dominio proprio incluido')&&landing.includes('Dominio proprio incluido'));
ok('Business esta na landing',landing.includes('flori-business-plan-rc610'));
ok('Master explica acesso principal',masterPlans.includes('Usuarios administrativos adicionais permanecem fora do escopo atual'));
ok('Tabela de lojas nao vende contador multiadmin',stores.includes('acesso principal configurado'));
ok('Fallback limita acesso administrativo a um',platformApi.includes('adminUserLimit:1,sortOrder:20')&&platformApi.includes('adminUserLimit:1,sortOrder:30'));
ok('Migration RC6.10 presente',exists('supabase/migrations/202609151330_floriweb_rc6_10_plan_simplification.sql'));
ok('Validacao RC6.10 presente',exists('supabase/VALIDAR_RC6_10.sql'));
ok('Favicon RC6.10 referenciado',index.includes('favicon-floriweb-rc610.svg')&&exists('public/favicon-floriweb-rc610.svg'));
ok('Hotfix suporte V2 preservado',exists('src/components/PlatformHelpButton.tsx')&&read('src/components/PlatformHelpButton.tsx').includes('PlatformHelpButtonProps'));

let failed=0;
for(const [label,pass] of checks){console.log(`${pass?'OK  ':'ERRO'} ${label}`);if(!pass)failed++;}
if(failed){console.error(`\n${failed} verificacao(oes) falharam.`);process.exit(1);}
console.log('\nRC6.10 pronto para migration, validacao e publicacao.');
