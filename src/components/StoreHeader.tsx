import { AtSign, Clock3, MapPin, MessageCircle, Search, ShoppingBag } from 'lucide-react';
import { useMemo } from 'react';
import { useCart } from '../contexts/CartContext';
import { useStore } from '../contexts/StoreContext';
import { storefrontPath } from '../utils/storefrontRoute';
import { normalizeInstagramHandle, sanitizeWhatsAppNumber } from '../utils/format';
import { getStoreOpenStatus } from '../utils/storeHours';
import { ImageWithFallback } from './ui/ImageWithFallback';

export function StoreHeader({searchOpen,onSearchClick}:{searchOpen?:boolean;onSearchClick?:()=>void}){
  const {settings,storeBasePath}=useStore();const {totalItems}=useCart();
  const instagram=normalizeInstagramHandle(settings.instagram);const whatsapp=sanitizeWhatsAppNumber(settings.whatsapp);
  const status=useMemo(()=>getStoreOpenStatus(settings.openingSchedule),[settings.openingSchedule]);
  return <>
    <div className="hero" style={{backgroundImage:`url(${settings.heroUrl})`}} aria-label="Capa da floricultura"/>
    <section className="store-card container">
      <ImageWithFallback className="store-card__logo" src={settings.logoUrl} alt={`Logo ${settings.name}`}/>
      <div className="store-card__main">
        <div className="store-card__title-row"><div><h1>{settings.name}</h1><span className="store-card__location"><MapPin size={15}/>{settings.city} — {settings.state}</span></div><div className="store-status"><span className={`open-pill ${status.open?'is-open':'is-closed'}`}>{status.label}</span><small>{status.detail}</small></div></div>
        <p className="store-card__tagline">{settings.tagline}</p>
        <div className="store-card__chips">{settings.deliveryEnabled&&<span>Entrega</span>}{settings.pickupEnabled&&<span>Retirada</span>}<span title={settings.openingHours}><Clock3 size={13}/>{settings.openingHours || 'Horários configuráveis'}</span></div>
      </div>
      <div className="store-card__actions">{whatsapp&&<a className="outline-action" href={`https://wa.me/${whatsapp}`} target="_blank" rel="noreferrer" aria-label="Falar com a loja pelo WhatsApp" title="Contato geral com a floricultura"><MessageCircle size={18}/>Atendimento</a>}{instagram&&<a className="outline-action" href={`https://instagram.com/${instagram}`} target="_blank" rel="noreferrer"><AtSign size={18}/>Instagram</a>}{onSearchClick&&<button type="button" className={`icon-action ${searchOpen?'is-active':''}`} onClick={onSearchClick} aria-label="Pesquisar"><Search size={20}/></button>}<a className="icon-action cart-action" href={storefrontPath(storeBasePath,"/carrinho")} aria-label="Carrinho"><ShoppingBag size={20}/>{totalItems>0&&<span>{totalItems}</span>}</a></div>
    </section>
  </>;
}
