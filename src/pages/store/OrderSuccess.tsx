import { ArrowLeft, Banknote, Check, CheckCircle2, Copy, CreditCard, MessageCircle, QrCode, Store } from 'lucide-react';
import { useMemo, useState } from 'react';
import { useLocation, useParams } from 'react-router-dom';
import { useStore } from '../../contexts/StoreContext';
import { useToast } from '../../contexts/ToastContext';
import type { OrderConfirmation } from '../../types';
import { copyText } from '../../utils/clipboard';
import { currency } from '../../utils/format';
import { formatOrderNumber, readOrderConfirmation } from '../../utils/orderConfirmation';
import { buildPostOrderWhatsAppMessage, getWhatsAppUrl } from '../../utils/whatsapp';
import { storefrontPath } from '../../utils/storefrontRoute';

export default function OrderSuccess() {
  const { orderId = '' } = useParams();
  const location = useLocation();
  const { markOrderWhatsAppClicked, storeBasePath } = useStore();
  const { showToast } = useToast();
  const [copied, setCopied] = useState(false);
  const [whatsappMarkState, setWhatsappMarkState] = useState<'idle' | 'sending' | 'done' | 'error'>('idle');

  const confirmation = useMemo(() => {
    const fromState = location.state as OrderConfirmation | null;
    if (fromState?.orderId === orderId) return fromState;
    return readOrderConfirmation(orderId);
  }, [location.state, orderId]);

  if (!confirmation) {
    return (
      <main className="order-success-page">
        <section className="order-success-card order-success-card--missing">
          <div className="success-icon"><CheckCircle2 size={50} /></div>
          <h1>Pedido não disponível nesta sessão</h1>
          <p>Por segurança, os dados de confirmação ficam somente nesta sessão do navegador.</p>
          <a className="primary-button" href={storefrontPath(storeBasePath)}><ArrowLeft size={18} />Voltar para a loja</a>
        </section>
      </main>
    );
  }

  const isPix = confirmation.paymentMethod === 'pix' && confirmation.pixEnabled;
  const isPixCopyPaste = isPix && confirmation.pixReceiptMode === 'copy_paste' && Boolean(confirmation.pixCopyPaste.trim());
  const isPixKey = isPix && confirmation.pixReceiptMode === 'key' && Boolean(confirmation.pixKey.trim());
  const isCard = confirmation.paymentMethod === 'card';
  const isCash = confirmation.paymentMethod === 'cash';
  const whatsappMessage = buildPostOrderWhatsAppMessage(confirmation);
  const whatsappUrl = getWhatsAppUrl(confirmation.storeWhatsapp, whatsappMessage);
  const pixValue = isPixCopyPaste ? confirmation.pixCopyPaste : confirmation.pixKey;

  const handleCopyPix = async () => {
    try {
      await copyText(pixValue);
      setCopied(true);
      showToast(isPixCopyPaste ? 'PIX Copia e Cola copiado.' : 'Chave PIX copiada.', 'success');
      window.setTimeout(() => setCopied(false), 1800);
    } catch {
      showToast('Não foi possível copiar o PIX.', 'error');
    }
  };

  const handleWhatsAppClick = () => {
    setWhatsappMarkState('sending');
    void markOrderWhatsAppClicked(confirmation.orderId)
      .then(() => setWhatsappMarkState('done'))
      .catch((error) => {
        console.error('Não foi possível atualizar o status do WhatsApp:', error);
        setWhatsappMarkState('error');
        showToast('O pedido está registrado, mas não foi possível marcar a abertura do WhatsApp. Você pode tentar o botão novamente.', 'error');
      });
  };

  return (
    <main className="order-success-page">
      <section className="order-success-card">
        <div className="success-icon"><CheckCircle2 size={54} strokeWidth={2.2} /></div>

        <h1>Pedido registrado!</h1>
        <p className="order-success-number">Pedido <strong>#{formatOrderNumber(confirmation.orderNumber)}</strong></p>

        <div className="order-registration-proof" role="status">
          <CheckCircle2 size={20} />
          <div><strong>Salvo no FloriWeb</strong><span>Este pedido já foi registrado no sistema. O WhatsApp é a próxima etapa de contato com a floricultura.</span></div>
        </div>

        <div className="order-success-payment">
          <div className="order-success-payment__title">
            {isCash ? <Banknote size={22} /> : isCard ? <CreditCard size={22} /> : isPixCopyPaste ? <QrCode size={22} /> : <CreditCard size={22} />}
            <strong>{isCash ? 'Pagamento em dinheiro' : isCard ? 'Pagamento por cartão' : isPix ? 'PIX (Comprovante)' : 'Aguardando confirmação'}</strong>
          </div>

          {isPix ? (
            <>
              <p>{isPixCopyPaste ? 'Copie o PIX Copia e Cola abaixo. Ele já contém o valor deste pedido.' : 'Efetue o pagamento via PIX e envie o comprovante pelo WhatsApp para a loja confirmar seu pedido.'}</p>
              <strong className="order-success-total">Total: {currency.format(confirmation.total)}</strong>
            </>
          ) : isCard ? (
            <>
              <p>Seu pedido foi registrado. Solicite o link de pagamento pelo WhatsApp. A floricultura gerará e enviará o link manualmente.</p>
              <strong className="order-success-total">Total: {currency.format(confirmation.total)}</strong>
            </>
          ) : isCash ? (
            <>
              <p>Seu pedido foi registrado para pagamento em dinheiro. Combine pelo WhatsApp se precisar de troco.</p>
              <strong className="order-success-total">Total: {currency.format(confirmation.total)}</strong>
            </>
          ) : (
            <>
              <p>Seu pedido foi registrado. Fale com a floricultura pelo WhatsApp para confirmar disponibilidade, entrega e pagamento.</p>
              <strong className="order-success-total">Total: {currency.format(confirmation.total)}</strong>
            </>
          )}
        </div>

        {(isPixCopyPaste || isPixKey) && (
          <div className="pix-confirmation-box">
            <p>{isPixCopyPaste ? `Copie o código abaixo e cole na opção “PIX Copia e Cola” do seu banco. O valor de ${currency.format(confirmation.total)} já está preenchido.` : `Copie a chave PIX, informe o valor de ${currency.format(confirmation.total)} no banco e depois envie o comprovante para ${confirmation.storeName}.`}</p>
            <span className="pix-key-label">{isPixCopyPaste ? 'PIX Copia e Cola · valor automático' : `Chave PIX · ${confirmation.pixKeyType || 'Chave cadastrada'}`}</span>
            <div className="pix-key-row">
              <code>{pixValue}</code>
              <button type="button" onClick={() => void handleCopyPix()} aria-label="Copiar PIX" title="Copiar PIX">
                {copied ? <Check size={21} /> : <Copy size={21} />}
              </button>
            </div>
            {confirmation.pixReceiver && <small>Recebedor: {confirmation.pixReceiver}</small>}
          </div>
        )}

        {isCard && (
          <div className="card-link-info-box">
            <CreditCard size={24} />
            <div><strong>O pagamento não é feito dentro do FloriWeb.</strong><span>Ao tocar no botão abaixo, o WhatsApp abrirá com uma solicitação pronta. A loja deverá gerar o link no banco/adquirente e enviá-lo manualmente para você.</span></div>
          </div>
        )}

        <div className="order-success-store">
          <Store size={20} />
          <span>{confirmation.storeName}</span>
        </div>

        <a
          className="whatsapp-confirmation-button"
          href={whatsappUrl}
          target="_blank"
          rel="noopener noreferrer"
          onClick={handleWhatsAppClick}
        >
          <MessageCircle size={21} />
          {isPix ? 'Abrir WhatsApp e enviar comprovante' : isCard ? 'Abrir WhatsApp e solicitar link' : isCash ? 'Abrir WhatsApp e combinar pagamento' : 'Abrir WhatsApp para confirmar'}
        </a>
        <div className={`whatsapp-sync-state is-${whatsappMarkState}`} aria-live="polite">
          {whatsappMarkState === 'sending' && <span>Registrando a abertura do WhatsApp no pedido...</span>}
          {whatsappMarkState === 'done' && <span>A abertura do WhatsApp foi vinculada ao pedido #{formatOrderNumber(confirmation.orderNumber)}.</span>}
          {whatsappMarkState === 'error' && <span>O pedido continua salvo; apenas o status do WhatsApp não foi atualizado. Toque no botão novamente quando voltar.</span>}
        </div>

        {isPix && <p className="order-success-hint">O WhatsApp abrirá com a mensagem pronta. Depois do pagamento, anexe a imagem do comprovante na conversa.</p>}
        {isCard && <p className="order-success-hint">Nunca informe número completo do cartão, CVV ou senha pelo WhatsApp. Utilize apenas o link de pagamento enviado pela loja.</p>}
        {isCash && <p className="order-success-hint">Se precisar de troco, informe pelo WhatsApp antes da entrega ou retirada.</p>}

        <a className="order-success-back" href={storefrontPath(storeBasePath)}><ArrowLeft size={19} />Voltar para a loja</a>
      </section>
    </main>
  );
}
