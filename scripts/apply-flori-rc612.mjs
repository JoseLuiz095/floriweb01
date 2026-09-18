import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root=process.cwd();
const here=path.dirname(fileURLToPath(import.meta.url));
const packageRoot=path.resolve(here,'..');
const payload=path.join(packageRoot,'payload');
const VERSION='3.0.0-rc.6.12';
const stamp=new Date().toISOString().replace(/[-:TZ.]/g,'').slice(0,14);
const backup=path.join(root,`_backup_rc612_self_service_${stamp}`);

const fail=(m)=>{console.error(`ERRO: ${m}`);process.exit(1)};
const must=(rel)=>{const p=path.join(root,rel);if(!fs.existsSync(p))fail(`${rel} nao encontrado. Execute na raiz atual do FloriWeb.`);return p};
const read=(rel)=>fs.readFileSync(must(rel),'utf8');
const write=(rel,text)=>{const p=path.join(root,rel);fs.mkdirSync(path.dirname(p),{recursive:true});fs.writeFileSync(p,text,'utf8')};
const backupFile=(rel)=>{const src=must(rel);const dst=path.join(backup,rel);fs.mkdirSync(path.dirname(dst),{recursive:true});fs.copyFileSync(src,dst)};
const copyPayload=(rel)=>{const src=path.join(payload,rel);if(!fs.existsSync(src))fail(`Payload ausente: ${rel}`);const dst=path.join(root,rel);fs.mkdirSync(path.dirname(dst),{recursive:true});fs.copyFileSync(src,dst)};
const replaceRequired=(text,from,to,label)=>{if(text.includes(to))return text;if(!text.includes(from))fail(`Nao encontrei ponto de ajuste: ${label}`);return text.replace(from,to)};
const replaceRegexRequired=(text,re,to,label)=>{if(typeof to==='string'&&text.includes(to))return text;if(!re.test(text))fail(`Nao encontrei ponto de ajuste: ${label}`);re.lastIndex=0;return text.replace(re,to)};
const appendOnce=(text,marker,block)=>text.includes(marker)?text:`${text.trimEnd()}\n\n${block.trim()}\n`;

['package.json','package-lock.json','src/App.tsx','src/contexts/AuthContext.tsx','src/layouts/MasterLayout.tsx','src/layouts/AdminLayout.tsx','src/pages/admin/Login.tsx','src/pages/store/Landing.tsx','src/styles.css','scripts/smoke.mjs'].forEach(backupFile);
fs.mkdirSync(backup,{recursive:true});

const pkg=JSON.parse(read('package.json'));if(pkg.name!=='floriweb')fail('Este pacote foi executado na raiz de outro projeto. package.json inesperado.');pkg.version=VERSION;write('package.json',`${JSON.stringify(pkg,null,2)}\n`);
const lock=JSON.parse(read('package-lock.json'));lock.version=VERSION;if(lock.packages?.[''])lock.packages[''].version=VERSION;write('package-lock.json',`${JSON.stringify(lock,null,2)}\n`);

[
 'src/services/selfServiceSignup.ts',
 'src/pages/store/SelfSignup.tsx',
 'src/pages/store/SignupComplete.tsx',
 'src/pages/master/SignupRequests.tsx',
 'supabase/migrations/202609171945_floriweb_rc612_self_service_signup.sql',
 'supabase/VALIDAR_RC6_12_SELF_SERVICE.sql',
 'supabase/migrations/202609180800_floriweb_rc612_trial_eligibility_hardening.sql',
 'supabase/VALIDAR_RC612_REV2.sql',
].forEach(copyPayload);

