export interface ConfidenceResult {
  score: number
  label: 'high' | 'medium' | 'low'
  factors: string[]
}

export function computeConfidence(dossierText: string, enrichment: any): ConfidenceResult {
  let score = 50 // baseline: model-generated reasoning
  const factors: string[] = ['baseline model reasoning']

  // +10 if SEC filing data present
  if (/\b(10-K|8-K|10-Q)\b/i.test(dossierText)) {
    score += 10
    factors.push('SEC filing data present')
  }

  // +10 if insider trading data present
  const insiderTransactions =
    enrichment?.insider?.transactions ??
    enrichment?.insiderTotalBuys ??
    enrichment?.insider?.totalBuys
  const hasInsiderData =
    insiderTransactions > 0 ||
    (enrichment?.insider && (enrichment.insider.totalBuys > 0 || enrichment.insider.totalSells > 0))
  if (hasInsiderData) {
    score += 10
    factors.push('insider trading data present')
  }

  // +10 if analyst data present
  const analystCount =
    enrichment?.analystCount ??
    enrichment?.analyst?.count ??
    enrichment?.analyst?.analystCount
  if (analystCount > 0) {
    score += 10
    factors.push(`analyst coverage (${analystCount} analysts)`)
  }

  // +10 if price data fresh (within last 7 days)
  const price = enrichment?.price ?? 0
  const priceDate = enrichment?.priceDate ?? enrichment?.lastUpdated ?? enrichment?.price_date
  if (price > 0) {
    let fresh = false
    if (priceDate) {
      const date = new Date(priceDate)
      const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
      fresh = date >= sevenDaysAgo
    } else {
      // If price exists but no date, assume it was fetched now (live data)
      fresh = true
    }
    if (fresh) {
      score += 10
      factors.push('fresh price data')
    }
  }

  // +10 if Brave/web sources found (2+ URLs in dossier)
  const urlMatches = dossierText.match(/https?:\/\/[^\s\)\]"'<>]{15,}/g) ?? []
  const uniqueUrls = [...new Set(urlMatches)]
  if (uniqueUrls.length >= 2) {
    score += 10
    factors.push(`web sources cited (${uniqueUrls.length} URLs)`)
  }

  // −20 if enrichment failed (no price, no analyst data, no insider data)
  const hasPrice = (enrichment?.price ?? 0) > 0
  const hasAnalysts = (analystCount ?? 0) > 0
  const hasInsider =
    (enrichment?.insider?.totalBuys ?? 0) > 0 ||
    (enrichment?.insider?.totalSells ?? 0) > 0 ||
    (enrichment?.insiderTotalBuys ?? 0) > 0
  if (!hasPrice && !hasAnalysts && !hasInsider) {
    score -= 20
    factors.push('enrichment failed: no price, analyst, or insider data')
  }

  // Cap
  score = Math.max(0, Math.min(100, score))

  // high ≥ 90, medium 50–89, low < 50
  const label: 'high' | 'medium' | 'low' =
    score >= 90 ? 'high' :
    score >= 50 ? 'medium' :
    'low'

  return { score, label, factors }
}
