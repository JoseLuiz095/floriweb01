import type { CartItem, CustomerMessageTemplates, Order } from '../types';
import { formatOrderNumber } from './orderConfirmation';

export type RecentOrderSnapshot = { items: CartItem[]; customerName: string; customerPhone: string; createdAt: string };
const recentOrderKey = (storeId: string) => `floriweb_recent_order_v1:${storeId}`;

export const DEFAULT_CUSTOMER_MESSAGE_TEMPLATES: CustomerMessageTemplates = {
  orderCreated: 'Olá, {cliente}! Seu pedido {pedido} foi registrado na {loja}. Total: {total}. Se precisar ajustar algum detalhe, responda esta mensagem.',
  whatsappOpened: 'Olá, {cliente}! Estamos acompanhando o pedido {pedido} da {loja}. Se precisar de ajuda com entrega, presente ou cartão, fale por aqui.',
  cancelled: 'Olá, {cliente}. O pedido {pedido} foi cancelado. Se quiser refazer ou escolher outro presente, responda esta mensagem.',
  salesRecovery: 'Olá, {cliente}! Vimos que o pedido {pedido} na {loja}, no total de {total}, foi registrado mas o atendimento não foi concluído. Se ainda quiser finalizar seu presente, responda esta mensagem.',
  comeBack: 'Olá, {cliente}! A {loja} está por aqui quando você quiser preparar um novo presente ou repetir uma escolha especial. Se quiser ajuda, responda esta mensagem.',
};

export function normalizeCustomerMessageTemplates(value: unknown): CustomerMessageTemplates {
  const raw = value && typeof value === 'object' ? value as Partial<CustomerMessageTemplates> : {};
  return { ...DEFAULT_CUSTOMER_MESSAGE_TEMPLATES, ...Object.fromEntries(Object.entries(raw).filter(([,v]) => typeof v === 'string' && v.trim())) } as CustomerMessageTemplates;
}

export function saveRecentOrder(storeId: string, items: CartItem[], customerName: string, customerPhone: string) {
  if (!storeId || !items.length) return;
  try { localStorage.setItem(recentOrderKey(storeId), JSON.stringify({ items, customerName, customerPhone, createdAt: new Date().toISOString() } satisfies RecentOrderSnapshot)); } catch { /* armazenamento indisponível */ }
}

export function loadRecentOrder(storeId: string, maxAgeDays = 180): RecentOrderSnapshot | null {
  if (!storeId) return null;
  try {
    const raw=localStorage.getItem(recentOrderKey(storeId)); if(!raw)return null;
    const parsed=JSON.parse(raw) as RecentOrderSnapshot;
    if(!Array.isArray(parsed.items)||!parsed.items.length)return null;
    const age=Date.now()-new Date(parsed.createdAt).getTime();
    return Number.isFinite(age)&&age<=Math.max(1,maxAgeDays)*86_400_000?parsed:null;
  } catch { return null; }
}

export function normalizeWhatsappPhone(phone?: string) {
  const digits=(phone||'').replace(/\D/g,'');
  if(!digits)return '';
  if(digits.startsWith('55'))return digits;
  return digits.length===10||digits.length===11?`55${digits}`:digits;
}

export function openCustomerWhatsapp(phone: string | undefined, message: string) {
  const normalized=normalizeWhatsappPhone(phone); if(!normalized)return false;
  window.open(`https://wa.me/${normalized}?text=${encodeURIComponent(message)}`,'_blank','noopener,noreferrer'); return true;
}

function renderTemplate(template:string, vars:Record<string,string>) { return template.replace(/\{([a-zA-Z0-9_]+)\}/g,(match,key)=>vars[key]??match); }
function orderVariables(storeName:string, order:Order) {
  const number=order.orderNumber?`#${formatOrderNumber(order.orderNumber)}`:`#${order.id.slice(0,8)}`;
  return { cliente:order.customerName, pedido:number, loja:storeName, total:order.total.toLocaleString('pt-BR',{style:'currency',currency:'BRL'}), previsao:order.desiredDate||'a combinar', status:order.status };
}

export function buildOrderStatusMessage(storeName:string, order:Order, templates?:CustomerMessageTemplates) {
  const key = order.status==='cancelled'?'cancelled':order.status==='sent_to_whatsapp'?'whatsappOpened':'orderCreated';
  return renderTemplate((templates??DEFAULT_CUSTOMER_MESSAGE_TEMPLATES)[key],orderVariables(storeName,order));
}
export function buildSalesRecoveryMessage(storeName: string, order: Order, templates?:CustomerMessageTemplates) { return renderTemplate((templates??DEFAULT_CUSTOMER_MESSAGE_TEMPLATES).salesRecovery,orderVariables(storeName,order)); }
export function buildComeBackMessage(storeName: string, customerName: string, templates?:CustomerMessageTemplates) { return renderTemplate((templates??DEFAULT_CUSTOMER_MESSAGE_TEMPLATES).comeBack,{cliente:customerName,pedido:'',loja:storeName,total:'',previsao:'',status:''}); }
