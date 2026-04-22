// HappySpeech scene library — 3D-ish SVG scenes (no hippos, our own language).
// All scenes follow the same visual rules:
//   • soft radial-gradient base for pseudo-3D volume
//   • warm drop shadows at the base
//   • highlight glare at 30% 25%
//   • 1-2 accent sparkles
//   • bright pastel palette matching HS tokens
// They are framed as round-corner stages so they drop cleanly into cards.

const { HS, Butterfly, Star, Sparkle } = window;

// Inject scene-level keyframes once
(function injectSceneStyles(){
  if (document.getElementById('hs-scene-styles')) return;
  const s = document.createElement('style');
  s.id = 'hs-scene-styles';
  s.textContent = `
    @keyframes hsOrbit    { 0%{transform:translate(0,0)} 50%{transform:translate(3px,-4px)} 100%{transform:translate(0,0)} }
    @keyframes hsWiggle   { 0%,100%{transform:rotate(-3deg)} 50%{transform:rotate(3deg)} }
    @keyframes hsRise     { 0%{transform:translateY(0)} 50%{transform:translateY(-6px)} 100%{transform:translateY(0)} }
    @keyframes hsBurst    { 0%{transform:scale(.8); opacity:0} 40%{transform:scale(1.15); opacity:1} 100%{transform:scale(1); opacity:1} }
    @keyframes hsPop      { 0%{transform:scale(0)} 60%{transform:scale(1.2)} 100%{transform:scale(1)} }
    @keyframes hsSpin     { 0%{transform:rotate(0)} 100%{transform:rotate(360deg)} }
    @keyframes hsGlow     { 0%,100%{filter:drop-shadow(0 0 8px rgba(255,200,100,.4))} 50%{filter:drop-shadow(0 0 18px rgba(255,200,100,.8))} }
    @keyframes hsFlicker  { 0%,100%{transform:scale(1) translateY(0)} 25%{transform:scale(1.08,.94) translateY(-2px)} 75%{transform:scale(.94,1.06) translateY(1px)} }
    @keyframes hsFloat    { 0%,100%{transform:translateY(0)} 50%{transform:translateY(-10px)} }
    @keyframes hsPulse    { 0%,100%{transform:scale(1); opacity:.6} 50%{transform:scale(1.4); opacity:0} }
    .hs-orbit   { animation: hsOrbit 3.4s ease-in-out infinite; }
    .hs-wiggle  { animation: hsWiggle 2.8s ease-in-out infinite; transform-origin: 50% 80%; }
    .hs-rise    { animation: hsRise 3.2s ease-in-out infinite; }
    .hs-burst   { animation: hsBurst 1.6s ease-out infinite; }
    .hs-pop     { animation: hsPop 1.4s cubic-bezier(.68,-.55,.27,1.55) infinite; }
    .hs-spin    { animation: hsSpin 12s linear infinite; }
    .hs-glow    { animation: hsGlow 2s ease-in-out infinite; }
    .hs-flicker { animation: hsFlicker 0.6s ease-in-out infinite; transform-origin: 50% 100%; }
    .hs-float   { animation: hsFloat 4s ease-in-out infinite; }
    .hs-pulse   { animation: hsPulse 2.2s ease-out infinite; }
  `;
  document.head.appendChild(s);
})();

// ─── BASE PRIMITIVES ──────────────────────────────────────────
// A pseudo-3D sphere with highlight + rim shading
function Sphere({ cx, cy, r, color, stroke, hi = 0.6, style }) {
  const id = `sph-${cx}-${cy}-${r}-${color}`.replace(/[^\w]/g,'');
  return (
    <g style={style}>
      <defs>
        <radialGradient id={id} cx="35%" cy="30%" r="70%">
          <stop offset="0%" stopColor="#fff" stopOpacity={hi}/>
          <stop offset="45%" stopColor={color} stopOpacity="1"/>
          <stop offset="100%" stopColor={color} stopOpacity="1"/>
        </radialGradient>
      </defs>
      <circle cx={cx} cy={cy} r={r} fill={color}/>
      <circle cx={cx} cy={cy} r={r} fill={`url(#${id})`}/>
      {stroke && <circle cx={cx} cy={cy} r={r} fill="none" stroke={stroke} strokeWidth="1.2" opacity="0.4"/>}
      {/* specular glare */}
      <ellipse cx={cx - r*0.28} cy={cy - r*0.32} rx={r*0.26} ry={r*0.16} fill="#fff" opacity="0.55"/>
    </g>
  );
}

