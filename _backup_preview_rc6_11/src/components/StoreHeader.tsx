import { Clock3, MapPin, MessageCircle, ShoppingBag } from 'lucide-react';
import { useMemo } from 'react';
import { useCart } from '../contexts/CartContext';
import { useStore } from '../contexts/StoreContext';
import { sanitizeWhatsAppNumber } from '../utils/format';
import { getOpeningScheduleOverview, getStoreOpenStatus } from '../utils/storeHours';

export function StoreHeader() {
  const { settings } = useStore();
  const { totalItems } = useCart();
  const whatsapp = sanitizeWhatsAppNumber(settings.whatsapp);
  const status = useMemo(() => getStoreOpenStatus(settings.openingSchedule), [settings.openingSchedule]);
  const scheduleOverview = useMemo(() => getOpeningScheduleOverview(settings.openingSchedule), [settings.openingSchedule]);
  const todaySchedule = scheduleOverview.today?.summary || 'Consulte os horários';

  return (
    <header className="hero" style={{ backgroundImage: `url(${settings.heroUrl})` }}>
      <div className="hero-overlay">
        <div className="container hero-content">
          <div className="top-nav">
            <div className="brand">FloriWeb</div>
            <a className="cart-link" href="/carrinho" aria-label="Ir para o carrinho">
              <ShoppingBag size={18} />
              <span>{totalItems}</span>
            </a>
          </div>
          <div className="store-card">
            <img className="store-logo" src={settings.logoUrl} alt={settings.name} />
            <div className="store-info">
              <div className="store-meta-top">
                <div>
                  <h1>{settings.name}</h1>
                  <div className="store-location">
                    <MapPin size={14} />
                    <span>{settings.city} — {settings.state}</span>
                  </div>
                </div>
                <div className="store-status-box">
                  <span className={`status-pill ${status.open ? 'open' : 'closed'}`}>{status.label}</span>
                  <small>{status.detail}</small>
                </div>
              </div>
              <p>{settings.description || settings.tagline}</p>
              <div className="store-fulfillment-row">
                {settings.pickupEnabled && <span className="fulfillment-pill">Retirada</span>}
                <div className="hours-summary-card">
                  <div className="hours-summary-line">
                    <Clock3 size={14} />
                    <div>
                      <strong>Hoje</strong>
                      <span>{todaySchedule}</span>
                    </div>
                  </div>
                  <details className="hours-details">
                    <summary>Ver horários da semana</summary>
                    <div className="hours-details-list">
                      {scheduleOverview.days.map((day) => (
                        <div key={day.day} className={`hours-details-item ${day.isToday ? 'is-today' : ''}`}>
                          <strong>{day.shortLabel}</strong>
                          <span>{day.summary}</span>
                        </div>
                      ))}
                    </div>
                  </details>
                </div>
              </div>
              <div className="store-actions">
                <a className="primary-button" href={`https://wa.me/${whatsapp}`} target="_blank" rel="noreferrer"><MessageCircle size={18} /> Atendimento</a>
                {settings.instagram && <a className="secondary-button" href={settings.instagram.startsWith('http') ? settings.instagram : `https://instagram.com/${settings.instagram.replace('@', '')}`} target="_blank" rel="noreferrer">Instagram</a>}
              </div>
            </div>
          </div>
        </div>
      </div>
    </header>
  );
}
