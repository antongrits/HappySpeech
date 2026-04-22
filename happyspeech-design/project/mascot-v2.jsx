// HappySpeech v2 — extended mascot moods + companion characters.
// All original, no hippos, no emoji. Style: soft pastel 3D-ish SVG.

const { HS } = window;

// Inject mascot-v2 keyframes once
(function injectMascotV2Styles(){
  if (document.getElementById('hs-mascot-v2-styles')) return;
  const s = document.createElement('style');
  s.id = 'hs-mascot-v2-styles';
  s.textContent = `
    @keyframes hsBlink { 0%, 92%, 100% { transform: scaleY(1); } 96% { transform: scaleY(0.1); } }
    @keyframes hsEar   { 0%, 100% { transform: rotate(-4deg); } 50% { transform: rotate(4deg); } }
    @keyframes hsTail  { 0%, 100% { transform: rotate(0); } 50% { transform: rotate(18deg); } }
    @keyframes hsBreath { 0%, 100% { transform: scale(1); } 50% { transform: scale(1.04); } }
    .hs-blink  { animation: hsBlink 4s ease-in-out infinite; transform-origin: 50% 50%; }
    .hs-ear-L  { animation: hsEar 2.4s ease-in-out infinite; transform-origin: 100% 100%; }
    .hs-ear-R  { animation: hsEar 2.4s ease-in-out infinite reverse; transform-origin: 0% 100%; }
    .hs-tail   { animation: hsTail 1.8s ease-in-out infinite; transform-origin: 0% 50%; }
    .hs-breath { animation: hsBreath 3s ease-in-out infinite; }
  `;
  document.head.appendChild(s);
})();

