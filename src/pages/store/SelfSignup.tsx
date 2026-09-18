import { ArrowLeft, Check, Clock3, Eye, EyeOff, Flower2, ShieldCheck, Store, UserPlus } from 'lucide-react';
import { useEffect, useState, type FormEvent } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { TurnstileWidget } from '../../components/ui/TurnstileWidget';
import { appConfig } from '../../lib/config';
import { loadPublicLanding, type BillingPlan } from '../../services/billingFinanceApi';
import {
  continueSelfServiceWithExistingAccount,
  createSelfServiceAccount,
  type SelfServiceSignupInput,
} from '../../services/selfServiceSignup';

const money=(value:number)=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(value);
const DEMO_PLAN:BillingPlan={id:'demo-self-service',code:'DEMO',name:'Demo 30 dias',monthlyPrice:0};
const allowedPlan=(code:string)=>['DEMO','BASIC','PRO','PREMIUM'].includes(code.toUpperCase());

export default function SelfSignup(){
  const navigate=useNavigate();
  const[searchParams]=useSearchParams();
  const[plans,setPlans]=useState<BillingPlan[]>([DEMO_PLAN]);
  const[demoDays,setDemoDays]=useState(30);
  const[demoEnabled,setDemoEnabled]=useState(true);
  const[mode,setMode]=useState<'new'|'existing'>('new');
  const[showPassword,setShowPassword]=useState(false);
  const[loading,setLoading]=useState(false);
  const[error,setError]=useState('');
  const[success,setSuccess]=useState('');
  const[captchaToken,setCaptchaToken]=useState('');
  const[captchaReset,setCaptchaReset]=useState(0);
  const[form,setForm]=useState<SelfServiceSignupInput>({
    storeName:'',ownerName:'',email:'',password:'',planCode:(searchParams.get('plan')||'DEMO').toUpperCase(),city:'',state:'',contactPhone:'',businessDocument:'',captchaToken:'',
  });

  useEffect(()=>{
    void loadPublicLanding().then((landing)=>{
      const days=landing.demoDurationDays||30;
      setDemoDays(days);setDemoEnabled(landing.demoEnabled!==false);
      const commercial=landing.plans.filter((plan)=>allowedPlan(plan.code)&&plan.code!=='DEMO');
      setPlans([...(landing.demoEnabled!==false?[{...DEMO_PLAN,name:`Demo ${days} dias`}]:[]),...commercial]);
      setForm((current)=>{
        const desired=current.planCode;
        const available=(landing.demoEnabled!==false&&desired==='DEMO')||commercial.some((plan)=>plan.code===desired);
        return {...current,planCode:available?desired:(commercial[0]?.code||'DEMO')};
      });
    }).catch(()=>undefined);
  },[]);

  const isDemo=form.planCode==='DEMO';
  const setField=<K extends keyof SelfServiceSignupInput>(key:K,value:SelfServiceSignupInput[K])=>setForm((current)=>({...current,[key]:value}));

  const submit=async(event:FormEvent)=>{
    event.preventDefault();if(loading)return;
    setError('');setSuccess('');
    if(form.storeName.trim().length<2){setError('Informe o nome da floricultura.');return;}
    if(form.ownerName.trim().length<2){setError('Informe o nome do responsável.');return;}
    if(!/^\S+@\S+\.\S+$/.test(form.email.trim())){setError('Informe um e-mail válido.');return;}
    const phoneDigits=form.contactPhone.replace(/\D/g,'');
    if(phoneDigits.length<10||phoneDigits.length>13){setError('Informe um WhatsApp comercial válido.');return;}
    const cnpjDigits=(form.businessDocument||'').replace(/\D/g,'');
    if(cnpjDigits&&cnpjDigits.length!==14){setError('O CNPJ deve ter 14 dígitos.');return;}
    if(form.password.length<8){setError('A senha deve ter pelo menos 8 caracteres.');return;}
    if(!captchaToken){setError('Conclua a verificação de segurança.');return;}

    setLoading(true);
    const input={...form,captchaToken};
    try{
      if(mode==='existing'){
        const completion=await continueSelfServiceWithExistingAccount(input);
        setSuccess(completion.existing?'Sua conta já possui uma floricultura no FloriWeb. Abrindo painel...':'Solicitação criada. Abrindo seu espaço de configuração...');
        window.setTimeout(()=>navigate('/admin/primeiros-passos',{replace:true}),700);
        return;
      }
      const result=await createSelfServiceAccount(input);
      if(result.requiresEmailConfirmation){
        setSuccess('Cadastro iniciado. Confira seu e-mail para confirmar a conta; depois a criação da floricultura será concluída automaticamente.');
      }else{
        setSuccess('Conta criada. Abrindo seu painel...');
        window.setTimeout(()=>navigate('/admin/primeiros-passos',{replace:true}),700);
      }
    }catch(e){
      setError(e instanceof Error?e.message:'Não foi possível concluir o cadastro.');
      setCaptchaReset((value)=>value+1);setCaptchaToken('');
    }finally{setLoading(false)}
  };

  return <div className="self-signup-page flori-self-signup-page">
    <header className="self-signup-topbar"><Link to="/"><ArrowLeft size={18}/>Voltar</Link><strong><Flower2 size={19}/>FloriWeb</strong><Link to="/admin/login">Entrar</Link></header>
    <main className="self-signup-shell">
      <section className="self-signup-intro">
        <span className="eyebrow">COMECE AGORA</span>
        <h1>Crie seu acesso, escolha o plano e prepare sua floricultura antes da liberação final.</h1>
        <p>Você adianta catálogo, identidade, entregas e configurações. O Admin Master revisa a solicitação e libera a vitrine quando o cadastro estiver pronto.</p>
        <div className="self-signup-rules">
          <article><Clock3/><div><strong>Demo por {demoDays} dias</strong><span>Teste gratuito sujeito à validação cadastral do negócio.</span></div></article>
          <article><Store/><div><strong>Configuração antecipada</strong><span>O painel fica disponível em modo de preparação, mesmo antes da vitrine.</span></div></article>
          <article><ShieldCheck/><div><strong>Liberação controlada</strong><span>O Admin Master pode aprovar ou rejeitar o novo cadastro.</span></div></article>
        </div>
      </section>

      <section className="self-signup-card">
        <div className="self-signup-mode">
          <button type="button" className={mode==='new'?'active':''} onClick={()=>{setMode('new');setError('')}}>Criar nova conta</button>
          <button type="button" className={mode==='existing'?'active':''} onClick={()=>{setMode('existing');setError('')}}>Já tenho conta</button>
        </div>
        <form onSubmit={submit}>
          <div className="self-signup-heading"><UserPlus size={22}/><div><h2>{mode==='new'?'Novo cadastro':'Usar uma conta existente'}</h2><p>{mode==='new'?'Você poderá confirmar o e-mail antes da criação final.':'Entre com o usuário já existente e conclua a solicitação.'}</p></div></div>
          <label>Nome da floricultura<input required value={form.storeName} onChange={(e)=>setField('storeName',e.target.value)} placeholder="Ex.: Flores da Vila"/></label>
          <div className="self-signup-grid"><label>Responsável<input required value={form.ownerName} onChange={(e)=>setField('ownerName',e.target.value)} placeholder="Seu nome"/></label><label>Cidade<input value={form.city||''} onChange={(e)=>setField('city',e.target.value)} placeholder="Cidade"/></label></div>
          <div className="self-signup-grid"><label>E-mail<input required type="email" autoComplete="email" value={form.email} onChange={(e)=>setField('email',e.target.value)} placeholder="voce@floricultura.com"/></label><label>UF<input maxLength={2} value={form.state||''} onChange={(e)=>setField('state',e.target.value.toUpperCase())} placeholder="ES"/></label></div>
          <div className="self-signup-grid"><label>WhatsApp comercial<input required inputMode="tel" value={form.contactPhone} onChange={(e)=>setField('contactPhone',e.target.value)} placeholder="(27) 99999-9999"/></label><label>CNPJ <small>(opcional)</small><input inputMode="numeric" value={form.businessDocument||''} onChange={(e)=>setField('businessDocument',e.target.value)} placeholder="00.000.000/0001-00"/></label></div>
          <label>Senha<div className="self-signup-password"><input required minLength={8} type={showPassword?'text':'password'} autoComplete={mode==='new'?'new-password':'current-password'} value={form.password} onChange={(e)=>setField('password',e.target.value)} placeholder="Mínimo de 8 caracteres"/><button type="button" onClick={()=>setShowPassword((value)=>!value)} aria-label="Mostrar ou ocultar senha">{showPassword?<EyeOff size={18}/>:<Eye size={18}/>}</button></div></label>

          <fieldset className="self-signup-plans"><legend>Escolha seu plano</legend>{plans.map((plan)=><label key={plan.code} className={form.planCode===plan.code?'selected':''}><input type="radio" name="plan" value={plan.code} checked={form.planCode===plan.code} onChange={()=>setField('planCode',plan.code)}/><div><strong>{plan.name}</strong><span>{plan.code==='DEMO'?`${demoDays} dias gratuitos`:`${money(plan.monthlyPrice)} / mês`}</span></div>{form.planCode===plan.code&&<Check size={18}/>}</label>)}</fieldset>

          {isDemo&&demoEnabled&&<div className="self-signup-notice"><Clock3 size={17}/><span>O período gratuito começa após a liberação do Admin Master. A elegibilidade é verificada pelos dados cadastrais do negócio.</span></div>}
          {!isDemo&&<div className="self-signup-notice"><ShieldCheck size={17}/><span>Você poderá preparar a floricultura, mas a vitrine continuará indisponível até o Admin Master liberar o cadastro.</span></div>}

          {appConfig.turnstileSiteKey?<TurnstileWidget siteKey={appConfig.turnstileSiteKey} action="signup" onToken={setCaptchaToken} resetSignal={captchaReset}/>:<div className="form-error">Turnstile não configurado neste build. O auto cadastro permanece bloqueado por segurança.</div>}
          {error&&<div className="form-error">{error}</div>}
          {success&&<div className="form-success self-signup-success">{success}</div>}
          <button className="primary-button self-signup-submit" disabled={loading||!appConfig.turnstileSiteKey||!captchaToken}>{loading?'Processando...':mode==='new'?'Criar conta e continuar':'Entrar e solicitar acesso'}</button>
          <small className="self-signup-footnote">Ao continuar, você solicita a criação de um ambiente FloriWeb. A liberação pública depende da revisão do Admin Master.</small>
        </form>
      </section>
    </main>
  </div>;
}