let app=read('src/App.tsx');
if(!app.includes("./pages/store/SelfSignup")){
  app=replaceRequired(app,
    "const Landing = lazy(() => import('./pages/store/Landing'));",
    "const Landing = lazy(() => import('./pages/store/Landing'));\nconst SelfSignup = lazy(() => import('./pages/store/SelfSignup'));\nconst SignupComplete = lazy(() => import('./pages/store/SignupComplete'));",
    'imports auto cadastro');
}
if(!app.includes("./pages/master/SignupRequests")){
  app=replaceRequired(app,
    "const MasterStores = lazy(() => import('./pages/master/Stores'));",
    "const MasterStores = lazy(() => import('./pages/master/Stores'));\nconst MasterSignupRequests = lazy(() => import('./pages/master/SignupRequests'));",
    'import solicitacoes Master');
}
if(!app.includes('path="/cadastro"')){
  app=replaceRequired(app,
    '        <Route path="/admin/login" element={<AdminLogin />} />',
    '        <Route path="/cadastro" element={<SelfSignup />} />\n        <Route path="/cadastro/confirmar" element={<SignupComplete />} />\n\n        <Route path="/admin/login" element={<AdminLogin />} />',
    'rotas auto cadastro');
}
if(!app.includes('path="/admin-master/solicitacoes"')){
  app=replaceRequired(app,
    '          <Route path="/admin-master/lojas" element={<MasterStores />} />',
    '          <Route path="/admin-master/lojas" element={<MasterStores />} />\n          <Route path="/admin-master/solicitacoes" element={<MasterSignupRequests />} />',
    'rota solicitacoes Master');
}
if(!app.includes('preparationRouteAllowed')){
  app=replaceRequired(app,
    "  if (membership.mustChangePassword && location.pathname !== '/admin/primeiro-acesso') return <Navigate to=\"/admin/primeiro-acesso\" replace />;",
    "  if (membership.mustChangePassword && location.pathname !== '/admin/primeiro-acesso') return <Navigate to=\"/admin/primeiro-acesso\" replace />;\n  const preparationRouteAllowed = location.pathname === '/admin'\n    || location.pathname === '/admin/primeiros-passos'\n    || location.pathname.startsWith('/admin/produtos')\n    || ['/admin/categorias','/admin/adicionais','/admin/entregas','/admin/configuracoes'].includes(location.pathname);\n  if (membership.limitedAccess && !preparationRouteAllowed) return <Navigate to=\"/admin/primeiros-passos\" replace />;",
    'bloqueio de rotas no workspace pendente');
}
write('src/App.tsx',app);

let auth=read('src/contexts/AuthContext.tsx');
auth=replaceRequired(auth,
  "export type Membership = { id: string; storeId: string; role: Role; active: boolean; storeName?: string; mustChangePassword: boolean };",
  "export type Membership = { id: string; storeId: string; role: Role; active: boolean; storeName?: string; mustChangePassword: boolean; approvalStatus?: 'pending' | 'approved' | 'rejected'; limitedAccess?: boolean };",
  'Membership approvalStatus');
auth=replaceRequired(auth,
  "type StoreRow = { id: string; name: string; active: boolean; access_status?: 'online' | 'suspended' };",
  "type StoreRow = { id: string; name: string; active: boolean; access_status?: 'online' | 'suspended'; approval_status?: 'pending' | 'approved' | 'rejected' };",
  'StoreRow approval_status');
auth=replaceRequired(auth,
  '`stores?select=id,name,active,access_status&id=in.(${ids})&order=name.asc`',
  '`stores?select=id,name,active,access_status,approval_status&id=in.(${ids})&order=name.asc`',
  'select approval_status');
auth=replaceRequired(auth,
  "        if (!store?.active || (store.access_status ?? 'online') !== 'online') return [];",
  "        if (!store?.active) return [];\n        const pendingWorkspace = store.approval_status === 'pending';\n        if ((store.access_status ?? 'online') !== 'online' && !pendingWorkspace) return [];",
  'workspace pending');
if(!auth.includes("approvalStatus: store.approval_status || 'approved'")){
  auth=replaceRegexRequired(auth,
    /(mustChangePassword:\s*Boolean\(row\.must_change_password\),)(\r?\n\s*)(}\];)/,
    `$1$2          approvalStatus: store.approval_status || 'approved',$2          limitedAccess: store.approval_status === 'pending' && (store.access_status ?? 'online') !== 'online',$2        $3`,
    'map approval status');
}
write('src/contexts/AuthContext.tsx',auth);

let master=read('src/layouts/MasterLayout.tsx');
if(!master.includes('UserPlus')){
  master=master.replace("Package2, Settings2, ShieldCheck, X } from 'lucide-react';","Package2, Settings2, ShieldCheck, UserPlus, X } from 'lucide-react';");
}
if(!master.includes("/admin-master/solicitacoes")){
  master=replaceRequired(master,
    "  { to: '/admin-master/lojas', label: 'Lojas e clientes', icon: Package2 },",
    "  { to: '/admin-master/lojas', label: 'Lojas e clientes', icon: Package2 },\n  { to: '/admin-master/solicitacoes', label: 'Solicitações', icon: UserPlus },",
    'menu solicitacoes');
}
write('src/layouts/MasterLayout.tsx',master);

