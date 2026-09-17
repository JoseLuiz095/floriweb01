import {
  ArrowDownCircle,
  ArrowUpCircle,
  Camera,
  FileSearch,
  Landmark,
  Loader2,
  Plus,
  Upload,
} from 'lucide-react';
import { useEffect, useMemo, useRef, useState, type FormEvent } from 'react';
import { useStore } from '../../contexts/StoreContext';
import {
  createFinancialEntry,
  loadFinancialOverview,
  type FinancialDirection,
  type FinancialOverview,
} from '../../services/billingFinanceApi';
import {
  normalizeCounterpartyKey,
  readLocalFinancialDocument,
  type LocalFinancialReadProgress,
  type LocalFinancialReadResult,
} from '../../utils/localFinancialDocumentReader';

const money = (value: number) =>
  new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(value);
const today = () => new Date().toISOString().slice(0, 10);
const expenseCategories = [
  'Flores e plantas',
  'Vasos e cachepôs',
  'Embalagens',
  'Laços e fitas',
  'Cartões',
  'Presentes e complementos',
  'Insumos florais',
  'Frete e entrega',
  'Fornecedores',
  'Funcionários',
  'Marketing',
  'Energia',
  'Água',
  'Aluguel',
  'Taxas bancárias',
  'Impostos',
  'Manutenção',
  'Outros',
];
const incomeCategories = ['Vendas', 'Outras receitas'];

