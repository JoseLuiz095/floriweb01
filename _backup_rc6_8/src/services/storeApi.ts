import { appConfig, isDemoMode } from '../lib/config';
import { invokePublicFunction, restFetch, storageDelete, storageUpload, SupabaseHttpError } from '../lib/supabaseRest';
import { seedAddons, seedCategories, seedDeliveryZones, seedOrders, seedPlan, seedProducts, seedSettings } from '../data/seed';
import type { Addon, CartItem, Category, CheckoutData, CheckoutSecurityContext, CreateOrderResult, DeliveryZone, Order, PaymentMethod, Plan, PlanUsage, Product, ProductImage, StoreSettings } from '../types';
import { addDaysLocalISO, formatDateBR, roundMoney, slugify } from '../utils/format';
import { formatOpeningSchedule, normalizeOpeningSchedule } from '../utils/storeHours';
import { createId } from '../utils/id';


export class StorefrontUnavailableError extends Error {
  storeName: string;
  constructor(storeName: string) {
    super('Esta floricultura está temporariamente indisponível.');
    this.name = 'StorefrontUnavailableError';
    this.storeName = storeName;
  }
}

type StorefrontStatus = { found: boolean; id?: string; slug?: string; name?: string; status?: 'online' | 'unavailable' };

type PublicStorefrontRpc = {
  found: boolean;
  status?: 'online' | 'unavailable';
  store?: StoreRow | { id: string; slug: string; name: string };
  categories?: CategoryRow[];
  products?: ProductRow[];
  product_images?: ProductImageRow[];
  product_variants?: ProductVariantRow[];
  addons?: AddonRow[];
  product_addons?: ProductAddonRow[];
  delivery_zones?: DeliveryZoneRow[];
};

export type StoreSnapshot = {
  settings: StoreSettings;
  categories: Category[];
  products: Product[];
  addons: Addon[];
  deliveryZones: DeliveryZone[];
  orders: Order[];
  planUsage: PlanUsage;
};

const DEMO_KEY = 'floriweb_demo_database_v2_6';

type DemoDatabase = StoreSnapshot;

type StoreRow = {
  id: string; slug: string; name: string; description: string | null; logo_url: string | null; logo_storage_path: string | null;
  cover_url: string | null; cover_storage_path: string | null; whatsapp: string | null; instagram: string | null; address: string | null;
  city: string | null; state: string | null; zip_code: string | null; delivery_enabled: boolean; pickup_enabled: boolean;
  pix_enabled: boolean; pix_receipt_mode: 'copy_paste'|'key' | null; pix_key_type: string | null; pix_key: string | null; pix_copy_paste: string | null; pix_holder_name: string | null; show_pix_before_confirmation: boolean; confirmation_payment_enabled: boolean; card_payment_enabled: boolean; cash_payment_enabled: boolean; payment_method_order: unknown;
  minimum_order: number | string; opening_hours: unknown; active: boolean; access_status?: 'online'|'suspended';
};
type CategoryRow = { id: string; store_id: string; name: string; slug: string; description: string | null; active: boolean; sort_order: number };
type ProductRow = { id: string; store_id: string; category_id: string; name: string; slug: string; description: string; price: number | string; promotional_price: number | string | null; active: boolean; featured: boolean; made_to_order: boolean; production_days: number | null; stock_status: Product['stockStatus'] };
type ProductImageRow = { id: string; product_id: string; url: string; storage_path: string | null; alt_text: string | null; sort_order: number; is_primary: boolean };
type ProductVariantRow = { id: string; product_id: string; name: string; price_delta: number | string; active: boolean; sort_order: number };
type AddonRow = { id: string; store_id: string; name: string; description: string | null; price: number | string; active: boolean; image_url: string | null; image_storage_path: string | null };
type DeliveryZoneRow = { id: string; store_id: string; name: string; aliases: string[] | null; city: string; state: string; fee: number | string; active: boolean; sort_order: number };
type ProductAddonRow = { product_id: string; addon_id: string };
type PlanRow = { id: string; code: string; name: string; product_limit: number | null; image_limit_per_product: number | null; custom_domain: boolean; reports: boolean; priority_support: boolean; monthly_price: number | string | null; setup_price: number | string | null; category_limit: number | null; addon_limit: number | null; admin_user_limit: number | null; sort_order: number | null; active: boolean };
type SubscriptionRow = { id: string; store_id: string; plan_id: string; status: 'trial' | 'active' | 'suspended' | 'cancelled'; started_at: string; expires_at: string | null };
type StoreDomainRow = { store_id: string; domain: string; active: boolean; is_primary: boolean };
type OrderRow = { id: string; order_number?: number | string | null; store_id: string; customer_name: string; customer_phone: string | null; customer_email?: string | null; delivery_type: 'delivery'|'pickup'; desired_date: string; desired_period: string | null; recipient_name: string | null; recipient_phone?: string | null; delivery_address: string | null; delivery_zip_code?: string | null; delivery_street?: string | null; delivery_number?: string | null; delivery_complement?: string | null; delivery_neighborhood?: string | null; delivery_zone_id?: string | null; delivery_zone_name?: string | null; delivery_fee?: number | string | null; delivery_city?: string | null; delivery_state?: string | null; reference_point?: string | null; card_message: string | null; card_signature?: string | null; anonymous_sender?: boolean | null; notes: string | null; payment_method: string; subtotal: number|string; total: number|string; status: Order['status']; whatsapp_clicked_at: string | null; created_at: string };

