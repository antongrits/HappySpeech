// Specialist mode + additional overlays
const { HS, Butterfly, Phone, Display, Title, Body, Mono, Card, Chip, Ring, Bar, Placeholder } = window;

// Specialist dashboard
function SpecDashboardScreen() {
  return (
    <Phone bg={HS.spec.bg}>
      <div style={{ padding: '16px 16px 20px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
          <div>
            <Mono color={HS.spec.inkMuted}>СПЕЦИАЛИСТ · 6 ДЕТЕЙ</Mono>
            <Title size={22} color={HS.spec.ink}>Дела на сегодня</Title>
          </div>
          <div style={{ background: HS.spec.panel, border: `1px solid ${HS.spec.line}`, borderRadius: 8, padding: '6px 10px', fontSize: 12 }}>⚙</div>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8, marginTop: 14 }}>
          {[['6','Подопечных',HS.spec.accent],['23','Записей',HS.brand.mint],['3','На ревью',HS.sem.warning]].map(([v,l,c]) => (
            <div key={l} style={{ background: HS.spec.surface, border: `1px solid ${HS.spec.line}`, borderRadius: 10, padding: 10 }}>
              <div style={{ width: 20, height: 3, background: c, borderRadius: 2 }}/>
              <Display size={22} style={{ marginTop: 6 }}>{v}</Display>
              <Mono size={9} color={HS.spec.inkMuted}>{l}</Mono>
            </div>
          ))}
        </div>

        <div style={{ marginTop: 14 }}>
          <Mono color={HS.spec.inkMuted} style={{ marginBottom: 6 }}>ПАЦИЕНТЫ</Mono>
          {[
            ['Миша К.','6 лет','/r/ автоматизация','74%',HS.sem.success,'3д'],
            ['Катя В.','5 лет','/ʂ/ постановка','42%',HS.sem.warning,'1д'],
            ['Саша Р.','7 лет','/ts/–/s/ дифф.','88%',HS.sem.success,'2ч'],
            ['Лиза М.','6 лет','/r/ подготовка','28%',HS.sem.error,'5д'],
          ].map(([n,a,t,p,c,d],i) => (
            <div key={n} style={{ background: HS.spec.surface, border: `1px solid ${HS.spec.line}`, borderRadius: 8, padding: '10px 12px', marginBottom: 6, display: 'flex', alignItems: 'center', gap: 10 }}>
              <div style={{ width: 32, height: 32, borderRadius: 8, background: HS.spec.panel, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: HS.font.display, fontWeight: 700, fontSize: 12 }}>{n.split(' ')[0][0]}{n.split(' ')[1][0]}</div>
              <div style={{ flex: 1 }}>
                <Body size={13} weight={600}>{n} · {a}</Body>
                <Mono size={10} color={HS.spec.inkMuted}>{t} · {d}</Mono>
              </div>
              <div style={{ width: 8, height: 8, borderRadius: 4, background: c }}/>
              <Mono size={11} weight={700} style={{ width: 34, textAlign: 'right' }}>{p}</Mono>
            </div>
          ))}
        </div>
      </div>
    </Phone>
  );
}

