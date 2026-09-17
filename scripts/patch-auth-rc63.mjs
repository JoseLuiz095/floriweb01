import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const file = path.join(root, 'src/contexts/AuthContext.tsx');
if (!fs.existsSync(file)) {
  console.error('ERRO: src/contexts/AuthContext.tsx nao encontrado.');
  process.exit(1);
}
let source = fs.readFileSync(file, 'utf8');
if (source.includes('captchaToken?: string') && source.includes('options: captchaToken ? { captchaToken } : undefined')) {
  console.log('OK AuthContext ja possui suporte a captchaToken.');
  process.exit(0);
}
const replacements = [
  [
    "signIn: (email: string, password: string, scope?: SignInScope) => Promise<boolean>;",
    "signIn: (email: string, password: string, scope?: SignInScope, captchaToken?: string) => Promise<boolean>;",
  ],
  [
    "const signIn = useCallback(async (email: string, password: string, scope: SignInScope = 'any') => {",
    "const signIn = useCallback(async (email: string, password: string, scope: SignInScope = 'any', captchaToken = '') => {",
  ],
  [
    "supabase.auth.signInWithPassword({ email: email.trim(), password });",
    "supabase.auth.signInWithPassword({ email: email.trim(), password, options: captchaToken ? { captchaToken } : undefined });",
  ],
];
for (const [before, after] of replacements) {
  if (!source.includes(before)) {
    console.error(`ERRO: padrao esperado nao encontrado no AuthContext:\n${before}`);
    process.exit(1);
  }
  source = source.replace(before, after);
}
fs.writeFileSync(file, source, 'utf8');
console.log('OK AuthContext atualizado para encaminhar captchaToken ao Supabase Auth.');
