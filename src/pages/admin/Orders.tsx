import { CheckCircle2, CircleDollarSign, MessageCircle, RefreshCw, RotateCcw, Search, ShoppingBag, Users } from 'lucide-react';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { ErrorState, LoadingState } from '../../components/ui/AsyncState';
import { useStore } from '../../contexts/StoreContext';
import { trackInteraction } from '../../services/interactionTelemetry';
import { currency, formatDateBR, formatDateTimeBR } from '../../utils/format';
import type { OrderStatus, PaymentMethod } from '../../types';
import { formatOrderNumber } from '../../utils/orderConfirmation';
import { buildComeBackMessage, buildSalesRecoveryMessage, normalizeWhatsappPhone, openCustomerWhatsapp } from '../../utils/customerSales';

const statusLabel: Record<OrderStatus, string> = {
  draft: 'Pedido realizado',
  sent_to_whatsapp: 'WhatsApp aberto',
  cancelled: 'Cancelado',
};

const paymentLabel: Record<PaymentMethod, string> = {
  confirm: 'Confirmar com a loja',
  pix: 'PIX',
  card: 'Cartão',
  cash: 'Dinheiro',
};

const sortOptions = [
  { value: 'newest', label: 'Mais recentes' },
  { value: 'oldest', label: 'Mais antigos' },
  { value: 'total_desc', label: 'Maior valor' },
  { value: 'total_asc', label: 'Menor valor' },
  { value: 'customer_asc', label: 'Cliente A-Z' },
] as const;

type SortMode = (typeof sortOptions)[number]['value'];

