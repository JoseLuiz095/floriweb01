export type Role = 'owner' | 'admin' | 'employee';
export type StoreAccessStatus = 'online' | 'suspended';
export type StoreCredentialMode = 'invite' | 'temporary_password';

export type PlatformAdmin = {
  id: string;
  userId: string;
  name: string;
  active: boolean;
};

export type Category = {
  id: string;
  storeId: string;
  name: string;
  slug: string;
  description?: string;
  active: boolean;
  sortOrder: number;
};

export type ProductVariation = {
  id: string;
  productId?: string;
  name: string;
  priceDelta: number;
  active: boolean;
  sortOrder: number;
};

export type DeliveryZone = {
  id: string;
  storeId: string;
  name: string;
  aliases: string[];
  city: string;
  state: string;
  fee: number;
  active: boolean;
  sortOrder: number;
};

export type PaymentMethod = 'confirm' | 'pix' | 'card' | 'cash';

export type Addon = {
  id: string;
  storeId: string;
  name: string;
  description?: string;
  price: number;
  active: boolean;
  imageUrl?: string;
  imageStoragePath?: string;
};

export type ProductImage = {
  id: string;
  productId: string;
  url: string;
  storagePath?: string;
  altText?: string;
  sortOrder: number;
  isPrimary: boolean;
};

export type Product = {
  id: string;
  storeId: string;
  slug: string;
  name: string;
  description: string;
  categoryId: string;
  price: number;
  promotionalPrice?: number;
  imageUrl: string;
  gallery: string[];
  images: ProductImage[];
  featured: boolean;
  active: boolean;
  madeToOrder: boolean;
  productionDays: number;
  stockStatus: 'available' | 'low_stock' | 'unavailable';
  stockLabel?: string;
  variations: ProductVariation[];
  addons: Addon[];
};


export type OpeningDayConfig = {
  day: number;
  enabled: boolean;
  open: string;
  close: string;
};

export type OpeningSchedule = {
  timezone: string;
  days: OpeningDayConfig[];
};

export type StoreSettings = {
  id: string;
  slug: string;
  name: string;
  tagline: string;
  description?: string;
  city: string;
  state: string;
  zipCode?: string;
  whatsapp: string;
  instagram: string;
  address: string;
  logoUrl: string;
  logoStoragePath?: string;
  heroUrl: string;
  heroStoragePath?: string;
  pixEnabled: boolean;
  pixReceiptMode: 'copy_paste' | 'key';
  pixKeyType: string;
  pixKey: string;
  pixCopyPaste: string;
  pixReceiver: string;
  showPixBeforeConfirmation: boolean;
  confirmationPaymentEnabled: boolean;
  cardPaymentEnabled: boolean;
  cashPaymentEnabled: boolean;
  paymentMethodOrder: PaymentMethod[];
  deliveryEnabled: boolean;
  pickupEnabled: boolean;
  minimumOrder: number;
  openingHours: string;
  openingSchedule: OpeningSchedule;
  active: boolean;
  accessStatus?: StoreAccessStatus;
};

export type Plan = {
  id: string;
  code: string;
  name: string;
  productLimit: number | null;
  imageLimitPerProduct: number | null;
  customDomain: boolean;
  reports: boolean;
  prioritySupport: boolean;
  monthlyPrice?: number;
  setupPrice?: number;
  categoryLimit?: number | null;
  addonLimit?: number | null;
  adminUserLimit?: number | null;
  sortOrder?: number;
  active: boolean;
};

export type PlatformSettings = {
  demoEnabled: boolean;
  demoDurationDays: number;
  demoWarningDays: number;
};

export type StoreSubscription = {
  id: string;
  storeId: string;
  planId: string;
  status: 'trial' | 'active' | 'suspended' | 'cancelled';
  startedAt: string;
  expiresAt?: string;
  plan: Plan;
};

export type PlanUsage = {
  plan: Plan;
  productCount: number;
  activeProductCount: number;
  canCreateProduct: boolean;
  canActivateProduct: boolean;
  subscriptionStatus?: 'trial' | 'active' | 'suspended' | 'cancelled';
  expiresAt?: string;
};

export type StoreUser = {
  id: string;
  storeId: string;
  userId: string;
  role: Role;
  active: boolean;
  mustChangePassword?: boolean;
};

export type AuthUser = {
  id: string;
  email: string;
};

export type AuthSession = {
  accessToken: string;
  refreshToken: string;
  expiresAt: number;
  user: AuthUser;
};

export type CartItem = {
  id: string;
  productId: string;
  productName: string;
  imageUrl: string;
  unitPrice: number;
  quantity: number;
  variation?: ProductVariation;
  addons: Addon[];
};