let admin=read('src/layouts/AdminLayout.tsx');
if(!admin.includes('  ShieldCheck,')) admin=admin.replace('  ShoppingBag,','  ShieldCheck,\n  ShoppingBag,');
if(!admin.includes('preparationNavAllowed')){
  admin=replaceRequired(admin,
    "            const items = section.items.filter((item: any) => !item.requiresReports || planUsage.plan.reports);",
    "            const preparationNavAllowed = new Set(['/admin','/admin/primeiros-passos','/admin/produtos','/admin/categorias','/admin/adicionais','/admin/entregas','/admin/configuracoes']);\n            const items = section.items.filter((item: any) => (!item.requiresReports || planUsage.plan.reports) && (!membership?.limitedAccess || preparationNavAllowed.has(item.to)));",
    'menu reduzido no workspace pendente');
}
if(!admin.includes('self-service-approval-banner')){
  admin=replaceRequired(admin,
    '        <div className="admin-page"><div key={`${location.pathname}:${membership?.storeId || \'none\'}`}><Outlet /></div></div>',
    `        {membership?.approvalStatus === 'pending' && <div className="self-service-approval-banner is-limited"><ShieldCheck size={18}/><div><strong>Cadastro em preparação</strong><span>Você pode configurar catálogo, identidade, entregas e configurações. Pedidos, Analytics, Financeiro, cobrança e a vitrine ficam bloqueados até a aprovação do Admin Master.</span></div></div>}\n        <div className="admin-page"><div key={\`${'${'}location.pathname}:${'${'}membership?.storeId || 'none'}\`}><Outlet /></div></div>`,
    'banner admin pending');
}
write('src/layouts/AdminLayout.tsx',admin);

let adminLogin=read('src/pages/admin/Login.tsx');
if(!adminLogin.includes('login-self-signup')){
  adminLogin=replaceRequired(adminLogin,
    '<a href="/" className="login-back">← Voltar para a página inicial</a>',
    '<div className="login-self-signup"><span>Ainda não tem acesso?</span><a href="/cadastro">Criar conta e escolher plano</a></div><a href="/" className="login-back">← Voltar para a página inicial</a>',
    'atalho de auto cadastro no login');
}
write('src/pages/admin/Login.tsx',adminLogin);

let landing=read('src/pages/store/Landing.tsx');
if(!landing.includes('flori-self-service-nav')){
  landing=replaceRequired(landing,
    '<div><a href="/admin/login">Entrar</a><ProtectedContactButton className="flori-sales-primary" intent="trial">',
    '<div><a href="/admin/login">Entrar</a><a className="flori-self-service-nav" href="/cadastro">Criar conta</a><ProtectedContactButton className="flori-sales-primary" intent="trial">',
    'CTA header');
}
if(!landing.includes('flori-self-service-cta')){
  landing=replaceRequired(landing,
    '</ProtectedContactButton><a href={demoHref}>Ver uma loja funcionando <ArrowRight size={18}/></a>',
    '</ProtectedContactButton><a className="flori-self-service-cta" href="/cadastro?plan=DEMO"><UserPlus size={18}/>Criar minha conta</a><a href={demoHref}>Ver uma loja funcionando <ArrowRight size={18}/></a>',
    'CTA hero');
  landing=landing.replace("Sparkles, Store, WalletCards } from 'lucide-react';","Sparkles, Store, UserPlus, WalletCards } from 'lucide-react';");
}
if(!landing.includes('flori-plan-self-service')){
  const planCardsEnd='</ProtectedContactButton></article>})}<article className="flori-business-plan-rc610">';
  const planCardsNew='</ProtectedContactButton><a className="flori-plan-self-service" href={`/cadastro?plan=${encodeURIComponent(plan.code)}`}>Criar conta neste plano <ArrowRight size={15}/></a></article>})}<article className="flori-business-plan-rc610">';
  landing=replaceRequired(landing,planCardsEnd,planCardsNew,'CTA auto cadastro nos planos');
}
write('src/pages/store/Landing.tsx',landing);

