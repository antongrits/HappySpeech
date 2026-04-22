// PARENT + SPECIALIST screens
const { HS, Butterfly, Phone, Display, Title, Body, Mono, Card, Chip, Ring, Bar, Placeholder, ParentTabBar } = window;

// Tiny inline chart helpers
function MiniSpark({ values, color = HS.parent.accent, h = 40 }) {
  const w = 200;
  const max = Math.max(...values);
  const pts = values.map((v, i) => `${(i/(values.length-1))*w},${h - (v/max)*h*0.9}`).join(' ');
  return (
    <svg viewBox={`0 0 ${w} ${h}`} style={{ width: '100%', height: h }}>
      <polyline points={pts} fill="none" stroke={color} strokeWidth="2.5" strokeLinecap="round"/>
      <polyline points={`0,${h} ${pts} ${w},${h}`} fill={color} opacity="0.1"/>
    </svg>
  );
}

function BarChart({ values, color = HS.parent.accent, h = 80 }) {
  const max = Math.max(...values, 1);
  return (
    <div style={{ display: 'flex', alignItems: 'flex-end', gap: 3, height: h, paddingTop: 6 }}>
      {values.map((v,i) => (
        <div key={i} style={{ flex: 1, height: `${(v/max)*100}%`, background: `color-mix(in oklch, ${color} ${60 + i*3}%, white)`, borderRadius: 4, minHeight: 3 }}/>
      ))}
    </div>
  );
}