const toNumber = (value: number | string | null | undefined) => value == null ? 0 : Number(value);

const normalizePaymentOrder = (value: unknown): PaymentMethod[] => {
  const allowed: PaymentMethod[] = ['confirm', 'pix', 'card', 'cash'];
  const input = Array.isArray(value) ? value : [];
  const filtered = input.filter((method): method is PaymentMethod => typeof method === 'string' && allowed.includes(method as PaymentMethod));
  return [...filtered, ...allowed.filter((method) => !filtered.includes(method))];
};

const mapStore = (r: StoreRow): StoreSettings => ({
  id: r.id, slug: r.slug, name: r.name, tagline: r.description || 'Flores para momentos especiais.', description: r.description || undefined,
  city: r.city || '', state: r.state || '', zipCode: r.zip_code || '', whatsapp: r.whatsapp || '', instagram: r.instagram || '', address: r.address || '',
  logoUrl: r.logo_url || '/assets/logo.svg', logoStoragePath: r.logo_storage_path || undefined,
  heroUrl: r.cover_url || '/assets/hero.svg', heroStoragePath: r.cover_storage_path || undefined,
  pixEnabled: r.pix_enabled, pixReceiptMode: r.pix_receipt_mode || 'key', pixKeyType: r.pix_key_type || '', pixKey: r.pix_key || '', pixCopyPaste: r.pix_copy_paste || '', pixReceiver: r.pix_holder_name || '',
  showPixBeforeConfirmation: r.show_pix_before_confirmation, confirmationPaymentEnabled: r.confirmation_payment_enabled ?? true, cardPaymentEnabled: r.card_payment_enabled ?? false, cashPaymentEnabled: r.cash_payment_enabled ?? false, paymentMethodOrder: normalizePaymentOrder(r.payment_method_order), deliveryEnabled: r.delivery_enabled, pickupEnabled: r.pickup_enabled,
  minimumOrder: toNumber(r.minimum_order), openingSchedule: normalizeOpeningSchedule(r.opening_hours), openingHours: (() => { const schedule=normalizeOpeningSchedule(r.opening_hours); const legacy=typeof r.opening_hours === 'string' ? r.opening_hours : ((r.opening_hours as { display?: string } | null)?.display || ''); return schedule.days.some((d)=>d.enabled) ? formatOpeningSchedule(schedule) : legacy; })(), active: r.active, accessStatus: r.access_status || 'online',
});
const mapCategory = (r: CategoryRow): Category => ({ id: r.id, storeId: r.store_id, name: r.name, slug: r.slug, description: r.description || undefined, active: r.active, sortOrder: r.sort_order });
const mapAddon = (r: AddonRow): Addon => ({ id: r.id, storeId: r.store_id, name: r.name, description: r.description || undefined, price: toNumber(r.price), active: r.active, imageUrl: r.image_url || undefined, imageStoragePath: r.image_storage_path || undefined });
const mapDeliveryZone = (r: DeliveryZoneRow): DeliveryZone => ({ id: r.id, storeId: r.store_id, name: r.name, aliases: r.aliases || [], city: r.city, state: r.state, fee: toNumber(r.fee), active: r.active, sortOrder: r.sort_order });
const mapPlan = (r: PlanRow): Plan => ({ id: r.id, code: r.code, name: r.name, productLimit: r.product_limit, imageLimitPerProduct: r.image_limit_per_product, customDomain: r.custom_domain, reports: r.reports, prioritySupport: r.priority_support, monthlyPrice:toNumber(r.monthly_price), setupPrice:toNumber(r.setup_price), categoryLimit:r.category_limit, addonLimit:r.addon_limit, adminUserLimit:r.admin_user_limit, sortOrder:r.sort_order ?? 0, active: r.active });
const mapOrder = (r: OrderRow): Order => ({ id: r.id, orderNumber: toNumber(r.order_number), storeId: r.store_id, customerName: r.customer_name, customerPhone: r.customer_phone || undefined, customerEmail: r.customer_email || undefined, deliveryType: r.delivery_type, desiredDate: r.desired_date, desiredPeriod: r.desired_period || undefined, recipientName: r.recipient_name || undefined, recipientPhone: r.recipient_phone || undefined, deliveryAddress: r.delivery_address || undefined, deliveryZipCode: r.delivery_zip_code || undefined, deliveryStreet: r.delivery_street || undefined, deliveryNumber: r.delivery_number || undefined, deliveryComplement: r.delivery_complement || undefined, deliveryNeighborhood: r.delivery_neighborhood || undefined, deliveryZoneId: r.delivery_zone_id || undefined, deliveryZoneName: r.delivery_zone_name || undefined, deliveryFee: toNumber(r.delivery_fee), deliveryCity: r.delivery_city || undefined, deliveryState: r.delivery_state || undefined, referencePoint: r.reference_point || undefined, cardMessage: r.card_message || undefined, cardSignature: r.card_signature || undefined, anonymousSender: r.anonymous_sender ?? undefined, notes: r.notes || undefined, paymentMethod: (r.payment_method as PaymentMethod), subtotal: toNumber(r.subtotal), total: toNumber(r.total), status: r.status, whatsappClickedAt: r.whatsapp_clicked_at || undefined, createdAt: r.created_at });

