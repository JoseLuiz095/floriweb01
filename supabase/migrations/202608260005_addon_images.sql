-- FloriWeb 2.4.0 - imagens para adicionais
-- Seguro para bancos já existentes.

alter table public.addons
  add column if not exists image_url text,
  add column if not exists image_storage_path text;

comment on column public.addons.image_url is 'URL pública da imagem do adicional.';
comment on column public.addons.image_storage_path is 'Caminho do objeto no Supabase Storage para permitir substituição/exclusão.';
