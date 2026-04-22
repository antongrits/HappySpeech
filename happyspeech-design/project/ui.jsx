// UI primitives shared across HappySpeech screens.
// Pure function components, no deps beyond HS tokens + mascot.

const { HS } = window;

// Phone frame — simplified, no nav bar. We need MANY of these so keep it lean.
function Phone({ width = 300, height = 620, bg = '#F6F1EA', dark = false, children, style = {} }) {
  return (
    <div style={{
      width, height, borderRadius: 44, overflow: 'hidden', position: 'relative',
      background: bg, boxShadow: '0 0 0 1px rgba(0,0,0,0.10), 0 24px 48px rgba(30,20,10,0.12)',
      fontFamily: HS.font.text, WebkitFontSmoothing: 'antialiased', ...style,
    }}>
      {/* Dynamic island */}
      <div style={{
        position: 'absolute', top: 10, left: '50%', transform: 'translateX(-50%)',
        width: 92, height: 27, borderRadius: 18, background: '#000', zIndex: 50,
      }}/>
      {/* Status bar */}
      <StatusBar dark={dark}/>
      {/* Content */}
      <div style={{ position: 'absolute', top: 44, bottom: 0, left: 0, right: 0, overflow: 'hidden' }}>
        {children}
      </div>
      {/* Home indicator */}
      <div style={{
        position: 'absolute', bottom: 6, left: '50%', transform: 'translateX(-50%)',
        width: 100, height: 4, borderRadius: 10,
        background: dark ? 'rgba(255,255,255,0.7)' : 'rgba(0,0,0,0.25)', zIndex: 60,
      }}/>
    </div>
  );
}

function StatusBar({ dark = false }) {
  const c = dark ? '#fff' : '#1a1208';
  return (
    <div style={{
      position: 'absolute', top: 0, left: 0, right: 0, height: 44,
      display: 'flex', justifyContent: 'space-between', alignItems: 'center',
      padding: '0 24px', zIndex: 10, pointerEvents: 'none',
    }}>
      <div style={{ fontSize: 14, fontWeight: 600, color: c, fontFamily: HS.font.display }}>9:41</div>
      <div style={{ display: 'flex', gap: 5, alignItems: 'center' }}>
        <svg width="15" height="10" viewBox="0 0 15 10"><rect x="0" y="6" width="2.5" height="4" rx="0.5" fill={c}/><rect x="3.5" y="4" width="2.5" height="6" rx="0.5" fill={c}/><rect x="7" y="2" width="2.5" height="8" rx="0.5" fill={c}/><rect x="10.5" y="0" width="2.5" height="10" rx="0.5" fill={c}/></svg>
        <svg width="22" height="11" viewBox="0 0 22 11"><rect x="0.5" y="0.5" width="18" height="10" rx="2.5" stroke={c} strokeOpacity="0.4" fill="none"/><rect x="2" y="2" width="15" height="7" rx="1.5" fill={c}/></svg>
      </div>
    </div>
  );
}

// ─── Typography ───
function Display({ children, color, size = 34, style }) {
  return <div style={{ fontFamily: HS.font.display, fontSize: size, fontWeight: 800, letterSpacing: -0.8, lineHeight: 1.05, color, ...style }}>{children}</div>;
}
function Title({ children, color, size = 22, weight = 700, style }) {
  return <div style={{ fontFamily: HS.font.display, fontSize: size, fontWeight: weight, letterSpacing: -0.4, lineHeight: 1.15, color, ...style }}>{children}</div>;
}
function Body({ children, color, size = 14, weight = 400, style }) {
  return <div style={{ fontFamily: HS.font.text, fontSize: size, fontWeight: weight, lineHeight: 1.4, color, ...style }}>{children}</div>;
}
function Mono({ children, color, size = 11, style }) {
  return <div style={{ fontFamily: HS.font.mono, fontSize: size, color, letterSpacing: 0.2, ...style }}>{children}</div>;
}