let css=read('src/styles.css');
css=appendOnce(css,'/* FLORIWEB RC6.12 SELF SERVICE */',`/* FLORIWEB RC6.12 SELF SERVICE */
.flori-self-service-nav,.flori-self-service-cta,.flori-plan-self-service{display:inline-flex;align-items:center;justify-content:center;gap:8px;text-decoration:none;font-weight:800}.flori-self-service-nav{padding:9px 13px;border:1px solid rgba(23,99,61,.2);border-radius:12px;color:#17633d}.flori-self-service-cta{padding:13px 18px;border:1px solid rgba(23,99,61,.22);border-radius:14px;background:#fff;color:#17633d}.flori-plan-self-service{margin-top:8px;padding:10px 12px;border:1px solid rgba(23,99,61,.2);border-radius:12px;color:#17633d}.login-self-signup{display:flex;align-items:center;justify-content:center;gap:6px;flex-wrap:wrap;font-size:.88rem}.login-self-signup a{color:#17633d;font-weight:850;text-decoration:none}
.self-signup-page{min-height:100vh;background:linear-gradient(180deg,#fff 0,#f7fcf8 100%);color:#173329}.self-signup-topbar{height:64px;display:flex;align-items:center;justify-content:space-between;max-width:1180px;margin:auto;padding:0 24px}.self-signup-topbar a,.self-signup-topbar strong{display:inline-flex;gap:7px;align-items:center;color:inherit;text-decoration:none;font-weight:800}
.self-signup-shell{max-width:1180px;margin:auto;padding:54px 24px 80px;display:grid;grid-template-columns:minmax(0,.9fr) minmax(420px,1fr);gap:56px;align-items:start}.self-signup-intro h1{font-size:clamp(2rem,4vw,3.4rem);line-height:1.04;margin:12px 0 18px}.self-signup-intro>p{font-size:1.04rem;line-height:1.65;color:#52675d}.self-signup-rules{display:grid;gap:12px;margin-top:30px}.self-signup-rules article{display:flex;gap:12px;padding:15px;border:1px solid #d9e8df;border-radius:16px;background:#fff}.self-signup-rules svg{flex:0 0 auto;color:#17633d}.self-signup-rules div{display:grid;gap:3px}.self-signup-rules span{font-size:.9rem;color:#607268}
.self-signup-card{background:#fff;border:1px solid #d9e8df;border-radius:22px;box-shadow:0 22px 60px rgba(23,99,61,.08);overflow:hidden}.self-signup-mode{display:grid;grid-template-columns:1fr 1fr;background:#f4faf6;border-bottom:1px solid #d9e8df}.self-signup-mode button{padding:14px;border:0;background:transparent;font-weight:800;cursor:pointer}.self-signup-mode button.active{background:#fff;color:#17633d}.self-signup-card form{padding:24px;display:grid;gap:16px}.self-signup-heading{display:flex;gap:12px;align-items:flex-start}.self-signup-heading h2{margin:0}.self-signup-heading p{margin:3px 0 0;color:#607268;font-size:.9rem}.self-signup-card label{display:grid;gap:6px;font-size:.84rem;font-weight:750}.self-signup-card input{width:100%;min-height:44px;border:1px solid #cfe0d6;border-radius:11px;padding:0 12px;font:inherit}.self-signup-grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}.self-signup-password{display:flex;border:1px solid #cfe0d6;border-radius:11px;overflow:hidden}.self-signup-password input{border:0}.self-signup-password button{width:44px;border:0;background:#fff;display:grid;place-items:center}.self-signup-plans{border:0;padding:0;margin:2px 0;display:grid;gap:9px}.self-signup-plans legend{font-weight:850;margin-bottom:8px}.self-signup-plans>label{grid-template-columns:auto 1fr auto;align-items:center;padding:12px;border:1px solid #d9e8df;border-radius:12px;cursor:pointer}.self-signup-plans>label.selected{border-color:#17633d;background:#f2faf5}.self-signup-plans input{width:auto;min-height:0}.self-signup-plans div{display:grid}.self-signup-plans span{font-size:.82rem;color:#607268}.self-signup-notice,.self-service-approval-banner{display:flex;gap:10px;align-items:flex-start;border-radius:12px;padding:12px 14px;background:#fff8e8;border:1px solid #efd79a;font-size:.88rem}.self-signup-submit{width:100%;justify-content:center}.self-signup-footnote{color:#607268;line-height:1.5;text-align:center}.self-signup-success{padding:12px;border-radius:10px;background:#edf9f1;color:#17633d}.signup-complete-page{min-height:100vh;display:grid;place-items:center;background:#f7fcf8;padding:24px}.signup-complete-card{max-width:560px;text-align:center;background:#fff;border:1px solid #d9e8df;border-radius:22px;padding:36px;box-shadow:0 22px 60px rgba(23,99,61,.08)}.signup-complete-card>svg{width:38px;height:38px}.signup-complete-card .spin{animation:selfspin 1s linear infinite}.signup-complete-actions{display:flex;gap:10px;justify-content:center;margin-top:20px}@keyframes selfspin{to{transform:rotate(360deg)}}
.signup-request-summary{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-bottom:16px}.signup-request-summary article{display:flex;gap:12px;align-items:center;background:#fff;border:1px solid var(--border,#e5e7eb);border-radius:14px;padding:16px}.signup-request-summary strong{font-size:1.4rem}.signup-request-summary div{display:grid}.signup-request-summary span{font-size:.82rem;color:#6b7280}.signup-request-filters{display:flex;gap:8px;margin-bottom:12px}.signup-request-filters button{border:1px solid var(--border,#e5e7eb);background:#fff;border-radius:999px;padding:8px 12px;font-weight:750}.signup-request-filters button.active{background:#173329;color:#fff}.signup-request-table td small{display:block;margin-top:4px;color:#6b7280}.signup-request-actions{display:flex;gap:7px}.signup-status-chip,.signup-access-chip{display:inline-flex;border-radius:999px;padding:5px 8px;font-size:.76rem;font-weight:850}.signup-status-chip.pending{background:#fff6df;color:#8a5a00}.signup-status-chip.approved,.signup-access-chip.online{background:#eaf8ef;color:#17633d}.signup-status-chip.rejected,.signup-access-chip.limited{background:#fdecec;color:#a12828}.signup-request-empty{text-align:center;padding:44px 20px}.self-service-approval-banner{margin:14px 22px 0}.self-service-approval-banner div{display:grid;gap:2px}.self-service-approval-banner span{font-size:.86rem}
@media(max-width:850px){.self-signup-shell{grid-template-columns:1fr;padding-top:28px}.self-signup-grid{grid-template-columns:1fr}.signup-request-summary{grid-template-columns:1fr}.self-signup-topbar{padding:0 16px}}`);
write('src/styles.css',css);

