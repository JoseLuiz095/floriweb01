-- Seed idempotente do FloriWeb Demo.
-- Execute depois da migration inicial.

insert into public.plans(id,code,name,product_limit,image_limit_per_product,custom_domain,reports,priority_support,active)
values
('40000000-0000-4000-8000-000000000001','DEMO','Demo',15,3,false,false,false,true),
('40000000-0000-4000-8000-000000000002','BASIC','Essencial',15,3,false,false,false,true),
('40000000-0000-4000-8000-000000000003','PRO','Profissional',40,6,false,true,true,true),
('40000000-0000-4000-8000-000000000004','PREMIUM','Premium',100,10,true,true,true,true)
on conflict(id) do update set code=excluded.code,name=excluded.name,product_limit=excluded.product_limit,image_limit_per_product=excluded.image_limit_per_product,custom_domain=excluded.custom_domain,reports=excluded.reports,priority_support=excluded.priority_support,active=excluded.active;

insert into public.stores(id,slug,name,description,logo_url,cover_url,whatsapp,instagram,address,city,state,delivery_enabled,pickup_enabled,pix_enabled,pix_receipt_mode,pix_key_type,pix_key,pix_copy_paste,pix_holder_name,show_pix_before_confirmation,confirmation_payment_enabled,card_payment_enabled,cash_payment_enabled,payment_method_order,minimum_order,opening_hours,active)
values('00000000-0000-4000-8000-000000000001','floriweb-demo','Jardim da Vila Floricultura','Flores que transformam momentos em lembranças.','/assets/logo.svg','/assets/hero.svg','5527999999999','@jardimdavila','Centro, Linhares - ES','Linhares','ES',true,true,true,'copy_paste','E-mail','demo@floriweb.local','00020126410014BR.GOV.BCB.PIX0119demo@floriweb.local5204000053039865802BR5914JARDIM DA VILA6008LINHARES62070503***6304715B','Jardim da Vila Floricultura',true,false,true,true,'["pix","card","cash","confirm"]'::jsonb,0,'{"display":"Seg 08:00–18:00 · Ter 08:00–18:00 · Qua 08:00–18:00 · Qui 08:00–18:00 · Sex 08:00–18:00 · Sáb 08:00–14:00","timezone":"America/Sao_Paulo","days":[{"day":0,"enabled":false,"open":"08:00","close":"18:00"},{"day":1,"enabled":true,"open":"08:00","close":"18:00"},{"day":2,"enabled":true,"open":"08:00","close":"18:00"},{"day":3,"enabled":true,"open":"08:00","close":"18:00"},{"day":4,"enabled":true,"open":"08:00","close":"18:00"},{"day":5,"enabled":true,"open":"08:00","close":"18:00"},{"day":6,"enabled":true,"open":"08:00","close":"14:00"}]}'::jsonb,true)
on conflict(id) do update set slug=excluded.slug,name=excluded.name,description=excluded.description,logo_url=excluded.logo_url,cover_url=excluded.cover_url,whatsapp=excluded.whatsapp,instagram=excluded.instagram,address=excluded.address,city=excluded.city,state=excluded.state,delivery_enabled=excluded.delivery_enabled,pickup_enabled=excluded.pickup_enabled,pix_enabled=excluded.pix_enabled,pix_receipt_mode=excluded.pix_receipt_mode,pix_key_type=excluded.pix_key_type,pix_key=excluded.pix_key,pix_copy_paste=excluded.pix_copy_paste,pix_holder_name=excluded.pix_holder_name,show_pix_before_confirmation=excluded.show_pix_before_confirmation,confirmation_payment_enabled=excluded.confirmation_payment_enabled,card_payment_enabled=excluded.card_payment_enabled,cash_payment_enabled=excluded.cash_payment_enabled,payment_method_order=excluded.payment_method_order,minimum_order=excluded.minimum_order,opening_hours=excluded.opening_hours,active=excluded.active;

insert into public.categories(id,store_id,name,slug,active,sort_order) values
('10000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001','Buquês','buques',true,10),
('10000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000001','Rosas','rosas',true,20),
('10000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000001','Flores variadas','flores-variadas',true,30),
('10000000-0000-4000-8000-000000000004','00000000-0000-4000-8000-000000000001','Presentes','presentes',true,40),
('10000000-0000-4000-8000-000000000005','00000000-0000-4000-8000-000000000001','Casamentos','casamentos',true,50)
on conflict(id) do update set name=excluded.name,slug=excluded.slug,active=excluded.active,sort_order=excluded.sort_order;

