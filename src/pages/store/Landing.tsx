import { ArrowRight, BarChart3, Check, Flower2, Gift, Heart, MapPin, MessageCircle, ShieldCheck, ShoppingBag, Sparkles, Store } from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';
import ProtectedContactButton from '../../components/ProtectedContactButton';
import { loadPublicLanding, type BillingPlan, type PublicLanding } from '../../services/billingFinanceApi';
import { InteractiveShowcase } from '../../components/marketing/InteractiveShowcase';
import { ExistingValueSection } from '../../components/marketing/ExistingValueSection';

const money=(value:number)=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(value);
const fallback:PublicLanding={demoStoreSlug:'floriweb-demo',demoEnabled:true,demoDurationDays:14,contactProtected:true,stores:[],plans:[{id:'basic',code:'BASIC',name:'Essencial',monthlyPrice:39.9},{id:'pro',code:'PRO',name:'Profissional',monthlyPrice:69.9},{id:'premium',code:'PREMIUM',name:'Premium',monthlyPrice:119.9}]};

type PlanMarketingContent={
  eyebrow:string;
  description:string;
  idealFor:string;
  features:string[];
  contactLabel:string;
  intent:'trial'|'commercial';
};

const planMarketingContent:Record<string,PlanMarketingContent>={
  BASIC:{
    eyebrow:'PARA COMEÇAR',
    description:'Uma vitrine profissional para organizar produtos, pedidos, entrega e atendimento sem deixar a operação mais complicada.',
    idealFor:'Floriculturas menores que querem começar a vender online com uma apresentação profissional e fluxo de pedido organizado.',
    features:[
      'Até 15 produtos ativos',
      'Até 5 categorias e 10 adicionais',
      'Até 3 fotos por produto',
      'Catálogo online profissional',
      'Pedidos estruturados antes do WhatsApp',
      'Entrega programada e retirada',
      'Mensagem personalizada no cartão',
    ],
    contactLabel:'Quero saber sobre o Essencial',
    intent:'commercial',
  },
  PRO:{
    eyebrow:'MAIS INDICADO',
    description:'O plano Profissional combina a experiência de venda da floricultura com ferramentas de acompanhamento comercial e financeiro para uma gestão mais completa.',
    idealFor:'Floriculturas em operação que querem vender melhor, acompanhar resultados e administrar catálogo, pedidos e financeiro no mesmo painel.',
    features:[
      'Até 40 produtos ativos',
      'Até 15 categorias e 40 adicionais',
      'Até 6 fotos por produto',
      'Catálogo, pedidos e WhatsApp integrados',
      'Entrega programada, retirada e mensagem no cartão',
      'Analytics comercial para acompanhar desempenho',
      'Financeiro gerencial com entradas e despesas',
      'Leitura local de documentos financeiros',
      'Acompanhamento de recebimento dos pedidos',
      'Suporte prioritário ao lojista',
    ],
    contactLabel:'Quero testar por 14 dias',
    intent:'trial',
  },
  PREMIUM:{
    eyebrow:'OPERAÇÃO CONSOLIDADA',
    description:'Mais capacidade de catálogo, presença de marca e recursos para floriculturas que já possuem uma operação digital mais madura.',
    idealFor:'Operações com catálogo maior, maior volume de produtos e necessidade de domínio próprio e mais capacidade de apresentação.',
    features:[
      'Tudo do plano Profissional',
      'Até 100 produtos ativos',
      'Categorias e adicionais sem limite definido',
      'Até 10 fotos por produto',
      'Domínio próprio incluído',
      'Analytics comercial liberado',
      'Financeiro gerencial completo',
      'Suporte prioritário ao lojista',
    ],
    contactLabel:'Quero falar sobre o Premium',
    intent:'commercial',
  },
};

const getPlanContent=(plan:BillingPlan,trialDays:number):PlanMarketingContent=>{
  if(plan.code==='PRO')return {...planMarketingContent.PRO,contactLabel:`Quero testar por ${trialDays} dias`};
  return planMarketingContent[plan.code]??{
    eyebrow:plan.code,
    description:'Recursos para profissionalizar a vitrine, organizar pedidos e simplificar a rotina da floricultura.',
    idealFor:'Floriculturas que procuram uma operação digital mais organizada.',
    features:['Catálogo online profissional','Pedidos organizados','Atendimento integrado ao WhatsApp'],
    contactLabel:`Quero falar sobre o ${plan.name}`,
    intent:'commercial',
  };
};

