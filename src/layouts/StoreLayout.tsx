import { ArrowRight, Clock3, Flower2, ShoppingBag } from 'lucide-react';
import { useEffect } from 'react';
import { Outlet, useLocation } from 'react-router-dom';
import PlatformHelpButton from '../components/PlatformHelpButton';
import { useCart } from '../contexts/CartContext';
import { useStore } from '../contexts/StoreContext';
import { isFloriWebMarketingRoot } from '../lib/config';
import { currency } from '../utils/format';
import { storefrontPath } from '../utils/storefrontRoute';

export default function StoreLayout() {
  const location = useLocation();
  const { storeUnavailable, unavailableStoreName, storeBasePath, settings } = useStore();
  const { totalItems, subtotal } = useCart();
  const marketing = typeof window !== 'undefined' && isFloriWebMarketingRoot(location.pathname, window.location.hostname);

  useEffect(() => {
    window.scrollTo({ top: 0, left: 0, behavior: 'auto' });
  }, [location.pathname]);

  if (marketing) {
    return (
      <main className="store-layout flori-marketing-layout">
        <Outlet />
      </main>
    );
  }

  if (storeUnavailable) {
    return (
      <main className="store-layout storefront-unavailable-page">
        <section className="storefront-unavailable-card">
          <div className="storefront-unavailable-icon"><Flower2 size={30} /></div>
          <span className="eyebrow">CATÁLOGO TEMPORARIAMENTE INDISPONÍVEL</span>
          <h1>{unavailableStoreName || 'Floricultura'}</h1>
          <p>Esta loja está passando por uma pausa temporária no catálogo online.</p>
          <div className="storefront-unavailable-note">
            <Clock3 size={18} />
            <span>Tente novamente mais tarde. Nenhum dado do estabelecimento ou dos pedidos anteriores foi removido.</span>
          </div>
          <small>FloriWeb · catálogo digital para floriculturas</small>
        </section>
        <PlatformHelpButton context="store" storeName={unavailableStoreName} />
      </main>
    );
  }

  const path = location.pathname;
  const hideDock = path.includes('/carrinho') || path.includes('/finalizar') || path.includes('/pedido/');
  const showDock = totalItems > 0 && !hideDock;

  return (
    <main className={`store-layout ${showDock ? 'has-mobile-cart-dock' : ''}`}>
      <div key={location.pathname} className="store-route-view"><Outlet /></div>
      {showDock && (
        <a
          className="mobile-cart-dock"
          href={storefrontPath(storeBasePath, '/carrinho')}
          aria-label={`Abrir carrinho com ${totalItems} item(ns)`}
        >
          <span className="mobile-cart-dock__icon"><ShoppingBag size={19} /><b>{totalItems}</b></span>
          <span className="mobile-cart-dock__copy"><small>Seu carrinho</small><strong>{currency.format(subtotal)}</strong></span>
          <span className="mobile-cart-dock__action">Ver carrinho <ArrowRight size={17} /></span>
        </a>
      )}
      <PlatformHelpButton context="store" storeName={settings.name} />
    </main>
  );
}