// Bigger, more expressive Lyalya-butterfly — bigger head, softer eyes,
// more sparkle. Adds moods: 'excited', 'encouraging', 'shy', 'focused'.
function ButterflyV2({ size = 160, mood = 'happy', sparkles = true, style = {} }) {
  const wingBase = 'oklch(0.78 0.16 35)';
  const wingDark = 'oklch(0.58 0.19 28)';
  const wingPattern = 'oklch(0.90 0.13 60)';
  const wingAccent = 'oklch(0.82 0.14 20)';
  const body = 'oklch(0.32 0.05 40)';
  const cheek = 'oklch(0.82 0.15 20)';

  // Mood-specific faces
  const eyes = (() => {
    if (mood === 'sleeping') return (
      <>
        <path d="M-8 0 Q-4 -3 0 0" stroke={body} strokeWidth="2.2" fill="none" strokeLinecap="round"/>
        <path d="M4 0 Q8 -3 12 0" stroke={body} strokeWidth="2.2" fill="none" strokeLinecap="round"/>
      </>
    );
    if (mood === 'shy') return (
      <>
        <path d="M-8 0 Q-4 2 0 0" stroke={body} strokeWidth="2.2" fill="none" strokeLinecap="round"/>
        <path d="M4 0 Q8 2 12 0" stroke={body} strokeWidth="2.2" fill="none" strokeLinecap="round"/>
      </>
    );
    const common = (ox) => (
      <g transform={`translate(${ox} 0)`}>
        <ellipse rx="4.2" ry="5.2" fill={body}/>
        <circle cx="1.2" cy="-1.5" r="1.8" fill="#fff"/>
        <circle cx="0.5" cy="1.5" r="0.8" fill="#fff" opacity="0.8"/>
      </g>
    );
    return <g className="hs-blink">{common(-4)}{common(8)}</g>;
  })();

  const mouth = (() => {
    if (mood === 'celebrating' || mood === 'excited') return (
      <path d="M-6 2 Q2 10 10 2 Q6 8 2 8 Q-2 8 -6 2 Z" fill="oklch(0.45 0.15 20)" stroke={body} strokeWidth="1.6" strokeLinecap="round"/>
    );
    if (mood === 'thinking' || mood === 'focused') return <path d="M-4 3 L8 3" stroke={body} strokeWidth="2" strokeLinecap="round"/>;
    if (mood === 'listening') return <ellipse cx="2" cy="4" rx="3" ry="2.4" fill={body}/>;
    if (mood === 'encouraging') return <path d="M-4 2 Q2 7 8 2" stroke={body} strokeWidth="2" fill="none" strokeLinecap="round"/>;
    return <path d="M-4 1.5 Q2 6 8 1.5" stroke={body} strokeWidth="2" fill="none" strokeLinecap="round"/>;
  })();

  // tongue for listening
  const tongue = mood === 'listening' ? <ellipse cx="2" cy="7" rx="2" ry="1.2" fill="oklch(0.72 0.15 20)"/> : null;

  return (
    <div style={{ width: size, height: size, display: 'inline-block', ...style }} className="hs-mascot-bob">
      <svg viewBox="0 0 160 160" width={size} height={size} style={{ overflow: 'visible' }}>
        <defs>
          <radialGradient id="wing-grad" cx="45%" cy="40%" r="65%">
            <stop offset="0%" stopColor={wingPattern}/>
            <stop offset="55%" stopColor={wingBase}/>
            <stop offset="100%" stopColor={wingDark}/>
          </radialGradient>
          <radialGradient id="head-grad" cx="40%" cy="35%" r="65%">
            <stop offset="0%" stopColor="oklch(0.55 0.05 40)"/>
            <stop offset="100%" stopColor={body}/>
          </radialGradient>
        </defs>

        {sparkles && <>
          <g className="hs-sparkle" style={{ animationDelay: '0s' }}>
            <path transform="translate(24 28)" d="M0 -7 L2 -2 L7 0 L2 2 L0 7 L-2 2 L-7 0 L-2 -2 Z" fill="oklch(0.88 0.14 85)"/>
          </g>
          <g className="hs-sparkle" style={{ animationDelay: '0.6s' }}>
            <path transform="translate(134 36)" d="M0 -6 L1.5 -1.5 L6 0 L1.5 1.5 L0 6 L-1.5 1.5 L-6 0 L-1.5 -1.5 Z" fill="oklch(0.80 0.14 305)"/>
          </g>
          <g className="hs-sparkle" style={{ animationDelay: '1.2s' }}>
            <path transform="translate(140 112)" d="M0 -5 L1.2 -1.2 L5 0 L1.2 1.2 L0 5 L-1.2 1.2 L-5 0 L-1.2 -1.2 Z" fill="oklch(0.82 0.13 165)"/>
          </g>
        </>}

        {/* Left wings */}
        <g className="hs-wing-L">
          <path d="M80 80 C 40 40, 16 48, 18 80 C 20 108, 54 108, 80 88 Z" fill="url(#wing-grad)" stroke={wingDark} strokeWidth="2"/>
          <circle cx="38" cy="68" r="6" fill={wingPattern}/>
          <circle cx="34" cy="68" r="2.5" fill={wingAccent}/>
          <circle cx="48" cy="92" r="4" fill={wingPattern}/>
          <path d="M80 80 C 56 96, 40 120, 52 128 C 66 136, 76 108, 80 92 Z" fill={wingAccent} stroke={wingDark} strokeWidth="2"/>
          <circle cx="60" cy="116" r="3" fill="oklch(0.90 0.13 70)"/>
        </g>

        {/* Right wings */}
        <g className="hs-wing-R">
          <path d="M80 80 C 120 40, 144 48, 142 80 C 140 108, 106 108, 80 88 Z" fill="url(#wing-grad)" stroke={wingDark} strokeWidth="2"/>
          <circle cx="122" cy="68" r="6" fill={wingPattern}/>
          <circle cx="126" cy="68" r="2.5" fill={wingAccent}/>
          <circle cx="112" cy="92" r="4" fill={wingPattern}/>
          <path d="M80 80 C 104 96, 120 120, 108 128 C 94 136, 84 108, 80 92 Z" fill={wingAccent} stroke={wingDark} strokeWidth="2"/>
          <circle cx="100" cy="116" r="3" fill="oklch(0.90 0.13 70)"/>
        </g>

        {/* body */}
        <ellipse cx="80" cy="84" rx="8" ry="22" fill={body}/>
        <ellipse cx="80" cy="84" rx="8" ry="22" fill="url(#head-grad)" opacity="0.5"/>
        {/* abdominal rings */}
        <ellipse cx="80" cy="76" rx="8" ry="1.5" fill="oklch(0.26 0.05 40)"/>
        <ellipse cx="80" cy="86" rx="8" ry="1.5" fill="oklch(0.26 0.05 40)"/>
        <ellipse cx="80" cy="96" rx="7" ry="1.5" fill="oklch(0.26 0.05 40)"/>

        {/* head */}
        <circle cx="80" cy="62" r="15" fill="url(#head-grad)"/>

        {/* antennae */}
        <path d="M74 50 Q 68 34 62 28" stroke={body} strokeWidth="2.5" fill="none" strokeLinecap="round"/>
        <path d="M86 50 Q 92 34 98 28" stroke={body} strokeWidth="2.5" fill="none" strokeLinecap="round"/>
        <circle cx="62" cy="28" r="3" fill={wingBase}/>
        <circle cx="98" cy="28" r="3" fill={wingBase}/>
        <circle cx="62" cy="28" r="1" fill="#fff"/>
        <circle cx="98" cy="28" r="1" fill="#fff"/>

        {/* face */}
        <g transform="translate(76 60)">{eyes}</g>
        <g transform="translate(76 64)">{mouth}{tongue}</g>
        <circle cx="70" cy="66" r="3" fill={cheek} opacity="0.55"/>
        <circle cx="90" cy="66" r="3" fill={cheek} opacity="0.55"/>

        {/* head highlight */}
        <ellipse cx="74" cy="54" rx="4" ry="2.5" fill="#fff" opacity="0.35"/>
      </svg>
    </div>
  );
}

