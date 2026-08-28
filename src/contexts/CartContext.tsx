import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import type { Addon, CartItem, Product, ProductVariation } from '../types';
import { roundMoney } from '../utils/format';
import { useStore } from './StoreContext';

const cartKeyFor = (storeId: string) => `floriweb_cart_v2:${storeId}`;
const readCart = (key: string): CartItem[] => {
  try { const raw=localStorage.getItem(key); return raw ? JSON.parse(raw) as CartItem[] : []; } catch { return []; }
};

type CartContextValue = {
  items: CartItem[];
  totalItems: number;
  subtotal: number;
  addItem: (product: Product, quantity: number, variation?: ProductVariation, addons?: Addon[]) => void;
  updateQuantity: (id: string, quantity: number) => void;
  removeItem: (id: string) => void;
  clear: () => void;
  validateAgainstProducts: (products: Product[]) => void;
};

const CartContext = createContext<CartContextValue | null>(null);
export const cartItemUnitTotal = (item: CartItem) => roundMoney(item.unitPrice + item.addons.reduce((sum, addon) => sum + addon.price, 0));
export const calculateCartSubtotal = (items: CartItem[]) => roundMoney(items.reduce((sum,item)=>sum+cartItemUnitTotal(item)*item.quantity,0));

export function CartProvider({ children }: { children: ReactNode }) {
  const { settings } = useStore();
  const cartKey = cartKeyFor(settings.id || settings.slug || 'default');
  const [state, setState] = useState<{key:string;items:CartItem[]}>(()=>({key:cartKey,items:readCart(cartKey)}));
  const items = state.key === cartKey ? state.items : readCart(cartKey);

  useEffect(()=>{
    if(state.key!==cartKey)setState({key:cartKey,items:readCart(cartKey)});
  },[cartKey,state.key]);
  useEffect(()=>{
    if(state.key!==cartKey)return;
    try{localStorage.setItem(cartKey,JSON.stringify(state.items));}catch{/* armazenamento indisponível */}
  },[state,cartKey]);

  const setItems = (updater: (current: CartItem[]) => CartItem[]) => setState((current)=>{
    const base=current.key===cartKey?current.items:readCart(cartKey);
    return{key:cartKey,items:updater(base)};
  });

  const value = useMemo<CartContextValue>(() => ({
    items,
    totalItems: items.reduce((sum,item)=>sum+item.quantity,0),
    subtotal: calculateCartSubtotal(items),
    addItem: (product, quantity, variation, addons=[]) => {
      const base=product.promotionalPrice??product.price; const unitPrice=roundMoney(base+(variation?.priceDelta??0));
      const id=[product.id,variation?.id??'base',...addons.map(a=>a.id).sort()].join('|');
      setItems((current)=>{const existing=current.find((item)=>item.id===id);if(existing)return current.map((item)=>item.id===id?{...item,quantity:item.quantity+quantity}:item);return[...current,{id,productId:product.id,productName:product.name,imageUrl:product.imageUrl,unitPrice,quantity,variation,addons}]});
    },
    updateQuantity:(id,quantity)=>setItems((current)=>current.map((item)=>item.id===id?{...item,quantity:Math.max(1,quantity)}:item)),
    removeItem:(id)=>setItems((current)=>current.filter((item)=>item.id!==id)),
    clear:()=>setItems(()=>[]),
    validateAgainstProducts:(products)=>setItems((current)=>current.flatMap((item)=>{
      const product=products.find((p)=>p.id===item.productId&&p.active&&p.stockStatus!=='unavailable');
      if(!product)return[];
      const variation=item.variation?product.variations.find((v)=>v.id===item.variation?.id&&v.active):undefined;
      if(item.variation&&!variation)return[];
      const addons=item.addons.map((selected)=>product.addons.find((addon)=>addon.id===selected.id&&addon.active)).filter((addon):addon is Addon=>Boolean(addon));
      const unitPrice=roundMoney((product.promotionalPrice??product.price)+(variation?.priceDelta??0));
      return[{...item,productName:product.name,imageUrl:product.imageUrl,unitPrice,variation,addons}];
    })),
  }),[items,cartKey]);

  return <CartContext.Provider value={value}>{children}</CartContext.Provider>;
}

export const useCart=()=>{const value=useContext(CartContext);if(!value)throw new Error('useCart deve ser usado dentro de CartProvider');return value;};
