// ── Composite Signal Score ──
// Data-driven scoring across Technical, Fundamental, Sentiment, Insider, and Contrarian dimensions.

import type { TickerEnrichment } from './enrich'
import type { InsiderResult } from '../tools/insider'
import type { PeerPositioning } from './peers'
import type { MacroContext } from './macroRegime'

export interface SignalScores {
  composite: number      // 0–100, weighted average
  technical: number      // 0–100
  fundamental: number    // 0–100
  sentiment: number      // 0–100
  insider: number        // 0–100
  contrarian: number     // 0–100, underfollowed + AI divergence + valuation + theme
  smartMoney: number     // 0–100, insider clusters + institutional flow + Congress
  government: number     // 0–100, contracts + sector + regulatory catalysts
  signals: string[]      // human-readable signal descriptions
}

// ── Technical Score (25%) ──

function scoreTechnical(e: Partial<TickerEnrichment>): { score: number; signals: string[] } {
  const signals: string[] = []
  let total = 0
  let count = 0
  const ind = e.indicators

  // RSI (0–100): 30–70 is healthy range; <30 oversold bounce potential; >70 overbought risk
  if (ind?.rsi?.value != null) {
    const rsi = ind.rsi.value
    if (rsi < 30) {
      total += 80 // oversold bounce potential
      signals.push(`RSI ${rsi} — oversold, potential bounce`)
    } else if (rsi < 45) {
      total += 60 // slightly oversold
      signals.push(`RSI ${rsi} — slightly oversold`)
    } else if (rsi <= 55) {
      total += 50 // neutral
      signals.push(`RSI ${rsi} — neutral`)
    } else if (rsi <= 70) {
      total += 40 // slightly overbought
      signals.push(`RSI ${rsi} — slightly overbought`)
    } else {
      total += 20 // overbought
      signals.push(`RSI ${rsi} — overbought, caution`)
    }
    count++
  }

  // MACD trend
  if (ind?.macd?.trend) {
    if (ind.macd.trend === 'bullish') {
      total += 70
      signals.push('MACD bullish — momentum up')
    } else {
      total += 30
      signals.push('MACD bearish — momentum down')
    }
    count++
  }

  // Bollinger position
  if (ind?.bollinger?.upper && ind?.bollinger?.lower && e.price) {
    const range = ind.bollinger.upper - ind.bollinger.lower
    if (range > 0) {
      const position = (e.price - ind.bollinger.lower) / range // 0=lower, 1=upper
      if (position < 0.25) {
        total += 70 // near support
        signals.push('Price near lower Bollinger Band — support zone')
      } else if (position > 0.75) {
        total += 30 // near resistance
        signals.push('Price near upper Bollinger Band — resistance zone')
      } else {
        total += 50 // mid-range
      }
      count++
    }
  }

  // Volume confirmation
  if (ind?.volume?.ratio != null) {
    if (ind.volume.ratio > 1.5) {
      total += 70
      signals.push(`Volume ${ind.volume.ratio}x avg — elevated interest`)
    } else if (ind.volume.ratio > 1.0) {
      total += 55
    } else if (ind.volume.ratio < 0.5) {
      total += 35
      signals.push(`Volume ${ind.volume.ratio}x avg — low participation`)
    } else {
      total += 45
    }
    count++
  }

  const score = count > 0 ? Math.round(total / count) : 50
  return { score, signals }
}

// ── Fundamental Score (25%, rebalanced) ──

