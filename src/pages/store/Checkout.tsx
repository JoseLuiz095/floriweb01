import {
  AlertCircle,
  ArrowLeft,
  Banknote,
  CalendarDays,
  CheckCircle2,
  Clock3,
  CreditCard,
  Gift,
  LoaderCircle,
  Mail,
  MapPin,
  PackageCheck,
  Phone,
  QrCode,
  ShoppingBag,
  Truck,
  UserRound,
} from 'lucide-react';
import { useCallback, useEffect, useMemo, useRef, useState, type FormEvent } from 'react';
import { ErrorState, LoadingState } from '../../components/ui/AsyncState';
import { ImageWithFallback } from '../../components/ui/ImageWithFallback';
import { TurnstileWidget } from '../../components/ui/TurnstileWidget';
import { cartItemUnitTotal, useCart } from '../../contexts/CartContext';
import { useStore } from '../../contexts/StoreContext';
import { useToast } from '../../contexts/ToastContext';
import { appConfig } from '../../lib/config';
import { SupabaseHttpError } from '../../lib/supabaseRest';
import { getAnalyticsSessionId, trackPublicEvent } from '../../services/analyticsApi';
import { lookupCep } from '../../services/cepApi';
import type { CheckoutData, DeliveryZone, OrderConfirmation, PaymentMethod } from '../../types';
import { currency, sanitizeWhatsAppNumber, todayLocalISO } from '../../utils/format';
import { saveOrderConfirmation } from '../../utils/orderConfirmation';
import { buildPixCopyPasteWithAmount } from '../../utils/pix';
import { normalizeText } from '../../utils/text';
import { buildWhatsAppMessage } from '../../utils/whatsapp';
import { storefrontPath } from '../../utils/storefrontRoute';

const initial: CheckoutData = {
  customerName: '',
  customerPhone: '',
  customerEmail: '',
  fulfillment: 'delivery',
  desiredDate: '',
  timeWindow: '',
  recipientName: '',
  recipientPhone: '',
  zipCode: '',
  street: '',
  addressNumber: '',
  complement: '',
  neighborhood: '',
  deliveryZoneId: '',
  deliveryFee: 0,
  deliveryCity: '',
  deliveryState: '',
  referencePoint: '',
  cardMessage: '',
  cardSignature: '',
  anonymousSender: false,
  notes: '',
  paymentMethod: 'confirm',
  reviewConfirmed: false,
};


const CHECKOUT_DRAFT_PREFIX = 'floriweb_checkout_draft_v1';
const checkoutDraftKey = (storeId: string) => `${CHECKOUT_DRAFT_PREFIX}:${storeId}`;

const readCheckoutDraft = (storeId: string): Partial<CheckoutData> | null => {
  try {
    const raw = sessionStorage.getItem(checkoutDraftKey(storeId));
    if (!raw) return null;
    const parsed = JSON.parse(raw) as Partial<CheckoutData>;
    return parsed && typeof parsed === 'object' ? parsed : null;
  } catch {
    return null;
  }
};

const saveCheckoutDraft = (storeId: string, form: CheckoutData) => {
  try {
    // Mantem apenas dados operacionais nesta sessao. Conteudo pessoal de cartao/mensagem/notas nao e persistido.
    const draft: Partial<CheckoutData> = {
      customerName: form.customerName,
      customerPhone: form.customerPhone,
      customerEmail: form.customerEmail,
      fulfillment: form.fulfillment,
      desiredDate: form.desiredDate,
      timeWindow: form.timeWindow,
      recipientName: form.recipientName,
      recipientPhone: form.recipientPhone,
      zipCode: form.zipCode,
      street: form.street,
      addressNumber: form.addressNumber,
      complement: form.complement,
      neighborhood: form.neighborhood,
      deliveryZoneId: form.deliveryZoneId,
      deliveryFee: form.deliveryFee,
      deliveryCity: form.deliveryCity,
      deliveryState: form.deliveryState,
      referencePoint: form.referencePoint,
      anonymousSender: form.anonymousSender,
      paymentMethod: form.paymentMethod,
      reviewConfirmed: false,
    };
    sessionStorage.setItem(checkoutDraftKey(storeId), JSON.stringify(draft));
  } catch {
    // Checkout continua funcionando mesmo se o navegador bloquear sessionStorage.
  }
};

const clearCheckoutDraft = (storeId: string) => {
  try { sessionStorage.removeItem(checkoutDraftKey(storeId)); } catch { /* sem storage */ }
};

const onlyDigits = (value: string) => value.replace(/\D/g, '');

