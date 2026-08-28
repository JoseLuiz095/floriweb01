import { ArrowLeft, Check, Clock3, Minus, Plus, Share2, ShoppingBag } from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';
import { useParams } from 'react-router-dom';
import { ImageWithFallback } from '../../components/ui/ImageWithFallback';
import { LoadingState } from '../../components/ui/AsyncState';
import { useCart } from '../../contexts/CartContext';
import { useStore } from '../../contexts/StoreContext';
import type { Addon, ProductVariation } from '../../types';
import { addDaysLocalISO, currency, formatDateBR, roundMoney } from '../../utils/format';
import { useToast } from '../../contexts/ToastContext';
import { storefrontPath } from '../../utils/storefrontRoute';
import { trackPublicEvent } from '../../services/analyticsApi';

export default function ProductDetail(){
  const {slug}=useParams();const {products,categories,settings,loading,storeBasePath}=useStore();const {addItem}=useCart();const {showToast}=useToast();const product=products.find(p=>p.slug===slug&&p.active);
  const[quantity,setQuantity]=useState(1);const[variationId,setVariationId]=useState('');const[selectedAddonIds,setSelectedAddonIds]=useState<string[]>([]);const[imageIndex,setImageIndex]=useState(0);
  useEffect(()=>{setQuantity(1);setVariationId('');setSelectedAddonIds([]);setImageIndex(0)},[product?.id]);
  useEffect(()=>{if(!loading&&product?.id&&settings.id)void trackPublicEvent(settings.id,'product_view',product.id)},[loading,product?.id,settings.id]);
  const variations=product?.variations.filter(v=>v.active)??[];const selectedVariation=variations.find(v=>v.id===variationId)??variations[0];const selectedAddons=(product?.addons??[]).filter(a=>selectedAddonIds.includes(a.id)&&a.active);
  const total=useMemo(()=>{if(!product)return 0;const base=product.promotionalPrice??product.price;return roundMoney((base+(selectedVariation?.priceDelta??0)+selectedAddons.reduce((s,a)=>s+a.price,0))*quantity)},[product,selectedVariation,selectedAddons,quantity]);
  if(loading)return <div className="page-center"><LoadingState label="Carregando produto..."/></div>;
  if(!product)return <div className="not-found"><h2>Produto não encontrado</h2><a href={storefrontPath(storeBasePath)}>Voltar ao catálogo</a></div>;
  const category=categories.find(c=>c.id===product.categoryId);const gallery=product.gallery.length?product.gallery:[product.imageUrl];const unavailable=product.stockStatus==='unavailable';
  const toggleAddon=(addon:Addon)=>setSelectedAddonIds(current=>current.includes(addon.id)?current.filter(id=>id!==addon.id):[...current,addon.id]);
  const share=async()=>{const url=window.location.href;try{if(navigator.share)await navigator.share({title:product.name,text:product.description,url});else{await navigator.clipboard.writeText(url);showToast('Link do produto copiado.','success')}}catch{/* usuário cancelou */}};
  const add=()=>{if(unavailable)return;if(!variationId&&variations.length)setVariationId(variations[0].id);addItem(product,quantity,selectedVariation,selectedAddons);void trackPublicEvent(settings.id,'add_to_cart',product.id);showToast('Produto adicionado ao carrinho.','success');window.location.assign(storefrontPath(storeBasePath,'/carrinho'))};
  return <div className="simple-page"><header className="simple-topbar container"><a href={storefrontPath(storeBasePath)}><ArrowLeft size={19}/>Voltar ao catálogo</a><button onClick={()=>void share()}><Share2 size={18}/>Compartilhar</button></header><div className="container product-detail-layout">
    <section className="product-gallery"><div className="product-main-image"><ImageWithFallback src={gallery[imageIndex]||gallery[0]} alt={product.name}/>{product.madeToOrder&&<span className="gallery-badge"><Clock3 size={14}/>Sob encomenda</span>}</div>{gallery.length>1&&<div className="gallery-thumbs">{gallery.map((src,index)=><button key={`${src}-${index}`} className={imageIndex===index?'active':''} onClick={()=>setImageIndex(index)}><ImageWithFallback src={src} alt={`${product.name} ${index+1}`}/></button>)}</div>}</section>
    <section className="product-detail-info"><span className="eyebrow">{category?.name??'PRODUTO'}</span><h1>{product.name}</h1><p className="product-long-description">{product.description}</p>{product.madeToOrder&&<div className="made-to-order"><Clock3 size={19}/><div><strong>Produzido sob encomenda</strong><span>Prazo de produção: {product.productionDays} {product.productionDays===1?'dia':'dias'}. Primeira data disponível para entrega ou retirada: <strong>{formatDateBR(addDaysLocalISO(product.productionDays))}</strong>.</span></div></div>}
      {variations.length>0&&<div className="option-group"><h3>Escolha uma opção</h3><div className="variation-list">{variations.map((variation:ProductVariation)=><button key={variation.id} className={(selectedVariation?.id===variation.id)?'selected':''} onClick={()=>setVariationId(variation.id)}><span>{variation.name}</span><strong>{variation.priceDelta===0?'Incluso':`${variation.priceDelta>0?'+':''}${currency.format(variation.priceDelta)}`}</strong>{selectedVariation?.id===variation.id&&<Check size={16}/>}</button>)}</div></div>}
      {product.addons.filter(a=>a.active).length>0&&<div className="option-group"><div className="option-group__heading"><div><h3>Quer complementar?</h3><p>Adicione um mimo para deixar o presente ainda mais especial.</p></div></div><div className="addon-list">{product.addons.filter(a=>a.active).map(addon=><label key={addon.id} className={selectedAddonIds.includes(addon.id)?'selected':''}><input type="checkbox" checked={selectedAddonIds.includes(addon.id)} onChange={()=>toggleAddon(addon)}/><ImageWithFallback className="addon-image" src={addon.imageUrl || '/assets/placeholder-flower.svg'} alt={addon.name}/><span><strong>{addon.name}</strong>{addon.description&&<small>{addon.description}</small>}<b>+ {currency.format(addon.price)}</b></span><span className="addon-checkmark">{selectedAddonIds.includes(addon.id)&&<Check size={15}/>}</span></label>)}</div></div>}
      <div className="buy-box"><div className="quantity-control"><button onClick={()=>setQuantity(q=>Math.max(1,q-1))} aria-label="Diminuir quantidade"><Minus size={17}/></button><span>{quantity}</span><button onClick={()=>setQuantity(q=>q+1)} aria-label="Aumentar quantidade"><Plus size={17}/></button></div><div className="buy-total"><small>Total</small><strong>{currency.format(total)}</strong></div><button className="primary-button" disabled={unavailable} onClick={add}><ShoppingBag size={18}/>{unavailable?'Indisponível':'Adicionar ao carrinho'}</button></div>
    </section></div></div>;
}