function scoreFundamental(e: Partial<TickerEnrichment>): { score: number; signals: string[] } {
  const signals: string[] = []
  let total = 0
  let count = 0
  const a = e.analyst

  if (a) {
    // Analyst consensus (1=Strong Buy, 5=Strong Sell) — FLIPPED logic for underfollowed
    if (a.meanRating != null) {
      const normalized = Math.round((5 - a.meanRating) / 4 * 100)
      total += normalized
      if (a.consensus) signals.push(`Analyst consensus: ${a.consensus} (${a.count} analysts)`)
      count++
    }

    // Price target upside
    if (a.targetMean && e.price && e.price > 0) {
      const upside = (a.targetMean - e.price) / e.price
      if (upside > 0.3) {
        total += 85
        signals.push(`${Math.round(upside * 100)}% upside to mean target`)
      } else if (upside > 0.1) {
        total += 65
      } else if (upside > 0) {
        total += 50
      } else {
        total += 25
        signals.push(`Trading above mean target — limited upside`)
      }
      count++
    }

    // Analyst count — slightly reward low coverage (contrarian dimension handles the heavy boost)
    if (a.count === 0) total += 50
    else if (a.count <= 2) total += 45
    else if (a.count <= 5) total += 55
    else if (a.count <= 10) total += 50
    else total += 40
    count++
  }

  // Revenue acceleration (NEW)
  if (e.revAcceleration != null) {
    if (e.revAcceleration > 5) {
      total += 90
      signals.push(`Revenue accelerating +${e.revAcceleration.toFixed(1)}% YoY`)
    } else if (e.revAcceleration > 0) {
      total += 70
      signals.push(`Growth reaccelerating`)
    } else if (e.revAcceleration < -5) {
      total += 30
      signals.push(`Growth decelerating −${Math.abs(e.revAcceleration).toFixed(1)}%`)
    } else {
      total += 50
    }
    count++
  }

  // GAAP quality (NEW)
  if (e.gaapQualityScore != null) {
    if (e.gaapQualityScore >= 2) {
      total += 80
      signals.push(`High GAAP quality (cash > earnings)`)
    } else if (e.gaapQualityScore >= 1) {
      total += 65
      signals.push(`Good GAAP quality`)
    } else if (e.gaapQualityScore < 0) {
      total += 30
      signals.push(`Poor GAAP quality — accruals concern`)
    } else {
      total += 50
    }
    count++
  }

  // Earnings miss count (NEW)
  if (e.earningsMissCount != null) {
    if (e.earningsMissCount === 0) {
      total += 70
      signals.push(`Earnings track record clean`)
    } else if (e.earningsMissCount === 1) {
      total += 55
    } else if (e.earningsMissCount >= 3) {
      total += 25
      signals.push(`${e.earningsMissCount} recent earnings misses`)
    } else {
      total += 45
    }
    count++
  }

  // Short interest as fundamental pressure
  if (e.shortInterest?.shortPctOfFloat != null) {
    const si = e.shortInterest.shortPctOfFloat
    if (si > 20) {
      total += 75
      signals.push(`${si}% short interest — squeeze potential`)
    } else if (si > 10) {
      total += 60
      signals.push(`${si}% short interest — elevated`)
    } else if (si > 5) {
      total += 50
    } else {
      total += 40
    }
    count++
  }

  // Short interest month-over-month change
  if (e.shortInterest?.shortMoMChange != null) {
    const mom = e.shortInterest.shortMoMChange
    if (mom > 20) {
      total += 70
      signals.push(`Short interest +${mom}% MoM — shorts piling on`)
    } else if (mom < -20) {
      total += 75
      signals.push(`Short interest ${mom}% MoM — shorts covering`)
    } else if (mom < -5) {
      total += 60
    }
    count++
  }

  // Job posting acceleration
  if (e.jobAcceleration?.acceleration != null) {
    if (e.jobAcceleration.acceleration > 30) {
      total += 70
      signals.push(`🚀 Job acceleration +${Math.round(e.jobAcceleration.acceleration)}% — hiring ramp`)
      count++
    } else if (e.jobAcceleration.acceleration > 0) {
      total += 50
      signals.push(`Job growth +${Math.round(e.jobAcceleration.acceleration)}%`)
      count++
    }
  }

  // Analyst estimate revisions (leading indicator — analysts lead price 4-6 weeks)
  if (e.analystRevisions?.revisionMomentum != null) {
    const r = e.analystRevisions
    if (r.revisionsUp >= 3 && r.revisionMomentum >= 3) {
      total += 90  // 3+ upward revisions in 90d = consensus inflection
      signals.push(r.signal)
    } else if (r.revisionMomentum > 0) {
      total += 65
      signals.push(r.signal)
    } else if (r.revisionMomentum < -2) {
      total += 30
      signals.push(r.signal)
    } else {
      total += 50
    }
    count++
  }

  // Stock buyback vs. dilution (management capital-allocation signal)
  const b = e.buybackAnalysis
  if (b?.sharesChangePct != null) {
    if (b.buybackActive && b.sharesRepurchasedPct >= 5) {
      total += 80  // aggressive buyback = strong conviction
      signals.push(b.signal)
    } else if (b.buybackActive) {
      total += 65
      signals.push(b.signal)
    } else if (b.sharesChangePct > 5) {
      total += 25  // heavy dilution
      signals.push(b.signal)
    } else {
      total += 50
    }
    count++
  }

  // Dividend initiation / growth (profitability inflection / earnings confidence)
  if (e.dividendSignal?.paysDividend) {
    const d = e.dividendSignal
    if (d.dividendInitiated) {
      total += 80  // first dividend = cash-generation proof
      signals.push(d.signal)
    } else if (d.yieldChange != null && d.yieldChange > 0.3) {
      total += 70
      signals.push(d.signal)
    } else {
      total += 55
    }
    count++
  }

  // Debt maturity / refinancing risk (hidden balance-sheet risk)
  if (e.secAnalysis?.refinancingRisk && e.secAnalysis.refinancingRisk !== 'unknown') {
    if (e.secAnalysis.refinancingRisk === 'high') {
      total += 30
      signals.push('⚠️ High refinancing risk — >30% of debt due within 12mo')
    } else if (e.secAnalysis.refinancingRisk === 'moderate') {
      total += 45
    } else {
      total += 65  // low near-term maturities = deleveraging discipline
      signals.push('Low refinancing risk — debt well-laddered')
    }
    count++
  }

  // DCF intrinsic value check
  if (e.dcfValuation) {
    const d = e.dcfValuation
    if (d.verdict === 'undervalued') {
      total += 85
      signals.push(`DCF: undervalued ${d.upsidePct > 0 ? '+' : ''}${Math.round(d.upsidePct)}% to intrinsic ($${d.intrinsicPerShare.toFixed(2)})`)
    } else if (d.verdict === 'fairly_valued') {
      total += 55
      signals.push(`DCF: fairly valued (intrinsic $${d.intrinsicPerShare.toFixed(2)})`)
    } else {
      total += 20
      signals.push(`DCF: overvalued ${Math.round(d.upsidePct)}% above intrinsic`)
    }
    count++
  }

  const score = count > 0 ? Math.round(total / count) : 50
  return { score, signals }
}