function formatPhone(value: string) {
  const digits = onlyDigits(value).slice(0, 11);
  if (digits.length <= 2) return digits;
  if (digits.length <= 7) return `(${digits.slice(0, 2)}) ${digits.slice(2)}`;
  if (digits.length <= 10) return `(${digits.slice(0, 2)}) ${digits.slice(2, 6)}-${digits.slice(6)}`;
  return `(${digits.slice(0, 2)}) ${digits.slice(2, 7)}-${digits.slice(7)}`;
}

function formatCep(value: string) {
  const digits = onlyDigits(value).slice(0, 8);
  return digits.length > 5 ? `${digits.slice(0, 5)}-${digits.slice(5)}` : digits;
}

function findMatchingZone(zones: DeliveryZone[], neighborhood: string, city: string, state: string) {
  const target = normalizeText(neighborhood);
  if (!target) return undefined;
  const cityNorm = normalizeText(city);
  const stateNorm = state.trim().toUpperCase();
  const candidates = zones.filter((zone) => {
    const sameState = !stateNorm || zone.state.toUpperCase() === stateNorm;
    const sameCity = !cityNorm || normalizeText(zone.city) === cityNorm;
    return sameState && sameCity;
  });

  const exact = candidates.find((zone) => {
    const names = [zone.name, ...zone.aliases].map(normalizeText);
    return names.includes(target);
  });
  if (exact) return exact;

  return candidates.find((zone) => {
    const names = [zone.name, ...zone.aliases].map(normalizeText);
    return names.some((name) => name.includes(target) || target.includes(name));
  });
}

const createCheckoutRequestId = () => {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') return crypto.randomUUID();
  const template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx';
  return template.replace(/[xy]/g, (char) => {
    const random = Math.floor(Math.random() * 16);
    const value = char === 'x' ? random : (random & 0x3) | 0x8;
    return value.toString(16);
  });
};

const paymentLabels: Record<PaymentMethod, { title: string; description: string }> = {
  confirm: {
    title: 'Confirmar com a floricultura',
    description: 'A loja confirma disponibilidade e os dados finais antes do pagamento.',
  },
  pix: {
    title: 'PIX',
    description: 'Finalize e receba as instruções PIX na próxima tela.',
  },
  card: {
    title: 'Cartão',
    description: 'A floricultura enviará manualmente o link de pagamento pelo WhatsApp.',
  },
  cash: {
    title: 'Dinheiro',
    description: 'Pagamento em dinheiro na entrega ou retirada. Combine eventual troco pelo WhatsApp.',
  },
};