// ── Companion characters — sound-family mascots ──
// Each companion is a friendly round creature; distinct silhouette per family.

// Zippy (Whistling family: С, З, Ц) — teal droplet mouse
function Zippy({ size = 100, style }) {
  return (
    <div style={{ width: size, height: size, display: 'inline-block', ...style }}>
      <svg viewBox="0 0 120 120" width={size} height={size}>
        <defs>
          <radialGradient id="zp-body" cx="40%" cy="35%" r="65%">
            <stop offset="0%" stopColor="#fff"/>
            <stop offset="45%" stopColor="oklch(0.82 0.12 200)"/>
            <stop offset="100%" stopColor="oklch(0.55 0.14 205)"/>
          </radialGradient>
        </defs>
        <ellipse cx="60" cy="110" rx="34" ry="4" fill="rgba(0,0,0,0.2)"/>
        {/* ears */}
        <g className="hs-ear-L" style={{ transformOrigin: '48px 52px' }}>
          <ellipse cx="44" cy="36" rx="10" ry="14" fill="oklch(0.70 0.13 200)"/>
          <ellipse cx="44" cy="38" rx="5" ry="8" fill="oklch(0.88 0.11 30)"/>
        </g>
        <g className="hs-ear-R" style={{ transformOrigin: '72px 52px' }}>
          <ellipse cx="76" cy="36" rx="10" ry="14" fill="oklch(0.70 0.13 200)"/>
          <ellipse cx="76" cy="38" rx="5" ry="8" fill="oklch(0.88 0.11 30)"/>
        </g>
        {/* body */}
        <ellipse cx="60" cy="72" rx="32" ry="34" fill="url(#zp-body)"/>
        {/* belly */}
        <ellipse cx="60" cy="84" rx="20" ry="20" fill="#fff" opacity="0.7"/>
        {/* face */}
        <g className="hs-blink">
          <ellipse cx="50" cy="66" rx="4" ry="5" fill="oklch(0.22 0.04 40)"/>
          <ellipse cx="70" cy="66" rx="4" ry="5" fill="oklch(0.22 0.04 40)"/>
          <circle cx="51" cy="64" r="1.4" fill="#fff"/>
          <circle cx="71" cy="64" r="1.4" fill="#fff"/>
        </g>
        <ellipse cx="60" cy="76" rx="3" ry="2" fill="oklch(0.55 0.12 200)"/>
        <path d="M54 80 Q60 84 66 80" stroke="oklch(0.22 0.04 40)" strokeWidth="1.6" fill="none" strokeLinecap="round"/>
        <circle cx="42" cy="74" r="3" fill="oklch(0.85 0.14 20)" opacity="0.55"/>
        <circle cx="78" cy="74" r="3" fill="oklch(0.85 0.14 20)" opacity="0.55"/>
        {/* letter badge */}
        <circle cx="88" cy="96" r="10" fill="oklch(0.72 0.14 200)" stroke="#fff" strokeWidth="2"/>
        <text x="88" y="100" fontSize="11" fontWeight="900" fill="#fff" textAnchor="middle" fontFamily="Nunito">С</text>
      </svg>
    </div>
  );
}

