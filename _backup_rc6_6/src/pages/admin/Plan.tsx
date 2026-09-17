import { BarChart3, Check, Crown, Globe2, Headphones, Images, Package, Puzzle, Sparkles, Tags, Users } from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';
import { ErrorState, LoadingState } from '../../components/ui/AsyncState';
import { useStore } from '../../contexts/StoreContext';
import { platformApi } from '../../services/platformApi';
import type { Plan } from '../../types';
import { currency } from '../../utils/format';

type PlanFeature = { label: string; icon: typeof Package };

const limitText = (value: number | null | undefined, singular: string, plural: string) => {
  if (value == null) return `${plural} ilimitados`;
  return `${value} ${value === 1 ? singular : plural}`;
};

const planFeatures = (plan: Plan): PlanFeature[] => [
  { label: limitText(plan.productLimit, 'produto ativo', 'produtos ativos'), icon: Package },
  { label: limitText(plan.categoryLimit, 'categoria', 'categorias'), icon: Tags },
  { label: limitText(plan.imageLimitPerProduct, 'foto por produto', 'fotos por produto'), icon: Images },
  { label: limitText(plan.addonLimit, 'adicional', 'adicionais'), icon: Puzzle },
  { label: limitText(plan.adminUserLimit, 'usuário administrativo', 'usuários administrativos'), icon: Users },
  { label: plan.customDomain ? 'Domínio próprio incluído' : 'Endereço padrão FloriWeb', icon: Globe2 },
  { label: plan.reports ? 'Relatórios comerciais' : 'Visão geral do catálogo', icon: BarChart3 },
  { label: plan.prioritySupport ? 'Suporte prioritário' : 'Suporte padrão', icon: Headphones },
];

const coreFeatures = [
  'Catálogo responsivo e página de produtos',
  'Carrinho e checkout',
  'Pedidos organizados pelo WhatsApp',
  'PIX, cartão por link e dinheiro',
  'Entrega, retirada e taxa por bairro',
  'Variações, adicionais e produtos sob encomenda',
  'Painel administrativo e recuperação de senha',
];

export default function AdminPlan() {
  const { planUsage } = useStore();
  const [plans, setPlans] = useState<Plan[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    let active = true;
    platformApi.listPlans()
      .then((rows) => { if (active) setPlans(rows.filter((plan) => plan.active && plan.code !== 'DEMO')); })
      .catch((cause) => { if (active) setError(cause instanceof Error ? cause.message : 'Não foi possível carregar os planos.'); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, []);

  const sorted = useMemo(() => [...plans].sort((a, b) => (a.sortOrder ?? 0) - (b.sortOrder ?? 0)), [plans]);

  if (loading) return <LoadingState label="Carregando planos..." />;
  if (error) return <ErrorState message={error} />;

  return <>
    <div className="admin-page-title plan-page-heading">
      <div>
        <span className="eyebrow">MEU PLANO</span>
        <h1>Plano e vantagens</h1>
        <p>Veja o que sua assinatura inclui e compare os níveis do FloriWeb sem alterar nada sozinho.</p>
      </div>
      <div className="current-plan-pill"><Crown size={17}/><span>Plano atual</span><strong>{planUsage.plan.name}</strong></div>
    </div>

    <section className="admin-card plan-core-card">
      <div>
        <span className="eyebrow">INCLUÍDO EM TODOS OS PLANOS</span>
        <h2>O essencial para vender sem complicar a operação</h2>
        <p>Os planos não removem o fluxo principal da loja. A diferença está em capacidade, gestão, relatórios, suporte e personalização.</p>
      </div>
      <div className="plan-core-grid">
        {coreFeatures.map((feature) => <span key={feature}><Check size={16}/>{feature}</span>)}
      </div>
    </section>

    <div className="customer-plan-grid">
      {sorted.map((plan) => {
        const current = plan.id === planUsage.plan.id || plan.code === planUsage.plan.code;
        const recommended = plan.code === 'PRO';
        return <article className={`customer-plan-card ${recommended ? 'recommended' : ''} ${current ? 'current' : ''}`} key={plan.id}>
          <div className="customer-plan-card__top">
            <div>
              <span className="eyebrow">{plan.code}</span>
              <h2>{plan.name}</h2>
            </div>
            {current ? <span className="customer-plan-badge current"><Check size={14}/>Seu plano</span> : recommended ? <span className="customer-plan-badge"><Sparkles size={14}/>Melhor custo-benefício</span> : null}
          </div>
          <div className="customer-plan-price"><strong>{currency.format(plan.monthlyPrice ?? 0)}</strong><span>/mês</span></div>
          {(plan.setupPrice ?? 0) > 0 && <small className="customer-plan-setup">Implantação de referência: {currency.format(plan.setupPrice ?? 0)}</small>}
          <div className="customer-plan-features">
            {planFeatures(plan).map(({label, icon: Icon}) => <div key={label}><Icon size={17}/><span>{label}</span></div>)}
          </div>
          <div className="customer-plan-footer">
            {current ? <strong>Você já possui este plano.</strong> : <span>Alterações de plano são feitas com o suporte FloriWeb para evitar cobranças ou limites incorretos.</span>}
          </div>
        </article>;
      })}

      <article className="customer-plan-card business-anchor">
        <div className="customer-plan-card__top">
          <div><span className="eyebrow">SOB MEDIDA</span><h2>Business</h2></div>
          <span className="customer-plan-badge business"><Crown size={14}/>Projeto personalizado</span>
        </div>
        <div className="customer-plan-price"><span className="price-prefix">a partir de</span><strong>R$ 349,90</strong><span>/mês</span></div>
        <small className="customer-plan-setup">Implantação e desenvolvimento conforme o escopo.</small>
        <div className="customer-plan-features">
          <div><Globe2 size={17}/><span>Multiunidade e domínios especiais</span></div>
          <div><BarChart3 size={17}/><span>Relatórios e processos sob medida</span></div>
          <div><Puzzle size={17}/><span>Integrações com ERP, financeiro e APIs</span></div>
          <div><Users size={17}/><span>Equipe, permissões e fluxos personalizados</span></div>
          <div><Headphones size={17}/><span>Acompanhamento técnico dedicado</span></div>
        </div>
        <div className="customer-plan-footer"><span>Este é um projeto personalizado, não um plano automático. O valor final depende do escopo contratado.</span></div>
      </article>
    </div>

    <section className="admin-card plan-transparency-card">
      <Sparkles size={22}/>
      <div><strong>Comparação transparente</strong><p>O plano Business funciona como referência para operações que já precisam de software sob medida. Não usamos preço riscado artificial nem desconto fictício: os planos padrão permanecem menores porque compartilham a mesma plataforma e infraestrutura.</p></div>
    </section>
  </>;
}