insert into public.addons(id,store_id,name,description,price,image_url,active) values
('20000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001','Chocolate 90g','Chocolate para acompanhar o presente.',18,'/assets/cesta-afeto.svg',true),
('20000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000001','Cartão especial','Cartão premium com mensagem personalizada.',8,'/assets/bouquet-aurora-2.svg',true),
('20000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000001','Mini pelúcia','Mini pelúcia para complementar o presente.',29.90,'/assets/box-carinho.svg',true),
('20000000-0000-4000-8000-000000000004','00000000-0000-4000-8000-000000000001','Caneca personalizada','Caneca para composição de cestas.',34.90,'/assets/lirio-encanto.svg',true)
on conflict(id) do update set name=excluded.name,description=excluded.description,price=excluded.price,image_url=excluded.image_url,active=excluded.active;

insert into public.products(id,store_id,category_id,name,slug,description,price,promotional_price,active,featured,made_to_order,production_days,stock_status) values
('30000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','Buquê Aurora','buque-aurora','Composição alegre com flores selecionadas em tons vibrantes. Ideal para aniversários, agradecimentos e momentos especiais.',149.90,129.90,true,true,false,0,'available'),
('30000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000003','Lírio Encanto','lirio-encanto','Arranjo delicado com lírios e folhagens, montado em embalagem de acabamento premium.',119.90,null,true,true,false,0,'available'),
('30000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','12 Rosas Clássicas','rosas-doze','Doze rosas frescas com folhagens e acabamento elegante para surpreender em qualquer ocasião.',169.90,null,true,false,false,0,'low_stock'),
('30000000-0000-4000-8000-000000000004','00000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000004','Box Carinho','box-carinho','Flores, chocolates e uma apresentação pronta para presentear. Uma escolha prática e marcante.',189.90,null,true,true,false,0,'available'),
('30000000-0000-4000-8000-000000000005','00000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000005','Buquê de Noiva Clássico','buque-noiva-classico','Buquê personalizado para casamento, desenvolvido de acordo com referências, paleta de cores e estilo da cerimônia.',320,null,true,false,true,10,'available'),
('30000000-0000-4000-8000-000000000006','00000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000003','Girassol Luz','girassol-luz','Composição vibrante de girassóis com folhagens naturais e embalagem kraft.',109.90,null,true,false,false,0,'available'),
('30000000-0000-4000-8000-000000000007','00000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','Rosa Unitária Premium','rosa-unitaria-premium','Uma rosa selecionada com acabamento refinado e cartão para uma lembrança elegante.',39.90,null,true,false,false,0,'available'),
('30000000-0000-4000-8000-000000000008','00000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000004','Cesta Afeto','cesta-afeto','Cesta com flores, doces e itens delicadamente organizados para presentear com afeto.',219.90,null,true,false,false,0,'available')
on conflict(id) do update set category_id=excluded.category_id,name=excluded.name,slug=excluded.slug,description=excluded.description,price=excluded.price,promotional_price=excluded.promotional_price,active=excluded.active,featured=excluded.featured,made_to_order=excluded.made_to_order,production_days=excluded.production_days,stock_status=excluded.stock_status;

insert into public.product_images(id,product_id,url,alt_text,sort_order,is_primary) values
('31000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','/assets/bouquet-aurora.svg','Buquê Aurora',0,true),
('31000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000001','/assets/bouquet-aurora-2.svg','Buquê Aurora detalhe',1,false),
('31000000-0000-4000-8000-000000000003','30000000-0000-4000-8000-000000000005','/assets/noiva-classico.svg','Buquê de noiva clássico',0,true),
('31000000-0000-4000-8000-000000000004','30000000-0000-4000-8000-000000000005','/assets/noiva-classico-2.svg','Buquê de noiva detalhe',1,false)
on conflict(id) do update set url=excluded.url,alt_text=excluded.alt_text,sort_order=excluded.sort_order,is_primary=excluded.is_primary;