// Shushkin (Hissing: Ш, Ж, Ч, Щ) — lilac fox-ish creature
function Shushkin({ size = 100, style }) {
  return (
    <div style={{ width: size, height: size, display: 'inline-block', ...style }}>
      <svg viewBox="0 0 120 120" width={size} height={size}>
        <defs>
          <radialGradient id="sh-body" cx="40%" cy="35%" r="65%">
            <stop offset="0%" stopColor="#fff"/>
            <stop offset="45%" stopColor="oklch(0.80 0.13 305)"/>
            <stop offset="100%" stopColor="oklch(0.55 0.15 300)"/>
          </radialGradient>
        </defs>
        <ellipse cx="60" cy="110" rx="34" ry="4" fill="rgba(0,0,0,0.2)"/>
        {/* tail */}
        <g className="hs-tail" style={{ transformOrigin: '90px 80px' }}>
          <ellipse cx="104" cy="72" rx="14" ry="8" fill="oklch(0.74 0.14 305)" transform="rotate(-30 104 72)"/>
          <ellipse cx="110" cy="68" rx="6" ry="4" fill="#fff" transform="rotate(-30 110 68)"/>
        </g>
        {/* ears (pointy) */}
        <polygon points="36,28 48,22 48,46" fill="oklch(0.72 0.14 305)"/>
        <polygon points="84,28 72,22 72,46" fill="oklch(0.72 0.14 305)"/>
        <polygon points="42,30 48,28 48,42" fill="oklch(0.90 0.12 305)"/>
        <polygon points="78,30 72,28 72,42" fill="oklch(0.90 0.12 305)"/>
        {/* body */}
        <ellipse cx="60" cy="72" rx="30" ry="34" fill="url(#sh-body)"/>
        {/* face */}
        <g className="hs-blink">
          <ellipse cx="50" cy="66" rx="4" ry="5" fill="oklch(0.22 0.04 40)"/>
          <ellipse cx="70" cy="66" rx="4" ry="5" fill="oklch(0.22 0.04 40)"/>
          <circle cx="51" cy="64" r="1.4" fill="#fff"/>
          <circle cx="71" cy="64" r="1.4" fill="#fff"/>
        </g>
        <path d="M56 76 Q60 80 64 76" stroke="oklch(0.22 0.04 40)" strokeWidth="2" fill="oklch(0.55 0.15 300)" strokeLinecap="round"/>
        <circle cx="42" cy="74" r="3" fill="oklch(0.85 0.14 20)" opacity="0.5"/>
        <circle cx="78" cy="74" r="3" fill="oklch(0.85 0.14 20)" opacity="0.5"/>
        {/* letter badge */}
        <circle cx="90" cy="96" r="10" fill="oklch(0.60 0.17 300)" stroke="#fff" strokeWidth="2"/>
        <text x="90" y="100" fontSize="11" fontWeight="900" fill="#fff" textAnchor="middle" fontFamily="Nunito">Ш</text>
      </svg>
    </div>
  );
}

