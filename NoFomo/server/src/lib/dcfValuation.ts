export interface DCFResult {
  intrinsicPerShare: number
  price: number
  upsidePct: number
  verdict: 'undervalued' | 'fairly_valued' | 'overvalued'
  buyBelow: number
  impliedGrowth: number | null
  pvFcf: number
  pvTerminal: number
  equityValue: number
  asymmetryRatio: number
  bearValue: number
  baseValue: number
  bullValue: number
  growthUsed: number
}

export interface DCFInputs {
  fcf: number
  cash: number
  debt: number
  shares: number
  price: number
  growth: number
  discount?: number
  terminal?: number
  years?: number
  marginOfSafety?: number
}

function intrinsic(
  fcf: number, cash: number, debt: number, shares: number,
  growth: number, discount: number, terminal: number, years: number,
): { perShare: number; pvFcf: number; pvTerminal: number; equity: number } {
  let pvFcf = 0
  for (let t = 1; t <= years; t++) {
    pvFcf += (fcf * Math.pow(1 + growth, t)) / Math.pow(1 + discount, t)
  }
  const fcfFinal = fcf * Math.pow(1 + growth, years)
  const terminalValue = (fcfFinal * (1 + terminal)) / (discount - terminal)
  const pvTerminal = terminalValue / Math.pow(1 + discount, years)
  const equity = pvFcf + pvTerminal + cash - debt
  return { perShare: equity / shares, pvFcf, pvTerminal, equity }
}

function reverseGrowth(
  fcf: number, cash: number, debt: number, shares: number,
  price: number, discount: number, terminal: number, years: number,
): number | null {
  const valueAt = (g: number) =>
    intrinsic(fcf, cash, debt, shares, g, discount, terminal, years).perShare
  let lo = -0.5
  let hi = 1.5
  if (valueAt(hi) < price || valueAt(lo) > price) return null
  for (let i = 0; i < 80; i++) {
    const mid = (lo + hi) / 2
    if (valueAt(mid) > price) hi = mid
    else lo = mid
  }
  return (lo + hi) / 2
}

export function runDCF(inputs: DCFInputs): DCFResult | null {
  const {
    fcf, cash, debt, shares, price, growth,
    discount = 0.10,
    terminal = 0.025,
    years = 10,
    marginOfSafety = 0.25,
  } = inputs

  if (fcf <= 0 || shares <= 0 || discount <= terminal) return null

  const { perShare, pvFcf, pvTerminal, equity } = intrinsic(fcf, cash, debt, shares, growth, discount, terminal, years)
  const upsidePct = (perShare / price - 1) * 100
  const verdict: DCFResult['verdict'] =
    upsidePct > 10 ? 'undervalued' : upsidePct < -10 ? 'overvalued' : 'fairly_valued'

  const bearPs = intrinsic(fcf, cash, debt, shares, growth - 0.10, discount, terminal, years).perShare
  const bullPs = intrinsic(fcf, cash, debt, shares, growth + 0.10, discount, terminal, years).perShare
  const bearRetPct = (bearPs / price - 1) * 100
  const bullRetPct = (bullPs / price - 1) * 100
  const downside = Math.max(Math.abs(Math.min(bearRetPct, 0)), 1e-9)
  const upside = Math.max(bullRetPct, 0)

  return {
    intrinsicPerShare: perShare,
    price,
    upsidePct,
    verdict,
    buyBelow: perShare * (1 - marginOfSafety),
    impliedGrowth: reverseGrowth(fcf, cash, debt, shares, price, discount, terminal, years),
    pvFcf,
    pvTerminal,
    equityValue: equity,
    asymmetryRatio: upside / downside,
    bearValue: bearPs,
    baseValue: perShare,
    bullValue: bullPs,
    growthUsed: growth,
  }
}