const buildProducts = (rows: ProductRow[], images: ProductImageRow[], variants: ProductVariantRow[], addons: Addon[], links: ProductAddonRow[]): Product[] => rows.map((r) => {
  const productImages: ProductImage[] = images.filter((i) => i.product_id === r.id).sort((a,b)=>a.sort_order-b.sort_order).map((i)=>({ id:i.id, productId:i.product_id, url:i.url, storagePath:i.storage_path || undefined, altText:i.alt_text || undefined, sortOrder:i.sort_order, isPrimary:i.is_primary }));
  const primary = productImages.find((image)=>image.isPrimary) || productImages[0];
  const productAddonIds = new Set(links.filter((link)=>link.product_id===r.id).map((link)=>link.addon_id));
  return {
    id:r.id, storeId:r.store_id, categoryId:r.category_id, name:r.name, slug:r.slug, description:r.description,
    price:toNumber(r.price), promotionalPrice:r.promotional_price == null ? undefined : toNumber(r.promotional_price), active:r.active, featured:r.featured,
    madeToOrder:r.made_to_order, productionDays:r.production_days || 0, stockStatus:r.stock_status || 'available',
    stockLabel:r.stock_status === 'low_stock' ? 'Últimas unidades' : r.stock_status === 'unavailable' ? 'Indisponível' : undefined,
    images: productImages, imageUrl: primary?.url || '/assets/placeholder-flower.svg', gallery: productImages.map((image)=>image.url),
    variations: variants.filter((v)=>v.product_id===r.id).sort((a,b)=>a.sort_order-b.sort_order).map((v)=>({ id:v.id, productId:v.product_id, name:v.name, priceDelta:toNumber(v.price_delta), active:v.active, sortOrder:v.sort_order })),
    addons: addons.filter((addon)=>productAddonIds.has(addon.id)),
  };
});

const clone = <T,>(value: T): T => JSON.parse(JSON.stringify(value)) as T;
const createDemoDb = (): DemoDatabase => {
  const activeProductCount = seedProducts.filter((product) => product.active).length;
  return { settings: clone(seedSettings), categories: clone(seedCategories), products: clone(seedProducts), addons: clone(seedAddons), deliveryZones: clone(seedDeliveryZones), orders: clone(seedOrders), planUsage: { plan: clone(seedPlan), productCount: seedProducts.length, activeProductCount, canCreateProduct: true, canActivateProduct: seedPlan.productLimit == null || activeProductCount < seedPlan.productLimit } };
};
const readDemo = (): DemoDatabase => {
  try {
    const raw = localStorage.getItem(DEMO_KEY);
    if (!raw) return createDemoDb();
    const db = JSON.parse(raw) as DemoDatabase;
    db.planUsage = db.planUsage || createDemoDb().planUsage;
    db.planUsage.productCount = db.products.length;
    db.planUsage.activeProductCount = db.products.filter((product) => product.active).length;
    db.planUsage.canCreateProduct = true;
    db.planUsage.canActivateProduct = db.planUsage.plan.productLimit == null || db.planUsage.activeProductCount < db.planUsage.plan.productLimit;
    return db;
  } catch { return createDemoDb(); }
};
const writeDemo = (db: DemoDatabase) => {
  db.planUsage.productCount = db.products.length;
  db.planUsage.activeProductCount = db.products.filter((product) => product.active).length;
  db.planUsage.canCreateProduct = true;
  db.planUsage.canActivateProduct = db.planUsage.plan.productLimit == null || db.planUsage.activeProductCount < db.planUsage.plan.productLimit;
  try { localStorage.setItem(DEMO_KEY, JSON.stringify(db)); }
  catch { throw new Error('O armazenamento local do navegador ficou sem espaço. Use imagens menores no modo demo ou configure o Supabase Storage.'); }
};

const encode = (value: string) => encodeURIComponent(value);
const inFilter = (ids: string[]) => `in.(${ids.join(',')})`;

const loadPlanUsage = async (storeId: string, productCount: number, activeProductCount: number): Promise<PlanUsage> => {
  const subs = await restFetch<SubscriptionRow[]>(`store_subscriptions?select=*&store_id=eq.${encode(storeId)}&status=in.(trial,active)&order=started_at.desc&limit=10`);
  const current = subs.find((sub)=>!sub.expires_at || new Date(sub.expires_at).getTime() >= Date.now());
  if (!current) return { plan: seedPlan, productCount, activeProductCount, canCreateProduct: true, canActivateProduct: seedPlan.productLimit == null || activeProductCount < seedPlan.productLimit };
  const plans = await restFetch<PlanRow[]>(`plans?select=*&id=eq.${encode(current.plan_id)}&limit=1`);
  const plan = plans[0] ? mapPlan(plans[0]) : seedPlan;
  return { plan, productCount, activeProductCount, canCreateProduct: true, canActivateProduct: plan.productLimit == null || activeProductCount < plan.productLimit, subscriptionStatus: current.status, expiresAt: current.expires_at || undefined };
};

