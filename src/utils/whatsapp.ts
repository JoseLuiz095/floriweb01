import type { CartItem, CheckoutData, OrderConfirmation, StoreSettings } from '../types';
import { currency, formatDateBR, sanitizeWhatsAppNumber } from './format';
import { cartItemUnitTotal } from '../contexts/CartContext';
import { formatOrderNumber } from './orderConfirmation';

export const buildWhatsAppMessage = (
  items: CartItem[],
  checkout: CheckoutData,
  store: StoreSettings,
  orderNumber?: number,
) => {
  const lines: string[] = [
    `Olá, ${store.name}! Gostaria de confirmar este pedido realizado pelo site:`,
    '',
    orderNumber ? `*PEDIDO #${formatOrderNumber(orderNumber)}*` : '*PEDIDO*',
  ];

  items.forEach((item, index) => {
    lines.push('', `${index + 1}. *${item.quantity}x ${item.productName}*`);
    if (item.variation) {
      lines.push(`   Variação: ${item.variation.name}${item.variation.priceDelta ? ` (${item.variation.priceDelta > 0 ? '+' : ''}${currency.format(item.variation.priceDelta)})` : ''}`);
    }
    if (item.addons.length) {
      lines.push('   Adicionais:');
      item.addons.forEach((addon) => lines.push(`   • ${addon.name} (${currency.format(addon.price)})`));
    }
    lines.push(`   ${currency.format(cartItemUnitTotal(item) * item.quantity)}`);
  });

  const productsTotal = items.reduce((sum, item) => sum + cartItemUnitTotal(item) * item.quantity, 0);
  const deliveryFee = checkout.fulfillment === 'delivery' ? checkout.deliveryFee : 0;
  const total = productsTotal + deliveryFee;
  lines.push('', `*TOTAL DOS PRODUTOS: ${currency.format(productsTotal)}*`);
  if (checkout.fulfillment === 'delivery') lines.push(`Taxa de entrega (${checkout.neighborhood}): ${deliveryFee === 0 ? 'Grátis' : currency.format(deliveryFee)}`);
  lines.push(`*TOTAL DO PEDIDO: ${currency.format(total)}*`, '', '*DADOS DO PEDIDO*', `Cliente: ${checkout.customerName}`);
  if (checkout.customerPhone) lines.push(`Telefone: ${checkout.customerPhone}`);
  if (checkout.customerEmail) lines.push(`E-mail: ${checkout.customerEmail}`);
  lines.push(`Forma: ${checkout.fulfillment === 'delivery' ? 'Entrega' : 'Retirada'}`, `Data desejada: ${formatDateBR(checkout.desiredDate)}`);
  if (checkout.timeWindow) lines.push(`Período: ${checkout.timeWindow}`);
  if (checkout.recipientName) lines.push(`Destinatário: ${checkout.recipientName}`);
  if (checkout.recipientPhone) lines.push(`Telefone do destinatário: ${checkout.recipientPhone}`);
  if (checkout.fulfillment === 'delivery') {
    const address = [
      [checkout.street, checkout.addressNumber].filter(Boolean).join(', '),
      checkout.complement,
      [checkout.neighborhood, checkout.deliveryCity, checkout.deliveryState].filter(Boolean).join(' - '),
      checkout.zipCode ? `CEP ${checkout.zipCode}` : '',
    ].filter(Boolean).join(' | ');
    if (address) lines.push(`Endereço: ${address}`);
    if (checkout.referencePoint) lines.push(`Referência: ${checkout.referencePoint}`);
  }
  if (checkout.cardMessage) {
    lines.push('', '*MENSAGEM DO CARTÃO*', checkout.cardMessage);
    if (checkout.anonymousSender) lines.push('Assinatura: Anônimo');
    else if (checkout.cardSignature) lines.push(`Assinatura: ${checkout.cardSignature}`);
  }
  if (checkout.notes) lines.push('', '*OBSERVAÇÕES*', checkout.notes);

  lines.push('', '*PAGAMENTO*');
  if (checkout.paymentMethod === 'pix') {
    lines.push(store.pixReceiptMode === 'copy_paste' ? 'PIX Copia e Cola — código com o valor do pedido disponível na tela de confirmação.' : `PIX — ${store.pixKeyType}: ${store.pixKey}`);
    lines.push('', 'Pedido registrado pelo site.');
  } else if (checkout.paymentMethod === 'card') {
    lines.push('Cartão — aguardo o link de pagamento da floricultura.');
    lines.push('', 'Por favor, envie o link de pagamento por cartão nesta conversa.');
  } else if (checkout.paymentMethod === 'cash') {
    lines.push('Dinheiro — pagamento na entrega ou retirada.');
    lines.push('', 'Se necessário, combinarei o troco com a floricultura por esta conversa.');
  } else {
    lines.push('Após confirmação da floricultura');
    lines.push('', 'Aguardo a confirmação de disponibilidade, entrega e forma de pagamento.');
  }

  return lines.join('\n');
};

export const buildPostOrderWhatsAppMessage = (confirmation: OrderConfirmation) => {
  if (confirmation.paymentMethod === 'pix') {
    return [
      confirmation.orderMessage,
      '',
      '*COMPROVANTE PIX*',
      `Pedido #${formatOrderNumber(confirmation.orderNumber)} · ${currency.format(confirmation.total)}`,
      'Efetuei o pagamento via PIX e vou anexar o comprovante nesta conversa.',
    ].join('\n');
  }

  if (confirmation.paymentMethod === 'card') {
    return [
      confirmation.orderMessage,
      '',
      '*LINK DE PAGAMENTO POR CARTÃO*',
      `Pedido #${formatOrderNumber(confirmation.orderNumber)} · ${currency.format(confirmation.total)}`,
      'Escolhi pagar por cartão. Pode me enviar o link de pagamento por aqui?',
    ].join('\n');
  }

  if (confirmation.paymentMethod === 'cash') {
    return [
      confirmation.orderMessage,
      '',
      '*PAGAMENTO EM DINHEIRO*',
      `Pedido #${formatOrderNumber(confirmation.orderNumber)} · ${currency.format(confirmation.total)}`,
      'O pagamento será feito em dinheiro. Se precisar de troco, combinarei por esta conversa.',
    ].join('\n');
  }

  return confirmation.orderMessage;
};

export const getWhatsAppUrl = (number: string, message: string) =>
  `https://wa.me/${sanitizeWhatsAppNumber(number)}?text=${encodeURIComponent(message)}`;

export const openWhatsApp = (number: string, message: string) =>
  window.open(getWhatsAppUrl(number, message), '_blank', 'noopener,noreferrer');