-- Imagem principal para os demais produtos.
insert into public.product_images(id,product_id,url,alt_text,sort_order,is_primary) values
('31000000-0000-4000-8000-000000000005','30000000-0000-4000-8000-000000000002','/assets/lirio-encanto.svg','Lírio Encanto',0,true),
('31000000-0000-4000-8000-000000000006','30000000-0000-4000-8000-000000000003','/assets/rosas-doze.svg','12 Rosas Clássicas',0,true),
('31000000-0000-4000-8000-000000000007','30000000-0000-4000-8000-000000000004','/assets/box-carinho.svg','Box Carinho',0,true),
('31000000-0000-4000-8000-000000000008','30000000-0000-4000-8000-000000000006','/assets/girassol-luz.svg','Girassol Luz',0,true),
('31000000-0000-4000-8000-000000000009','30000000-0000-4000-8000-000000000007','/assets/rosa-unitaria.svg','Rosa Unitária Premium',0,true),
('31000000-0000-4000-8000-000000000010','30000000-0000-4000-8000-000000000008','/assets/cesta-afeto.svg','Cesta Afeto',0,true)
on conflict(id) do update set url=excluded.url,alt_text=excluded.alt_text,sort_order=excluded.sort_order,is_primary=excluded.is_primary;

insert into public.product_variants(id,product_id,name,price_delta,active,sort_order) values
('32000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','Clássico',0,true,10),
('32000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000001','Premium',35,true,20),
('32000000-0000-4000-8000-000000000003','30000000-0000-4000-8000-000000000001','Luxo',70,true,30),
('32000000-0000-4000-8000-000000000004','30000000-0000-4000-8000-000000000002','Branco',0,true,10),
('32000000-0000-4000-8000-000000000005','30000000-0000-4000-8000-000000000002','Rosa',0,true,20),
('32000000-0000-4000-8000-000000000006','30000000-0000-4000-8000-000000000003','Vermelhas',0,true,10),
('32000000-0000-4000-8000-000000000007','30000000-0000-4000-8000-000000000003','Rosas',0,true,20),
('32000000-0000-4000-8000-000000000008','30000000-0000-4000-8000-000000000003','Brancas',0,true,30),
('32000000-0000-4000-8000-000000000009','30000000-0000-4000-8000-000000000004','Tradicional',0,true,10),
('32000000-0000-4000-8000-000000000010','30000000-0000-4000-8000-000000000004','Com pelúcia',35,true,20),
('32000000-0000-4000-8000-000000000011','30000000-0000-4000-8000-000000000005','Buquê',0,true,10),
('32000000-0000-4000-8000-000000000012','30000000-0000-4000-8000-000000000005','Lapela',-240,true,20),
('32000000-0000-4000-8000-000000000013','30000000-0000-4000-8000-000000000005','Grinalda',-180,true,30),
('32000000-0000-4000-8000-000000000014','30000000-0000-4000-8000-000000000006','3 girassóis',0,true,10),
('32000000-0000-4000-8000-000000000015','30000000-0000-4000-8000-000000000006','6 girassóis',55,true,20)
on conflict(id) do update set name=excluded.name,price_delta=excluded.price_delta,active=excluded.active,sort_order=excluded.sort_order;

insert into public.product_addons(product_id,addon_id) values
('30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001'),
('30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000002'),
('30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000003'),
('30000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000001'),
('30000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000002'),
('30000000-0000-4000-8000-000000000008','20000000-0000-4000-8000-000000000002'),
('30000000-0000-4000-8000-000000000008','20000000-0000-4000-8000-000000000004')
on conflict do nothing;


