import { AlertCircle, ArrowLeft, ArrowRight, Clock3, ShoppingBag, Trash2 } from 'lucide-react';
import { useEffect } from 'react';
import { ImageWithFallback } from '../../components/ui/ImageWithFallback';
import { LoadingState } from '../../components/ui/AsyncState';
import { QuantityControl } from '../../components/QuantityControl';
import { cartItemUnitTotal, useCart } from '../../contexts/CartContext';
import { useStore } from '../../contexts/StoreContext';
import { addDaysLocalISO, currency, formatDateBR } from '../../utils/format';
import { storefrontPath } from '../../utils/storefrontRoute';

export default function Cart() {
  const { items, subtotal, updateQuantity, removeItem, validateAgainstProducts } = useCart();
  const { products, settings, loading, storeBasePath } = useStore();

  useEffect(() => {
    if (!loading) validateAgainstProducts(products);
  }, [products, loading, validateAgainstProducts]);

  if (loading) return <div className="page-center"><LoadingState label="Carregando carrinho..." /></div>;

  if (!items.length) {
    return <div className="simple-page">
      <header className="simple-topbar container cart-navigation-layer"><a className="cart-nav-button" href={storefrontPath(storeBasePath)}><ArrowLeft size={19} />Voltar ao catálogo</a></header>
      <div className="cart-empty"><ShoppingBag size={48} /><h1>Seu carrinho está vazio</h1><p>Escolha flores ou presentes e volte aqui para finalizar.</p><a className="primary-button" href={storefrontPath(storeBasePath)}>Ver produtos</a></div>
    </div>;
  }

  const minimumMissing = Math.max(0, settings.minimumOrder - subtotal);
  const madeToOrderProducts = items
    .map((item) => products.find((product) => product.id === item.productId))
    .filter((product): product is NonNullable<typeof product> => Boolean(product?.madeToOrder && product.productionDays > 0));
  const maxProductionDays = madeToOrderProducts.reduce((max, product) => Math.max(max, product.productionDays), 0);
  const minimumMadeToOrderDate = maxProductionDays > 0 ? addDaysLocalISO(maxProductionDays) : '';
  const limitingProducts = madeToOrderProducts.filter((product) => product.productionDays === maxProductionDays);
  return <div className="simple-page">
    <header className="simple-topbar container cart-navigation-layer"><a className="cart-nav-button" href={storefrontPath(storeBasePath)}><ArrowLeft size={19} />Continuar comprando</a><span>Seu carrinho</span></header>
    <div className="container cart-layout">
      <section>
        <div className="page-title"><span className="eyebrow">SEU PEDIDO</span><h1>Revise os itens</h1><p>Confira produtos, variações e complementos antes de avançar.</p></div>
        {minimumMadeToOrderDate && <div className="made-to-order-cart-warning"><Clock3 size={19}/><div><strong>Seu carrinho tem produto sob encomenda</strong><span>A primeira data disponível para entrega ou retirada é <b>{formatDateBR(minimumMadeToOrderDate)}</b>, considerando o maior prazo de produção ({maxProductionDays} {maxProductionDays===1?'dia':'dias'}){limitingProducts.length ? ` de ${limitingProducts.map((product) => product.name).join(', ')}` : ''}.</span></div></div>}
        <div className="cart-list">{items.map((item) => <article key={item.id} className="cart-item">
          <ImageWithFallback src={item.imageUrl} alt={item.productName} />
          <div className="cart-item__main"><strong>{item.productName}</strong>{item.variation && <span>Variação: {item.variation.name}</span>}{item.addons.length > 0 && <span>{item.addons.map((a) => a.name).join(' · ')}</span>}<b>{currency.format(cartItemUnitTotal(item))} / un.</b></div>
          <QuantityControl value={item.quantity} onChange={(q) => updateQuantity(item.id, q)} />
          <strong className="cart-item__total">{currency.format(cartItemUnitTotal(item) * item.quantity)}</strong>
          <button type="button" className="row-delete" onClick={() => removeItem(item.id)} aria-label={`Remover ${item.productName}`}><Trash2 size={18} /></button>
        </article>)}</div>
      </section>
      <aside className="order-summary cart-navigation-layer">
        <span className="eyebrow">RESUMO</span>
        <div className="summary-total"><span>Subtotal</span><strong>{currency.format(subtotal)}</strong></div>
        {settings.minimumOrder > 0 && <div className={`minimum-order ${minimumMissing > 0 ? 'warning' : ''}`}><span>Pedido mínimo: {currency.format(settings.minimumOrder)}</span>{minimumMissing > 0 && <strong>Faltam {currency.format(minimumMissing)}</strong>}</div>}
        <p>Taxa de entrega e disponibilidade serão confirmadas pela loja.</p>
        {minimumMissing > 0 ? <button type="button" className="primary-button cart-continue-button" disabled>Continuar <ArrowRight size={18} /></button> : <a className="primary-button cart-continue-button" href={storefrontPath(storeBasePath,"/finalizar")}>Continuar <ArrowRight size={18} /></a>}
      </aside>
    </div>
  </div>;
}