export default function Finance() {
  const { settings } = useStore();
  const [data, setData] = useState<FinancialOverview | null>(null);
  const [direction, setDirection] = useState<FinancialDirection>('expense');
  const [form, setForm] = useState({
    description: '',
    category: 'Flores e plantas',
    amount: '',
    occurredOn: today(),
    dueOn: '',
    status: 'paid' as 'paid' | 'pending',
    counterparty: '',
    documentType: 'none',
    documentNumber: '',
    notes: '',
  });
  const [error, setError] = useState('');
  const [saving, setSaving] = useState(false);
  const [scanning, setScanning] = useState(false);
  const [readProgress, setReadProgress] = useState<LocalFinancialReadProgress | null>(null);
  const [readResult, setReadResult] = useState<LocalFinancialReadResult | null>(null);
  const fileRef = useRef<HTMLInputElement | null>(null);
  const cameraRef = useRef<HTMLInputElement | null>(null);

  const load = () =>
    loadFinancialOverview(settings.id)
      .then(setData)
      .catch((currentError) =>
        setError(currentError instanceof Error ? currentError.message : 'Não foi possível carregar o financeiro.'),
      );

  useEffect(() => {
    if (settings.id) void load();
  }, [settings.id]);

  const categories = direction === 'income' ? incomeCategories : expenseCategories;

  useEffect(() => {
    setForm((current) => ({ ...current, category: categories[0] }));
  }, [direction]);

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    setSaving(true);
    setError('');
    try {
      await createFinancialEntry(settings.id, {
        direction,
        description: form.description,
        category: form.category,
        amount: Number(form.amount.replace(',', '.')),
        occurredOn: form.occurredOn,
        dueOn: form.dueOn || undefined,
        status: form.status,
        counterparty: form.counterparty,
        documentType: form.documentType,
        documentNumber: form.documentNumber,
        notes: form.notes,
      });
      setForm((current) => ({
        ...current,
        description: '',
        amount: '',
        counterparty: '',
        documentNumber: '',
        notes: '',
      }));
      setReadResult(null);
      setReadProgress(null);
      await load();
    } catch (currentError) {
      setError(currentError instanceof Error ? currentError.message : 'Falha ao salvar lançamento.');
    } finally {
      setSaving(false);
    }
  };

  const readFile = async (file?: File) => {
    if (!file) return;
    setScanning(true);
    setError('');
    setReadResult(null);
    setReadProgress({ percent: 1, message: 'Preparando leitura local...' });

    try {
      const suggestion = await readLocalFinancialDocument(file, setReadProgress);
      const supplierKey = normalizeCounterpartyKey(suggestion.counterparty || '');
      const previousCategory = supplierKey
        ? data?.entries.find(
            (entry) =>
              entry.direction === direction &&
              entry.category &&
              normalizeCounterpartyKey(entry.counterparty || '') === supplierKey,
          )?.category
        : undefined;

      setForm((current) => ({
        ...current,
        description: suggestion.description || current.description,
        amount: suggestion.amount !== undefined ? String(suggestion.amount) : current.amount,
        occurredOn: suggestion.occurredOn || current.occurredOn,
        dueOn: suggestion.dueOn || current.dueOn,
        status: suggestion.documentType === 'boleto' && suggestion.dueOn ? 'pending' : current.status,
        counterparty: suggestion.counterparty || current.counterparty,
        documentType: suggestion.documentType || current.documentType,
        documentNumber: suggestion.documentNumber || current.documentNumber,
        category: previousCategory || current.category,
      }));
      setReadResult(suggestion);
    } catch (currentError) {
      setError(
        currentError instanceof Error
          ? currentError.message
          : 'Não foi possível ler o documento. Preencha manualmente.',
      );
    } finally {
      setScanning(false);
      if (fileRef.current) fileRef.current.value = '';
      if (cameraRef.current) cameraRef.current.value = '';
    }
  };

  const top = useMemo(() => data?.expenseByCategory.slice(0, 6) || [], [data]);

  return (
    <>
      <div className="admin-page-title">
        <div>
          <span className="eyebrow">FINANCEIRO</span>
          <h1>Quanto entrou, quanto saiu e quanto sobrou</h1>
          <p>Visão gerencial simples para entender resultado e principais despesas da floricultura.</p>
        </div>
      </div>

      {error && <div className="form-error">{error}</div>}

      {data && (
        <>
          <div className="flori-finance-kpis">
            <article><span>Entradas</span><strong>{money(data.income)}</strong></article>
            <article><span>Saídas</span><strong>{money(data.expense)}</strong></article>
            <article className="result"><span>Resultado gerencial</span><strong>{money(data.result)}</strong></article>
            <article><span>A receber / A pagar</span><strong>{money(data.receivable)} / {money(data.payable)}</strong></article>
          </div>

          <div className="flori-finance-grid">
            <section className="admin-card">
              <h2>Onde estou gastando?</h2>
              {top.length ? top.map((item) => (
                <div className="flori-category-spend" key={item.category}>
                  <span>{item.category}</span><strong>{money(item.amount)}</strong>
                </div>
              )) : <p>Cadastre despesas para visualizar a distribuição.</p>}
            </section>

            <section className="admin-card">
              <h2>Últimos lançamentos</h2>
              {data.entries.slice(0, 8).map((entry) => (
                <div className="flori-finance-entry" key={entry.id}>
                  <span className={entry.direction}>
                    <i>{entry.direction === 'income' ? <ArrowUpCircle /> : <ArrowDownCircle />}</i>
                    <b>{entry.description}</b>
                    <small>{entry.category} · {entry.occurredOn}</small>
                  </span>
                  <strong>{entry.direction === 'income' ? '+' : '-'} {money(entry.amount)}</strong>
                </div>
              ))}
            </section>
          </div>
        </>
      )}

      <section className="admin-card flori-finance-form">
        <div className="admin-card__header">
          <div><span className="eyebrow">NOVO LANÇAMENTO</span><h2>Cadastro rápido</h2></div>
          <Landmark />
        </div>

        <div className="flori-direction">
          <button type="button" className={direction === 'income' ? 'active income' : ''} onClick={() => setDirection('income')}>
            <ArrowUpCircle />Entrada / ganho
          </button>
          <button type="button" className={direction === 'expense' ? 'active expense' : ''} onClick={() => setDirection('expense')}>
            <ArrowDownCircle />Saída / despesa
          </button>
        </div>

        <div className="flori-document-reader-rc67">
          <div className="flori-document-reader-head-rc67">
            <div className="flori-document-reader-icon-rc67"><FileSearch size={22} /></div>
            <div>
              <span className="eyebrow">LEITURA AUTOMÁTICA</span>
              <strong>Ler nota, boleto ou cupom</strong>
              <p>Tire uma foto ou escolha um arquivo. A leitura acontece somente no navegador e sugere os campos para você revisar.</p>
            </div>
          </div>

          <div className="flori-document-actions-rc67">
            <button type="button" className="is-primary" onClick={() => cameraRef.current?.click()} disabled={scanning}>
              <Camera size={19} />
              <span><strong>Tirar foto</strong><small>Usar a câmera do celular</small></span>
            </button>
            <button type="button" onClick={() => fileRef.current?.click()} disabled={scanning}>
              <Upload size={19} />
              <span><strong>Escolher arquivo</strong><small>JPG, PNG, WEBP ou PDF</small></span>
            </button>
          </div>

          <input ref={cameraRef} hidden type="file" accept="image/*" capture="environment" aria-label="Tirar foto do documento" onChange={(event) => void readFile(event.target.files?.[0])} />
          <input ref={fileRef} hidden type="file" accept="image/jpeg,image/png,image/webp,application/pdf" aria-label="Escolher documento financeiro" onChange={(event) => void readFile(event.target.files?.[0])} />

          {readProgress && (
            <div className={`flori-local-read-status-rc67 ${scanning ? 'is-loading' : 'is-complete'}`}>
              <div className="flori-local-read-status-line-rc67">
                {scanning ? <Loader2 className="spin" size={17} /> : <FileSearch size={17} />}
                <span><strong>{scanning ? 'Lendo documento' : 'Leitura concluída'}</strong><small>{readProgress.message}</small></span>
                <b>{scanning ? `${readProgress.percent}%` : '100%'}</b>
              </div>
              {scanning && <span className="flori-local-read-progress-rc67"><i style={{ width: `${Math.max(4, readProgress.percent)}%` }} /></span>}
            </div>
          )}

          {readResult && (
            <div className="flori-local-read-result-rc67">
              <div>
                <strong>{readResult.recognizedFields} campo(s) preenchido(s)</strong>
                <span>Confiança estimada de {Math.round(readResult.confidence * 100)}%. Confira os dados antes de salvar.</span>
              </div>
              {readResult.signals.length > 0 && (
                <div className="flori-local-read-chips-rc67">
                  {readResult.signals.map((signal) => <span key={signal}>{signal}</span>)}
                </div>
              )}
            </div>
          )}

          <small className="flori-document-reader-footnote-rc67">Nenhuma imagem ou PDF é enviado para IA. Limites: imagem até 8 MB e PDF até 10 MB.</small>
        </div>

        <form onSubmit={submit} className="flori-finance-fields">
          <label>Descrição<input required value={form.description} onChange={(event) => setForm({ ...form, description: event.target.value })} /></label>
          <label>Valor<input required inputMode="decimal" value={form.amount} onChange={(event) => setForm({ ...form, amount: event.target.value })} /></label>
          <label>Categoria<select value={form.category} onChange={(event) => setForm({ ...form, category: event.target.value })}>{categories.map((category) => <option key={category}>{category}</option>)}</select></label>
          <label>Data<input type="date" required value={form.occurredOn} onChange={(event) => setForm({ ...form, occurredOn: event.target.value })} /></label>
          <label>Situação<select value={form.status} onChange={(event) => setForm({ ...form, status: event.target.value as 'paid' | 'pending' })}><option value="paid">Realizado</option><option value="pending">Pendente</option></select></label>
          <label>Fornecedor / origem<input value={form.counterparty} onChange={(event) => setForm({ ...form, counterparty: event.target.value })} /></label>
          <button className="primary-button" disabled={saving || scanning}><Plus size={16} />{saving ? 'Salvando...' : 'Salvar lançamento'}</button>
        </form>
      </section>
    </>
  );
}