export type CheckoutData = {
  customerName: string;
  customerPhone: string;
  customerEmail: string;
  fulfillment: 'delivery' | 'pickup';
  desiredDate: string;
  timeWindow: string;
  recipientName: string;
  recipientPhone: string;
  zipCode: string;
  street: string;
  addressNumber: string;
  complement: string;
  neighborhood: string;
  deliveryZoneId: string;
  deliveryFee: number;
  deliveryCity: string;
  deliveryState: string;
  referencePoint: string;
  cardMessage: string;
  cardSignature: string;
  anonymousSender: boolean;
  notes: string;
  paymentMethod: PaymentMethod;
  reviewConfirmed: boolean;
};

export type OrderStatus = 'draft' | 'sent_to_whatsapp' | 'cancelled';


export type CreateOrderResult = {
  orderId: string;
  orderNumber: number;
  total: number;
};

export type OrderConfirmation = {
  orderId: string;
  orderNumber: number;
  total: number;
  paymentMethod: PaymentMethod;
  customerName: string;
  fulfillment: 'delivery' | 'pickup';
  storeName: string;
  storeWhatsapp: string;
  pixEnabled: boolean;
  pixReceiptMode: 'copy_paste' | 'key';
  pixKeyType: string;
  pixKey: string;
  pixCopyPaste: string;
  pixReceiver: string;
  orderMessage: string;
  createdAt: string;
};

export type Order = {
  id: string;
  orderNumber: number;
  storeId: string;
  customerName: string;
  customerPhone?: string;
  customerEmail?: string;
  deliveryType: 'delivery' | 'pickup';
  desiredDate: string;
  desiredPeriod?: string;
  recipientName?: string;
  recipientPhone?: string;
  deliveryAddress?: string;
  deliveryZipCode?: string;
  deliveryStreet?: string;
  deliveryNumber?: string;
  deliveryComplement?: string;
  deliveryNeighborhood?: string;
  deliveryZoneId?: string;
  deliveryZoneName?: string;
  deliveryFee?: number;
  deliveryCity?: string;
  deliveryState?: string;
  referencePoint?: string;
  cardMessage?: string;
  cardSignature?: string;
  anonymousSender?: boolean;
  notes?: string;
  paymentMethod: PaymentMethod;
  subtotal: number;
  total: number;
  status: OrderStatus;
  whatsappClickedAt?: string;
  createdAt: string;
};

export type SaveProductInput = Omit<Product, 'imageUrl' | 'gallery' | 'images'> & {
  images?: ProductImage[];
};


export type PlatformStoreSummary = {
  id: string;
  name: string;
  slug: string;
  city: string;
  state: string;
  ownerName?: string;
  ownerEmail?: string;
  active: boolean;
  accessStatus: StoreAccessStatus;
  productCount: number;
  activeProductCount: number;
  adminUserCount: number;
  subscriptionId?: string;
  subscriptionStatus?: 'trial' | 'active' | 'suspended' | 'cancelled';
  planId?: string;
  planName?: string;
  planCode?: string;
  billingAmount?: number;
  dueDay?: number;
  nextDueDate?: string;
  customDomain?: string;
  suspendedAt?: string;
  suspensionReason?: string;
  expiresAt?: string;
};

export type PlatformSystemCheck = {
  version: string;
  platformAdmin: boolean;
  stores: number;
  storesOnline: number;
  storesSuspended: number;
  plans: number;
  subscriptions: number;
  users: number;
  products: number;
  orders: number;
  deliveryZones: number;
  domains: number;
  analyticsEvents?: number;
  analyticsReady?: boolean;
  demoEnabled?: boolean;
  demoTrials?: number;
  demoTrialsExpiringSoon?: number;
  demoDurationDays?: number;
  demoWarningDays?: number;
  demoCronScheduled?: boolean;
  demoCronExists?: boolean;
  demoCronActive?: boolean;
  demoCronSchedule?: string | null;
};

export type PlatformDashboardStats = {
  storesTotal: number;
  storesOnline: number;
  storesSuspended: number;
  storesTrial: number;
  trialsExpiringSoon: number;
  monthlyRecurringRevenue: number;
};
export type PublicAnalyticsEventName = 'storefront_view' | 'product_view' | 'add_to_cart' | 'checkout_started';

export type CheckoutSecurityContext = {
  turnstileToken?: string;
  analyticsSessionId?: string;
  requestId?: string;
};

export type AnalyticsProductStat = {
  productId: string;
  name: string;
  views: number;
  addToCartSessions: number;
  soldUnits: number;
};

export type AnalyticsReport = {
  from: string;
  to: string;
  storefrontSessions: number;
  productViews: number;
  productViewSessions: number;
  addToCartSessions: number;
  checkoutSessions: number;
  orderSessions: number;
  orders: number;
  whatsappClicks: number;
  conversionRate: number;
  cartAbandonmentRate: number;
  checkoutAbandonmentRate: number;
  whatsappRate: number;
  revenue: number;
  averageTicket: number;
  topProducts: AnalyticsProductStat[];
  viewedNotSold: AnalyticsProductStat[];
};