// Specialist case view with waveform
function SpecCaseScreen() {
  return (
    <Phone bg={HS.spec.bg}>
      <div style={{ padding: '16px 16px 20px' }}>
        <Mono color={HS.spec.inkMuted}>← ВСЕ ДЕТИ</Mono>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 6 }}>
          <div style={{ width: 40, height: 40, borderRadius: 10, background: HS.spec.panel, display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700 }}>МК</div>
          <div style={{ flex: 1 }}>
            <Title size={18} color={HS.spec.ink}>Миша К., 6 лет</Title>
            <Mono size={10} color={HS.spec.inkMuted}>Случай #A-0034 · начат 12.03.26</Mono>
          </div>
          <div style={{ background: HS.spec.accent, color: '#fff', borderRadius: 8, padding: '6px 10px', fontSize: 11, fontWeight: 600 }}>Записать сессию</div>
        </div>

        <div style={{ display: 'flex', gap: 4, marginTop: 12 }}>
          {['Обзор','Цели','Попытки','Анализ','Заметки','Отчёт'].map((t,i) => (
            <div key={t} style={{ padding: '4px 10px', borderRadius: 6, background: i===3?HS.spec.ink:'transparent', color: i===3?'#fff':HS.spec.inkMuted, fontSize: 11, fontWeight: 500 }}>{t}</div>
          ))}
        </div>

        {/* Waveform panel */}
        <div style={{ background: HS.spec.surface, border: `1px solid ${HS.spec.line}`, borderRadius: 8, padding: 12, marginTop: 10 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <Mono size={10} color={HS.spec.inkMuted}>ПОПЫТКА · 21.04 18:42</Mono>
              <Title size={14}>«рыба» · /r/</Title>
            </div>
            <div style={{ display: 'flex', gap: 4 }}>
              <div style={{ width: 26, height: 26, borderRadius: 6, background: HS.spec.panel, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 11 }}>▶</div>
              <div style={{ width: 26, height: 26, borderRadius: 6, background: HS.spec.panel, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 11 }}>⟲</div>
            </div>
          </div>
          {/* waveform */}
          <svg viewBox="0 0 260 70" style={{ width: '100%', height: 70, marginTop: 8 }}>
            <rect x="0" y="0" width="260" height="70" fill={HS.spec.grid}/>
            {Array.from({length:130}).map((_,i) => {
              const h = 30 + Math.sin(i*0.3)*15 + Math.sin(i*0.08)*10 + (Math.random()*6);
              return <rect key={i} x={i*2} y={35-h/2} width="1.4" height={h} fill={i > 40 && i < 90 ? HS.spec.waveform : 'oklch(0.70 0.04 250)'}/>;
            })}
            <rect x="80" y="0" width="100" height="70" fill={HS.spec.target} opacity="0.08"/>
            <line x1="80" y1="0" x2="80" y2="70" stroke={HS.spec.target} strokeDasharray="2 3"/>
            <line x1="180" y1="0" x2="180" y2="70" stroke={HS.spec.target} strokeDasharray="2 3"/>
            <text x="130" y="12" textAnchor="middle" fontSize="8" fill={HS.spec.target} fontFamily="monospace">/r/ target</text>
          </svg>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 6 }}>
            <Mono size={9} color={HS.spec.inkMuted}>0.00s</Mono>
            <Mono size={9} color={HS.spec.inkMuted}>1.24s</Mono>
          </div>
        </div>

        {/* Spectrum */}
        <div style={{ background: HS.spec.surface, border: `1px solid ${HS.spec.line}`, borderRadius: 8, padding: 12, marginTop: 8 }}>
          <Mono size={10} color={HS.spec.inkMuted}>СПЕКТРОГРАММА / LPC</Mono>
          <svg viewBox="0 0 260 80" style={{ width: '100%', height: 80, marginTop: 6 }}>
            {Array.from({length:40}).map((_,i) => (
              Array.from({length:16}).map((_,j) => {
                const v = Math.sin(i*0.3+j*0.2)*0.5 + 0.5;
                return <rect key={`${i}-${j}`} x={i*6.5} y={j*5} width="6" height="4.5" fill={`oklch(${0.35 + v*0.45} ${0.1 + v*0.08} 250)`}/>;
              })
            ))}
            <path d="M0 40 Q 60 35 120 30 Q 180 28 260 32" stroke="oklch(0.85 0.15 60)" strokeWidth="1.5" fill="none"/>
            <path d="M0 60 Q 60 55 120 50 Q 180 48 260 52" stroke="oklch(0.85 0.15 60)" strokeWidth="1.5" fill="none"/>
            <text x="4" y="10" fontSize="8" fill="#fff" fontFamily="monospace">F1·F2</text>
          </svg>
        </div>

        {/* Scoring row */}
        <div style={{ background: HS.spec.surface, border: `1px solid ${HS.spec.line}`, borderRadius: 8, padding: 12, marginTop: 8 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <div>
              <Mono size={10} color={HS.spec.inkMuted}>РУЧНАЯ ОЦЕНКА</Mono>
              <Title size={14}>Качество артикуляции</Title>
            </div>
            <Mono size={10} color={HS.spec.accent}>AI: 72% ✓</Mono>
          </div>
          <div style={{ display: 'flex', gap: 4, marginTop: 10 }}>
            {['✓ Норма','◐ Искаж.','◑ Замена','✕ Пропуск','? Неясно'].map((l,i) => (
              <div key={l} style={{ flex: 1, background: i===0?HS.sem.success:HS.spec.panel, color: i===0?'#fff':HS.spec.ink, padding: '6px 4px', borderRadius: 6, textAlign: 'center', fontSize: 10, fontWeight: 600 }}>{l}</div>
            ))}
          </div>
        </div>
      </div>
    </Phone>
  );
}

