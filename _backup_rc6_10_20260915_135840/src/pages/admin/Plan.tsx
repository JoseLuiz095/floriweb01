import {
  AlertTriangle,
  BarChart3,
  CalendarDays,
  Check,
  CheckCircle2,
  Clipboard,
  Clock3,
  Crown,
  Globe2,
  Headphones,
  Images,
  MessageCircle,
  Package,
  Puzzle,
  ReceiptText,
  RefreshCw,
  Sparkles,
  Tags,
  Users,
  WalletCards,
} from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';
import { useLocation } from 'react-router-dom';
import { ErrorState, LoadingState } from '../../components/ui/AsyncState';
import { useStore } from '../../contexts/StoreContext';
import {
  createManualCharge,
  loadBillingOverview,
  markProofSent,
  type BillingOverview,
  type SubscriptionPayment,
} from '../../services/billingFinanceApi';
import { platformApi } from '../../services/platformApi';
import type { Plan } from '../../types';
import { currency } from '../../utils/format';
import { getBillingVisualStatus } from '../../utils/billingStatus';
import { trackInteraction } from '../../services/interactionTelemetry';
import { buildPixCopyPasteWithAmount, buildStaticPixCopyPaste } from '../../utils/pix';

type PlanFeature = { label: string; icon: typeof Package };
const BILLING_WARNING_DAYS = 7;

const limitText = (value: number | null | undefined, singular: string, plural: string) => {
  if (value == null) return `${plural} ilimitados`;
  return `${value} ${value === 1 ? singular : plural}`;
};

const planFeatures = (plan: Plan): PlanFeature[] => [
  { label: limitText(plan.productLimit, 'produto ativo', 'produtos ativos'), icon: Package },
  { label: limitText(plan.categoryLimit, 'categoria', 'categorias'), icon: Tags },
  { label: limitText(plan.imageLimitPerProduct, 'foto por produto', 'fotos por produto'), icon: Images },
  { label: limitText(plan.addonLimit, 'adicional', 'adicionais'), icon: Puzzle },
  { label: limitText(plan.adminUserLimit, 'usuario administrativo', 'usuarios administrativos'), icon: Users },
  { label: plan.customDomain ? 'Dominio proprio incluido' : 'Endereco padrao FloriWeb', icon: Globe2 },
  { label: plan.reports ? 'Relatorios comerciais' : 'Visao geral do catalogo', icon: BarChart3 },
  { label: plan.prioritySupport ? 'Suporte prioritario' : 'Suporte padrao', icon: Headphones },
];

const dateBr = (value?: string) => value
  ? new Date(`${value.slice(0, 10)}T12:00:00`).toLocaleDateString('pt-BR')
  : '---';

const dateTimeBr = (value?: string) => value
  ? new Date(value).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' })
  : '---';



const statusLabel = (status: SubscriptionPayment['status']) => ({
  pending: 'Aguardando pagamento',
  proof_sent: 'Comprovante enviado',
  paid: 'Pago',
  rejected: 'Nao renovado',
  cancelled: 'Cancelado',
}[status] || status);