// 1) Parent dashboard
function ParentDashboardScreen() {
  return (
    <Phone bg={HS.parent.bgDeep}>
      <div style={{ padding: '16px 16px 80px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div>
            <Body size={12} color={HS.parent.inkMuted}>Кабинет родителя</Body>
            <Title size={24} color={HS.parent.ink}>Привет, Анна</Title>
          </div>
          <div style={{ width: 36, height: 36, borderRadius: 18, background: HS.parent.surface, border: `1px solid ${HS.parent.line}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>👤</div>
        </div>

        {/* Child switcher */}
        <div style={{ display: 'flex', gap: 8, marginTop: 14 }}>
          {[['Миша','🦊',true],['Катя','🐰',false]].map(([n,e,a]) => (
            <div key={n} style={{ display: 'flex', gap: 8, padding: '8px 12px', borderRadius: 14, background: a ? HS.parent.surface : 'transparent', border: `1px solid ${a ? HS.parent.lineStrong : HS.parent.line}`, alignItems: 'center' }}>
              <div style={{ width: 24, height: 24, borderRadius: 12, background: HS.brand.mint, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 14 }}>{e}</div>
              <Body size={13} weight={a?700:500}>{n}</Body>
            </div>
          ))}
          <div style={{ padding: '8px 12px', borderRadius: 14, border: `1px dashed ${HS.parent.line}`, color: HS.parent.inkSoft, fontSize: 13 }}>+ Профиль</div>
        </div>

        {/* Today summary */}
        <Card style={{ marginTop: 14 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div>
              <Mono color={HS.parent.inkSoft}>СЕГОДНЯ</Mono>
              <Title size={18} color={HS.parent.ink} style={{ marginTop: 2 }}>Хорошая тренировка</Title>
              <Body size={12} color={HS.parent.inkMuted} style={{ marginTop: 2 }}>Миша позанимался 8 мин · 5 упражнений</Body>
            </div>
            <Ring size={54} value={84} color={HS.sem.success}>
              <div style={{ fontSize: 14, fontWeight: 700 }}>84%</div>
            </Ring>
          </div>
          <div style={{ display: 'flex', gap: 14, marginTop: 14, paddingTop: 14, borderTop: `1px solid ${HS.parent.line}` }}>
            {[['8′','Время'],['27','Попыток'],['Р·Ш','Звуки'],['+24','⭐']].map(([v,l]) => (
              <div key={l}>
                <Title size={15}>{v}</Title>
                <Mono size={9} color={HS.parent.inkMuted}>{l}</Mono>
              </div>
            ))}
          </div>
        </Card>

        {/* Weekly activity */}
        <Card style={{ marginTop: 10 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <Title size={14}>Активность за 14 дней</Title>
            <Chip label="Ещё" color={HS.parent.inkSoft}/>
          </div>
          <BarChart values={[3,5,4,6,8,7,5,9,6,8,7,9,10,8]} color={HS.parent.accent} h={60}/>
        </Card>

        {/* AI summary */}
        <Card style={{ marginTop: 10, background: `color-mix(in oklch, ${HS.brand.lilac} 6%, white)`, border: `1px solid ${HS.brand.lilac}` }}>
          <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
            <Sparkle/><Mono color={HS.brand.lilac} style={{ fontWeight: 700 }}>AI-СВОДКА</Mono>
          </div>
          <Body size={13} color={HS.parent.ink} style={{ marginTop: 6 }}>Звук Р становится увереннее — точность выросла с 58% до 74% за неделю. Можно переходить от изолированных слогов к словам.</Body>
        </Card>

        {/* Recommendation */}
        <Card style={{ marginTop: 10 }}>
          <Title size={14}>Что делать вечером</Title>
          <Body size={12} color={HS.parent.inkMuted} style={{ marginTop: 2 }}>7-минутная сессия без телефона</Body>
          <div style={{ display: 'flex', gap: 8, marginTop: 10 }}>
            <Chip label="Разминка 1 мин" color={HS.sem.success}/>
            <Chip label="Ш в словах" color={HS.brand.lilac}/>
            <Chip label="Сказка" color={HS.brand.sky}/>
          </div>
        </Card>
      </div>
      <ParentTabBar active="overview"/>
    </Phone>
  );
}

function Sparkle() {
  return <div style={{ width: 10, height: 10 }}><svg viewBox="-5 -5 10 10"><path d="M0 -4 L1 -1 L4 0 L1 1 L0 4 L-1 1 L-4 0 L-1 -1 Z" fill={HS.brand.lilac}/></svg></div>;
}

// 2) Child profile detail
function ChildProfileScreen() {
  return (
    <Phone bg={HS.parent.bg}>
      <div style={{ padding: '16px 16px 80px' }}>
        <Body size={12} color={HS.parent.inkMuted}>← Дети</Body>
        <div style={{ display: 'flex', gap: 12, marginTop: 8, alignItems: 'center' }}>
          <div style={{ width: 64, height: 64, borderRadius: 32, background: HS.brand.mint, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 32 }}>🦊</div>
          <div>
            <Title size={22} color={HS.parent.ink}>Миша, 6 лет</Title>
            <Body size={12} color={HS.parent.inkMuted}>Начал: 12.03.2026 · 34 дня</Body>
          </div>
        </div>
        <div style={{ display: 'flex', gap: 8, marginTop: 14 }}>
          {['Обзор','Звуки','История','Настройки'].map((t,i) => (
            <div key={t} style={{ padding: '6px 12px', borderRadius: 99, background: i===0?HS.parent.ink:HS.parent.surface, color: i===0?'#fff':HS.parent.inkMuted, border: `1px solid ${HS.parent.line}`, fontSize: 12, fontWeight: 500 }}>{t}</div>
          ))}
        </div>

        <Card style={{ marginTop: 12 }}>
          <Title size={14}>Общий прогресс</Title>
          <div style={{ display: 'flex', gap: 14, marginTop: 10 }}>
            <Ring size={80} value={62} stroke={8} color={HS.parent.accent}>
              <div style={{ textAlign: 'center' }}>
                <Display size={22}>62%</Display>
                <Mono size={9} color={HS.parent.inkMuted}>общий</Mono>
              </div>
            </Ring>
            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 6, justifyContent: 'center' }}>
              {[['Подготовка',95, HS.sem.success],['Постановка',82, HS.brand.primary],['Автоматизация',58, HS.brand.lilac],['Дифференциация',28, HS.kid.line]].map(([l,v,c]) => (
                <div key={l}>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <Body size={11} color={HS.parent.ink}>{l}</Body>
                    <Mono size={10} color={HS.parent.inkMuted}>{v}%</Mono>
                  </div>
                  <Bar value={v} color={c} height={5} track={HS.parent.line}/>
                </div>
              ))}
            </div>
          </div>
        </Card>

        <Card style={{ marginTop: 10 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <Title size={14}>Целевые звуки</Title>
            <Body size={12} color={HS.parent.accent}>Изменить</Body>
          </div>
          {[['Р','Сонорный','primary',74],['Ш','Шипящий','lilac',52],['С','Свистящий','sky',94],['Л','Сонорный','primary',38]].map(([s,f,c,v]) => (
            <div key={s} style={{ padding: '10px 0', borderBottom: `1px solid ${HS.parent.line}`, display: 'flex', alignItems: 'center', gap: 12 }}>
              <div style={{ width: 36, height: 36, borderRadius: 10, background: HS.brand[c], color: '#fff', fontFamily: HS.font.display, fontWeight: 800, fontSize: 18, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{s}</div>
              <div style={{ flex: 1 }}>
                <Body size={13} weight={600}>{s} · {f}</Body>
                <Bar value={v} color={HS.brand[c]} height={4} track={HS.parent.line} style={{ marginTop: 4 }}/>
              </div>
              <Mono size={10} color={HS.parent.inkMuted}>{v}%</Mono>
            </div>
          ))}
        </Card>
      </div>
      <ParentTabBar active="overview"/>
    </Phone>
  );
}

// 3) Sound map
function SoundMapScreen() {
  return (
    <Phone bg={HS.parent.bg}>
      <div style={{ padding: '16px 16px 80px' }}>
        <Body size={12} color={HS.parent.inkMuted}>← Миша</Body>
        <Title size={22} color={HS.parent.ink} style={{ marginTop: 4 }}>Карта звуков</Title>
        <Body size={12} color={HS.parent.inkMuted}>По группам и стадиям работы</Body>

        <Card style={{ marginTop: 12 }}>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            {Object.entries(HS.soundFamily).slice(0,4).map(([k,f]) => (
              <div key={k} style={{ background: f.bg, borderRadius: 10, padding: 8, minWidth: 100, flex: 1 }}>
                <Mono size={9} color={HS.parent.inkMuted}>{f.name.toUpperCase()}</Mono>
                <div style={{ display: 'flex', gap: 4, marginTop: 4 }}>
                  {['С','З','Ц'].slice(0, 3).map((s,i) => (
                    <div key={i} style={{ width: 26, height: 26, borderRadius: 7, background: f.hue, color: '#fff', fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 12 }}>{s}</div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </Card>

        <Card style={{ marginTop: 10 }}>
          <Title size={14}>Звук Р · в фокусе</Title>
          <Body size={12} color={HS.parent.inkMuted}>Сонорный · старт 12.03</Body>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 12 }}>
            {[['Подг.','✓', HS.sem.success],['Пост.','◐', HS.sem.success],['Автом.','●', HS.brand.primary],['Дифф.','○', HS.kid.line],['Речь','○', HS.kid.line]].map(([l,ic,c]) => (
              <div key={l} style={{ textAlign: 'center' }}>
                <div style={{ width: 36, height: 36, borderRadius: 18, background: c, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, fontSize: 14 }}>{ic}</div>
                <Mono size={9} color={HS.parent.inkMuted} style={{ marginTop: 4 }}>{l}</Mono>
              </div>
            ))}
          </div>
          <div style={{ marginTop: 12 }}>
            <MiniSpark values={[40,44,48,52,58,62,68,72,74]} color={HS.brand.primary} h={50}/>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <Mono size={9} color={HS.parent.inkMuted}>2 нед. назад</Mono>
              <Mono size={9} color={HS.parent.inkMuted}>сейчас · 74%</Mono>
            </div>
          </div>
        </Card>

        <Card style={{ marginTop: 10 }}>
          <Title size={14}>Позиция звука в слове</Title>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8, marginTop: 10 }}>
            {[['Начало', 86],['Середина', 68],['Конец', 52]].map(([p,v]) => (
              <div key={p} style={{ background: HS.parent.bgDeep, borderRadius: 10, padding: 10, textAlign: 'center' }}>
                <Display size={22}>{v}%</Display>
                <Mono size={9} color={HS.parent.inkMuted}>{p}</Mono>
              </div>
            ))}
          </div>
        </Card>
      </div>
      <ParentTabBar active="analytics"/>
    </Phone>
  );
}

// 4) Weekly plan
function WeeklyPlanScreen() {
  const days = ['Пн','Вт','Ср','Чт','Пт','Сб','Вс'];
  return (
    <Phone bg={HS.parent.bg}>
      <div style={{ padding: '16px 16px 80px' }}>
        <Title size={22} color={HS.parent.ink}>План на неделю</Title>
        <Body size={12} color={HS.parent.inkMuted}>Составлен на основе прогресса</Body>

        <div style={{ display: 'flex', gap: 4, marginTop: 14 }}>
          {days.map((d,i) => (
            <div key={d} style={{ flex: 1, background: i < 4 ? HS.parent.accent : HS.parent.surface, color: i < 4 ? '#fff' : HS.parent.ink, border: `1px solid ${HS.parent.line}`, borderRadius: 8, padding: '8px 4px', textAlign: 'center' }}>
              <Mono size={9} color={i < 4 ? 'rgba(255,255,255,0.7)' : HS.parent.inkMuted}>{d}</Mono>
              <Title size={14} color={i < 4 ? '#fff' : HS.parent.ink}>{i+11}</Title>
              <div style={{ fontSize: 9, marginTop: 2 }}>{i < 4 ? '✓' : i === 4 ? '●' : '·'}</div>
            </div>
          ))}
        </div>

        <Card style={{ marginTop: 14 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <div>
              <Mono color={HS.parent.inkSoft}>ПЯТНИЦА · СЕГОДНЯ</Mono>
              <Title size={18}>Автоматизация Р в словах</Title>
            </div>
            <Chip label="7 мин" color={HS.parent.accent}/>
          </div>
          {[
            ['⏱', 'Разминка дыхания', '1 мин'],
            ['👄', 'Артикуляция «Заборчик»', '1 мин'],
            ['🔊', 'Слоги РА-РО-РУ', '2 мин'],
            ['📖', 'Слова в начале', '2 мин'],
            ['🌸', 'Короткая сказка', '1 мин'],
          ].map(([e,t,d],i) => (
            <div key={t} style={{ padding: '10px 0', borderBottom: i < 4 ? `1px solid ${HS.parent.line}` : 'none', display: 'flex', alignItems: 'center', gap: 10 }}>
              <div style={{ width: 30, height: 30, borderRadius: 8, background: HS.parent.bgDeep, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{e}</div>
              <div style={{ flex: 1 }}>
                <Body size={13} weight={600}>{t}</Body>
              </div>
              <Mono size={10} color={HS.parent.inkMuted}>{d}</Mono>
            </div>
          ))}
        </Card>

        <Card style={{ marginTop: 10, background: HS.sem.infoBg, border: `1px solid color-mix(in oklch, ${HS.sem.info} 20%, white)` }}>
          <Title size={13} color={HS.sem.info}>📱 Без телефона</Title>
          <Body size={12} color={HS.parent.ink} style={{ marginTop: 4 }}>Вечером: 5 минут — проговорите вместе слова с Р: рыба, радуга, ромашка, ракета.</Body>
        </Card>
      </div>
      <ParentTabBar active="plan"/>
    </Phone>
  );
}

// 5) Analytics detailed
function AnalyticsScreen() {
  return (
    <Phone bg={HS.parent.bg}>
      <div style={{ padding: '16px 16px 80px' }}>
        <Title size={22} color={HS.parent.ink}>Аналитика</Title>
        <div style={{ display: 'flex', gap: 6, marginTop: 10 }}>
          {['Неделя','Месяц','3 мес','Всё'].map((t,i) => (
            <div key={t} style={{ padding: '6px 12px', borderRadius: 8, background: i===1?HS.parent.ink:HS.parent.surface, color: i===1?'#fff':HS.parent.ink, border: `1px solid ${HS.parent.line}`, fontSize: 12 }}>{t}</div>
          ))}
        </div>

        <Card style={{ marginTop: 10 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <Title size={14}>Точность звука Р</Title>
            <Chip label="+16%" filled color={HS.sem.success}/>
          </div>
          <MiniSpark values={[42,48,44,52,58,54,62,68,66,72,74,76]} color={HS.brand.primary} h={80}/>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 6 }}>
            <Mono size={10} color={HS.parent.inkMuted}>12 март</Mono>
            <Mono size={10} color={HS.parent.inkMuted}>сегодня · 76%</Mono>
          </div>
        </Card>

        <div style={{ display: 'flex', gap: 10, marginTop: 10 }}>
          <Card style={{ flex: 1 }}>
            <Mono color={HS.parent.inkMuted}>СРЕДНЕЕ ВРЕМЯ</Mono>
            <Display size={22}>7.4′</Display>
            <MiniSpark values={[6,7,5,8,7,9,7,8]} color={HS.brand.sky} h={30}/>
          </Card>
          <Card style={{ flex: 1 }}>
            <Mono color={HS.parent.inkMuted}>ПОПЫТОК / ДЕНЬ</Mono>
            <Display size={22}>34</Display>
            <MiniSpark values={[20,24,28,26,30,32,34,36]} color={HS.brand.mint} h={30}/>
          </Card>
        </div>

        <Card style={{ marginTop: 10 }}>
          <Title size={14}>Ошибки по типам</Title>
          {[
            ['Замена Р → Л', 38, HS.brand.primary],
            ['Пропуск Р', 22, HS.sem.warning],
            ['Горловое Р', 15, HS.sem.error],
            ['Искажение', 10, HS.brand.lilac],
          ].map(([l,v,c]) => (
            <div key={l} style={{ padding: '8px 0', display: 'flex', alignItems: 'center', gap: 10 }}>
              <div style={{ width: 8, height: 8, borderRadius: 4, background: c }}/>
              <Body size={12} style={{ flex: 1 }}>{l}</Body>
              <Bar value={v} color={c} height={4} track={HS.parent.line} style={{ width: 80 }}/>
              <Mono size={10} color={HS.parent.inkMuted} style={{ width: 32, textAlign: 'right' }}>{v}%</Mono>
            </div>
          ))}
        </Card>
      </div>
      <ParentTabBar active="analytics"/>
    </Phone>
  );
}

// 6) Attempt history with audio
function AttemptHistoryScreen() {
  return (
    <Phone bg={HS.parent.bg}>
      <div style={{ padding: '16px 16px 80px' }}>
        <Body size={12} color={HS.parent.inkMuted}>← Аналитика</Body>
        <Title size={22} color={HS.parent.ink}>История попыток</Title>
        <Body size={12} color={HS.parent.inkMuted}>Звук Р · последние 20</Body>

        <div style={{ display: 'flex', gap: 6, marginTop: 10 }}>
          <Chip label="Все" filled color={HS.parent.ink}/>
          <Chip label="✓ Правильно"/>
          <Chip label="◐ Почти"/>
          <Chip label="✕ Ошибки"/>
        </div>

        <div style={{ marginTop: 10 }}>
          {[
            ['21.04 · 18:42', 'рыба', 'ok', 92],
            ['21.04 · 18:40', 'радуга', 'ok', 88],
            ['21.04 · 18:39', 'ромашка', 'near', 64],
            ['21.04 · 10:15', 'ракета', 'ok', 95],
            ['20.04 · 19:20', 'рука', 'miss', 32],
            ['20.04 · 19:18', 'рыцарь', 'near', 58],
          ].map(([t,w,s,v],i) => (
            <Card key={i} style={{ marginBottom: 6, padding: 12 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <div style={{ width: 32, height: 32, borderRadius: 16, background: s==='ok'?HS.sem.success:s==='near'?HS.sem.warning:HS.sem.error, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 14 }}>▶</div>
                <div style={{ flex: 1 }}>
                  <Body size={13} weight={600}>{w}</Body>
                  <Mono size={10} color={HS.parent.inkMuted}>{t}</Mono>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                  {Array.from({length:14}).map((_,j) => (
                    <div key={j} style={{ width: 2, height: `${6 + Math.abs(Math.sin(j+i)*10)}px`, background: s==='ok'?HS.sem.success:s==='near'?HS.sem.warning:HS.sem.error, borderRadius: 1 }}/>
                  ))}
                </div>
                <Mono size={11} color={HS.parent.ink} style={{ fontWeight: 700, marginLeft: 6 }}>{v}%</Mono>
              </div>
            </Card>
          ))}
        </div>
      </div>
      <ParentTabBar active="analytics"/>
    </Phone>
  );
}

// 7) Settings
function ParentSettingsScreen() {
  return (
    <Phone bg={HS.parent.bg}>
      <div style={{ padding: '16px 16px 80px' }}>
        <Title size={22} color={HS.parent.ink}>Настройки</Title>

        <div style={{ marginTop: 14 }}>
          <Mono color={HS.parent.inkMuted} style={{ marginBottom: 6 }}>ЗАНЯТИЯ</Mono>
          <Card pad={0}>
            {[
              ['Длительность сессии','7 минут'],
              ['Сложность','Средняя'],
              ['Экранное время','30 мин / день'],
              ['Только офлайн','Вкл'],
              ['Голос бабочки','Взрослый женский'],
            ].map(([l,v],i) => (
              <div key={l} style={{ padding: '12px 14px', borderBottom: i < 4 ? `1px solid ${HS.parent.line}` : 'none', display: 'flex', justifyContent: 'space-between' }}>
                <Body size={14}>{l}</Body>
                <Body size={13} color={HS.parent.inkMuted}>{v} ›</Body>
              </div>
            ))}
          </Card>
        </div>

        <div style={{ marginTop: 14 }}>
          <Mono color={HS.parent.inkMuted} style={{ marginBottom: 6 }}>ДАННЫЕ И ПРИВАТНОСТЬ</Mono>
          <Card pad={0}>
            {[
              ['Синхронизация iCloud','Вкл'],
              ['Хранить аудио','14 дней'],
              ['Экспорт отчёта','PDF / CSV'],
              ['Удалить все записи',''],
            ].map(([l,v],i) => (
              <div key={l} style={{ padding: '12px 14px', borderBottom: i < 3 ? `1px solid ${HS.parent.line}` : 'none', display: 'flex', justifyContent: 'space-between' }}>
                <Body size={14} color={i===3?HS.sem.error:HS.parent.ink}>{l}</Body>
                <Body size={13} color={HS.parent.inkMuted}>{v} ›</Body>
              </div>
            ))}
          </Card>
        </div>

        <div style={{ marginTop: 14 }}>
          <Mono color={HS.parent.inkMuted} style={{ marginBottom: 6 }}>КОНТЕНТ-ПАКИ</Mono>
          <Card>
            {[
              ['Основной (звуки Р, Ш, С, З, Л)','412 МБ','installed'],
              ['Расширенный (все группы)','1.2 ГБ','available'],
              ['Сказки-аудиотека','380 МБ','installed'],
              ['Голосовая модель RU','220 МБ','installed'],
            ].map(([n,s,st],i) => (
              <div key={n} style={{ padding: '10px 0', borderBottom: i < 3 ? `1px solid ${HS.parent.line}` : 'none', display: 'flex', alignItems: 'center', gap: 10 }}>
                <div style={{ width: 32, height: 32, borderRadius: 8, background: HS.parent.bgDeep, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>📦</div>
                <div style={{ flex: 1 }}>
                  <Body size={13} weight={600}>{n}</Body>
                  <Mono size={10} color={HS.parent.inkMuted}>{s}</Mono>
                </div>
                <Chip label={st==='installed'?'✓ Установлен':'Скачать'} color={st==='installed'?HS.sem.success:HS.parent.accent} filled={st!=='installed'}/>
              </div>
            ))}
          </Card>
        </div>
      </div>
      <ParentTabBar active="settings"/>
    </Phone>
  );
}

// 8) Parental gate
function ParentalGateScreen() {
  return (
    <Phone bg="rgba(10,15,25,0.65)">
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.35)', backdropFilter: 'blur(10px)' }}/>
      <div style={{ position: 'absolute', inset: 20, top: 120, bottom: 120, background: HS.parent.surface, borderRadius: 24, padding: 24, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
        <div style={{ fontSize: 40 }}>🔐</div>
        <Title size={18} color={HS.parent.ink} style={{ marginTop: 10, textAlign: 'center' }}>Только для взрослых</Title>
        <Body size={12} color={HS.parent.inkMuted} style={{ textAlign: 'center', marginTop: 6 }}>Сколько будет семь плюс пять?</Body>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 6, marginTop: 16, width: '100%' }}>
          {['9','12','14','17','11','10'].map((n,i) => (
            <div key={i} style={{ padding: 14, background: i===1?HS.parent.accent:HS.parent.bgDeep, color: i===1?'#fff':HS.parent.ink, borderRadius: 10, textAlign: 'center', fontSize: 17, fontWeight: 700 }}>{n}</div>
          ))}
        </div>
        <div style={{ marginTop: 'auto', color: HS.parent.inkSoft, fontSize: 12 }}>Отмена</div>
      </div>
    </Phone>
  );
}

// 9) Report export
function ReportExportScreen() {
  return (
    <Phone bg={HS.parent.bg}>
      <div style={{ padding: '16px 16px 80px' }}>
        <Title size={22} color={HS.parent.ink}>Отчёт</Title>
        <Body size={12} color={HS.parent.inkMuted}>Для логопеда · апрель 2026</Body>

        <Card style={{ marginTop: 14, padding: 18 }}>
          <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12 }}>
            <div style={{ width: 44, height: 44, borderRadius: 10, background: HS.brand.mint, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22 }}>🦊</div>
            <div style={{ flex: 1 }}>
              <Title size={16}>Миша, 6 лет</Title>
              <Body size={11} color={HS.parent.inkMuted}>Отчёт за 30 дней · 22 сессии</Body>
            </div>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8, marginTop: 14 }}>
            {[['3ч 42м','Всего'],['594','Попыток'],['76%','Точность']].map(([v,l]) => (
              <div key={l} style={{ textAlign: 'center', padding: 10, background: HS.parent.bgDeep, borderRadius: 10 }}>
                <Display size={18}>{v}</Display>
                <Mono size={9} color={HS.parent.inkMuted}>{l}</Mono>
              </div>
            ))}
          </div>
        </Card>

        <Card style={{ marginTop: 10 }}>
          <Mono color={HS.parent.inkMuted}>ВКЛЮЧИТЬ В ОТЧЁТ</Mono>
          <div style={{ marginTop: 8 }}>
            {[
              ['Общий прогресс по звукам', true],
              ['Динамика точности (графики)', true],
              ['Типы ошибок', true],
              ['Образцы аудиозаписей', false],
              ['Рекомендации на следующий месяц', true],
            ].map(([l,on]) => (
              <div key={l} style={{ padding: '8px 0', display: 'flex', alignItems: 'center', gap: 10 }}>
                <div style={{ width: 20, height: 20, borderRadius: 6, border: `1.5px solid ${on?HS.parent.accent:HS.parent.line}`, background: on?HS.parent.accent:'transparent', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 12 }}>{on && '✓'}</div>
                <Body size={13}>{l}</Body>
              </div>
            ))}
          </div>
        </Card>

        <div style={{ display: 'flex', gap: 8, marginTop: 14 }}>
          <div style={{ flex: 1, padding: 12, borderRadius: 12, background: HS.parent.surface, border: `1px solid ${HS.parent.line}`, textAlign: 'center', fontWeight: 600 }}>PDF</div>
          <div style={{ flex: 1, padding: 12, borderRadius: 12, background: HS.parent.surface, border: `1px solid ${HS.parent.line}`, textAlign: 'center', fontWeight: 600 }}>CSV</div>
          <div style={{ flex: 2, padding: 12, borderRadius: 12, background: HS.parent.accent, color: '#fff', textAlign: 'center', fontWeight: 600 }}>Отправить</div>
        </div>
      </div>
    </Phone>
  );
}

// 10) Parent tips library
function TipsScreen() {
  return (
    <Phone bg={HS.parent.bg}>
      <div style={{ padding: '16px 16px 80px' }}>
        <Title size={22} color={HS.parent.ink}>Родителям</Title>
        <Body size={12} color={HS.parent.inkMuted}>Короткие советы от логопедов</Body>
        <div style={{ display: 'flex', gap: 6, marginTop: 12, overflow: 'hidden' }}>
          {['Всё','Игры дома','Звуки','Мотивация','Не дави'].map((c,i) => <Chip key={c} label={c} filled={i===0} color={i===0?HS.parent.ink:HS.parent.accent}/>)}
        </div>
        {[
          ['🎈','Почему важно дышать животом', 'Речевое дыхание — основа чистых звуков…', '2 мин'],
          ['🌱','Как хвалить, не перехваливая', 'Признавайте усилия, а не результат…', '3 мин'],
          ['🐣','5 игр с Р на кухне', 'Используйте обычные предметы…', '4 мин'],
          ['🎭','Когда звук «застрял»', 'Что делать, если прогресс замедлился…', '5 мин'],
        ].map(([e,t,d,m]) => (
          <Card key={t} style={{ marginTop: 10 }}>
            <div style={{ display: 'flex', gap: 12, alignItems: 'flex-start' }}>
              <div style={{ width: 48, height: 48, borderRadius: 10, background: HS.parent.bgDeep, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22 }}>{e}</div>
              <div style={{ flex: 1 }}>
                <Title size={14}>{t}</Title>
                <Body size={11} color={HS.parent.inkMuted} style={{ marginTop: 2 }}>{d}</Body>
                <Mono size={10} color={HS.parent.inkSoft} style={{ marginTop: 4 }}>⏱ {m}</Mono>
              </div>
            </div>
          </Card>
        ))}
      </div>
      <ParentTabBar active="library"/>
    </Phone>
  );
}

Object.assign(window, {
  ParentDashboardScreen, ChildProfileScreen, SoundMapScreen, WeeklyPlanScreen, AnalyticsScreen,
  AttemptHistoryScreen, ParentSettingsScreen, ParentalGateScreen, ReportExportScreen, TipsScreen,
});