// ── Sentiment Score (15%, reduced) ──

function scoreSentiment(
  e: Partial<TickerEnrichment>,
  councilBull?: boolean,
): { score: number; signals: string[] } {
  const signals: string[] = []
  let total = 0
  let count = 0

  // Headline count (signal of attention)
  if (e.headlines?.length) {
    if (e.headlines.length >= 5) {
      total += 60
      signals.push(`${e.headlines.length} recent headlines — moderate attention`)
    } else {
      total += 40
    }
    count++
  }

  // AI snapshot exists = enough data for analysis
  if (e.aiSnapshot) {
    total += 55
    count++
  }

  // Council verdict
  if (councilBull !== undefined) {
    total += councilBull ? 65 : 35
    signals.push(councilBull ? 'AI council bullish' : 'AI council bearish')
    count++
  }

  // Quiver sentiment
  if (e.quiver?.tickerData) {
    const qd = e.quiver.tickerData
    if (qd.wsbMentionsWeekly && qd.wsbMentionsWeekly > 10) {
      total += 55
      signals.push(`${qd.wsbMentionsWeekly} WSB mentions this week`)
      count++
    }
  }

  // Peer earnings momentum (sector tailwind/headwind)
  if (e.peerEarnings?.sectorMomentum != null) {
    const p = e.peerEarnings
    if (p.sectorMomentum >= 0.75) {
      total += 60  // peers beating = sector tailwind
      signals.push(p.signal)
    } else if (p.sectorMomentum <= 0.4) {
      total += 50  // peers missing = contrarian setup if this name beats
      signals.push(p.signal)
    } else {
      total += 45
    }
    count++
  }

  const score = count > 0 ? Math.round(total / count) : 50
  return { score, signals }
}

// ── Contrarian Score (20%, NEW) ──
// Hunting for non-consensus opportunities that the market has not yet priced in.
// EMERGENCY BOOST: Aggressively favor underfollowed + founder-aligned names

