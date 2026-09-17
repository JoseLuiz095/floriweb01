import {
  BadgeDollarSign,
  BarChart3,
  CircleAlert,
  CircleCheckBig,
  ExternalLink,
  Flower2,
  Landmark,
  LayoutDashboard,
  LogOut,
  Menu,
  Package,
  Puzzle,
  Rocket,
  Settings,
  ShoppingBag,
  Tags,
  Truck,
  WalletCards,
  X,
} from 'lucide-react';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom';
import { ImageWithFallback } from '../components/ui/ImageWithFallback';
import PlatformHelpButton from '../components/PlatformHelpButton';
import { useAuth } from '../contexts/AuthContext';
import { useStore } from '../contexts/StoreContext';
import { loadBillingOverview, type BillingOverview } from '../services/billingFinanceApi';

const navSections = [
  {
    label: 'Operação',
    items: [
      { to: '/admin', label: 'Visão geral', icon: LayoutDashboard, end: true },
      { to: '/admin/primeiros-passos', label: 'Primeiros passos', icon: Rocket },
      { to: '/admin/analytics', label: 'Análises', icon: BarChart3, requiresReports: true },
      { to: '/admin/pedidos', label: 'Pedidos', icon: ShoppingBag },
    ],
  },
  {
    label: 'Catálogo',
    items: [
      { to: '/admin/produtos', label: 'Produtos', icon: Package },
      { to: '/admin/categorias', label: 'Categorias', icon: Tags },
      { to: '/admin/adicionais', label: 'Adicionais', icon: Puzzle },
      { to: '/admin/entregas', label: 'Entregas', icon: Truck },
    ],
  },
  { label: 'Gestão', items: [{ to: '/admin/financeiro', label: 'Financeiro', icon: Landmark }] },
  {
    label: 'Conta',
    items: [
      { to: '/admin/plano', label: 'Meu plano', icon: BadgeDollarSign },
      { to: '/admin/mensalidade', label: 'Mensalidade e PIX', icon: WalletCards },
      { to: '/admin/configuracoes', label: 'Configurações', icon: Settings },
    ],
  },
];

const dateBr = (value?: string) => {
  if (!value) return '—';
  const [year, month, day] = value.slice(0, 10).split('-');
  return year && month && day ? `${day}/${month}/${year}` : value;
};

const isDateOverdue = (value?: string) => {
  if (!value) return false;
  const today = new Date();
  const todayKey = [today.getFullYear(), String(today.getMonth() + 1).padStart(2, '0'), String(today.getDate()).padStart(2, '0')].join('-');
  return value.slice(0, 10) < todayKey;
};

