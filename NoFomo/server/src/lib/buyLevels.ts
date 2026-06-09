// ── Buy-zone levels ──
// Volatility-aware entry levels derived from price + recent support + beta.
// aggressive = shallow dip, base = near support, conservative = deeper pullback.

export interface BuyLevels {
  aggressive: number
  base: number
  conservative: number
}

export function computeBuyLevels(
  price: number,
  priceHistory: number[],
  beta: number | null,
): BuyLevels | null {
  if (!price || price <= 0) return null

  // Volatility proxy: higher beta → wider zones. Clamp to a sane band.
  const vol = beta != null && beta > 0 ? Math.min(0.45, Math.max(0.06, 0.09 * beta)) : 0.10

  // Recent support from the trailing window (last ~40 closes).
  let support = price
  if (priceHistory && priceHistory.length >= 20) {
    support = Math.min(...priceHistory.slice(-40))
  }

  const round = (n: number) => Math.round(n * 100) / 100
  const aggressive = round(price * (1 - vol * 0.4))                 // small pullback
  const base = round(Math.max(support, price * (1 - vol)))          // near support
  const conservative = round(Math.min(base, price * (1 - vol * 1.8))) // deep value

  return { aggressive, base, conservative }
}
