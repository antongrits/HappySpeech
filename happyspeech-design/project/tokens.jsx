// HappySpeech design tokens — shared between kid / parent / specialist contours.
// All colors in oklch; pastel but saturated. Kid layer is warmer; Parent layer
// is cooler + cleaner; Specialist layer is neutral + data-dense.

const HS = {
  // Brand
  brand: {
    primary:   'oklch(0.72 0.17 35)',   // coral-apricot — mascot wings, main CTA
    primaryHi: 'oklch(0.82 0.14 45)',
    primaryLo: 'oklch(0.58 0.19 32)',
    mint:      'oklch(0.82 0.11 165)',  // success, progress
    sky:       'oklch(0.80 0.10 230)',  // info, links
    lilac:     'oklch(0.78 0.11 305)',  // magic / AR accent
    butter:    'oklch(0.90 0.12 90)',   // rewards, streaks
    rose:      'oklch(0.82 0.10 15)',   // warmth on cards
  },

  // Kid surfaces — warm cream world
  kid: {
    bg:        'oklch(0.975 0.012 80)',   // cream
    bgDeep:    'oklch(0.955 0.020 75)',
    surface:   '#ffffff',
    surfaceAlt:'oklch(0.97 0.014 70)',
    ink:       'oklch(0.22 0.025 60)',   // warm near-black
    inkMuted:  'oklch(0.50 0.020 60)',
    inkSoft:   'oklch(0.65 0.015 60)',
    line:      'oklch(0.91 0.010 70)',
    shadow:    '0 2px 0 rgba(58,40,28,0.06), 0 8px 24px rgba(58,40,28,0.08)',
    shadowLg:  '0 4px 0 rgba(58,40,28,0.06), 0 20px 40px rgba(58,40,28,0.10)',
  },

  // Parent surfaces — cool, neutral, focused
  parent: {
    bg:        'oklch(0.985 0.004 250)',
    bgDeep:    'oklch(0.965 0.006 250)',
    surface:   '#ffffff',
    ink:       'oklch(0.22 0.015 250)',
    inkMuted:  'oklch(0.50 0.012 250)',
    inkSoft:   'oklch(0.68 0.010 250)',
    line:      'oklch(0.92 0.006 250)',
    lineStrong:'oklch(0.86 0.008 250)',
    accent:    'oklch(0.62 0.14 240)',   // cool primary for parent
    shadow:    '0 1px 2px rgba(16,24,40,0.05), 0 1px 3px rgba(16,24,40,0.04)',
  },

  // Specialist — neutral cool
  spec: {
    bg:        'oklch(0.98 0.003 250)',
    surface:   '#ffffff',
    panel:     'oklch(0.96 0.004 250)',
    ink:       'oklch(0.18 0.010 250)',
    inkMuted:  'oklch(0.48 0.008 250)',
    line:      'oklch(0.90 0.005 250)',
    grid:      'oklch(0.94 0.004 250)',
    accent:    'oklch(0.55 0.13 250)',
    waveform:  'oklch(0.55 0.14 200)',
    target:    'oklch(0.72 0.17 140)',
  },

  // Semantic
  sem: {
    success:   'oklch(0.68 0.15 150)',
    successBg: 'oklch(0.95 0.05 150)',
    error:     'oklch(0.65 0.18 25)',
    errorBg:   'oklch(0.96 0.04 25)',
    warning:   'oklch(0.78 0.15 80)',
    warningBg: 'oklch(0.96 0.06 85)',
    info:      'oklch(0.65 0.12 230)',
    infoBg:    'oklch(0.96 0.03 230)',
  },

  // Sound-group palette — each speech sound family gets a hue
  soundFamily: {
    whistling:  { // свистящие С З Ц
      name: 'Свистящие',
      icon: '◠',
      hue:  'oklch(0.78 0.12 200)',   // teal
      bg:   'oklch(0.95 0.04 200)',
    },
    hissing: { // шипящие Ш Ж Ч Щ
      name: 'Шипящие',
      icon: '◑',
      hue:  'oklch(0.76 0.13 305)',   // lilac
      bg:   'oklch(0.95 0.04 305)',
    },
    sonorant: { // сонорные Л Р
      name: 'Сонорные',
      icon: '◐',
      hue:  'oklch(0.72 0.16 35)',    // coral
      bg:   'oklch(0.96 0.04 35)',
    },
    velar: { // заднеязычные К Г Х
      name: 'Заднеязычные',
      icon: '◒',
      hue:  'oklch(0.76 0.13 135)',   // green
      bg:   'oklch(0.95 0.05 135)',
    },
    vowels: {
      name: 'Гласные',
      icon: '○',
      hue:  'oklch(0.82 0.13 85)',    // butter
      bg:   'oklch(0.96 0.05 85)',
    },
  },

  // Radii & spacing
  r:  { xs: 8, sm: 12, md: 18, lg: 24, xl: 32, full: 9999 },
  sp: { 1: 4, 2: 8, 3: 12, 4: 16, 5: 20, 6: 24, 8: 32, 10: 40, 12: 48, 16: 64 },

  // Type — SF as system
  font: {
    display: '"SF Pro Rounded", -apple-system, "Inter Rounded", system-ui',
    text:    '-apple-system, "SF Pro Text", "Inter", system-ui',
    mono:    '"SF Mono", "JetBrains Mono", ui-monospace, monospace',
  },

  // Motion
  ease: {
    outQuick: 'cubic-bezier(0.16, 1, 0.3, 1)',
    spring:   'cubic-bezier(0.34, 1.56, 0.64, 1)',
    bounce:   'cubic-bezier(0.68, -0.55, 0.27, 1.55)',
  },
};

window.HS = HS;