export default function OrdersAdmin() {
  const { orders, loading, error, reloadAdmin, confirmOrderPayment, settings } = useStore();
  const [searchParams] = useSearchParams();
  const [query, setQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<'all' | OrderStatus>('all');
  const [sortBy, setSortBy] = useState<SortMode>('newest');
  const [refreshing, setRefreshing] = useState(false);
  const [confirmingPaymentId, setConfirmingPaymentId] = useState<string | null>(null);
  const [lastUpdatedAt, setLastUpdatedAt] = useState<Date | null>(null);
  const refreshingRef = useRef(false);
  const rowsRef = useRef<Record<string, HTMLTableRowElement | null>>({});
  const highlightedOrderId = searchParams.get('highlight') || '';

  const refreshOrders = useCallback(async () => {
    if (refreshingRef.current) return;
    refreshingRef.current = true;
    setRefreshing(true);
    try {
      await reloadAdmin({ silent: true });
      setLastUpdatedAt(new Date());
    } catch (refreshError) {
      console.error('Não foi possível atualizar os pedidos em segundo plano:', refreshError);
    } finally {
      refreshingRef.current = false;
      setRefreshing(false);
    }
  }, [reloadAdmin]);

  const confirmPayment = async (orderId: string, orderNumber: number, total: number) => {
    const confirmed = window.confirm(
      `Confirmar o recebimento de ${currency.format(total)} do pedido #${formatOrderNumber(orderNumber)}?\n\nAo confirmar, a entrada será lançada automaticamente no Financeiro.`,
    );
    if (!confirmed) return;

    setConfirmingPaymentId(orderId);
    try {
      await trackInteraction('order_payment_confirm', () => confirmOrderPayment(orderId), { storeId: settings.id });
      setLastUpdatedAt(new Date());
    } catch (paymentError) {
      window.alert(paymentError instanceof Error ? paymentError.message : 'Não foi possível confirmar o recebimento.');
    } finally {
      setConfirmingPaymentId(null);
    }
  };

  useEffect(() => {
    if (!loading && !lastUpdatedAt) setLastUpdatedAt(new Date());
  }, [loading, lastUpdatedAt]);

  useEffect(() => {
    const interval = window.setInterval(() => {
      if (document.visibilityState === 'visible') void refreshOrders();
    }, 15000);
    const onFocus = () => void refreshOrders();
    const onVisibility = () => {
      if (document.visibilityState === 'visible') void refreshOrders();
    };
    window.addEventListener('focus', onFocus);
    document.addEventListener('visibilitychange', onVisibility);
    return () => {
      window.clearInterval(interval);
      window.removeEventListener('focus', onFocus);
      document.removeEventListener('visibilitychange', onVisibility);
    };
  }, [refreshOrders]);

  const filtered = useMemo(() => {
    const term = query.toLowerCase().trim();
    const list = orders.filter((order) => {
      const searchable = `${order.customerName} ${order.customerPhone ?? ''} ${order.recipientName ?? ''} ${order.id} ${order.orderNumber}`.toLowerCase();
      const matchesTerm = !term || searchable.includes(term);
      const matchesStatus = statusFilter === 'all' || order.status === statusFilter;
      return matchesTerm && matchesStatus;
    });

    return [...list].sort((a, b) => {
      if (sortBy === 'oldest') return new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime();
      if (sortBy === 'total_desc') return b.total - a.total;
      if (sortBy === 'total_asc') return a.total - b.total;
      if (sortBy === 'customer_asc') return a.customerName.localeCompare(b.customerName, 'pt-BR');
      return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
    });
  }, [orders, query, statusFilter, sortBy]);

  const recoveryOrders = useMemo(() => {
    const now = Date.now();
    return orders.filter((order) => {
      const age = now - new Date(order.createdAt).getTime();
      return settings.salesRecoveryEnabled && Boolean(order.customerPhone) && order.status === 'draft' && !order.whatsappClickedAt && age >= settings.salesRecoveryMinutes * 60_000 && age <= 72 * 60 * 60_000;
    }).slice(0, 12);
  }, [orders, settings.salesRecoveryEnabled, settings.salesRecoveryMinutes]);

  const customers = useMemo(() => {
    const map = new Map<string, { key:string; name:string; phone:string; orders:number; total:number; lastAt:string }>();
    for (const order of orders) {
      const key = normalizeWhatsappPhone(order.customerPhone);
      if (!key || order.status === 'cancelled') continue;
      const current = map.get(key);
      if (!current) map.set(key, { key, name:order.customerName, phone:order.customerPhone || key, orders:1, total:order.total, lastAt:order.createdAt });
      else { current.orders += 1; current.total += order.total; if (new Date(order.createdAt).getTime() > new Date(current.lastAt).getTime()) { current.lastAt=order.createdAt; current.name=order.customerName; } }
    }
    return [...map.values()].sort((a,b)=>new Date(b.lastAt).getTime()-new Date(a.lastAt).getTime()).slice(0,20);
  }, [orders]);

  useEffect(() => {
    if (!highlightedOrderId) return;
    const highlightedOrder = orders.find((order) => order.id === highlightedOrderId);
    if (!highlightedOrder) return;

    // Garante que filtros locais não escondam o pedido vindo do Financeiro.
    setQuery('');
    setStatusFilter('all');

    const timer = window.setTimeout(() => {
      const row = rowsRef.current[highlightedOrderId];
      row?.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }, 180);
    return () => window.clearTimeout(timer);
  }, [highlightedOrderId, orders]);

  if (loading) return <LoadingState label="Carregando pedidos..." />;
  if (error) return <ErrorState message={error} onRetry={() => void reloadAdmin()} />;

  return (
    <>
      <div className="admin-page-title">
        <div>
          <span className="eyebrow">PEDIDOS</span>
          <h1>Pedidos realizados</h1>
          <p>Confirme o recebimento no próprio pedido. A entrada é registrada automaticamente no Financeiro, sem duplicidade.</p>
        </div>
      </div>

      <div className="sales-ops-grid-rc617">
        <details className="sales-ops-panel-rc617" open={recoveryOrders.length > 0}>
          <summary><span><RotateCcw size={18}/><strong>Recuperação de vendas</strong></span><b>{recoveryOrders.length}</b></summary>
          <p>Pedidos registrados há pelo menos {settings.salesRecoveryMinutes} minutos em que o WhatsApp ainda não foi aberto. O contato continua manual, com mensagem pronta.</p>
          {recoveryOrders.length ? <div className="sales-ops-list-rc617">{recoveryOrders.map((order)=><article key={order.id}><div><strong>#{formatOrderNumber(order.orderNumber)} · {order.customerName}</strong><span>{currency.format(order.total)} · {formatDateTimeBR(order.createdAt)}</span></div><button type="button" onClick={()=>openCustomerWhatsapp(order.customerPhone,buildSalesRecoveryMessage(settings.name,order))}><MessageCircle size={15}/>Recuperar venda</button></article>)}</div> : <div className="sales-ops-empty-rc617">Nenhuma oportunidade pendente agora.</div>}
        </details>
        {settings.crmEnabled&&<details className="sales-ops-panel-rc617">
          <summary><span><Users size={18}/><strong>CRM simples de clientes</strong></span><b>{customers.length}</b></summary>
          <p>Frequência, valor acumulado e última compra, calculados a partir dos pedidos recentes.</p>
          {customers.length ? <div className="sales-ops-list-rc617">{customers.map((customer)=><article key={customer.key}><div><strong>{customer.name}</strong><span>{customer.orders} pedido{customer.orders===1?'':'s'} · {currency.format(customer.total)} · último {new Date(customer.lastAt).toLocaleDateString('pt-BR')}</span></div><button type="button" onClick={()=>openCustomerWhatsapp(customer.phone,buildComeBackMessage(settings.name,customer.name))}><MessageCircle size={15}/>Mensagem de recompra</button></article>)}</div> : <div className="sales-ops-empty-rc617">Os clientes aparecerão aqui conforme os pedidos forem chegando.</div>}
        </details>}
      </div>

      <section className="admin-card no-padding">
        <div className="table-toolbar orders-toolbar orders-toolbar--filters">
          <div className="admin-search">
            <Search size={18} />
            <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Buscar pedido, cliente, telefone ou destinatário..." />
          </div>

          <div className="toolbar-selects">
            <label>
              <span>Status</span>
              <select value={statusFilter} onChange={(event) => setStatusFilter(event.target.value as 'all' | OrderStatus)}>
                <option value="all">Todos</option>
                <option value="draft">Pedido realizado</option>
                <option value="sent_to_whatsapp">WhatsApp aberto</option>
                <option value="cancelled">Cancelado</option>
              </select>
            </label>
            <label>
              <span>Ordenar por</span>
              <select value={sortBy} onChange={(event) => setSortBy(event.target.value as SortMode)}>
                {sortOptions.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}
              </select>
            </label>
          </div>

          <div className="orders-toolbar__sync" aria-live="polite">
            <span>{filtered.length} pedido{filtered.length === 1 ? '' : 's'}</span>
            <small>{lastUpdatedAt ? `Atualizado às ${lastUpdatedAt.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit', second: '2-digit' })}` : 'Atualização automática ativa'}</small>
            <button type="button" className="secondary-button compact-button" onClick={() => void refreshOrders()} disabled={refreshing} aria-busy={refreshing}>
              <RefreshCw size={15} className={refreshing ? 'spin' : ''} />
              {refreshing ? 'Atualizando...' : 'Atualizar'}
            </button>
          </div>
        </div>

        {highlightedOrderId && (
          <div className="highlight-order-banner">O pedido relacionado vindo do Financeiro foi destacado abaixo.</div>
        )}

        {filtered.length === 0 ? (
          <div className="admin-empty">
            <ShoppingBag size={32} />
            <strong>Nenhum pedido encontrado</strong>
            <span>Ajuste os filtros ou aguarde o próximo pedido registrado.</span>
          </div>
        ) : (
          <div className="responsive-table">
            <table>
              <thead>
                <tr>
                  <th>Pedido</th>
                  <th>Cliente</th>
                  <th>Entrega / retirada</th>
                  <th>Pagamento</th>
                  <th>Total</th>
                  <th>Recebimento</th>
                  <th>Status</th>
                  <th>Criado em</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((order) => {
                  const highlighted = order.id === highlightedOrderId;
                  return (
                    <tr
                      key={order.id}
                      ref={(node) => {
                        rowsRef.current[order.id] = node;
                      }}
                      className={highlighted ? 'order-row-highlighted' : ''}
                    >
                      <td>
                        <strong>#{order.orderNumber ? formatOrderNumber(order.orderNumber) : order.id.slice(0, 8)}</strong>
                        {highlighted && <small>Pedido vindo do Financeiro</small>}
                      </td>
                      <td>
                        <div className="order-customer">
                          <strong>{order.customerName}</strong>
                          <span>{order.customerPhone || order.recipientName || 'Sem telefone informado'}</span>
                        </div>
                      </td>
                      <td>
                        <div className="order-customer">
                          <strong>{order.deliveryType === 'delivery' ? 'Entrega' : 'Retirada'} · {formatDateBR(order.desiredDate)}</strong>
                          {order.deliveryType === 'delivery' && order.deliveryZoneName && (
                            <span>{order.deliveryZoneName}{order.deliveryFee != null ? ` · ${currency.format(order.deliveryFee)}` : ''}</span>
                          )}
                        </div>
                      </td>
                      <td><strong>{paymentLabel[order.paymentMethod]}</strong></td>
                      <td><strong>{currency.format(order.total)}</strong>{order.deliveryFee ? <small className="order-fee-note">inclui {currency.format(order.deliveryFee)} de entrega</small> : null}</td>
                      <td>
                        {order.paymentStatus === 'paid' ? (
                          <span className="order-payment-received">
                            <CheckCircle2 size={15} />
                            <span><strong>Recebido</strong>{order.paymentReceivedAt ? <small>{formatDateTimeBR(order.paymentReceivedAt)}</small> : null}</span>
                          </span>
                        ) : order.status === 'cancelled' ? (
                          <span className="order-payment-cancelled">Pedido cancelado</span>
                        ) : (
                          <button
                            type="button"
                            className="order-payment-confirm-button"
                            disabled={confirmingPaymentId === order.id}
                            onClick={() => void confirmPayment(order.id, order.orderNumber, order.total)}
                          >
                            <CircleDollarSign size={15} />
                            {confirmingPaymentId === order.id ? 'Confirmando...' : 'Confirmar recebimento'}
                          </button>
                        )}
                      </td>
                      <td><span className={`order-status order-status--${order.status}`}><MessageCircle size={13} />{statusLabel[order.status]}</span></td>
                      <td>{formatDateTimeBR(order.createdAt)}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </>
  );
}