// Specialist plan builder
function SpecPlanScreen() {
  return (
    <Phone bg={HS.spec.bg}>
      <div style={{ padding: '16px 16px 20px' }}>
        <Mono color={HS.spec.inkMuted}>МИША К. → ПЛАН</Mono>
        <Title size={20} color={HS.spec.ink}>Конструктор занятий</Title>

        <div style={{ background: HS.spec.surface, border: `1px solid ${HS.spec.line}`, borderRadius: 8, padding: 12, marginTop: 12 }}>
          <Mono size={10} color={HS.spec.inkMuted}>ЦЕЛЕВЫЕ ЗВУКИ</Mono>
          <div style={{ display: 'flex', gap: 4, marginTop: 6, flexWrap: 'wrap' }}>
            {[['Р',true,HS.brand.primary],['Ш',true,HS.brand.lilac],['С',false,HS.brand.sky],['Л',true,HS.brand.primary],['Ж',false,HS.brand.lilac]].map(([s,on,c],i) => (
              <div key={s} style={{ width: 36, height: 36, borderRadius: 8, background: on?c:HS.spec.panel, color: on?'#fff':HS.spec.inkMuted, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: HS.font.display, fontWeight: 700, fontSize: 16, border: on?'none':`1px dashed ${HS.spec.line}` }}>{s}</div>
            ))}
          </div>
        </div>

        <div style={{ background: HS.spec.surface, border: `1px solid ${HS.spec.line}`, borderRadius: 8, padding: 12, marginTop: 8 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <Mono size={10} color={HS.spec.inkMuted}>СТРУКТУРА ЗАНЯТИЯ · 8 мин</Mono>
            <Mono size={10} color={HS.spec.accent}>+ Добавить</Mono>
          </div>
          {[
            ['1','Разминка дыхания','60с',HS.brand.sky],
            ['2','Артикуляция: «Парус»','60с',HS.brand.mint],
            ['3','Изолир. /r/ → слоги','120с',HS.brand.primary],
            ['4','Слова: начало (8 слов)','120с',HS.brand.primary],
            ['5','Визуально-акуст. студия','90с',HS.brand.lilac],
            ['6','Finale: сказка','30с',HS.brand.butter],
          ].map(([i,t,d,c]) => (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '8px 0', borderBottom: `1px solid ${HS.spec.line}` }}>
              <Mono color={HS.spec.inkMuted} style={{ width: 14 }}>{i}</Mono>
              <div style={{ width: 3, height: 24, background: c, borderRadius: 2 }}/>
              <Body size={12} style={{ flex: 1 }}>{t}</Body>
              <Mono size={10} color={HS.spec.inkMuted}>{d}</Mono>
              <div style={{ color: HS.spec.inkMuted, fontSize: 11 }}>⋮</div>
            </div>
          ))}
        </div>

        <div style={{ display: 'flex', gap: 6, marginTop: 10 }}>
          <div style={{ flex: 1, background: HS.spec.panel, border: `1px solid ${HS.spec.line}`, borderRadius: 8, padding: 10, textAlign: 'center', fontSize: 12 }}>Черновик</div>
          <div style={{ flex: 2, background: HS.spec.accent, color: '#fff', borderRadius: 8, padding: 10, textAlign: 'center', fontSize: 12, fontWeight: 600 }}>Отправить Мише</div>
        </div>
      </div>
    </Phone>
  );
}

