// KID CONTOUR screens — each is an artboard-ready React component
const { HS, Butterfly, Phone, Display, Title, Body, Mono, KidCTA, KidTile, Chip, Ring, Bar, Placeholder, Pict, KidTabBar, Speech, Sparkle, Cloud, Star } = window;

const KID_BG = `linear-gradient(180deg, oklch(0.96 0.03 60) 0%, oklch(0.97 0.025 80) 100%)`;

// Soft sun / background decoration
function KidBgDecor({ theme = 'day' }) {
  return (
    <>
      <Cloud size={80} opacity={0.85} style={{ position: 'absolute', top: 60, left: -20 }}/>
      <Cloud size={50} opacity={0.7} style={{ position: 'absolute', top: 100, right: 10 }}/>
      <div style={{ position: 'absolute', top: -40, right: -40, width: 140, height: 140, borderRadius: 70,
        background: 'radial-gradient(circle, oklch(0.92 0.10 80) 0%, transparent 70%)' }}/>
    </>
  );
}

// 1) Splash
function SplashScreen() {
  return (
    <Phone bg="linear-gradient(180deg, oklch(0.72 0.17 35), oklch(0.62 0.18 20))">
      <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', color: '#fff' }}>
        <Butterfly size={160} mood="celebrating" sparkles/>
        <Display size={40} color="#fff" style={{ marginTop: 24, letterSpacing: -1 }}>HappySpeech</Display>
        <div style={{ fontFamily: HS.font.display, fontSize: 14, opacity: 0.85, marginTop: 4, letterSpacing: 2, textTransform: 'uppercase' }}>Говорим волшебно</div>
        <div style={{ position: 'absolute', bottom: 80, width: 60, height: 3, background: 'rgba(255,255,255,0.4)', borderRadius: 2, overflow: 'hidden' }}>
          <div style={{ width: '60%', height: '100%', background: '#fff', borderRadius: 2 }}/>
        </div>
      </div>
    </Phone>
  );
}

// 2) Welcome / Intro carousel
function WelcomeScreen() {
  return (
    <Phone bg={KID_BG}>
      <KidBgDecor/>
      <div style={{ position: 'absolute', inset: 0, padding: '40px 24px 24px', display: 'flex', flexDirection: 'column' }}>
        <Mono color={HS.kid.inkMuted}>1 / 4</Mono>
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center' }}>
          <Butterfly size={140} mood="happy" sparkles/>
          <Display size={28} color={HS.kid.ink} style={{ marginTop: 24 }}>Привет! Я Ляля —<br/>твоя подружка-бабочка</Display>
          <Body size={14} color={HS.kid.inkMuted} style={{ marginTop: 12, maxWidth: 240 }}>
            Вместе мы будем учиться говорить звонко, красиво и весело.
          </Body>
        </div>
        <div style={{ display: 'flex', justifyContent: 'center', gap: 6, marginBottom: 16 }}>
          {[0,1,2,3].map(i => <div key={i} style={{ width: i === 0 ? 20 : 6, height: 6, borderRadius: 3, background: i === 0 ? HS.brand.primary : HS.kid.line }}/>)}
        </div>
        <KidCTA label="Продолжить →" style={{ justifyContent: 'center' }}/>
      </div>
    </Phone>
  );
}

// 3) Role select
function RoleSelectScreen() {
  return (
    <Phone bg={HS.kid.bg}>
      <div style={{ padding: '40px 24px' }}>
        <Title color={HS.kid.ink} size={26}>Кто вы?</Title>
        <Body color={HS.kid.inkMuted} style={{ marginTop: 6 }}>Выберите профиль, чтобы начать.</Body>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 14, marginTop: 24 }}>
          {[
            ['Родитель', 'Настройка и контроль', HS.brand.sky, '👨‍👩‍👧'],
            ['Логопед', 'Специалист, занятия', HS.brand.lilac, '🎓'],
            ['Ребёнок продолжает', 'Если профиль уже создан', HS.brand.mint, '🌱'],
          ].map(([t, s, c, e]) => (
            <div key={t} style={{ background: '#fff', borderRadius: 20, padding: 18, display: 'flex', alignItems: 'center', gap: 14, boxShadow: HS.kid.shadow }}>
              <div style={{ width: 52, height: 52, borderRadius: 16, background: `color-mix(in oklch, ${c} 20%, white)`, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 26 }}>{e}</div>
              <div style={{ flex: 1 }}>
                <Title size={17} color={HS.kid.ink}>{t}</Title>
                <Body size={12} color={HS.kid.inkMuted}>{s}</Body>
              </div>
              <div style={{ color: HS.kid.inkSoft, fontSize: 18 }}>›</div>
            </div>
          ))}
        </div>
      </div>
    </Phone>
  );
}

