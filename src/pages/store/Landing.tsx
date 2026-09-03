import {
  ArrowRight,
  BarChart3,
  Check,
  Flower2,
  Gift,
  Heart,
  Landmark,
  MapPin,
  MessageCircle,
  PackageCheck,
  ShieldCheck,
  ShoppingBag,
  Sparkles,
  Store,
  WalletCards,
} from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';
import PlatformHelpButton from '../../components/PlatformHelpButton';
import { loadPublicLanding, type BillingPlan, type PublicLanding } from '../../services/billingFinanceApi';

const money = (value: number) =>
  new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(value);

const fallback: PublicLanding = {
  demoStoreSlug: 'floriweb-demo',
  demoEnabled: true,
  demoDurationDays: 30,
  marketingWhatsapp: '',
  supportWhatsapp: '',
  stores: [],
  plans: [
    { id: 'basic', code: 'BASIC', name: 'Essencial', monthlyPrice: 49.9 },
    { id: 'pro', code: 'PRO', name: 'Profissional', monthlyPrice: 89.9 },
    { id: 'premium', code: 'PREMIUM', name: 'Premium', monthlyPrice: 149.9 },
  ],
};

const waUrl = (phone: string, message: string) => {
  const digits = phone.replace(/\D/g, '');
  if (!digits) return '#planos';
  const normalized = digits.startsWith('55') ? digits : `55${digits}`;
  return `https://wa.me/${normalized}?text=${encodeURIComponent(message)}`;
};

const planCopy = (plan: BillingPlan) => {
  if (plan.code === 'BASIC') return 'Catálogo profissional, pedidos e WhatsApp para sair do PDF.';
  if (plan.code === 'PRO') return 'Analytics e Financeiro para entender vendas, despesas e resultado.';
  return 'Mais capacidade, gestão e estrutura para uma operação que já cresceu.';
};

