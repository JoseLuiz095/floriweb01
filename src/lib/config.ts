const trimSlash = (value: string) => value.replace(/\/+$/, '');

// URL e publishable key sao identificadores publicos do frontend Supabase.
// Variaveis VITE_* continuam tendo prioridade.
export const FLORIWEB_DEFAULT_SUPABASE_URL = 'https://elttryavkeartoxgdgse.supabase.co';
export const FLORIWEB_DEFAULT_SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_zBBXeb_s0IPTQgN283z9tw_-MisrJpl';

export const appConfig = {
  supabaseUrl: trimSlash(import.meta.env.VITE_SUPABASE_URL || FLORIWEB_DEFAULT_SUPABASE_URL),
  supabaseAnonKey: import.meta.env.VITE_SUPABASE_ANON_KEY ?? import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY ?? FLORIWEB_DEFAULT_SUPABASE_PUBLISHABLE_KEY,
  defaultStoreSlug: import.meta.env.VITE_DEFAULT_STORE_SLUG || 'floriweb-demo',
  appEnv: import.meta.env.VITE_APP_ENV || 'development',
  analyticsEnabled: String(import.meta.env.VITE_ANALYTICS_ENABLED || '').toLowerCase() === 'true',
  turnstileSiteKey: import.meta.env.VITE_TURNSTILE_SITE_KEY || '',
};

export const isSupabaseConfigured = Boolean(appConfig.supabaseUrl && appConfig.supabaseAnonKey);
export const isDemoMode = import.meta.env.DEV && !isSupabaseConfigured;

const PLATFORM_HOSTS = new Set(['floriweb.joseluizacama.workers.dev','localhost','127.0.0.1']);
export const isFloriWebPlatformHost = (hostname:string) => PLATFORM_HOSTS.has(String(hostname||'').trim().toLowerCase());
export const isFloriWebMarketingRoot = (pathname:string,hostname:string) => pathname==='/' && isFloriWebPlatformHost(hostname);
