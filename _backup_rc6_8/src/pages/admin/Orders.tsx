import { MessageCircle, RefreshCw, Search, ShoppingBag } from 'lucide-react';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { ErrorState, LoadingState } from '../../components/ui/AsyncState';
import { useStore } from '../../contexts/StoreContext';
import { currency, formatDateBR, formatDateTimeBR } from '../../utils/format';
import type { PaymentMethod } from '../../types';
import { formatOrderNumber } from '../../utils/orderConfirmation';

const statusLabel = { draft: 'Pedido realizado', sent_to_whatsapp: 'WhatsApp aberto', cancelled: 'Cancelado' } as const;
const paymentLabel: Record<PaymentMethod, string> = { confirm: 'Confirmar com a loja', pix: 'PIX', card: 'Cartão', cash: 'Dinheiro' };

export default function OrdersAdmin() {
  const { orders, loading, error, reloadAdmin } = useStore();
  const [query, setQuery] = useState('');
  const [refreshing, setRefreshing] = useState(false);
  const [lastUpdatedAt, setLastUpdatedAt] = useState<Date | null>(null);
  const refreshingRef = useRef(false);
  const filtered = useMemo(() => { const term=query.toLowerCase().trim(); return orders.filter((order)=>`${order.customerName} ${order.recipientName ?? ''} ${order.id} ${order.orderNumber}`.toLowerCase().includes(term)); }, [orders, query]);
  const refreshOrders = useCallback(async () => {
    if (refreshingRef.current) return; refreshingRef.current=true; setRefreshing(true);
    try { await reloadAdmin({ silent:true }); setLastUpdatedAt(new Date()); }
    catch (refreshError) { console.error('Não foi possível atualizar os pedidos em segundo plano:', refreshError); }
    finally { refreshingRef.current=false; setRefreshing(false); }
  }, [reloadAdmin]);
  useEffect(()=>{ if(!loading&&!lastUpdatedAt)setLastUpdatedAt(new Date()); },[loading,lastUpdatedAt]);
  useEffect(()=>{
    const interval=window.setInterval(()=>{ if(document.visibilityState==='visible')void refreshOrders(); },15000);
    const onFocus=()=>void refreshOrders(); const onVisibility=()=>{ if(document.visibilityState==='visible')void refreshOrders(); };
    window.addEventListener('focus',onFocus); document.addEventListener('visibilitychange',onVisibility);
    return()=>{ window.clearInterval(interval); window.removeEventListener('focus',onFocus); document.removeEventListener('visibilitychange',onVisibility); };
  },[refreshOrders]);
  if (loading) return <LoadingState label="Carregando pedidos..." />;
  if (error) return <ErrorState message={error} onRetry={() => void reloadAdmin()} />;
  return <>
    <div className="admin-page-title"><div><span className="eyebrow">PEDIDOS</span><h1>Pedidos realizados</h1><p>O pedido é salvo antes de o cliente abrir o WhatsApp. Esta tela atualiza automaticamente quando você retorna para a aba.</p></div></div>
    <section className="admin-card no-padding">
      <div className="table-toolbar orders-toolbar">
        <div className="admin-search"><Search size={18}/><input value={query} onChange={(e)=>setQuery(e.target.value)} placeholder="Buscar pedido, cliente ou destinatário..."/></div>
        <div className="orders-toolbar__sync" aria-live="polite"><span>{filtered.length} pedido{filtered.length===1?'':'s'}</span><small>{lastUpdatedAt?`Atualizado às ${lastUpdatedAt.toLocaleTimeString('pt-BR',{hour:'2-digit',minute:'2-digit',second:'2-digit'})}`:'Atualização automática ativa'}</small><button type="button" className="secondary-button compact-button" onClick={()=>void refreshOrders()} disabled={refreshing} aria-busy={refreshing}><RefreshCw size={15} className={refreshing?'spin':''}/>{refreshing?'Atualizando...':'Atualizar'}</button></div>
      </div>
      {filtered.length===0?<div className="admin-empty"><ShoppingBag size={32}/><strong>Nenhum pedido registrado</strong><span>Depois que o cliente tocar em “Registrar pedido”, o pedido aparecerá aqui — mesmo antes de abrir o WhatsApp.</span></div>:(
        <div className="responsive-table"><table><thead><tr><th>Pedido</th><th>Cliente</th><th>Recebimento</th><th>Pagamento</th><th>Total</th><th>Status</th><th>Criado em</th></tr></thead><tbody>{filtered.map((order)=><tr key={order.id}>
          <td><strong>#{order.orderNumber?formatOrderNumber(order.orderNumber):order.id.slice(0,8)}</strong></td>
          <td><div className="order-customer"><strong>{order.customerName}</strong><span>{order.customerPhone||order.recipientName||'Sem telefone informado'}</span></div></td>
          <td><div className="order-customer"><strong>{order.deliveryType==='delivery'?'Entrega':'Retirada'} · {formatDateBR(order.desiredDate)}</strong>{order.deliveryType==='delivery'&&order.deliveryZoneName&&<span>{order.deliveryZoneName}{order.deliveryFee!=null?` · ${currency.format(order.deliveryFee)}`:''}</span>}</div></td>
          <td><strong>{paymentLabel[order.paymentMethod]}</strong></td><td><strong>{currency.format(order.total)}</strong>{order.deliveryFee?<small className="order-fee-note">inclui {currency.format(order.deliveryFee)} de entrega</small>:null}</td>
          <td><span className={`order-status order-status--${order.status}`}><MessageCircle size={13}/>{statusLabel[order.status]}</span></td><td>{formatDateTimeBR(order.createdAt)}</td>
        </tr>)}</tbody></table></div>)}
    </section>
  </>;
}