let smoke=read('scripts/smoke.mjs');
smoke=smoke.replace(/Versao V3 RC6\.11/g,'Versao V3 RC6.12');
smoke=smoke.replace(/packageJson\.version\s*===\s*['"]3\.0\.0-rc\.6\.11['"]/g,"packageJson.version === '3.0.0-rc.6.12'");
if(!smoke.includes('RC6.12 auto cadastro publico')){
  const anchor="ok('Versao V3 RC6.12', packageJson.version === '3.0.0-rc.6.12');";
  if(!smoke.includes(anchor))fail('Check de versao RC6.12 nao encontrado no smoke apos ajuste.');
  const insert=`\nconst selfSignup = read('src/pages/store/SelfSignup.tsx');\nconst selfSignupService = read('src/services/selfServiceSignup.ts');\nconst signupRequests = read('src/pages/master/SignupRequests.tsx');\nconst mRc612 = read('supabase/migrations/202609171945_floriweb_rc612_self_service_signup.sql');\nok('RC6.12 auto cadastro publico', app.includes('path=\\"/cadastro\\"') && selfSignup.includes('Criar nova conta'));\nok('RC6.12 Demo com elegibilidade cadastral', exists('supabase/migrations/202609180800_floriweb_rc612_trial_eligibility_hardening.sql') && selfSignup.includes('validação cadastral do negócio') && selfSignupService.includes('complete_self_service_signup_v2'));\nok('RC6.12 workspace pendente protegido', mRc612.includes("s.approval_status='pending'") && auth.includes('pendingWorkspace') && app.includes('preparationRouteAllowed') && adminLayout.includes('preparationNavAllowed') && adminLayout.includes('self-service-approval-banner'));\nok('RC6.12 Master aprova auto cadastro', signupRequests.includes('Liberar') && selfSignupService.includes('platform_approve_self_service_signup_v2'));\n`;
  smoke=smoke.replace(anchor,anchor+insert);
}
write('scripts/smoke.mjs',smoke);

console.log('OK FloriWeb V3 RC6.12 aplicado.');
console.log(`Backup: ${path.basename(backup)}`);
console.log('PROXIMO: execute as migrations 202609171945 e 202609180800, depois VALIDAR_RC612_REV2.sql no Supabase.');
