import { RefreshCw, Search, ShoppingBag } from 'lucide-react';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { ErrorState, LoadingState } from '../../components/ui/AsyncState';
import { useStore } from '../../contexts/StoreContext';
import { currency, formatDateTimeBR } from '../../utils/format';
import { formatOrderNumber } from '../../utils/orderConfirmation';
import type { OrderStatus, PaymentMethod } from '../../types';

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
  const { orders, loading, error, reloadAdmin } = useStore();
  const [searchParams] = useSearchParams();
  const [query, setQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<'all' | OrderStatus>('all');
  const [sortBy, setSortBy] = useState<SortMode>('newest');
  const [refreshing, setRefreshing] = useState(false);
  const [lastUpdatedAt, setLastUpdatedAt] = useState<Date | null>(null);
  const rowsRef = useRef<Record<string, HTMLTableRowElement | null>>({});
  const highlightedOrderId = searchParams.get('highlight') || '';

  const refreshOrders = useCallback(async () => {
    setRefreshing(true);
    try {
      await reloadAdmin({ silent: true });
      setLastUpdatedAt(new Date());
    } finally {
      setRefreshing(false);
    }
  }, [reloadAdmin]);

  useEffect(() => {
    if (!highlightedOrderId) return;
    const row = rowsRef.current[highlightedOrderId];
    if (!row) return;
    const timer = window.setTimeout(() => {
      row.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }, 160);
    return () => window.clearTimeout(timer);
  }, [highlightedOrderId, orders.length]);

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

  if (loading) return <LoadingState label="Carregando pedidos..." />;
  if (error) return <ErrorState message={error} onRetry={() => void reloadAdmin()} />;

  return (
    <>
      <div className="admin-page-title">
        <div>
          <span className="eyebrow">PEDIDOS</span>
          <h1>Pedidos realizados</h1>
          <p>Agora você pode localizar pedidos com mais facilidade, ordenar a visualização e abrir o pedido relacionado a partir do Financeiro com destaque automático.</p>
        </div>
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
            <small>{lastUpdatedAt ? `Atualizado às ${lastUpdatedAt.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })}` : 'Atualização automática ativa'}</small>
            <button type="button" className="secondary-button compact-button" onClick={() => void refreshOrders()} disabled={refreshing}>
              <RefreshCw size={15} className={refreshing ? 'spin' : ''} />
              {refreshing ? 'Atualizando...' : 'Atualizar'}
            </button>
          </div>
        </div>

        {highlightedOrderId && (
          <div className="highlight-order-banner">O pedido relacionado vindo do Financeiro foi destacado na lista abaixo.</div>
        )}

        {filtered.length === 0 ? (
          <div className="admin-empty">
            <ShoppingBag size={32} />
            <strong>Nenhum pedido encontrado</strong>
            <span>Depois que o cliente registrar um pedido, ele aparecerá aqui.</span>
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
                        <strong>Pedido #{formatOrderNumber(order.orderNumber)}</strong>
                        <small>{order.id}</small>
                      </td>
                      <td>
                        <strong>{order.customerName}</strong>
                        <small>{order.customerPhone || 'Telefone não informado'}</small>
                      </td>
                      <td>
                        <strong>{order.deliveryType === 'delivery' ? 'Entrega' : 'Retirada'}</strong>
                        <small>{order.deliveryType === 'delivery' ? (order.deliveryNeighborhood || order.deliveryAddress || 'Endereço não informado') : 'Retirada na loja'}</small>
                      </td>
                      <td>
                        <strong>{paymentLabel[order.paymentMethod]}</strong>
                        <small>{order.recipientName ? `Destinatário: ${order.recipientName}` : 'Sem destinatário separado'}</small>
                      </td>
                      <td><strong>{currency.format(order.total)}</strong></td>
                      <td><span className={`status-badge ${order.status}`}>{statusLabel[order.status]}</span></td>
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
