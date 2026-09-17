import { restFetch } from '../lib/supabaseRest';
type Payload={support_whatsapp?:string|null};
export async function loadAdminSupportContact():Promise<string>{
  const payload=await restFetch<Payload>('rpc/get_admin_support_contact_v1',{method:'POST',body:{}});
  return String(payload?.support_whatsapp||'').replace(/\D/g,'');
}
