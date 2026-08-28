import type { Addon, Category, DeliveryZone, Order, Plan, Product, StoreSettings, StoreSubscription } from '../types';

const STORE_ID = '00000000-0000-4000-8000-000000000001';

export const seedCategories: Category[] = [
  { id: '10000000-0000-4000-8000-000000000001', storeId: STORE_ID, name: 'Buquês', slug: 'buques', active: true, sortOrder: 10 },
  { id: '10000000-0000-4000-8000-000000000002', storeId: STORE_ID, name: 'Rosas', slug: 'rosas', active: true, sortOrder: 20 },
  { id: '10000000-0000-4000-8000-000000000003', storeId: STORE_ID, name: 'Flores variadas', slug: 'flores-variadas', active: true, sortOrder: 30 },
  { id: '10000000-0000-4000-8000-000000000004', storeId: STORE_ID, name: 'Presentes', slug: 'presentes', active: true, sortOrder: 40 },
  { id: '10000000-0000-4000-8000-000000000005', storeId: STORE_ID, name: 'Casamentos', slug: 'casamentos', active: true, sortOrder: 50 },
];



const linharesZones: Array<[string, string[], number, number]> = [
  ['Alphaville', [], 10, 10],
  ['Araçá', [], 8, 20],
  ['Aviso', [], 10, 30],
  ['Bebedouro', ['Bebedouro (bairro/distrito integrado)'], 14, 40],
  ['Betânia', ['Vila Betânea', 'Vila Betania'], 10, 50],
  ['Boa Vista', [], 10, 60],
  ['Canivete', [], 12, 70],
  ['Centro', [], 8, 80],
  ['Colina', [], 9, 90],
  ['Conceição', ['Nossa Senhora da Conceição', 'Nossa Senhora da Conceicao'], 9, 100],
  ['Farias', ['Farias (área urbana)', 'Farias (area urbana)'], 12, 110],
  ['Gaivotas', [], 10, 120],
  ['Interlagos', [], 10, 130],
  ['Jardim Laguna', ['Jardim Laguna I', 'Jardim Laguna II', 'Jardim Laguna (I e II)'], 10, 140],
  ['Jocafe', ['Jocafe I', 'Jocafe II', 'Jocafe (I e II)'], 10, 150],
  ['José Rodrigues Maciel', ['Jose Rodrigues Maciel'], 10, 160],
  ['Juparanã', ['Juparana'], 10, 170],
  ['Lagoa do Meio', [], 10, 180],
  ['Linhares V', [], 12, 190],
  ['Movelar', ['Mobrasa', 'Movelar (incluindo Mobrasa)'], 10, 200],
  ['Nova Esperança', ['Nova Esperanca'], 10, 210],
  ['Novo Horizonte', [], 10, 220],
  ['Olaria', [], 9, 230],
  ['Palmital', [], 10, 240],
  ['Planalto', [], 10, 250],
  ['Residencial Rio Doce', [], 12, 260],
  ['Rio Quartel', ['Rio Quartel (área urbana)', 'Rio Quartel (area urbana)'], 14, 270],
  ['Santa Cruz', [], 10, 280],
  ['Shell', ['Pó do Shell', 'Po do Shell', 'Shell (incluindo Pó do Shell)'], 9, 290],
  ['Três Barras', ['Tres Barras'], 10, 300],
  ['Vila Isabel', [], 10, 310],
];

export const seedDeliveryZones: DeliveryZone[] = linharesZones.map(([name, aliases, fee, sortOrder], index) => ({
  id: `50000000-0000-4000-8000-${String(index + 1).padStart(12, '0')}`,
  storeId: STORE_ID,
  name,
  aliases,
  city: 'Linhares',
  state: 'ES',
  fee,
  active: true,
  sortOrder,
}));

export const seedAddons: Addon[] = [
  { id: '20000000-0000-4000-8000-000000000001', storeId: STORE_ID, name: 'Chocolate 90g', description: 'Chocolate para acompanhar o presente.', price: 18, active: true, imageUrl: '/assets/cesta-afeto.svg' },
  { id: '20000000-0000-4000-8000-000000000002', storeId: STORE_ID, name: 'Cartão especial', description: 'Cartão premium com mensagem personalizada.', price: 8, active: true, imageUrl: '/assets/bouquet-aurora-2.svg' },
  { id: '20000000-0000-4000-8000-000000000003', storeId: STORE_ID, name: 'Mini pelúcia', description: 'Mini pelúcia para complementar o presente.', price: 29.9, active: true, imageUrl: '/assets/box-carinho.svg' },
  { id: '20000000-0000-4000-8000-000000000004', storeId: STORE_ID, name: 'Caneca personalizada', description: 'Caneca para composição de cestas.', price: 34.9, active: true, imageUrl: '/assets/lirio-encanto.svg' },
];