// A pseudo-3D rounded slab (trophy base, books, stages)
function Slab({ x, y, w, h, r = 8, color, depth = 6, tiltDark = 'rgba(0,0,0,0.18)' }) {
  return (
    <g>
      {/* side/depth */}
      <path d={`M${x+r} ${y+h} L${x+w-r} ${y+h} Q${x+w} ${y+h} ${x+w} ${y+h-r} L${x+w} ${y+h-r+depth} Q${x+w} ${y+h+depth} ${x+w-r} ${y+h+depth} L${x+r} ${y+h+depth} Q${x} ${y+h+depth} ${x} ${y+h-r+depth} L${x} ${y+h-r} Q${x} ${y+h} ${x+r} ${y+h}`} fill={tiltDark}/>
      <rect x={x} y={y} width={w} height={h} rx={r} fill={color}/>
      <rect x={x} y={y} width={w} height={h*0.4} rx={r} fill="#fff" opacity="0.22"/>
    </g>
  );
}

// Rays background — the signature "starburst" look
function RaysBg({ hue = 'oklch(0.90 0.08 200)', hue2 = 'oklch(0.96 0.04 200)', opacity = 0.5 }) {
  const rays = Array.from({length: 24}, (_, i) => i * 15);
  return (
    <div style={{ position: 'absolute', inset: 0, overflow: 'hidden' }}>
      <div style={{ position: 'absolute', inset: 0, background: `radial-gradient(circle at 50% 60%, ${hue2}, ${hue})` }}/>
      <svg viewBox="-100 -100 200 200" preserveAspectRatio="xMidYMid slice" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', opacity }}>
        {rays.map(a => (
          <polygon key={a} transform={`rotate(${a})`} points="-4,-200 4,-200 0,0" fill="#fff" opacity={a % 30 === 0 ? 0.6 : 0.3}/>
        ))}
      </svg>
    </div>
  );
}

// ─── ILLUSTRATED OBJECTS ──────────────────────────────────────

// Trophy — coral/gold cup on a rounded podium
function Trophy({ size = 120, style }) {
  return (
    <svg viewBox="0 0 120 140" width={size} height={size * 140/120} style={style}>
      <defs>
        <radialGradient id="tr-gold" cx="35%" cy="25%" r="80%">
          <stop offset="0%" stopColor="oklch(0.95 0.14 85)"/>
          <stop offset="55%" stopColor="oklch(0.80 0.16 75)"/>
          <stop offset="100%" stopColor="oklch(0.60 0.16 60)"/>
        </radialGradient>
      </defs>
      {/* shadow */}
      <ellipse cx="60" cy="132" rx="38" ry="5" fill="rgba(58,40,28,0.25)"/>
      {/* podium */}
      <Slab x={28} y={118} w={64} h={14} r={4} color="oklch(0.78 0.14 20)" depth={4} tiltDark="oklch(0.55 0.16 20)"/>
      {/* stem */}
      <rect x="52" y="92" width="16" height="28" rx="4" fill="url(#tr-gold)"/>
      {/* cup */}
      <path d="M28 42 Q28 82 60 94 Q92 82 92 42 Z" fill="url(#tr-gold)" stroke="oklch(0.55 0.16 60)" strokeWidth="1.5"/>
      {/* rim */}
      <ellipse cx="60" cy="42" rx="32" ry="7" fill="oklch(0.90 0.15 80)" stroke="oklch(0.55 0.16 60)" strokeWidth="1.5"/>
      <ellipse cx="60" cy="42" rx="32" ry="7" fill="none" stroke="#fff" strokeWidth="1" opacity="0.6"/>
      {/* handles */}
      <path d="M28 52 Q10 56 14 74 Q18 88 34 82" fill="none" stroke="oklch(0.75 0.16 70)" strokeWidth="7" strokeLinecap="round"/>
      <path d="M92 52 Q110 56 106 74 Q102 88 86 82" fill="none" stroke="oklch(0.75 0.16 70)" strokeWidth="7" strokeLinecap="round"/>
      {/* star */}
      <g transform="translate(60 62)">
        <path d="M0 -12 L3.5 -3.5 L12 0 L3.5 3.5 L0 12 L-3.5 3.5 L-12 0 L-3.5 -3.5 Z" fill="#fff"/>
      </g>
      {/* glare */}
      <ellipse cx="46" cy="56" rx="8" ry="16" fill="#fff" opacity="0.5" transform="rotate(-18 46 56)"/>
    </svg>
  );
}

