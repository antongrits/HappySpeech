// More lesson variants + AR + additional kid states
const { HS, Butterfly, Phone, Display, Title, Body, Mono, KidCTA, KidTile, Chip, Ring, Bar, Placeholder, Pict, KidTabBar, Speech } = window;
const KID_BG = `linear-gradient(180deg, oklch(0.96 0.03 60) 0%, oklch(0.97 0.025 80) 100%)`;

// Breathing exercise full
function BreathingScreen() {
  return (
    <Phone bg="linear-gradient(180deg, oklch(0.92 0.08 200), oklch(0.95 0.05 160))">
      <div style={{ position: 'absolute', inset: 0, padding: 20, display: 'flex', flexDirection: 'column' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ width: 32, height: 32, borderRadius: 16, background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>←</div>
          <Bar value={40} color={HS.brand.sky} style={{ flex: 1 }}/>
          <Mono color={HS.kid.inkMuted}>2/5</Mono>
        </div>
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
          <Title size={22} style={{ textAlign: 'center' }}>Надуй шарик</Title>
          <Body color={HS.kid.inkMuted} style={{ marginTop: 4 }}>Вдох 4 · выдох 6</Body>
          <div style={{ width: 200, height: 200, borderRadius: 100, background: 'radial-gradient(circle at 30% 30%, oklch(0.85 0.14 30), oklch(0.72 0.16 20))', marginTop: 20, boxShadow: '0 20px 50px rgba(200,100,80,0.3)', position: 'relative' }}>
            <div style={{ position: 'absolute', top: 25, left: 30, width: 40, height: 24, borderRadius: 20, background: 'rgba(255,255,255,0.5)', filter: 'blur(4px)' }}/>
          </div>
          <div style={{ marginTop: 16, background: '#fff', padding: '8px 14px', borderRadius: 14, fontSize: 13, fontWeight: 700 }}>Выдох… 3 с</div>
        </div>
      </div>
    </Phone>
  );
}

// Syllable ladder
function SyllableScreen() {
  return (
    <Phone bg={KID_BG}>
      <div style={{ padding: '16px 20px', height: '100%', display: 'flex', flexDirection: 'column' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ width: 32, height: 32, borderRadius: 16, background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>←</div>
          <Bar value={55} color={HS.brand.primary} style={{ flex: 1 }}/>
          <Mono color={HS.kid.inkMuted}>3/7</Mono>
        </div>
        <Title size={20} style={{ marginTop: 14 }}>Лесенка слогов</Title>
        <Body size={12} color={HS.kid.inkMuted}>Повторяй за Лялей по ступенькам</Body>
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', gap: 8, padding: '20px 0' }}>
          {[['РЫ','done',HS.sem.success],['РА','done',HS.sem.success],['РО','active',HS.brand.primary],['РУ','locked',HS.kid.line],['РЭ','locked',HS.kid.line]].map(([s,st,c],i) => (
            <div key={s} style={{ marginLeft: `${i*18}px`, background: '#fff', borderRadius: 18, padding: '12px 18px', display: 'flex', alignItems: 'center', gap: 12, boxShadow: HS.kid.shadow, border: st === 'active' ? `3px solid ${c}` : 'none' }}>
              <Display size={28} color={c}>{s}</Display>
              <div style={{ flex: 1 }}/>
              {st === 'done' && <div style={{ width: 28, height: 28, borderRadius: 14, background: HS.sem.success, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>✓</div>}
              {st === 'active' && <div style={{ width: 36, height: 36, borderRadius: 18, background: c, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>🎤</div>}
              {st === 'locked' && <span style={{ color: HS.kid.inkSoft }}>🔒</span>}
            </div>
          ))}
        </div>
      </div>
    </Phone>
  );
}

// Mini-story
function StoryScreen() {
  return (
    <Phone bg={KID_BG}>
      <div style={{ padding: '16px 20px', height: '100%', display: 'flex', flexDirection: 'column' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ width: 32, height: 32, borderRadius: 16, background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>←</div>
          <Bar value={80} color={HS.brand.lilac} style={{ flex: 1 }}/>
          <Mono color={HS.kid.inkMuted}>4/5</Mono>
        </div>
        <Title size={20} style={{ marginTop: 12 }}>Сказка: Рыжий Рыцарь</Title>
        <div style={{ flex: 1, background: '#fff', borderRadius: 22, padding: 14, marginTop: 10, boxShadow: HS.kid.shadow, display: 'flex', flexDirection: 'column' }}>
          <Placeholder label="scene · castle in field" h={140} r={14}/>
          <Body size={14} style={{ marginTop: 12, lineHeight: 1.5 }}>
            Жил-был <b style={{ color: HS.brand.primary }}>р</b>ыжий <b style={{ color: HS.brand.primary }}>р</b>ыцарь. Он любил <b style={{ color: HS.brand.primary }}>р</b>ычать и <b style={{ color: HS.brand.primary }}>р</b>ешать загадки…
          </Body>
          <div style={{ flex: 1 }}/>
          <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
            <div style={{ flex: 1, background: HS.kid.surfaceAlt, borderRadius: 14, padding: 10, textAlign: 'center' }}>
              <Body size={11} color={HS.kid.inkMuted}>Цель</Body>
              <Title size={16}>8 раз «Р»</Title>
            </div>
            <div style={{ flex: 1, background: HS.sem.successBg, borderRadius: 14, padding: 10, textAlign: 'center' }}>
              <Body size={11} color={HS.sem.success}>Услышала</Body>
              <Title size={16} color={HS.sem.success}>6 / 8</Title>
            </div>
          </div>
        </div>
        <div style={{ display: 'flex', gap: 10, marginTop: 12 }}>
          <div style={{ flex: 1, background: '#fff', borderRadius: 18, padding: 12, textAlign: 'center', border: `2px solid ${HS.kid.line}`, fontWeight: 700 }}>◀ Назад</div>
          <KidCTA label="Читать дальше" color={HS.brand.lilac} dark="oklch(0.55 0.14 305)" style={{ flex: 1.6, justifyContent: 'center' }}/>
        </div>
      </div>
    </Phone>
  );
}

// Picture description
function PictureScreen() {
  return (
    <Phone bg={KID_BG}>
      <div style={{ padding: '16px 20px', height: '100%', display: 'flex', flexDirection: 'column' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ width: 32, height: 32, borderRadius: 16, background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>←</div>
          <Bar value={45} color={HS.brand.mint} style={{ flex: 1 }}/>
          <Mono color={HS.kid.inkMuted}>3/6</Mono>
        </div>
        <Title size={20} style={{ marginTop: 12 }}>Расскажи, что видишь</Title>
        <Placeholder label="illustration · park with pond" h={180} r={18} style={{ marginTop: 10 }}/>
        <div style={{ marginTop: 12, background: '#fff', borderRadius: 16, padding: 12, boxShadow: HS.kid.shadow }}>
          <Mono color={HS.kid.inkMuted}>НАЙДИ И НАЗОВИ</Mono>
          <div style={{ display: 'flex', gap: 6, marginTop: 8, flexWrap: 'wrap' }}>
            {['ры́ба','ра́дуга','ру́чей','ромашка','рыцарь'].map((w,i) => (
              <div key={w} style={{ padding: '6px 10px', borderRadius: 99, background: i < 2 ? HS.sem.successBg : HS.kid.surfaceAlt, color: i < 2 ? HS.sem.success : HS.kid.ink, fontSize: 13, fontWeight: 600, textDecoration: i < 2 ? 'line-through' : 'none' }}>
                {i < 2 && '✓ '}{w}
              </div>
            ))}
          </div>
        </div>
        <div style={{ flex: 1 }}/>
        <div style={{ display: 'flex', justifyContent: 'center' }}>
          <div style={{ width: 76, height: 76, borderRadius: 38, background: HS.brand.primary, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 34, color: '#fff', boxShadow: '0 5px 0 oklch(0.55 0.19 30), 0 0 0 8px rgba(220,100,60,0.12)' }}>🎤</div>
        </div>
      </div>
    </Phone>
  );
}

// Drag & drop matching
function MatchScreen() {
  return (
    <Phone bg={KID_BG}>
      <div style={{ padding: '16px 20px', height: '100%', display: 'flex', flexDirection: 'column' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ width: 32, height: 32, borderRadius: 16, background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>←</div>
          <Bar value={70} color={HS.brand.butter} style={{ flex: 1 }}/>
          <Mono color={HS.kid.inkMuted}>4/5</Mono>
        </div>
        <Title size={18} style={{ marginTop: 12 }}>Собери пары: С или Ш?</Title>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginTop: 14 }}>
          {[
            ['СУМКА', HS.brand.sky],['ШАПКА', HS.brand.lilac],
            ['СОК', HS.brand.sky],['ШУБА', HS.brand.lilac],
          ].map(([w,c]) => (
            <div key={w} style={{ background: '#fff', borderRadius: 16, padding: 10, textAlign: 'center', boxShadow: HS.kid.shadow }}>
              <Pict color={c} size={50} glyph={w[0]} style={{ margin: '0 auto' }}/>
              <Body size={12} weight={700} style={{ marginTop: 4 }}>{w}</Body>
            </div>
          ))}
        </div>
        <div style={{ flex: 1, display: 'flex', gap: 10, marginTop: 14 }}>
          <div style={{ flex: 1, background: `color-mix(in oklch, ${HS.brand.sky} 16%, white)`, borderRadius: 20, padding: 12, border: `2px dashed ${HS.brand.sky}`, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
            <Display size={32} color={HS.brand.sky}>С</Display>
            <Body size={11} color={HS.brand.sky}>свистящий</Body>
            <div style={{ flex: 1, display: 'flex', alignItems: 'center', color: HS.kid.inkSoft, fontSize: 24 }}>↓</div>
          </div>
          <div style={{ flex: 1, background: `color-mix(in oklch, ${HS.brand.lilac} 16%, white)`, borderRadius: 20, padding: 12, border: `2px dashed ${HS.brand.lilac}`, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
            <Display size={32} color={HS.brand.lilac}>Ш</Display>
            <Body size={11} color={HS.brand.lilac}>шипящий</Body>
            <div style={{ flex: 1, display: 'flex', alignItems: 'center', color: HS.kid.inkSoft, fontSize: 24 }}>↓</div>
          </div>
        </div>
      </div>
    </Phone>
  );
}

// Rhythm game
function RhythmScreen() {
  return (
    <Phone bg="linear-gradient(180deg, oklch(0.88 0.12 305), oklch(0.94 0.08 270))">
      <div style={{ position: 'absolute', inset: 0, padding: 20, display: 'flex', flexDirection: 'column', color: '#fff' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ width: 32, height: 32, borderRadius: 16, background: 'rgba(255,255,255,0.4)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>←</div>
          <Bar value={60} color="#fff" track="rgba(255,255,255,0.3)" style={{ flex: 1 }}/>
        </div>
        <Title size={22} color="#fff" style={{ marginTop: 14 }}>Хлопни ритм</Title>
        <Body size={12} color="#fff" style={{ opacity: 0.85 }}>ПА — ПА-ПА — ПА</Body>
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
          <div style={{ display: 'flex', gap: 8, justifyContent: 'center' }}>
            {[1,0,1,1,0,1].map((on,i) => (
              <div key={i} style={{ width: 38, height: 38, borderRadius: 19, background: on ? '#fff' : 'rgba(255,255,255,0.3)', boxShadow: on ? '0 0 0 6px rgba(255,255,255,0.3)' : 'none' }}/>
            ))}
          </div>
          <div style={{ display: 'flex', justifyContent: 'center', marginTop: 40 }}>
            <div style={{ width: 140, height: 140, borderRadius: 70, background: 'rgba(255,255,255,0.25)', backdropFilter: 'blur(20px)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 60, border: '2px solid rgba(255,255,255,0.5)' }}>👏</div>
          </div>
        </div>
      </div>
    </Phone>
  );
}

// Pause / rest
function PauseScreen() {
  return (
    <Phone bg="linear-gradient(180deg, oklch(0.94 0.05 200), oklch(0.97 0.03 140))">
      <div style={{ position: 'absolute', inset: 0, padding: 24, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center' }}>
        <Butterfly size={130} mood="thinking"/>
        <Title size={22} style={{ marginTop: 20 }}>Отдохни минутку</Title>
        <Body color={HS.kid.inkMuted} style={{ marginTop: 6 }}>Моргни глазками 10 раз и попей водички</Body>
        <div style={{ background: '#fff', borderRadius: 20, padding: 20, marginTop: 24, display: 'flex', alignItems: 'center', gap: 16 }}>
          <Ring size={72} value={75} color={HS.brand.sky}>
            <div style={{ textAlign: 'center' }}>
              <Display size={20}>45</Display>
              <Mono size={9} color={HS.kid.inkMuted}>сек</Mono>
            </div>
          </Ring>
          <div style={{ textAlign: 'left' }}>
            <Title size={14}>Маленькая пауза</Title>
            <Body size={11} color={HS.kid.inkMuted}>Скоро продолжим!</Body>
          </div>
        </div>
        <div style={{ background: 'rgba(255,255,255,0.7)', padding: '8px 14px', borderRadius: 14, marginTop: 14, fontSize: 13, color: HS.kid.inkMuted }}>
          Пропустить паузу
        </div>
      </div>
    </Phone>
  );
}

// ─── AR screens ─── //

// AR lobby
function ARLobbyScreen() {
  return (
    <Phone bg="linear-gradient(180deg, oklch(0.82 0.14 305), oklch(0.90 0.09 270))">
      <div style={{ position: 'absolute', inset: 0, padding: 20, display: 'flex', flexDirection: 'column', color: '#fff' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <Title size={22} color="#fff">AR-зеркало ✨</Title>
          <div style={{ background: 'rgba(255,255,255,0.25)', padding: '4px 10px', borderRadius: 12, fontSize: 11, fontWeight: 600 }}>3D</div>
        </div>
        <div style={{ display: 'flex', justifyContent: 'center', margin: '12px 0' }}>
          <Butterfly size={90} mood="celebrating" sparkles/>
        </div>
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 10 }}>
          {[
            ['🪞','Зеркало артикуляции','Следи за губами и язычком'],
            ['👅','Лови язычком','Открой рот широко'],
            ['💨','Сдуй облачко','Дыхание и поток воздуха'],
            ['🎭','Повтори позу губ','Улыбка → трубочка'],
          ].map(([e,t,d]) => (
            <div key={t} style={{ background: 'rgba(255,255,255,0.2)', backdropFilter: 'blur(20px)', border: '1px solid rgba(255,255,255,0.3)', borderRadius: 18, padding: 14, display: 'flex', gap: 12, alignItems: 'center' }}>
              <div style={{ width: 48, height: 48, borderRadius: 14, background: 'rgba(255,255,255,0.4)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22 }}>{e}</div>
              <div style={{ flex: 1 }}>
                <Title size={14} color="#fff">{t}</Title>
                <Body size={11} color="#fff" style={{ opacity: 0.85 }}>{d}</Body>
              </div>
              <div style={{ color: '#fff' }}>›</div>
            </div>
          ))}
        </div>
      </div>
    </Phone>
  );
}

// AR tutorial / permission
function ARPermissionScreen() {
  return (
    <Phone bg="#0a0a14">
      <div style={{ position: 'absolute', inset: 0, padding: 24, color: '#fff', display: 'flex', flexDirection: 'column', justifyContent: 'center', alignItems: 'center', textAlign: 'center' }}>
        <div style={{ width: 120, height: 120, borderRadius: 60, background: 'radial-gradient(circle, oklch(0.78 0.13 305), oklch(0.58 0.18 290))', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 60, boxShadow: '0 0 40px rgba(180,120,240,0.5)' }}>📷</div>
        <Title size={22} color="#fff" style={{ marginTop: 24 }}>Покажи мне своё личико</Title>
        <Body color="#fff" style={{ opacity: 0.75, marginTop: 8, maxWidth: 240 }}>Камера нужна только сейчас. Мы не записываем и не сохраняем видео.</Body>
        <div style={{ marginTop: 28, width: '100%' }}>
          <div style={{ background: HS.brand.primary, padding: 14, borderRadius: 16, fontWeight: 700, textAlign: 'center' }}>Разрешить камеру</div>
          <div style={{ padding: 14, color: '#fff', opacity: 0.6, textAlign: 'center', marginTop: 6 }}>Не сейчас</div>
        </div>
      </div>
    </Phone>
  );
}

// AR mirror
function ARMirrorScreen() {
  return (
    <Phone bg="#101018">
      <div style={{ position: 'absolute', inset: 0, background: 'radial-gradient(circle at 50% 45%, oklch(0.30 0.04 280) 0%, #0a0a14 70%)', color: '#fff' }}>
        {/* Face silhouette */}
        <svg viewBox="0 0 300 600" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', opacity: 0.4 }}>
          <ellipse cx="150" cy="260" rx="85" ry="110" fill="none" stroke="oklch(0.78 0.12 305)" strokeWidth="1" strokeDasharray="3 4"/>
          {Array.from({length:24}).map((_,i) => {
            const a = (i/24)*Math.PI*2;
            return <circle key={i} cx={150 + Math.cos(a)*85} cy={260 + Math.sin(a)*110} r="2" fill="oklch(0.82 0.12 305)"/>;
          })}
        </svg>
        {/* Mouth target */}
        <div style={{ position: 'absolute', top: 290, left: '50%', transform: 'translateX(-50%)', width: 80, height: 44, borderRadius: 30, background: 'oklch(0.72 0.17 35)', boxShadow: '0 0 0 3px rgba(255,200,180,0.6), 0 0 30px rgba(220,100,60,0.5)' }}>
          <div style={{ position: 'absolute', inset: 6, borderRadius: 20, background: '#1a0608' }}/>
        </div>
        {/* HUD top */}
        <div style={{ position: 'absolute', top: 50, left: 16, right: 16, display: 'flex', justifyContent: 'space-between' }}>
          <div style={{ background: 'rgba(255,255,255,0.15)', backdropFilter: 'blur(20px)', borderRadius: 14, padding: '8px 12px', display: 'flex', gap: 8, alignItems: 'center' }}>
            <div style={{ width: 6, height: 6, borderRadius: 3, background: HS.sem.success }}/>
            <Mono size={10} color="#fff">Лицо найдено</Mono>
          </div>
          <div style={{ background: 'rgba(255,255,255,0.15)', backdropFilter: 'blur(20px)', width: 36, height: 36, borderRadius: 18, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>✕</div>
        </div>
        {/* Mascot coach */}
        <div style={{ position: 'absolute', left: 16, bottom: 160, display: 'flex', alignItems: 'flex-end', gap: 8 }}>
          <Butterfly size={60}/>
          <div style={{ background: '#fff', color: HS.kid.ink, padding: '10px 12px', borderRadius: 16, fontSize: 12, fontWeight: 600, maxWidth: 160 }}>
            Открой ротик широко — как бегемотик!
          </div>
        </div>
        {/* Bottom controls */}
        <div style={{ position: 'absolute', bottom: 20, left: 16, right: 16, background: 'rgba(255,255,255,0.15)', backdropFilter: 'blur(20px)', borderRadius: 24, padding: 14, display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ flex: 1 }}>
            <Mono size={9} color="rgba(255,255,255,0.6)">ЦЕЛЬ</Mono>
            <Title size={14} color="#fff">Открой рот 3 раза</Title>
            <div style={{ display: 'flex', gap: 4, marginTop: 6 }}>
              {[1,1,0].map((v,i) => <div key={i} style={{ flex: 1, height: 4, borderRadius: 2, background: v ? HS.sem.success : 'rgba(255,255,255,0.3)' }}/>)}
            </div>
          </div>
          <div style={{ width: 56, height: 56, borderRadius: 28, background: HS.brand.primary, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 24, color: '#fff' }}>⏸</div>
        </div>
      </div>
    </Phone>
  );
}

// AR tongue catch
function ARTongueScreen() {
  return (
    <Phone bg="#0c1018">
      <div style={{ position: 'absolute', inset: 0, color: '#fff' }}>
        <svg viewBox="0 0 300 600" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', opacity: 0.35 }}>
          <ellipse cx="150" cy="280" rx="80" ry="100" fill="none" stroke="oklch(0.78 0.13 30)" strokeWidth="1" strokeDasharray="3 4"/>
        </svg>
        {/* Floating butterflies to catch */}
        {[[80,160,40],[220,200,36],[130,400,44],[250,380,38]].map(([x,y,s],i) => (
          <div key={i} style={{ position: 'absolute', left: x-s/2, top: y-s/2 }}><Butterfly size={s}/></div>
        ))}
        {/* Caught score */}
        <div style={{ position: 'absolute', top: 50, left: 16, right: 16, display: 'flex', justifyContent: 'space-between' }}>
          <div style={{ background: 'rgba(255,255,255,0.15)', backdropFilter: 'blur(20px)', borderRadius: 14, padding: '8px 14px', color: '#fff', fontWeight: 700 }}>🦋 3 / 8</div>
          <div style={{ background: 'rgba(255,255,255,0.15)', backdropFilter: 'blur(20px)', borderRadius: 14, padding: '8px 12px' }}>0:42</div>
        </div>
        {/* Instruction */}
        <div style={{ position: 'absolute', bottom: 120, left: 16, right: 16, textAlign: 'center' }}>
          <div style={{ background: 'rgba(255,255,255,0.15)', backdropFilter: 'blur(20px)', borderRadius: 20, padding: 14, display: 'inline-block' }}>
            <Title size={16} color="#fff">Высунь язычок — поймай бабочку!</Title>
          </div>
        </div>
      </div>
    </Phone>
  );
}

// AR low tracking
function ARLowTrackingScreen() {
  return (
    <Phone bg="#101018">
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(10,10,20,0.6)' }}/>
      <div style={{ position: 'absolute', inset: 0, padding: 24, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', color: '#fff', textAlign: 'center' }}>
        <div style={{ width: 100, height: 100, borderRadius: 50, border: '3px dashed rgba(255,255,255,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 40 }}>📷</div>
        <Title size={20} color="#fff" style={{ marginTop: 20 }}>Покажи личико целиком</Title>
        <Body style={{ opacity: 0.7, marginTop: 6 }}>Отойди чуть подальше — чтобы я видела тебя хорошо.</Body>
        <div style={{ display: 'flex', gap: 16, marginTop: 24 }}>
          {['💡 Больше света','📐 Держи ровно','😊 В центре'].map(t => (
            <div key={t} style={{ background: 'rgba(255,255,255,0.12)', padding: '8px 12px', borderRadius: 14, fontSize: 11 }}>{t}</div>
          ))}
        </div>
      </div>
    </Phone>
  );
}

// AR success
function ARSuccessScreen() {
  return (
    <Phone bg="linear-gradient(180deg, oklch(0.82 0.14 300), oklch(0.88 0.11 220))">
      <div style={{ position: 'absolute', inset: 0, padding: 24, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', color: '#fff', textAlign: 'center' }}>
        <Butterfly size={160} mood="celebrating" sparkles/>
        <Display size={30} color="#fff" style={{ marginTop: 16 }}>Супер!</Display>
        <Body color="#fff" style={{ opacity: 0.85, marginTop: 4 }}>Ты поймал 8 бабочек язычком</Body>
        <div style={{ background: 'rgba(255,255,255,0.25)', backdropFilter: 'blur(20px)', borderRadius: 20, padding: 14, marginTop: 20, width: '100%' }}>
          <div style={{ display: 'flex', justifyContent: 'space-around' }}>
            {[['100%','точность'],['0:58','время'],['+24','⭐']].map(([v,l],i) => (
              <div key={i}>
                <Display size={22} color="#fff">{v}</Display>
                <Mono size={9} color="#fff" style={{ opacity: 0.7 }}>{l}</Mono>
              </div>
            ))}
          </div>
        </div>
        <div style={{ marginTop: 28, background: '#fff', color: HS.brand.primary, padding: '14px 28px', borderRadius: 22, fontWeight: 800, fontFamily: HS.font.display }}>Дальше →</div>
      </div>
    </Phone>
  );
}

// Empty state
function EmptyStateScreen() {
  return (
    <Phone bg={KID_BG}>
      <div style={{ padding: 24, height: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center' }}>
        <Butterfly size={120} mood="thinking"/>
        <Title size={20} style={{ marginTop: 20 }}>Тут пока тихо…</Title>
        <Body color={HS.kid.inkMuted} style={{ marginTop: 6 }}>Начни своё первое приключение — и это место наполнится чудесами.</Body>
        <KidCTA label="Начать занятие" style={{ marginTop: 24, justifyContent: 'center' }}/>
      </div>
    </Phone>
  );
}

// Offline state
function OfflineScreen() {
  return (
    <Phone bg={KID_BG}>
      <div style={{ padding: 24, height: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center' }}>
        <div style={{ fontSize: 80 }}>📡</div>
        <Title size={20} style={{ marginTop: 12 }}>Можно играть без интернета</Title>
        <Body color={HS.kid.inkMuted} style={{ marginTop: 6 }}>Почти все занятия работают офлайн — мы уже скачали всё нужное.</Body>
        <div style={{ background: '#fff', borderRadius: 16, padding: 14, marginTop: 20, width: '100%', boxShadow: HS.kid.shadow }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
            <Body size={12} weight={700}>Скачано офлайн</Body>
            <Mono size={10} color={HS.kid.inkMuted}>780 МБ</Mono>
          </div>
          <Bar value={92} color={HS.sem.success}/>
          <Mono size={10} color={HS.kid.inkMuted} style={{ marginTop: 4 }}>92% основного контента</Mono>
        </div>
        <KidCTA label="Продолжить игру" color={HS.sem.success} dark="oklch(0.52 0.15 150)" style={{ marginTop: 20, justifyContent: 'center' }}/>
      </div>
    </Phone>
  );
}

// Loading
function LoadingScreen() {
  return (
    <Phone bg={KID_BG}>
      <div style={{ padding: 24, height: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
        <Butterfly size={120} mood="happy"/>
        <Title size={18} style={{ marginTop: 20 }}>Готовим приключение…</Title>
        <div style={{ display: 'flex', gap: 6, marginTop: 16 }}>
          {[0,1,2].map(i => <div key={i} style={{ width: 8, height: 8, borderRadius: 4, background: HS.brand.primary, opacity: 0.3 + i*0.25 }}/>)}
        </div>
        <Body size={11} color={HS.kid.inkMuted} style={{ marginTop: 20 }}>Загружаем звуки</Body>
      </div>
    </Phone>
  );
}

Object.assign(window, {
  BreathingScreen, SyllableScreen, StoryScreen, PictureScreen, MatchScreen, RhythmScreen, PauseScreen,
  ARLobbyScreen, ARPermissionScreen, ARMirrorScreen, ARTongueScreen, ARLowTrackingScreen, ARSuccessScreen,
  EmptyStateScreen, OfflineScreen, LoadingScreen,
});