// 4) Sign up
function SignUpScreen() {
  return (
    <Phone bg={HS.parent.bg}>
      <div style={{ padding: '40px 24px' }}>
        <Title color={HS.parent.ink} size={26}>Создать аккаунт</Title>
        <Body color={HS.parent.inkMuted} style={{ marginTop: 6 }}>Для синхронизации между устройствами.</Body>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12, marginTop: 24 }}>
          {[
            ['Имя родителя', 'Анна'],
            ['E-mail', 'anna@example.com'],
            ['Пароль', '••••••••'],
          ].map(([l, v]) => (
            <div key={l}>
              <Mono color={HS.parent.inkMuted} style={{ marginBottom: 4 }}>{l.toUpperCase()}</Mono>
              <div style={{ background: '#fff', border: `1px solid ${HS.parent.line}`, borderRadius: 12, padding: '12px 14px', fontSize: 15, color: HS.parent.ink }}>{v}</div>
            </div>
          ))}
          <div style={{ background: HS.sem.infoBg, borderRadius: 12, padding: 12, display: 'flex', gap: 10, marginTop: 6 }}>
            <div style={{ width: 20, height: 20, borderRadius: 10, background: HS.sem.info, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 12, flexShrink: 0 }}>i</div>
            <Body size={11} color={HS.sem.info}>Мы не храним аудио ребёнка в облаке без вашего разрешения. Всё — оффлайн.</Body>
          </div>
          <div style={{ background: HS.parent.accent, color: '#fff', padding: 14, borderRadius: 14, textAlign: 'center', fontWeight: 600, marginTop: 6 }}>Продолжить</div>
          <div style={{ textAlign: 'center', color: HS.parent.inkSoft, fontSize: 13, marginTop: 4 }}>или Apple ID</div>
        </div>
      </div>
    </Phone>
  );
}

// 5) Add child profile
function AddChildScreen() {
  return (
    <Phone bg={KID_BG}>
      <div style={{ padding: '40px 24px' }}>
        <Title color={HS.kid.ink} size={24}>Кто будет заниматься?</Title>
        <Body color={HS.kid.inkMuted} style={{ marginTop: 6 }}>Первый профиль ребёнка</Body>
        <div style={{ display: 'flex', justifyContent: 'center', margin: '24px 0' }}>
          <div style={{ width: 100, height: 100, borderRadius: 50, background: HS.brand.mint, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 50, boxShadow: HS.kid.shadow }}>🦊</div>
        </div>
        <div style={{ display: 'flex', justifyContent: 'center', gap: 8, marginBottom: 20 }}>
          {['🦊','🐰','🐼','🦁','🐻','🦄'].map((e,i) => (
            <div key={i} style={{ width: 36, height: 36, borderRadius: 18, background: i === 0 ? HS.brand.primary : '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 18 }}>{e}</div>
          ))}
        </div>
        <div style={{ background: '#fff', borderRadius: 18, padding: 16, boxShadow: HS.kid.shadow }}>
          {[['Имя','Миша'],['Возраст','6 лет'],['Звуки для работы','Р, Ш']].map(([l,v]) => (
            <div key={l} style={{ padding: '10px 0', borderBottom: `1px solid ${HS.kid.line}`, display: 'flex', justifyContent: 'space-between' }}>
              <Body color={HS.kid.inkMuted} size={13}>{l}</Body>
              <Body color={HS.kid.ink} weight={600} size={13}>{v}</Body>
            </div>
          ))}
        </div>
        <KidCTA label="Создать профиль" style={{ justifyContent: 'center', marginTop: 20 }}/>
      </div>
    </Phone>
  );
}

// 6) Permissions
function PermissionsScreen() {
  return (
    <Phone bg={KID_BG}>
      <div style={{ padding: '40px 24px', display: 'flex', flexDirection: 'column', height: '100%' }}>
        <div style={{ display: 'flex', justifyContent: 'center' }}>
          <Butterfly size={96} mood="listening"/>
        </div>
        <Title color={HS.kid.ink} size={22} style={{ textAlign: 'center', marginTop: 12 }}>Нам понадобятся разрешения</Title>
        <Body color={HS.kid.inkMuted} style={{ textAlign: 'center', marginTop: 6 }}>Чтобы слушать, как ты говоришь, и показывать тебе в зеркале.</Body>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginTop: 22 }}>
          {[
            ['🎤','Микрофон','Слушать речь во время игр', true],
            ['📷','Камера','AR-зеркало и артикуляция', true],
            ['🔔','Уведомления','Напоминания о занятиях', false],
          ].map(([e,t,d,on]) => (
            <div key={t} style={{ background: '#fff', borderRadius: 16, padding: 14, display: 'flex', alignItems: 'center', gap: 12, boxShadow: HS.kid.shadow }}>
              <div style={{ width: 40, height: 40, borderRadius: 12, background: HS.kid.surfaceAlt, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 20 }}>{e}</div>
              <div style={{ flex: 1 }}>
                <Title size={14}>{t}</Title>
                <Body size={11} color={HS.kid.inkMuted}>{d}</Body>
              </div>
              <div style={{ width: 40, height: 24, borderRadius: 12, background: on ? HS.sem.success : HS.kid.line, padding: 2 }}>
                <div style={{ width: 20, height: 20, borderRadius: 10, background: '#fff', marginLeft: on ? 16 : 0 }}/>
              </div>
            </div>
          ))}
        </div>
        <div style={{ flex: 1 }}/>
        <KidCTA label="Разрешить всё" style={{ justifyContent: 'center' }}/>
      </div>
    </Phone>
  );
}