export default function Landing(){
  const[data,setData]=useState<PublicLanding>(fallback);
  useEffect(()=>{void loadPublicLanding().then(setData).catch(()=>undefined)},[]);
  const demo=useMemo(()=>data.stores.find((store)=>store.slug===data.demoStoreSlug)||data.stores[0],[data]);
  const demoHref=`/${encodeURIComponent(data.demoStoreSlug)}`;
  const trialDays=data.demoEnabled?data.demoDurationDays:14;
  return <div className="flori-sales-page flori-sales-page-v62 flori-sales-page-v63 flori-sales-page-v615">
    <header className="flori-sales-nav"><a href="/" className="flori-sales-brand"><Flower2/><strong>FloriWeb</strong></a><nav><a href="#recursos">Recursos</a><a href="#demonstracao">Demonstração</a><a href="#lojas">Floriculturas</a><a href="#planos">Planos</a></nav><div><a href="/admin/login">Entrar</a><a className="flori-sales-primary" href="/cadastro?plan=DEMO">Criar conta e testar {trialDays} dias</a></div></header>
    <main>
      <section className="flori-sales-hero flori-sales-hero-v62"><div className="flori-sales-hero-copy-v62"><span><Sparkles size={16}/> Feito para floriculturas que querem vender melhor</span><h1>Sua floricultura merece uma vitrine que <em>valorize cada detalhe.</em></h1><p>Venda presentes com catálogo elegante, entrega programada, mensagem no cartão, pedidos diretos, Analytics e Financeiro em uma plataforma feita para floriculturas.</p><div className="flori-sales-actions"><a className="flori-sales-primary flori-trial-cta" href="/cadastro?plan=DEMO">Criar conta e testar por {trialDays} dias</a><a href="#demonstracao">Ver demonstração interativa <ArrowRight size={18}/></a></div><div className="flori-sales-proof"><span><Check/>Sua marca em destaque</span><span><Check/>Pedido direto no WhatsApp</span><span><ShieldCheck/>Contato comercial protegido</span></div></div>
        <div className="flori-hero-preview-v62"><div className="flori-hero-preview-cover" style={demo?.heroUrl?{backgroundImage:`url(${demo.heroUrl})`}:{backgroundImage:'url(/assets/hero.svg)'}}><span>Vitrine da sua floricultura</span></div><div className="flori-hero-store-card"><img src={demo?.logoUrl||'/assets/logo.svg'} alt=""/><div><small>DEMONSTRAÇÃO</small><h3>{demo?.name||'Jardim da Vila Floricultura'}</h3><p>{demo?.description||'Flores e presentes em uma experiência digital elegante.'}</p></div><a href={demoHref}>Abrir <ArrowRight size={15}/></a></div><div className="flori-hero-product-row"><article><img src="/assets/bouquet-aurora.svg" alt=""/><span>Buquê Aurora</span><strong>R$ 189,90</strong></article><article><img src="/assets/rosas-doze.svg" alt=""/><span>12 Rosas</span><strong>R$ 169,90</strong></article><article><img src="/assets/cesta-afeto.svg" alt=""/><span>Cesta Afeto</span><strong>R$ 219,90</strong></article></div></div>
      </section>
      <section id="recursos" className="flori-sales-benefits flori-sales-benefits-v62"><div className="flori-sales-heading"><span>DA VITRINE À GESTÃO</span><h2>Tudo para profissionalizar a floricultura sem virar um ERP complicado.</h2><p>Uma experiência elegante para o cliente e uma rotina objetiva para quem administra.</p></div><div className="flori-sales-benefit-grid flori-benefit-grid-v62"><article><Gift/><h3>Catálogo que encanta</h3><p>Fotos, categorias, presentes e entrega com apresentação que valoriza o produto.</p></article><article><ShoppingBag/><h3>Pedidos organizados</h3><p>O cliente monta o pedido e a floricultura recebe tudo estruturado.</p></article><article><BarChart3/><h3>Analytics comercial</h3><p>Entenda interesse, carrinho e oportunidades de conversão.</p></article><article><ShieldCheck/><h3>Suporte reservado ao lojista</h3><p>O WhatsApp de suporte da plataforma só aparece depois do login do Admin/Master.</p></article></div></section>
      <ExistingValueSection variant="flori"/>

      <InteractiveShowcase variant="flori" demoHref={demoHref}/>
      <section id="lojas" className="flori-sales-stores"><div className="flori-sales-heading"><span>FLORICULTURAS NA PLATAFORMA</span><h2>Conheça vitrines publicadas no FloriWeb.</h2></div>{data.stores.length?<div className="flori-store-grid">{data.stores.map((store)=><a href={`/${store.slug}`} key={store.id}><div className="flori-store-cover" style={store.heroUrl?{backgroundImage:`url(${store.heroUrl})`}:undefined}/><div><img src={store.logoUrl||'/assets/logo.svg'} alt=""/><section><h3>{store.name}</h3><p>{store.description}</p><span><MapPin size={13}/>{[store.city,store.state].filter(Boolean).join(' · ')}</span></section></div><strong>Visitar loja <ArrowRight size={15}/></strong></a>)}</div>:<p className="flori-sales-empty"><Store/>As lojas publicadas aparecerão aqui automaticamente.</p>}</section>
      <section id="planos" className="flori-sales-plans flori-sales-plans-v62 flori-sales-plans-v615"><div className="flori-sales-heading"><span>PLANOS</span><h2>Planos acessíveis para começar e recursos que acompanham o crescimento da floricultura.</h2><p>Compare a capacidade de cada opção. O Profissional pode ser testado por {trialDays} dias antes da assinatura.</p></div><div className="flori-plan-grid flori-plan-grid-v615">{data.plans.filter((plan)=>plan.code!=='DEMO').map((plan)=>{const recommended=plan.code==='PRO';const content=getPlanContent(plan,trialDays);return <article key={plan.id} className={recommended?'recommended':''}>{recommended&&<b>Teste por {trialDays} dias</b>}<div className="flori-plan-header-v615"><small>{content.eyebrow}</small><h3>{plan.name}</h3><strong>{money(plan.monthlyPrice)} <span>/ mês</span></strong><p className="flori-plan-description-v615">{content.description}</p><div className="flori-plan-fit-v615"><strong>Indicado para:</strong><span>{content.idealFor}</span></div></div><ul>{content.features.map((feature)=><li key={`${plan.id}-${feature}`}><Check/>{feature}</li>)}</ul><ProtectedContactButton className={`flori-plan-contact-v615 ${recommended?'flori-plan-contact-v615--featured':''}`} intent={content.intent}><MessageCircle size={16}/>{content.contactLabel}</ProtectedContactButton></article>})}<article className="flori-business-plan-rc610 flori-business-plan-v615"><b>SOB MEDIDA</b><small>BUSINESS</small><h3>Business</h3><strong>Sob consulta <span>· valor definido pelo projeto</span></strong><p className="flori-plan-description-v615">Uma solução desenhada para operações que precisam de integrações, automações ou processos além dos planos padronizados.</p><div className="flori-plan-fit-v615 flori-plan-fit-v615--dark"><strong>Indicado para:</strong><span>redes, multiunidades e floriculturas com processos próprios ou necessidades específicas de integração.</span></div><ul><li><Check/>Domínio próprio incluído</li><li><Check/>Multiunidade e processos personalizados</li><li><Check/>Integrações com ERP, financeiro e APIs</li><li><Check/>Automações e módulos sob medida</li><li><Check/>Acompanhamento técnico dedicado</li></ul><ProtectedContactButton className="flori-plan-contact-v615 flori-plan-contact-v615--dark" intent="commercial"><MessageCircle size={16}/>Quero avaliar um projeto Business</ProtectedContactButton></article></div><p className="flori-plan-note"><ShieldCheck/>O telefone comercial não fica exposto na landing e é liberado apenas após validação anti-robô.</p></section>
      <section className="flori-sales-final flori-sales-final-v62 flori-sales-final-v615"><Heart/><div><span>PRONTO PARA CONVERSAR?</span><h2>Encontre o plano certo para a rotina da sua floricultura.</h2><p>O contato público é protegido e o suporte técnico permanece reservado aos lojistas autenticados.</p></div><ProtectedContactButton className="flori-sales-final-button-rc64 flori-sales-final-contact-v615" intent="commercial"><MessageCircle size={17}/>Entrar em contato no WhatsApp</ProtectedContactButton></section>
    </main>
    <footer className="flori-sales-footer"><span><Flower2/>FloriWeb</span><p>Catálogo, pedidos e gestão para floriculturas.</p><div><a href="/admin/login">Painel da loja</a><a href="/admin-master/login">Admin Master</a></div></footer>
  </div>;
}
