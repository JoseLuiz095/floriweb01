import { restFetch } from '../lib/supabaseRest';

export type BillingPlan = {
  id: string;
  code: string;
  name: string;
  monthlyPrice: number;
  marketingBenefits?: string[];
};

export type BillingSettings = {
  pixKeyType: string;
  pixKey: string;
  pixHolderName: string;
  pixCity: string;
  pixCopyPaste: string;
  whatsapp: string;
  marketingWhatsapp: string;
  supportWhatsapp: string;
  proofRequired: boolean;
  graceDays: number;
};

export type SubscriptionPaymentStatus = 'pending' | 'proof_sent' | 'paid' | 'cancelled' | 'rejected';
export type BillingState = 'current' | 'overdue' | 'trial' | 'suspended' | 'cancelled' | 'none';

export type SubscriptionPayment = {
  id: string;
  storeId: string;
  planId: string;
  previousPlanId?: string;
  requestedPlanId?: string;
  paymentIntent: 'renewal' | 'plan_change';
  amount: number;
  dueDate: string;
  status: SubscriptionPaymentStatus;
  proofRequired: boolean;
  proofSentAt?: string;
  paidAt?: string;
  rejectedAt?: string;
  rejectionReason?: string;
  createdAt: string;
  storeName?: string;
  planName?: string;
  previousPlanName?: string;
  requestedPlanName?: string;
  dueDay?: number;
  nextDueDate?: string;
  billingState?: BillingState;
};

export type BillingSubscription = {
  id: string;
  status: 'trial' | 'active' | 'suspended' | 'cancelled';
  billingAmount: number;
  dueDay?: number;
  nextDueDate?: string;
  billingState: BillingState;
  daysOverdue: number;
  lastPayment?: SubscriptionPayment | null;
};

export type BillingOverview = {
  currentPlan?: BillingPlan;
  subscription?: BillingSubscription | null;
  plans: BillingPlan[];
  settings: BillingSettings;
  payments: SubscriptionPayment[];
};

export type FinancialDirection = 'income' | 'expense';
export type FinancialEntry = {
  id: string;
  storeId: string;
  direction: FinancialDirection;
  source?: 'manual' | 'order' | 'adjustment';
  orderId?: string;
  description: string;
  category: string;
  amount: number;
  occurredOn: string;
  dueOn?: string;
  paidAt?: string;
  status: 'pending' | 'paid' | 'cancelled';
  paymentMethod?: string;
  counterparty?: string;
  documentType?: string;
  documentNumber?: string;
  notes?: string;
  createdAt: string;
};

export type FinancialOverview = {
  income: number;
  expense: number;
  result: number;
  receivable: number;
  payable: number;
  entries: FinancialEntry[];
  expenseByCategory: { category: string; amount: number }[];
  monthly: { month: string; income: number; expense: number }[];
};

export type PublicLandingStore = {
  id: string;
  slug: string;
  name: string;
  description: string;
  logoUrl: string;
  heroUrl: string;
  city: string;
  state: string;
};

export type PublicLanding = {
  demoStoreSlug: string;
  demoEnabled: boolean;
  demoDurationDays: number;
  contactProtected: boolean;
  stores: PublicLandingStore[];
  plans: BillingPlan[];
};

type PublicLandingRpc = {
  demo_store_slug?: string | null;
  demo_enabled?: boolean | null;
  demo_duration_days?: number | string | null;
  contact_protected?: boolean | null;
  stores?: Array<{
    id: string;
    slug: string;
    name: string;
    description?: string | null;
    logo_url?: string | null;
    hero_url?: string | null;
    city?: string | null;
    state?: string | null;
  }>;
  plans?: Array<{
    id: string;
    code: string;
    name: string;
    monthly_price?: number | string | null;
    marketing_benefits?: string[] | null;
  }>;
};

const rpc = async <T>(name: string, body: Record<string, unknown> = {}) =>
  restFetch<T>(`rpc/${name}`, { method: 'POST', body });

const number = (value: unknown) => Number(value ?? 0);

