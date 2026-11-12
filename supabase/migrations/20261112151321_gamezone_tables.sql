-- Game Zone v2 (D-157), part 1: tables, content (Word War words, Memory Flash cards), avatars, realtime topics.

create table if not exists public.gz_matches (
  id uuid primary key default gen_random_uuid(),
  game text not null check (game in ('duel', 'rush', 'survival', 'blitz', 'words', 'memory', 'relay')),
  mode text not null check (mode in ('quick', 'ai', 'friend', 'ranked')),
  subject_id smallint,
  exam_id smallint not null default 1,
  status text not null default 'lobby' check (status in ('lobby', 'playing', 'done', 'cancelled')),
  code text unique,
  level text not null default 'medium' check (level in ('easy', 'medium', 'hard')),
  max_players smallint not null default 2,
  min_players smallint not null default 2,
  seconds smallint not null default 15,
  gap_ms integer not null default 3500,
  rounds smallint not null default 10,
  target smallint not null default 10,
  starts_at timestamptz,
  ends_at timestamptz,
  lobby_until timestamptz,
  items jsonb not null default '[]',
  keys jsonb not null default '[]',
  settled smallint not null default 0,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  finished_at timestamptz
);
create index if not exists gz_matches_open on public.gz_matches (game, status, subject_id) where status = 'lobby';
create index if not exists gz_matches_recent on public.gz_matches (created_at desc);
alter table public.gz_matches enable row level security;
create policy "staff read" on public.gz_matches for select using (private.is_staff());

create table if not exists public.gz_players (
  id bigint generated always as identity primary key,
  match_id uuid not null references public.gz_matches (id) on delete cascade,
  user_id uuid references auth.users (id) on delete cascade,
  bot jsonb,
  name text not null,
  team smallint not null default 0,
  score integer not null default 0,
  correct smallint not null default 0,
  answered smallint not null default 0,
  lives smallint not null default 3,
  alive boolean not null default true,
  out_round smallint,
  pos smallint not null default 0,
  last_at timestamptz,
  penalty_until timestamptz,
  combo smallint not null default 0,
  best_combo smallint not null default 0,
  finished_at timestamptz,
  place smallint,
  rating_before integer,
  rating_delta integer,
  xp integer not null default 0,
  joined_at timestamptz not null default now(),
  unique (match_id, user_id)
);
create index if not exists gz_players_user on public.gz_players (user_id, joined_at desc);
alter table public.gz_players enable row level security;
create policy "staff read" on public.gz_players for select using (private.is_staff());

create table if not exists public.gz_answers (
  match_id uuid not null references public.gz_matches (id) on delete cascade,
  player_id bigint not null references public.gz_players (id) on delete cascade,
  idx smallint not null,
  choice text,
  correct boolean not null,
  ms integer not null,
  points integer not null,
  at timestamptz not null default now(),
  primary key (match_id, player_id, idx)
);
alter table public.gz_answers enable row level security;

create table if not exists public.gz_queue (
  user_id uuid primary key references auth.users (id) on delete cascade,
  game text not null,
  subject_id smallint,
  ranked boolean not null default false,
  rating integer not null default 1000,
  joined_at timestamptz not null default now(),
  match_id uuid
);
alter table public.gz_queue enable row level security;

create table if not exists public.gz_ratings (
  user_id uuid not null references auth.users (id) on delete cascade,
  game text not null,
  rating integer not null default 1000,
  played integer not null default 0,
  won integer not null default 0,
  streak integer not null default 0,
  best_streak integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, game)
);
create index if not exists gz_ratings_board on public.gz_ratings (game, rating desc);
alter table public.gz_ratings enable row level security;
create policy "staff read" on public.gz_ratings for select using (private.is_staff());

-- Word War words and Memory Flash cards (admin-editable in Admin → Games).
create table if not exists public.gz_words (
  id bigint generated always as identity primary key,
  kind text not null check (kind in ('synonym', 'antonym', 'spelling')),
  word text not null,
  answer text not null,
  wrong text[] not null check (cardinality(wrong) >= 3),
  active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.gz_words enable row level security;
create policy "staff read" on public.gz_words for select using (private.is_staff());
create policy "staff edit" on public.gz_words for all using (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]));

create table if not exists public.gz_cards (
  id bigint generated always as identity primary key,
  subject_id smallint not null,
  front text not null,
  back text not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.gz_cards enable row level security;
create policy "staff read" on public.gz_cards for select using (private.is_staff());
create policy "staff edit" on public.gz_cards for all using (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]));