// Ryoka (Sonorant: Р, Л) — coral bear cub
function Ryoka({ size = 100, style }) {
  return (
    <div style={{ width: size, height: size, display: 'inline-block', ...style }}>
      <svg viewBox="0 0 120 120" width={size} height={size}>
        <defs>
          <radialGradient id="ry-body" cx="40%" cy="35%" r="65%">
            <stop offset="0%" stopColor="#fff"/>
            <stop offset="45%" stopColor="oklch(0.80 0.15 30)"/>
            <stop offset="100%" stopColor="oklch(0.55 0.18 28)"/>
          </radialGradient>
        </defs>
        <ellipse cx="60" cy="110" rx="34" ry="4" fill="rgba(0,0,0,0.2)"/>
        {/* round ears */}
        <circle cx="40" cy="38" r="10" fill="oklch(0.70 0.16 30)"/>
        <circle cx="80" cy="38" r="10" fill="oklch(0.70 0.16 30)"/>
        <circle cx="40" cy="40" r="5" fill="oklch(0.88 0.13 30)"/>
        <circle cx="80" cy="40" r="5" fill="oklch(0.88 0.13 30)"/>
        {/* body */}
        <ellipse cx="60" cy="72" rx="32" ry="34" fill="url(#ry-body)"/>
        {/* muzzle */}
        <ellipse cx="60" cy="78" rx="16" ry="12" fill="oklch(0.94 0.05 30)"/>
        {/* face */}
        <g className="hs-blink">
          <ellipse cx="50" cy="66" rx="4" ry="5" fill="oklch(0.22 0.04 40)"/>
          <ellipse cx="70" cy="66" rx="4" ry="5" fill="oklch(0.22 0.04 40)"/>
          <circle cx="51" cy="64" r="1.4" fill="#fff"/>
          <circle cx="71" cy="64" r="1.4" fill="#fff"/>
        </g>
        <ellipse cx="60" cy="76" rx="3.5" ry="2.5" fill="oklch(0.35 0.08 30)"/>
        <path d="M54 82 Q60 86 66 82" stroke="oklch(0.22 0.04 40)" strokeWidth="2" fill="none" strokeLinecap="round"/>
        <circle cx="40" cy="76" r="3" fill="oklch(0.85 0.14 20)" opacity="0.55"/>
        <circle cx="80" cy="76" r="3" fill="oklch(0.85 0.14 20)" opacity="0.55"/>
        {/* badge */}
        <circle cx="90" cy="96" r="10" fill="oklch(0.62 0.19 28)" stroke="#fff" strokeWidth="2"/>
        <text x="90" y="100" fontSize="11" fontWeight="900" fill="#fff" textAnchor="middle" fontFamily="Nunito">Р</text>
      </svg>
    </div>
  );
}

// Kuku (Velar: К, Г, Х) — green frog
function Kuku({ size = 100, style }) {
  return (
    <div style={{ width: size, height: size, display: 'inline-block', ...style }}>
      <svg viewBox="0 0 120 120" width={size} height={size}>
        <defs>
          <radialGradient id="kk-body" cx="40%" cy="35%" r="65%">
            <stop offset="0%" stopColor="#fff"/>
            <stop offset="45%" stopColor="oklch(0.80 0.14 145)"/>
            <stop offset="100%" stopColor="oklch(0.55 0.16 140)"/>
          </radialGradient>
        </defs>
        <ellipse cx="60" cy="110" rx="36" ry="4" fill="rgba(0,0,0,0.2)"/>
        {/* eye bumps */}
        <circle cx="44" cy="42" r="14" fill="oklch(0.78 0.14 140)"/>
        <circle cx="76" cy="42" r="14" fill="oklch(0.78 0.14 140)"/>
        <circle cx="44" cy="44" r="8" fill="#fff"/>
        <circle cx="76" cy="44" r="8" fill="#fff"/>
        <circle cx="44" cy="46" r="4" fill="oklch(0.22 0.04 40)"/>
        <circle cx="76" cy="46" r="4" fill="oklch(0.22 0.04 40)"/>
        <circle cx="45" cy="44" r="1.5" fill="#fff"/>
        <circle cx="77" cy="44" r="1.5" fill="#fff"/>
        {/* body */}
        <ellipse cx="60" cy="78" rx="36" ry="30" fill="url(#kk-body)"/>
        {/* belly */}
        <ellipse cx="60" cy="86" rx="22" ry="16" fill="oklch(0.92 0.08 140)"/>
        {/* mouth */}
        <path d="M40 76 Q60 92 80 76" stroke="oklch(0.22 0.04 40)" strokeWidth="2.4" fill="none" strokeLinecap="round"/>
        {/* badge */}
        <circle cx="92" cy="98" r="10" fill="oklch(0.58 0.16 140)" stroke="#fff" strokeWidth="2"/>
        <text x="92" y="102" fontSize="11" fontWeight="900" fill="#fff" textAnchor="middle" fontFamily="Nunito">К</text>
      </svg>
    </div>
  );
}

