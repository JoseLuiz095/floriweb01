import fs from 'node:fs';
import path from 'node:path';

const root=process.cwd();
const problems=[];
const read=(file)=>fs.readFileSync(path.join(root,file),'utf8');
const exists=(file)=>fs.existsSync(path.join(root,file));
const need=(condition,message)=>{if(!condition)problems.push(message)};

need(exists('package.json'),'package.json nao encontrado. Execute na raiz do FloriWeb.');
need(exists('src/pages/admin/Finance.tsx'),'Finance.tsx nao encontrado.');
need(exists('src/utils/localFinancialDocumentReader.ts'),'Leitor local nao foi aplicado.');
need(exists('public/favicon-floriweb-rc64.svg'),'Favicon versionado RC6.4 nao foi aplicado.');

if(!problems.length){
  const pkg=JSON.parse(read('package.json'));
  const finance=read('src/pages/admin/Finance.tsx');
  const reader=read('src/utils/localFinancialDocumentReader.ts');
  const landing=read('src/pages/store/Landing.tsx');
  const index=read('index.html');
  const deploy=read('DEPLOY_FLORI_RC6_FUNCTIONS.bat');
  const headers=read('public/_headers');

  need(pkg.version==='3.0.0-rc.6.4','package.json ainda nao esta na RC6.4.');
  need(pkg.dependencies?.['tesseract.js']==='7.0.0','Dependencia tesseract.js 7.0.0 ausente.');
  need(pkg.dependencies?.['pdfjs-dist']==='6.3.289','Dependencia pdfjs-dist 6.3.289 ausente.');
  need(finance.includes('readLocalFinancialDocument'),'Financeiro nao esta usando OCR local.');
  need(!finance.includes('uploadFinanceDocument'),'Financeiro ainda referencia a funcao antiga de OCR remoto.');
  need(reader.includes("import('tesseract.js')")&&reader.includes("import('pdfjs-dist')"),'Leitor local incompleto.');
  need(landing.includes('flori-sales-final-button-rc64'),'CTA final RC6.4 nao foi aplicado.');
  need(index.includes('/favicon-floriweb-rc64.svg'),'index.html nao aponta para o favicon versionado.');
  need(headers.includes("'wasm-unsafe-eval'") && headers.includes("worker-src 'self' blob:") && headers.includes('camera=(self)'),
    'public/_headers nao libera WebAssembly/Worker/camera necessarios ao OCR local.');
  need(!exists('supabase/functions/flori-finance-document-extract/index.ts'),'Edge Function antiga de OCR/IA ainda existe no projeto.');
  need(!deploy.includes('functions deploy flori-finance-document-extract'),'BAT financeiro ainda tenta publicar OCR remoto.');

  if(exists('public/favicon.svg')){
    need(read('public/favicon.svg')===read('public/favicon-floriweb-rc64.svg'),'favicon.svg e favicon RC6.4 nao sao o mesmo arquivo local.');
  }
}

const envFiles=['.env','.env.local','.env.production','.env.production.local'];
let turnstile='';
for(const file of envFiles){
  if(!exists(file))continue;
  for(const raw of read(file).split(/\r?\n/)){
    const line=raw.trim();
    if(!line||line.startsWith('#'))continue;
    const index=line.indexOf('=');
    if(index<1)continue;
    const key=line.slice(0,index).trim();
    let value=line.slice(index+1).trim().replace(/^['"]|['"]$/g,'');
    if(key==='VITE_TURNSTILE_SITE_KEY'&&value)turnstile=value;
  }
}
need(Boolean(turnstile),'VITE_TURNSTILE_SITE_KEY nao encontrada nos arquivos .env existentes. O patch nao cria nem substitui .env.');

if(problems.length){
  console.error('\nFALHA RC6.4:\n');
  for(const problem of problems)console.error(`- ${problem}`);
  process.exit(1);
}

console.log('OK   FloriWeb RC6.4 aplicado na raiz correta');
console.log('OK   OCR local ativo para foto/PDF, sem IA');
console.log('OK   CTA final atualizado');
console.log('OK   favicon versionado e forcado no build');
console.log('OK   .env existente preservado e Turnstile localizado');