export default function Checkout() {
  const { items, subtotal, clear } = useCart();
  const { settings, deliveryZones, registerOrder, loading, error, reloadPublic, storeBasePath } = useStore();
  const { showToast } = useToast();
  const [sending, setSending] = useState(false);
  const [cepLoading, setCepLoading] = useState(false);
  const [cepError, setCepError] = useState('');
  const [cepNeighborhood, setCepNeighborhood] = useState('');
  const [turnstileToken, setTurnstileToken] = useState('');
  const [turnstileResetSignal, setTurnstileResetSignal] = useState(0);
  const [checkoutRequestId] = useState(createCheckoutRequestId);
  const loadedDraftStore = useRef('');
  const checkoutCompleted = useRef(false);
  const handleTurnstileToken = useCallback((token: string) => setTurnstileToken(token), []);
  const [form, setForm] = useState<CheckoutData>(() => ({
    ...initial,
    fulfillment: settings.deliveryEnabled ? 'delivery' : 'pickup',
    deliveryCity: settings.city,
    deliveryState: settings.state,
  }));

  useEffect(() => {
    if (loading || !settings.id || loadedDraftStore.current === settings.id) return;
    loadedDraftStore.current = settings.id;
    const draft = readCheckoutDraft(settings.id);
    if (!draft) return;
    setForm((current) => ({
      ...current,
      ...draft,
      cardMessage: '',
      cardSignature: '',
      notes: '',
      reviewConfirmed: false,
    }));
  }, [loading, settings.id]);

  useEffect(() => {
    if (!settings.id || loadedDraftStore.current !== settings.id || sending || checkoutCompleted.current) return;
    const timer = window.setTimeout(() => saveCheckoutDraft(settings.id, form), 250);
    return () => window.clearTimeout(timer);
  }, [form, sending, settings.id]);

  useEffect(() => {
    if (!loading && items.length > 0 && settings.id) void trackPublicEvent(settings.id, 'checkout_started');
  }, [loading, items.length, settings.id]);

  const pixAvailable = settings.pixEnabled
    && settings.showPixBeforeConfirmation
    && (settings.pixReceiptMode === 'copy_paste' ? Boolean(settings.pixCopyPaste.trim()) : Boolean(settings.pixKey.trim()));

  const activeDeliveryZones = useMemo(
    () => deliveryZones.filter((zone) => zone.active).sort((a, b) => a.sortOrder - b.sortOrder || a.name.localeCompare(b.name)),
    [deliveryZones],
  );

  const availablePaymentMethods = useMemo(() => {
    const order = settings.paymentMethodOrder?.length ? settings.paymentMethodOrder : ['confirm', 'pix', 'card', 'cash'] as PaymentMethod[];
    return order.filter((method) => {
      if (method === 'confirm') return settings.confirmationPaymentEnabled;
      if (method === 'pix') return pixAvailable;
      if (method === 'card') return settings.cardPaymentEnabled;
      if (method === 'cash') return settings.cashPaymentEnabled;
      return false;
    });
  }, [pixAvailable, settings.confirmationPaymentEnabled, settings.cardPaymentEnabled, settings.cashPaymentEnabled, settings.paymentMethodOrder]);

  const visibleDeliveryZones = useMemo(() => {
    const city = normalizeText(form.deliveryCity);
    const state = form.deliveryState.trim().toUpperCase();
    if (!city && !state) return activeDeliveryZones;
    return activeDeliveryZones.filter((zone) => {
      const sameCity = !city || normalizeText(zone.city) === city;
      const sameState = !state || zone.state.toUpperCase() === state;
      return sameCity && sameState;
    });
  }, [activeDeliveryZones, form.deliveryCity, form.deliveryState]);

  const selectedZone = useMemo(
    () => activeDeliveryZones.find((zone) => zone.id === form.deliveryZoneId),
    [activeDeliveryZones, form.deliveryZoneId],
  );
  const deliveryFee = form.fulfillment === 'delivery' ? selectedZone?.fee ?? 0 : 0;
  const orderTotal = subtotal + deliveryFee;

  useEffect(() => {
    setForm((current) => {
      const next = { ...current };
      if ((!settings.deliveryEnabled || activeDeliveryZones.length === 0) && settings.pickupEnabled) next.fulfillment = 'pickup';
      if (!settings.pickupEnabled && settings.deliveryEnabled && activeDeliveryZones.length > 0) next.fulfillment = 'delivery';
      if (!next.deliveryCity) next.deliveryCity = settings.city;
      if (!next.deliveryState) next.deliveryState = settings.state;
      if (!availablePaymentMethods.includes(next.paymentMethod)) next.paymentMethod = availablePaymentMethods[0] ?? 'confirm';
      if (next.fulfillment === 'pickup') {
        next.deliveryZoneId = '';
        next.deliveryFee = 0;
      }
      return next;
    });
  }, [settings.deliveryEnabled, settings.pickupEnabled, settings.city, settings.state, availablePaymentMethods, activeDeliveryZones.length]);

  useEffect(() => {
    if (form.fulfillment !== 'delivery') return;
    const digits = onlyDigits(form.zipCode);
    if (digits.length !== 8) {
      setCepError('');
      setCepNeighborhood('');
      return;
    }

    const controller = new AbortController();
    const timer = window.setTimeout(() => {
      setCepLoading(true);
      setCepError('');
      void lookupCep(digits, controller.signal)
        .then((address) => {
          const zone = findMatchingZone(activeDeliveryZones, address.neighborhood, address.city, address.state);
          setCepNeighborhood(address.neighborhood);
          setForm((current) => ({
            ...current,
            zipCode: formatCep(address.cep),
            street: address.street || current.street,
            complement: current.complement || address.complement,
            deliveryCity: address.city || current.deliveryCity,
            deliveryState: address.state || current.deliveryState,
            deliveryZoneId: zone?.id || '',
            neighborhood: zone?.name || '',
            deliveryFee: zone?.fee ?? 0,
          }));
          if (!zone) {
            setCepError(address.neighborhood
              ? `O bairro “${address.neighborhood}” foi localizado, mas ainda não está disponível nas áreas ativas da loja.`
              : 'O CEP foi localizado, mas o bairro não veio informado. Selecione uma área de entrega manualmente.');
          }
        })
        .catch((lookupError: unknown) => {
          if (controller.signal.aborted) return;
          setCepError(lookupError instanceof Error ? lookupError.message : 'Não foi possível consultar o CEP.');
        })
        .finally(() => {
          if (!controller.signal.aborted) setCepLoading(false);
        });
    }, 450);

    return () => {
      controller.abort();
      window.clearTimeout(timer);
    };
  }, [form.zipCode, form.fulfillment, activeDeliveryZones]);

  const fullAddress = useMemo(() => {
    if (form.fulfillment !== 'delivery') return '';
    const firstLine = [form.street.trim(), form.addressNumber.trim()].filter(Boolean).join(', ');
    const secondLine = [form.neighborhood.trim(), form.deliveryCity.trim(), form.deliveryState.trim()].filter(Boolean).join(' - ');
    return [firstLine, form.complement.trim(), secondLine, form.zipCode.trim() ? `CEP ${form.zipCode.trim()}` : '', form.referencePoint.trim() ? `Referência: ${form.referencePoint.trim()}` : '']
      .filter(Boolean)
      .join(' | ');
  }, [form]);

  if (loading) return <div className="page-center"><LoadingState label="Carregando finalização..." /></div>;
  if (error) return <div className="container page-center"><ErrorState message={error} onRetry={() => void reloadPublic()} /></div>;
  if (!items.length) return <div className="not-found"><h2>Não há itens para finalizar</h2><a href={storefrontPath(storeBasePath)}>Voltar ao catálogo</a></div>;

  const update = <K extends keyof CheckoutData>(key: K, value: CheckoutData[K]) =>
    setForm((current) => ({ ...current, [key]: value }));

  const selectZone = (zoneId: string) => {
    const zone = activeDeliveryZones.find((item) => item.id === zoneId);
    setForm((current) => ({
      ...current,
      deliveryZoneId: zone?.id || '',
      neighborhood: zone?.name || '',
      deliveryCity: zone?.city || current.deliveryCity,
      deliveryState: zone?.state || current.deliveryState,
      deliveryFee: zone?.fee ?? 0,
    }));
    if (zone) setCepError('');
  };

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    if (sending) return;

    if (subtotal < settings.minimumOrder) {
      showToast(`O pedido mínimo é ${currency.format(settings.minimumOrder)}.`, 'error');
      window.location.assign(storefrontPath(storeBasePath,'/carrinho'));
      return;
    }

    if (sanitizeWhatsAppNumber(settings.whatsapp).length < 10) {
      showToast('O WhatsApp da floricultura ainda não foi configurado corretamente.', 'error');
      return;
    }

    if (form.fulfillment === 'delivery') {
      if (!form.recipientName.trim() || !form.recipientPhone.trim()) {
        showToast('Informe o nome e o telefone de quem receberá o pedido.', 'error');
        return;
      }
      if (!form.street.trim() || !form.addressNumber.trim() || !form.deliveryCity.trim() || !form.deliveryState.trim()) {
        showToast('Preencha o endereço de entrega completo.', 'error');
        return;
      }
      if (!selectedZone) {
        showToast('Selecione um bairro/área de entrega disponível.', 'error');
        return;
      }
    }

    if (!form.reviewConfirmed) {
      showToast('Confirme que revisou os dados do pedido antes de finalizar.', 'error');
      return;
    }

    if (appConfig.turnstileSiteKey && !turnstileToken) {
      showToast('Conclua a verificação anti-spam antes de finalizar.', 'error');
      return;
    }

    if (form.paymentMethod === 'pix' && settings.pixReceiptMode === 'copy_paste') {
      try {
        buildPixCopyPasteWithAmount(settings.pixCopyPaste, orderTotal);
      } catch (pixError) {
        showToast(pixError instanceof Error ? pixError.message : 'O PIX Copia e Cola da loja está inválido.', 'error');
        return;
      }
    }
    if (form.paymentMethod === 'card' && !settings.cardPaymentEnabled) {
      showToast('Pagamento por cartão não está disponível nesta loja.', 'error');
      return;
    }
    if (form.paymentMethod === 'cash' && !settings.cashPaymentEnabled) {
      showToast('Pagamento em dinheiro não está disponível nesta loja.', 'error');
      return;
    }

    const normalizedForm: CheckoutData = {
      ...form,
      customerName: form.customerName.trim(),
      customerPhone: form.customerPhone.trim(),
      customerEmail: form.customerEmail.trim(),
      recipientName: form.recipientName.trim(),
      recipientPhone: form.recipientPhone.trim(),
      neighborhood: selectedZone?.name || form.neighborhood.trim(),
      deliveryZoneId: selectedZone?.id || '',
      deliveryFee,
      deliveryCity: selectedZone?.city || form.deliveryCity.trim(),
      deliveryState: selectedZone?.state || form.deliveryState.trim().toUpperCase(),
      cardSignature: form.anonymousSender ? '' : form.cardSignature.trim(),
    };

    setSending(true);
    try {
      const created = await registerOrder(settings, items, normalizedForm, subtotal, { turnstileToken, analyticsSessionId: getAnalyticsSessionId(settings.id), requestId: checkoutRequestId });
      const orderMessage = buildWhatsAppMessage(items, normalizedForm, settings, created.orderNumber);

      let generatedPixCopyPaste = '';
      if (normalizedForm.paymentMethod === 'pix' && settings.pixReceiptMode === 'copy_paste') {
        generatedPixCopyPaste = buildPixCopyPasteWithAmount(settings.pixCopyPaste, created.total);
      }

      const confirmation: OrderConfirmation = {
        orderId: created.orderId,
        orderNumber: created.orderNumber,
        total: created.total,
        paymentMethod: normalizedForm.paymentMethod,
        customerName: normalizedForm.customerName,
        fulfillment: normalizedForm.fulfillment,
        storeName: settings.name,
        storeWhatsapp: settings.whatsapp,
        pixEnabled: settings.pixEnabled,
        pixReceiptMode: settings.pixReceiptMode,
        pixKeyType: settings.pixKeyType,
        pixKey: settings.pixKey,
        pixCopyPaste: generatedPixCopyPaste,
        pixReceiver: settings.pixReceiver,
        orderMessage,
        createdAt: new Date().toISOString(),
      };

      saveOrderConfirmation(confirmation);
      checkoutCompleted.current = true;
      clearCheckoutDraft(settings.id);
      clear();
      window.location.assign(storefrontPath(storeBasePath,`/pedido/${created.orderId}`));
    } catch (submitError) {
      setTurnstileResetSignal((value) => value + 1);
      console.error('Falha ao finalizar pedido:', submitError);
      if (submitError instanceof SupabaseHttpError) {
        showToast(submitError.message || 'Não foi possível finalizar o pedido.', 'error');
      } else {
        showToast(submitError instanceof Error ? submitError.message : 'Não foi possível finalizar o pedido.', 'error');
      }
    } finally {
      setSending(false);
    }
  };

  const submitDisabled = sending || !form.reviewConfirmed || (appConfig.turnstileSiteKey ? !turnstileToken : false) || (form.fulfillment === 'delivery' && !selectedZone);

  const renderPaymentMethod = (method: PaymentMethod) => {
    const selected = form.paymentMethod === method;
    const info = paymentLabels[method];
    return (
      <label key={method} className={selected ? 'selected' : ''}>
        <input type="radio" name="pay" checked={selected} onChange={() => update('paymentMethod', method)} />
        <span className="payment-radio" />
        <span>
          <strong>
            {info.title}
            {method === 'pix' && settings.pixReceiptMode === 'copy_paste' && <em className="recommended-badge">Recomendado</em>}
          </strong>
          <small>{method === 'pix' && settings.pixReceiptMode === 'copy_paste' ? 'PIX Copia e Cola já com o total completo do pedido, incluindo entrega.' : info.description}</small>
        </span>
        <b>
          {method === 'pix' ? <QrCode size={15} /> : method === 'card' ? <CreditCard size={15} /> : method === 'cash' ? <Banknote size={15} /> : <CheckCircle2 size={15} />}
        </b>
      </label>
    );
  };

  return (
    <div className="checkout-page">
      <header className="checkout-topbar">
        <div className="container checkout-topbar__inner">
          <a href={storefrontPath(storeBasePath,"/carrinho")}><ArrowLeft size={18} />Voltar ao carrinho</a>
          <div className="checkout-steps" aria-label="Etapas da compra">
            <span className="done">1</span><b>Carrinho</b><i />
            <span className="active">2</span><b>Dados</b><i />
            <span>3</span><b>Confirmação</b>
          </div>
          <div className="checkout-security"><CheckCircle2 size={17} />Pedido seguro</div>
        </div>
      </header>

      <form className="container checkout-layout checkout-layout--premium" onSubmit={submit}>
        <main className="checkout-main">
          <div className="page-title checkout-title">
            <span className="eyebrow">FINALIZAR PEDIDO</span>
            <h1>Falta pouco para enviar seu pedido</h1>
            <p>Confira os dados com atenção. O total será atualizado automaticamente quando você selecionar a área de entrega.</p>
            <div className="checkout-draft-note"><CheckCircle2 size={17}/><span><strong>Proteção contra perda de preenchimento</strong><small>Os dados básicos podem ser recuperados nesta aba se a página recarregar. Mensagem do cartão, assinatura e observações não são armazenadas.</small></span></div>
          </div>

          <section className="checkout-card">
            <div className="checkout-card__heading">
              <span><Truck size={20} /></span>
              <div><small>ETAPA 1</small><h2>Como você quer receber?</h2><p>Escolha entre entrega e retirada na floricultura.</p></div>
            </div>
            <div className="fulfillment-grid fulfillment-grid--premium">
              {settings.deliveryEnabled && (
                <button type="button" disabled={!activeDeliveryZones.length} className={form.fulfillment === 'delivery' ? 'selected' : ''} onClick={() => update('fulfillment', 'delivery')}>
                  <span className="fulfillment-icon"><Truck size={22} /></span>
                  <div><strong>Entrega</strong><span>{activeDeliveryZones.length ? 'Receber em uma das áreas atendidas' : 'Aguardando configuração das áreas de entrega'}</span></div>
                  <CheckCircle2 className="selection-check" size={19} />
                </button>
              )}
              {settings.pickupEnabled && (
                <button type="button" className={form.fulfillment === 'pickup' ? 'selected' : ''} onClick={() => update('fulfillment', 'pickup')}>
                  <span className="fulfillment-icon"><PackageCheck size={22} /></span>
                  <div><strong>Retirada</strong><span>Buscar diretamente na floricultura</span></div>
                  <CheckCircle2 className="selection-check" size={19} />
                </button>
              )}
            </div>
            {settings.deliveryEnabled && activeDeliveryZones.length === 0 && (
              <div className="delivery-lookup-message is-warning checkout-delivery-unavailable">
                <AlertCircle size={17} />
                <span><strong>Entrega temporariamente indisponível</strong>A floricultura ainda não ativou bairros/áreas com taxa de entrega. {settings.pickupEnabled ? 'Você pode continuar escolhendo Retirada.' : 'Entre em contato com a loja antes de finalizar.'}</span>
              </div>
            )}
          </section>

          <section className="checkout-card">
            <div className="checkout-card__heading">
              <span><UserRound size={20} /></span>
              <div><small>ETAPA 2</small><h2>Seus dados</h2><p>Usaremos estes dados apenas para identificação e contato sobre o pedido.</p></div>
            </div>
            <div className="checkout-form-grid">
              <label className="field field--full"><span>Seu nome completo *</span><div className="field-control"><UserRound size={17} /><input required value={form.customerName} onChange={(e) => update('customerName', e.target.value)} placeholder="Nome de quem está fazendo o pedido" /></div></label>
              <label className="field"><span>WhatsApp / telefone *</span><div className="field-control"><Phone size={17} /><input required inputMode="tel" value={form.customerPhone} onChange={(e) => update('customerPhone', formatPhone(e.target.value))} placeholder="(27) 99999-9999" /></div></label>
              <label className="field"><span>E-mail</span><div className="field-control"><Mail size={17} /><input type="email" value={form.customerEmail} onChange={(e) => update('customerEmail', e.target.value)} placeholder="voce@email.com" /></div></label>
            </div>
          </section>

          <section className="checkout-card">
            <div className="checkout-card__heading">
              <span><CalendarDays size={20} /></span>
              <div><small>ETAPA 3</small><h2>Data e horário</h2><p>Informe quando você gostaria que o pedido fosse entregue ou retirado.</p></div>
            </div>
            <div className="checkout-form-grid">
              <label className="field"><span>Data desejada *</span><div className="field-control"><CalendarDays size={17} /><input type="date" required min={todayLocalISO()} value={form.desiredDate} onChange={(e) => update('desiredDate', e.target.value)} /></div></label>
              <label className="field"><span>Período</span><div className="field-control"><Clock3 size={17} /><select value={form.timeWindow} onChange={(e) => update('timeWindow', e.target.value)}><option value="">A combinar com a loja</option><option>Manhã</option><option>Tarde</option><option>Noite</option></select></div></label>
            </div>
          </section>

          {form.fulfillment === 'delivery' && (
            <section className="checkout-card">
              <div className="checkout-card__heading">
                <span><MapPin size={20} /></span>
                <div><small>ETAPA 4</small><h2>Dados de quem vai receber</h2><p>Digite o CEP para preencher o endereço e confirmar automaticamente a taxa da região.</p></div>
              </div>
              <div className="checkout-form-grid">
                <label className="field"><span>Nome do destinatário *</span><div className="field-control"><UserRound size={17} /><input required value={form.recipientName} onChange={(e) => update('recipientName', e.target.value)} placeholder="Quem receberá as flores" /></div></label>
                <label className="field"><span>Telefone do destinatário *</span><div className="field-control"><Phone size={17} /><input required inputMode="tel" value={form.recipientPhone} onChange={(e) => update('recipientPhone', formatPhone(e.target.value))} placeholder="(27) 99999-9999" /></div></label>
                <label className="field field--small"><span>CEP *</span><div className="field-control cep-control"><input required inputMode="numeric" value={form.zipCode} onChange={(e) => update('zipCode', formatCep(e.target.value))} placeholder="29900-000" />{cepLoading && <LoaderCircle className="spin" size={16} />}</div></label>
                <label className="field field--grow"><span>Rua / Avenida *</span><input required value={form.street} onChange={(e) => update('street', e.target.value)} placeholder="Nome da rua ou avenida" /></label>
                <label className="field field--small"><span>Número *</span><input required value={form.addressNumber} onChange={(e) => update('addressNumber', e.target.value)} placeholder="123" /></label>
                <label className="field"><span>Complemento</span><input value={form.complement} onChange={(e) => update('complement', e.target.value)} placeholder="Apto, bloco, casa..." /></label>
                <label className="field field--full delivery-zone-select"><span>Bairro / área de entrega *</span><select required value={form.deliveryZoneId} onChange={(e) => selectZone(e.target.value)}><option value="">Selecione o bairro atendido</option>{visibleDeliveryZones.map((zone) => <option key={zone.id} value={zone.id}>{zone.name} — {zone.city}/{zone.state} · {currency.format(zone.fee)}</option>)}</select><small>{visibleDeliveryZones.length ? 'A taxa aparece ao lado do bairro e entra automaticamente no total.' : 'Nenhuma área ativa foi encontrada para a cidade/UF informada.'}</small></label>
                <label className="field"><span>Cidade *</span><input required value={form.deliveryCity} onChange={(e) => update('deliveryCity', e.target.value)} placeholder="Cidade" /></label>
                <label className="field field--small"><span>UF *</span><input required maxLength={2} value={form.deliveryState} onChange={(e) => update('deliveryState', e.target.value.toUpperCase().replace(/[^A-Z]/g, '').slice(0, 2))} placeholder="ES" /></label>
                <label className="field field--full"><span>Ponto de referência</span><textarea value={form.referencePoint} onChange={(e) => update('referencePoint', e.target.value)} placeholder="Ex.: Próximo à praça, portão azul, ao lado da farmácia..." /></label>

                {cepError && <div className="delivery-lookup-message is-warning field--full"><AlertCircle size={17} /><span><strong>Confira a área de entrega</strong>{cepError}{cepNeighborhood && <> Bairro retornado pelo CEP: <b>{cepNeighborhood}</b>.</>}</span></div>}
                {selectedZone && <div className="delivery-fee-confirmation field--full"><Truck size={18} /><div><span>Entrega confirmada para <strong>{selectedZone.name}</strong></span><small>{selectedZone.city}/{selectedZone.state}</small></div><b>{selectedZone.fee === 0 ? 'Grátis' : currency.format(selectedZone.fee)}</b></div>}
                {fullAddress && <div className="address-preview field--full"><MapPin size={16} /><span><strong>Resumo do endereço</strong>{fullAddress}</span></div>}
              </div>
            </section>
          )}

          {form.fulfillment === 'pickup' && (
            <section className="checkout-card checkout-pickup-card">
              <div className="checkout-card__heading">
                <span><PackageCheck size={20} /></span>
                <div><small>ETAPA 4</small><h2>Retirada na loja</h2><p>Seu pedido ficará disponível para retirada após a confirmação da floricultura.</p></div>
              </div>
              <div className="pickup-address"><MapPin size={19} /><div><strong>{settings.name}</strong><span>{settings.address || `${settings.city} - ${settings.state}`}</span></div></div>
            </section>
          )}

          <section className="checkout-card">
            <div className="checkout-card__heading">
              <span><Gift size={20} /></span>
              <div><small>ETAPA 5</small><h2>Cartão e observações</h2><p>Personalize a mensagem que acompanhará o presente.</p></div>
            </div>
            <div className="checkout-form-grid">
              <label className="field field--full"><span>Mensagem para o cartão</span><textarea value={form.cardMessage} onChange={(e) => update('cardMessage', e.target.value)} maxLength={280} placeholder="Ex.: Feliz aniversário! Que seu dia seja tão especial quanto você." /><small className="counter">{form.cardMessage.length}/280</small></label>
              <label className="field"><span>Assinatura do cartão</span><input disabled={form.anonymousSender} value={form.cardSignature} onChange={(e) => update('cardSignature', e.target.value)} placeholder="Ex.: Com amor, José" /></label>
              <label className="inline-check"><input type="checkbox" checked={form.anonymousSender} onChange={(e) => update('anonymousSender', e.target.checked)} /><span><strong>Enviar de forma anônima</strong><small>Não mostrar quem enviou no cartão.</small></span></label>
              <label className="field field--full"><span>Observações do pedido</span><textarea value={form.notes} onChange={(e) => update('notes', e.target.value)} placeholder="Alguma orientação especial? Ex.: tocar interfone, evitar ligar antes da entrega..." /></label>
            </div>
          </section>

          <section className="checkout-card">
            <div className="checkout-card__heading">
              <span><CreditCard size={20} /></span>
              <div><small>ETAPA 6</small><h2>Forma de pagamento</h2><p>Escolha como deseja prosseguir com o pagamento.</p></div>
            </div>
            <div className="payment-options">{availablePaymentMethods.map(renderPaymentMethod)}</div>
          </section>

          <section className="checkout-card checkout-review-card">
            {appConfig.turnstileSiteKey && <div className="checkout-security-check"><div><strong>Verificação de segurança</strong><span>Proteção automática contra pedidos abusivos. Nenhum dado do pedido é enviado ao Turnstile.</span></div><TurnstileWidget siteKey={appConfig.turnstileSiteKey} onToken={handleTurnstileToken} resetSignal={turnstileResetSignal} /></div>}
            <label className="review-confirmation">
              <input required type="checkbox" checked={form.reviewConfirmed} onChange={(e) => update('reviewConfirmed', e.target.checked)} />
              <span className="review-checkmark"><CheckCircle2 size={18} /></span>
              <span><strong>Confirmo que revisei todos os dados do pedido e estão corretos *</strong><small>Confira especialmente telefone, data, destinatário, endereço, bairro de entrega e forma de pagamento. Esses dados serão usados para preparar o pedido.</small></span>
            </label>
          </section>
        </main>

        <aside className="order-summary checkout-summary checkout-summary--sticky">
          <div className="summary-header"><span className="eyebrow">RESUMO DO PEDIDO</span><ShoppingBag size={20} /></div>
          <div className="checkout-summary-items">
            {items.map((item) => (
              <article className="summary-product summary-product--rich" key={item.id}>
                <ImageWithFallback src={item.imageUrl} alt={item.productName} />
                <div className="summary-product__content">
                  <div className="summary-product__title"><strong>{item.productName}</strong><span>{item.quantity}x</span></div>
                  {item.variation && <span>Variação: {item.variation.name}</span>}
                  {item.addons.length > 0 && <small>+ {item.addons.map((addon) => addon.name).join(' · ')}</small>}
                  <b>{currency.format(cartItemUnitTotal(item) * item.quantity)}</b>
                </div>
              </article>
            ))}
          </div>
          <div className="summary-divider" />
          <div className="summary-row"><span>Produtos</span><strong>{currency.format(subtotal)}</strong></div>
          <div className="summary-row"><span>{form.fulfillment === 'delivery' ? 'Entrega' : 'Retirada'}</span><strong>{form.fulfillment === 'delivery' ? (selectedZone ? (deliveryFee === 0 ? 'Grátis' : currency.format(deliveryFee)) : 'Selecione o bairro') : 'Sem taxa'}</strong></div>
          {selectedZone && <div className="summary-row muted"><span>Área</span><strong>{selectedZone.name}</strong></div>}
          <div className="summary-total summary-total--large"><span>Total</span><strong>{currency.format(orderTotal)}</strong></div>
          <div className="summary-note"><CheckCircle2 size={17} /><span>{form.fulfillment === 'delivery' ? (selectedZone ? `Taxa de ${selectedZone.name} já incluída no total.` : 'Selecione o bairro para calcular a entrega.') : 'Retirada selecionada: não há taxa de entrega.'}</span></div>
          <button className="primary-button checkout-submit" disabled={submitDisabled} type="submit" aria-busy={sending}>
            <CheckCircle2 size={19} />{sending ? 'Registrando pedido...' : 'Registrar pedido'}
          </button>
          <p className="checkout-submit-hint">O pedido é salvo no FloriWeb antes de você abrir o WhatsApp. Depois do registro, você verá o número do pedido e poderá continuar a conversa com a loja.</p>
        </aside>
        <div className="checkout-mobile-submit"><div><small>Total do pedido</small><strong>{currency.format(orderTotal)}</strong></div><button className="primary-button" disabled={submitDisabled} type="submit" aria-busy={sending}>{sending?<LoaderCircle className="spin" size={18}/>:<CheckCircle2 size={18}/>}<span>{sending?'Registrando...':'Registrar pedido'}</span></button></div>
      </form>
    </div>
  );
}
