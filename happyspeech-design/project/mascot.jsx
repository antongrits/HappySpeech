// HappySpeech mascot — the bright friendly butterfly "Ляля".
// SVG-only, no external assets. Subtle wing-flap animation.

(function injectMascotStyles(){
  if (document.getElementById('hs-mascot-styles')) return;
  const s = document.createElement('style');
  s.id = 'hs-mascot-styles';
  s.textContent = `
    @keyframes hsFlap {
      0%, 100% { transform: scaleX(1); }
      50%      { transform: scaleX(0.82); }
    }
    @keyframes hsBob {
      0%, 100% { transform: translateY(0); }
      50%      { transform: translateY(-4px); }
    }
    @keyframes hsSparkle {
      0%, 100% { opacity: 0.2; transform: scale(0.8); }
      50%      { opacity: 1;   transform: scale(1.1); }
    }
    .hs-mascot-bob   { animation: hsBob 3.4s ease-in-out infinite; }
    .hs-wing-L       { transform-origin: 60% 50%; animation: hsFlap 1.6s ease-in-out infinite; }
    .hs-wing-R       { transform-origin: 40% 50%; animation: hsFlap 1.6s ease-in-out infinite; }
    .hs-sparkle      { animation: hsSparkle 2.2s ease-in-out infinite; }
  `;
  document.head.appendChild(s);
})();

// Butterfly in various moods: happy, celebrating, thinking, listening, sleeping
function Butterfly({ size = 120, mood = 'happy', flap = true, bob = true, sparkles = false, style = {} }) {
  const wingBody = mood === 'celebrating' ? 'oklch(0.75 0.18 35)' : 'oklch(0.72 0.17 35)';
  const wingEdge = 'oklch(0.62 0.19 30)';
  const wingPattern = 'oklch(0.88 0.11 50)';
  const body = 'oklch(0.35 0.04 40)';
  const cheek = 'oklch(0.82 0.13 20)';

  const eye = mood === 'sleeping'
    ? <>
        <path d="M-6 0 Q-3 -2 0 0" stroke={body} strokeWidth="2" fill="none" strokeLinecap="round"/>
      </>
    : <>
        <ellipse cx="0" cy="0" rx="3.2" ry="4" fill={body}/>
        <circle cx="1" cy="-1.2" r="1.3" fill="#fff"/>
      </>;

  const mouth = mood === 'celebrating'
    ? <path d="M-4 2 Q0 6 4 2" stroke={body} strokeWidth="1.6" fill="oklch(0.50 0.14 20)" strokeLinecap="round"/>
    : mood === 'thinking'
      ? <path d="M-3 2 L3 2" stroke={body} strokeWidth="1.6" strokeLinecap="round"/>
      : mood === 'listening'
        ? <circle cx="0" cy="2.5" r="2" fill={body} opacity="0.85"/>
        : <path d="M-3 1.5 Q0 4 3 1.5" stroke={body} strokeWidth="1.6" fill="none" strokeLinecap="round"/>;

  return (
    <div className={bob ? 'hs-mascot-bob' : ''} style={{ width: size, height: size, display: 'inline-block', ...style }}>
      <svg viewBox="0 0 120 120" width={size} height={size} style={{ overflow: 'visible' }}>
        {/* Sparkles */}
        {sparkles && <>
          <g className="hs-sparkle" style={{ animationDelay: '0s' }}><Star x={18} y={22} size={6} color="oklch(0.88 0.13 85)"/></g>
          <g className="hs-sparkle" style={{ animationDelay: '0.6s' }}><Star x={98} y={30} size={5} color="oklch(0.80 0.13 305)"/></g>
          <g className="hs-sparkle" style={{ animationDelay: '1.1s' }}><Star x={102} y={86} size={4} color="oklch(0.82 0.11 165)"/></g>
        </>}

        {/* Left wing */}
        <g className={flap ? 'hs-wing-L' : ''}>
          <path d="M60 60 C 30 30, 12 38, 14 62 C 16 82, 40 82, 60 66 Z" fill={wingBody} stroke={wingEdge} strokeWidth="2"/>
          <circle cx="28" cy="52" r="4.5" fill={wingPattern}/>
          <circle cx="35" cy="68" r="3" fill={wingPattern}/>
          <path d="M60 60 C 42 72, 30 88, 40 96 C 50 102, 58 82, 60 70 Z" fill="oklch(0.78 0.14 40)" stroke={wingEdge} strokeWidth="2"/>
          <circle cx="46" cy="88" r="2.5" fill={wingPattern}/>
        </g>

        {/* Right wing */}
        <g className={flap ? 'hs-wing-R' : ''}>
          <path d="M60 60 C 90 30, 108 38, 106 62 C 104 82, 80 82, 60 66 Z" fill={wingBody} stroke={wingEdge} strokeWidth="2"/>
          <circle cx="92" cy="52" r="4.5" fill={wingPattern}/>
          <circle cx="85" cy="68" r="3" fill={wingPattern}/>
          <path d="M60 60 C 78 72, 90 88, 80 96 C 70 102, 62 82, 60 70 Z" fill="oklch(0.78 0.14 40)" stroke={wingEdge} strokeWidth="2"/>
          <circle cx="74" cy="88" r="2.5" fill={wingPattern}/>
        </g>

        {/* Body */}
        <ellipse cx="60" cy="62" rx="6" ry="18" fill={body}/>
        <circle cx="60" cy="46" r="11" fill={body}/>
        {/* Antennae */}
        <path d="M56 38 Q 52 26 48 22" stroke={body} strokeWidth="2" fill="none" strokeLinecap="round"/>
        <path d="M64 38 Q 68 26 72 22" stroke={body} strokeWidth="2" fill="none" strokeLinecap="round"/>
        <circle cx="48" cy="22" r="2.2" fill={wingBody}/>
        <circle cx="72" cy="22" r="2.2" fill={wingBody}/>

        {/* Face */}
        <g transform="translate(56, 46)">{eye}</g>
        <g transform="translate(64, 46)">{eye}</g>
        <circle cx="52" cy="50" r="2.2" fill={cheek} opacity="0.55"/>
        <circle cx="68" cy="50" r="2.2" fill={cheek} opacity="0.55"/>
        <g transform="translate(60, 48)">{mouth}</g>
      </svg>
    </div>
  );
}

function Star({ x, y, size, color }) {
  return <path transform={`translate(${x} ${y}) scale(${size/10})`}
    d="M0 -5 L1.5 -1.5 L5 0 L1.5 1.5 L0 5 L-1.5 1.5 L-5 0 L-1.5 -1.5 Z"
    fill={color}/>;
}

// Small decorative elements for the world
function Cloud({ size=60, color='#fff', opacity=1, style }) {
  return (
    <svg viewBox="0 0 100 60" width={size} height={size*0.6} style={{ opacity, ...style }}>
      <path d="M20 40 Q10 40 10 30 Q10 20 22 22 Q24 10 38 12 Q48 4 58 14 Q74 10 78 26 Q90 26 90 40 Q90 50 78 50 L22 50 Q12 50 20 40 Z"
        fill={color} stroke="oklch(0.88 0.01 80)" strokeWidth="1.5"/>
    </svg>
  );
}

function Sparkle({ size=16, color='oklch(0.88 0.13 85)', style }) {
  return (
    <svg viewBox="-10 -10 20 20" width={size} height={size} style={style}>
      <path d="M0 -8 L2 -2 L8 0 L2 2 L0 8 L-2 2 L-8 0 L-2 -2 Z" fill={color}/>
    </svg>
  );
}

Object.assign(window, { Butterfly, Star, Cloud, Sparkle });