-- Áreas de entrega de demonstração. Em produção, configure as taxas no painel Admin > Entregas.
insert into public.delivery_zones(id,store_id,name,aliases,city,state,fee,active,sort_order) values
('50000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001','Alphaville','{}','Linhares','ES',10,true,10),
('50000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000001','Araçá','{}','Linhares','ES',8,true,20),
('50000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000001','Aviso','{}','Linhares','ES',10,true,30),
('50000000-0000-4000-8000-000000000004','00000000-0000-4000-8000-000000000001','Bebedouro',array['Bebedouro (bairro/distrito integrado)'],'Linhares','ES',14,true,40),
('50000000-0000-4000-8000-000000000005','00000000-0000-4000-8000-000000000001','Betânia',array['Vila Betânea','Vila Betania'],'Linhares','ES',10,true,50),
('50000000-0000-4000-8000-000000000006','00000000-0000-4000-8000-000000000001','Boa Vista','{}','Linhares','ES',10,true,60),
('50000000-0000-4000-8000-000000000007','00000000-0000-4000-8000-000000000001','Canivete','{}','Linhares','ES',12,true,70),
('50000000-0000-4000-8000-000000000008','00000000-0000-4000-8000-000000000001','Centro','{}','Linhares','ES',8,true,80),
('50000000-0000-4000-8000-000000000009','00000000-0000-4000-8000-000000000001','Colina','{}','Linhares','ES',9,true,90),
('50000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000001','Conceição',array['Nossa Senhora da Conceição','Nossa Senhora da Conceicao'],'Linhares','ES',9,true,100),
('50000000-0000-4000-8000-000000000011','00000000-0000-4000-8000-000000000001','Farias',array['Farias (área urbana)','Farias (area urbana)'],'Linhares','ES',12,true,110),
('50000000-0000-4000-8000-000000000012','00000000-0000-4000-8000-000000000001','Gaivotas','{}','Linhares','ES',10,true,120),
('50000000-0000-4000-8000-000000000013','00000000-0000-4000-8000-000000000001','Interlagos','{}','Linhares','ES',10,true,130),
('50000000-0000-4000-8000-000000000014','00000000-0000-4000-8000-000000000001','Jardim Laguna',array['Jardim Laguna I','Jardim Laguna II','Jardim Laguna (I e II)'],'Linhares','ES',10,true,140),
('50000000-0000-4000-8000-000000000015','00000000-0000-4000-8000-000000000001','Jocafe',array['Jocafe I','Jocafe II','Jocafe (I e II)'],'Linhares','ES',10,true,150),
('50000000-0000-4000-8000-000000000016','00000000-0000-4000-8000-000000000001','José Rodrigues Maciel',array['Jose Rodrigues Maciel'],'Linhares','ES',10,true,160),
('50000000-0000-4000-8000-000000000017','00000000-0000-4000-8000-000000000001','Juparanã',array['Juparana'],'Linhares','ES',10,true,170),
('50000000-0000-4000-8000-000000000018','00000000-0000-4000-8000-000000000001','Lagoa do Meio','{}','Linhares','ES',10,true,180),
('50000000-0000-4000-8000-000000000019','00000000-0000-4000-8000-000000000001','Linhares V','{}','Linhares','ES',12,true,190),
('50000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000001','Movelar',array['Mobrasa','Movelar (incluindo Mobrasa)'],'Linhares','ES',10,true,200),
('50000000-0000-4000-8000-000000000021','00000000-0000-4000-8000-000000000001','Nova Esperança',array['Nova Esperanca'],'Linhares','ES',10,true,210),
('50000000-0000-4000-8000-000000000022','00000000-0000-4000-8000-000000000001','Novo Horizonte','{}','Linhares','ES',10,true,220),
('50000000-0000-4000-8000-000000000023','00000000-0000-4000-8000-000000000001','Olaria','{}','Linhares','ES',9,true,230),
('50000000-0000-4000-8000-000000000024','00000000-0000-4000-8000-000000000001','Palmital','{}','Linhares','ES',10,true,240),
('50000000-0000-4000-8000-000000000025','00000000-0000-4000-8000-000000000001','Planalto','{}','Linhares','ES',10,true,250),
('50000000-0000-4000-8000-000000000026','00000000-0000-4000-8000-000000000001','Residencial Rio Doce','{}','Linhares','ES',12,true,260),
('50000000-0000-4000-8000-000000000027','00000000-0000-4000-8000-000000000001','Rio Quartel',array['Rio Quartel (área urbana)','Rio Quartel (area urbana)'],'Linhares','ES',14,true,270),
('50000000-0000-4000-8000-000000000028','00000000-0000-4000-8000-000000000001','Santa Cruz','{}','Linhares','ES',10,true,280),
('50000000-0000-4000-8000-000000000029','00000000-0000-4000-8000-000000000001','Shell',array['Pó do Shell','Po do Shell','Shell (incluindo Pó do Shell)'],'Linhares','ES',9,true,290),
('50000000-0000-4000-8000-000000000030','00000000-0000-4000-8000-000000000001','Três Barras',array['Tres Barras'],'Linhares','ES',10,true,300),
('50000000-0000-4000-8000-000000000031','00000000-0000-4000-8000-000000000001','Vila Isabel','{}','Linhares','ES',10,true,310)
on conflict(id) do update set name=excluded.name,aliases=excluded.aliases,city=excluded.city,state=excluded.state,fee=excluded.fee,active=excluded.active,sort_order=excluded.sort_order;

insert into public.store_subscriptions(id,store_id,plan_id,status,started_at)
values('41000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000001','trial',now())
on conflict(id) do update set plan_id=excluded.plan_id,status=excluded.status;
