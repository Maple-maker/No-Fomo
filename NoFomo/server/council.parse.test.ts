import { parseCIO } from './src/routes/council'

let pass = 0
let fail = 0
function check(name: string, cond: boolean) {
  console.log(`${cond ? 'PASS' : 'FAIL'}  ${name}`)
  cond ? pass++ : fail++
}

// ── Case 1: full valid Claude output, consensus_risk = true ──
// Claude wraps JSON in prose + markdown fence (realistic), scores in range,
// tripleSignal claimed true but must be forced false because consensus_risk.
const case1 = `Here is my final verdict.

\`\`\`json
{
  "verdict": "BULL",
  "synthesis": "Both analysts landed BULL on the sole-source IDIQ + founder buying.",
  "tier": 2,
  "score": 82,
  "tripleSignal": true,
  "consensus_risk": true,
  "asymmetry": 8,
  "conviction": 7,
  "catalyst": 9,
  "management": 8,
  "asymmetryRationale": "1.9x fwd sales vs 4-6x peers with defined $5.50 floor",
  "convictionRationale": "Backlog $90M to $310M corroborated by Form 4 cluster",
  "catalystRationale": "Binary July delivery-order decision within 8 weeks",
  "managementRationale": "Founder 32% owner bought open-market, zero sales 24mo"
}
\`\`\``
const r1 = parseCIO(case1)
console.log('\n-- Case 1 (valid, consensus_risk=true):', JSON.stringify(r1, null, 1))
check('verdict BULL', r1.verdict === 'BULL')
check('score preserved 82', r1.score === 82)
check('4 dimensions parsed', [r1.asymmetry, r1.conviction, r1.catalyst, r1.management].every(d => typeof d === 'number'))
check('dimensions exact [8,7,9,8]', r1.asymmetry === 8 && r1.conviction === 7 && r1.catalyst === 9 && r1.management === 8)
check('4 rationales land', [r1.asymmetryRationale, r1.convictionRationale, r1.catalystRationale, r1.managementRationale].every(s => typeof s === 'string' && s.length > 0))
check('consensus_risk = true', r1.consensus_risk === true)
check('tripleSignal FORCED false despite claim', r1.tripleSignal === false)

// ── Case 2: out-of-range + missing fields ──
// score absent → must fall back to 0 (not 5). Dimensions out of range → clamp 1-10.
// rationales missing → undefined (tolerated). consensus_risk absent → false; tripleSignal honored.
const case2 = `{
  "verdict": "BEAR",
  "synthesis": "Customer concentration kills it.",
  "tier": 3,
  "tripleSignal": true,
  "asymmetry": 15,
  "conviction": 0,
  "catalyst": -2,
  "management": 6.7
}`
const r2 = parseCIO(case2)
console.log('\n-- Case 2 (clamp + missing):', JSON.stringify(r2, null, 1))
check('verdict BEAR', r2.verdict === 'BEAR')
check('missing score falls back to 0 (not 5)', r2.score === 0)
check('asymmetry 15 clamped to 10', r2.asymmetry === 10)
check('conviction 0 clamped to 1', r2.conviction === 1)
check('catalyst -2 clamped to 1', r2.catalyst === 1)
check('management 6.7 rounded to 7', r2.management === 7)
check('missing rationales are undefined', r2.asymmetryRationale === undefined && r2.managementRationale === undefined)
check('consensus_risk defaults false', r2.consensus_risk === false)
check('tripleSignal honored when no consensus_risk', r2.tripleSignal === true)

// ── Case 3: garbage (parser must not throw, returns safe default with score 0) ──
const r3 = parseCIO('the model refused and returned only prose, no json here')
console.log('\n-- Case 3 (garbage):', JSON.stringify(r3, null, 1))
check('garbage → safe default, score 0', r3.score === 0 && typeof r3.verdict === 'string')

console.log(`\n=== ${pass} passed, ${fail} failed ===`)
process.exit(fail === 0 ? 0 : 1)