// 7) Kid home
function KidHomeScreen() {
  return (
    <Phone bg={KID_BG}>
      <KidBgDecor/>
      <div style={{ padding: '16px 20px 80px', position: 'relative' }}>
        {/* Greeting */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ width: 44, height: 44, borderRadius: 22, background: HS.brand.mint, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22 }}>🦊</div>
          <div style={{ flex: 1 }}>
            <Body size={11} color={HS.kid.inkMuted}>Доброе утро</Body>
            <Title size={18}>Миша</Title>
          </div>
          <div style={{ background: HS.brand.butter, padding: '6px 10px', borderRadius: 14, display: 'flex', alignItems: 'center', gap: 4, color: 'oklch(0.35 0.10 60)', fontWeight: 700, fontSize: 13 }}>
            <span style={{ fontSize: 14 }}>🔥</span> 7
          </div>
        </div>

        {/* Mission card */}
        <div style={{ background: 'linear-gradient(135deg, oklch(0.75 0.15 30), oklch(0.72 0.14 50))', borderRadius: 24, padding: 18, marginTop: 16, position: 'relative', overflow: 'hidden', color: '#fff', boxShadow: HS.kid.shadowLg }}>
          <Mono style={{ opacity: 0.85, letterSpacing: 1 }}>МИССИЯ НА СЕГОДНЯ</Mono>
          <Title size={22} color="#fff" style={{ marginTop: 4 }}>Спасаем Рычажную поляну</Title>
          <Body size={12} color="#fff" style={{ opacity: 0.9, marginTop: 2 }}>5 игр · ~7 минут · звук Р</Body>
          <div style={{ display: 'flex', gap: 6, marginTop: 12 }}>
            {[1,1,0,0,0].map((v,i) => <div key={i} style={{ flex: 1, height: 6, borderRadius: 3, background: v ? '#fff' : 'rgba(255,255,255,0.3)' }}/>)}
          </div>
          <div style={{ display: 'inline-block', background: '#fff', color: HS.brand.primary, fontFamily: HS.font.display, fontWeight: 800, padding: '10px 20px', borderRadius: 18, marginTop: 14, fontSize: 14, boxShadow: '0 3px 0 rgba(0,0,0,0.08)' }}>Играть ▶</div>
          <div style={{ position: 'absolute', right: -8, bottom: -8 }}>
            <Butterfly size={90} mood="celebrating"/>
          </div>
        </div>

        {/* Quick tiles */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginTop: 16 }}>
          <KidTile color={HS.brand.mint} icon="👄" label="Разминка" sub="2 мин" progress={60}/>
          <KidTile color={HS.brand.lilac} icon="✨" label="AR-зеркало" sub="Покажи язычок"/>
          <KidTile color={HS.brand.sky} icon="👂" label="Слушай-ка" sub="Игра на слух"/>
          <KidTile color={HS.brand.butter} icon="🏆" label="Награды" sub="3 новых"/>
        </div>
      </div>
      <KidTabBar active="home"/>
    </Phone>
  );
}

