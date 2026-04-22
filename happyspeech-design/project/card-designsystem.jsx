// Design System showcase card (artboard content)
const { HS, Butterfly, Display, Title, Body, Mono, Sparkle } = window;

function DesignSystemCard() {
  return (
    <div style={{ padding: 32, background: HS.kid.bg, width: '100%', height: '100%', overflow: 'hidden',
      fontFamily: HS.font.text, color: HS.kid.ink }}>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 28, height: '100%' }}>

        {/* ── LEFT: brand + colors ── */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
            <Butterfly size={72} mood="happy" sparkles/>
            <div>
              <Mono color={HS.kid.inkMuted}>BRAND / TALISMAN</Mono>
              <Display size={36}>HappySpeech</Display>
              <Body color={HS.kid.inkMuted} size={12}>Ляля the speech-butterfly · warm, magical, trusted</Body>
            </div>
          </div>

          <div>
            <Mono color={HS.kid.inkMuted} style={{ marginBottom: 8 }}>PALETTE / BRAND</Mono>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', gap: 6 }}>
              {[
                ['Primary', HS.brand.primary],
                ['Mint', HS.brand.mint],
                ['Sky', HS.brand.sky],
                ['Lilac', HS.brand.lilac],
                ['Butter', HS.brand.butter],
                ['Rose', HS.brand.rose],
              ].map(([n, c]) => (
                <div key={n}>
                  <div style={{ height: 46, borderRadius: 10, background: c, border: '1px solid rgba(0,0,0,0.05)' }}/>
                  <Mono size={9} color={HS.kid.inkMuted} style={{ marginTop: 4 }}>{n}</Mono>
                </div>
              ))}
            </div>
          </div>

          <div>
            <Mono color={HS.kid.inkMuted} style={{ marginBottom: 8 }}>SOUND FAMILIES / ЗВУКИ</Mono>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 6 }}>
              {Object.entries(HS.soundFamily).map(([k, f]) => (
                <div key={k} style={{ background: f.bg, borderRadius: 12, padding: 10, border: '1px solid rgba(0,0,0,0.04)' }}>
                  <div style={{ width: 24, height: 24, borderRadius: 8, background: f.hue, color: '#fff',
                    display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 14, marginBottom: 6 }}>{f.icon}</div>
                  <div style={{ fontSize: 10, fontWeight: 700, color: HS.kid.ink }}>{f.name}</div>
                  <Mono size={8} color={HS.kid.inkMuted}>С·З·Ц</Mono>
                </div>
              ))}
            </div>
          </div>

          <div>
            <Mono color={HS.kid.inkMuted} style={{ marginBottom: 8 }}>SEMANTIC</Mono>
            <div style={{ display: 'flex', gap: 6 }}>
              {[
                ['Success', HS.sem.success, HS.sem.successBg],
                ['Warning', HS.sem.warning, HS.sem.warningBg],
                ['Error', HS.sem.error, HS.sem.errorBg],
                ['Info', HS.sem.info, HS.sem.infoBg],
              ].map(([n, c, bg]) => (
                <div key={n} style={{ flex: 1, background: bg, borderRadius: 10, padding: 8 }}>
                  <div style={{ width: 10, height: 10, borderRadius: 5, background: c, marginBottom: 4 }}/>
                  <Mono size={9} color={c} style={{ fontWeight: 700 }}>{n}</Mono>
                </div>
              ))}
            </div>
          </div>

          <div>
            <Mono color={HS.kid.inkMuted} style={{ marginBottom: 8 }}>THREE CONTOURS</Mono>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }}>
              {[
                ['Kid', HS.kid.bg, HS.brand.primary, 'тёплый, дружелюбный'],
                ['Parent', HS.parent.bg, HS.parent.accent, 'cпокойный, ясный'],
                ['Specialist', HS.spec.panel, HS.spec.accent, 'точный, data-dense'],
              ].map(([n, bg, acc, desc]) => (
                <div key={n} style={{ background: bg, borderRadius: 12, padding: 10, border: `1px solid ${HS.parent.line}` }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
                    <div style={{ width: 8, height: 8, borderRadius: 4, background: acc }}/>
                    <div style={{ fontSize: 11, fontWeight: 700 }}>{n}</div>
                  </div>
                  <Mono size={9} color={HS.kid.inkMuted} style={{ marginTop: 3 }}>{desc}</Mono>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* ── RIGHT: type + components + motion ── */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
          <div>
            <Mono color={HS.kid.inkMuted} style={{ marginBottom: 8 }}>TYPE / SF PRO ROUNDED + TEXT</Mono>
            <div style={{ background: '#fff', borderRadius: 14, padding: 14 }}>
              <Display size={28}>Привет, друг!</Display>
              <Title size={18} style={{ marginTop: 6 }}>Давай потренируем звук Р</Title>
              <Body size={13} style={{ marginTop: 4 }} color={HS.kid.inkMuted}>Родитель видит прогресс спокойно и ясно.</Body>
              <Mono size={10} style={{ marginTop: 4 }} color={HS.kid.inkMuted}>N=47 · p=0.82 · 12/15</Mono>
            </div>
          </div>

          <div>
            <Mono color={HS.kid.inkMuted} style={{ marginBottom: 8 }}>BUTTONS · CHIPS · CARDS</Mono>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, alignItems: 'center' }}>
              <div style={{ background: HS.brand.primary, color: '#fff', padding: '10px 20px', borderRadius: 18, fontFamily: HS.font.display, fontWeight: 700, fontSize: 14, boxShadow: '0 3px 0 oklch(0.55 0.19 30)' }}>Поехали!</div>
              <div style={{ background: '#fff', color: HS.kid.ink, padding: '10px 18px', borderRadius: 18, fontFamily: HS.font.display, fontWeight: 700, fontSize: 14, border: `2px solid ${HS.kid.line}` }}>Позже</div>
              <div style={{ background: HS.parent.accent, color: '#fff', padding: '8px 16px', borderRadius: 10, fontWeight: 600, fontSize: 13 }}>Сохранить</div>
              <div style={{ background: HS.brand.mint, color: '#fff', width: 40, height: 40, borderRadius: 20, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>✓</div>
              <div style={{ padding: '4px 10px', borderRadius: 99, background: HS.sem.successBg, color: HS.sem.success, fontSize: 11, fontWeight: 600 }}>+12 звёзд</div>
              <div style={{ padding: '4px 10px', borderRadius: 99, background: HS.sem.infoBg, color: HS.sem.info, fontSize: 11, fontWeight: 600 }}>Шипящие</div>
            </div>
          </div>

          <div>
            <Mono color={HS.kid.inkMuted} style={{ marginBottom: 8 }}>RADII · SHADOWS · SPACING</Mono>
            <div style={{ display: 'flex', gap: 8, alignItems: 'flex-end' }}>
              {[8,12,18,24,32].map(r => (
                <div key={r} style={{ flex: 1, textAlign: 'center' }}>
                  <div style={{ height: 40, background: '#fff', borderRadius: r, boxShadow: HS.kid.shadow }}/>
                  <Mono size={9} color={HS.kid.inkMuted}>{r}</Mono>
                </div>
              ))}
            </div>
          </div>

          <div>
            <Mono color={HS.kid.inkMuted} style={{ marginBottom: 8 }}>MICROCOPY · TONE</Mono>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 6 }}>
              {[
                ['Kid','«Попробуем ещё раз — у тебя почти получилось!»', HS.brand.primary],
                ['Parent','«На этой неделе звук Р звучит уверенней.»', HS.parent.accent],
                ['Specialist','«Target /r/: accuracy 74% · n=58.»', HS.spec.accent],
              ].map(([n, t, c]) => (
                <div key={n} style={{ background: '#fff', borderRadius: 10, padding: 10, border: `1px solid ${HS.parent.line}` }}>
                  <div style={{ fontSize: 10, fontWeight: 700, color: c, marginBottom: 3 }}>{n}</div>
                  <Body size={11} color={HS.kid.ink}>{t}</Body>
                </div>
              ))}
            </div>
          </div>

          <div>
            <Mono color={HS.kid.inkMuted} style={{ marginBottom: 8 }}>MOTION · 220–420ms spring</Mono>
            <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
              <Sparkle size={14}/><Body size={11}>tap bounce · wing flap 1.6s · confetti on success · gentle shake on mistake · mascot idle</Body>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

window.DesignSystemCard = DesignSystemCard;
