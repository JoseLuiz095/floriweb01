import fs from 'node:fs';
import path from 'node:path';

const root=process.cwd();
const failures=[];
const read=(p)=>fs.readFileSync(path.join(root,p),'utf8');
const has=(p)=>fs.existsSync(path.join(root,p));
const check=(label,condition)=>{console.log(`${condition?'OK  ':'FAIL'} ${label}`);if(!condition)failures.push(label)};

const pkg=JSON.parse(read('package.json'));
const orders=read('src/pages/admin/Orders.tsx');
const storeApi=read('src/services/storeApi.ts');
const storeContext=read('src/contexts/StoreContext.tsx');
const types=read('src/types/index.ts');
const migration='supabase/migrations/202609041600_floriweb_rc6_8_order_payment_finance.sql';

check('FloriWeb V3 RC6.8 aplicado',pkg.version==='3.0.0-rc.6.8');
check('Pedido possui paymentStatus',types.includes("OrderPaymentStatus = 'pending' | 'paid'"));
check('Orders possui Confirmar recebimento',orders.includes('Confirmar recebimento')&&orders.includes('confirmOrderPayment'));
check('Store API chama confirm_order_payment_v1',storeApi.includes('rpc/confirm_order_payment_v1'));
check('StoreContext recarrega pedido apos confirmar',storeContext.includes('storeApi.confirmOrderPayment(orderId)'));
check('Migration RC6.8 presente',has(migration));
check('Validacao RC6.8 presente',has('supabase/VALIDAR_RC6_8.sql'));
check('CSS RC6.8 aplicado',read('src/styles.css').includes('RC6.8 - confirmacao de recebimento do pedido'));

if(failures.length){console.error(`\n${failures.length} falha(s). RC6.8 nao esta pronto para publicar.`);process.exit(1)}
console.log('\nRC6.8 pronto. Execute a migration/validacao no Supabase antes de publicar.');
