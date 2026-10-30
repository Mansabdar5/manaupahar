-- ManaUpahar sample test data
-- Run setup.sql and all required upgrade scripts first (especially upgrade-v5.sql and upgrade-v6.sql).
-- Paste into Supabase SQL Editor and Run. Safe to rerun: these sample IDs are replaced.
-- WARNING: This inserts fictional products and orders. Remove them before going live.

begin;

-- Remove only this seed pack's previous records (not real shop data).
delete from public.orders where id in (
 'd0000000-0000-4000-8000-000000000001',
 'd0000000-0000-4000-8000-000000000002',
 'd0000000-0000-4000-8000-000000000003',
 'd0000000-0000-4000-8000-000000000004'
);
delete from public.products where id in (
 'a0000000-0000-4000-8000-000000000001',
 'a0000000-0000-4000-8000-000000000002',
 'a0000000-0000-4000-8000-000000000003',
 'a0000000-0000-4000-8000-000000000004',
 'a0000000-0000-4000-8000-000000000005',
 'a0000000-0000-4000-8000-000000000006',
 'a0000000-0000-4000-8000-000000000007',
 'a0000000-0000-4000-8000-000000000008'
);
delete from public.addons where id in (
 'b0000000-0000-4000-8000-000000000001',
 'b0000000-0000-4000-8000-000000000002',
 'b0000000-0000-4000-8000-000000000003'
);
delete from public.delivery_zones where id in (
 'c0000000-0000-4000-8000-000000000001',
 'c0000000-0000-4000-8000-000000000002',
 'c0000000-0000-4000-8000-000000000003'
);

insert into public.products
(id,name,category,price,description,stock,images,personalise,personalise_label,featured,material,made_by,region,size,care,prep_days,occasions,created_at)
values
('a0000000-0000-4000-8000-000000000001','Hand-painted Terracotta Vase','Pottery & Terracotta',699,'Wheel-thrown clay vase with hand-painted botanical motifs.',6,'{}',false,null,true,'Terracotta','Lakshmi Pottery Group','Hyderabad, Telangana','9 in tall','Wipe with a dry cloth.',0,array['Housewarming','Festival'],now()-interval '2 days'),
('a0000000-0000-4000-8000-000000000002','Carved Wooden Name Plate','Wood & Bamboo',1299,'Personalised solid-wood name plate, carved and finished by hand.',5,'{}',true,'Name or house number to carve',true,'Mango wood','Ravi Woodcraft Collective','Nirmal, Telangana','12 x 6 in','Keep dry; wipe with a soft cloth.',5,array['Housewarming','Wedding'],now()-interval '1 day'),
('a0000000-0000-4000-8000-000000000003','Handloom Cotton Table Runner','Textiles & Handloom',899,'Natural cotton runner with hand-knotted fringe.',2,'{}',false,null,true,'Cotton','Sakhi Weavers','Pochampally, Telangana','14 x 60 in','Gentle hand wash in cold water.',0,array['Housewarming','Festival'],now()-interval '5 days'),
('a0000000-0000-4000-8000-000000000004','Brass Diya Set of 4','Metal & Brass',999,'Four hand-polished brass diyas in a reusable gift box.',8,'{}',false,null,false,'Brass','Kashi Metal Artisans','Warangal, Telangana','2.5 in each','Polish with a soft dry cloth.',0,array['Festival','Housewarming'],now()-interval '4 days'),
('a0000000-0000-4000-8000-000000000005','Cheriyal Folk Art Panel','Paintings & Folk Art',1499,'Traditional folk-art inspired painting on handmade paper.',0,'{}',false,null,false,'Natural colours on handmade paper','Rangula Art Studio','Cheriyal, Telangana','A4','Keep away from direct sunlight and moisture.',0,array['Wedding','Thank you'],now()-interval '3 days'),
('a0000000-0000-4000-8000-000000000006','Bamboo Desk Organiser','Wood & Bamboo',449,'Compact desk organiser made from sustainably sourced bamboo.',12,'{}',false,null,false,'Bamboo','Green Craft Makers','Adilabad, Telangana','8 x 4 x 4 in','Wipe clean with a dry cloth.',0,array['Birthday','Thank you'],now()-interval '6 days'),
('a0000000-0000-4000-8000-000000000007','Warli Art Wall Frame','Paintings & Folk Art',1899,'Hand-painted tribal-art inspired frame, made to order.',3,'{}',false,null,false,'Acrylic on wood','Asha Artisan Group','Maharashtra','12 x 16 in','Dust with a soft brush.',7,array['Wedding','Housewarming'],now()-interval '7 days'),
('a0000000-0000-4000-8000-000000000008','Palm Leaf Bookmark Set','Natural Fibre Crafts',199,'Set of three handwoven palm-leaf bookmarks.',20,'{}',false,null,false,'Palm leaf','Vanam Self Help Group','Telangana','2 x 6 in each','Keep dry.',0,array['Birthday','Thank you'],now()-interval '8 days');