// ─── Kid buttons ───
function KidCTA({ label, sub, icon, color = HS.brand.primary, dark, onClick, style }) {
  return (
    <div onClick={onClick} style={{
      background: color, borderRadius: 22, padding: '14px 22px',
      boxShadow: `0 4px 0 ${dark || 'oklch(0.55 0.19 30)'}, 0 10px 20px rgba(200,80,40,0.20)`,
      display: 'flex', alignItems: 'center', gap: 12,
      color: '#fff', fontFamily: HS.font.display, fontWeight: 700, fontSize: 18,
      cursor: 'pointer', ...style,
    }}>
      {icon}
      <div>
        <div>{label}</div>
        {sub && <div style={{ fontSize: 12, fontWeight: 500, opacity: 0.85 }}>{sub}</div>}
      </div>
    </div>
  );
}

function KidTile({ color = HS.brand.primary, icon, label, sub, locked, progress, onClick, style }) {
  return (
    <div onClick={onClick} style={{
      background: '#fff', borderRadius: 20, padding: 14, position: 'relative', overflow: 'hidden',
      boxShadow: HS.kid.shadow, cursor: 'pointer', ...style,
    }}>
      <div style={{ width: 44, height: 44, borderRadius: 14, background: color,
        display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22, color: '#fff', marginBottom: 10 }}>
        {icon}
      </div>
      <Title color={HS.kid.ink} size={15}>{label}</Title>
      {sub && <Body color={HS.kid.inkMuted} size={12} style={{ marginTop: 2 }}>{sub}</Body>}
      {progress !== undefined && (
        <div style={{ height: 5, background: HS.kid.line, borderRadius: 3, marginTop: 10, overflow: 'hidden' }}>
          <div style={{ height: '100%', width: `${progress}%`, background: color, borderRadius: 3 }}/>
        </div>
      )}
      {locked && (
        <div style={{ position: 'absolute', inset: 0, background: 'rgba(255,255,255,0.72)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22, backdropFilter: 'blur(2px)' }}>🔒</div>
      )}
    </div>
  );
}

// ─── Parent surfaces ───
function Card({ children, pad = 16, style }) {
  return <div style={{ background: HS.parent.surface, borderRadius: 14, padding: pad, border: `1px solid ${HS.parent.line}`, boxShadow: HS.parent.shadow, ...style }}>{children}</div>;
}

function Chip({ label, color = HS.parent.accent, filled, style }) {
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 4, padding: '4px 10px',
      borderRadius: 999, fontSize: 11, fontWeight: 600,
      background: filled ? color : `color-mix(in oklch, ${color} 14%, white)`,
      color: filled ? '#fff' : color, letterSpacing: 0.1, ...style,
    }}>{label}</div>
  );
}

// ─── Progress indicators ───
function Ring({ size = 48, stroke = 5, value = 0, color = HS.brand.primary, track = HS.kid.line, children }) {
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  return (
    <div style={{ width: size, height: size, position: 'relative', display: 'inline-block' }}>
      <svg width={size} height={size} style={{ transform: 'rotate(-90deg)' }}>
        <circle cx={size/2} cy={size/2} r={r} stroke={track} strokeWidth={stroke} fill="none"/>
        <circle cx={size/2} cy={size/2} r={r} stroke={color} strokeWidth={stroke} fill="none"
          strokeDasharray={c} strokeDashoffset={c * (1 - value/100)} strokeLinecap="round"/>
      </svg>
      {children && <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{children}</div>}
    </div>
  );
}

function Bar({ value = 0, color = HS.brand.primary, height = 8, track = HS.kid.line, style }) {
  return (
    <div style={{ height, background: track, borderRadius: height/2, overflow: 'hidden', ...style }}>
      <div style={{ height: '100%', width: `${value}%`, background: color, borderRadius: height/2, transition: 'width .4s' }}/>
    </div>
  );
}

// Placeholder image — subtle stripe with label (for pictures)
function Placeholder({ label = 'image', w = '100%', h = 120, r = 12, style }) {
  return (
    <div style={{
      width: w, height: h, borderRadius: r,
      background: `repeating-linear-gradient(135deg, oklch(0.95 0.02 70), oklch(0.95 0.02 70) 6px, oklch(0.92 0.03 70) 6px, oklch(0.92 0.03 70) 12px)`,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontFamily: HS.font.mono, fontSize: 10, color: HS.kid.inkSoft,
      border: '1px dashed oklch(0.82 0.02 70)', ...style,
    }}>{label}</div>
  );
}

