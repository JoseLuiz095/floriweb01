import { MessageCircle, Save, ShieldCheck, WalletCards } from 'lucide-react';
import { useEffect, useState, type FormEvent } from 'react';
import {
  loadMasterBilling,
  saveMasterBilling,
  type BillingSettings,
} from '../../services/billingFinanceApi';

const empty: BillingSettings = {
  pixKeyType: 'cnpj',
  pixKey: '',
  pixHolderName: '',
  pixCity: 'Linhares',
  pixCopyPaste: '',
  whatsapp: '',
  marketingWhatsapp: '',
  supportWhatsapp: '',
  proofRequired: true,
  graceDays: 3,
};

export default function Billing() {
  const [form, setForm] = useState<BillingSettings>(empty);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');

  useEffect(() => {
    void loadMasterBilling()
      .then((data) => setForm({ ...empty, ...data.settings }))
      .catch((error) => setMessage(error instanceof Error ? error.message : 'Falha ao carregar cobrança.'));
  }, []);

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    setBusy(true);
    setMessage('');
    try {
      setForm(await saveMasterBilling(form));
      setMessage('Configuração comercial e de cobrança salva.');
    } catch (error) {
      setMessage(error instanceof Error ? error.message : 'Falha ao salvar.');
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      <div className="admin-page-title">
        <div>
          <span className="eyebrow">COBRANÇA E CONTATO</span>
          <h1>PIX, vendas e suporte da plataforma</h1>
          <p>
            Configure a mensalidade por PIX e os WhatsApps que serão usados para comprovantes,
            novos interessados e ajuda aos lojistas.
          </p>
        </div>
      </div>

      <form className="admin-card flori-master-billing" onSubmit={submit}>
        <div className="admin-card__header">
          <div>
            <span className="eyebrow">MENSALIDADE</span>
            <h2>Recebimento manual por PIX</h2>
            <p>O valor de cada cobrança é obtido do plano cadastrado no banco.</p>
          </div>
          <WalletCards />
        </div>

        <div className="flori-master-billing-grid">
          <label>
            Tipo da chave
            <select value={form.pixKeyType} onChange={(event) => setForm({ ...form, pixKeyType: event.target.value })}>
              <option value="cnpj">CNPJ</option>
              <option value="cpf">CPF</option>
              <option value="email">E-mail</option>
              <option value="phone">Telefone</option>
              <option value="random">Aleatória</option>
            </select>
          </label>

          <label>
            Chave PIX
            <input required value={form.pixKey} onChange={(event) => setForm({ ...form, pixKey: event.target.value })} />
          </label>

          <label>
            Titular
            <input required value={form.pixHolderName} onChange={(event) => setForm({ ...form, pixHolderName: event.target.value })} />
          </label>

          <label>
            Cidade
            <input required maxLength={15} value={form.pixCity} onChange={(event) => setForm({ ...form, pixCity: event.target.value })} />
          </label>

          <label>
            Carência após vencimento (dias)
            <input
              type="number"
              min={0}
              max={30}
              value={form.graceDays}
              onChange={(event) => setForm({ ...form, graceDays: Number(event.target.value) })}
            />
          </label>

          <label className="span-2">
            PIX Copia e Cola base <em>opcional</em>
            <textarea
              value={form.pixCopyPaste}
              onChange={(event) => setForm({ ...form, pixCopyPaste: event.target.value })}
              placeholder="Se vazio, o FloriWeb gera o PIX usando a chave, titular, cidade e valor do plano."
            />
          </label>
        </div>

        <div className="flori-master-contact-block">
          <div className="admin-card__header">
            <div>
              <span className="eyebrow">WHATSAPP</span>
              <h2>Contato da plataforma</h2>
              <p>Você pode usar o mesmo número nos três campos ou separar financeiro, comercial e suporte.</p>
            </div>
            <MessageCircle />
          </div>

          <div className="flori-master-billing-grid">
            <label className="span-2">
              WhatsApp para comprovantes
              <input
                required
                placeholder="5527999999999"
                value={form.whatsapp}
                onChange={(event) => setForm({ ...form, whatsapp: event.target.value })}
              />
              <small>Recebe comprovantes de renovação e alteração de plano.</small>
            </label>

            <label className="span-2">
              WhatsApp comercial da página inicial <em>opcional</em>
              <input
                placeholder="5527999999999"
                value={form.marketingWhatsapp}
                onChange={(event) => setForm({ ...form, marketingWhatsapp: event.target.value })}
              />
              <small>Usado pelo contato comercial protegido da página pública. O número não é entregue ao navegador antes da validação anti-robô.</small>
            </label>

            <label className="span-2">
              WhatsApp de suporte / Ajuda <em>opcional</em>
              <input
                placeholder="5527999999999"
                value={form.supportWhatsapp}
                onChange={(event) => setForm({ ...form, supportWhatsapp: event.target.value })}
              />
              <small>Uso interno: aparece somente para Admin da floricultura e Admin Master autenticados. Se vazio, usa o financeiro como fallback interno.</small>
            </label>
          </div>
        </div>

        <label className="flori-proof-required">
          <input
            type="checkbox"
            checked={form.proofRequired}
            onChange={(event) => setForm({ ...form, proofRequired: event.target.checked })}
          />
          Exigir comprovante no WhatsApp antes da confirmação da mensalidade
        </label>

        <div className="flori-master-security-note">
          <ShieldCheck size={17} />
          <span>
            Chave PIX, telefone financeiro e telefone de suporte não são expostos na landing. O contato comercial público é liberado somente pelo servidor após Turnstile e rate limit.
          </span>
        </div>

        {message && (
          <div className={message.includes('salva') ? 'form-success' : 'form-error'}>{message}</div>
        )}

        <button className="primary-button" disabled={busy}>
          <Save size={16} />
          {busy ? 'Salvando...' : 'Salvar cobrança e contatos'}
        </button>
      </form>
    </>
  );
}