-- The student's game avatar when they have no photo (or hide it): skin, hair, hairColor, shirt, glasses.
alter table public.community_profiles add column if not exists game_avatar jsonb;

-- Live topics: gz:<match> for its players, gzu:<user> for "match found".
create or replace function private.tutor_topic_ok(p_topic text)
returns boolean language sql stable security definer set search_path = '' as $$
  select case
    when p_topic ~ '^tutor:[0-9a-f-]{36}$' then private.tutor_chat_member(substr(p_topic, 7)::uuid)
    when p_topic ~ '^user:[0-9a-f-]{36}$' then substr(p_topic, 6)::uuid = (select auth.uid())
    when p_topic ~ '^cnote:[0-9a-f-]{36}$' then substr(p_topic, 7)::uuid = (select auth.uid())
    when p_topic ~ '^gzu:[0-9a-f-]{36}$' then substr(p_topic, 5)::uuid = (select auth.uid())
    when p_topic ~ '^gz:[0-9a-f-]{36}$' then exists (select 1 from public.gz_players p where p.match_id = substr(p_topic, 4)::uuid and p.user_id = (select auth.uid()))
    else false end;
$$;

-- Settings (admin-editable): which games are on, XP.
update public.app_settings set value = value || jsonb_build_object('gz', jsonb_build_object(
  'on', jsonb_build_object('duel', true, 'rush', true, 'survival', true, 'blitz', true, 'words', true, 'memory', true, 'relay', true),
  'xp_play', 5, 'xp_win', 15, 'queue_seconds', 15))
where key = 'games' and not (value ? 'gz');