// Rocket — for premium paywall
function Rocket({ size = 120, style, flame = true }) {
  return (
    <svg viewBox="0 0 120 160" width={size} height={size * 160/120} style={style}>
      <defs>
        <linearGradient id="rk-body" x1="0" x2="1">
          <stop offset="0%" stopColor="#fff"/>
          <stop offset="50%" stopColor="oklch(0.96 0.02 280)"/>
          <stop offset="100%" stopColor="oklch(0.80 0.04 280)"/>
        </linearGradient>
        <linearGradient id="rk-fin" x1="0" x2="1">
          <stop offset="0%" stopColor="oklch(0.78 0.16 30)"/>
          <stop offset="100%" stopColor="oklch(0.58 0.19 28)"/>
        </linearGradient>
      </defs>
      {/* flame */}
      {flame && (
        <g className="hs-flicker">
          <path d="M48 130 Q60 160 72 130 Q68 124 60 126 Q52 124 48 130 Z" fill="oklch(0.85 0.19 55)"/>
          <path d="M52 130 Q60 150 68 130 Q64 126 60 128 Q56 126 52 130 Z" fill="oklch(0.92 0.17 85)"/>
          <path d="M56 130 Q60 144 64 130 Z" fill="#fff"/>
        </g>
      )}
      {/* fins */}
      <path d="M34 100 L46 110 L46 130 Z" fill="url(#rk-fin)"/>
      <path d="M86 100 L74 110 L74 130 Z" fill="url(#rk-fin)"/>
      {/* body */}
      <path d="M60 12 Q86 40 86 110 L34 110 Q34 40 60 12 Z" fill="url(#rk-body)" stroke="oklch(0.70 0.04 280)" strokeWidth="1.2"/>
      {/* window */}
      <circle cx="60" cy="62" r="14" fill="oklch(0.88 0.12 240)"/>
      <circle cx="60" cy="62" r="14" fill="none" stroke="oklch(0.55 0.14 250)" strokeWidth="2.5"/>
      <path d="M50 60 Q60 50 70 60" stroke="#fff" strokeWidth="2" fill="none" opacity="0.7"/>
      {/* stripe */}
      <rect x="34" y="96" width="52" height="6" fill="oklch(0.78 0.16 30)"/>
      {/* glare */}
      <path d="M46 24 Q42 60 44 100" stroke="#fff" strokeWidth="3" fill="none" opacity="0.5" strokeLinecap="round"/>
    </svg>
  );
}

// Gift — 3D box
function Gift({ size = 80, color = 'oklch(0.78 0.16 30)', ribbon = 'oklch(0.82 0.13 85)', style }) {
  return (
    <svg viewBox="0 0 100 100" width={size} height={size} style={style}>
      <defs>
        <linearGradient id={`g-${color}`.replace(/[^\w]/g,'')} x1="0" x2="1">
          <stop offset="0%" stopColor={color}/>
          <stop offset="100%" stopColor="oklch(0.60 0.18 30)"/>
        </linearGradient>
      </defs>
      <ellipse cx="50" cy="92" rx="30" ry="4" fill="rgba(0,0,0,0.2)"/>
      {/* box */}
      <rect x="16" y="38" width="68" height="52" rx="6" fill={`url(#g-${color}`.replace(/[^\w]/g,'')+')'}/>
      <rect x="16" y="38" width="68" height="16" rx="6" fill="#fff" opacity="0.25"/>
      {/* lid */}
      <rect x="12" y="30" width="76" height="16" rx="4" fill={color}/>
      <rect x="12" y="30" width="76" height="6" rx="2" fill="#fff" opacity="0.3"/>
      {/* ribbon vertical */}
      <rect x="44" y="30" width="12" height="60" fill={ribbon}/>
      <rect x="44" y="30" width="12" height="60" fill="url(#g-ribbon)" opacity="0.3"/>
      {/* bow */}
      <ellipse cx="40" cy="28" rx="12" ry="8" fill={ribbon}/>
      <ellipse cx="60" cy="28" rx="12" ry="8" fill={ribbon}/>
      <circle cx="50" cy="28" r="5" fill={color}/>
    </svg>
  );
}

