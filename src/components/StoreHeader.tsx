import { AtSign, Clock3, MapPin, MessageCircle, Search, ShoppingBag } from 'lucide-react';
import { useEffect, useMemo, useRef, useState } from 'react';
import { useCart } from '../contexts/CartContext';
import { useStore } from '../contexts/StoreContext';
import { storefrontPath } from '../utils/storefrontRoute';
import { normalizeInstagramHandle, sanitizeWhatsAppNumber } from '../utils/format';
import { getOpeningScheduleOverview, getStoreOpenStatus } from '../utils/storeHours';
import { ImageWithFallback } from './ui/ImageWithFallback';

export function StoreHeader({searchOpen,onSearchClick}:{searchOpen?:boolean;onSearchClick?:()=>void}){
  const {settings,storeBasePath}=useStore();
  const {totalItems}=useCart();
  const instagram=normalizeInstagramHandle(settings.instagram);
  const whatsapp=sanitizeWhatsAppNumber(settings.whatsapp);
  const status=useMemo(()=>getStoreOpenStatus(settings.openingSchedule),[settings.openingSchedule]);
  const scheduleOverview=useMemo(()=>getOpeningScheduleOverview(settings.openingSchedule),[settings.openingSchedule]);
  const todaySchedule=scheduleOverview.today?.summary||'Consulte os horários';
  const [hoursOpen,setHoursOpen]=useState(false);
  const hoursRef=useRef<HTMLDivElement|null>(null);

  useEffect(()=>{
    const onPointerDown=(event:PointerEvent)=>{
      if(!hoursOpen)return;
      const target=event.target as Node|null;
      if(target && !hoursRef.current?.contains(target))setHoursOpen(false);
    };
    const onKeyDown=(event:KeyboardEvent)=>{if(event.key==='Escape')setHoursOpen(false);};
    document.addEventListener('pointerdown',onPointerDown);
    document.addEventListener('keydown',onKeyDown);
    return()=>{document.removeEventListener('pointerdown',onPointerDown);document.removeEventListener('keydown',onKeyDown);};
  },[hoursOpen]);

  return <>
    <div className="hero" role="img" style={{backgroundImage:`url(${settings.heroUrl})`}} aria-label="Capa da floricultura"/>
    <section className="store-card container">
      <ImageWithFallback className="store-card__logo" src={settings.logoUrl} alt={`Logo ${settings.name}`}/>
      <div className="store-card__main">
        <div className="store-card__title-row">
          <div><h1>{settings.name}</h1><span className="store-card__location"><MapPin size={15}/>{settings.city} — {settings.state}</span></div>
          <div className="store-status"><span className={`open-pill ${status.open?'is-open':'is-closed'}`}>{status.label}</span><small>{status.detail}</small></div>
        </div>
        <p className="store-card__tagline">{settings.tagline}</p>
        <div className="store-card__chips">
          {settings.deliveryEnabled&&<span>Entrega</span>}
          {settings.pickupEnabled&&<span>Retirada</span>}
          <span className="store-today-hours"><Clock3 size={13}/><b>Hoje</b>{todaySchedule}</span>
          <div className="store-hours-popover" ref={hoursRef}>
            <button type="button" className="store-hours-button" aria-expanded={hoursOpen} aria-haspopup="dialog" onClick={()=>setHoursOpen((current)=>!current)}>Outros dias</button>
            {hoursOpen&&<div className="store-hours-details__list" role="dialog" aria-label="Horários da semana">
              {scheduleOverview.days.map((day)=><div key={day.day} className={day.isToday?'is-today':''}><strong>{day.shortLabel}</strong><span>{day.summary}</span></div>)}
            </div>}
          </div>
        </div>
      </div>
      <div className="store-card__actions">
        {whatsapp&&<a className="outline-action" href={`https://wa.me/${whatsapp}`} target="_blank" rel="noreferrer" aria-label="Falar com a loja pelo WhatsApp" title="Contato geral com a floricultura"><MessageCircle size={18}/>Atendimento</a>}
        {instagram&&<a className="outline-action" href={`https://instagram.com/${instagram}`} target="_blank" rel="noreferrer"><AtSign size={18}/>Instagram</a>}
        {onSearchClick&&<button type="button" className={`icon-action ${searchOpen?'is-active':''}`} onClick={onSearchClick} aria-label="Pesquisar"><Search size={20}/></button>}
        <a className="icon-action cart-action" href={storefrontPath(storeBasePath,"/carrinho")} aria-label="Carrinho"><ShoppingBag size={20}/>{totalItems>0&&<span>{totalItems}</span>}</a>
      </div>
    </section>
  </>;
}