function scoreContrarian(
  e: Partial<TickerEnrichment>,
  councilBull?: boolean,
  insider?: Partial<InsiderResult>,
  peerPositioning?: PeerPositioning | null,
  macro?: MacroContext | null,
): { score: number; signals: string[] } {
  const signals: string[] = []
  let total = 0
  let count = 0

  // AI vs. Wall Street divergence (HIGHEST conviction contrarian signal)
  if (councilBull !== undefined && e.analyst) {
    if (councilBull && e.analyst.count <= 2) {
      total += 100  // BOOSTED from 80: underfollowed + AI bullish = highest conviction
      signals.push(`🎯 AI bullish, virtually no coverage (${e.analyst.count || 0} analysts)`)
    } else if (councilBull && e.analyst.count <= 5) {
      total += 90  // BOOSTED from 60: AI bullish on under-followed
      signals.push(`AI bullish, underfollowed (${e.analyst.count} analysts)`)
    } else if (councilBull && (e.analyst.consensus === 'sell' || e.analyst.consensus === 'underperform')) {
      total += 95  // BOOSTED: AI bullish vs Street bearish = massive divergence
      signals.push(`🔥 Massive divergence: AI bullish, Street says ${e.analyst.consensus}`)
    } else if (councilBull) {
      total += 55  // REDUCED from 60: well-covered bullish is less contrarian
    } else if (!councilBull && e.analyst.count <= 2) {
      total += 65  // New: contrarian view on underfollowed (could be hidden gem)
      signals.push(`Underfollowed but bearish from AI (potential setup)`)
    } else {
      total += 35
    }
    count++
  } else if (e.analyst && e.analyst.count <= 2) {
    // No council data, underfollowed — neutral until fundamentals confirm
    total += 50
    signals.push(`Underfollowed (${e.analyst.count} analyst(s)) — unverified`)
    count++
  }

  // Underfollowed + volume signal — require both to score highly
  if (e.analyst && e.indicators?.volume) {
    if (e.analyst.count <= 1 && e.indicators.volume.ratio > 1.2) {
      total += 75  // discovery signal, not automatic Tier 1
      signals.push(`💎 Low coverage + ${e.indicators.volume.ratio.toFixed(1)}x volume — potential discovery`)
    } else if (e.analyst.count === 0) {
      total += 55  // zero coverage alone is not a signal
      signals.push(`Zero analyst coverage`)
    } else if (e.analyst.count <= 2 && e.indicators.volume.ratio > 1.5) {
      total += 85
      signals.push(`Underfollowed + unusual volume accumulation`)
    }
    count++
  }

  // Peer valuation discount (bottom quintile = potential cheap growth)
  if (peerPositioning) {
    if (peerPositioning.percentileRank < 15) {
      total += 95  // BOOSTED: extreme discount vs peers
      signals.push(`⚡ Extreme bargain: ${peerPositioning.percentileRank}th percentile vs peers`)
    } else if (peerPositioning.percentileRank < 30) {
      total += 85  // BOOSTED: significant discount
      signals.push(`Significantly undervalued (${peerPositioning.percentileRank}th percentile)`)
    } else if (peerPositioning.percentileRank < 40) {
      total += 70
      signals.push(`Undervalued vs. peers (${peerPositioning.percentileRank}th percentile)`)
    } else if (peerPositioning.percentileRank > 75) {
      total += 15  // PENALIZED: expensive vs peers
      signals.push(`Premium valuation (${peerPositioning.percentileRank}th percentile) - risky`)
    } else {
      total += 50
    }
    count++
  }

  // Theme tailwind (structural demand secular tailwind, macro-aware)
  if (e.tags && e.tags.length > 0) {
    const defenseTag = e.tags.includes('Defense & GovTech')
    const bullThemes = ['Defense & GovTech', 'AI & Data Infrastructure']
    const hasTheme = e.tags.some((t: string) => bullThemes.includes(t))
    if (hasTheme) {
      let tailwindScore = 75
      let tailwindNote = e.tags.join(', ')
      if (defenseTag && macro?.defense_spend_trend === 'rising') {
        tailwindScore = 90
        tailwindNote = `Defense tailwind: global spend rising + ${e.tags.join(', ')}`
      } else if (defenseTag && macro?.defense_spend_trend === 'falling') {
        tailwindScore = 45
        tailwindNote = `⚠️ Defense spend contracting — macro headwind for ${e.tags.join(', ')}`
      }
      total += tailwindScore
      signals.push(`🎯 Structural tailwind: ${tailwindNote}`)
    } else if (macro?.regime_flags.includes('global_slowdown')) {
      total += 35  // penalize cyclical/consumer plays in a global slowdown
      signals.push(`⚠️ Global slowdown regime — macro headwind for ${e.tags[0]} exposure`)
    }
    count++
  }

  // Founder alignment (insider skin-in-game) — BOOSTED
  if (e.insiderPct != null) {
    if (e.insiderPct > 15) {
      total += 95
      signals.push(`👑 Heavy founder ownership (${e.insiderPct.toFixed(1)}%) — ultimate conviction`)
    } else if (e.insiderPct > 10) {
      total += 90  // BOOSTED
      signals.push(`Founder-led: insiders own ${e.insiderPct.toFixed(1)}%`)
    } else if (e.insiderPct > 5) {
      total += 80  // BOOSTED from 75
      signals.push(`CEO owns ${e.insiderPct.toFixed(1)}% — strong alignment`)
    } else if (e.insiderPct > 2) {
      total += 60
      signals.push(`Insider ownership ${e.insiderPct.toFixed(1)}%`)
    }
    count++
  }

  // Insider cluster buying — BOOSTED
  if (insider?.clusterScore && insider.clusterScore >= 7) {
    total += 90  // BOOSTED from 80
    signals.push(`🔥 Insider cluster buying (${insider.clusterScore}/10) — smart money loading`)
    count++
  } else if (insider?.clusterScore && insider.clusterScore >= 4) {
    total += 60
    signals.push(`Moderate insider activity (${insider.clusterScore}/10)`)
    count++
  }

  // Revenue acceleration (new signal integration)
  if (e.revAcceleration != null && e.revAcceleration > 5) {
    total += 80
    signals.push(`📈 Revenue accelerating +${e.revAcceleration.toFixed(1)}% — inflection point`)
    count++
  }

  // Patent velocity (R&D acceleration = 12-24mo lead indicator)
  if (e.patentAcceleration?.acceleration != null && e.patentAcceleration.acceleration > 20) {
    total += 85  // Strong patent acceleration = R&D pipeline building
    signals.push(`🔬 Patent acceleration +${Math.round(e.patentAcceleration.acceleration)}% YoY — R&D inflection`)
    count++
  } else if (e.patentAcceleration?.acceleration != null && e.patentAcceleration.acceleration > 0) {
    total += 60
    signals.push(`Patent filing growth (R&D up ${Math.round(e.patentAcceleration.acceleration)}%)`)
    count++
  }

  // GAAP quality (new signal integration)
  if (e.gaapQualityScore != null && e.gaapQualityScore >= 2) {
    total += 65
    signals.push(`High-quality earnings (operating cash flow >> net income)`)
    count++
  }

  // SEC management changes (strategy inflection)
  if (e.secAnalysis?.managementChanges && e.secAnalysis.managementChanges.length > 0) {
    total += 30
    signals.push(`New management: ${e.secAnalysis.managementChanges.map(m => m.role).join(', ')} — strategy shift`)
    count++
  }

  // Material contracts (new revenue source)
  if (e.secAnalysis?.materialContracts && e.secAnalysis.materialContracts.length > 0) {
    total += 25
    signals.push(`📜 Material contracts filed (new revenue catalyst)`)
    count++
  }

  // Transcript sentiment — improving tone but stock down = contrarian signal
  if (e.transcriptSentiment?.sentimentScore != null && e.changePct != null) {
    if (e.transcriptSentiment.sentimentScore > 30 && e.changePct < 0) {
      total += 60
      signals.push(`🎯 Bullish tone (+${Math.round(e.transcriptSentiment.sentimentScore)}) but stock down — contrarian`)
      count++
    } else if (e.transcriptSentiment.sentimentScore > 30) {
      total += 40
      signals.push(`Management tone improving`)
      count++
    }
  }

  // Short seller reports (contrarian signal if fundamentals improving)
  if (e.shortReports && e.shortReports.length > 0 && insider?.clusterScore && insider.clusterScore >= 7 && e.patentAcceleration?.acceleration && e.patentAcceleration.acceleration > 0) {
    // Short report exists BUT insiders buying + patents growing = shorts are wrong
    total += 50
    signals.push(`🔄 Short reports exist BUT insiders buying + patents accelerating — thesis contradicted`)
    count++
  } else if (e.shortReports && e.shortReports.length > 0) {
    // Short report exists (neutral signal — just flag it)
    signals.push(`Short seller report published (${e.shortReports[0]?.source || 'Unknown'})`)
  }

  // Short squeeze setup — binary catalyst, strongest when insiders are buying into it
  if (e.squeezeAnalysis?.shortSqueezePct != null && e.squeezeAnalysis.shortSqueezePct > 25) {
    if (insider?.clusterScore && insider.clusterScore >= 7) {
      total += 95  // squeeze + insider cluster = massive asymmetry (insiders front-run)
      signals.push(`🚀 Squeeze setup (${e.squeezeAnalysis.shortSqueezePct}% of float short) + insider cluster buying`)
    } else {
      total += 70
      signals.push(e.squeezeAnalysis.signal)
    }
    count++
  }

  // Reddit mention velocity — retail discovery often leads institutional repricing
  if (e.socialSentiment?.mentionVelocity != null) {
    const s = e.socialSentiment
    const underfollowed = (e.analyst?.count ?? 99) <= 2
    if (s.mentionVelocity >= 5 && underfollowed) {
      total += 90  // discovery surge on an underfollowed name
      signals.push(`🔥 Discovery signal: Reddit ${s.mentionVelocity}x velocity on underfollowed name`)
    } else if (s.mentionVelocity >= 3) {
      total += 65
      signals.push(s.signal)
    } else {
      total += 45
    }
    count++
  }

  // Options positioning — high IV / bullish call skew on a beaten-down name = pre-catalyst
  if (e.optionsSignal?.impliedVol != null || e.optionsSignal?.putCallRatio != null) {
    const o = e.optionsSignal
    const beatenDown = (e.changePct ?? 0) < 0
    if (o.putCallRatio != null && o.putCallRatio < 0.6) {
      total += 70  // call-heavy skew = bullish positioning
      signals.push(o.signal)
    } else if (o.impliedVol != null && o.impliedVol > 80 && beatenDown) {
      total += 65  // elevated IV on a down name = market pricing a catalyst
      signals.push(`⚡ Elevated IV (${o.impliedVol}%) on a down name — pre-catalyst setup`)
    } else {
      total += 48
    }
    count++
  }

  // Implied growth divergence: price assumes X% but company is growing at Y%
  if (e.dcfValuation?.impliedGrowth != null && e.revAcceleration != null) {
    const implied = e.dcfValuation.impliedGrowth * 100
    const actual = e.revAcceleration
    const divergence = actual - implied
    if (divergence > 15) {
      total += 90
      signals.push(`🎯 Priced for ${implied.toFixed(1)}% growth, delivering ${actual.toFixed(1)}% — major discount`)
      count++
    } else if (divergence > 8) {
      total += 70
      signals.push(`Growing faster (${actual.toFixed(1)}%) than market expects (${implied.toFixed(1)}%)`)
      count++
    } else if (divergence < -15) {
      total += 20
      signals.push(`⚠️ Priced for ${implied.toFixed(1)}% growth but only delivering ${actual.toFixed(1)}%`)
      count++
    }
  }

  const score = count > 0 ? Math.round(total / count) : 50
  return { score, signals }
}