// Book stack — for learn cards
function BookStack({ size = 120, style }) {
  return (
    <svg viewBox="0 0 140 100" width={size} height={size * 100/140} style={style}>
      <ellipse cx="70" cy="92" rx="50" ry="4" fill="rgba(0,0,0,0.2)"/>
      {/* bottom */}
      <Slab x={14} y={66} w={112} h={20} r={4} color="oklch(0.72 0.13 30)" depth={5} tiltDark="oklch(0.50 0.15 28)"/>
      {/* middle */}
      <Slab x={24} y={46} w={92} h={20} r={4} color="oklch(0.78 0.14 90)" depth={5} tiltDark="oklch(0.58 0.16 80)"/>
      {/* top */}
      <Slab x={36} y={26} w={68} h={20} r={4} color="oklch(0.76 0.13 200)" depth={5} tiltDark="oklch(0.55 0.15 210)"/>
      {/* letter on top */}
      <text x="70" y="42" fill="#fff" fontSize="16" fontWeight="900" textAnchor="middle" fontFamily="system-ui">A</text>
      {/* spine dots */}
      {[28, 50, 72, 94].map(x => <circle key={x} cx={x} cy={76} r="1.4" fill="#fff" opacity="0.6"/>)}
    </svg>
  );
}

// Easel with letters (learn-to-speak)
function Easel({ size = 120, style, letter1 = 'Р', letter2 = 'А' }) {
  return (
    <svg viewBox="0 0 140 140" width={size} height={size} style={style}>
      <ellipse cx="70" cy="130" rx="52" ry="5" fill="rgba(0,0,0,0.2)"/>
      {/* legs */}
      <path d="M36 40 L22 126" stroke="oklch(0.55 0.08 40)" strokeWidth="5" strokeLinecap="round"/>
      <path d="M104 40 L118 126" stroke="oklch(0.55 0.08 40)" strokeWidth="5" strokeLinecap="round"/>
      <path d="M70 40 L70 130" stroke="oklch(0.50 0.10 40)" strokeWidth="3"/>
      {/* board */}
      <rect x="24" y="20" width="92" height="68" rx="6" fill="oklch(0.82 0.14 160)"/>
      <rect x="24" y="20" width="92" height="68" rx="6" fill="url(#easel-shade)" opacity="0.15"/>
      <rect x="24" y="20" width="92" height="68" rx="6" fill="none" stroke="oklch(0.55 0.12 160)" strokeWidth="2"/>
      {/* letters */}
      <text x="50" y="56" fontSize="26" fontWeight="900" fill="oklch(0.62 0.20 25)" fontFamily="Nunito,system-ui">{letter1}</text>
      <text x="82" y="58" fontSize="30" fontWeight="900" fill="oklch(0.65 0.18 280)" fontFamily="Nunito,system-ui">{letter2}</text>
      <text x="60" y="80" fontSize="22" fontWeight="900" fill="oklch(0.68 0.16 85)" fontFamily="Nunito,system-ui">О</text>
      {/* tray */}
      <rect x="18" y="84" width="104" height="10" rx="3" fill="oklch(0.55 0.10 40)"/>
    </svg>
  );
}

// Stage / podium with curtains
function Stage({ size = 120, style }) {
  return (
    <svg viewBox="0 0 140 100" width={size} height={size * 100/140} style={style}>
      <ellipse cx="70" cy="90" rx="58" ry="5" fill="rgba(0,0,0,0.18)"/>
      <ellipse cx="70" cy="76" rx="56" ry="12" fill="oklch(0.65 0.16 15)"/>
      <ellipse cx="70" cy="74" rx="56" ry="12" fill="oklch(0.78 0.14 15)"/>
      <ellipse cx="70" cy="72" rx="52" ry="10" fill="oklch(0.86 0.10 15)"/>
      <ellipse cx="70" cy="72" rx="52" ry="10" fill="none" stroke="#fff" strokeWidth="1" opacity="0.6"/>
    </svg>
  );
}

// Island — rocky outcrop, for map nodes
function Island({ size = 160, style, variant = 'grass' }) {
  const grass = variant === 'grass';
  return (
    <svg viewBox="0 0 160 110" width={size} height={size * 110/160} style={style}>
      {/* water shadow */}
      <ellipse cx="80" cy="94" rx="68" ry="12" fill="rgba(40,80,140,0.25)"/>
      {/* rock base */}
      <path d="M20 72 Q14 88 30 96 L130 96 Q146 88 140 72 Q140 58 120 56 Q120 44 100 46 Q92 36 76 42 Q64 38 52 50 Q34 48 30 62 Q18 62 20 72 Z"
        fill={grass ? 'oklch(0.64 0.09 60)' : 'oklch(0.70 0.05 40)'}/>
      {/* top grass */}
      {grass && <path d="M22 72 Q14 58 34 54 Q50 40 70 46 Q90 36 108 46 Q128 44 138 62 Q140 68 132 72 Q110 66 88 70 Q64 62 42 72 Q30 66 22 72 Z"
        fill="oklch(0.78 0.14 140)"/>}
      {grass && <path d="M30 68 Q46 60 62 64 Q82 56 100 62 Q118 58 132 64" fill="none" stroke="oklch(0.58 0.16 140)" strokeWidth="1.2" opacity="0.5"/>}
      {/* rim highlight */}
      <path d="M22 76 Q80 72 138 76" fill="none" stroke="#fff" strokeWidth="1.5" opacity="0.4"/>
    </svg>
  );
}