const product = (input: Partial<Product> & Pick<Product, 'id' | 'slug' | 'name' | 'description' | 'categoryId' | 'price' | 'imageUrl'>): Product => ({
  storeId: STORE_ID,
  promotionalPrice: undefined,
  gallery: [input.imageUrl],
  images: [{ id: `${input.id}-img-1`, productId: input.id, url: input.imageUrl, sortOrder: 0, isPrimary: true, altText: input.name }],
  featured: false,
  active: true,
  madeToOrder: false,
  productionDays: 0,
  stockStatus: 'available',
  variations: [],
  addons: [],
  ...input,
});

export const seedProducts: Product[] = [
  product({
    id: '30000000-0000-4000-8000-000000000001', slug: 'buque-aurora', name: 'Buquê Aurora',
    description: 'Composição alegre com flores selecionadas em tons vibrantes. Ideal para aniversários, agradecimentos e momentos especiais.',
    categoryId: seedCategories[0].id, price: 149.9, promotionalPrice: 129.9,
    imageUrl: '/assets/bouquet-aurora.svg', gallery: ['/assets/bouquet-aurora.svg', '/assets/bouquet-aurora-2.svg'],
    images: [
      { id: '31000000-0000-4000-8000-000000000001', productId: '30000000-0000-4000-8000-000000000001', url: '/assets/bouquet-aurora.svg', sortOrder: 0, isPrimary: true, altText: 'Buquê Aurora' },
      { id: '31000000-0000-4000-8000-000000000002', productId: '30000000-0000-4000-8000-000000000001', url: '/assets/bouquet-aurora-2.svg', sortOrder: 1, isPrimary: false, altText: 'Buquê Aurora - detalhe' },
    ],
    featured: true, stockLabel: 'Disponível hoje',
    variations: [
      { id: '32000000-0000-4000-8000-000000000001', name: 'Clássico', priceDelta: 0, active: true, sortOrder: 10 },
      { id: '32000000-0000-4000-8000-000000000002', name: 'Premium', priceDelta: 35, active: true, sortOrder: 20 },
      { id: '32000000-0000-4000-8000-000000000003', name: 'Luxo', priceDelta: 70, active: true, sortOrder: 30 },
    ],
    addons: seedAddons.slice(0, 3),
  }),
  product({
    id: '30000000-0000-4000-8000-000000000002', slug: 'lirio-encanto', name: 'Lírio Encanto',
    description: 'Arranjo delicado com lírios e folhagens, montado em embalagem de acabamento premium.',
    categoryId: seedCategories[2].id, price: 119.9, imageUrl: '/assets/lirio-encanto.svg', featured: true,
    variations: [
      { id: '32000000-0000-4000-8000-000000000004', name: 'Branco', priceDelta: 0, active: true, sortOrder: 10 },
      { id: '32000000-0000-4000-8000-000000000005', name: 'Rosa', priceDelta: 0, active: true, sortOrder: 20 },
    ], addons: seedAddons.slice(0, 2),
  }),
  product({
    id: '30000000-0000-4000-8000-000000000003', slug: 'rosas-doze', name: '12 Rosas Clássicas',
    description: 'Doze rosas frescas com folhagens e acabamento elegante para surpreender em qualquer ocasião.',
    categoryId: seedCategories[1].id, price: 169.9, imageUrl: '/assets/rosas-doze.svg', stockLabel: 'Últimas unidades', stockStatus: 'low_stock',
    variations: [
      { id: '32000000-0000-4000-8000-000000000006', name: 'Vermelhas', priceDelta: 0, active: true, sortOrder: 10 },
      { id: '32000000-0000-4000-8000-000000000007', name: 'Rosas', priceDelta: 0, active: true, sortOrder: 20 },
      { id: '32000000-0000-4000-8000-000000000008', name: 'Brancas', priceDelta: 0, active: true, sortOrder: 30 },
    ],
  }),
  product({
    id: '30000000-0000-4000-8000-000000000004', slug: 'box-carinho', name: 'Box Carinho',
    description: 'Flores, chocolates e uma apresentação pronta para presentear. Uma escolha prática e marcante.',
    categoryId: seedCategories[3].id, price: 189.9, imageUrl: '/assets/box-carinho.svg', featured: true,
    variations: [
      { id: '32000000-0000-4000-8000-000000000009', name: 'Tradicional', priceDelta: 0, active: true, sortOrder: 10 },
      { id: '32000000-0000-4000-8000-000000000010', name: 'Com pelúcia', priceDelta: 35, active: true, sortOrder: 20 },
    ],
  }),
  product({
    id: '30000000-0000-4000-8000-000000000005', slug: 'buque-noiva-classico', name: 'Buquê de Noiva Clássico',
    description: 'Buquê personalizado para casamento, desenvolvido de acordo com referências, paleta de cores e estilo da cerimônia.',
    categoryId: seedCategories[4].id, price: 320, imageUrl: '/assets/noiva-classico.svg',
    gallery: ['/assets/noiva-classico.svg', '/assets/noiva-classico-2.svg'],
    images: [
      { id: '31000000-0000-4000-8000-000000000003', productId: '30000000-0000-4000-8000-000000000005', url: '/assets/noiva-classico.svg', sortOrder: 0, isPrimary: true, altText: 'Buquê de noiva clássico' },
      { id: '31000000-0000-4000-8000-000000000004', productId: '30000000-0000-4000-8000-000000000005', url: '/assets/noiva-classico-2.svg', sortOrder: 1, isPrimary: false, altText: 'Buquê de noiva clássico - detalhe' },
    ],
    madeToOrder: true, productionDays: 10,
    variations: [
      { id: '32000000-0000-4000-8000-000000000011', name: 'Buquê', priceDelta: 0, active: true, sortOrder: 10 },
      { id: '32000000-0000-4000-8000-000000000012', name: 'Lapela', priceDelta: -240, active: true, sortOrder: 20 },
      { id: '32000000-0000-4000-8000-000000000013', name: 'Grinalda', priceDelta: -180, active: true, sortOrder: 30 },
    ],
  }),
  product({ id: '30000000-0000-4000-8000-000000000006', slug: 'girassol-luz', name: 'Girassol Luz', description: 'Composição vibrante de girassóis com folhagens naturais e embalagem kraft.', categoryId: seedCategories[2].id, price: 109.9, imageUrl: '/assets/girassol-luz.svg', variations: [{ id: '32000000-0000-4000-8000-000000000014', name: '3 girassóis', priceDelta: 0, active: true, sortOrder: 10 }, { id: '32000000-0000-4000-8000-000000000015', name: '6 girassóis', priceDelta: 55, active: true, sortOrder: 20 }] }),
  product({ id: '30000000-0000-4000-8000-000000000007', slug: 'rosa-unitaria-premium', name: 'Rosa Unitária Premium', description: 'Uma rosa selecionada com acabamento refinado e cartão para uma lembrança elegante.', categoryId: seedCategories[1].id, price: 39.9, imageUrl: '/assets/rosa-unitaria.svg', variations: [{ id: '32000000-0000-4000-8000-000000000016', name: 'Vermelha', priceDelta: 0, active: true, sortOrder: 10 }, { id: '32000000-0000-4000-8000-000000000017', name: 'Rosa', priceDelta: 0, active: true, sortOrder: 20 }, { id: '32000000-0000-4000-8000-000000000018', name: 'Champagne', priceDelta: 0, active: true, sortOrder: 30 }] }),
  product({ id: '30000000-0000-4000-8000-000000000008', slug: 'cesta-afeto', name: 'Cesta Afeto', description: 'Cesta com flores, doces e itens delicadamente organizados para presentear com afeto.', categoryId: seedCategories[3].id, price: 219.9, imageUrl: '/assets/cesta-afeto.svg', addons: [seedAddons[1], seedAddons[3]] }),
];