// ── Insider Score (20%) ──

function scoreInsider(i: Partial<InsiderResult>): { score: number; signals: string[] } {
  const signals: string[] = []
  let total = 0
  let count = 0

  // Cluster score
  if (i.clusterScore != null) {
    total += i.clusterScore * 10 // 0-100
    if (i.clusterScore >= 7) signals.push(`Insider cluster: ${i.clusterScore}/10`)
    count++
  }

  // Net sentiment
  if (i.netInsiderSentiment) {
    if (i.netInsiderSentiment === 'bullish') {
      total += 75
      signals.push('Insider buying exceeds selling')
    } else if (i.netInsiderSentiment === 'bearish') {
      total += 25
      signals.push('Insider selling predominant')
    } else {
      total += 50
    }
    count++
  }

  // Unique buying insiders
  if (i.buyingInsiders?.length) {
    if (i.buyingInsiders.length >= 3) {
      total += 85
      signals.push(`${i.buyingInsiders.length} insiders buying — cluster confirmed`)
    } else if (i.buyingInsiders.length >= 1) {
      total += 60
    }
    count++
  }

  // Enhanced CEO/founder signals
  if (i.ceoPersonalBuyingScore && i.ceoPersonalBuyingScore === 95) {
    total += 95 // CEO buying = ultimate conviction (replaces cluster score)
    signals.push(`👑 CEO personal buy — highest conviction signal`)
    count++
  } else if (i.ceoPersonalBuyingScore && i.ceoPersonalBuyingScore > 0) {
    total += i.ceoPersonalBuyingScore
    count++
  }

  // Founder alignment
  if (i.founderAlignment) {
    total += 95
    signals.push(`Founder/Director buying repeatedly — alignment confirmed`)
    count++
  }

  // Form 3 — newly registered insider (founder/exec confirmation)
  if (i.form3Insiders && i.form3Insiders.length > 0) {
    const execForm3 = i.form3Insiders.some(s => /ceo|chief|founder|director|president/i.test(s))
    if (execForm3) {
      total += 80  // new exec/founder entering the cap table = strong signal
      signals.push(`👤 New insider registered (Form 3): ${i.form3Insiders[0]}`)
    } else {
      total += 60
      signals.push(`${i.form3Insiders.length} new insider Form 3 filing(s)`)
    }
    count++
  }

  // Form 5 — late-disclosed annual transaction volume (hidden accumulation)
  if (i.form5UnreportedVolume && i.form5UnreportedVolume > 1_000_000) {
    total += 55
    signals.push(`Form 5 discloses ${i.form5UnreportedVolume.toLocaleString()} late-reported shares`)
    count++
  }

  const score = count > 0 ? Math.round(total / count) : 50
  return { score, signals }
}