// Cloud 3D-ish
function Cloud3D({ size = 80, style, opacity = 1 }) {
  return (
    <svg viewBox="0 0 100 60" width={size} height={size * 60/100} style={{ ...style, opacity }}>
      <defs>
        <radialGradient id="cl-sh" cx="50%" cy="30%" r="70%">
          <stop offset="0%" stopColor="#fff"/>
          <stop offset="100%" stopColor="oklch(0.88 0.04 220)"/>
        </radialGradient>
      </defs>
      <path d="M16 42 Q6 42 10 30 Q14 20 26 22 Q32 10 48 14 Q58 4 70 14 Q86 12 88 28 Q96 28 94 40 Q92 50 80 50 L22 50 Q10 50 16 42 Z" fill="url(#cl-sh)"/>
    </svg>
  );
}

// Flower — decorative
function Flower({ size = 30, color = 'oklch(0.80 0.16 15)', style }) {
  return (
    <svg viewBox="-30 -30 60 60" width={size} height={size} style={style}>
      {[0, 72, 144, 216, 288].map(a => (
        <ellipse key={a} cx="0" cy="-12" rx="6" ry="10" fill={color} transform={`rotate(${a})`}/>
      ))}
      <circle r="5" fill="oklch(0.85 0.15 85)"/>
    </svg>
  );
}

// Heart — for rewards
function Heart3D({ size = 40, color = 'oklch(0.72 0.18 20)', style }) {
  return (
    <svg viewBox="0 0 40 40" width={size} height={size} style={style}>
      <defs>
        <radialGradient id={`h-${color}`.replace(/[^\w]/g,'')} cx="30%" cy="25%" r="75%">
          <stop offset="0%" stopColor="#fff" stopOpacity="0.7"/>
          <stop offset="40%" stopColor={color} stopOpacity="1"/>
          <stop offset="100%" stopColor={color}/>
        </radialGradient>
      </defs>
      <path d="M20 36 C 8 26, 2 18, 6 10 C 10 2, 18 4, 20 10 C 22 4, 30 2, 34 10 C 38 18, 32 26, 20 36 Z" fill={`url(#h-${color}`.replace(/[^\w]/g,'') + ')'}/>
    </svg>
  );
}

// Flame — for streak
function Flame({ size = 100, style, animate = true }) {
  return (
    <svg viewBox="0 0 100 140" width={size} height={size * 140/100} style={style}>
      <defs>
        <radialGradient id="fl-outer" cx="50%" cy="80%" r="60%">
          <stop offset="0%" stopColor="oklch(0.92 0.17 50)"/>
          <stop offset="70%" stopColor="oklch(0.75 0.20 30)"/>
          <stop offset="100%" stopColor="oklch(0.55 0.22 28)"/>
        </radialGradient>
        <radialGradient id="fl-inner" cx="50%" cy="70%" r="55%">
          <stop offset="0%" stopColor="#fff"/>
          <stop offset="60%" stopColor="oklch(0.92 0.17 85)"/>
          <stop offset="100%" stopColor="oklch(0.80 0.19 50)"/>
        </radialGradient>
      </defs>
      <ellipse cx="50" cy="130" rx="36" ry="4" fill="rgba(200,80,40,0.3)"/>
      <g className={animate ? 'hs-flicker' : ''}>
        <path d="M50 8 C 70 32 86 50 86 80 C 86 106 70 124 50 124 C 30 124 14 106 14 80 C 14 50 30 32 50 8 Z" fill="url(#fl-outer)"/>
        <path d="M50 28 C 62 44 72 58 72 78 C 72 98 62 112 50 112 C 38 112 28 98 28 78 C 28 58 38 44 50 28 Z" fill="url(#fl-inner)"/>
        {/* face */}
        <ellipse cx="42" cy="80" rx="3" ry="4" fill="oklch(0.28 0.10 30)"/>
        <ellipse cx="58" cy="80" rx="3" ry="4" fill="oklch(0.28 0.10 30)"/>
        <circle cx="43" cy="78.5" r="1.2" fill="#fff"/>
        <circle cx="59" cy="78.5" r="1.2" fill="#fff"/>
        <path d="M44 90 Q50 96 56 90" stroke="oklch(0.28 0.10 30)" strokeWidth="2" fill="oklch(0.60 0.18 25)" strokeLinecap="round"/>
        <circle cx="36" cy="88" r="2.5" fill="oklch(0.85 0.14 20)" opacity="0.6"/>
        <circle cx="64" cy="88" r="2.5" fill="oklch(0.85 0.14 20)" opacity="0.6"/>
      </g>
    </svg>
  );
}

