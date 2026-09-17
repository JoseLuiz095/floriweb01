import { MessageCircle } from 'lucide-react';
import { useEffect, useState } from 'react';
import { loadAdminSupportContact } from '../services/supportApi';

type PlatformHelpButtonProps = {
  context?: 'admin' | 'master' | 'store';
  storeName?: string | null;
};

export default function PlatformHelpButton({
  context = 'admin',
  storeName,
}: PlatformHelpButtonProps) {
  const [phone, setPhone] = useState('');

  useEffect(() => {
    let active = true;

    void loadAdminSupportContact()
      .then((value) => {
        if (active) setPhone(value);
      })
      .catch(() => undefined);

    return () => {
      active = false;
    };
  }, []);

  if (!phone) return null;

  const normalized =
    (phone.length === 10 || phone.length === 11) && !phone.startsWith('55')
      ? `55${phone}`
      : phone;

  const storeReference = storeName?.trim() ? ` ${storeName.trim()}` : '';
  const message = encodeURIComponent(
    context === 'store'
      ? `Olá! Preciso de suporte com a loja${storeReference} no FloriWeb.`
      : context === 'master'
        ? 'Olá! Preciso de suporte com a administração do FloriWeb.'
        : 'Olá! Sou lojista e preciso de suporte com o FloriWeb.',
  );

  return (
    <a
      className="flori-help-fab flori-admin-only-help"
      href={`https://wa.me/${normalized}?text=${message}`}
      target="_blank"
      rel="noreferrer"
      aria-label="Abrir suporte do FloriWeb no WhatsApp"
    >
      <MessageCircle size={21} />
      <span>Suporte</span>
    </a>
  );
}