// ── Smart Money Score (0–100) ──
// Measures whether "smart money" (insiders, institutions, Congress) is betting on this stock.
// Composed of: insider cluster activity (40%), institutional flow direction (30%),
// insider buy/sell volume ratio (20%), Quiver congressional trades (10%).

function scoreSmartMoney(
  enrichment: Partial<TickerEnrichment>,
  insider?: Partial<InsiderResult>,
): { score: number; signals: string[] } {
  const signals: string[] = []
  let total = 0
  let count = 0

  // 1. Insider cluster score (0–10 → 0–100) — weight 40%
  const clusterScore = insider?.clusterScore ?? 0
  if (clusterScore > 0) {
    const clusterPct = Math.min(clusterScore * 10, 100) // 0–10 → 0–100
    total += clusterPct * 0.40
    count += 0.40
    if (clusterScore >= 7) {
      signals.push(`Insider cluster buying (${clusterScore}/10) — strong conviction`)
    } else if (clusterScore >= 4) {
      signals.push(`Insider cluster forming (${clusterScore}/10) — monitoring`)
    } else if (clusterScore > 0) {
      signals.push(`Light insider accumulation (${clusterScore}/10)`)
    }
  }

  // 2. Insider buy/sell volume ratio — weight 20%
  const buyVol = insider?.buyVolume ?? 0
  const sellVol = insider?.sellVolume ?? 0
  if (buyVol > 0 || sellVol > 0) {
    const totalVol = buyVol + sellVol
    if (totalVol > 0) {
      const buyRatio = buyVol / totalVol // 0–1
      const ratioScore = Math.round(buyRatio * 100)
      total += ratioScore * 0.20
      count += 0.20
      if (buyRatio > 0.8) {
        signals.push(`Heavy insider buying — ${Math.round(buyRatio * 100)}% of volume is buys`)
      } else if (buyRatio > 0.5) {
        signals.push(`Insider buying outpacing sells (${Math.round(buyRatio * 100)}% buys)`)
      } else if (buyRatio < 0.3) {
        signals.push(`Insider selling dominant (${Math.round((1 - buyRatio) * 100)}% sells)`)
      }
    }
  }

  // 3. Institutional flow direction — weight 30%
  // Compute from institutional holdings: if top holders are increasing = accumulation
  const instHoldings = enrichment.institutional ?? []
  const instOwnership = enrichment.insiderPct ?? 0
  if (instHoldings.length > 0) {
    const avgPctChange = instHoldings.reduce((sum: number, h: any) => sum + (h.pctChange || 0), 0) / instHoldings.length
    if (avgPctChange > 0.05) {
      total += 85 * 0.30
      signals.push(`Institutions accumulating (+${(avgPctChange * 100).toFixed(0)}% avg position change)`)
    } else if (avgPctChange < -0.05) {
      total += 20 * 0.30
      signals.push('Institutions distributing — 13F flow negative')
    } else {
      total += 50 * 0.30 // flat
    }
    count += 0.30
  } else if (instOwnership > 0) {
    // Fallback: score based on ownership level
    if (instOwnership > 70) {
      total += 75 * 0.30
      signals.push(`High institutional ownership (${instOwnership}%) — widely held`)
    } else if (instOwnership > 40) {
      total += 60 * 0.30
      signals.push(`Moderate institutional ownership (${instOwnership}%)`)
    } else {
      total += 45 * 0.30
      signals.push(`Low institutional ownership (${instOwnership}%) — underfollowed`)
    }
    count += 0.30
  }

  // 4. Congress trades (Quiver) — weight 10%
  const quiver = enrichment.quiver as any
  const congressTrades = quiver?.congressTrades
  if (congressTrades && congressTrades.length > 0) {
    const recentBuys = congressTrades.filter((t: any) => {
      const action = (t.action || t.transaction || '').toLowerCase()
      return action.includes('buy') || action.includes('purchase')
    }).length
    const recentSells = congressTrades.filter((t: any) => {
      const action = (t.action || t.transaction || '').toLowerCase()
      return action.includes('sell') || action.includes('sale')
    }).length
    if (recentBuys > recentSells) {
      total += 80 * 0.10
      signals.push(`Congress buying — ${recentBuys} recent purchases vs ${recentSells} sales`)
    } else if (recentSells > recentBuys) {
      total += 15 * 0.10
      signals.push(`Congress selling — ${recentSells} recent sales`)
    } else {
      total += 50 * 0.10
    }
    count += 0.10
  }

  // Normalize score to 0–100 based on weighted components
  const score = count > 0 ? Math.round(total / count) : 0
  return { score, signals }
}