// Backpack for "school prep"
function Backpack({ size = 100, style }) {
  return (
    <svg viewBox="0 0 100 120" width={size} height={size * 120/100} style={style}>
      <ellipse cx="50" cy="114" rx="38" ry="4" fill="rgba(0,0,0,0.2)"/>
      {/* straps */}
      <rect x="26" y="10" width="8" height="30" rx="4" fill="oklch(0.55 0.15 250)"/>
      <rect x="66" y="10" width="8" height="30" rx="4" fill="oklch(0.55 0.15 250)"/>
      {/* body */}
      <path d="M20 40 Q20 24 50 24 Q80 24 80 40 L80 104 Q80 114 70 114 L30 114 Q20 114 20 104 Z" fill="oklch(0.68 0.17 250)"/>
      <path d="M20 40 Q20 24 50 24 Q80 24 80 40" fill="none" stroke="#fff" strokeWidth="1.5" opacity="0.5"/>
      {/* pocket */}
      <rect x="28" y="60" width="44" height="36" rx="6" fill="oklch(0.78 0.14 245)"/>
      <rect x="28" y="60" width="44" height="10" rx="6" fill="#fff" opacity="0.3"/>
      {/* badge */}
      <circle cx="60" cy="78" r="5" fill="oklch(0.85 0.16 60)"/>
    </svg>
  );
}

// Pencil cup — used in school-prep scene
function PencilBunch({ size = 80, style }) {
  const pens = [
    { c: 'oklch(0.78 0.18 30)', x: 0, h: 80 },
    { c: 'oklch(0.80 0.14 160)', x: 12, h: 70 },
    { c: 'oklch(0.78 0.14 260)', x: 24, h: 90 },
    { c: 'oklch(0.85 0.14 85)', x: 36, h: 65 },
  ];
  return (
    <svg viewBox="0 0 60 100" width={size} height={size * 100/60} style={style}>
      {pens.map((p, i) => (
        <g key={i} transform={`translate(${p.x + 6} ${100 - p.h})`}>
          <rect x="0" y="6" width="10" height={p.h - 14} rx="1" fill={p.c}/>
          <rect x="0" y="6" width="10" height="6" rx="1" fill="oklch(0.35 0.04 40)"/>
          <polygon points="0,0 10,0 5,-8" fill="oklch(0.85 0.06 60)"/>
          <polygon points="3,-5 7,-5 5,-8" fill="oklch(0.25 0.02 40)"/>
        </g>
      ))}
    </svg>
  );
}

// Number glyphs 3D style — for school-prep
function BigNum({ num = '1', size = 60, color = 'oklch(0.78 0.18 30)', style }) {
  return (
    <svg viewBox="0 0 60 80" width={size} height={size * 80/60} style={style}>
      <text x="30" y="66" fontSize="72" fontWeight="900" fill={color} fontFamily="Nunito,system-ui" textAnchor="middle"
        stroke="#fff" strokeWidth="2">{num}</text>
    </svg>
  );
}

// Music note
function Note3D({ size = 40, color = 'oklch(0.72 0.16 280)', style }) {
  return (
    <svg viewBox="0 0 40 50" width={size} height={size * 50/40} style={style}>
      <ellipse cx="14" cy="38" rx="10" ry="7" fill={color}/>
      <ellipse cx="14" cy="36" rx="10" ry="7" fill="none" stroke="#fff" strokeWidth="1.2" opacity="0.5"/>
      <rect x="22" y="10" width="4" height="30" fill={color}/>
      <path d="M22 10 Q36 14 36 26" stroke={color} strokeWidth="4" fill="none" strokeLinecap="round"/>
    </svg>
  );
}

// ─── BIGGER COMPOSITE SCENES ──────────────────────────────────