const loadPublicSnapshotFromRpc = async (slug: string, hostname: string): Promise<StoreSnapshot> => {
  const payload = await restFetch<PublicStorefrontRpc>('rpc/get_public_storefront_v3', {
    method: 'POST',
    body: { p_slug: slug || null, p_hostname: hostname || null },
  });

  if (!payload?.found) throw new Error('Floricultura não encontrada.');
  const publicStore = payload.store;
  if (payload.status !== 'online') {
    const name = publicStore && 'name' in publicStore ? publicStore.name : 'Floricultura';
    throw new StorefrontUnavailableError(name || 'Floricultura');
  }
  if (!publicStore || !('delivery_enabled' in publicStore)) throw new Error('A vitrine pública retornou dados incompletos.');

  const settings = mapStore(publicStore as StoreRow);
  const categories = (payload.categories || []).map(mapCategory);
  const addons = (payload.addons || []).map(mapAddon);
  const deliveryZones = (payload.delivery_zones || []).map(mapDeliveryZone);
  const products = buildProducts(
    payload.products || [],
    payload.product_images || [],
    payload.product_variants || [],
    addons,
    payload.product_addons || [],
  );
  const activeProductCount = products.filter((product) => product.active).length;
  return {
    settings,
    categories,
    products,
    addons,
    deliveryZones,
    orders: [],
    planUsage: {
      plan: seedPlan,
      productCount: products.length,
      activeProductCount,
      canCreateProduct: true,
      canActivateProduct: true,
    },
  };
};

const isMissingPublicStorefrontRpc = (error: unknown) =>
  error instanceof SupabaseHttpError
  && (error.status === 404 || error.details === 'PGRST202' || error.message.includes('get_public_storefront_v3'));

const loadSnapshotFromSupabase = async (slugOrId: string, admin = false): Promise<StoreSnapshot> => {
  const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(slugOrId);
  const storeFilter = isUuid ? `id=eq.${encode(slugOrId)}` : `slug=eq.${encode(slugOrId)}`;
  const stores = await restFetch<StoreRow[]>(`stores?select=*&${storeFilter}&limit=1`);
  if (!stores.length) throw new Error('Floricultura não encontrada ou sem permissão.');
  const settings = mapStore(stores[0]);
  const categoryRows = await restFetch<CategoryRow[]>(`categories?select=*&store_id=eq.${encode(settings.id)}${admin ? '' : '&active=eq.true'}&order=sort_order.asc,name.asc`);
  const productRows = await restFetch<ProductRow[]>(`products?select=*&store_id=eq.${encode(settings.id)}${admin ? '' : '&active=eq.true'}&order=featured.desc,name.asc`);
  const addonRows = await restFetch<AddonRow[]>(`addons?select=*&store_id=eq.${encode(settings.id)}${admin ? '' : '&active=eq.true'}&order=name.asc`);
  const deliveryZoneRows = await restFetch<DeliveryZoneRow[]>(`delivery_zones?select=*&store_id=eq.${encode(settings.id)}${admin ? '' : '&active=eq.true'}&order=sort_order.asc,name.asc`);
  const productIds = productRows.map((p)=>p.id);
  const [imageRows, variantRows, linkRows] = productIds.length ? await Promise.all([
    restFetch<ProductImageRow[]>(`product_images?select=*&product_id=${encode(inFilter(productIds))}&order=sort_order.asc`),
    restFetch<ProductVariantRow[]>(`product_variants?select=*&product_id=${encode(inFilter(productIds))}${admin ? '' : '&active=eq.true'}&order=sort_order.asc`),
    restFetch<ProductAddonRow[]>(`product_addons?select=*&product_id=${encode(inFilter(productIds))}`),
  ]) : [[], [], []];
  const categories = categoryRows.map(mapCategory);
  const addons = addonRows.map(mapAddon);
  const deliveryZones = deliveryZoneRows.map(mapDeliveryZone);
  const products = buildProducts(productRows, imageRows, variantRows, addons, linkRows);
  const orders = admin ? (await restFetch<OrderRow[]>(`orders?select=*&store_id=eq.${encode(settings.id)}&order=created_at.desc&limit=100`)).map(mapOrder) : [];
  const activeProductCount = products.filter((product) => product.active).length;
  const planUsage = admin ? await loadPlanUsage(settings.id, products.length, activeProductCount) : { plan: seedPlan, productCount: products.length, activeProductCount, canCreateProduct: true, canActivateProduct: true };
  return { settings, categories, products, addons, deliveryZones, orders, planUsage };
};