// Session comparison
function SpecComparisonScreen() {
  return (
    <Phone bg={HS.spec.bg}>
      <div style={{ padding: '16px 16px 20px' }}>
        <Mono color={HS.spec.inkMuted}>МИША К. → АНАЛИЗ</Mono>
        <Title size={20} color={HS.spec.ink}>Сравнение сессий</Title>

        {[['12.03 · начало','28%',HS.sem.error,[20,30,25,35,40,30,38]],
          ['05.04 · после 4 нед','58%',HS.sem.warning,[40,50,48,55,60,58,62]],
          ['21.04 · сегодня','74%',HS.sem.success,[50,60,68,72,70,76,80]]].map(([d,a,c,vals],i) => (
          <div key={i} style={{ background: HS.spec.surface, border: `1px solid ${HS.spec.line}`, borderRadius: 8, padding: 12, marginTop: 8 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <Mono size={10} color={HS.spec.inkMuted}>{d}</Mono>
                <Title size={14}>Точность /r/ · {a}</Title>
              </div>
              <div style={{ width: 8, height: 8, borderRadius: 4, background: c }}/>
            </div>
            <div style={{ display: 'flex', gap: 3, alignItems: 'flex-end', marginTop: 8, height: 50 }}>
              {vals.map((v,j) => <div key={j} style={{ flex: 1, height: `${v}%`, background: c, opacity: 0.5 + j*0.07, borderRadius: 2 }}/>)}
            </div>
          </div>
        ))}

        <div style={{ background: `color-mix(in oklch, ${HS.spec.accent} 6%, white)`, border: `1px solid ${HS.spec.accent}`, borderRadius: 8, padding: 12, marginTop: 10 }}>
          <Mono size={10} color={HS.spec.accent} weight={700}>AI СВОДКА</Mono>
          <Body size={12} style={{ marginTop: 4, color: HS.spec.ink }}>Рост +46% за 40 дней. Стабилизация на уровне слога. Рекомендуется переход к словам с /r/ в позиции «начало».</Body>
        </div>
      </div>
    </Phone>
  );
}

// Onboarding: intro carousel slide
function IntroCarouselScreen() {
  return (
    <Phone bg="linear-gradient(180deg, oklch(0.95 0.05 200), oklch(0.97 0.03 80))">
      <div style={{ position: 'absolute', inset: 0, padding: '40px 24px 24px', display: 'flex', flexDirection: 'column' }}>
        <Mono color={HS.kid.inkMuted}>3 / 4</Mono>
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center' }}>
          <div style={{ width: 220, height: 220, borderRadius: 110, background: `radial-gradient(circle, ${HS.brand.mint} 0%, transparent 70%)`, position: 'absolute', top: 120, filter: 'blur(10px)' }}/>
          <div style={{ position: 'relative', width: 200, height: 180 }}>
            <Butterfly size={100} style={{ position: 'absolute', left: 40, top: 10 }}/>
            <div style={{ position: 'absolute', right: 0, top: 40, width: 60, height: 60, borderRadius: 20, background: '#fff', boxShadow: HS.kid.shadow, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 28 }}>🎤</div>
            <div style={{ position: 'absolute', left: 10, bottom: 0, width: 60, height: 60, borderRadius: 20, background: '#fff', boxShadow: HS.kid.shadow, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 28 }}>✨</div>
          </div>
          <Display size={24} color={HS.kid.ink} style={{ marginTop: 24 }}>Играй. Говори.<br/>Получай награды.</Display>
          <Body color={HS.kid.inkMuted} style={{ marginTop: 10, maxWidth: 260 }}>Короткие игры по 7 минут. Без перегруза. С настоящей обратной связью.</Body>
        </div>
        <div style={{ display: 'flex', justifyContent: 'center', gap: 6, marginBottom: 16 }}>
          {[0,1,2,3].map(i => <div key={i} style={{ width: i === 2 ? 20 : 6, height: 6, borderRadius: 3, background: i === 2 ? HS.brand.primary : HS.kid.line }}/>)}
        </div>
        <div style={{ display: 'flex', gap: 10 }}>
          <div style={{ flex: 1, padding: 14, borderRadius: 18, textAlign: 'center', color: HS.kid.inkMuted, fontWeight: 600 }}>Пропустить</div>
          <div style={{ flex: 1.5, background: HS.brand.primary, color: '#fff', padding: 14, borderRadius: 18, textAlign: 'center', fontFamily: HS.font.display, fontWeight: 800 }}>Дальше</div>
        </div>
      </div>
    </Phone>
  );
}

// Initial screening assessment
function AssessmentScreen() {
  return (
    <Phone bg={HS.parent.bg}>
      <div style={{ padding: '16px 16px 20px' }}>
        <Mono color={HS.parent.inkMuted}>ПЕРВИЧНАЯ ОЦЕНКА · 3/8</Mono>
        <Title size={20} color={HS.parent.ink} style={{ marginTop: 4 }}>Что чаще всего беспокоит?</Title>
        <Body size={12} color={HS.parent.inkMuted}>Выберите все подходящее</Body>
        <div style={{ marginTop: 16, display: 'flex', flexDirection: 'column', gap: 8 }}>
          {[
            ['Не выговаривает Р', true],
            ['Путает С и Ш', true],
            ['Говорит невнятно', false],
            ['Пропускает слоги', false],
            ['Заменяет звуки', true],
            ['Горловое произношение', false],
          ].map(([l,on]) => (
            <div key={l} style={{ background: HS.parent.surface, border: `1.5px solid ${on?HS.parent.accent:HS.parent.line}`, borderRadius: 12, padding: 14, display: 'flex', alignItems: 'center', gap: 10 }}>
              <div style={{ width: 22, height: 22, borderRadius: 6, background: on?HS.parent.accent:'transparent', border: `1.5px solid ${on?HS.parent.accent:HS.parent.line}`, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 13 }}>{on && '✓'}</div>
              <Body size={14}>{l}</Body>
            </div>
          ))}
        </div>
        <div style={{ background: HS.parent.accent, color: '#fff', padding: 14, borderRadius: 14, textAlign: 'center', fontWeight: 600, marginTop: 16 }}>Далее</div>
      </div>
    </Phone>
  );
}

// Notification / reminder
function NotificationScreen() {
  return (
    <Phone bg="linear-gradient(180deg, oklch(0.82 0.08 200), oklch(0.88 0.05 80))" dark>
      <div style={{ position: 'absolute', inset: 0 }}>
        <div style={{ position: 'absolute', top: 80, left: 12, right: 12, background: 'rgba(245,245,250,0.85)', backdropFilter: 'blur(30px)', borderRadius: 18, padding: 14, boxShadow: '0 10px 30px rgba(0,0,0,0.15)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <div style={{ width: 22, height: 22, borderRadius: 5, background: HS.brand.primary, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <div style={{ width: 14, height: 14 }}><Butterfly size={18}/></div>
            </div>
            <Mono size={10} weight={600} color={HS.kid.ink}>HAPPYSPEECH</Mono>
            <Mono size={10} color={HS.kid.inkSoft} style={{ marginLeft: 'auto' }}>сейчас</Mono>
          </div>
          <Title size={15} style={{ marginTop: 6 }}>Ляля зовёт играть! 🦋</Title>
          <Body size={13} color={HS.kid.inkMuted} style={{ marginTop: 2 }}>У Миши огонёк 6 дней. Не теряем его — всего 7 минут!</Body>
        </div>
        <div style={{ position: 'absolute', bottom: 120, left: 0, right: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', color: '#fff' }}>
          <Display size={56} color="#fff" style={{ fontWeight: 300, letterSpacing: -2 }}>19:30</Display>
          <Body color="#fff" style={{ opacity: 0.9 }}>вторник, 21 апреля</Body>
        </div>
      </div>
    </Phone>
  );
}

// Home practice without phone
function HomePracticeScreen() {
  return (
    <Phone bg={HS.parent.bg}>
      <div style={{ padding: '16px 16px 20px' }}>
        <Mono color={HS.parent.inkMuted}>РОДИТЕЛЯМ</Mono>
        <Title size={22} color={HS.parent.ink}>5 минут без телефона</Title>
        <Body size={12} color={HS.parent.inkMuted}>Сегодня вечером · звук Р</Body>

        <Card style={{ marginTop: 14, background: `color-mix(in oklch, ${HS.brand.mint} 7%, white)`, border: `1px solid color-mix(in oklch, ${HS.brand.mint} 30%, white)` }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ fontSize: 28 }}>🍽️</div>
            <div>
              <Title size={14}>За ужином</Title>
              <Mono size={10} color={HS.parent.inkMuted}>2 мин · игра «Что на столе?»</Mono>
            </div>
          </div>
          <Body size={12} style={{ marginTop: 8 }}>Найдите на столе 5 предметов со звуком Р: <b>р</b>ис, ог<b>р</b>ом<b>р</b>ый, ку<b>р</b>ица, моло<b>к</b>о… Проговорите медленно.</Body>
        </Card>

        <Card style={{ marginTop: 8 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ fontSize: 28 }}>🚶</div>
            <div>
              <Title size={14}>По дороге домой</Title>
              <Mono size={10} color={HS.parent.inkMuted}>3 мин · игра «Угадайка»</Mono>
            </div>
          </div>
          <Body size={12} style={{ marginTop: 8 }}>«Я вижу что-то круглое, <b>р</b>азноцветное…» — ребёнок угадывает и повторяет слово.</Body>
        </Card>

        <div style={{ background: HS.sem.infoBg, borderRadius: 12, padding: 14, marginTop: 10 }}>
          <Title size={13} color={HS.sem.info}>Совет</Title>
          <Body size={12} style={{ marginTop: 4 }}>Хвалите не результат, а старание: «Я заметил, как ты старался рычать!»</Body>
        </div>
      </div>
    </Phone>
  );
}

// Screen map / architecture
function ScreenMapCard() {
  const groups = [
    ['Вход', HS.brand.primary, ['Splash','Welcome','Intro ×4','Role','SignUp','AddChild','Permissions','Offline intro','Privacy']],
    ['Ассесмент', HS.parent.accent, ['Скрининг ×8','Первый профиль','Целевые звуки','Расписание','Сводка']],
    ['Детский — Home', HS.brand.mint, ['Home','Map','Today','Quickstart','Choose mascot','Choose world','Progress']],
    ['Lesson player', HS.brand.sky, ['Warmup','Articulation','Breathing','Voice','Listen','Discriminate','Repeat','Syllables','Words','Phrases','Picture','Story','Record','Processing','Feedback','Try again','Pause','End']],
    ['AR', HS.brand.lilac, ['Lobby','Tutorial','Permission','Mirror','Tongue game','Mouth','Lips','Hold pose','Combo','Success','Retry','Results','Low tracking']],
    ['Rewards', HS.brand.butter, ['Reward moment','Sticker unlock','Level up','Collection','Album','Streak','Profile','Next adventure']],
    ['Родитель', HS.parent.accent, ['Dashboard','Children','Child detail','Sound map','Weekly plan','Daily rec','Analytics','History','Audio archive','Rewards view','Motivation','Session len','Difficulty','Screen time','Content packs','Models','Notifications','Reminders','Tips library','Home practice','Reports','Account','Privacy','Sync','Help','About']],
    ['Specialist', HS.spec.accent, ['Dashboard','Case','Goals','Targets','Plan builder','Attempts','Waveform','Comparison','Scoring','Notes','Labeling','Export','Monthly','Homework']],
    ['Системные', HS.kid.inkMuted, ['Loading','Empty','Success','Error','Offline','Sync','No mic','No camera','Low tracking','Tired kid','Parental gate','Notification','Downloading']],
  ];
  return (
    <div style={{ padding: 28, background: HS.kid.bg, width: '100%', height: '100%', overflow: 'hidden', fontFamily: HS.font.text }}>
      <Mono color={HS.kid.inkMuted}>PRODUCT MAP · SCREEN INVENTORY</Mono>
      <Display size={30}>Полная карта экранов</Display>
      <Body color={HS.kid.inkMuted} style={{ marginTop: 4 }}>9 групп · 100+ состояний · единая логика навигации по трём контурам</Body>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10, marginTop: 18 }}>
        {groups.map(([g,c,items]) => (
          <div key={g} style={{ background: '#fff', borderRadius: 14, padding: 12, border: `1px solid ${HS.kid.line}` }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <div style={{ width: 10, height: 10, borderRadius: 5, background: c }}/>
              <Title size={14}>{g}</Title>
              <Mono size={9} color={HS.kid.inkMuted} style={{ marginLeft: 'auto' }}>{items.length}</Mono>
            </div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 3, marginTop: 8 }}>
              {items.map(it => (
                <div key={it} style={{ padding: '2px 7px', borderRadius: 99, background: `color-mix(in oklch, ${c} 10%, white)`, fontSize: 10, color: HS.kid.ink, border: `1px solid color-mix(in oklch, ${c} 20%, white)` }}>{it}</div>
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// Motion rules card
function MotionRulesCard() {
  return (
    <div style={{ padding: 28, background: HS.kid.bg, width: '100%', height: '100%', overflow: 'hidden', fontFamily: HS.font.text }}>
      <Mono color={HS.kid.inkMuted}>MOTION SYSTEM</Mono>
      <Display size={28}>Язык движения</Display>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 20, marginTop: 16 }}>
        <div>
          <Title size={14}>Длительности</Title>
          <div style={{ marginTop: 8 }}>
            {[['xs',120,'микроподсветка'],['sm',180,'tap bounce'],['md',240,'card reveal'],['lg',360,'screen in/out'],['xl',600,'reward burst']].map(([n,v,d]) => (
              <div key={n} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '6px 0', borderBottom: `1px solid ${HS.kid.line}` }}>
                <Mono style={{ width: 24 }}>{n}</Mono>
                <Body size={12} weight={700} style={{ width: 50 }}>{v}ms</Body>
                <div style={{ flex: 1, height: 4, background: HS.kid.line, borderRadius: 2, overflow: 'hidden' }}>
                  <div style={{ width: `${v/10}%`, height: '100%', background: HS.brand.primary }}/>
                </div>
                <Mono size={10} color={HS.kid.inkMuted} style={{ width: 100 }}>{d}</Mono>
              </div>
            ))}
          </div>
        </div>
        <div>
          <Title size={14}>Easing кривые</Title>
          <div style={{ marginTop: 8 }}>
            {[['out-quick','cubic-bezier(0.16, 1, 0.3, 1)','обычные переходы'],['spring','cubic-bezier(0.34, 1.56, 0.64, 1)','kid bounce'],['bounce','cubic-bezier(0.68, -0.55, 0.27, 1.55)','награды'],['linear','linear','идл/фон']].map(([n,v,d]) => (
              <div key={n} style={{ padding: '6px 0', borderBottom: `1px solid ${HS.kid.line}` }}>
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <Body size={12} weight={700}>{n}</Body>
                  <Mono size={10} color={HS.kid.inkMuted}>{d}</Mono>
                </div>
                <Mono size={9} color={HS.kid.inkSoft}>{v}</Mono>
              </div>
            ))}
          </div>
        </div>
      </div>
      <div style={{ marginTop: 20 }}>
        <Title size={14}>Движения бабочки</Title>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 10, marginTop: 10 }}>
          {[['happy','idle'],['celebrating','success'],['thinking','retry'],['listening','record'],['sleeping','pause']].map(([m,c]) => (
            <div key={m} style={{ background: '#fff', borderRadius: 14, padding: 10, textAlign: 'center', boxShadow: HS.kid.shadow }}>
              <Butterfly size={56} mood={m}/>
              <Body size={10} weight={700} style={{ marginTop: 6 }}>{m}</Body>
              <Mono size={9} color={HS.kid.inkMuted}>{c}</Mono>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

// Component library card
function ComponentLibraryCard() {
  const { KidCTA, KidTile, Chip, Bar, Ring, Speech } = window;
  return (
    <div style={{ padding: 28, background: HS.kid.bg, width: '100%', height: '100%', overflow: 'hidden', fontFamily: HS.font.text }}>
      <Mono color={HS.kid.inkMuted}>COMPONENTS LIBRARY · 24 TYPES × 6 STATES</Mono>
      <Display size={26}>Компонентная система</Display>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 16, marginTop: 16 }}>
        <div>
          <Mono color={HS.kid.inkMuted}>BUTTONS</Mono>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginTop: 8 }}>
            <KidCTA label="Primary"/>
            <KidCTA label="Secondary" color={HS.brand.sky} dark="oklch(0.55 0.12 230)"/>
            <div style={{ background: '#fff', border: `2px solid ${HS.kid.line}`, padding: '12px 20px', borderRadius: 20, textAlign: 'center', fontWeight: 700 }}>Tertiary</div>
            <div style={{ background: HS.kid.line, color: HS.kid.inkSoft, padding: '12px 20px', borderRadius: 20, textAlign: 'center', fontWeight: 700 }}>Disabled</div>
            <div style={{ display: 'flex', gap: 6 }}>
              <div style={{ width: 48, height: 48, borderRadius: 24, background: HS.brand.primary, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>＋</div>
              <div style={{ width: 48, height: 48, borderRadius: 24, background: '#fff', border: `2px solid ${HS.kid.line}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>🎤</div>
              <div style={{ width: 48, height: 48, borderRadius: 24, background: HS.sem.success, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>✓</div>
            </div>
          </div>
        </div>
        <div>
          <Mono color={HS.kid.inkMuted}>FEEDBACK</Mono>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginTop: 8 }}>
            <div style={{ background: HS.sem.successBg, color: HS.sem.success, padding: 10, borderRadius: 12, fontSize: 12, fontWeight: 600 }}>✓ Отлично получилось!</div>
            <div style={{ background: HS.sem.warningBg, color: HS.sem.warning, padding: 10, borderRadius: 12, fontSize: 12, fontWeight: 600 }}>◐ Почти — попробуем ещё</div>
            <div style={{ background: HS.sem.errorBg, color: HS.sem.error, padding: 10, borderRadius: 12, fontSize: 12, fontWeight: 600 }}>✕ Нет звука в микрофоне</div>
            <div style={{ background: HS.sem.infoBg, color: HS.sem.info, padding: 10, borderRadius: 12, fontSize: 12, fontWeight: 600 }}>i Скачиваем пакет 420 МБ</div>
            <Speech>Умничка!</Speech>
            <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
              <Chip label="свистящие" filled color={HS.brand.sky}/>
              <Chip label="в работе" color={HS.sem.success}/>
              <Chip label="заблокировано" color={HS.kid.inkSoft}/>
            </div>
          </div>
        </div>
        <div>
          <Mono color={HS.kid.inkMuted}>PROGRESS · CARDS</Mono>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginTop: 8 }}>
            <Bar value={72}/>
            <Bar value={40} color={HS.brand.lilac}/>
            <div style={{ display: 'flex', gap: 8 }}>
              <Ring size={48} value={74}><Body size={11} weight={700}>74%</Body></Ring>
              <Ring size={48} value={42} color={HS.brand.lilac}><Body size={11} weight={700}>42%</Body></Ring>
              <Ring size={48} value={92} color={HS.sem.success}><Body size={11} weight={700}>92%</Body></Ring>
            </div>
            <KidTile color={HS.brand.primary} icon="Р" label="Звук Р" sub="в словах" progress={62}/>
          </div>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, {
  SpecDashboardScreen, SpecCaseScreen, SpecPlanScreen, SpecComparisonScreen,
  IntroCarouselScreen, AssessmentScreen, NotificationScreen, HomePracticeScreen,
  ScreenMapCard, MotionRulesCard, ComponentLibraryCard,
});