export default function AdminLayout() {
  const { settings, planUsage, dataMode } = useStore();
  const { user, signOut, platformAdmin, membership, memberships, selectStore } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [open, setOpen] = useState(false);
  const [billing, setBilling] = useState<BillingOverview | null>(null);

  const logout = async () => {
    await signOut();
    navigate('/admin/login', { replace: true });
  };

  const refreshBilling = useCallback(async () => {
    if (!membership?.storeId || dataMode !== 'supabase') {
      setBilling(null);
      return;
    }
    try {
      setBilling(await loadBillingOverview(membership.storeId));
    } catch {
      // O status de cobrança é informativo e não deve bloquear o restante do painel.
      setBilling(null);
    }
  }, [membership?.storeId, dataMode]);

  useEffect(() => {
    void refreshBilling();
    const interval = window.setInterval(() => void refreshBilling(), 120_000);
    const onFocus = () => void refreshBilling();
    window.addEventListener('focus', onFocus);
    return () => {
      window.clearInterval(interval);
      window.removeEventListener('focus', onFocus);
    };
  }, [refreshBilling]);

  const storeOnline = settings.active && settings.accessStatus !== 'suspended';
  const subscription = billing?.subscription;
  const showBillingState = Boolean(subscription && subscription.billingState !== 'trial' && subscription.billingState !== 'none');
  const overdue = showBillingState && (subscription?.billingState === 'overdue' || isDateOverdue(subscription?.nextDueDate));

  const billingCaption = useMemo(() => {
    if (!subscription?.nextDueDate) return overdue ? 'Pagamento pendente' : 'Sem vencimento definido';
    const today = new Date();
    const todayKey = [today.getFullYear(), String(today.getMonth() + 1).padStart(2, '0'), String(today.getDate()).padStart(2, '0')].join('-');
    if (subscription.nextDueDate.slice(0, 10) === todayKey) return `Vence hoje · dia ${subscription.dueDay || '—'}`;
    return overdue
      ? `Venceu ${dateBr(subscription.nextDueDate)}`
      : `Próximo ${dateBr(subscription.nextDueDate)}`;
  }, [overdue, subscription?.dueDay, subscription?.nextDueDate]);

  return (
    <div className="admin-shell">
      <button className="admin-mobile-menu" onClick={() => setOpen(true)} aria-label="Abrir menu"><Menu size={21} /></button>
      {open && <button className="admin-backdrop" onClick={() => setOpen(false)} aria-label="Fechar menu" />}

      <aside className={`admin-sidebar ${open ? 'is-open' : ''}`}>
        <button className="admin-sidebar-close" onClick={() => setOpen(false)} aria-label="Fechar"><X /></button>
        <div className="admin-brand"><Flower2 size={24} /><div><strong>FloriWeb</strong><span>Administração</span></div></div>
        <div className="admin-store-mini"><ImageWithFallback src={settings.logoUrl} alt={`Logo ${settings.name}`} /><div><strong>{settings.name}</strong><span>{settings.city} · {settings.state}</span></div></div>
        {memberships.length > 1 && (
          <label className="admin-store-switcher">
            <span>Loja ativa</span>
            <select value={membership?.storeId || ''} onChange={(event) => selectStore(event.target.value)}>
              {memberships.map((item) => <option value={item.storeId} key={item.storeId}>{item.storeName || item.storeId}</option>)}
            </select>
          </label>
        )}
        <nav className="admin-nav">
          {navSections.map((section) => {
            const items = section.items.filter((item: any) => !item.requiresReports || planUsage.plan.reports);
            return (
              <div className="admin-nav__group" key={section.label}>
                <span className="admin-nav__label">{section.label}</span>
                {items.map(({ to, label, icon: Icon, end }: any) => (
                  <NavLink key={to} to={to} end={end} onClick={() => setOpen(false)}><Icon size={18} />{label}</NavLink>
                ))}
              </div>
            );
          })}
        </nav>
        <div className="admin-sidebar__bottom">
          <a href={`/${settings.slug}`} target="_blank" rel="noreferrer"><ExternalLink size={18} /> Ver loja pública</a>
          {platformAdmin && <a href="/admin-master"><LayoutDashboard size={18} /> Admin Master</a>}
          <button onClick={() => void logout()}><LogOut size={18} /> Sair</button>
        </div>
      </aside>

      <section className="admin-content">
        <header className="admin-topbar">
          <div className="admin-topbar__context">
            <span className="eyebrow">{dataMode === 'demo' ? 'MODO DEMONSTRAÇÃO' : 'SUPABASE ATIVO'}</span>
            <div className="admin-topbar__meta">
              <strong>Plano {planUsage.plan.name}</strong>
              <span className={`admin-live-status ${storeOnline ? 'is-online' : 'is-offline'}`}><CircleCheckBig size={14} />{storeOnline ? 'Loja online' : 'Loja indisponível'}</span>
            </div>
          </div>

          {showBillingState && (
            <button
              type="button"
              className={`admin-billing-status-rc65 ${overdue ? 'is-overdue' : 'is-current'}`}
              onClick={() => navigate('/admin/mensalidade')}
              title="Abrir detalhes da mensalidade"
            >
              {overdue ? <CircleAlert size={18} /> : <CircleCheckBig size={18} />}
              <span>
                <strong>{overdue ? 'Mensalidade atrasada' : 'Mensalidade em dia'}</strong>
                <small>{billingCaption}</small>
              </span>
            </button>
          )}

          <div className="admin-topbar__actions">
            <a className="admin-topbar__store-link" href={`/${settings.slug}`} target="_blank" rel="noreferrer"><ExternalLink size={15} />Abrir vitrine</a>
            <div className="admin-user"><span>{(user?.email || 'AD').slice(0, 2).toUpperCase()}</span><div><strong>{membership?.storeName || 'Administrador'}</strong><small>{user?.email}</small></div></div>
          </div>
        </header>
        <div className="admin-page"><div key={`${location.pathname}:${membership?.storeId || 'none'}`}><Outlet /></div></div>
      </section>
      <PlatformHelpButton />
    </div>
  );
}