// "Sprout/plant" scene — for launch-speech category
function SproutScene({ w = 220, h = 160, style }) {
  return (
    <div style={{ width: w, height: h, position: 'relative', overflow: 'hidden', borderRadius: 20, background: 'linear-gradient(180deg, oklch(0.94 0.06 300), oklch(0.96 0.04 260))', ...style }}>
      <RaysBg hue="oklch(0.88 0.09 280)" hue2="oklch(0.97 0.04 290)" opacity={0.35}/>
      <svg viewBox="0 0 220 160" width={w} height={h} style={{ position: 'absolute', inset: 0 }}>
        <ellipse cx="110" cy="140" rx="80" ry="12" fill="rgba(60,40,60,0.15)"/>
        {/* pot */}
        <path d="M72 106 L68 138 Q68 148 78 148 L142 148 Q152 148 152 138 L148 106 Z" fill="oklch(0.72 0.14 30)"/>
        <rect x="66" y="100" width="88" height="12" rx="3" fill="oklch(0.80 0.14 30)"/>
        <rect x="66" y="100" width="88" height="4" fill="#fff" opacity="0.3"/>
        {/* stem */}
        <path d="M110 100 Q106 70 110 40 Q114 10 110 8" stroke="oklch(0.58 0.15 140)" strokeWidth="5" fill="none" strokeLinecap="round"/>
        {/* leaves */}
        <ellipse cx="84" cy="60" rx="18" ry="10" fill="oklch(0.70 0.16 140)" transform="rotate(-25 84 60)"/>
        <ellipse cx="136" cy="46" rx="22" ry="12" fill="oklch(0.76 0.16 140)" transform="rotate(20 136 46)"/>
        <ellipse cx="90" cy="30" rx="16" ry="9" fill="oklch(0.78 0.15 140)" transform="rotate(-35 90 30)"/>
        {/* flowers */}
        <circle cx="128" cy="20" r="10" fill="oklch(0.85 0.16 20)"/>
        <circle cx="128" cy="20" r="4" fill="oklch(0.85 0.15 85)"/>
        <circle cx="88" cy="14" r="7" fill="oklch(0.80 0.16 305)"/>
      </svg>
    </div>
  );
}

// "Alphabet playground" scene — for develop-speech
function AlphaPlayScene({ w = 220, h = 160, style }) {
  return (
    <div style={{ width: w, height: h, position: 'relative', overflow: 'hidden', borderRadius: 20, background: 'linear-gradient(180deg, oklch(0.92 0.08 200), oklch(0.96 0.05 220))', ...style }}>
      <RaysBg hue="oklch(0.85 0.10 210)" hue2="oklch(0.95 0.05 220)" opacity={0.4}/>
      <Cloud3D size={50} style={{ position: 'absolute', top: 8, left: 14 }}/>
      <Cloud3D size={40} style={{ position: 'absolute', top: 22, right: 22, opacity: 0.7 }}/>
      <Easel size={120} style={{ position: 'absolute', bottom: 6, left: 10 }}/>
      <BookStack size={80} style={{ position: 'absolute', bottom: 6, right: 16 }}/>
    </div>
  );
}

// "Games scene" — cube + blocks + letters
function GamesScene({ w = 220, h = 160, style }) {
  return (
    <div style={{ width: w, height: h, position: 'relative', overflow: 'hidden', borderRadius: 20, background: 'linear-gradient(180deg, oklch(0.93 0.07 310), oklch(0.96 0.04 280))', ...style }}>
      <RaysBg hue="oklch(0.86 0.10 305)" hue2="oklch(0.96 0.04 295)" opacity={0.35}/>
      <svg viewBox="0 0 220 160" style={{ position: 'absolute', inset: 0 }} width={w} height={h}>
        <ellipse cx="110" cy="140" rx="80" ry="12" fill="rgba(60,40,60,0.15)"/>
        {/* big cube */}
        <polygon points="70,70 120,60 160,78 160,128 120,136 70,120" fill="oklch(0.72 0.16 305)"/>
        <polygon points="70,70 120,60 120,110 70,120" fill="oklch(0.82 0.14 305)"/>
        <polygon points="120,60 160,78 160,128 120,110" fill="oklch(0.60 0.18 305)"/>
        <text x="92" y="96" fontSize="22" fontWeight="900" fill="#fff" fontFamily="Nunito">5</text>
        {/* dice */}
        <rect x="28" y="100" width="36" height="36" rx="6" fill="oklch(0.78 0.14 160)" transform="rotate(-8 46 118)"/>
        <circle cx="38" cy="112" r="2.4" fill="#fff" transform="rotate(-8 46 118)"/>
        <circle cx="54" cy="124" r="2.4" fill="#fff" transform="rotate(-8 46 118)"/>
        {/* small block */}
        <rect x="162" y="108" width="28" height="28" rx="5" fill="oklch(0.82 0.14 60)"/>
        <text x="176" y="128" fontSize="16" fontWeight="900" fill="oklch(0.50 0.16 50)" textAnchor="middle" fontFamily="Nunito">А</text>
      </svg>
    </div>
  );
}