// Aoko (Vowels) — butter bunny-bird
function Aoko({ size = 100, style }) {
  return (
    <div style={{ width: size, height: size, display: 'inline-block', ...style }}>
      <svg viewBox="0 0 120 120" width={size} height={size}>
        <defs>
          <radialGradient id="ao-body" cx="40%" cy="35%" r="65%">
            <stop offset="0%" stopColor="#fff"/>
            <stop offset="45%" stopColor="oklch(0.88 0.14 85)"/>
            <stop offset="100%" stopColor="oklch(0.68 0.17 75)"/>
          </radialGradient>
        </defs>
        <ellipse cx="60" cy="110" rx="34" ry="4" fill="rgba(0,0,0,0.2)"/>
        {/* long ears */}
        <ellipse cx="46" cy="30" rx="5" ry="20" fill="oklch(0.78 0.16 80)"/>
        <ellipse cx="74" cy="30" rx="5" ry="20" fill="oklch(0.78 0.16 80)"/>
        <ellipse cx="46" cy="32" rx="2.5" ry="14" fill="oklch(0.90 0.10 30)"/>
        <ellipse cx="74" cy="32" rx="2.5" ry="14" fill="oklch(0.90 0.10 30)"/>
        {/* body */}
        <ellipse cx="60" cy="74" rx="30" ry="34" fill="url(#ao-body)"/>
        {/* face */}
        <g className="hs-blink">
          <ellipse cx="50" cy="66" rx="4" ry="5" fill="oklch(0.22 0.04 40)"/>
          <ellipse cx="70" cy="66" rx="4" ry="5" fill="oklch(0.22 0.04 40)"/>
          <circle cx="51" cy="64" r="1.4" fill="#fff"/>
          <circle cx="71" cy="64" r="1.4" fill="#fff"/>
        </g>
        <path d="M56 76 Q60 82 64 76" stroke="oklch(0.22 0.04 40)" strokeWidth="2" fill="oklch(0.50 0.14 20)" strokeLinecap="round"/>
        <circle cx="42" cy="74" r="3" fill="oklch(0.85 0.14 20)" opacity="0.55"/>
        <circle cx="78" cy="74" r="3" fill="oklch(0.85 0.14 20)" opacity="0.55"/>
        {/* badge */}
        <circle cx="90" cy="96" r="10" fill="oklch(0.72 0.16 75)" stroke="#fff" strokeWidth="2"/>
        <text x="90" y="100" fontSize="11" fontWeight="900" fill="#fff" textAnchor="middle" fontFamily="Nunito">А</text>
      </svg>
    </div>
  );
}

// Shhh — quiet room librarian-like character (finger to lips)
function QuietFriend({ size = 140, style }) {
  return (
    <div style={{ width: size, height: size, display: 'inline-block', ...style }} className="hs-mascot-bob">
      <svg viewBox="0 0 140 160" width={size} height={size * 160/140}>
        <defs>
          <radialGradient id="qf-body" cx="40%" cy="30%" r="65%">
            <stop offset="0%" stopColor="#fff"/>
            <stop offset="55%" stopColor="oklch(0.82 0.11 165)"/>
            <stop offset="100%" stopColor="oklch(0.55 0.14 160)"/>
          </radialGradient>
          <radialGradient id="qf-skin" cx="40%" cy="30%" r="65%">
            <stop offset="0%" stopColor="#fff"/>
            <stop offset="60%" stopColor="oklch(0.88 0.06 60)"/>
            <stop offset="100%" stopColor="oklch(0.72 0.10 45)"/>
          </radialGradient>
        </defs>
        <ellipse cx="70" cy="152" rx="40" ry="4" fill="rgba(0,0,0,0.2)"/>
        {/* headband */}
        <path d="M36 56 Q70 38 104 56" fill="oklch(0.55 0.14 160)"/>
        <path d="M42 62 Q70 46 98 62" fill="oklch(0.70 0.14 160)"/>
        {/* head */}
        <circle cx="70" cy="74" r="36" fill="url(#qf-skin)"/>
        {/* hair */}
        <path d="M38 62 Q36 90 42 100 Q38 70 48 58 Q60 50 70 50 Q80 50 92 58 Q102 70 98 100 Q104 90 102 62 Q100 42 70 42 Q40 42 38 62 Z" fill="oklch(0.45 0.08 45)"/>
        {/* face */}
        <g className="hs-blink">
          <circle cx="58" cy="74" r="3" fill="oklch(0.22 0.04 40)"/>
          <circle cx="82" cy="74" r="3" fill="oklch(0.22 0.04 40)"/>
        </g>
        <circle cx="50" cy="82" r="4" fill="oklch(0.85 0.14 20)" opacity="0.6"/>
        <circle cx="90" cy="82" r="4" fill="oklch(0.85 0.14 20)" opacity="0.6"/>
        <ellipse cx="70" cy="88" rx="4" ry="2" fill="oklch(0.70 0.14 25)"/>
        {/* body */}
        <path d="M30 150 Q30 116 50 108 Q70 102 90 108 Q110 116 110 150 Z" fill="url(#qf-body)"/>
        {/* finger-to-lips arm */}
        <path d="M64 120 Q62 104 70 96 L72 90 Q74 94 72 100 L68 104" fill="url(#qf-skin)" stroke="oklch(0.60 0.09 45)" strokeWidth="1"/>
      </svg>
    </div>
  );
}

