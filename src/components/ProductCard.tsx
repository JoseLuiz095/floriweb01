import { ArrowUpRight, Clock3 } from 'lucide-react';
import type { Category, Product } from '../types';
import { currency } from '../utils/format';
import { Badge } from './Badge';
import { ImageWithFallback } from './ui/ImageWithFallback';
import { useStore } from '../contexts/StoreContext';
import { storefrontPath } from '../utils/storefrontRoute';

export function ProductCard({product,category}:{product:Product;category?:Category}){
  const {storeBasePath}=useStore();
  const unavailable=product.stockStatus==='unavailable';
  return <a href={storefrontPath(storeBasePath,`/produto/${product.slug}`)} className={`product-card ${unavailable?'is-unavailable':''}`}>
    <div className="product-card__image-wrap"><ImageWithFallback src={product.imageUrl} alt={product.name} className="product-card__image"/><div className="product-card__badges">{product.promotionalPrice!=null&&<Badge tone="rose">Oferta</Badge>}{product.madeToOrder&&<Badge tone="amber"><Clock3 size={12}/>Sob encomenda · {product.productionDays} {product.productionDays===1?'dia':'dias'}</Badge>}{unavailable&&<Badge tone="amber">Indisponível</Badge>}</div><span className="product-card__open"><ArrowUpRight size={18}/></span></div>
    <div className="product-card__content"><span className="product-card__category">{category?.name??'Flores'}</span><h3>{product.name}</h3><p>{product.description}</p><div className="product-card__price">{product.promotionalPrice!=null?<><strong>{currency.format(product.promotionalPrice)}</strong><del>{currency.format(product.price)}</del></>:<strong>{currency.format(product.price)}</strong>}</div></div>
  </a>;
}