// 8) World map
function WorldMapScreen() {
  const nodes = [
    { x: 40, y: 520, done: true, label: 'Старт' },
    { x: 180, y: 460, done: true, label: '' },
    { x: 80, y: 400, done: true, label: '' },
    { x: 220, y: 340, active: true, label: 'Рычажная поляна' },
    { x: 100, y: 280, locked: true },
    { x: 210, y: 210, locked: true, label: 'Шипучее озеро' },
    { x: 90, y: 140, locked: true, chest: true },
  ];
  return (
    <Phone bg="linear-gradient(180deg, oklch(0.82 0.08 200) 0%, oklch(0.92 0.06 110) 100%)">
      <div style={{ position: 'absolute', inset: 0, padding: '16px 20px 80px', color: HS.kid.ink }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <Title size={22}>Карта миров</Title>
          <div style={{ background: '#fff', padding: '6px 12px', borderRadius: 14, fontFamily: HS.font.display, fontWeight: 700, fontSize: 12 }}>⭐ 284</div>
        </div>
        <svg viewBox="0 0 300 600" style={{ position: 'absolute', top: 60, left: 0, right: 0, width: '100%', height: 560 }}>
          <path d="M40 520 Q 120 480 180 460 Q 100 420 80 400 Q 180 380 220 340 Q 110 310 100 280 Q 180 240 210 210 Q 110 170 90 140" stroke="oklch(0.82 0.03 70)" strokeWidth="6" strokeDasharray="2 10" strokeLinecap="round" fill="none"/>
        </svg>
        <div style={{ position: 'absolute', top: 60, left: 0, right: 0, height: 560 }}>
          {nodes.map((n, i) => (
            <div key={i} style={{ position: 'absolute', left: n.x, top: n.y, transform: 'translate(-50%, -50%)' }}>
              <div style={{
                width: n.active ? 72 : 54, height: n.active ? 72 : 54, borderRadius: '50%',
                background: n.done ? HS.brand.mint : n.active ? HS.brand.primary : n.chest ? HS.brand.butter : '#fff',
                border: `3px solid ${n.active ? 'oklch(0.55 0.19 30)' : '#fff'}`,
                display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: n.active ? 32 : 22,
                boxShadow: '0 4px 0 rgba(0,0,0,0.1), 0 8px 20px rgba(0,0,0,0.15)',
              }}>{n.done ? '✓' : n.active ? '⭐' : n.chest ? '🎁' : n.locked ? '🔒' : '•'}</div>
              {n.label && <div style={{ position: 'absolute', top: '100%', left: '50%', transform: 'translateX(-50%)', marginTop: 4, background: '#fff', padding: '2px 8px', borderRadius: 8, fontSize: 10, fontWeight: 700, whiteSpace: 'nowrap' }}>{n.label}</div>}
            </div>
          ))}
        </div>
        <Butterfly size={60} mood="happy" style={{ position: 'absolute', top: 330, right: 30 }}/>
      </div>
      <KidTabBar active="map"/>
    </Phone>
  );
}

// 9) Warmup / breathing
function WarmupScreen() {
  return (
    <Phone bg={KID_BG}>
      <div style={{ padding: '16px 20px', display: 'flex', flexDirection: 'column', height: '100%' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ width: 32, height: 32, borderRadius: 16, background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 16 }}>←</div>
          <Bar value={30} color={HS.brand.primary} height={8} style={{ flex: 1 }}/>
          <Mono color={HS.kid.inkMuted}>1/5</Mono>
        </div>
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
          <Title size={20} style={{ textAlign: 'center' }}>Подуй на бабочку!</Title>
          <Body color={HS.kid.inkMuted} style={{ textAlign: 'center', marginTop: 4 }}>Вдох носом, долгий выдох ртом</Body>
          <div style={{ position: 'relative', marginTop: 30 }}>
            <div style={{ width: 220, height: 220, borderRadius: 110, background: `radial-gradient(circle, oklch(0.92 0.08 160) 0%, transparent 70%)`, position: 'absolute', inset: 0 }}/>
            <div style={{ position: 'relative', width: 220, height: 220, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Butterfly size={120} mood="happy"/>
            </div>
          </div>
          <div style={{ marginTop: 24, background: '#fff', padding: 14, borderRadius: 20, display: 'flex', alignItems: 'center', gap: 10, boxShadow: HS.kid.shadow }}>
            <div style={{ width: 40, height: 40, borderRadius: 20, background: HS.sem.success, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff' }}>🎤</div>
            <div>
              <Body weight={700} size={13}>Слушаем дыхание…</Body>
              <Body size={11} color={HS.kid.inkMuted}>Длинный ровный выдох</Body>
            </div>
          </div>
        </div>
        <KidCTA label="Готово!" color={HS.sem.success} dark="oklch(0.52 0.15 150)" style={{ justifyContent: 'center' }}/>
      </div>
    </Phone>
  );
}

// 10) Articulation gymnastics
function ArticulationScreen() {
  return (
    <Phone bg={KID_BG}>
      <div style={{ padding: '16px 20px', height: '100%', display: 'flex', flexDirection: 'column' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ width: 32, height: 32, borderRadius: 16, background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 16 }}>←</div>
          <Bar value={50} color={HS.brand.lilac} height={8} style={{ flex: 1 }}/>
          <Mono color={HS.kid.inkMuted}>2/5</Mono>
        </div>
        <Title size={20} style={{ marginTop: 14 }}>Язычок-художник</Title>
        <Body size={12} color={HS.kid.inkMuted}>Повтори за Лялей</Body>

        <div style={{ marginTop: 14, background: '#fff', borderRadius: 24, padding: 18, boxShadow: HS.kid.shadow, flex: 1, display: 'flex', flexDirection: 'column' }}>
          <Placeholder label="looped video · smile → wide → narrow" h={140} r={16}/>
          <Title size={16} style={{ marginTop: 12 }}>«Заборчик» → «Трубочка»</Title>
          <Body size={12} color={HS.kid.inkMuted} style={{ marginTop: 2 }}>Улыбнись, покажи все зубки. Теперь вытяни губы трубочкой.</Body>
          <div style={{ display: 'flex', gap: 6, marginTop: 10, flexWrap: 'wrap' }}>
            {[1,1,1,0,0,0,0,0].map((v,i) => <div key={i} style={{ width: 18, height: 6, borderRadius: 3, background: v ? HS.brand.lilac : HS.kid.line }}/>)}
            <Mono size={10} color={HS.kid.inkMuted} style={{ marginLeft: 'auto' }}>3 / 8 повторов</Mono>
          </div>
        </div>
        <div style={{ display: 'flex', gap: 10, marginTop: 14 }}>
          <div style={{ flex: 1, background: '#fff', borderRadius: 18, padding: 12, textAlign: 'center', border: `2px solid ${HS.kid.line}`, fontWeight: 700 }}>Пропустить</div>
          <KidCTA label="Получилось!" color={HS.brand.lilac} dark="oklch(0.55 0.14 305)" style={{ flex: 1.5, justifyContent: 'center' }}/>
        </div>
      </div>
    </Phone>
  );
}

// 11) Sound discrimination (listen & choose)
function SoundListenScreen() {
  return (
    <Phone bg={KID_BG}>
      <div style={{ padding: '16px 20px', height: '100%', display: 'flex', flexDirection: 'column' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ width: 32, height: 32, borderRadius: 16, background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 16 }}>←</div>
          <Bar value={70} color={HS.brand.sky} height={8} style={{ flex: 1 }}/>
          <Mono color={HS.kid.inkMuted}>3/5</Mono>
        </div>
        <Title size={20} style={{ marginTop: 14 }}>Где спряталась Ш?</Title>
        <Body size={12} color={HS.kid.inkMuted}>Нажми слово, где слышишь «Ш»</Body>

        <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <div style={{ width: 110, height: 110, borderRadius: 55, background: HS.brand.sky, display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 0 0 12px oklch(0.94 0.04 230), 0 10px 30px rgba(0,100,200,0.2)' }}>
            <div style={{ fontSize: 44, color: '#fff' }}>▶</div>
          </div>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          {[
            ['Мышка', HS.brand.sky, true],
            ['Мишка', HS.brand.mint, false],
            ['Сок', HS.brand.butter, false],
            ['Шапка', HS.brand.lilac, true],
          ].map(([w, c, correct]) => (
            <div key={w} style={{ background: '#fff', borderRadius: 20, padding: 14, textAlign: 'center', boxShadow: HS.kid.shadow, border: `2px solid ${HS.kid.line}` }}>
              <Pict color={c} size={60} glyph={w[0]} style={{ margin: '0 auto' }}/>
              <Title size={15} style={{ marginTop: 8 }}>{w}</Title>
            </div>
          ))}
        </div>
      </div>
    </Phone>
  );
}

// 12) Repeat-after-me / word practice
function WordPracticeScreen() {
  return (
    <Phone bg={KID_BG}>
      <div style={{ padding: '16px 20px', height: '100%', display: 'flex', flexDirection: 'column' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ width: 32, height: 32, borderRadius: 16, background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 16 }}>←</div>
          <Bar value={60} color={HS.brand.primary} height={8} style={{ flex: 1 }}/>
          <Mono color={HS.kid.inkMuted}>4/5</Mono>
        </div>
        <Title size={20} style={{ marginTop: 14 }}>Повтори за Лялей</Title>
        <div style={{ marginTop: 12, background: '#fff', borderRadius: 22, padding: 18, boxShadow: HS.kid.shadow, textAlign: 'center' }}>
          <div style={{ margin: '0 auto' }}>
            <Pict color={HS.brand.primary} size={96} glyph="Р" style={{ margin: '0 auto' }}/>
          </div>
          <Display size={38} style={{ marginTop: 14, color: HS.brand.primary, letterSpacing: -1 }}>РА‑РА‑РА</Display>
          <div style={{ display: 'flex', justifyContent: 'center', gap: 8, marginTop: 10, alignItems: 'center' }}>
            <div style={{ width: 36, height: 36, borderRadius: 18, background: HS.brand.sky, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>▶</div>
            <Body size={12} color={HS.kid.inkMuted}>Послушай ещё раз</Body>
          </div>
        </div>

        <div style={{ flex: 1 }}/>
        {/* Waveform */}
        <div style={{ background: '#fff', borderRadius: 20, padding: 14, boxShadow: HS.kid.shadow, marginBottom: 12 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <div style={{ width: 12, height: 12, borderRadius: 6, background: HS.sem.error }}/>
            <Body size={12} weight={700}>Записываю…</Body>
            <Mono size={11} color={HS.kid.inkMuted} style={{ marginLeft: 'auto' }}>0:02</Mono>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 2, height: 40, marginTop: 8 }}>
            {Array.from({length:36}).map((_,i) => (
              <div key={i} style={{ flex: 1, height: `${20 + Math.sin(i*0.6)*15 + Math.random()*8}px`, background: i < 24 ? HS.brand.primary : HS.kid.line, borderRadius: 2 }}/>
            ))}
          </div>
        </div>
        {/* Big mic button */}
        <div style={{ display: 'flex', justifyContent: 'center' }}>
          <div style={{ width: 88, height: 88, borderRadius: 44, background: HS.brand.primary, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 40, color: '#fff', boxShadow: '0 6px 0 oklch(0.55 0.19 30), 0 0 0 8px rgba(220,100,60,0.15)' }}>🎤</div>
        </div>
      </div>
    </Phone>
  );
}

// 13) Success / feedback
function SuccessScreen() {
  return (
    <Phone bg="linear-gradient(180deg, oklch(0.88 0.10 160), oklch(0.95 0.06 100))">
      <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: 24, textAlign: 'center' }}>
        {/* Confetti */}
        {Array.from({length: 12}).map((_,i) => (
          <div key={i} style={{ position: 'absolute', left: `${10 + i*7}%`, top: `${10 + (i%3)*18}%`, width: 10, height: 16,
            background: [HS.brand.primary, HS.brand.mint, HS.brand.sky, HS.brand.lilac, HS.brand.butter][i%5],
            transform: `rotate(${i*34}deg)`, borderRadius: 2 }}/>
        ))}
        <Butterfly size={160} mood="celebrating" sparkles/>
        <Display size={32} color={HS.kid.ink} style={{ marginTop: 20 }}>Отлично!</Display>
        <Body color={HS.kid.inkMuted} style={{ marginTop: 4 }}>Ты справился на 9 из 10</Body>
        <div style={{ display: 'flex', gap: 8, marginTop: 16 }}>
          {[1,1,1].map((_,i) => (
            <div key={i} style={{ width: 44, height: 44, borderRadius: 22, background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 24 }}>⭐</div>
          ))}
        </div>
        <div style={{ marginTop: 20, background: 'rgba(255,255,255,0.9)', borderRadius: 18, padding: 14, display: 'flex', gap: 10, alignItems: 'center' }}>
          <div style={{ width: 44, height: 44, borderRadius: 22, background: HS.brand.butter, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22 }}>🎁</div>
          <div style={{ textAlign: 'left' }}>
            <Body size={11} color={HS.kid.inkMuted}>Новая наклейка!</Body>
            <Title size={15}>Лисичка-говорушка</Title>
          </div>
        </div>
        <KidCTA label="Дальше →" color={HS.sem.success} dark="oklch(0.52 0.15 150)" style={{ marginTop: 24, justifyContent: 'center' }}/>
      </div>
    </Phone>
  );
}

// 14) Try again
function TryAgainScreen() {
  return (
    <Phone bg={KID_BG}>
      <div style={{ padding: '16px 20px', height: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
        <Butterfly size={130} mood="thinking"/>
        <Title size={22} style={{ marginTop: 20, textAlign: 'center' }}>Почти получилось!</Title>
        <Body color={HS.kid.inkMuted} style={{ marginTop: 6, textAlign: 'center' }}>Попробуй ещё раз — у тебя точно выйдет.</Body>
        <div style={{ marginTop: 20, background: '#fff', borderRadius: 18, padding: 14, textAlign: 'center', boxShadow: HS.kid.shadow }}>
          <Body size={11} color={HS.kid.inkMuted}>Подсказка от Ляли</Body>
          <Title size={15} style={{ marginTop: 4 }}>Вытяни губки трубочкой и рычи сильней: Р‑Р‑Р!</Title>
        </div>
        <div style={{ display: 'flex', gap: 10, marginTop: 20, width: '100%' }}>
          <div style={{ flex: 1, background: '#fff', padding: 14, borderRadius: 18, textAlign: 'center', fontWeight: 700, border: `2px solid ${HS.kid.line}` }}>Показать снова</div>
          <KidCTA label="Попробую!" style={{ flex: 1.2, justifyContent: 'center' }}/>
        </div>
      </div>
    </Phone>
  );
}

// 15) Lesson end + rewards
function LessonEndScreen() {
  return (
    <Phone bg={KID_BG}>
      <div style={{ padding: '20px', height: '100%', display: 'flex', flexDirection: 'column' }}>
        <Title size={20}>Урок завершён</Title>
        <Body color={HS.kid.inkMuted}>Поляна Рычажная · 7 минут</Body>
        <div style={{ display: 'flex', justifyContent: 'center', margin: '20px 0' }}>
          <Butterfly size={120} mood="celebrating" sparkles/>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }}>
          {[['⭐','9/10','Звёзды'],['🎯','84%','Точность'],['🔥','7','Дней']].map(([e,v,l]) => (
            <div key={l} style={{ background: '#fff', borderRadius: 16, padding: 12, textAlign: 'center', boxShadow: HS.kid.shadow }}>
              <div style={{ fontSize: 22 }}>{e}</div>
              <Display size={18} color={HS.kid.ink}>{v}</Display>
              <Mono size={10} color={HS.kid.inkMuted}>{l}</Mono>
            </div>
          ))}
        </div>
        <div style={{ background: '#fff', borderRadius: 18, padding: 14, marginTop: 12, boxShadow: HS.kid.shadow }}>
          <Mono color={HS.kid.inkMuted} style={{ marginBottom: 6 }}>ЧТО СЕГОДНЯ БЫЛО</Mono>
          {['👄 Разминка «Заборчик-Трубочка»','👂 Нашёл 8 из 8 слов с Ш','🎤 Произнёс Ра-Ра 7 раз','🌸 Сказал «Рыба» уверенно'].map(t => (
            <div key={t} style={{ padding: '6px 0', borderBottom: `1px solid ${HS.kid.line}` }}>
              <Body size={12}>{t}</Body>
            </div>
          ))}
        </div>
        <div style={{ flex: 1 }}/>
        <KidCTA label="Получить награды →" color={HS.brand.butter} dark="oklch(0.70 0.12 80)" style={{ justifyContent: 'center' }}/>
      </div>
    </Phone>
  );
}

// 16) Rewards / collection
function RewardsScreen() {
  return (
    <Phone bg={KID_BG}>
      <div style={{ padding: '16px 20px 80px' }}>
        <Title size={22}>Моя коллекция</Title>
        <Body size={12} color={HS.kid.inkMuted}>24 из 60 наклеек</Body>
        <div style={{ display: 'flex', gap: 8, marginTop: 14, overflow: 'hidden' }}>
          {['Все','Свист.','Шип.','Сонор.','Загад.'].map((c,i) => (
            <Chip key={c} label={c} filled={i===0} color={i===0?HS.brand.primary:HS.brand.sky}/>
          ))}
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10, marginTop: 14 }}>
          {[
            ['🦊', HS.brand.primary, 'Лиска-говорушка', false],
            ['🐯', HS.brand.butter, 'Тигр-Рыкун', false],
            ['🐰', HS.brand.mint, 'Зай-Шептун', false],
            ['🦉', HS.brand.sky, 'Сова-Учёная', false],
            ['🐌', HS.brand.lilac, 'Шуршун', false],
            ['?', HS.kid.line, 'Секрет', true],
            ['?', HS.kid.line, 'Секрет', true],
            ['?', HS.kid.line, 'Секрет', true],
            ['?', HS.kid.line, 'Секрет', true],
          ].map(([e,c,n,locked],i) => (
            <div key={i} style={{ background: '#fff', borderRadius: 16, padding: 12, textAlign: 'center', boxShadow: HS.kid.shadow, opacity: locked ? 0.5 : 1 }}>
              <div style={{ width: 56, height: 56, borderRadius: 18, background: `color-mix(in oklch, ${c} 18%, white)`, margin: '0 auto', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 28 }}>{e}</div>
              <Body size={10} weight={700} style={{ marginTop: 6 }}>{n}</Body>
            </div>
          ))}
        </div>
      </div>
      <KidTabBar active="rewards"/>
    </Phone>
  );
}

// 17) Streak screen
function StreakScreen() {
  return (
    <Phone bg="linear-gradient(180deg, oklch(0.85 0.14 50), oklch(0.92 0.10 70))">
      <div style={{ position: 'absolute', inset: 0, padding: 20, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center' }}>
        <div style={{ fontSize: 80 }}>🔥</div>
        <Display size={56} color="#fff">7</Display>
        <Title size={20} color="#fff">дней подряд!</Title>
        <Body color="#fff" style={{ opacity: 0.85, marginTop: 4 }}>Ты занимаешься каждый день</Body>
        <div style={{ marginTop: 20, background: 'rgba(255,255,255,0.95)', borderRadius: 20, padding: 16, width: '100%' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', gap: 4 }}>
            {['Пн','Вт','Ср','Чт','Пт','Сб','Вс'].map((d,i) => (
              <div key={d} style={{ flex: 1, textAlign: 'center' }}>
                <Mono size={10} color={HS.kid.inkMuted}>{d}</Mono>
                <div style={{ width: 28, height: 28, margin: '4px auto', borderRadius: 14, background: i < 6 ? HS.brand.primary : HS.brand.butter, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', fontWeight: 700, fontSize: 12 }}>
                  {i < 6 ? '✓' : '☆'}
                </div>
              </div>
            ))}
          </div>
        </div>
        <KidCTA label="Продолжить огонёк!" color={HS.brand.primary} style={{ marginTop: 20, justifyContent: 'center' }}/>
      </div>
    </Phone>
  );
}

// 18) Profile (kid)
function KidProfileScreen() {
  return (
    <Phone bg={KID_BG}>
      <div style={{ padding: '16px 20px' }}>
        <Title size={22}>Мой профиль</Title>
        <div style={{ background: '#fff', borderRadius: 22, padding: 18, marginTop: 14, boxShadow: HS.kid.shadow, textAlign: 'center' }}>
          <div style={{ width: 88, height: 88, borderRadius: 44, background: HS.brand.mint, margin: '0 auto', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 44, boxShadow: 'inset 0 0 0 4px #fff, 0 0 0 3px oklch(0.55 0.15 165)' }}>🦊</div>
          <Title size={20} style={{ marginTop: 10 }}>Миша, 6 лет</Title>
          <Body size={12} color={HS.kid.inkMuted}>Путешественник 3 уровня</Body>
          <div style={{ display: 'flex', justifyContent: 'space-around', marginTop: 14 }}>
            {[['284','⭐'],['7','🔥'],['24','🎁'],['12','🗺️']].map(([n,e]) => (
              <div key={n} style={{ textAlign: 'center' }}>
                <div style={{ fontSize: 20 }}>{e}</div>
                <Display size={18}>{n}</Display>
              </div>
            ))}
          </div>
        </div>
        <div style={{ marginTop: 14 }}>
          <Mono color={HS.kid.inkMuted} style={{ marginBottom: 6 }}>ЗВУКИ — МОЙ ПУТЬ</Mono>
          <div style={{ background: '#fff', borderRadius: 18, padding: 12, boxShadow: HS.kid.shadow }}>
            {[['Р', HS.brand.primary, 62], ['Ш', HS.brand.lilac, 34], ['С', HS.brand.sky, 91]].map(([s,c,p]) => (
              <div key={s} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 0' }}>
                <div style={{ width: 36, height: 36, borderRadius: 10, background: c, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: HS.font.display, fontWeight: 800, fontSize: 18 }}>{s}</div>
                <div style={{ flex: 1 }}>
                  <Bar value={p} color={c}/>
                </div>
                <Mono size={11} color={HS.kid.ink} style={{ fontWeight: 700 }}>{p}%</Mono>
              </div>
            ))}
          </div>
        </div>
      </div>
    </Phone>
  );
}

Object.assign(window, {
  SplashScreen, WelcomeScreen, RoleSelectScreen, SignUpScreen, AddChildScreen, PermissionsScreen,
  KidHomeScreen, WorldMapScreen, WarmupScreen, ArticulationScreen, SoundListenScreen, WordPracticeScreen,
  SuccessScreen, TryAgainScreen, LessonEndScreen, RewardsScreen, StreakScreen, KidProfileScreen,
});