-- ---------- starter content ----------
insert into public.gz_words (kind, word, answer, wrong) values
('synonym','abundant','plentiful','{scarce,rare,meagre}'),('synonym','candid','frank','{secretive,shy,cunning}'),
('synonym','diligent','hardworking','{lazy,careless,idle}'),('synonym','eloquent','articulate','{tongue-tied,silent,clumsy}'),
('synonym','frugal','thrifty','{wasteful,lavish,greedy}'),('synonym','gregarious','sociable','{reserved,lonely,hostile}'),
('synonym','hostile','unfriendly','{welcoming,warm,kind}'),('synonym','imminent','impending','{distant,remote,past}'),
('synonym','jovial','cheerful','{gloomy,sad,serious}'),('synonym','lucid','clear','{confusing,vague,dark}'),
('synonym','meticulous','careful','{sloppy,careless,hasty}'),('synonym','novice','beginner','{expert,veteran,master}'),
('synonym','obsolete','outdated','{modern,current,new}'),('synonym','placid','calm','{agitated,stormy,angry}'),
('synonym','prudent','wise','{reckless,foolish,rash}'),('synonym','reluctant','unwilling','{eager,keen,ready}'),
('synonym','scrutinise','examine','{ignore,overlook,neglect}'),('synonym','tenacious','persistent','{weak,yielding,feeble}'),
('synonym','vivid','bright','{dull,faint,pale}'),('synonym','wary','cautious','{careless,trusting,bold}'),
('synonym','zeal','enthusiasm','{apathy,boredom,indifference}'),('synonym','benevolent','kind','{cruel,mean,spiteful}'),
('synonym','commence','begin','{end,finish,stop}'),('synonym','deteriorate','worsen','{improve,recover,heal}'),
('synonym','enormous','huge','{tiny,small,minute}'),('synonym','feasible','possible','{impossible,unlikely,absurd}'),
('synonym','hilarious','funny','{tragic,sad,dull}'),('synonym','inquisitive','curious','{uninterested,bored,indifferent}'),
('synonym','lethargic','sluggish','{energetic,lively,active}'),('synonym','mundane','ordinary','{exciting,unusual,rare}'),
('synonym','ominous','threatening','{hopeful,promising,cheerful}'),('synonym','pensive','thoughtful','{carefree,careless,cheerful}'),
('synonym','resilient','tough','{fragile,weak,delicate}'),('synonym','sporadic','occasional','{constant,regular,steady}'),
('synonym','trivial','unimportant','{vital,crucial,serious}'),('synonym','vanish','disappear','{appear,emerge,arrive}'),
('synonym','affluent','wealthy','{poor,needy,broke}'),('synonym','concise','brief','{lengthy,wordy,long}'),
('synonym','eradicate','eliminate','{create,plant,keep}'),('synonym','gullible','naive','{suspicious,shrewd,wise}'),
('antonym','generous','stingy','{kind,lavish,gentle}'),('antonym','ancient','modern','{old,aged,antique}'),
('antonym','brave','cowardly','{bold,daring,heroic}'),('antonym','scarce','abundant','{rare,limited,few}'),
('antonym','humble','arrogant','{modest,meek,simple}'),('antonym','expand','contract','{grow,enlarge,swell}'),
('antonym','victory','defeat','{triumph,win,success}'),('antonym','permanent','temporary','{lasting,fixed,stable}'),
('antonym','optimist','pessimist','{idealist,dreamer,believer}'),('antonym','artificial','natural','{fake,synthetic,false}'),
('antonym','superior','inferior','{better,greater,higher}'),('antonym','vague','precise','{unclear,hazy,blurred}'),
('antonym','hostile','friendly','{aggressive,unkind,cold}'),('antonym','obedient','rebellious','{dutiful,loyal,faithful}'),
('antonym','prosperity','poverty','{wealth,success,plenty}'),('antonym','reveal','conceal','{show,expose,display}'),
('antonym','accept','reject','{receive,take,welcome}'),('antonym','fertile','barren','{fruitful,rich,productive}'),
('antonym','transparent','opaque','{clear,see-through,lucid}'),('antonym','external','internal','{outer,outside,exterior}'),
('antonym','majority','minority','{most,bulk,greater}'),('antonym','increase','decrease','{grow,rise,raise}'),
('antonym','guilty','innocent','{culpable,responsible,blamable}'),('antonym','famous','obscure','{renowned,popular,known}'),
('antonym','condemn','praise','{blame,criticise,denounce}'),('antonym','visible','invisible','{seen,clear,obvious}'),
('antonym','ascend','descend','{climb,rise,mount}'),('antonym','harmony','discord','{peace,unity,agreement}'),
('antonym','sincere','insincere','{honest,genuine,true}'),('antonym','lenient','strict','{mild,gentle,tolerant}'),
('antonym','courteous','rude','{polite,civil,gracious}'),('antonym','frequent','rare','{common,regular,often}'),
('antonym','maximum','minimum','{greatest,most,peak}'),('antonym','encourage','discourage','{support,cheer,inspire}'),
('antonym','import','export','{bring,carry,receive}'),('antonym','vertical','horizontal','{upright,erect,standing}'),
('spelling','accommodate','accommodate','{accomodate,acommodate,accommadate}'),('spelling','necessary','necessary','{neccessary,necesary,neccesary}'),
('spelling','embarrass','embarrass','{embarass,embarras,embaras}'),('spelling','separate','separate','{seperate,separete,seprate}'),
('spelling','definitely','definitely','{definately,definitly,defenitely}'),('spelling','occurrence','occurrence','{occurence,occurrance,ocurrence}'),
('spelling','committee','committee','{commitee,comittee,committe}'),('spelling','privilege','privilege','{priviledge,privilage,privelege}'),
('spelling','rhythm','rhythm','{rythm,rhythym,rythem}'),('spelling','conscience','conscience','{concience,consience,conscence}'),
('spelling','government','government','{goverment,governmant,govenment}'),('spelling','independent','independent','{independant,indipendent,independint}'),
('spelling','maintenance','maintenance','{maintainance,maintenence,maintanance}'),('spelling','millennium','millennium','{millenium,milennium,millenniam}'),
('spelling','occasion','occasion','{ocassion,occassion,ocasion}'),('spelling','possession','possession','{posession,possesion,posesion}'),
('spelling','recommend','recommend','{reccomend,recomend,reccommend}'),('spelling','successful','successful','{succesful,successfull,sucessful}'),
('spelling','tomorrow','tomorrow','{tommorow,tommorrow,tomorow}'),('spelling','weird','weird','{wierd,weerd,wiard}'),
('spelling','beginning','beginning','{begining,beggining,beginnig}'),('spelling','environment','environment','{enviroment,environmant,envirnment}'),
('spelling','guarantee','guarantee','{garantee,guarentee,guaranty}'),('spelling','knowledge','knowledge','{knowlege,knowladge,knoledge}'),
('spelling','parliament','parliament','{parliment,parlament,parliamant}'),('spelling','questionnaire','questionnaire','{questionaire,questionnair,questionnare}');