export default function Landing() {
  const [data, setData] = useState<PublicLanding>(fallback);

  useEffect(() => {
    void loadPublicLanding().then(setData).catch(() => undefined);
  }, []);

  const demo = useMemo(
    () => data.stores.find((store) => store.slug === data.demoStoreSlug) || data.stores[0],
    [data],
  );
  const demoHref = `/${encodeURIComponent(data.demoStoreSlug)}`;
  const trialDays = data.demoEnabled ? data.demoDurationDays : 30;
  const salesPhone = data.marketingWhatsapp || data.supportWhatsapp;
  const trialMessage = `Olá! Tenho interesse em testar o Plano Profissional do FloriWeb por ${trialDays} dias para minha floricultura. Gostaria de saber como ativar a demonstração.`;
  const trialHref = waUrl(salesPhone, trialMessage);

  const interestUrl = (plan: BillingPlan) =>
    waUrl(
      salesPhone,
      `Olá! Tenho interesse no plano ${plan.name} do FloriWeb (${money(plan.monthlyPrice)}/mês). Gostaria de saber como começar.`,
    );

  return (
    <div className="flori-sales-page flori-sales-page-v62">
      <header className="flori-sales-nav">
        <a href="/" className="flori-sales-brand">
          <Flower2 />
          <strong>FloriWeb</strong>
        </a>
        <nav>
          <a href="#recursos">Recursos</a>
          <a href="#demonstracao">Demonstração</a>
          <a href="#lojas">Floriculturas</a>
          <a href="#planos">Planos</a>
        </nav>
        <div>
          <a href="/admin/login">Entrar</a>
          <a
            className="flori-sales-primary"
            href={trialHref}
            target={salesPhone ? '_blank' : undefined}
            rel={salesPhone ? 'noreferrer' : undefined}
          >
            Teste por {trialDays} dias
          </a>
        </div>
      </header>

      <main>
        <section className="flori-sales-hero flori-sales-hero-v62">
          <div className="flori-sales-hero-copy-v62">
            <span><Sparkles size={16} /> Feito para floriculturas que querem vender melhor</span>
            <h1>
              Sua floricultura merece uma vitrine que <em>valorize cada detalhe.</em>
            </h1>
            <p>
              Catálogo digital, pedidos diretos, entrega, WhatsApp, Analytics, Financeiro e mensalidade por PIX em uma plataforma com identidade própria para o seu negócio.
            </p>
            <div className="flori-sales-actions">
              <a
                className="flori-sales-primary flori-trial-cta"
                href={trialHref}
                target={salesPhone ? '_blank' : undefined}
                rel={salesPhone ? 'noreferrer' : undefined}
              >
                <MessageCircle size={18} /> Testar o Profissional por {trialDays} dias
              </a>
              <a href={demoHref}>Ver uma loja funcionando <ArrowRight size={18} /></a>
            </div>
            <div className="flori-sales-proof">
              <span><Check /> Sua marca em destaque</span>
              <span><Check /> Pedido direto no WhatsApp</span>
              <span><Check /> Suporte humano</span>
            </div>
          </div>

          <div className="flori-hero-preview-v62">
            <div
              className="flori-hero-preview-cover"
              style={demo?.heroUrl ? { backgroundImage: `url(${demo.heroUrl})` } : { backgroundImage: 'url(/assets/hero.svg)' }}
            >
              <span>Vitrine da sua floricultura</span>
            </div>
            <div className="flori-hero-store-card">
              <img src={demo?.logoUrl || '/assets/logo.svg'} alt="" />
              <div>
                <small>DEMONSTRAÇÃO</small>
                <h3>{demo?.name || 'Jardim da Vila Floricultura'}</h3>
                <p>{demo?.description || 'Flores e presentes para transformar momentos especiais.'}</p>
              </div>
              <a href={demoHref}>Abrir <ArrowRight size={15} /></a>
            </div>
            <div className="flori-hero-product-row">
              <article><img src="/assets/bouquet-aurora.svg" alt="Buquê de demonstração" /><span>Buquê Aurora</span><strong>R$ 189,90</strong></article>
              <article><img src="/assets/rosas-doze.svg" alt="Rosas de demonstração" /><span>12 Rosas</span><strong>R$ 169,90</strong></article>
              <article><img src="/assets/cesta-afeto.svg" alt="Cesta de demonstração" /><span>Cesta Afeto</span><strong>R$ 219,90</strong></article>
            </div>
          </div>
        </section>

        <section id="recursos" className="flori-sales-benefits flori-sales-benefits-v62">
          <div className="flori-sales-heading">
            <span>DA VITRINE À GESTÃO</span>
            <h2>Tudo para profissionalizar a floricultura sem virar um ERP complicado.</h2>
            <p>Uma experiência elegante para o cliente e uma rotina objetiva para quem administra.</p>
          </div>
          <div className="flori-sales-benefit-grid flori-benefit-grid-v62">
            <article><Gift /><h3>Catálogo que encanta</h3><p>Fotos, categorias, presentes, adicionais e entrega com uma apresentação que aumenta a percepção de valor.</p></article>
            <article><ShoppingBag /><h3>Pedidos organizados</h3><p>O cliente monta o pedido online e a floricultura recebe tudo estruturado antes do contato pelo WhatsApp.</p></article>
            <article><BarChart3 /><h3>Analytics comercial</h3><p>Entenda o que chama atenção, o que entra no carrinho e onde existem oportunidades de conversão.</p></article>
            <article><Landmark /><h3>Financeiro gerencial</h3><p>Entradas, saídas, despesas por categoria e resultado gerencial de forma simples para o dia a dia.</p></article>
          </div>
        </section>

        <section id="demonstracao" className="flori-product-tour-v62">
          <div className="flori-sales-heading">
            <span>VEJA O QUE VOCÊ VAI USAR</span>
            <h2>Uma plataforma visual para vender, atender e entender o negócio.</h2>
          </div>
          <div className="flori-tour-grid-v62">
            <article className="flori-tour-storefront">
              <div className="flori-tour-window-head"><i /><i /><i /><span>floriweb.com.br/sua-floricultura</span></div>
              <div className="flori-tour-storefront-body">
                <img src="/assets/bouquet-aurora-2.svg" alt="Produto floral" />
                <div><small>COLEÇÃO ESPECIAL</small><h3>Buquê Aurora</h3><p>Uma vitrine pensada para transformar produto em presente.</p><strong>R$ 189,90</strong><button>Adicionar ao carrinho</button></div>
              </div>
              <footer><span>Catálogo online</span><span>Entrega</span><span>WhatsApp</span></footer>
            </article>

            <div className="flori-tour-modules">
              <article><PackageCheck /><div><small>PEDIDOS</small><h3>Atendimento mais organizado</h3><p>Visualize os pedidos e os dados do cliente sem depender de mensagens soltas.</p></div></article>
              <article><BarChart3 /><div><small>ANALYTICS</small><h3>Descubra o que desperta interesse</h3><div className="flori-mini-chart"><i /><i /><i /><i /><i /></div></div></article>
              <article><Landmark /><div><small>FINANCEIRO</small><h3>Quanto entrou, saiu e sobrou?</h3><div className="flori-mini-finance"><span>Entradas <b>R$ 18.450</b></span><span>Saídas <b>R$ 11.280</b></span><span>Resultado <b>R$ 7.170</b></span></div></div></article>
              <article><WalletCards /><div><small>MENSALIDADE</small><h3>PIX Copia e Cola</h3><p>Renovação ou troca de plano com comprovante enviado ao WhatsApp.</p></div></article>
            </div>
          </div>
          <div className="flori-tour-cta">
            <div><strong>Experimente antes de decidir</strong><span>Use a experiência do Profissional por {trialDays} dias.</span></div>
            <a
              href={trialHref}
              target={salesPhone ? '_blank' : undefined}
              rel={salesPhone ? 'noreferrer' : undefined}
            >
              <MessageCircle size={17} /> Quero testar agora
            </a>
          </div>
        </section>

        <section id="lojas" className="flori-sales-stores">
          <div className="flori-sales-heading">
            <span>FLORICULTURAS NA PLATAFORMA</span>
            <h2>Conheça vitrines publicadas no FloriWeb.</h2>
          </div>
          {data.stores.length ? (
            <div className="flori-store-grid">
              {data.stores.map((store) => (
                <a href={`/${store.slug}`} key={store.id}>
                  <div className="flori-store-cover" style={store.heroUrl ? { backgroundImage: `url(${store.heroUrl})` } : undefined} />
                  <div>
                    <img src={store.logoUrl || '/assets/logo.svg'} alt="" loading="lazy" decoding="async" />
                    <section>
                      <h3>{store.name}</h3>
                      <p>{store.description}</p>
                      <span><MapPin size={13} />{[store.city, store.state].filter(Boolean).join(' · ')}</span>
                    </section>
                  </div>
                  <strong>Visitar loja <ArrowRight size={15} /></strong>
                </a>
              ))}
            </div>
          ) : (
            <p className="flori-sales-empty"><Store /> As lojas publicadas aparecerão aqui automaticamente.</p>
          )}
        </section>

        <section id="planos" className="flori-sales-plans flori-sales-plans-v62">
          <div className="flori-sales-heading">
            <span>PLANOS</span>
            <h2>Comece com o necessário e evolua quando fizer sentido.</h2>
            <p>O teste de {trialDays} dias permite conhecer a experiência antes da assinatura.</p>
          </div>
          <div className="flori-plan-grid">
            {data.plans.filter((plan) => plan.code !== 'DEMO').map((plan) => {
              const recommended = plan.code === 'PRO';
              return (
                <article key={plan.id} className={recommended ? 'recommended' : ''}>
                  {recommended && <b>Teste por {trialDays} dias</b>}
                  <small>{plan.code}</small>
                  <h3>{plan.name}</h3>
                  <strong>{money(plan.monthlyPrice)} <span>/ mês</span></strong>
                  <p className="flori-plan-description">{planCopy(plan)}</p>
                  <ul>
                    <li><Check /> Catálogo online profissional</li>
                    <li><Check /> Pedidos e WhatsApp</li>
                    <li><Check /> Produtos e entregas</li>
                    {plan.code !== 'BASIC' && <li><Check /> Analytics comercial</li>}
                    {['PRO', 'PREMIUM'].includes(plan.code) && <li><Check /> Financeiro gerencial</li>}
                  </ul>
                  <a
                    href={recommended ? trialHref : interestUrl(plan)}
                    target={salesPhone ? '_blank' : undefined}
                    rel={salesPhone ? 'noreferrer' : undefined}
                  >
                    <MessageCircle size={15} /> {recommended ? `Testar por ${trialDays} dias` : `Tenho interesse no ${plan.name}`}
                  </a>
                </article>
              );
            })}
          </div>
          <p className="flori-plan-note">
            <ShieldCheck /> Mensalidade por PIX Copia e Cola, com comprovante enviado ao WhatsApp cadastrado no Admin Master.
          </p>
        </section>

        <section className="flori-sales-final flori-sales-final-v62">
          <Heart />
          <div>
            <span>PRONTO PARA COMEÇAR?</span>
            <h2>Mostre seus produtos com a mesma atenção que você coloca em cada presente.</h2>
            <p>Fale diretamente conosco e ative uma demonstração acompanhada do FloriWeb.</p>
          </div>
          <a
            href={trialHref}
            target={salesPhone ? '_blank' : undefined}
            rel={salesPhone ? 'noreferrer' : undefined}
          >
            <MessageCircle size={17} /> Quero usar o FloriWeb
          </a>
        </section>
      </main>

      <footer className="flori-sales-footer">
        <span><Flower2 /> FloriWeb</span>
        <p>Catálogo, pedidos e gestão para floriculturas.</p>
        <div><a href="/admin/login">Painel da loja</a><a href="/admin-master/login">Admin Master</a></div>
      </footer>

      <PlatformHelpButton context="landing" />
    </div>
  );
}
