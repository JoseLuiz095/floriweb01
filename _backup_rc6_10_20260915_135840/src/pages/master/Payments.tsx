import {
  Ban,
  CalendarDays,
  CheckCircle2,
  RefreshCw,
  ReceiptText,
  X,
} from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';
import {
  confirmSubscriptionPayment,
  loadMasterBilling,
  rejectSubscriptionPayment,
  type SubscriptionPayment,
} from '../../services/billingFinanceApi';
import { trackInteraction } from '../../services/interactionTelemetry';

const money = (value: number) => new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(value);
const dateBr = (value?: string) => value ? new Date(`${value.slice(0, 10)}T12:00:00`).toLocaleDateString('pt-BR') : '—';
const dateTimeBr = (value?: string) => value ? new Date(value).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' }) : '—';

const statusLabel = (payment: SubscriptionPayment) => ({
  proof_sent: 'Comprovante enviado',
  paid: 'Pago',
  rejected: 'Não renovado',
  cancelled: 'Cancelado',
  pending: 'Aguardando pagamento',
}[payment.status]);

export default function Payments() {
  const [payments, setPayments] = useState<SubscriptionPayment[]>([]);
  const [busy, setBusy] = useState('');
  const [error, setError] = useState('');
  const [rejecting, setRejecting] = useState<SubscriptionPayment | null>(null);
  const [rejectReason, setRejectReason] = useState('');

  const load = async () => {
    try {
      setError('');
      const data = await loadMasterBilling();
      setPayments(data.payments);
    } catch (currentError) {
      setError(currentError instanceof Error ? currentError.message : 'Falha ao carregar pagamentos.');
    }
  };

  useEffect(() => { void load(); }, []);

  const pendingCount = useMemo(
    () => payments.filter((payment) => payment.status === 'pending' || payment.status === 'proof_sent').length,
    [payments],
  );

  const confirm = async (payment: SubscriptionPayment) => {
    if (!window.confirm(`Confirma o crédito bancário de ${money(payment.amount)} e o comprovante recebido?`)) return;
    setBusy(payment.id);
    setError('');
    try {
      await trackInteraction(
        payment.paymentIntent === 'plan_change' ? 'subscription_plan_change_confirm' : 'subscription_renewal_confirm',
        () => confirmSubscriptionPayment(payment.id),
        { storeId: payment.storeId, successKind: 'audit' },
      );
      await load();
    } catch (currentError) {
      setError(currentError instanceof Error ? currentError.message : 'Falha ao confirmar.');
    } finally {
      setBusy('');
    }
  };

  const openReject = (payment: SubscriptionPayment) => {
    setRejectReason(payment.paymentIntent === 'renewal'
      ? 'Renovação não confirmada pelo financeiro.'
      : 'Alteração de plano não confirmada pelo financeiro.');
    setRejecting(payment);
  };

  const reject = async () => {
    if (!rejecting || rejectReason.trim().length < 5) {
      setError('Informe um motivo para registrar a não renovação/negação.');
      return;
    }
    setBusy(rejecting.id);
    setError('');
    try {
      await trackInteraction(
        rejecting.paymentIntent === 'plan_change' ? 'subscription_plan_change_reject' : 'subscription_renewal_reject',
        () => rejectSubscriptionPayment(rejecting.id, rejectReason.trim()),
        { storeId: rejecting.storeId, successKind: 'audit' },
      );
      setRejecting(null);
      setRejectReason('');
      await load();
    } catch (currentError) {
      setError(currentError instanceof Error ? currentError.message : 'Falha ao negar a cobrança.');
    } finally {
      setBusy('');
    }
  };

  return (
    <>
      <div className="admin-page-title">
        <div>
          <span className="eyebrow">MENSALIDADES</span>
          <h1>Pagamentos e alterações de plano</h1>
          <p>Confirme somente após conferir o PIX. Se o crédito não existir ou a renovação não for aceita, registre como não renovado sem deslocar o vencimento da loja.</p>
        </div>
        <button className="secondary-button" onClick={() => void load()}><RefreshCw size={16} />Atualizar</button>
      </div>

      <section className="master-payment-summary-rc65">
        <span><strong>{pendingCount}</strong><small>Aguardando decisão</small></span>
        <span><strong>{payments.filter((payment) => payment.status === 'paid').length}</strong><small>Pagamentos confirmados</small></span>
        <span><strong>{payments.filter((payment) => payment.status === 'rejected').length}</strong><small>Não renovados</small></span>
      </section>

      {error && <div className="form-error">{error}</div>}

      <div className="flori-master-payment-list">
        {payments.length ? payments.map((payment) => (
          <article className="admin-card" key={payment.id}>
            <div className="flori-payment-status">
              <ReceiptText />
              <div>
                <span>{payment.storeName || 'Floricultura'}</span>
                <h2>{payment.paymentIntent === 'plan_change'
                  ? `${payment.previousPlanName || 'Plano atual'} → ${payment.requestedPlanName || payment.planName}`
                  : payment.planName || 'Renovação'}</h2>
              </div>
              <b className={`status-${payment.status}`}>{statusLabel(payment)}</b>
            </div>

            <div className="flori-payment-admin-meta flori-payment-admin-meta-rc65">
              <span>Valor <strong>{money(payment.amount)}</strong></span>
              <span>Cobrança <strong>#{payment.id.slice(0, 8)}</strong></span>
              <span>Referência / vencimento <strong>{dateBr(payment.dueDate)}</strong></span>
              <span>Dia configurado <strong>{payment.dueDay ? `Dia ${payment.dueDay}` : '—'}</strong></span>
              <span>Próximo vencimento <strong>{dateBr(payment.nextDueDate)}</strong></span>
              {payment.paidAt && <span>Confirmado em <strong>{dateTimeBr(payment.paidAt)}</strong></span>}
              {payment.rejectedAt && <span>Negado em <strong>{dateTimeBr(payment.rejectedAt)}</strong></span>}
            </div>

            {payment.billingState === 'overdue' && (
              <div className="master-payment-overdue-rc65"><CalendarDays size={16} /><span>A mensalidade desta loja está vencida. O próximo vencimento só avança quando um pagamento válido for confirmado.</span></div>
            )}

            {payment.status === 'rejected' && payment.rejectionReason && (
              <div className="master-payment-rejection-reason-rc65"><strong>Motivo:</strong> {payment.rejectionReason}</div>
            )}

            {(payment.status === 'pending' || payment.status === 'proof_sent') && (
              <div className="master-payment-actions-rc65">
                <button
                  type="button"
                  className="primary-button"
                  disabled={busy === payment.id || (payment.proofRequired && payment.status !== 'proof_sent')}
                  onClick={() => void confirm(payment)}
                  title={payment.proofRequired && payment.status !== 'proof_sent' ? 'Aguardando o lojista informar o envio do comprovante.' : undefined}
                >
                  <CheckCircle2 size={16} />
                  {busy === payment.id
                    ? 'Confirmando...'
                    : payment.paymentIntent === 'plan_change'
                      ? 'Confirmar alteração de plano'
                      : 'Confirmar renovação'}
                </button>
                <button type="button" className="secondary-button danger-button-rc65" disabled={busy === payment.id} onClick={() => openReject(payment)}>
                  <Ban size={16} />{payment.paymentIntent === 'plan_change' ? 'Negar alteração' : 'Não confirmar renovação'}
                </button>
                {payment.proofRequired && payment.status !== 'proof_sent' && (
                  <small className="master-payment-proof-note-r69">A confirmação fica disponível assim que o comprovante for informado pelo lojista.</small>
                )}
              </div>
            )}
          </article>
        )) : <div className="admin-card"><p>Nenhuma cobrança registrada.</p></div>}
      </div>

      {rejecting && (
        <div className="modal-overlay">
          <div className="master-modal master-payment-reject-modal-rc65">
            <button type="button" className="modal-close" onClick={() => setRejecting(null)}><X /></button>
            <span className="eyebrow">DECISÃO DO FINANCEIRO</span>
            <h2>{rejecting.paymentIntent === 'plan_change' ? 'Negar alteração de plano' : 'Registrar mensalidade não renovada'}</h2>
            <p>A data de vencimento da assinatura não será avançada. Se ela estiver vencida, o lojista verá o alerta vermelho no painel.</p>
            <label>
              Motivo
              <textarea value={rejectReason} onChange={(event) => setRejectReason(event.target.value)} placeholder="Ex.: crédito não identificado, comprovante inválido ou renovação não realizada." />
            </label>
            <div className="master-modal-actions">
              <button className="secondary-button" onClick={() => setRejecting(null)}>Cancelar</button>
              <button className="primary-button danger-primary-rc65" disabled={busy === rejecting.id || rejectReason.trim().length < 5} onClick={() => void reject()}>
                <Ban size={16} />{busy === rejecting.id ? 'Registrando...' : 'Confirmar não renovação'}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
