import {
  AlertTriangle,
  CalendarDays,
  CheckCircle2,
  Clipboard,
  Clock3,
  MessageCircle,
  ReceiptText,
  RefreshCw,
  Sparkles,
  WalletCards,
} from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';
import { useStore } from '../../contexts/StoreContext';
import {
  createManualCharge,
  loadBillingOverview,
  markProofSent,
  type BillingOverview,
  type SubscriptionPayment,
} from '../../services/billingFinanceApi';
import { buildPixCopyPasteWithAmount, buildStaticPixCopyPaste } from '../../utils/pix';

const money = (value: number) => new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(value);
const dateBr = (value?: string) => value ? new Date(`${value.slice(0, 10)}T12:00:00`).toLocaleDateString('pt-BR') : '—';
const dateTimeBr = (value?: string) => value ? new Date(value).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' }) : '—';

const statusLabel = (status: SubscriptionPayment['status']) => ({
  pending: 'Aguardando pagamento',
  proof_sent: 'Comprovante enviado',
  paid: 'Pago',
  rejected: 'Não renovado',
  cancelled: 'Cancelado',
}[status]);

export default function Billing() {
  const { settings } = useStore();
  const [data, setData] = useState<BillingOverview | null>(null);
  const [busy, setBusy] = useState('');
  const [error, setError] = useState('');

  const load = async () => {
    try {
      setError('');
      setData(await loadBillingOverview(settings.id));
    } catch (currentError) {
      setError(currentError instanceof Error ? currentError.message : 'Falha ao carregar cobrança.');
    }
  };

  useEffect(() => {
    if (settings.id) void load();
  }, [settings.id]);

  const pending = useMemo(
    () => data?.payments.find((payment) => payment.status === 'pending' || payment.status === 'proof_sent'),
    [data],
  );
  const lastPaid = data?.subscription?.lastPayment || data?.payments.find((payment) => payment.status === 'paid');
  const lastRejected = data?.payments.find((payment) => payment.status === 'rejected');
  const subscription = data?.subscription;
  const overdue = subscription?.billingState === 'overdue';

  const pixFor = (payment: SubscriptionPayment) => {
    if (!data) return '';
    try {
      return data.settings.pixCopyPaste
        ? buildPixCopyPasteWithAmount(data.settings.pixCopyPaste, payment.amount)
        : buildStaticPixCopyPaste({
          key: data.settings.pixKey,
          receiver: data.settings.pixHolderName,
          city: data.settings.pixCity,
          amount: payment.amount,
          txid: payment.id.replace(/-/g, '').slice(0, 25),
        });
    } catch {
      return '';
    }
  };

  const request = async (planId: string) => {
    setBusy(planId);
    setError('');
    try {
      setData(await createManualCharge(settings.id, planId));
    } catch (currentError) {
      setError(currentError instanceof Error ? currentError.message : 'Não foi possível criar a cobrança.');
    } finally {
      setBusy('');
    }
  };

  const proof = async (payment: SubscriptionPayment) => {
    if (!data) return;
    const phone = data.settings.whatsapp.replace(/\D/g, '');
    if (!phone) {
      setError('O WhatsApp financeiro ainda não foi cadastrado pelo Admin Master.');
      return;
    }
    const current = data.currentPlan?.name || 'Plano atual';
    const target = data.plans.find((item) => item.id === payment.requestedPlanId)?.name
      || data.plans.find((item) => item.id === payment.planId)?.name
      || 'Plano';
    const message = payment.paymentIntent === 'plan_change'
      ? `Olá! Realizei o pagamento e gostaria de alterar o plano da floricultura ${settings.name} de ${current} para ${target}. Valor ${money(payment.amount)}. Cobrança #${payment.id.slice(0, 8)}. Estou enviando o comprovante.`
      : `Olá! Realizei o pagamento da mensalidade da floricultura ${settings.name}. Plano ${target}. Valor ${money(payment.amount)}. Cobrança #${payment.id.slice(0, 8)}. Estou enviando o comprovante.`;
    window.open(`https://wa.me/55${phone.replace(/^55/, '')}?text=${encodeURIComponent(message)}`, '_blank', 'noopener,noreferrer');
    setData(await markProofSent(payment.id));
  };

  return (
    <>
      <div className="admin-page-title">
        <div>
          <span className="eyebrow">MENSALIDADE</span>
          <h1>Plano e pagamento por PIX</h1>
          <p>Consulte vencimento, último pagamento e renove ou altere o plano quando necessário.</p>
        </div>
        <button className="secondary-button" onClick={() => void load()}><RefreshCw size={16} />Atualizar</button>
      </div>

      {error && <div className="form-error">{error}</div>}

      {!data ? <div className="admin-card">Carregando...</div> : (
        <>
          {subscription && subscription.billingState !== 'trial' && (
            <section className={`admin-card flori-billing-health-rc65 ${overdue ? 'is-overdue' : 'is-current'}`}>
              {overdue ? <AlertTriangle size={25} /> : <CheckCircle2 size={25} />}
              <div>
                <span className="eyebrow">SITUAÇÃO DA MENSALIDADE</span>
                <h2>{overdue ? 'Mensalidade atrasada' : 'Mensalidade em dia'}</h2>
                <p>
                  {overdue
                    ? `O vencimento de ${dateBr(subscription.nextDueDate)} ainda não possui renovação confirmada.`
                    : `Próximo vencimento em ${dateBr(subscription.nextDueDate)}, respeitando o dia ${subscription.dueDay || '—'} configurado pelo Admin Master.`}
                </p>
              </div>
              <strong>{overdue && subscription.daysOverdue > 0 ? `${subscription.daysOverdue} dia(s) em atraso` : `Dia ${subscription.dueDay || '—'}`}</strong>
            </section>
          )}

          <section className="admin-card flori-current-plan flori-current-plan-rc65">
            <div>
              <span>PLANO ATUAL</span>
              <h2>{data.currentPlan?.name || 'Sem plano ativo'}</h2>
              <strong>{money(subscription?.billingAmount ?? data.currentPlan?.monthlyPrice ?? 0)}/mês</strong>
            </div>
            <div className="flori-subscription-meta-rc65">
              <span><CalendarDays size={17} /><small>Dia de vencimento</small><strong>{subscription?.dueDay ? `Dia ${subscription.dueDay}` : '—'}</strong></span>
              <span><Clock3 size={17} /><small>Próximo vencimento</small><strong>{dateBr(subscription?.nextDueDate)}</strong></span>
              <span><ReceiptText size={17} /><small>Último pagamento</small><strong>{dateBr(lastPaid?.paidAt)}</strong></span>
            </div>
          </section>

          <section className="admin-card flori-last-payment-rc65">
            <div className="admin-card__header">
              <div><span className="eyebrow">ÚLTIMO PAGAMENTO</span><h2>{lastPaid ? 'Mensalidade confirmada' : 'Nenhum pagamento confirmado ainda'}</h2></div>
              <ReceiptText />
            </div>
            {lastPaid ? (
              <div className="flori-last-payment-grid-rc65">
                <span><small>Plano</small><strong>{lastPaid.requestedPlanName || lastPaid.planName || data.currentPlan?.name || '—'}</strong></span>
                <span><small>Valor</small><strong>{money(lastPaid.amount)}</strong></span>
                <span><small>Pago em</small><strong>{dateTimeBr(lastPaid.paidAt)}</strong></span>
                <span><small>Vencimento da referência</small><strong>{dateBr(lastPaid.dueDate)}</strong></span>
                <span><small>Próximo vencimento</small><strong>{dateBr(subscription?.nextDueDate)}</strong></span>
                <span><small>Cobrança</small><strong>#{lastPaid.id.slice(0, 8)}</strong></span>
              </div>
            ) : (
              <p>Quando o Admin Master confirmar a primeira mensalidade, os dados do pagamento aparecerão aqui.</p>
            )}
          </section>

          {lastRejected && (!lastPaid || new Date(lastRejected.createdAt).getTime() > new Date(lastPaid.createdAt).getTime()) && (
            <section className="admin-card flori-last-rejection-rc65">
              <AlertTriangle size={21} />
              <div>
                <strong>Última renovação não foi confirmada</strong>
                <p>{lastRejected.rejectionReason || 'O Admin Master marcou a cobrança como não renovada.'}</p>
                <small>Analisado em {dateTimeBr(lastRejected.rejectedAt || lastRejected.createdAt)} · referência {dateBr(lastRejected.dueDate)}</small>
              </div>
            </section>
          )}

          <div className="flori-admin-plan-grid">
            {data.plans.map((plan) => (
              <article className={`admin-card ${data.currentPlan?.id === plan.id ? 'current' : ''}`} key={plan.id}>
                <small>{plan.code}</small>
                <h2>{plan.name}</h2>
                <strong>{money(plan.monthlyPrice)}<span>/mês</span></strong>
                <p>{plan.code === 'BASIC' ? 'Catálogo e pedidos para começar.' : plan.code === 'PRO' ? 'Mais recursos para crescer e analisar.' : 'Estrutura completa para operações avançadas.'}</p>
                <button className="primary-button" disabled={Boolean(busy) || pending?.requestedPlanId === plan.id} onClick={() => void request(plan.id)}>
                  {busy === plan.id ? 'Gerando...' : data.currentPlan?.id === plan.id ? 'Renovar com PIX' : 'Mudar para este plano'}
                </button>
              </article>
            ))}
          </div>

          {pending && (
            <section className="admin-card flori-payment-card">
              <div className="admin-card__header">
                <div><span className="eyebrow">PAGAMENTO PENDENTE</span><h2>{pending.paymentIntent === 'plan_change' ? 'Alteração de plano' : 'Renovação da mensalidade'}</h2></div>
                <WalletCards />
              </div>
              <div className="flori-payment-value"><span>Valor</span><strong>{money(pending.amount)}</strong></div>
              <div className="flori-pending-reference-rc65"><CalendarDays size={16} /><span>Vencimento da referência: <strong>{dateBr(pending.dueDate)}</strong></span></div>
              {pixFor(pending) ? (
                <>
                  <label>PIX Copia e Cola</label>
                  <div className="flori-copy-row"><textarea readOnly value={pixFor(pending)} /><button onClick={() => void navigator.clipboard.writeText(pixFor(pending))}><Clipboard size={16} />Copiar</button></div>
                </>
              ) : <div className="form-error">Cadastre uma Chave PIX válida ou PIX Copia e Cola base no Admin Master.</div>}
              <div className="flori-proof-step">
                <MessageCircle />
                <div><strong>Envio do comprovante é obrigatório</strong><p>Depois de pagar, abra o WhatsApp, anexe o comprovante e aguarde a conferência do Admin Master.</p></div>
                <button className="primary-button" onClick={() => void proof(pending)}>{pending.status === 'proof_sent' ? <><CheckCircle2 size={16} />Comprovante informado</> : <>Enviar comprovante no WhatsApp</>}</button>
              </div>
            </section>
          )}

          <section className="admin-card flori-billing-note">
            <Sparkles />
            <div><strong>Vencimento preservado</strong><p>O pagamento confirmado recebe a data real da confirmação. O próximo vencimento continua seguindo o dia configurado pelo Admin Master; pagar atrasado não empurra a mensalidade para o dia do pagamento.</p></div>
          </section>

          {data.payments.length > 0 && (
            <section className="admin-card flori-payment-history-rc65">
              <div className="admin-card__header"><div><span className="eyebrow">HISTÓRICO RECENTE</span><h2>Últimas cobranças</h2></div></div>
              <div>
                {data.payments.slice(0, 5).map((payment) => (
                  <div className="flori-payment-history-row-rc65" key={payment.id}>
                    <span><strong>{payment.paymentIntent === 'plan_change' ? 'Alteração de plano' : 'Mensalidade'}</strong><small>#{payment.id.slice(0, 8)} · referência {dateBr(payment.dueDate)}</small></span>
                    <span>{money(payment.amount)}</span>
                    <b className={`status-${payment.status}`}>{statusLabel(payment.status)}</b>
                  </div>
                ))}
              </div>
            </section>
          )}
        </>
      )}
    </>
  );
}
