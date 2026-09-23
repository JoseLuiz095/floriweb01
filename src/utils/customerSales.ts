import type { CartItem, Order } from '../types';
import { formatOrderNumber } from './orderConfirmation';

export type RecentOrderSnapshot = { items: CartItem[]; customerName: string; customerPhone: string; createdAt: string };
const recentOrderKey = (storeId: string) => `floriweb_recent_order_v1:${storeId}`;

export function saveRecentOrder(storeId: string, items: CartItem[], customerName: string, customerPhone: string) {
  if (!storeId || !items.length) return;
  try { localStorage.setItem(recentOrderKey(storeId), JSON.stringify({ items, customerName, customerPhone, createdAt: new Date().toISOString() } satisfies RecentOrderSnapshot)); } catch { /* armazenamento indisponível */ }
}

export function loadRecentOrder(storeId: string): RecentOrderSnapshot | null {
  if (!storeId) return null;
  try { const raw=localStorage.getItem(recentOrderKey(storeId)); if(!raw)return null; const parsed=JSON.parse(raw) as RecentOrderSnapshot; return Array.isArray(parsed.items)&&parsed.items.length?parsed:null; } catch { return null; }
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

export function buildSalesRecoveryMessage(storeName: string, order: Order) {
  const number=order.orderNumber?`#${formatOrderNumber(order.orderNumber)}`:`#${order.id.slice(0,8)}`;
  return `Olá, ${order.customerName}! 🌷\n\nVimos que o pedido ${number} na ${storeName} foi registrado, mas a conversa no WhatsApp não foi concluída.\n\nSe ainda quiser finalizar seu presente, responda esta mensagem e seguimos por aqui.`;
}

export function buildComeBackMessage(storeName: string, customerName: string) {
  return `Olá, ${customerName}! 🌷\n\nA ${storeName} está por aqui quando você quiser preparar um novo presente ou repetir uma escolha especial.\n\nSe quiser ajuda para montar o próximo pedido, é só responder esta mensagem.`;
}
