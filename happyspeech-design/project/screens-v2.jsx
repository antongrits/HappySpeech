// HappySpeech v2 screens — premium redesigned surfaces
// Imports primitives + new scenes/mascots from window.

const { HS, Butterfly, ButterflyV2, Zippy, Shushkin, Ryoka, Kuku, Aoko, QuietFriend, Snail,
  Phone, Display, Title, Body, Mono, Card, Chip, Ring, Bar, Placeholder, KidCTA, KidTile, KidTabBar, ParentTabBar,
  Sparkle, Cloud, Star,
  RaysBg, Trophy, Rocket, Gift, BookStack, Easel, Island, Cloud3D, Flower, Heart3D, Flame, Backpack, BigNum, Note3D,
  SproutScene, AlphaPlayScene, GamesScene, SchoolScene, TrophyScene, SoundIslandScene,
} = window;

// Shared kid background with rays — the signature home look
const RAY_BG = (<div style={{ position: 'absolute', inset: 0 }}><RaysBg hue="oklch(0.90 0.10 220)" hue2="oklch(0.97 0.04 225)" opacity={0.5}/></div>);

// ─────────────────────────────────────────────────────────────
// 1. WELCOME 2.0 — hero with dual phones, license row
// ─────────────────────────────────────────────────────────────
function WelcomeV2Screen() {
  return (
    <Phone bg="linear-gradient(180deg, oklch(0.92 0.09 290) 0%, oklch(0.94 0.08 230) 100%)" style={{ position: 'relative' }}>
      <div style={{ position: 'absolute', inset: 0, overflow: 'hidden' }}>
        {/* hero dual-phone collage */}
        <div style={{ position: 'absolute', top: 60, left: -10, right: -10, height: 200 }}>
          {/* left phone tilted back */}
          <div style={{ position: 'absolute', left: 12, top: 28, width: 140, height: 180, borderRadius: 22, background: 'linear-gradient(180deg, oklch(0.92 0.11 210), oklch(0.95 0.08 200))', transform: 'rotate(-14deg)', boxShadow: '0 16px 40px rgba(40,40,80,0.25)', border: '3px solid #1a1a1a', overflow: 'hidden', padding: 12 }}>
            {/* sound buttons */}
            {[['С', 0, 0],['Ж', 62, 10],['Ш', 18, 54],['Щ', 76, 70],['Ц', 40, 110]].map(([l,x,y]) => (
              <div key={l} style={{ position: 'absolute', left: x+10, top: y+30, width: 36, height: 36, borderRadius: 18, background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: 'Nunito', fontWeight: 900, color: HS.brand.lilac, fontSize: 18, boxShadow: '0 4px 10px rgba(0,0,0,0.12)' }}>{l}</div>
            ))}
            {/* dashed path */}
            <svg viewBox="0 0 120 160" style={{ position: 'absolute', inset: 0 }}><path d="M30 30 Q60 60 40 90 Q20 120 60 140" stroke={HS.brand.lilac} strokeWidth="1.5" strokeDasharray="4 4" fill="none" opacity="0.7"/></svg>
          </div>
          {/* right phone tilted forward with Lyalya */}
          <div style={{ position: 'absolute', right: 12, top: 10, width: 144, height: 190, borderRadius: 22, background: `linear-gradient(180deg, ${HS.brand.lilac}, oklch(0.65 0.16 290))`, transform: 'rotate(12deg)', boxShadow: '0 20px 50px rgba(40,40,80,0.28)', border: '3px solid #1a1a1a', overflow: 'hidden' }}>
            <div style={{ position: 'absolute', top: 8, left: '50%', transform: 'translateX(-50%)', width: 40, height: 12, borderRadius: 6, background: '#1a1a1a' }}/>
            <div style={{ position: 'absolute', inset: '30px 8px 8px', borderRadius: 16, background: 'linear-gradient(180deg, oklch(0.94 0.08 320), oklch(0.88 0.13 300))', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <ButterflyV2 size={100} mood="happy"/>
            </div>
          </div>
        </div>

        {/* main card */}
        <div style={{ position: 'absolute', left: 16, right: 16, top: 260, background: '#fff', borderRadius: 28, padding: 24, boxShadow: '0 20px 40px rgba(60,40,90,0.15)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14 }}>
            <div style={{ width: 36, height: 36, borderRadius: 10, background: HS.brand.lilac, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Butterfly size={26} bob={false}/>
            </div>
            <div>
              <div style={{ fontFamily: 'Nunito', fontWeight: 900, fontSize: 22, color: HS.kid.ink, lineHeight: 1, letterSpacing: -0.5 }}>HappySpeech</div>
              <Mono size={8} color={HS.kid.inkMuted}>ПЛАТФОРМА ДЛЯ ЗАНЯТИЙ</Mono>
            </div>
          </div>
          {[
            'Запускает и развивает речь через игру',
            'Научит выговаривать «Р», «Л», «Ш», «С»',
            'Результат уже через 2 недели',
            'Подходит детям от 4 до 8 лет',
          ].map(t => (
            <div key={t} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '6px 0' }}>
              <div style={{ width: 20, height: 20, borderRadius: 10, background: HS.brand.lilac, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <svg width="12" height="12" viewBox="0 0 12 12"><path d="M2 6L5 9L10 3" stroke="#fff" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
              </div>
              <Body size={12} weight={600} color={HS.kid.ink}>{t}</Body>
            </div>
          ))}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginTop: 18 }}>
            <div style={{ padding: '14px 20px', borderRadius: 28, background: HS.brand.lilac, color: '#fff', fontFamily: 'Nunito', fontWeight: 800, fontSize: 16, textAlign: 'center', boxShadow: '0 4px 0 oklch(0.55 0.15 290)' }}>Начать обучение</div>
            <div style={{ padding: '12px 20px', borderRadius: 28, background: '#fff', border: `1.5px solid ${HS.kid.line}`, fontFamily: 'Nunito', fontWeight: 700, fontSize: 13, color: HS.kid.ink, textAlign: 'center' }}>У меня есть аккаунт — войти</div>
          </div>
          <div style={{ textAlign: 'center', marginTop: 10, fontSize: 11, color: HS.brand.lilac, fontWeight: 600 }}>Я специалист</div>
        </div>

        {/* license row */}
        <div style={{ position: 'absolute', bottom: 10, left: 16, right: 16, display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ width: 24, height: 24, borderRadius: 6, background: HS.brand.lilac, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="#fff" strokeWidth="1.5"><path d="M7 1L2 4v4c0 3 2.5 4.5 5 5 2.5-.5 5-2 5-5V4z"/></svg>
          </div>
          <Body size={10} color={HS.kid.inkMuted}>Образовательная лицензия · Минпросвещения РФ</Body>
        </div>
      </div>
    </Phone>
  );
}

// ─────────────────────────────────────────────────────────────
// 2. DIAGNOSTICS INTRO 2.0 — video + checklist + letter bg
// ─────────────────────────────────────────────────────────────
function DiagnosticsV2Screen() {
  return (
    <Phone bg="linear-gradient(180deg, oklch(0.93 0.08 210) 0%, oklch(0.92 0.09 290) 100%)">
      <div style={{ position: 'absolute', inset: 0, overflow: 'hidden' }}>
        {/* background letters */}
        <div style={{ position: 'absolute', inset: 0, fontFamily: 'Nunito', fontWeight: 900, color: 'rgba(255,255,255,0.5)' }}>
          {[['З', 20, 4, 60],['К', 70, 48, 80],['Ж', 2, 42, 50],['Р', 78, 10, 44],['Ш', 8, 80, 60],['Ц', 70, 88, 46]].map(([l,x,y,s],i) => (
            <div key={i} style={{ position: 'absolute', left: `${x}%`, top: `${y}%`, fontSize: s }}>{l}</div>
          ))}
        </div>
        {/* back */}
        <div style={{ position: 'absolute', top: 14, left: 14, width: 36, height: 36, borderRadius: 18, background: 'rgba(255,255,255,0.6)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: HS.brand.lilac, fontWeight: 700 }}>‹</div>
        {/* video card */}
        <div style={{ position: 'absolute', top: 60, left: 16, right: 16, height: 200, borderRadius: 20, background: 'linear-gradient(135deg, oklch(0.88 0.08 290), oklch(0.72 0.14 280))', overflow: 'hidden', boxShadow: '0 20px 40px rgba(60,40,90,0.20)' }}>
          <div style={{ position: 'absolute', inset: 0, background: `radial-gradient(circle at 30% 30%, rgba(255,255,255,0.25), transparent 70%)` }}/>
          {/* Lyalya as child on tablet */}
          <div style={{ position: 'absolute', inset: '20% 24%', borderRadius: 16, background: 'linear-gradient(180deg, oklch(0.96 0.04 290), oklch(0.88 0.10 290))', border: '5px solid oklch(0.55 0.15 25)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <ButterflyV2 size={90} sparkles={true}/>
          </div>
          {/* play */}
          <div style={{ position: 'absolute', top: 12, right: 12, width: 26, height: 26, borderRadius: 13, background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M2 2v10M12 2v10" stroke="#fff" strokeWidth="2"/></svg>
          </div>
        </div>
        {/* content */}
        <div style={{ position: 'absolute', top: 280, left: 20, right: 20 }}>
          <div style={{ fontFamily: 'Nunito', fontWeight: 900, fontSize: 22, color: HS.brand.lilac, textAlign: 'center', letterSpacing: -0.3 }}>Цифровая диагностика речи</div>
          <div style={{ marginTop: 18 }}>
            {[
              'Определит, соответствует ли речь норме',
              'Какие звуки нужно подтянуть',
              'Точность результата 98,9%',
            ].map(t => (
              <div key={t} style={{ display: 'flex', alignItems: 'flex-start', gap: 10, padding: '6px 0' }}>
                <div style={{ width: 16, height: 16, borderRadius: 8, background: HS.brand.lilac, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, marginTop: 2 }}>
                  <svg width="10" height="10" viewBox="0 0 10 10"><path d="M2 5L4 7L8 3" stroke="#fff" strokeWidth="1.8" fill="none" strokeLinecap="round"/></svg>
                </div>
                <Body size={13} weight={700} color={HS.kid.ink}>{t}</Body>
              </div>
            ))}
          </div>
          <div style={{ display: 'flex', gap: 16, justifyContent: 'center', marginTop: 14 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, color: HS.kid.inkMuted, fontSize: 11 }}>
              <svg width="14" height="14" viewBox="0 0 14 14" fill={HS.brand.lilac}><rect x="2" y="2" width="10" height="10" rx="1"/></svg>
              подробный отчёт
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, color: HS.kid.inkMuted, fontSize: 11 }}>
              <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke={HS.brand.lilac} strokeWidth="1.6"><circle cx="7" cy="7" r="5"/><path d="M7 4v3l2 2"/></svg>
              до 12 минут
            </div>
          </div>
        </div>
        {/* CTA */}
        <div style={{ position: 'absolute', left: 16, right: 16, bottom: 20, padding: '16px 20px', borderRadius: 28, background: HS.brand.lilac, color: '#fff', fontFamily: 'Nunito', fontWeight: 800, fontSize: 16, textAlign: 'center', boxShadow: '0 6px 0 oklch(0.55 0.15 290), 0 14px 30px rgba(150,80,200,0.25)' }}>Начать</div>
      </div>
    </Phone>
  );
}

// ─────────────────────────────────────────────────────────────
// 3. QUIET ROOM — "обеспечьте тишину"
// ─────────────────────────────────────────────────────────────
function QuietRoomScreen() {
  return (
    <Phone bg="oklch(0.96 0.02 290)">
      <div style={{ position: 'absolute', inset: 0, padding: '14px 20px', display: 'flex', flexDirection: 'column' }}>
        <div style={{ width: 30, height: 30, color: HS.brand.lilac, fontSize: 22, fontWeight: 600 }}>‹</div>
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
          <QuietFriend size={180}/>
          <div style={{ fontFamily: 'Nunito', fontWeight: 900, fontSize: 22, color: HS.kid.ink, marginTop: 10 }}>Обеспечьте тишину</div>
          <Body size={13} color={HS.kid.inkMuted} style={{ textAlign: 'center', marginTop: 8, maxWidth: 260 }}>
            Телевизор, шум улицы или посторонний голос навредят результату диагностики
          </Body>
          <div style={{ marginTop: 22, background: '#fff', borderRadius: 14, padding: '10px 14px', display: 'flex', alignItems: 'center', gap: 10, boxShadow: '0 2px 10px rgba(60,40,90,0.08)' }}>
            <div style={{ width: 20, height: 20, borderRadius: 10, background: HS.brand.lilac, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <svg width="10" height="14" viewBox="0 0 10 14" fill="#fff"><rect x="3" y="0" width="4" height="7" rx="2"/><path d="M1 7a4 4 0 0 0 8 0" stroke="#fff" strokeWidth="1.5" fill="none"/><rect x="4.5" y="10" width="1" height="3"/></svg>
            </div>
            <Body size={11} color={HS.kid.ink}>Диагностика для детей 4–10 лет (для взрослых точность не гарантируется)</Body>
          </div>
        </div>
        <Body size={12} color={HS.kid.inkMuted} style={{ textAlign: 'center', marginBottom: 10 }}>Нажмите, если Миша готов</Body>
        <div style={{ padding: '16px 20px', borderRadius: 28, background: HS.brand.lilac, color: '#fff', fontFamily: 'Nunito', fontWeight: 800, fontSize: 16, textAlign: 'center', boxShadow: '0 6px 0 oklch(0.55 0.15 290)' }}>Начать</div>
      </div>
    </Phone>
  );
}

// ─────────────────────────────────────────────────────────────
// 4. KID HOME 2.0 — ray bg + 3D category cards + Lyalya corner
// ─────────────────────────────────────────────────────────────
function KidHomeV2Screen() {
  const cats = [
    { t: 'Запуск речи', sc: 'sprout', color: HS.brand.lilac, progress: 30 },
    { t: 'Развитие речи', sc: 'alpha', color: HS.brand.sky, progress: 65 },
    { t: 'Игры и звуки', sc: 'games', color: HS.brand.lilac, progress: 45 },
    { t: 'Подготовка к школе', sc: 'school', color: HS.brand.mint, progress: 12 },
  ];
  return (
    <Phone bg="oklch(0.94 0.08 200)">
      {RAY_BG}
      <div style={{ position: 'absolute', inset: 0, padding: '12px 16px', display: 'flex', flexDirection: 'column' }}>
        {/* top bar */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ width: 40, height: 40, borderRadius: 20, background: HS.brand.butter, display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 4px 10px rgba(200,150,50,0.3)' }}>
            <svg width="22" height="22" viewBox="0 0 24 24" fill="#fff"><circle cx="12" cy="8" r="4"/><path d="M4 22c0-5 4-8 8-8s8 3 8 8"/></svg>
          </div>
          <div style={{ display: 'flex', gap: 6, flex: 1, justifyContent: 'center' }}>
            <div style={{ padding: '8px 14px', borderRadius: 20, background: HS.brand.butter, color: '#fff', fontFamily: 'Nunito', fontWeight: 800, fontSize: 11, boxShadow: '0 3px 0 oklch(0.60 0.15 60)', display: 'flex', alignItems: 'center', gap: 6 }}>
              <svg width="12" height="14" viewBox="0 0 12 14" fill="#fff"><path d="M2 2h6l2 2v8H2z"/></svg>
              ДИАГНОСТИКА
            </div>
            <div style={{ padding: '8px 14px', borderRadius: 20, background: HS.brand.primary, color: '#fff', fontFamily: 'Nunito', fontWeight: 800, fontSize: 11, boxShadow: '0 3px 0 oklch(0.55 0.19 30)' }}>ПОЛНЫЙ ДОСТУП</div>
          </div>
          <div style={{ width: 36, height: 36, borderRadius: 18, background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 3px 8px rgba(0,0,0,0.08)' }}>
            <Note3D size={18}/>
          </div>
        </div>

        {/* greeting */}
        <div style={{ marginTop: 10, textAlign: 'center' }}>
          <div style={{ fontFamily: 'Nunito', fontWeight: 900, fontSize: 24, color: HS.kid.ink, letterSpacing: -0.5 }}>Привет, Миша!</div>
          <Body size={12} color={HS.kid.inkMuted}>Куда отправимся сегодня?</Body>
        </div>

        {/* scroll row of categories */}
        <div style={{ flex: 1, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginTop: 12, alignContent: 'start' }}>
          {cats.map(c => (
            <div key={c.t} style={{ background: '#fff', borderRadius: 18, padding: 10, boxShadow: '0 6px 14px rgba(60,80,120,0.10)', position: 'relative' }}>
              <div style={{ borderRadius: 12, overflow: 'hidden', position: 'relative', height: 100 }}>
                {c.sc === 'sprout' && <SproutScene w={130} h={100}/>}
                {c.sc === 'alpha' && <AlphaPlayScene w={130} h={100}/>}
                {c.sc === 'games' && <GamesScene w={130} h={100}/>}
                {c.sc === 'school' && <SchoolScene w={130} h={100}/>}
              </div>
              <div style={{ fontFamily: 'Nunito', fontWeight: 800, fontSize: 13, color: HS.kid.ink, marginTop: 8, lineHeight: 1.15 }}>{c.t}</div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 6 }}>
                <Bar value={c.progress} color={c.color} height={4} track={HS.kid.line} style={{ flex: 1 }}/>
                <Mono size={9} color={HS.kid.inkMuted}>{c.progress}%</Mono>
              </div>
            </div>
          ))}
        </div>

        {/* Lyalya corner */}
        <div style={{ position: 'absolute', left: -10, bottom: 60, pointerEvents: 'none' }}>
          <ButterflyV2 size={90} mood="encouraging"/>
        </div>
        {/* speech bubble */}
        <div style={{ position: 'absolute', left: 80, bottom: 120, background: '#fff', borderRadius: 14, padding: '8px 12px', fontSize: 11, fontWeight: 600, color: HS.kid.ink, boxShadow: '0 4px 12px rgba(0,0,0,0.12)', maxWidth: 140 }}>
          Сегодня — звук Р 🎯
          <div style={{ position: 'absolute', left: -6, bottom: 8, width: 0, height: 0, borderTop: '6px solid transparent', borderBottom: '6px solid transparent', borderRight: '8px solid #fff' }}/>
        </div>

        <KidTabBar active="home"/>
      </div>
    </Phone>
  );
}

// ─────────────────────────────────────────────────────────────
// 5. WORLD MAP 2.0 — vertical winding path with island nodes
// ─────────────────────────────────────────────────────────────
function WorldMapV2Screen() {
  // node states: done, active, next, locked
  const nodes = [
    { s: 'done', c: Zippy, label: 'С', step: 1 },
    { s: 'done', c: Aoko, label: 'А', step: 2 },
    { s: 'active', c: Ryoka, label: 'Р', step: 3 },
    { s: 'locked', c: Shushkin, label: 'Ш', step: 4 },
    { s: 'locked', c: Kuku, label: 'К', step: 5 },
  ];
  return (
    <Phone bg="linear-gradient(180deg, oklch(0.90 0.10 220) 0%, oklch(0.86 0.10 170) 100%)">
      <div style={{ position: 'absolute', inset: 0, overflow: 'hidden' }}>
        {/* top chrome */}
        <div style={{ position: 'absolute', top: 10, left: 14, right: 14, display: 'flex', justifyContent: 'space-between', zIndex: 2 }}>
          <div style={{ width: 38, height: 38, borderRadius: 19, background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', color: HS.brand.primary, fontWeight: 700, fontSize: 18, boxShadow: '0 3px 8px rgba(0,0,0,0.12)' }}>‹</div>
          <div style={{ padding: '8px 14px', borderRadius: 20, background: '#fff', fontFamily: 'Nunito', fontWeight: 800, fontSize: 12, color: HS.kid.ink, display: 'flex', alignItems: 'center', gap: 6, boxShadow: '0 3px 8px rgba(0,0,0,0.12)' }}>
            <div style={{ width: 18, height: 18, borderRadius: 9, background: HS.brand.sky, color: '#fff', fontSize: 11, fontWeight: 800, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>4+</div>
            Мишин остров
          </div>
        </div>
        {/* decorative sea waves */}
        <svg viewBox="0 0 320 620" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}>
          <defs>
            <pattern id="wave" width="40" height="12" patternUnits="userSpaceOnUse">
              <path d="M0 6 Q10 0 20 6 Q30 12 40 6" stroke="rgba(255,255,255,0.3)" fill="none" strokeWidth="1.5"/>
            </pattern>
          </defs>
          <rect width="320" height="620" fill="url(#wave)" opacity="0.6"/>
        </svg>

        <Cloud3D size={60} style={{ position: 'absolute', top: 60, left: 20 }}/>
        <Cloud3D size={44} style={{ position: 'absolute', top: 90, right: 30, opacity: 0.8 }}/>

        {/* winding path with nodes */}
        <div style={{ position: 'absolute', top: 60, left: 0, right: 0, height: 500, padding: '0 24px' }}>
          <svg viewBox="0 0 260 500" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}>
            <path d="M60 40 Q 200 90 180 180 Q 60 240 80 340 Q 220 390 200 480"
              stroke="oklch(0.80 0.08 60)" strokeWidth="10" fill="none" strokeDasharray="2 14" strokeLinecap="round"/>
          </svg>
          {nodes.map((n, i) => {
            const positions = [
              { left: 30, top: 20 },
              { left: 150, top: 90 },
              { left: 70, top: 180 },
              { left: 170, top: 270 },
              { left: 60, top: 380 },
            ];
            const p = positions[i];
            const done = n.s === 'done';
            const active = n.s === 'active';
            const locked = n.s === 'locked';
            return (
              <div key={i} style={{ position: 'absolute', left: p.left, top: p.top, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
                <div style={{ position: 'relative' }}>
                  <div style={{ width: 90, height: 90, borderRadius: 45, background: done ? HS.sem.success : active ? `radial-gradient(circle, ${HS.brand.butter}, ${HS.brand.primary})` : '#fff',
                    boxShadow: active ? '0 0 0 6px rgba(255,180,100,0.4), 0 8px 16px rgba(0,0,0,0.15)' : '0 4px 10px rgba(0,0,0,0.15)',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    border: locked ? `3px solid ${HS.kid.line}` : 'none' }} className={active ? 'hs-breath' : ''}>
                    {locked ? (
                      <svg width="24" height="24" viewBox="0 0 24 24" fill={HS.kid.inkSoft}><rect x="6" y="10" width="12" height="10" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3" stroke={HS.kid.inkSoft} strokeWidth="2" fill="none"/></svg>
                    ) : (
                      <n.c size={80}/>
                    )}
                  </div>
                  {done && (
                    <div style={{ position: 'absolute', right: -4, top: -4, width: 28, height: 28, borderRadius: 14, background: HS.sem.success, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', border: '3px solid #fff' }}>
                      <svg width="14" height="14" viewBox="0 0 14 14"><path d="M3 7l3 3 6-6" stroke="#fff" strokeWidth="2.2" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
                    </div>
                  )}
                </div>
                {active && (
                  <div style={{ marginTop: 8, padding: '4px 10px', borderRadius: 12, background: HS.brand.primary, color: '#fff', fontFamily: 'Nunito', fontWeight: 800, fontSize: 10, boxShadow: '0 3px 0 oklch(0.55 0.19 30)' }}>ИГРАТЬ</div>
                )}
              </div>
            );
          })}
        </div>

        {/* floating flower */}
        <Flower size={22} style={{ position: 'absolute', top: 320, right: 30 }}/>
        <Flower size={18} color="oklch(0.82 0.14 85)" style={{ position: 'absolute', top: 460, left: 30 }}/>

        <KidTabBar active="map"/>
      </div>
    </Phone>
  );
}

// ─────────────────────────────────────────────────────────────
// 6. PARENT LENTA — feed of articles with cover scenes
// ─────────────────────────────────────────────────────────────
function ParentLentaScreen() {
  const posts = [
    { tag: 'Приложение', title: 'Как развивать память, мышление и логику у ребёнка без репетитора', cover: 'games' },
    { tag: 'Советы', title: 'Не делайте эти ошибки, если хотите чтобы ребёнок выговаривал «Р»', cover: 'stage' },
    { tag: 'Анонсы', title: 'Новый мир звуков уже в приложении — начни с разминки', cover: 'trophy' },
  ];
  return (
    <Phone bg={HS.parent.bg}>
      <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column' }}>
        <div style={{ padding: '16px 20px 0' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <Title size={24} color={HS.parent.ink}>Добро пожаловать!</Title>
            <div style={{ display: 'flex', alignItems: 'center', gap: 4, padding: '8px 12px', borderRadius: 18, background: HS.brand.lilac, color: '#fff', fontSize: 11, fontWeight: 700 }}>
              <svg width="14" height="14" viewBox="0 0 14 14"><path d="M8 3L4 7l4 4" stroke="#fff" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
              В детский<br/>режим
            </div>
          </div>

          {/* premium banner */}
          <div style={{ marginTop: 14, borderRadius: 18, padding: 14, background: 'linear-gradient(120deg, oklch(0.88 0.10 300), oklch(0.82 0.12 280))', display: 'flex', alignItems: 'center', gap: 12, position: 'relative', overflow: 'hidden' }}>
            <div style={{ position: 'relative' }}>
              <Rocket size={48}/>
            </div>
            <div style={{ flex: 1 }}>
              <Body size={13} weight={800} color="oklch(0.30 0.08 280)">Ускорьте обучение ребёнка с премиум-доступом</Body>
            </div>
          </div>

          {/* filter chips */}
          <div style={{ display: 'flex', gap: 8, marginTop: 14, overflow: 'hidden' }}>
            {[['Все', true], ['Советы'], ['Анонсы'], ['Приложение']].map(([l, active]) => (
              <div key={l} style={{ padding: '7px 14px', borderRadius: 20, background: active ? `color-mix(in oklch, ${HS.brand.lilac} 20%, white)` : 'transparent', color: active ? HS.brand.lilac : HS.parent.inkMuted, fontSize: 12, fontWeight: 700, border: active ? 'none' : `1px solid ${HS.parent.line}` }}>{l}</div>
            ))}
          </div>
        </div>

        {/* feed */}
        <div style={{ flex: 1, overflow: 'hidden', padding: '14px 20px 70px', display: 'flex', flexDirection: 'column', gap: 14 }}>
          {posts.map((p, i) => (
            <div key={i} style={{ borderRadius: 16, background: '#fff', overflow: 'hidden', boxShadow: '0 2px 10px rgba(30,40,60,0.06)', position: 'relative' }}>
              <div style={{ height: 110, position: 'relative', overflow: 'hidden' }}>
                {p.cover === 'games' && <GamesScene w={280} h={110}/>}
                {p.cover === 'stage' && <AlphaPlayScene w={280} h={110}/>}
                {p.cover === 'trophy' && <TrophyScene w={280} h={110}/>}
                <div style={{ position: 'absolute', top: 10, right: 10, padding: '4px 10px', borderRadius: 12, background: `color-mix(in oklch, ${HS.brand.lilac} 20%, white)`, color: HS.brand.lilac, fontSize: 10, fontWeight: 700 }}>{p.tag}</div>
              </div>
              <div style={{ padding: 12 }}>
                <Body size={13} weight={700} color={HS.kid.ink} style={{ lineHeight: 1.3 }}>{p.title}</Body>
              </div>
            </div>
          ))}
        </div>

        {/* FAB gift */}
        <div style={{ position: 'absolute', bottom: 80, right: 16, width: 52, height: 52, borderRadius: 26, background: `radial-gradient(circle at 30% 30%, oklch(0.88 0.14 340), ${HS.brand.primary})`, display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 6px 20px rgba(200,80,150,0.3)' }} className="hs-rise">
          <Gift size={32} color="oklch(0.78 0.16 340)" ribbon="oklch(0.90 0.12 60)"/>
        </div>

        <ParentTabBarV2 active="feed"/>
      </div>
    </Phone>
  );
}

// ─────────────────────────────────────────────────────────────
// 7. PARENT CHILD DETAIL ACCORDION
// ─────────────────────────────────────────────────────────────
function ParentChildV2Screen() {
  const sections = [
    { t: 'Запуск речи', sc: 'sprout', open: false, progress: 30 },
    { t: 'Развитие речи', sc: 'alpha', open: true, progress: 62 },
    { t: 'Развивающие игры', sc: 'games', open: false, progress: 45 },
    { t: 'Подготовка к школе', sc: 'school', open: false, progress: 10 },
  ];
  return (
    <Phone bg={HS.parent.bg}>
      <div style={{ position: 'absolute', inset: 0, padding: '16px 20px 80px', overflow: 'hidden' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ padding: '10px 14px', borderRadius: 12, background: '#fff', border: `1px solid ${HS.parent.line}`, display: 'flex', alignItems: 'center', gap: 8 }}>
              <div style={{ fontSize: 14, fontWeight: 700 }}>Миша (5 лет)</div>
              <svg width="12" height="8" viewBox="0 0 12 8"><path d="M1 1L6 6L11 1" stroke={HS.kid.ink} strokeWidth="1.8" fill="none"/></svg>
            </div>
          </div>
          <div style={{ padding: '8px 12px', borderRadius: 18, background: HS.brand.lilac, color: '#fff', fontSize: 11, fontWeight: 700 }}>В детский<br/>режим</div>
        </div>

        {/* express test banner */}
        <div style={{ marginTop: 14, borderRadius: 16, padding: '14px 16px', background: `linear-gradient(120deg, oklch(0.92 0.11 80), oklch(0.86 0.14 60))`, display: 'flex', alignItems: 'center', gap: 12, position: 'relative', overflow: 'hidden' }}>
          <div style={{ flex: 1 }}>
            <Body size={13} weight={800} color="oklch(0.32 0.08 60)">Экспресс-тест речи</Body>
            <Body size={11} color="oklch(0.45 0.08 60)">Прямо в приложении</Body>
            <div style={{ marginTop: 8, padding: '6px 14px', borderRadius: 14, background: HS.brand.lilac, color: '#fff', fontSize: 11, fontWeight: 700, display: 'inline-block' }}>Пройти</div>
          </div>
          <ButterflyV2 size={60} mood="focused"/>
        </div>

        <div style={{ display: 'flex', gap: 10, marginTop: 14 }}>
          <div style={{ flex: 1, display: 'flex', alignItems: 'center', gap: 8, fontSize: 12, color: HS.brand.lilac, fontWeight: 700 }}>
            <svg width="14" height="18" viewBox="0 0 14 18" fill="none" stroke={HS.brand.lilac} strokeWidth="1.6"><rect x="1" y="1" width="12" height="16" rx="2"/><line x1="7" y1="14" x2="7" y2="14.01"/></svg>
            Обучение в<br/>приложении
          </div>
          <div style={{ flex: 1, padding: '10px 16px', borderRadius: 18, background: HS.brand.lilac, color: '#fff', fontSize: 12, fontWeight: 700, textAlign: 'center' }}>Добавить<br/>преподавателя</div>
        </div>

        {/* accordion */}
        <div style={{ marginTop: 14, display: 'flex', flexDirection: 'column', gap: 10 }}>
          {sections.map((s, i) => (
            <div key={i} style={{ borderRadius: 16, background: '#fff', boxShadow: '0 2px 8px rgba(30,40,60,0.05)', overflow: 'hidden' }}>
              <div style={{ padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 12 }}>
                <div style={{ width: 44, height: 44, borderRadius: 12, overflow: 'hidden' }}>
                  {s.sc === 'sprout' && <SproutScene w={44} h={44}/>}
                  {s.sc === 'alpha' && <AlphaPlayScene w={44} h={44}/>}
                  {s.sc === 'games' && <GamesScene w={44} h={44}/>}
                  {s.sc === 'school' && <SchoolScene w={44} h={44}/>}
                </div>
                <div style={{ flex: 1 }}>
                  <Body size={14} weight={700} color={HS.kid.ink}>{s.t}</Body>
                  <Bar value={s.progress} color={HS.brand.lilac} height={4} track={HS.kid.line} style={{ marginTop: 4 }}/>
                </div>
                <svg width="12" height="8" viewBox="0 0 12 8" style={{ transform: s.open ? 'rotate(180deg)' : 'none', transition: 'transform .2s' }}><path d="M1 1L6 6L11 1" stroke={HS.kid.ink} strokeWidth="1.8" fill="none"/></svg>
              </div>
              {s.open && (
                <div style={{ padding: '0 14px 14px', display: 'flex', flexDirection: 'column', gap: 6 }}>
                  {[['Разминка «Заборчик»', 'готово'],['Звук Р в слогах', 'активно'],['Звук Л в словах', 'закрыто']].map(([lesson, st]) => (
                    <div key={lesson} style={{ padding: '10px 12px', background: HS.parent.bgDeep, borderRadius: 10, display: 'flex', alignItems: 'center', gap: 10 }}>
                      <div style={{ width: 6, height: 6, borderRadius: 3, background: st === 'готово' ? HS.sem.success : st === 'активно' ? HS.brand.lilac : HS.kid.inkSoft }}/>
                      <Body size={12} color={HS.kid.ink} style={{ flex: 1 }}>{lesson}</Body>
                      <Mono size={9} color={HS.parent.inkMuted}>{st}</Mono>
                    </div>
                  ))}
                </div>
              )}
            </div>
          ))}
        </div>

        <ParentTabBarV2 active="child"/>
      </div>
    </Phone>
  );
}

// ─────────────────────────────────────────────────────────────
// 8. PARENT SETTINGS V2 — premium banner + register block + grouped rows
// ─────────────────────────────────────────────────────────────
function ParentSettingsV2Screen() {
  return (
    <Phone bg={HS.parent.bg}>
      <div style={{ position: 'absolute', inset: 0, overflow: 'hidden' }}>
        <div style={{ padding: '16px 20px 80px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div style={{ padding: '8px 14px', borderRadius: 20, background: '#fff', border: `1px solid ${HS.parent.line}`, display: 'flex', alignItems: 'center', gap: 8, fontSize: 12, fontWeight: 600 }}>
              <svg width="14" height="14" viewBox="0 0 14 14" fill={HS.brand.sky}><rect x="0" y="2" width="14" height="10" rx="2"/><path d="M1 4l6 4 6-4" stroke="#fff" strokeWidth="1.2" fill="none"/></svg>
              Подписаться
            </div>
            <div style={{ padding: '8px 12px', borderRadius: 18, background: HS.brand.lilac, color: '#fff', fontSize: 11, fontWeight: 700 }}>В детский<br/>режим</div>
          </div>

          {/* premium */}
          <div style={{ marginTop: 14, borderRadius: 16, padding: 14, background: 'linear-gradient(120deg, oklch(0.88 0.10 300), oklch(0.82 0.12 280))', display: 'flex', alignItems: 'center', gap: 12 }}>
            <Rocket size={40}/>
            <Body size={13} weight={800} color="oklch(0.30 0.08 280)">Ускорьте обучение ребёнка с премиум-доступом</Body>
          </div>

          {/* register block */}
          <div style={{ marginTop: 12, borderRadius: 16, padding: '16px 14px', background: `color-mix(in oklch, ${HS.brand.lilac} 10%, white)` }}>
            <Title size={14} color={HS.kid.ink} style={{ textAlign: 'center' }}>Зарегистрируйтесь в HappySpeech</Title>
            <Body size={11} color={HS.kid.inkMuted} style={{ textAlign: 'center', marginTop: 4 }}>Создайте аккаунт, чтобы не потерять полученный прогресс и настройки</Body>
            <div style={{ padding: '12px', borderRadius: 22, background: HS.brand.lilac, color: '#fff', fontSize: 13, fontWeight: 700, textAlign: 'center', marginTop: 10, boxShadow: '0 3px 0 oklch(0.55 0.15 290)' }}>Создать аккаунт</div>
            <div style={{ padding: '10px', borderRadius: 22, background: '#fff', border: `1px solid ${HS.parent.line}`, fontSize: 12, fontWeight: 600, textAlign: 'center', marginTop: 6 }}>У меня есть аккаунт, войти</div>
          </div>

          {/* list rows */}
          <div style={{ marginTop: 14, background: '#fff', borderRadius: 16, overflow: 'hidden', boxShadow: '0 2px 8px rgba(30,40,60,0.05)' }}>
            {[['Имя родителя', 'Указать'], ['Премиум-доступ', 'Получить'], ['Уведомления', 'alert']].map(([l, v], i, a) => (
              <div key={l} style={{ padding: '14px 16px', borderBottom: i < a.length - 1 ? `1px solid ${HS.parent.line}` : 'none', display: 'flex', alignItems: 'center', gap: 10 }}>
                <Body size={13} weight={600} color={HS.kid.ink} style={{ flex: 1 }}>{l}</Body>
                {v === 'alert' ? (
                  <div style={{ width: 18, height: 18, borderRadius: 9, background: oklch('0.62 0.20 25'), color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 11, fontWeight: 700 }}>!</div>
                ) : <Body size={12} color={HS.parent.inkMuted}>{v}</Body>}
                <span style={{ color: HS.parent.inkSoft }}>›</span>
              </div>
            ))}
          </div>

          <Title size={16} color={HS.kid.ink} style={{ marginTop: 16, marginBottom: 8 }}>Поддержка</Title>
          <div style={{ background: '#fff', borderRadius: 16, overflow: 'hidden', boxShadow: '0 2px 8px rgba(30,40,60,0.05)' }}>
            {['Частые вопросы', 'Настройка микрофона', 'Связаться с нами'].map((l, i, a) => (
              <div key={l} style={{ padding: '14px 16px', borderBottom: i < a.length - 1 ? `1px solid ${HS.parent.line}` : 'none', display: 'flex', alignItems: 'center' }}>
                <Body size={13} weight={600} color={HS.kid.ink} style={{ flex: 1 }}>{l}</Body>
                <span style={{ color: HS.parent.inkSoft }}>›</span>
              </div>
            ))}
          </div>
        </div>
        <ParentTabBarV2 active="settings"/>
      </div>
    </Phone>
  );
}

function oklch(v) { return `oklch(${v})`; }

// ─────────────────────────────────────────────────────────────
// 9. PREMIUM PAYWALL 2.0
// ─────────────────────────────────────────────────────────────
function PaywallV2Screen() {
  const feats = [
    ['300+ упражнений на все звуки'],
    ['Персональный план каждый день'],
    ['AR-зеркало артикуляции'],
    ['Отчёт для логопеда в один клик'],
    ['Без рекламы и ограничений'],
  ];
  return (
    <Phone bg="linear-gradient(180deg, oklch(0.94 0.08 290) 0%, oklch(0.88 0.13 280) 100%)">
      <div style={{ position: 'absolute', inset: 0, overflow: 'hidden' }}>
        <div style={{ position: 'absolute', top: 14, right: 14, width: 32, height: 32, borderRadius: 16, background: 'rgba(255,255,255,0.6)', color: HS.kid.inkSoft, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 18 }}>×</div>
        {/* hero rocket */}
        <div style={{ position: 'absolute', top: 40, left: 0, right: 0, display: 'flex', justifyContent: 'center' }}>
          <Rocket size={140}/>
        </div>
        <div style={{ position: 'absolute', top: 220, left: 16, right: 16, textAlign: 'center' }}>
          <div style={{ fontFamily: 'Nunito', fontWeight: 900, fontSize: 24, color: HS.kid.ink, letterSpacing: -0.5 }}>HappySpeech+</div>
          <Body size={12} color={HS.kid.inkMuted}>Полный доступ к всему приложению</Body>
        </div>
        <div style={{ position: 'absolute', top: 280, left: 16, right: 16, background: '#fff', borderRadius: 20, padding: 16, boxShadow: '0 10px 30px rgba(100,60,150,0.18)' }}>
          {feats.map(([t]) => (
            <div key={t} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '6px 0' }}>
              <div style={{ width: 20, height: 20, borderRadius: 10, background: `color-mix(in oklch, ${HS.brand.lilac} 20%, white)`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <svg width="12" height="12" viewBox="0 0 12 12"><path d="M2 6l3 3 5-6" stroke={HS.brand.lilac} strokeWidth="2" fill="none" strokeLinecap="round"/></svg>
              </div>
              <Body size={13} weight={600} color={HS.kid.ink}>{t}</Body>
            </div>
          ))}
        </div>
        {/* plans */}
        <div style={{ position: 'absolute', bottom: 100, left: 16, right: 16, display: 'flex', gap: 8 }}>
          {[
            { t: 'Месяц', p: '499 ₽', sub: 'в месяц' },
            { t: 'Год', p: '3 990 ₽', sub: '332 ₽/мес', popular: true },
          ].map(pl => (
            <div key={pl.t} style={{ flex: 1, borderRadius: 16, padding: 12, background: pl.popular ? HS.brand.lilac : '#fff', color: pl.popular ? '#fff' : HS.kid.ink, border: pl.popular ? 'none' : `2px solid ${HS.kid.line}`, position: 'relative', boxShadow: pl.popular ? '0 6px 16px rgba(150,80,200,0.25)' : 'none' }}>
              {pl.popular && <div style={{ position: 'absolute', top: -10, right: 10, padding: '3px 8px', borderRadius: 10, background: HS.brand.butter, color: '#fff', fontSize: 9, fontWeight: 800 }}>–44%</div>}
              <Body size={12} weight={700} color={pl.popular ? '#fff' : HS.kid.inkMuted}>{pl.t}</Body>
              <Display size={20} color={pl.popular ? '#fff' : HS.kid.ink}>{pl.p}</Display>
              <Body size={10} color={pl.popular ? 'rgba(255,255,255,0.8)' : HS.kid.inkMuted}>{pl.sub}</Body>
            </div>
          ))}
        </div>
        <div style={{ position: 'absolute', bottom: 30, left: 16, right: 16, padding: '16px 20px', borderRadius: 28, background: HS.brand.primary, color: '#fff', fontFamily: 'Nunito', fontWeight: 800, fontSize: 16, textAlign: 'center', boxShadow: '0 6px 0 oklch(0.55 0.19 30)' }}>Начать 7 дней бесплатно</div>
      </div>
    </Phone>
  );
}

// ─────────────────────────────────────────────────────────────
// 10. REWARDS SHELF V2 + STREAK V2 + LEVEL UP
// ─────────────────────────────────────────────────────────────
function RewardsV2Screen() {
  return (
    <Phone bg="linear-gradient(180deg, oklch(0.94 0.08 80) 0%, oklch(0.96 0.05 60) 100%)">
      <div style={{ position: 'absolute', inset: 0 }}>
        <RaysBg hue="oklch(0.88 0.14 70)" hue2="oklch(0.96 0.06 75)" opacity={0.35}/>
        <div style={{ position: 'absolute', inset: 0, padding: '16px 16px 80px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ width: 36, height: 36, borderRadius: 18, background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 18 }}>‹</div>
            <Title size={20}>Мои награды</Title>
            <div style={{ flex: 1 }}/>
            <Chip label="18 / 42" filled color={HS.brand.butter}/>
          </div>
          <div style={{ marginTop: 12, borderRadius: 18, background: 'rgba(255,255,255,0.6)', padding: 14, backdropFilter: 'blur(6px)' }}>
            <div style={{ display: 'flex', justifyContent: 'center' }}>
              <Trophy size={100}/>
            </div>
            <div style={{ textAlign: 'center', marginTop: 6, fontFamily: 'Nunito', fontWeight: 900, fontSize: 18, color: HS.kid.ink }}>Чемпион недели</div>
            <Body size={11} color={HS.kid.inkMuted} style={{ textAlign: 'center' }}>занимался 6 дней подряд</Body>
          </div>

          {/* shelf */}
          <div style={{ marginTop: 14 }}>
            <Mono color={HS.kid.inkMuted} style={{ marginBottom: 6 }}>КОЛЛЕКЦИЯ</Mono>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10 }}>
              {[
                { c: <Trophy size={54}/>, n: 'Первый урок', u: true },
                { c: <Gift size={44} color="oklch(0.78 0.16 30)"/>, n: 'Три ура', u: true },
                { c: <Heart3D size={44}/>, n: 'Любим Р', u: true },
                { c: <Flame size={48}/>, n: '7 дней', u: true },
                { c: <Zippy size={54}/>, n: 'Зиппи', u: true },
                { c: <Shushkin size={54}/>, n: 'Шушкин', u: false },
                { c: <Ryoka size={54}/>, n: 'Рёка', u: true },
                { c: <Kuku size={54}/>, n: 'Куку', u: false },
                { c: <Aoko size={54}/>, n: 'Аоко', u: false },
              ].map((r, i) => (
                <div key={i} style={{ borderRadius: 14, background: '#fff', padding: 8, textAlign: 'center', boxShadow: HS.kid.shadow, position: 'relative', opacity: r.u ? 1 : 0.4 }}>
                  <div style={{ height: 70, display: 'flex', alignItems: 'center', justifyContent: 'center', filter: r.u ? 'none' : 'grayscale(1)' }}>{r.c}</div>
                  <Mono size={9} color={HS.kid.inkMuted} style={{ marginTop: 2 }}>{r.n}</Mono>
                  {!r.u && <div style={{ position: 'absolute', top: 6, right: 6, width: 18, height: 18, borderRadius: 9, background: HS.kid.line, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 10 }}>🔒</div>}
                </div>
              ))}
            </div>
          </div>
        </div>
        <KidTabBar active="rewards"/>
      </div>
    </Phone>
  );
}

function StreakV2Screen() {
  const days = ['Пн','Вт','Ср','Чт','Пт','Сб','Вс'];
  return (
    <Phone bg="linear-gradient(180deg, oklch(0.94 0.10 50) 0%, oklch(0.88 0.14 30) 100%)">
      <div style={{ position: 'absolute', inset: 0 }}>
        <RaysBg hue="oklch(0.88 0.16 50)" hue2="oklch(0.96 0.08 60)" opacity={0.5}/>
        <div style={{ position: 'absolute', inset: 0, padding: '28px 20px', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
          <Mono color="rgba(255,255,255,0.8)" size={12}>ДЕНЬ 6 ИЗ 7</Mono>
          <div style={{ fontFamily: 'Nunito', fontWeight: 900, fontSize: 30, color: '#fff', letterSpacing: -0.5 }}>Огонёк горит!</div>
          <Flame size={160} style={{ marginTop: 10 }}/>
          <div style={{ marginTop: 14, background: 'rgba(255,255,255,0.9)', borderRadius: 22, padding: '14px 18px', width: '100%' }}>
            <Mono color={HS.kid.inkMuted} size={10}>НЕДЕЛЯ</Mono>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8 }}>
              {days.map((d, i) => {
                const done = i < 6;
                const today = i === 5;
                return (
                  <div key={d} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
                    <div style={{ width: 32, height: 32, borderRadius: 16, background: done ? `radial-gradient(circle at 35% 30%, ${HS.brand.butter}, ${HS.brand.primary})` : HS.kid.line, border: today ? `3px solid ${HS.brand.primary}` : 'none', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', fontWeight: 800 }}>
                      {done && <svg width="14" height="14" viewBox="0 0 14 14"><path d="M3 7l3 3 5-6" stroke="#fff" strokeWidth="2" fill="none" strokeLinecap="round"/></svg>}
                    </div>
                    <Mono size={9} color={HS.kid.inkMuted}>{d}</Mono>
                  </div>
                );
              })}
            </div>
          </div>
          <div style={{ marginTop: 14, padding: '14px 22px', borderRadius: 28, background: '#fff', color: HS.brand.primary, fontFamily: 'Nunito', fontWeight: 800, fontSize: 15, boxShadow: '0 6px 0 rgba(0,0,0,0.1)' }}>Позанимаюсь сегодня</div>
        </div>
      </div>
    </Phone>
  );
}

// ─────────────────────────────────────────────────────────────
// 11. LESSON V2 — articulation scene
// ─────────────────────────────────────────────────────────────
function LessonArticV2Screen() {
  return (
    <Phone bg="linear-gradient(180deg, oklch(0.92 0.08 210) 0%, oklch(0.88 0.10 180) 100%)">
      <div style={{ position: 'absolute', inset: 0 }}>
        {/* scenery top */}
        <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 300, overflow: 'hidden' }}>
          <Cloud3D size={70} style={{ position: 'absolute', top: 14, left: -10 }}/>
          <Cloud3D size={50} style={{ position: 'absolute', top: 50, right: 10, opacity: 0.8 }}/>
          <Island size={200} style={{ position: 'absolute', bottom: -20, left: 20 }}/>
          <div style={{ position: 'absolute', top: 90, left: '50%', transform: 'translateX(-50%)' }}>
            <ButterflyV2 size={140} mood="listening" sparkles={true}/>
          </div>
          {/* exercise name tag */}
          <div style={{ position: 'absolute', top: 14, left: 14, display: 'flex', alignItems: 'center', gap: 8 }}>
            <div style={{ width: 36, height: 36, borderRadius: 18, background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 16, boxShadow: '0 3px 8px rgba(0,0,0,0.12)' }}>‹</div>
            <div style={{ padding: '6px 12px', borderRadius: 16, background: '#fff', fontSize: 11, fontWeight: 700, boxShadow: '0 3px 8px rgba(0,0,0,0.12)' }}>3 / 5</div>
          </div>
          <div style={{ position: 'absolute', top: 14, right: 14, width: 36, height: 36, borderRadius: 18, background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 16, boxShadow: '0 3px 8px rgba(0,0,0,0.12)' }}>⏸</div>
        </div>

        {/* card */}
        <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, background: '#fff', borderTopLeftRadius: 28, borderTopRightRadius: 28, padding: 24, paddingBottom: 32, boxShadow: '0 -12px 30px rgba(60,80,120,0.10)' }}>
          <div style={{ textAlign: 'center' }}>
            <Mono color={HS.kid.inkMuted}>УПРАЖНЕНИЕ · АРТИКУЛЯЦИЯ</Mono>
            <div style={{ fontFamily: 'Nunito', fontWeight: 900, fontSize: 26, color: HS.kid.ink, marginTop: 4, letterSpacing: -0.3 }}>Парус</div>
            <Body size={12} color={HS.kid.inkMuted} style={{ marginTop: 2 }}>Подними язычок к нёбу — как парус на лодке</Body>
          </div>
          {/* example photo row */}
          <div style={{ display: 'flex', gap: 10, marginTop: 16, justifyContent: 'center' }}>
            {[1,2,3].map(i => (
              <div key={i} style={{ width: 64, height: 64, borderRadius: 16, background: `color-mix(in oklch, ${HS.brand.sky} 18%, white)`, display: 'flex', alignItems: 'center', justifyContent: 'center', border: i === 2 ? `3px solid ${HS.brand.primary}` : `1px solid ${HS.kid.line}` }}>
                <svg width="40" height="30" viewBox="0 0 40 30">
                  <path d="M4 24 Q20 4 36 24 Q20 30 4 24 Z" fill="oklch(0.70 0.14 25)"/>
                  {i === 2 && <path d="M12 16 Q20 10 28 16 Q20 18 12 16 Z" fill="#fff"/>}
                </svg>
              </div>
            ))}
          </div>
          <div style={{ display: 'flex', justifyContent: 'center', gap: 14, alignItems: 'center', marginTop: 20 }}>
            <div style={{ width: 48, height: 48, borderRadius: 24, background: HS.kid.surfaceAlt, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <svg width="22" height="22" viewBox="0 0 22 22" fill={HS.brand.primary}><path d="M5 3l12 8-12 8z"/></svg>
            </div>
            <div style={{ width: 80, height: 80, borderRadius: 40, background: `radial-gradient(circle at 30% 30%, ${HS.brand.primaryHi}, ${HS.brand.primary})`, display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 6px 0 oklch(0.55 0.19 30), 0 14px 30px rgba(200,80,40,0.3)' }} className="hs-breath">
              <svg width="36" height="46" viewBox="0 0 36 46" fill="#fff"><rect x="10" y="0" width="16" height="28" rx="8"/><path d="M2 22a16 16 0 0 0 32 0" stroke="#fff" strokeWidth="4" fill="none"/><rect x="16" y="38" width="4" height="8"/></svg>
            </div>
            <div style={{ width: 48, height: 48, borderRadius: 24, background: HS.kid.surfaceAlt, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <svg width="22" height="22" viewBox="0 0 22 22" fill="none" stroke={HS.kid.ink} strokeWidth="2.5" strokeLinecap="round"><path d="M4 11h14M12 5l6 6-6 6"/></svg>
            </div>
          </div>
        </div>
      </div>
    </Phone>
  );
}

// ─────────────────────────────────────────────────────────────
// 12. TAB BAR V2 — Лента / Ребёнок / Настройки / Логопед
// ─────────────────────────────────────────────────────────────
function ParentTabBarV2({ active = 'feed' }) {
  const tabs = [
    { id: 'feed', label: 'Лента', icon: <svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor"><path d="M3 10l9-7 9 7v10a2 2 0 0 1-2 2h-4v-7H10v7H6a2 2 0 0 1-2-2z"/></svg> },
    { id: 'child', label: 'Ребёнок', icon: <svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="8" r="4"/><path d="M4 22c0-5 4-8 8-8s8 3 8 8"/></svg> },
    { id: 'settings', label: 'Настройки', icon: <svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="12" r="3"/><path d="M12 1v4m0 14v4M4 12H1m22 0h-3M5 5l2 2m10 10l2 2M5 19l2-2m10-10l2-2"/></svg> },
    { id: 'spec', label: 'Специалист', icon: <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M12 14s-4-2-4-6a4 4 0 0 1 8 0c0 4-4 6-4 6zM8 22h8"/></svg> },
  ];
  return (
    <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, background: '#fff', padding: '10px 4px 12px', display: 'flex', justifyContent: 'space-around', boxShadow: '0 -4px 16px rgba(30,40,60,0.06)' }}>
      {tabs.map(t => {
        const a = active === t.id;
        return (
          <div key={t.id} style={{ position: 'relative', display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '4px 10px', borderRadius: 14, background: a ? `color-mix(in oklch, ${HS.brand.lilac} 14%, white)` : 'transparent', color: a ? HS.brand.lilac : HS.parent.inkSoft }}>
            <div style={{ marginBottom: 2 }}>{t.icon}</div>
            <div style={{ fontSize: 10, fontWeight: 700 }}>{t.label}</div>
          </div>
        );
      })}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 13. SUCCESS V2 with confetti
// ─────────────────────────────────────────────────────────────
function SuccessV2Screen() {
  return (
    <Phone bg="linear-gradient(180deg, oklch(0.94 0.10 140) 0%, oklch(0.88 0.14 165) 100%)">
      <div style={{ position: 'absolute', inset: 0 }}>
        <RaysBg hue="oklch(0.88 0.14 150)" hue2="oklch(0.96 0.07 160)" opacity={0.5}/>
        {/* confetti */}
        {[['oklch(0.85 0.16 30)', 40, 80],['oklch(0.80 0.18 85)', 260, 90],['oklch(0.78 0.14 290)', 80, 160],['oklch(0.82 0.14 165)', 240, 180],['oklch(0.85 0.16 30)', 30, 260],['oklch(0.80 0.14 250)', 260, 280]].map(([c,x,y],i) => (
          <div key={i} style={{ position: 'absolute', left: x, top: y, width: 10, height: 14, background: c, borderRadius: 2, transform: `rotate(${i*30}deg)`, opacity: 0.8 }} className="hs-rise"/>
        ))}
        <div style={{ position: 'absolute', inset: 0, padding: 24, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
          <Trophy size={140}/>
          <Mono color="rgba(0,60,30,0.6)" style={{ marginTop: 16 }}>УРОК ЗАВЕРШЁН</Mono>
          <div style={{ fontFamily: 'Nunito', fontWeight: 900, fontSize: 36, color: 'oklch(0.32 0.12 150)', letterSpacing: -1 }}>Умничка!</div>
          <Body size={14} color="oklch(0.42 0.10 150)" style={{ textAlign: 'center', maxWidth: 240 }}>Звук Р — 92% точности.<br/>Ляля гордится тобой!</Body>
          <div style={{ display: 'flex', gap: 18, marginTop: 18, padding: '12px 24px', background: 'rgba(255,255,255,0.85)', borderRadius: 20, backdropFilter: 'blur(8px)' }}>
            {[['⭐', '+24'],['🔥', '6 дней'],['⏱', '7 мин']].map(([e,v]) => (
              <div key={e} style={{ textAlign: 'center' }}>
                <div style={{ fontSize: 22 }}>{e}</div>
                <div style={{ fontFamily: 'Nunito', fontWeight: 800, fontSize: 13 }}>{v}</div>
              </div>
            ))}
          </div>
          <div style={{ marginTop: 24, padding: '14px 36px', borderRadius: 28, background: HS.brand.primary, color: '#fff', fontFamily: 'Nunito', fontWeight: 800, fontSize: 16, boxShadow: '0 6px 0 oklch(0.55 0.19 30)' }}>Дальше</div>
          <div style={{ marginTop: 10, fontSize: 12, color: 'oklch(0.42 0.10 150)', fontWeight: 600 }}>На главную</div>
        </div>
      </div>
    </Phone>
  );
}

// ─────────────────────────────────────────────────────────────
// 14. MASCOT LIBRARY CARD — showcase all characters
// ─────────────────────────────────────────────────────────────
function MascotLibraryCard() {
  const moods = ['happy','celebrating','thinking','listening','excited','encouraging','focused','shy','sleeping'];
  return (
    <div style={{ width: '100%', height: '100%', background: 'linear-gradient(135deg, oklch(0.97 0.03 290) 0%, oklch(0.94 0.08 60) 100%)', padding: 40, fontFamily: HS.font.text, overflow: 'hidden' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 20, marginBottom: 24 }}>
        <div style={{ width: 4, height: 48, background: HS.brand.primary, borderRadius: 2 }}/>
        <div>
          <Display size={32}>Персонажи и настроения</Display>
          <Mono color={HS.kid.inkMuted}>MASCOT LIBRARY · V2</Mono>
        </div>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 20, height: 'calc(100% - 100px)' }}>
        <div style={{ background: 'rgba(255,255,255,0.7)', borderRadius: 16, padding: 20 }}>
          <Title size={16}>Ляля · 9 настроений</Title>
          <Body size={11} color={HS.kid.inkMuted}>Главный талисман. Меняет лицо по контексту.</Body>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12, marginTop: 14 }}>
            {moods.map(m => (
              <div key={m} style={{ background: '#fff', borderRadius: 12, padding: 10, textAlign: 'center' }}>
                <ButterflyV2 size={70} mood={m} sparkles={false}/>
                <Mono size={9} color={HS.kid.inkMuted}>{m.toUpperCase()}</Mono>
              </div>
            ))}
          </div>
        </div>
        <div>
          <div style={{ background: 'rgba(255,255,255,0.7)', borderRadius: 16, padding: 20, marginBottom: 16 }}>
            <Title size={16}>Компаньоны звуковых групп</Title>
            <Body size={11} color={HS.kid.inkMuted}>Каждая семья звуков — свой зверёк-помощник.</Body>
            <div style={{ display: 'flex', justifyContent: 'space-around', marginTop: 14 }}>
              {[[Zippy, 'Зиппи', 'С З Ц'],[Shushkin, 'Шушкин', 'Ш Ж Щ'],[Ryoka, 'Рёка', 'Р Л'],[Kuku, 'Куку', 'К Г Х'],[Aoko, 'Аоко', 'А О У']].map(([C, n, s]) => (
                <div key={n} style={{ textAlign: 'center' }}>
                  <C size={80}/>
                  <div style={{ fontFamily: 'Nunito', fontWeight: 800, fontSize: 12 }}>{n}</div>
                  <Mono size={9} color={HS.kid.inkMuted}>{s}</Mono>
                </div>
              ))}
            </div>
          </div>
          <div style={{ background: 'rgba(255,255,255,0.7)', borderRadius: 16, padding: 20 }}>
            <Title size={16}>Сцены и поддерживающие персонажи</Title>
            <div style={{ display: 'flex', gap: 14, marginTop: 10, alignItems: 'center' }}>
              <QuietFriend size={80}/>
              <Snail size={80}/>
              <Flame size={80}/>
              <Rocket size={80} flame={false}/>
              <div style={{ flex: 1 }}>
                <Body size={11} color={HS.kid.inkMuted}>Тихая подруга для диагностики, улитка-паузы, огонёк streak, ракета-премиум.</Body>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 15. MOTION RULES CARD v2
// ─────────────────────────────────────────────────────────────
function MotionV2Card() {
  const anims = [
    ['orbit', 'hs-orbit', 'Лёгкое плавание для иконок-компаньонов'],
    ['wiggle', 'hs-wiggle', 'Лёгкое покачивание при привлечении внимания'],
    ['rise', 'hs-rise', 'Поднятие-опускание сценических элементов'],
    ['burst', 'hs-burst', 'Появление наград и успехов'],
    ['pop', 'hs-pop', 'Вход кнопок и карточек'],
    ['glow', 'hs-glow', 'Пульсация свечения для premium/подсказок'],
    ['flicker', 'hs-flicker', 'Колебание пламени streak'],
    ['float', 'hs-float', 'Плавающие облака и декорации'],
  ];
  return (
    <div style={{ width: '100%', height: '100%', background: '#fff', padding: 40, fontFamily: HS.font.text, overflow: 'hidden' }}>
      <Display size={32}>Motion system · v2</Display>
      <Mono color={HS.kid.inkMuted}>8 КЛЮЧЕВЫХ АНИМАЦИЙ · 150-2200мс · ПРУЖИНА + EASE</Mono>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginTop: 24 }}>
        {anims.map(([n, cls, desc]) => (
          <div key={n} style={{ border: `1px solid ${HS.kid.line}`, borderRadius: 14, padding: 18, textAlign: 'center' }}>
            <div style={{ height: 80, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <div className={cls} style={{ width: 54, height: 54, borderRadius: 14, background: `linear-gradient(135deg, ${HS.brand.primary}, ${HS.brand.lilac})`, boxShadow: '0 4px 14px rgba(150,80,200,0.3)' }}/>
            </div>
            <div style={{ fontFamily: 'Nunito', fontWeight: 800, fontSize: 14, marginTop: 8 }}>.{cls}</div>
            <Body size={10} color={HS.kid.inkMuted} style={{ marginTop: 4 }}>{desc}</Body>
          </div>
        ))}
      </div>
      <div style={{ marginTop: 20, padding: 18, background: HS.kid.bgDeep, borderRadius: 14 }}>
        <Title size={14}>Правила</Title>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 14, marginTop: 10 }}>
          {[
            ['Кнопки', 'spring 200ms · scale 0.96 на tap'],
            ['Персонаж', 'idle bob 3.4s · wing-flap 1.6s'],
            ['Успех', 'burst 1.6s + confetti rise 2s'],
            ['Переходы', 'slide-up 320ms · easeOutQuick'],
            ['Подсказки', 'glow pulse 2s · хальт при тапе'],
            ['Ошибка', 'shake 260ms · мягко, без тревоги'],
          ].map(([h, d]) => (
            <div key={h}><Body size={12} weight={700}>{h}</Body><Body size={10} color={HS.kid.inkMuted}>{d}</Body></div>
          ))}
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 16. ILLUSTRATION RULES CARD — shows scene library
// ─────────────────────────────────────────────────────────────
function IllustrationCard() {
  return (
    <div style={{ width: '100%', height: '100%', background: 'linear-gradient(135deg, oklch(0.97 0.03 60) 0%, oklch(0.94 0.08 30) 100%)', padding: 40, fontFamily: HS.font.text, overflow: 'hidden' }}>
      <Display size={32}>Иллюстрации · «soft 3D»</Display>
      <Mono color={HS.kid.inkMuted}>SVG-СЦЕНЫ С ОБЪЁМОМ · ГРАДИЕНТЫ + БЛИКИ + ТЕНИ</Mono>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16, marginTop: 24 }}>
        {[
          ['SproutScene', 'Запуск речи', <SproutScene w={280} h={180}/>],
          ['AlphaPlayScene', 'Развитие речи', <AlphaPlayScene w={280} h={180}/>],
          ['GamesScene', 'Игры и звуки', <GamesScene w={280} h={180}/>],
          ['SchoolScene', 'Подготовка к школе', <SchoolScene w={280} h={180}/>],
          ['TrophyScene', 'Награды и успех', <TrophyScene w={280} h={180}/>],
          ['SoundIslandScene', 'Мир звуков', <SoundIslandScene w={280} h={180} letter="Р"/>],
        ].map(([n, t, el]) => (
          <div key={n}>
            {el}
            <Body size={13} weight={700} style={{ marginTop: 6 }}>{t}</Body>
            <Mono size={10} color={HS.kid.inkMuted}>{'<'+n+'/>'}</Mono>
          </div>
        ))}
      </div>
      <div style={{ marginTop: 16, padding: 14, background: '#fff', borderRadius: 12, border: `1px solid ${HS.kid.line}` }}>
        <Title size={13}>Правила стиля</Title>
        <Body size={11} color={HS.kid.inkMuted} style={{ marginTop: 4 }}>
          Радиальные градиенты для объёма · 1–2 бликa на объект · базовая тень эллипсом · мягкие пастельные фоны · без эмодзи — только SVG-сцены из библиотеки. Никогда не копируем персонажей других приложений.
        </Body>
      </div>
    </div>
  );
}

Object.assign(window, {
  WelcomeV2Screen, DiagnosticsV2Screen, QuietRoomScreen,
  KidHomeV2Screen, WorldMapV2Screen, LessonArticV2Screen, SuccessV2Screen,
  RewardsV2Screen, StreakV2Screen, PaywallV2Screen,
  ParentLentaScreen, ParentChildV2Screen, ParentSettingsV2Screen, ParentTabBarV2,
  MascotLibraryCard, MotionV2Card, IllustrationCard,
});