export const loadBillingOverview = (storeId: string) =>
  rpc<BillingOverview>('get_store_billing_overview_v1', { p_store_id: storeId });

export const createManualCharge = (storeId: string, planId: string) =>
  rpc<BillingOverview>('create_manual_subscription_charge_v1', {
    p_store_id: storeId,
    p_plan_id: planId,
  });

export const markProofSent = (paymentId: string) =>
  rpc<BillingOverview>('mark_subscription_proof_sent_v1', { p_payment_id: paymentId });

export const loadMasterBilling = () =>
  rpc<{ settings: BillingSettings; payments: SubscriptionPayment[] }>('platform_get_billing_dashboard_v1');

export const saveMasterBilling = (settings: BillingSettings) =>
  rpc<BillingSettings>('platform_update_billing_settings_v2', {
    p_pix_key_type: settings.pixKeyType,
    p_pix_key: settings.pixKey,
    p_pix_holder_name: settings.pixHolderName,
    p_pix_city: settings.pixCity,
    p_pix_copy_paste: settings.pixCopyPaste,
    p_whatsapp: settings.whatsapp,
    p_marketing_whatsapp: settings.marketingWhatsapp,
    p_support_whatsapp: settings.supportWhatsapp,
    p_proof_required: settings.proofRequired,
    p_grace_days: settings.graceDays,
  });

export const confirmSubscriptionPayment = (paymentId: string) =>
  rpc<{ ok: boolean; paidAt?: string; referenceDueDate?: string; nextDueDate?: string }>(
    'platform_confirm_subscription_payment_v1',
    { p_payment_id: paymentId },
  );

export const rejectSubscriptionPayment = (paymentId: string, reason: string) =>
  rpc<{ ok: boolean; alreadyRejected?: boolean }>('platform_reject_subscription_payment_v1', {
    p_payment_id: paymentId,
    p_reason: reason || null,
  });

export const loadFinancialOverview = (storeId: string) =>
  rpc<FinancialOverview>('get_store_financial_overview_v1', { p_store_id: storeId });

export const createFinancialEntry = (
  storeId: string,
  input: Omit<FinancialEntry, 'id' | 'storeId' | 'createdAt'>,
) =>
  rpc<FinancialEntry>('create_financial_entry_v1', {
    p_store_id: storeId,
    p_direction: input.direction,
    p_description: input.description,
    p_category: input.category,
    p_amount: input.amount,
    p_occurred_on: input.occurredOn,
    p_due_on: input.dueOn || null,
    p_status: input.status,
    p_counterparty: input.counterparty || null,
    p_document_type: input.documentType || 'none',
    p_document_number: input.documentNumber || null,
    p_notes: input.notes || null,
  });

let publicLandingPromise: Promise<PublicLanding> | null = null;

export const loadPublicLanding = (): Promise<PublicLanding> => {
  if (publicLandingPromise) return publicLandingPromise;

  publicLandingPromise = rpc<PublicLandingRpc>('get_public_landing_v1')
    .then((data) => ({
      demoStoreSlug: data.demo_store_slug || 'floriweb-demo',
      demoEnabled: data.demo_enabled !== false,
      demoDurationDays: Math.max(1, number(data.demo_duration_days) || 30),
      contactProtected: data.contact_protected !== false,
      stores: (data.stores || []).map((store) => ({
        id: store.id,
        slug: store.slug,
        name: store.name,
        description: store.description || 'Flores, presentes e carinho em uma experiência digital elegante.',
        logoUrl: store.logo_url || '/assets/logo.svg',
        heroUrl: store.hero_url || '',
        city: store.city || '',
        state: store.state || '',
      })),
      plans: (data.plans || []).map((plan) => ({
        id: plan.id,
        code: plan.code,
        name: plan.name,
        monthlyPrice: number(plan.monthly_price),
        marketingBenefits: Array.isArray(plan.marketing_benefits) ? plan.marketing_benefits.filter(Boolean) : [],
      })),
    }))
    .catch((error) => {
      publicLandingPromise = null;
      throw error;
    });

  return publicLandingPromise;
};
