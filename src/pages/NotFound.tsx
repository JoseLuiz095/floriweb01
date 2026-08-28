import { Home, SearchX } from 'lucide-react';
export default function NotFound(){return <div className="not-found"><SearchX size={48}/><span className="eyebrow">404</span><h1>Página não encontrada</h1><p>O endereço informado não existe no FloriWeb.</p><a className="primary-button" href="/"><Home size={17}/>Voltar para a loja</a></div>}