// ── Government Score (0–100) ──
// Measures government exposure: contract awards, regulatory catalysts, sector alignment.
// Composed of: Quiver/SAM.gov contracts (50%), sector/industry alignment (25%),
// regulatory catalyst presence (25%).

function scoreGovernment(
  enrichment: Partial<TickerEnrichment>,
): { score: number; signals: string[] } {
  const signals: string[] = []
  let total = 0
  let count = 0

  // 1. Government contracts (Quiver) — weight 50%
  const quiver = enrichment.quiver as any
  const govContracts = quiver?.governmentContracts ?? quiver?.contracts
  if (govContracts && govContracts.length > 0) {
    const recentContracts = govContracts.filter((c: any) => {
      const date = c.date || c.awardDate || ''
      return true // count all; recency filtering is noisy without consistent date formats
    })
    const contractCount = recentContracts.length
    if (contractCount >= 5) {
      total += 95 * 0.50
      signals.push(`${contractCount}+ active government contracts`)
    } else if (contractCount >= 2) {
      total += 75 * 0.50
      signals.push(`${contractCount} government contracts active`)
    } else if (contractCount >= 1) {
      total += 55 * 0.50
      signals.push('Has government contracts')
    }
    count += 0.50
  }

  // 2. Sector / industry alignment — weight 25%
  const sector = enrichment.sector ?? (enrichment as any)?.industry ?? ''
  const sectorLower = sector.toLowerCase()
  const govSectors: Record<string, number> = {
    'defense': 95,
    'aerospace': 90,
    'government': 85,
    'military': 95,
    'space': 80,
    'nuclear': 75,
    'energy': 65,
    'healthcare': 60,
    'cybersecurity': 85,
    'infrastructure': 70,
  }
  let sectorScore = 20 // baseline — not every company is gov-adjacent
  let matchedSector = ''
  for (const [key, score] of Object.entries(govSectors)) {
    if (sectorLower.includes(key)) {
      sectorScore = Math.max(sectorScore, score)
      matchedSector = key
    }
  }
  total += sectorScore * 0.25
  count += 0.25
  if (matchedSector) {
    signals.push(`Sector alignment: ${matchedSector} — government-adjacent industry`)
  }

  // 3. Regulatory catalyst presence — weight 25%
  const catalysts = enrichment.catalysts ?? []
  const headlines = enrichment.headlines ?? []
  const allText = [
    ...catalysts.map((c: any) => `${c.label} ${c.detail}`),
    ...headlines.map((h: any) => `${h.headline}`),
  ].join(' ').toLowerCase()

  const regulatoryTerms = ['fda', 'fcc', 'nrc', 'epa', 'doe', 'dod', 'darpa', 'nasa',
    'ndaa', 'approval', 'clearance', 'authorization', 'license', 'certification',
    'contract award', 'grant', 'appropriation', 'rfp', 'solicitation']
  let regHits = 0
  for (const term of regulatoryTerms) {
    if (allText.includes(term)) regHits++
  }

  if (regHits >= 5) {
    total += 85 * 0.25
    signals.push(`Strong regulatory catalyst density (${regHits} signals)`)
  } else if (regHits >= 2) {
    total += 60 * 0.25
    signals.push(`Regulatory catalysts present (${regHits} signals)`)
  } else {
    total += 15 * 0.25
  }
  count += 0.25

  const score = count > 0 ? Math.round(total / count) : 0
  return { score, signals }
}