// "School scene" — backpack + pencils + numbers
function SchoolScene({ w = 220, h = 160, style }) {
  return (
    <div style={{ width: w, height: h, position: 'relative', overflow: 'hidden', borderRadius: 20, background: 'linear-gradient(180deg, oklch(0.93 0.08 230), oklch(0.96 0.05 250))', ...style }}>
      <RaysBg hue="oklch(0.86 0.10 235)" hue2="oklch(0.96 0.04 245)" opacity={0.4}/>
      <svg viewBox="0 0 220 160" width={w} height={h} style={{ position: 'absolute', inset: 0 }}>
        <ellipse cx="110" cy="144" rx="86" ry="10" fill="rgba(40,60,120,0.15)"/>
      </svg>
      <BigNum num="1" size={54} color="oklch(0.80 0.16 55)" style={{ position: 'absolute', top: 8, left: 40 }}/>
      <BigNum num="2" size={42} color="oklch(0.78 0.18 30)" style={{ position: 'absolute', top: 58, left: 84 }}/>
      <BigNum num="3" size={48} color="oklch(0.76 0.16 160)" style={{ position: 'absolute', top: 20, left: 108 }}/>
      <Backpack size={100} style={{ position: 'absolute', bottom: 0, right: 10 }}/>
      <PencilBunch size={60} style={{ position: 'absolute', bottom: 4, left: 16 }}/>
    </div>
  );
}

// "Trophy scene" — trophy + gifts + sparkles
function TrophyScene({ w = 220, h = 160, style }) {
  return (
    <div style={{ width: w, height: h, position: 'relative', overflow: 'hidden', borderRadius: 20, background: 'linear-gradient(180deg, oklch(0.93 0.08 60), oklch(0.96 0.05 80))', ...style }}>
      <RaysBg hue="oklch(0.88 0.12 70)" hue2="oklch(0.97 0.05 75)" opacity={0.5}/>
      <Trophy size={110} style={{ position: 'absolute', bottom: 0, left: '50%', transform: 'translateX(-50%)' }}/>
      <Gift size={52} color="oklch(0.80 0.16 20)" ribbon="oklch(0.90 0.12 85)" style={{ position: 'absolute', bottom: 8, left: 18 }}/>
      <Gift size={44} color="oklch(0.76 0.15 200)" ribbon="oklch(0.88 0.14 30)" style={{ position: 'absolute', bottom: 12, right: 20 }}/>
      <Sparkle size={18} style={{ position: 'absolute', top: 18, right: 40 }}/>
      <Sparkle size={14} color="oklch(0.80 0.14 305)" style={{ position: 'absolute', top: 40, left: 30 }}/>
    </div>
  );
}

// "Sound island" — island with butterfly on top, used for map
function SoundIslandScene({ w = 220, h = 160, style, letter = 'Р' }) {
  return (
    <div style={{ width: w, height: h, position: 'relative', overflow: 'hidden', borderRadius: 20, background: 'linear-gradient(180deg, oklch(0.93 0.07 210), oklch(0.96 0.04 215))', ...style }}>
      <Cloud3D size={46} style={{ position: 'absolute', top: 10, left: 20 }}/>
      <Cloud3D size={36} style={{ position: 'absolute', top: 24, right: 24, opacity: 0.6 }}/>
      <Island size={160} style={{ position: 'absolute', bottom: -10, left: 30 }}/>
      <div style={{ position: 'absolute', top: 22, left: '50%', transform: 'translateX(-50%)' }}>
        <Butterfly size={70} mood="happy" flap={true} bob={true}/>
      </div>
      <div style={{ position: 'absolute', bottom: 30, left: '50%', transform: 'translateX(-50%)', background: '#fff', borderRadius: 16, padding: '4px 14px', fontFamily: 'Nunito', fontWeight: 900, fontSize: 28, color: HS.brand.primary, boxShadow: '0 4px 10px rgba(0,0,0,0.1)' }}>{letter}</div>
    </div>
  );
}

Object.assign(window, {
  Sphere, Slab, RaysBg,
  Trophy, Rocket, Gift, BookStack, Easel, Stage, Island, Cloud3D, Flower, Heart3D, Flame, Backpack, PencilBunch, BigNum, Note3D,
  SproutScene, AlphaPlayScene, GamesScene, SchoolScene, TrophyScene, SoundIslandScene,
});