export const seedSettings: StoreSettings = {
  id: STORE_ID,
  slug: 'floriweb-demo',
  name: 'Jardim da Vila Floricultura',
  tagline: 'Flores que transformam momentos em lembranças.',
  description: 'Floricultura de demonstração do FloriWeb.',
  city: 'Linhares', state: 'ES', zipCode: '', whatsapp: '5527999999999', instagram: '@jardimdavila',
  address: 'Centro, Linhares - ES', logoUrl: '/assets/logo.svg', heroUrl: '/assets/hero.svg',
  pixEnabled: true, pixReceiptMode: 'copy_paste', pixKeyType: 'E-mail', pixKey: 'demo@floriweb.local', pixCopyPaste: '00020126410014BR.GOV.BCB.PIX0119demo@floriweb.local5204000053039865802BR5914JARDIM DA VILA6008LINHARES62070503***6304715B', pixReceiver: 'Jardim da Vila Floricultura',
  showPixBeforeConfirmation: true, confirmationPaymentEnabled: false, cardPaymentEnabled: true, cashPaymentEnabled: true, paymentMethodOrder: ['pix', 'card', 'cash', 'confirm'], deliveryEnabled: true, pickupEnabled: true, minimumOrder: 0,
  openingHours: 'Seg 08:00–18:00 · Ter 08:00–18:00 · Qua 08:00–18:00 · Qui 08:00–18:00 · Sex 08:00–18:00 · Sáb 08:00–14:00',
  openingSchedule: { timezone: 'America/Sao_Paulo', days: [
    { day: 0, enabled: false, open: '08:00', close: '18:00' },
    { day: 1, enabled: true, open: '08:00', close: '18:00' },
    { day: 2, enabled: true, open: '08:00', close: '18:00' },
    { day: 3, enabled: true, open: '08:00', close: '18:00' },
    { day: 4, enabled: true, open: '08:00', close: '18:00' },
    { day: 5, enabled: true, open: '08:00', close: '18:00' },
    { day: 6, enabled: true, open: '08:00', close: '14:00' },
  ] }, active: true,
};

export const seedPlan: Plan = {
  id: '40000000-0000-4000-8000-000000000001', code: 'DEMO', name: 'Demo', productLimit: 15,
  imageLimitPerProduct: 3, customDomain: false, reports: false, prioritySupport: false, active: true,
};

export const seedSubscription: StoreSubscription = {
  id: '41000000-0000-4000-8000-000000000001', storeId: STORE_ID, planId: seedPlan.id, status: 'trial',
  startedAt: new Date().toISOString(), plan: seedPlan,
};

export const seedOrders: Order[] = [];