insert into public.gz_cards (subject_id, front, back) values
(4,'Na','Sodium'),(4,'K','Potassium'),(4,'Fe','Iron'),(4,'Pb','Lead'),(4,'Cu','Copper'),(4,'Ag','Silver'),(4,'Au','Gold'),(4,'Hg','Mercury'),
(4,'Sn','Tin'),(4,'Ca','Calcium'),(4,'Mg','Magnesium'),(4,'Zn','Zinc'),(4,'Cl','Chlorine'),(4,'S','Sulphur'),(4,'P','Phosphorus'),(4,'Al','Aluminium'),
(4,'H₂O','Water'),(4,'NaCl','Common salt'),(4,'CO₂','Carbon dioxide'),(4,'H₂SO₄','Sulphuric acid'),(4,'HCl','Hydrochloric acid'),(4,'NH₃','Ammonia'),
(4,'CaCO₃','Limestone'),(4,'CH₄','Methane'),
(3,'v = fλ','Wave speed'),(3,'F = ma','Newton''s 2nd law'),(3,'V = IR','Ohm''s law'),(3,'P = IV','Electrical power'),(3,'E = mc²','Mass-energy'),
(3,'KE = ½mv²','Kinetic energy'),(3,'PE = mgh','Potential energy'),(3,'p = mv','Momentum'),(3,'P = F/A','Pressure'),(3,'ρ = m/V','Density'),
(3,'W = Fd','Work done'),(3,'T = 1/f','Period'),(3,'Newton (N)','Force'),(3,'Joule (J)','Energy'),(3,'Watt (W)','Power'),(3,'Pascal (Pa)','Pressure unit'),
(3,'Ohm (Ω)','Resistance'),(3,'Hertz (Hz)','Frequency'),(3,'Coulomb (C)','Charge'),(3,'Tesla (T)','Magnetic field'),
(2,'πr²','Area of a circle'),(2,'2πr','Circumference'),(2,'a² + b² = c²','Pythagoras'),(2,'½bh','Area of a triangle'),(2,'l × b','Area of a rectangle'),
(2,'πr²h','Volume of a cylinder'),(2,'⁴⁄₃πr³','Volume of a sphere'),(2,'(−b ± √(b²−4ac))/2a','Quadratic formula'),(2,'sin θ / cos θ','tan θ'),
(2,'a + (n−1)d','nth term of an AP'),(2,'arⁿ⁻¹','nth term of a GP'),(2,'(y₂−y₁)/(x₂−x₁)','Gradient'),(2,'180°','Angles in a triangle'),
(2,'360°','Angles at a point'),(2,'√144','12'),(2,'2⁵','32'),(2,'log₁₀ 1000','3'),(2,'0.25','¼'),(2,'15% of 200','30'),(2,'7 × 8','56'),
(5,'Mitochondrion','Respiration (energy)'),(5,'Ribosome','Protein synthesis'),(5,'Chloroplast','Photosynthesis'),(5,'Nucleus','Controls the cell'),
(5,'Xylem','Carries water'),(5,'Phloem','Carries food'),(5,'Haemoglobin','Carries oxygen'),(5,'Insulin','Lowers blood sugar'),
(5,'Stomata','Gas exchange in leaves'),(5,'Nephron','Kidney unit'),(5,'Neuron','Nerve cell'),(5,'Alveoli','Air sacs in lungs'),
(5,'Plasmodium','Malaria parasite'),(5,'Vitamin C','Prevents scurvy'),(5,'Vitamin D','Strong bones'),(5,'Pepsin','Digests protein'),
(5,'Amylase','Digests starch'),(5,'Lipase','Digests fats'),(5,'Producer','Makes its own food'),(5,'Herbivore','Eats plants'),
(1,'Synonym','Same meaning'),(1,'Antonym','Opposite meaning'),(1,'Noun','Naming word'),(1,'Verb','Doing word'),(1,'Adjective','Describes a noun'),
(1,'Adverb','Describes a verb'),(1,'Simile','Compares with like or as'),(1,'Metaphor','Says one thing is another'),(1,'Hyperbole','Exaggeration'),
(1,'Onomatopoeia','Word that sounds like its meaning'),(1,'Personification','Human traits for things'),(1,'Alliteration','Same first sound repeated');
