import { CreditCard, MessageCircle, Search, Sparkles, Truck } from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';
import { ProductCard } from '../../components/ProductCard';
import { StoreHeader } from '../../components/StoreHeader';
import { ErrorState, LoadingState } from '../../components/ui/AsyncState';
import { useStore } from '../../contexts/StoreContext';
import { trackPublicEvent } from '../../services/analyticsApi';

export default function Home(){
  const {products,categories,settings,loading,error,reloadPublic}=useStore();const[selectedCategory,setSelectedCategory]=useState('all');const[query,setQuery]=useState('');const[searchOpen,setSearchOpen]=useState(false);
  useEffect(()=>{if(!loading&&!error&&settings.id)void trackPublicEvent(settings.id,'storefront_view')},[loading,error,settings.id]);
  const visible=useMemo(()=>products.filter((product)=>{if(!product.active)return false;const categoryMatch=selectedCategory==='all'||product.categoryId===selectedCategory;const q=query.trim().toLowerCase();const textMatch=!q||`${product.name} ${product.description}`.toLowerCase().includes(q);return categoryMatch&&textMatch}),[products,selectedCategory,query]);
  const fulfillmentLabel=settings.deliveryEnabled&&settings.pickupEnabled?'Entrega ou retirada':settings.deliveryEnabled?'Entrega disponível':'Retirada na loja';
  const paymentLabels=[settings.pixEnabled&&settings.showPixBeforeConfirmation?'PIX':'',settings.cardPaymentEnabled?'Cartão':'',settings.cashPaymentEnabled?'Dinheiro':'',settings.confirmationPaymentEnabled?'A combinar':''].filter(Boolean);
  const paymentLabel=paymentLabels.length?paymentLabels.join(' · '):'Consulte a loja';
  if(loading)return <div className="page-center"><LoadingState label="Carregando floricultura..."/></div>;
  if(error)return <div className="container page-center"><ErrorState message={error} onRetry={()=>void reloadPublic()}/></div>;
  return <><StoreHeader searchOpen={searchOpen} onSearchClick={()=>setSearchOpen(v=>!v)}/><div className="container storefront-body"><div className="storefront-filter-stack">{searchOpen&&<div className="store-search"><Search size={19}/><input autoFocus value={query} onChange={e=>setQuery(e.target.value)} placeholder="Pesquisar por buquê, rosas, presente..."/></div>}
    <div className="category-strip"><button className={selectedCategory==='all'?'active':''} onClick={()=>setSelectedCategory('all')}>Todos</button>{categories.filter(c=>c.active).map(category=><button key={category.id} className={selectedCategory===category.id?'active':''} onClick={()=>setSelectedCategory(category.id)}>{category.name}</button>)}</div></div>
    <section className="storefront-commerce-strip" aria-label="Como funciona o pedido"><div><MessageCircle size={19}/><span><strong>Pedido direto</strong><small>Finalize e confirme no WhatsApp</small></span></div><div><Truck size={19}/><span><strong>{fulfillmentLabel}</strong><small>{settings.minimumOrder>0?`Pedido mínimo de R$ ${settings.minimumOrder.toFixed(2).replace('.',',')}`:'Sem pedido mínimo'}</small></span></div><div><CreditCard size={19}/><span><strong>Pagamento</strong><small>{paymentLabel}</small></span></div></section>
    <div className="section-heading"><div><span className="eyebrow"><Sparkles size={14}/>SELEÇÃO DA LOJA</span><h2>Escolha algo especial</h2><p>Flores e presentes preparados para transformar o seu momento.</p></div><span>{visible.length} {visible.length===1?'produto':'produtos'}</span></div>
    {visible.length?<div className="product-grid">{visible.map(product=><ProductCard key={product.id} product={product} category={categories.find(category=>category.id===product.categoryId)}/>)}</div>:<div className="empty-state"><Search size={28}/><h3>Nenhum produto encontrado</h3><p>Tente outra categoria ou termo de pesquisa.</p></div>}
  </div><footer className="store-footer"><div className="container"><strong>FloriWeb</strong><span>Catálogo digital para floriculturas.</span><a href="/admin/login">Acesso administrativo</a></div></footer></>;
}
