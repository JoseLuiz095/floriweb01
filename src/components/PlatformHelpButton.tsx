import { MessageCircle } from 'lucide-react';
import { useEffect, useState } from 'react';
import { loadPublicLanding } from '../services/billingFinanceApi';

type Props = {
  context?: 'landing' | 'store';
  storeName?: string;
};

const waUrl = (phone: string, message: string) => {
  const digits = phone.replace(/\D/g, '');
  if (!digits) return '';
  const normalized = digits.startsWith('55') ? digits : `55${digits}`;
  return `https://wa.me/${normalized}?text=${encodeURIComponent(message)}`;
};

export default function PlatformHelpButton({ context = 'store', storeName }: Props) {
  const [phone, setPhone] = useState('');

  useEffect(() => {
    let active = true;
    void loadPublicLanding()
      .then((data) => {
        if (active) setPhone(data.supportWhatsapp || data.marketingWhatsapp);
      })
      .catch(() => undefined);
    return () => {
      active = false;
    };
  }, []);

  if (!phone) return null;

  const message = context === 'landing'
    ? 'Olá! Preciso de ajuda e gostaria de saber mais sobre o FloriWeb.'
    : `Olá! Preciso de ajuda com o FloriWeb${storeName ? ` na floricultura ${storeName}` : ''}. Pode me atender?`;

  return (
    <a
      className="flori-help-fab"
      href={waUrl(phone, message)}
      target="_blank"
      rel="noreferrer"
      aria-label="Pedir ajuda pelo WhatsApp"
    >
      <MessageCircle size={21} />
      <span>Ajuda</span>
    </a>
  );
}