export default function AdminPlan() {
  const { settings, planUsage } = useStore();
  const location = useLocation();
  const [plans, setPlans] = useState<Plan[]>([]);
  const [data, setData] = useState<BillingOverview | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState('');
  const [error, setError] = useState('');

  const load = async () => {
    if (!settings.id) return;
    setError('');
    try {
      const [planRows, overview] = await Promise.all([
        platformApi.listPlans(),
        loadBillingOverview(settings.id),
      ]);
      setPlans(planRows.filter((plan) => plan.active && plan.code !== 'DEMO'));
      setData(overview);
    } catch (currentError) {
      setError(currentError instanceof Error ? currentError.message : 'Nao foi possivel carregar plano e cobranca.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void load();
  }, [settings.id]);

  useEffect(() => {
    if (location.hash !== '#vencimento' || !data) return;
    window.setTimeout(() => {
      document.getElementById('vencimento')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }, 40);
  }, [data, location.hash]);

  const sorted = useMemo(
    () => [...plans].sort((a, b) => (a.sortOrder ?? 0) - (b.sortOrder ?? 0)),
    [plans],
  );

  const pending = useMemo(
    () => data?.payments.find((payment) => payment.status === 'pending' || payment.status === 'proof_sent'),
    [data],
  );

  const subscription = data?.subscription;
  const lastPaid = subscription?.lastPayment || data?.payments.find((payment) => payment.status === 'paid');
  const lastRejected = data?.payments.find((payment) => payment.status === 'rejected');
  const billingStatus = getBillingVisualStatus({ billingState: subscription?.billingState, nextDueDate: subscription?.nextDueDate, dueDay: subscription?.dueDay, warningDays: BILLING_WARNING_DAYS });
  const daysToDue = billingStatus.daysToDue;
  const daysOverdue = subscription?.daysOverdue ?? 0;
  const configuredDueDay = subscription?.dueDay ?? null;
  const overdue = billingStatus.overdue;
  const dueSoon = billingStatus.dueSoon;
  const healthClass = `is-${billingStatus.level === 'hidden' ? 'current' : billingStatus.level}`;
  const healthTitle = billingStatus.label || 'Mensalidade';
  const healthDescription = overdue
    ? `O vencimento de ${dateBr(subscription?.nextDueDate)} ainda nao possui renovacao confirmada.`
    : dueSoon
      ? daysToDue === 0
        ? `A mensalidade vence hoje, ${dateBr(subscription?.nextDueDate)}.`
        : `Faltam ${daysToDue} dia(s) para o vencimento de ${dateBr(subscription?.nextDueDate)}.`
      : `Proximo vencimento em ${dateBr(subscription?.nextDueDate)}, respeitando o dia ${subscription?.dueDay || '---'} configurado pelo Admin Master.`;

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
      setData(await trackInteraction('subscription_charge_create', () => createManualCharge(settings.id, planId), { storeId: settings.id }));
      window.setTimeout(() => document.getElementById('pagamento-pix')?.scrollIntoView({ behavior: 'smooth', block: 'start' }), 40);
    } catch (currentError) {
      setError(currentError instanceof Error ? currentError.message : 'Nao foi possivel criar a cobranca.');
    } finally {
      setBusy('');
    }
  };

  const proof = async (payment: SubscriptionPayment) => {
    if (!data) return;
    const phone = data.settings.whatsapp.replace(/\D/g, '');
    if (!phone) {
      setError('O WhatsApp financeiro ainda nao foi cadastrado pelo Admin Master.');
      return;
    }

    const current = data.currentPlan?.name || 'Plano atual';
    const target = data.plans.find((item) => item.id === payment.requestedPlanId)?.name
      || data.plans.find((item) => item.id === payment.planId)?.name
      || 'Plano';
    const message = payment.paymentIntent === 'plan_change'
      ? `Ola! Realizei o pagamento e gostaria de alterar o plano da floricultura ${settings.name} de ${current} para ${target}. Valor ${currency.format(payment.amount)}. Cobranca #${payment.id.slice(0, 8)}. Estou enviando o comprovante.`
      : `Ola! Realizei o pagamento da mensalidade da floricultura ${settings.name}. Plano ${target}. Valor ${currency.format(payment.amount)}. Cobranca #${payment.id.slice(0, 8)}. Estou enviando o comprovante.`;

    window.open(`https://wa.me/55${phone.replace(/^55/, '')}?text=${encodeURIComponent(message)}`, '_blank', 'noopener,noreferrer');
    setData(await trackInteraction('subscription_proof_sent', () => markProofSent(payment.id), { storeId: settings.id }));
  };

  if (loading) return <LoadingState label="Carregando plano e mensalidade..." />;
  if (error && !data) return <ErrorState message={error} />;

  return <>
    <div className="admin-page-title plan-page-heading">
      <div>
        <span className="eyebrow">ASSINATURA FLORIWEB</span>
        <h1>Meu plano e mensalidade</h1>
        <p>Planos, vencimento, ultimo pagamento e renovacao por PIX reunidos em uma unica pagina.</p>
      </div>
      <div className="flori-plan-heading-actions-rc66">
        <div className="current-plan-pill"><Crown size={17}/><span>Plano atual</span><strong>{planUsage.plan.name}</strong></div>
        <button className="secondary-button" onClick={() => void load()}><RefreshCw size={16}/>Atualizar</button>
      </div>
    </div>

    {error && <div className="form-error">{error}</div>}

    {data && subscription?.billingState !== 'trial' && subscription?.billingState !== 'none' && (
      <section id="vencimento" className={`admin-card flori-billing-health-rc66 ${healthClass}`}>
        {overdue ? <AlertTriangle size={25}/> : dueSoon ? <Clock3 size={25}/> : <CheckCircle2 size={25}/>}
        <div>
          <span className="eyebrow">SITUACAO DA MENSALIDADE</span>
          <h2>{healthTitle}</h2>
          <p>{healthDescription}</p>
        </div>
        <strong>{overdue && daysOverdue > 0 ? `${daysOverdue} dia(s) em atraso` : dueSoon && daysToDue !== undefined ? (daysToDue === 0 ? 'Vence hoje' : `${daysToDue} dia(s)`) : `Dia ${configuredDueDay || '---'}`}</strong>
      </section>
    )}

    {data && (
      <section className="admin-card flori-current-plan-rc65">
        <div>
          <span>PLANO ATUAL</span>
          <h2>{data.currentPlan?.name || planUsage.plan.name}</h2>
          <strong>{currency.format(subscription?.billingAmount ?? data.currentPlan?.monthlyPrice ?? planUsage.plan.monthlyPrice ?? 0)}/mes</strong>
        </div>
        <div className="flori-subscription-meta-rc65">
          <span><CalendarDays size={17}/><small>Dia de vencimento</small><strong>{subscription?.dueDay ? `Dia ${subscription.dueDay}` : '---'}</strong></span>
          <span><Clock3 size={17}/><small>Proximo vencimento</small><strong>{dateBr(subscription?.nextDueDate)}</strong></span>
          <span><ReceiptText size={17}/><small>Ultimo pagamento</small><strong>{dateBr(lastPaid?.paidAt)}</strong></span>
        </div>
      </section>
    )}

    {data && (
      <section className="admin-card flori-last-payment-rc65">
        <div className="admin-card__header">
          <div><span className="eyebrow">ULTIMO PAGAMENTO</span><h2>{lastPaid ? 'Mensalidade confirmada' : 'Nenhum pagamento confirmado ainda'}</h2></div>
          <ReceiptText/>
        </div>
        {lastPaid ? (
          <div className="flori-last-payment-grid-rc65">
            <span><small>Plano</small><strong>{lastPaid.requestedPlanName || lastPaid.planName || data.currentPlan?.name || '---'}</strong></span>
            <span><small>Valor</small><strong>{currency.format(lastPaid.amount)}</strong></span>
            <span><small>Pago em</small><strong>{dateTimeBr(lastPaid.paidAt)}</strong></span>
            <span><small>Vencimento da referencia</small><strong>{dateBr(lastPaid.dueDate)}</strong></span>
            <span><small>Proximo vencimento</small><strong>{dateBr(subscription?.nextDueDate)}</strong></span>
            <span><small>Cobranca</small><strong>#{lastPaid.id.slice(0, 8)}</strong></span>
          </div>
        ) : <p>Quando o Admin Master confirmar a primeira mensalidade, os dados do pagamento aparecerao aqui.</p>}
      </section>
    )}

    {lastRejected && (!lastPaid || new Date(lastRejected.createdAt).getTime() > new Date(lastPaid.createdAt).getTime()) && (
      <section className="admin-card flori-last-rejection-rc65">
        <AlertTriangle size={21}/>
        <div>
          <strong>Ultima renovacao nao foi confirmada</strong>
          <p>{lastRejected.rejectionReason || 'O Admin Master marcou a cobranca como nao renovada.'}</p>
          <small>Analisado em {dateTimeBr(lastRejected.rejectedAt || lastRejected.createdAt)} - referencia {dateBr(lastRejected.dueDate)}</small>
        </div>
      </section>
    )}

    <section className="admin-card plan-core-card flori-plan-core-rc66">
      <div>
        <span className="eyebrow">ESCOLHA E RENOVACAO</span>
        <h2>Compare o plano e gere o PIX sem sair desta pagina</h2>
        <p>A alteracao so passa a valer depois da conferencia do comprovante pelo Admin Master.</p>
      </div>
    </section>

    <div className="customer-plan-grid flori-plan-grid-rc66">
      {sorted.map((plan) => {
        const current = plan.id === planUsage.plan.id || plan.code === planUsage.plan.code;
        const recommended = plan.code === 'PRO';
        return <article className={`customer-plan-card ${recommended ? 'recommended' : ''} ${current ? 'current' : ''}`} key={plan.id}>
          <div className="customer-plan-card__top">
            <div><span className="eyebrow">{plan.code}</span><h2>{plan.name}</h2></div>
            {current ? <span className="customer-plan-badge current"><Check size={14}/>Seu plano</span> : recommended ? <span className="customer-plan-badge"><Sparkles size={14}/>Recomendado</span> : null}
          </div>
          <div className="customer-plan-price"><strong>{currency.format(plan.monthlyPrice ?? 0)}</strong><span>/mes</span></div>
          <div className="customer-plan-features">
            {planFeatures(plan).map(({ label, icon: Icon }) => <div key={label}><Icon size={17}/><span>{label}</span></div>)}
          </div>
          <div className="customer-plan-footer flori-plan-card-action-rc66">
            {current && <strong>Seu plano atual</strong>}
            <button className={current ? 'secondary-button' : 'primary-button'} disabled={Boolean(busy) || pending?.requestedPlanId === plan.id} onClick={() => void request(plan.id)}>
              <WalletCards size={16}/>{busy === plan.id ? 'Gerando PIX...' : current ? 'Renovar com PIX' : `Mudar para ${plan.name}`}
            </button>
          </div>
        </article>;
      })}

      <article className="customer-plan-card business-anchor">
        <div className="customer-plan-card__top">
          <div><span className="eyebrow">SOB MEDIDA</span><h2>Business</h2></div>
          <span className="customer-plan-badge business"><Crown size={14}/>Projeto personalizado</span>
        </div>
        <div className="customer-plan-price"><span className="price-prefix">a partir de</span><strong>R$ 349,90</strong><span>/mes</span></div>
        <div className="customer-plan-features">
          <div><Globe2 size={17}/><span>Multiunidade e dominios especiais</span></div>
          <div><BarChart3 size={17}/><span>Relatorios e processos sob medida</span></div>
          <div><Puzzle size={17}/><span>Integracoes com ERP, financeiro e APIs</span></div>
          <div><Users size={17}/><span>Equipe, permissoes e fluxos personalizados</span></div>
          <div><Headphones size={17}/><span>Acompanhamento tecnico dedicado</span></div>
        </div>
        <div className="customer-plan-footer"><span>Contratacao feita diretamente com o suporte FloriWeb conforme o escopo.</span></div>
      </article>
    </div>

    <section className="admin-card flori-payment-simple-rc66">
      <WalletCards size={22}/>
      <div><h2>Pagamento simples por PIX</h2><p>O valor vem do plano cadastrado. Depois do pagamento, envie o comprovante pelo WhatsApp e aguarde a confirmacao do Admin Master.</p></div>
      <span>Conferencia manual</span>
    </section>

    {pending && data && (
      <section id="pagamento-pix" className="admin-card flori-payment-card flori-payment-card-rc66">
        <div className="admin-card__header">
          <div><span className="eyebrow">PAGAMENTO PENDENTE</span><h2>{pending.paymentIntent === 'plan_change' ? 'Alteracao de plano' : 'Renovacao da mensalidade'}</h2></div>
          <WalletCards/>
        </div>
        <div className="flori-payment-value"><span>Valor</span><strong>{currency.format(pending.amount)}</strong></div>
        <div className="flori-pending-reference-rc65"><CalendarDays size={16}/><span>Vencimento da referencia: <strong>{dateBr(pending.dueDate)}</strong></span></div>
        {pixFor(pending) ? (
          <>
            <label>PIX Copia e Cola</label>
            <div className="flori-copy-row"><textarea readOnly value={pixFor(pending)}/><button onClick={() => void navigator.clipboard.writeText(pixFor(pending))}><Clipboard size={16}/>Copiar PIX</button></div>
          </>
        ) : <div className="form-error">Cadastre uma Chave PIX valida ou PIX Copia e Cola base no Admin Master.</div>}
        <div className="flori-proof-step">
          <MessageCircle/>
          <div><strong>Comprovante obrigatorio</strong><p>Abra o WhatsApp, anexe o comprovante e aguarde a conferencia do Admin Master.</p></div>
          <button className="primary-button" onClick={() => void proof(pending)}>{pending.status === 'proof_sent' ? <><CheckCircle2 size={16}/>Comprovante informado</> : <>Enviar comprovante no WhatsApp</>}</button>
        </div>
      </section>
    )}

    <section className="admin-card flori-billing-note">
      <Sparkles/>
      <div><strong>Vencimento preservado</strong><p>O pagamento confirmado registra a data real da confirmacao. O proximo vencimento continua seguindo o dia configurado pelo Admin Master.</p></div>
    </section>

    {data && data.payments.length > 0 && (
      <section className="admin-card flori-payment-history-rc65">
        <div className="admin-card__header"><div><span className="eyebrow">HISTORICO RECENTE</span><h2>Ultimas cobrancas</h2></div></div>
        <div>
          {data.payments.slice(0, 5).map((payment) => (
            <div className="flori-payment-history-row-rc65" key={payment.id}>
              <span><strong>{payment.paymentIntent === 'plan_change' ? 'Alteracao de plano' : 'Mensalidade'}</strong><small>#{payment.id.slice(0, 8)} - referencia {dateBr(payment.dueDate)}</small></span>
              <span>{currency.format(payment.amount)}</span>
              <b className={`status-${payment.status}`}>{statusLabel(payment.status)}</b>
            </div>
          ))}
        </div>
      </section>
    )}
  </>;
}