// Illustrated picture — a colorful round disk with emoji-free SVG content
function Pict({ color = HS.brand.mint, size = 100, glyph, bg }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: size * 0.28,
      background: bg || `color-mix(in oklch, ${color} 18%, white)`,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontSize: size * 0.5, color,
      boxShadow: 'inset 0 0 0 2px rgba(255,255,255,0.6)',
    }}>
      <span style={{ fontFamily: HS.font.display, fontWeight: 800, letterSpacing: -1 }}>{glyph}</span>
    </div>
  );
}

// Tab bar (kid) — big friendly pills
function KidTabBar({ active = 'home' }) {
  const tabs = [
    { id: 'home',   label: 'Дом',     icon: '🏠' },
    { id: 'map',    label: 'Карта',   icon: '🗺️' },
    { id: 'ar',     label: 'Зеркало', icon: '✨' },
    { id: 'rewards',label: 'Награды', icon: '🏆' },
  ];
  return (
    <div style={{
      position: 'absolute', left: 12, right: 12, bottom: 12,
      background: '#fff', borderRadius: 28, padding: 8,
      display: 'flex', justifyContent: 'space-between',
      boxShadow: '0 4px 0 rgba(60,40,20,0.05), 0 12px 28px rgba(60,40,20,0.10)',
    }}>
      {tabs.map(t => (
        <div key={t.id} style={{
          flex: 1, padding: '8px 4px', borderRadius: 20, textAlign: 'center',
          background: active === t.id ? HS.brand.primary : 'transparent',
          color: active === t.id ? '#fff' : HS.kid.inkMuted,
          fontFamily: HS.font.display, fontSize: 11, fontWeight: 700,
        }}>
          <div style={{ fontSize: 20, lineHeight: 1, marginBottom: 2 }}>{t.icon}</div>
          {t.label}
        </div>
      ))}
    </div>
  );
}

// Tab bar (parent) — minimal system style
function ParentTabBar({ active = 'overview' }) {
  const tabs = [
    { id: 'overview', label: 'Обзор' },
    { id: 'plan',     label: 'План' },
    { id: 'analytics',label: 'Аналитика' },
    { id: 'library',  label: 'Библиотека' },
    { id: 'settings', label: 'Настройки' },
  ];
  return (
    <div style={{
      position: 'absolute', left: 0, right: 0, bottom: 0, height: 64,
      background: 'rgba(255,255,255,0.94)', backdropFilter: 'blur(20px)',
      borderTop: `1px solid ${HS.parent.line}`,
      display: 'flex', paddingBottom: 14,
    }}>
      {tabs.map(t => (
        <div key={t.id} style={{
          flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
          color: active === t.id ? HS.parent.accent : HS.parent.inkSoft,
          fontSize: 10, fontWeight: 600,
        }}>
          <div style={{ width: 20, height: 20, borderRadius: 5, background: 'currentColor', opacity: active === t.id ? 1 : 0.4, marginBottom: 3 }}/>
          {t.label}
        </div>
      ))}
    </div>
  );
}

// Speech bubble for mascot
function Speech({ children, tail = 'left', color = '#fff', textColor = HS.kid.ink, style }) {
  return (
    <div style={{
      background: color, color: textColor, padding: '10px 14px', borderRadius: 18,
      fontFamily: HS.font.display, fontWeight: 600, fontSize: 13,
      boxShadow: HS.kid.shadow, position: 'relative', display: 'inline-block', ...style,
    }}>
      {children}
      <svg width="14" height="12" style={{ position: 'absolute', bottom: -8, [tail]: 18 }} viewBox="0 0 14 12">
        <path d="M0 0 L14 0 L7 12 Z" fill={color}/>
      </svg>
    </div>
  );
}

Object.assign(window, {
  Phone, StatusBar, Display, Title, Body, Mono,
  KidCTA, KidTile, Card, Chip, Ring, Bar, Placeholder, Pict,
  KidTabBar, ParentTabBar, Speech,
});