export const storeApi = {
  get mode() { return isDemoMode ? 'demo' as const : 'supabase' as const; },

  async loadPublic(slug: string | null = null, hostname = '') {
    if (!isDemoMode) {
      const requestedSlug = slug || appConfig.defaultStoreSlug;
      const publicHostname = hostname && !['localhost','127.0.0.1'].includes(hostname) ? hostname.toLowerCase() : '';

      try {
        return await loadPublicSnapshotFromRpc(requestedSlug, publicHostname);
      } catch (error) {
        if (error instanceof StorefrontUnavailableError) throw error;
        if (!isMissingPublicStorefrontRpc(error)) throw error;
      }

      // Rollout seguro: enquanto a migration V3 do RPC consolidado ainda nao estiver
      // aplicada no banco, mantemos o fluxo V2.9 como fallback. Depois da aplicacao,
      // a vitrine usa uma unica requisicao publica.
      try {
        const status = await restFetch<StorefrontStatus>('rpc/resolve_storefront_status', {
          method:'POST',
          body:{ p_slug:requestedSlug || null, p_hostname:publicHostname || null },
        });
        if (!status?.found || !status.id) throw new Error('Floricultura não encontrada.');
        if (status.status !== 'online') throw new StorefrontUnavailableError(status.name || 'Floricultura');
        return loadSnapshotFromSupabase(status.id, false);
      } catch (error) {
        if (error instanceof StorefrontUnavailableError) throw error;
        let reference = slug || '';
        if (!reference && publicHostname) {
          try {
            const domains = await restFetch<StoreDomainRow[]>(`store_domains?select=store_id,domain,active,is_primary&domain=eq.${encode(publicHostname)}&active=eq.true&limit=1`);
            reference = domains[0]?.store_id || '';
          } catch { /* fallback para slug padrao */ }
        }
        return loadSnapshotFromSupabase(reference || appConfig.defaultStoreSlug, false);
      }
    }
    const db = readDemo();
    const activeCategoryIds = new Set(db.categories.filter((category)=>category.active).map((category)=>category.id));
    return { ...db, categories: db.categories.filter((c)=>c.active), products: db.products.filter((p)=>p.active&&activeCategoryIds.has(p.categoryId)), addons: db.addons.filter((a)=>a.active), deliveryZones: db.deliveryZones.filter((z)=>z.active).sort((a,b)=>a.sortOrder-b.sortOrder), orders: [] };
  },
  async loadAdmin(storeId: string) { return isDemoMode ? readDemo() : loadSnapshotFromSupabase(storeId, true); },

  async resetDemo() { const db = createDemoDb(); writeDemo(db); return db; },

  async saveSettings(settings: StoreSettings): Promise<StoreSettings> {
    if (isDemoMode) { const db=readDemo(); db.settings=clone(settings); writeDemo(db); return settings; }
    const payload = { name:settings.name, description:settings.tagline, logo_url:settings.logoUrl, logo_storage_path:settings.logoStoragePath ?? null, cover_url:settings.heroUrl, cover_storage_path:settings.heroStoragePath ?? null, whatsapp:settings.whatsapp, instagram:settings.instagram, address:settings.address, city:settings.city, state:settings.state, zip_code:settings.zipCode || null, delivery_enabled:settings.deliveryEnabled, pickup_enabled:settings.pickupEnabled, pix_enabled:settings.pixEnabled, pix_receipt_mode:settings.pixReceiptMode, pix_key_type:settings.pixKeyType || null, pix_key:settings.pixKey || null, pix_copy_paste:settings.pixCopyPaste || null, pix_holder_name:settings.pixReceiver || null, show_pix_before_confirmation:settings.showPixBeforeConfirmation, confirmation_payment_enabled:settings.confirmationPaymentEnabled, card_payment_enabled:settings.cardPaymentEnabled, cash_payment_enabled:settings.cashPaymentEnabled, payment_method_order:settings.paymentMethodOrder, minimum_order:settings.minimumOrder, opening_hours:{ display:formatOpeningSchedule(settings.openingSchedule), timezone:settings.openingSchedule.timezone, days:settings.openingSchedule.days } };
    const rows = await restFetch<StoreRow[]>(`stores?id=eq.${encode(settings.id)}&select=*`, { method:'PATCH', body:payload, prefer:'return=representation' });
    return mapStore(rows[0]);
  },

  async saveCategory(category: Category): Promise<Category> {
    if (isDemoMode) { const db=readDemo(); const idx=db.categories.findIndex(c=>c.id===category.id); if(idx>=0) db.categories[idx]=clone(category); else db.categories.push(clone(category)); writeDemo(db); return category; }
    const payload={ id:category.id, store_id:category.storeId, name:category.name, slug:category.slug||slugify(category.name), description:category.description||null, active:category.active, sort_order:category.sortOrder };
    const rows=await restFetch<CategoryRow[]>(`categories?on_conflict=id&select=*`,{method:'POST',body:payload,prefer:'resolution=merge-duplicates,return=representation'}); return mapCategory(rows[0]);
  },

  async deleteCategory(id: string) {
    if (isDemoMode) { const db=readDemo(); if(db.products.some(p=>p.categoryId===id)) throw new Error('Existem produtos vinculados a esta categoria.'); db.categories=db.categories.filter(c=>c.id!==id); writeDemo(db); return; }
    await restFetch<unknown>(`categories?id=eq.${encode(id)}`,{method:'DELETE'});
  },

  async saveAddon(addon: Addon): Promise<Addon> {
    if(isDemoMode){const db=readDemo();const idx=db.addons.findIndex(a=>a.id===addon.id);if(idx>=0)db.addons[idx]=clone(addon);else db.addons.push(clone(addon));db.products=db.products.map(p=>({...p,addons:p.addons.map(a=>a.id===addon.id?clone(addon):a)}));writeDemo(db);return addon;}
    const payload={id:addon.id,store_id:addon.storeId,name:addon.name,description:addon.description||null,price:addon.price,active:addon.active,image_url:addon.imageUrl||null,image_storage_path:addon.imageStoragePath||null};
    const rows=await restFetch<AddonRow[]>(`addons?on_conflict=id&select=*`,{method:'POST',body:payload,prefer:'resolution=merge-duplicates,return=representation'});return mapAddon(rows[0]);
  },

  async deleteAddon(id:string){
    if(isDemoMode){const db=readDemo();db.addons=db.addons.filter(a=>a.id!==id);db.products=db.products.map(p=>({...p,addons:p.addons.filter(a=>a.id!==id)}));writeDemo(db);return;}
    const rows=await restFetch<AddonRow[]>(`addons?select=*&id=eq.${encode(id)}&limit=1`);
    await restFetch<unknown>(`addons?id=eq.${encode(id)}`,{method:'DELETE'});
    const path=rows[0]?.image_storage_path;if(path){try{await storageDelete('store-assets',[path])}catch(error){console.warn('Adicional removido, mas houve falha ao limpar a imagem.',error)}}
  },

  async uploadAddonImage(storeId:string,addonId:string,file:File):Promise<{url:string;path?:string}>{
    const maxSize=5*1024*1024;const allowed=new Set(['image/jpeg','image/png','image/webp']);
    if(!allowed.has(file.type))throw new Error('Use uma imagem JPG, PNG ou WEBP.');if(file.size>maxSize)throw new Error('A imagem excede 5 MB.');
    if(isDemoMode){const url=await new Promise<string>((resolve,reject)=>{const reader=new FileReader();reader.onload=()=>resolve(String(reader.result));reader.onerror=()=>reject(reader.error);reader.readAsDataURL(file);});return{url};}
    const ext=(file.name.split('.').pop()||'webp').toLowerCase().replace(/[^a-z0-9]/g,'');
    const path=`stores/${storeId}/addons/${addonId}/${createId()}.${ext}`;return storageUpload('store-assets',path,file);
  },

  async saveDeliveryZones(zones: DeliveryZone[]): Promise<DeliveryZone[]> {
    if (isDemoMode) {
      const db = readDemo();
      const byId = new Map(zones.map((zone) => [zone.id, clone(zone)]));
      db.deliveryZones = db.deliveryZones.map((zone) => byId.get(zone.id) || zone);
      for (const zone of zones) if (!db.deliveryZones.some((item) => item.id === zone.id)) db.deliveryZones.push(clone(zone));
      writeDemo(db);
      return zones;
    }
    if (!zones.length) return [];
    const payload = zones.map((zone) => ({
      id: zone.id,
      store_id: zone.storeId,
      name: zone.name,
      aliases: zone.aliases,
      city: zone.city,
      state: zone.state.toUpperCase(),
      fee: zone.fee,
      active: zone.active,
      sort_order: zone.sortOrder,
    }));
    const rows = await restFetch<DeliveryZoneRow[]>('delivery_zones?on_conflict=id&select=*', { method: 'POST', body: payload, prefer: 'resolution=merge-duplicates,return=representation' });
    return rows.map(mapDeliveryZone);
  },

  async deleteDeliveryZone(id: string): Promise<void> {
    if (isDemoMode) {
      const db = readDemo();
      db.deliveryZones = db.deliveryZones.filter((zone) => zone.id !== id);
      writeDemo(db);
      return;
    }
    await restFetch<unknown>(`delivery_zones?id=eq.${encode(id)}`, { method: 'DELETE' });
  },

  async saveProduct(product: Product): Promise<Product> {
    if(isDemoMode){const db=readDemo();const existing=db.products.find(p=>p.id===product.id);const activeCount=db.products.filter(p=>p.active&&p.id!==product.id).length;const limit=db.planUsage.plan.productLimit;if(product.active&&limit!=null&&activeCount>=limit)throw new Error(`Seu plano permite até ${limit} produtos ativos. Desative um produto ou altere o plano para publicar este item.`);db.products=existing?db.products.map(p=>p.id===product.id?clone(product):p):[clone(product),...db.products];writeDemo(db);return product;}
    const payload={id:product.id,store_id:product.storeId,category_id:product.categoryId,name:product.name,slug:product.slug||slugify(product.name),description:product.description,price:product.price,promotional_price:product.promotionalPrice??null,active:product.active,featured:product.featured,made_to_order:product.madeToOrder,production_days:product.madeToOrder?product.productionDays:0,stock_status:product.stockStatus};
    await restFetch<ProductRow[]>(`products?on_conflict=id&select=*`,{method:'POST',body:payload,prefer:'resolution=merge-duplicates,return=representation'});
    await restFetch<unknown>(`product_variants?product_id=eq.${encode(product.id)}`,{method:'DELETE'});
    if(product.variations.length) await restFetch<unknown>('product_variants',{method:'POST',body:product.variations.map((v,i)=>({id:v.id||createId(),product_id:product.id,name:v.name,price_delta:v.priceDelta,active:v.active,sort_order:v.sortOrder||((i+1)*10)}))});
    await restFetch<unknown>(`product_addons?product_id=eq.${encode(product.id)}`,{method:'DELETE'});
    if(product.addons.length) await restFetch<unknown>('product_addons',{method:'POST',body:product.addons.map((a)=>({product_id:product.id,addon_id:a.id}))});
    return product;
  },

  async deleteProduct(id:string){
    if(isDemoMode){const db=readDemo();db.products=db.products.filter(p=>p.id!==id);writeDemo(db);return;}
    const images=await restFetch<ProductImageRow[]>(`product_images?select=*&product_id=eq.${encode(id)}`);
    await restFetch<unknown>(`products?id=eq.${encode(id)}`,{method:'DELETE'});
    const paths=images.map((image)=>image.storage_path).filter((path):path is string=>Boolean(path));
    if(paths.length){try{await storageDelete('product-images',paths)}catch(error){console.warn('Produto removido, mas houve falha ao limpar imagens do Storage.',error)}}
  },

  async uploadProductImages(storeId:string, productId:string, files:File[], current:ProductImage[]):Promise<ProductImage[]>{
    const maxSize=5*1024*1024; const allowed=new Set(['image/jpeg','image/png','image/webp']);
    for(const file of files){if(!allowed.has(file.type))throw new Error(`Formato não permitido: ${file.name}`);if(file.size>maxSize)throw new Error(`${file.name} excede 5 MB.`);}
    if(isDemoMode){
      const readFile=(file:File)=>new Promise<string>((resolve,reject)=>{const reader=new FileReader();reader.onload=()=>resolve(String(reader.result));reader.onerror=()=>reject(reader.error);reader.readAsDataURL(file);});
      const next=[...current];for(const file of files){const url=await readFile(file);next.push({id:createId(),productId,url,altText:file.name,sortOrder:next.length,isPrimary:next.length===0});}
      const db=readDemo();db.products=db.products.map(p=>p.id===productId?{...p,images:next,imageUrl:(next.find(i=>i.isPrimary)||next[0])?.url||p.imageUrl,gallery:next.map(i=>i.url)}:p);writeDemo(db);return next;
    }
    const added:ProductImage[]=[];
    for(const [index,file] of files.entries()){
      const ext=(file.name.split('.').pop()||'webp').toLowerCase().replace(/[^a-z0-9]/g,'');
      const path=`stores/${storeId}/products/${productId}/${createId()}.${ext}`;
      const uploaded=await storageUpload('product-images',path,file);
      const row={id:createId(),product_id:productId,url:uploaded.url,storage_path:uploaded.path,alt_text:file.name,sort_order:current.length+index,is_primary:current.length===0&&index===0};
      const result=await restFetch<ProductImageRow[]>('product_images?select=*',{method:'POST',body:row,prefer:'return=representation'});
      const r=result[0];added.push({id:r.id,productId:r.product_id,url:r.url,storagePath:r.storage_path||undefined,altText:r.alt_text||undefined,sortOrder:r.sort_order,isPrimary:r.is_primary});
    }
    return [...current,...added];
  },

  async deleteProductImage(image:ProductImage){
    if(isDemoMode){
      const db=readDemo();
      db.products=db.products.map((product)=>{
        if(product.id!==image.productId)return product;
        let next=product.images.filter((item)=>item.id!==image.id);
        if(image.isPrimary&&next.length&&!next.some((item)=>item.isPrimary))next=next.map((item,index)=>({...item,isPrimary:index===0}));
        const primary=next.find((item)=>item.isPrimary)||next[0];
        return{...product,images:next,gallery:next.map((item)=>item.url),imageUrl:primary?.url||'/assets/placeholder-flower.svg'};
      });
      writeDemo(db);return;
    }
    await restFetch<unknown>(`product_images?id=eq.${encode(image.id)}`,{method:'DELETE'});
    if(image.isPrimary){
      const remaining=await restFetch<ProductImageRow[]>(`product_images?select=*&product_id=eq.${encode(image.productId)}&order=sort_order.asc&limit=1`);
      if(remaining[0])await restFetch<unknown>(`product_images?id=eq.${encode(remaining[0].id)}`,{method:'PATCH',body:{is_primary:true}});
    }
    if(image.storagePath)await storageDelete('product-images',[image.storagePath]);
  },

  async setPrimaryImage(productId:string,imageId:string){
    if(isDemoMode){const db=readDemo();db.products=db.products.map(p=>p.id===productId?{...p,images:p.images.map(i=>({...i,isPrimary:i.id===imageId})),imageUrl:p.images.find(i=>i.id===imageId)?.url||p.imageUrl}:p);writeDemo(db);return;}
    await restFetch<unknown>(`product_images?product_id=eq.${encode(productId)}`,{method:'PATCH',body:{is_primary:false}});await restFetch<unknown>(`product_images?id=eq.${encode(imageId)}`,{method:'PATCH',body:{is_primary:true}});
  },

  async uploadStoreAsset(storeId:string,file:File,kind:'logo'|'cover'): Promise<{url:string;path?:string}>{
    const maxSize=5*1024*1024;const allowed=new Set(['image/jpeg','image/png','image/webp']);if(!allowed.has(file.type))throw new Error('Use uma imagem JPG, PNG ou WEBP.');if(file.size>maxSize)throw new Error('A imagem excede 5 MB.');
    if(isDemoMode){const url=await new Promise<string>((resolve,reject)=>{const reader=new FileReader();reader.onload=()=>resolve(String(reader.result));reader.onerror=()=>reject(reader.error);reader.readAsDataURL(file);});return{url};}
    const ext=(file.name.split('.').pop()||'webp').toLowerCase().replace(/[^a-z0-9]/g,'');const path=`stores/${storeId}/${kind}/${createId()}.${ext}`;return storageUpload('store-assets',path,file);
  },

  async createOrder(store:StoreSettings,items:CartItem[],form:CheckoutData,subtotal:number,security:CheckoutSecurityContext={}):Promise<CreateOrderResult>{
    const deliveryAddress=form.fulfillment==='delivery'?[`${form.street}${form.addressNumber?`, ${form.addressNumber}`:''}`,form.complement,`${form.neighborhood}${form.deliveryCity?` - ${form.deliveryCity}`:''}${form.deliveryState?`/${form.deliveryState}`:''}`,form.zipCode?`CEP ${form.zipCode}`:'',form.referencePoint?`Referência: ${form.referencePoint}`:''].filter(Boolean).join(' | '):null;
    const payload={store_id:store.id,customer_name:form.customerName,customer_phone:form.customerPhone||null,customer_email:form.customerEmail||null,delivery_type:form.fulfillment,desired_date:form.desiredDate,desired_period:form.timeWindow||null,recipient_name:form.recipientName||null,recipient_phone:form.recipientPhone||null,delivery_address:deliveryAddress,delivery_zip_code:form.fulfillment==='delivery'?form.zipCode||null:null,delivery_street:form.fulfillment==='delivery'?form.street||null:null,delivery_number:form.fulfillment==='delivery'?form.addressNumber||null:null,delivery_complement:form.fulfillment==='delivery'?form.complement||null:null,delivery_neighborhood:form.fulfillment==='delivery'?form.neighborhood||null:null,delivery_zone_id:form.fulfillment==='delivery'?form.deliveryZoneId||null:null,delivery_city:form.fulfillment==='delivery'?form.deliveryCity||null:null,delivery_state:form.fulfillment==='delivery'?form.deliveryState||null:null,reference_point:form.fulfillment==='delivery'?form.referencePoint||null:null,card_message:form.cardMessage||null,card_signature:form.anonymousSender?null:form.cardSignature||null,anonymous_sender:form.anonymousSender,notes:form.notes||null,payment_method:form.paymentMethod,review_confirmed:form.reviewConfirmed,subtotal:roundMoney(subtotal),total:roundMoney(subtotal),items:items.map(item=>({product_id:item.productId,product_name:item.productName,quantity:item.quantity,unit_price:item.unitPrice,variant_id:item.variation?.id||null,variant_name:item.variation?.name||null,variant_price_delta:item.variation?.priceDelta||0,addons:item.addons.map(a=>({id:a.id,name:a.name,price:a.price})),item_total:roundMoney((item.unitPrice+item.addons.reduce((s,a)=>s+a.price,0))*item.quantity)}))};
    if(isDemoMode){
      const db=readDemo();
      if(subtotal<store.minimumOrder)throw new Error(`Pedido mínimo de R$ ${store.minimumOrder.toFixed(2).replace('.',',')}.`);
      const id=createId();
      const orderNumber=Math.max(28623,...db.orders.map(order=>order.orderNumber||0))+1;
      if(!form.reviewConfirmed)throw new Error('Confirme que revisou os dados do pedido.');
      const madeToOrderItems=items.map((item)=>db.products.find((product)=>product.id===item.productId)).filter((product):product is Product=>Boolean(product?.madeToOrder&&product.productionDays>0));
      const maxProductionDays=madeToOrderItems.reduce((max,product)=>Math.max(max,product.productionDays),0);
      if(maxProductionDays>0){const minimumDate=addDaysLocalISO(maxProductionDays);if(form.desiredDate<minimumDate)throw new Error(`Produto sob encomenda: escolha ${formatDateBR(minimumDate)} ou uma data posterior.`);}
      const selectedZone=form.fulfillment==='delivery'?db.deliveryZones.find((zone)=>zone.id===form.deliveryZoneId&&zone.active):undefined;
      if(form.fulfillment==='delivery'&&!selectedZone)throw new Error('Selecione um bairro/área de entrega disponível.');
      const demoDeliveryFee=selectedZone?.fee ?? 0;
      const total=roundMoney(subtotal+demoDeliveryFee);
      db.orders.unshift({id,orderNumber,storeId:store.id,customerName:form.customerName,customerPhone:form.customerPhone||undefined,customerEmail:form.customerEmail||undefined,deliveryType:form.fulfillment,desiredDate:form.desiredDate,desiredPeriod:form.timeWindow||undefined,recipientName:form.recipientName||undefined,recipientPhone:form.recipientPhone||undefined,deliveryAddress:deliveryAddress||undefined,deliveryZipCode:form.zipCode||undefined,deliveryStreet:form.street||undefined,deliveryNumber:form.addressNumber||undefined,deliveryComplement:form.complement||undefined,deliveryNeighborhood:form.neighborhood||undefined,deliveryZoneId:selectedZone?.id,deliveryZoneName:selectedZone?.name,deliveryFee:selectedZone?.fee ?? 0,deliveryCity:form.deliveryCity||undefined,deliveryState:form.deliveryState||undefined,referencePoint:form.referencePoint||undefined,cardMessage:form.cardMessage||undefined,cardSignature:form.anonymousSender?undefined:form.cardSignature||undefined,anonymousSender:form.anonymousSender,notes:form.notes||undefined,paymentMethod:form.paymentMethod,subtotal:roundMoney(subtotal),total,status:'draft',createdAt:new Date().toISOString()});
      writeDemo(db);
      return {orderId:id,orderNumber,total};
    }
    const created=await invokePublicFunction<{orderId:string;orderNumber:number|string;total:number|string}>('public-checkout',{
      payload,
      turnstileToken:security.turnstileToken||'',
      analyticsSessionId:security.analyticsSessionId||'',
      requestId:security.requestId||'',
    });
    if(!created?.orderId)throw new Error('O pedido foi registrado, mas o identificador não foi retornado.');
    return {orderId:created.orderId,orderNumber:toNumber(created.orderNumber),total:toNumber(created.total)};
  },

  async markOrderWhatsAppClicked(orderId:string):Promise<void>{
    if(isDemoMode){
      const db=readDemo();
      db.orders=db.orders.map(order=>order.id===orderId?{...order,status:'sent_to_whatsapp',whatsappClickedAt:order.whatsappClickedAt||new Date().toISOString()}:order);
      writeDemo(db);
      return;
    }
    await restFetch<unknown>('rpc/mark_public_order_whatsapp_clicked',{method:'POST',body:{p_order_id:orderId},keepalive:true});
  },
};