// Snail (slow/focus) — for pause / rest state
function Snail({ size = 100, style }) {
  return (
    <div style={{ width: size, height: size, display: 'inline-block', ...style }} className="hs-mascot-bob">
      <svg viewBox="0 0 140 100" width={size} height={size * 100/140}>
        <defs>
          <radialGradient id="sn-shell" cx="40%" cy="35%" r="65%">
            <stop offset="0%" stopColor="oklch(0.92 0.10 30)"/>
            <stop offset="55%" stopColor="oklch(0.76 0.16 30)"/>
            <stop offset="100%" stopColor="oklch(0.50 0.16 25)"/>
          </radialGradient>
        </defs>
        <ellipse cx="70" cy="92" rx="52" ry="4" fill="rgba(0,0,0,0.2)"/>
        <ellipse cx="90" cy="80" rx="50" ry="12" fill="oklch(0.90 0.05 60)"/>
        {/* shell */}
        <circle cx="80" cy="54" r="30" fill="url(#sn-shell)"/>
        <path d="M80 54 Q82 40 66 42 Q56 50 66 60 Q74 66 80 54" fill="none" stroke="oklch(0.50 0.16 25)" strokeWidth="3"/>
        <path d="M80 54 Q92 38 104 52 Q110 68 94 76 Q82 76 80 60" fill="none" stroke="oklch(0.50 0.16 25)" strokeWidth="3"/>
        {/* body */}
        <ellipse cx="40" cy="74" rx="18" ry="10" fill="oklch(0.84 0.08 60)"/>
        {/* antennae */}
        <line x1="30" y1="68" x2="26" y2="52" stroke="oklch(0.50 0.08 60)" strokeWidth="2"/>
        <line x1="40" y1="66" x2="40" y2="48" stroke="oklch(0.50 0.08 60)" strokeWidth="2"/>
        <circle cx="26" cy="52" r="2" fill="oklch(0.22 0.04 40)"/>
        <circle cx="40" cy="48" r="2" fill="oklch(0.22 0.04 40)"/>
        {/* face */}
        <circle cx="34" cy="74" r="1.4" fill="oklch(0.22 0.04 40)"/>
        <path d="M30 78 Q34 80 38 78" stroke="oklch(0.22 0.04 40)" strokeWidth="1.2" fill="none" strokeLinecap="round"/>
      </svg>
    </div>
  );
}

// Lyalya flying — for headers / hero compositions (3/4 view)
function LyalyaHero({ size = 200, style }) {
  return (
    <div style={{ width: size, height: size * 0.9, position: 'relative', ...style }}>
      <ButterflyV2 size={size} sparkles={true}/>
      {/* additional floating dots */}
      <div style={{ position: 'absolute', top: '10%', left: '8%', width: 8, height: 8, borderRadius: 4, background: HS.brand.butter, opacity: 0.6 }} className="hs-rise"/>
      <div style={{ position: 'absolute', top: '28%', right: '10%', width: 6, height: 6, borderRadius: 3, background: HS.brand.lilac, opacity: 0.5 }} className="hs-rise" style={{ animationDelay: '0.8s' }}/>
    </div>
  );
}

Object.assign(window, {
  ButterflyV2, Zippy, Shushkin, Ryoka, Kuku, Aoko, QuietFriend, Snail, LyalyaHero,
});