insert into public.addons (id,name,price,per_item,active) values
('b0000000-0000-4000-8000-000000000001','Gift box packaging',79,true,true),
('b0000000-0000-4000-8000-000000000002','Handwritten message card',29,false,true),
('b0000000-0000-4000-8000-000000000003','Story card about the artisan',19,true,true);

insert into public.delivery_zones (id,label,pincodes,charge,free_above,active) values
('c0000000-0000-4000-8000-000000000001','Hyderabad local','500',60,1500,true),
('c0000000-0000-4000-8000-000000000002','Nearby Telangana towns','501, 502, 503, 504, 505',120,null,true),
('c0000000-0000-4000-8000-000000000003','Test exact pincode','500081',40,1000,true);

insert into public.settings(key,value) values
('whatsapp','919876543210'),
('note','Demo shop: payment and delivery details will be confirmed on WhatsApp.'),
('handmade_note','Every item is handmade; small variations make each piece unique.'),
('lead_days','1'),
('about','ManaUpahar celebrates thoughtful handmade gifts from Indian artisan communities.'),
('delivery','Sample delivery rates are for testing only. Confirm serviceability and charges on WhatsApp.')
on conflict (key) do update set value=excluded.value;

-- Illustrative admin-side order records. Names/addresses are intentionally not included.
insert into public.orders (id,ref,items,total,status,delivery_date,created_at) values
('d0000000-0000-4000-8000-000000000001','MU-TEST01',
 '[{"id":"a0000000-0000-4000-8000-000000000001","kind":"gift","name":"Hand-painted Terracotta Vase","price":699,"qty":1,"note":""},{"id":"b0000000-0000-4000-8000-000000000001","kind":"addon","name":"Gift box packaging","price":79,"qty":1},{"id":"delivery","kind":"delivery","name":"Delivery – Hyderabad local (500081)","price":60,"qty":1}]'::jsonb,
 838,'new',to_char(current_date+3,'YYYY-MM-DD'),now()-interval '2 hours'),
('d0000000-0000-4000-8000-000000000002','MU-TEST02',
 '[{"id":"a0000000-0000-4000-8000-000000000002","kind":"gift","name":"Carved Wooden Name Plate","price":1299,"qty":1,"note":"Sharma Family"}]'::jsonb,
 1299,'confirmed',to_char(current_date+8,'YYYY-MM-DD'),now()-interval '1 day'),
('d0000000-0000-4000-8000-000000000003','MU-TEST03',
 '[{"id":"a0000000-0000-4000-8000-000000000004","kind":"gift","name":"Brass Diya Set of 4","price":999,"qty":2,"note":""},{"id":"b0000000-0000-4000-8000-000000000002","kind":"addon","name":"Handwritten message card","price":29,"qty":1}]'::jsonb,
 2027,'delivered',null,now()-interval '10 days'),
('d0000000-0000-4000-8000-000000000004','MU-TEST04',
 '[{"id":"a0000000-0000-4000-8000-000000000005","kind":"gift","name":"Cheriyal Folk Art Panel","price":1499,"qty":1,"note":""}]'::jsonb,
 1499,'cancelled',null,now()-interval '4 days');

commit;
