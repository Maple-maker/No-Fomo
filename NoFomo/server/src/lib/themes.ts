// ── Theme tagging by ticker ──
// Maps a ticker to structural-tailwind themes. Used for the contrarian "theme" signal.
// Static map keyed to the discovery universe; unknown tickers return [].

const TICKER_THEMES: Record<string, string[]> = {
  // Defense / autonomy
  PLTR: ['Defense & GovTech', 'AI & Data Infrastructure'], KTOS: ['Defense & GovTech'],
  AVAV: ['Defense & GovTech'], LDOS: ['Defense & GovTech'], HWM: ['Defense & GovTech'],
  BWXT: ['Defense & GovTech', 'Energy'], GD: ['Defense & GovTech'], LHX: ['Defense & GovTech'],
  NOC: ['Defense & GovTech'], LMT: ['Defense & GovTech'], RTX: ['Defense & GovTech'],
  // Semis / AI infra
  NVDA: ['AI & Data Infrastructure', 'Semiconductors'], AMD: ['AI & Data Infrastructure', 'Semiconductors'],
  AVGO: ['AI & Data Infrastructure', 'Semiconductors'], MRVL: ['AI & Data Infrastructure', 'Semiconductors'],
  SMCI: ['AI & Data Infrastructure'], MU: ['Semiconductors'], ANET: ['AI & Data Infrastructure'],
  COHR: ['AI & Data Infrastructure'], VRT: ['AI & Data Infrastructure', 'Energy'], ALAB: ['AI & Data Infrastructure', 'Semiconductors'],
  // Energy / grid / nuclear
  CEG: ['Energy'], VST: ['Energy'], TLN: ['Energy'], SMR: ['Energy'], OKLO: ['Energy'], GEV: ['Energy'], ETN: ['Energy'],
  // AI / data / software
  SOUN: ['AI & Data Infrastructure'], BBAI: ['AI & Data Infrastructure', 'Defense & GovTech'], AI: ['AI & Data Infrastructure'],
  RDDT: ['AI & Data Infrastructure'], DDOG: ['AI & Data Infrastructure'], SNOW: ['AI & Data Infrastructure'],
  NET: ['AI & Data Infrastructure'], CFLT: ['AI & Data Infrastructure'],
  // Space
  RKLB: ['Space'], ASTS: ['Space'], GSAT: ['Space'], LUNR: ['Space'], RDW: ['Space'],
  // BTC / fintech
  MSTR: ['Crypto'], COIN: ['Crypto'], HOOD: ['Fintech', 'Crypto'], SOFI: ['Fintech'], CLSK: ['Crypto'],
  // Biotech
  CRVO: ['Biotech'], RXRX: ['Biotech', 'AI & Data Infrastructure'], ABCL: ['Biotech'],
}

export function tagThemes(ticker: string): string[] {
  return TICKER_THEMES[ticker?.toUpperCase()?.trim()] ?? []
}