// ── Composite ──

export function computeSignals(
  enrichment: Partial<TickerEnrichment>,
  insider: Partial<InsiderResult>,
  councilBull?: boolean,
  peerPositioning?: PeerPositioning | null,
  macro?: MacroContext | null,
): SignalScores {
  const tech = scoreTechnical(enrichment)
  const fund = scoreFundamental(enrichment)
  const sent = scoreSentiment(enrichment, councilBull)
  const ins = scoreInsider(insider)
  const contrarian = scoreContrarian(enrichment, councilBull, insider, peerPositioning, macro)
  const smartMoney = scoreSmartMoney(enrichment, insider)
  const gov = scoreGovernment(enrichment)

  // Weights: tech 18% + fundamental 22% + sentiment 14% + insider 18% + contrarian 18% + smartMoney 5% + gov 5%
  const composite = Math.round(
    tech.score * 0.18 +
    fund.score * 0.22 +
    sent.score * 0.14 +
    ins.score * 0.18 +
    contrarian.score * 0.18 +
    smartMoney.score * 0.05 +
    gov.score * 0.05
  )

  // Combine unique signals (limit to top 10 most important)
  const allSignals = [
    ...(composite >= 75 ? [`Composite score ${composite}/100 — strong signal`] : []),
    ...(composite >= 60 && composite < 75 ? [`Composite score ${composite}/100 — moderate signal`] : []),
    ...(composite < 60 ? [`Composite score ${composite}/100 — weak signal`] : []),
    ...contrarian.signals,  // Prioritize contrarian signals first
    ...tech.signals,
    ...fund.signals,
    ...sent.signals,
    ...ins.signals,
  ].slice(0, 10)

  console.log(`[signals] composite=${composite} tech=${tech.score} fund=${fund.score} sent=${sent.score} insider=${ins.score} contrarian=${contrarian.score}`)

  return {
    composite,
    technical: tech.score,
    fundamental: fund.score,
    sentiment: sent.score,
    insider: ins.score,
    contrarian: contrarian.score,
    smartMoney: smartMoney.score,
    government: gov.score,
    signals: allSignals,
  }
}
