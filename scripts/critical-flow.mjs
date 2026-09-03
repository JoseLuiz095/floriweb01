import fs from 'node:fs';
import path from 'node:path';

const root=process.cwd();
const read=(p)=>fs.readFileSync(path.join(root,p),'utf8');
const failures=[];
const checks=[];
const check=(n,c)=>{
  checks.push([n,c]);
  if(!c) failures.push(n);
};

const checkout=read('src/pages/store/Checkout.tsx'),
  success=read('src/pages/store/OrderSuccess.tsx'),
  storeApi=read('src/services/storeApi.ts'),
  rest=read('src/lib/supabaseRest.ts'),
  orders=read('src/pages/admin/Orders.tsx'),
  edge=read('supabase/functions/public-checkout/index.ts'),
  config=read('supabase/config.toml'),
  m140=read('supabase/migrations/202608270140_v3_checkout_edge_turnstile.sql'),
  m145=read('supabase/migrations/202608270145_v3_checkout_idempotency.sql'),
  mMade=read('supabase/diagnostics/202608280100_v3_made_to_order_lead_time.sql');