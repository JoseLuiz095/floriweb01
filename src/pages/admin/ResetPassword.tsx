import { CheckCircle2, Eye, EyeOff, Flower2, LockKeyhole } from 'lucide-react';
import { useMemo, useState, type FormEvent } from 'react';
import { Link } from 'react-router-dom';
import { recoveryTokenFromLocation, updatePasswordWithRecoveryToken } from '../../lib/supabaseRest';
import { temporaryPasswordValidationMessage } from '../../utils/email';

export default function ResetPassword() {
  const token = useMemo(() => recoveryTokenFromLocation(), []);
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [show, setShow] = useState(false);
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState('');

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    if (busy) return;
    setError('');
    const passwordError = temporaryPasswordValidationMessage(password);
    if (passwordError) { setError(passwordError); return; }
    if (password !== confirmPassword) { setError('As senhas informadas não são iguais.'); return; }
    setBusy(true);
    try {
      await updatePasswordWithRecoveryToken(token, password);
      setDone(true);
      window.history.replaceState({}, document.title, '/admin/redefinir-senha');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Não foi possível redefinir a senha.');
    } finally { setBusy(false); }
  };

  return <div className="auth-recovery-page">
    <div className="auth-recovery-brand"><Flower2 size={27}/><strong>FloriWeb</strong></div>
    <main className="auth-recovery-card">
      {done ? <>
        <div className="auth-success-icon"><CheckCircle2 size={30}/></div>
        <span className="eyebrow">SENHA ATUALIZADA</span>
        <h1>Seu acesso está pronto</h1>
        <p>A nova senha foi salva. Você já pode voltar ao painel administrativo.</p>
        <Link className="primary-button full-button" to="/admin/login">Entrar no FloriWeb</Link>
      </> : <form onSubmit={submit}>
        <span className="eyebrow">NOVA SENHA</span>
        <h1>Crie uma nova senha</h1>
        <p>Use pelo menos 10 caracteres, com maiúscula, minúscula e número. Evite reutilizar a senha de outros serviços.</p>
        {!token && <div className="form-error">Link de recuperação inválido ou expirado. Solicite um novo link.</div>}
        <label className="auth-field">Nova senha<div className="input-with-icon"><LockKeyhole size={18}/><input required minLength={10} value={password} onChange={(event)=>setPassword(event.target.value)} type={show?'text':'password'} autoComplete="new-password"/><button type="button" onClick={()=>setShow((value)=>!value)} aria-label="Mostrar ou ocultar senha">{show?<EyeOff size={18}/>:<Eye size={18}/>}</button></div></label>
        <label className="auth-field">Confirmar nova senha<div className="input-with-icon"><LockKeyhole size={18}/><input required minLength={10} value={confirmPassword} onChange={(event)=>setConfirmPassword(event.target.value)} type={show?'text':'password'} autoComplete="new-password"/></div></label>
        {error && <div className="form-error">{error}</div>}
        <button className="primary-button full-button" disabled={busy||!token} type="submit">{busy?'Alterando...':'Alterar senha'}</button>
        {!token && <Link className="text-link auth-recovery-new-link" to="/admin/esqueci-senha">Solicitar outro link</Link>}
      </form>}
    </main>
  </div>;
}
