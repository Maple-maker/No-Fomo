import { parseWallStreet } from './src/routes/council'

let pass = 0
let fail = 0
function check(name: string, cond: boolean) {
  console.log(`${cond ? 'PASS' : 'FAIL'}  ${name}`)
  cond ? pass++ : fail++
}

// ── Case 1: clean JSON output, all scores in range ──
// Realistic analyst output with grounded rationales.
const case1 = `{
  "moatScore": 8,
  "upsideScore": 7,
  "marketConditionScore": 6,
  "compAdvScore": 8,
  "moatRationale": "Sole-source DoD contracts + proprietary data flywheel rivals cannot replicate in 3-5y.",
  "upsideRationale": "DCF intrinsic $42.10 is 31% above current price with 25% margin of safety baked in.",
  "marketConditionRationale": "Defense budget tailwinds strong but rising rates compress growth multiples.",
  "compAdvRationale": "22nd percentile vs sector peers on P/S with 40%+ rev growth — clear cheap_growth signal.",
  "thesis": "With a DCF intrinsic of $42.10 vs the current price of $32.10 (31% upside), this name trades at a 40% discount to sector peers on P/S while growing revenues 42% YoY. The moat is a proprietary DoD data flywheel embedded in SOCOM command-and-control workflows — a 5-year switching cost that peers cannot replicate. The near-term catalyst is a $500M IDIQ award decision in Q3; downside is contained at $28 (DCF bear case) given the $310M contract backlog floor."
}`
const r1 = parseWallStreet(case1)
console.log('\n-- Case 1 (clean JSON, valid scores):', JSON.stringify(r1, null, 1))
check('moatScore = 8',            r1.moatScore === 8)
check('upsideScore = 7',          r1.upsideScore === 7)
check('marketConditionScore = 6', r1.marketConditionScore === 6)
check('compAdvScore = 8',         r1.compAdvScore === 8)
check('moatRationale is string',  typeof r1.moatRationale === 'string' && r1.moatRationale.length > 0)
check('upsideRationale present',  typeof r1.upsideRationale === 'string' && r1.upsideRationale.length > 0)
check('thesis is non-empty',      typeof r1.thesis === 'string' && r1.thesis.length > 0)

// ── Case 2: markdown-wrapped JSON (LLM often wraps in ```json fences) ──
const case2 = `Here is my Wall Street analysis:

\`\`\`json
{
  "moatScore": 9,
  "upsideScore": 6,
  "marketConditionScore": 4,
  "compAdvScore": 7,
  "moatRationale": "Three sole-source prime contracts create durable switching costs.",
  "upsideRationale": "Only 18% DCF upside — solid but not exceptional.",
  "marketConditionRationale": "Rising rate environment compresses high-multiple growth names.",
  "compAdvRationale": "Top-quartile gross margin vs sector peers but losing share in commercial segment.",
  "thesis": "Asymmetric DoD opportunity with a durable moat but near-term macro headwinds limit the multiple expansion needed for the full upside case."
}
\`\`\``
const r2 = parseWallStreet(case2)
console.log('\n-- Case 2 (markdown fence):', JSON.stringify(r2, null, 1))
check('scores parsed through fence: moat=9', r2.moatScore === 9)
check('scores parsed through fence: upside=6', r2.upsideScore === 6)
check('all 4 rationales non-empty', [r2.moatRationale, r2.upsideRationale, r2.marketConditionRationale, r2.compAdvRationale].every(s => typeof s === 'string' && s.length > 0))
check('thesis non-empty', r2.thesis.length > 0)

// ── Case 3: out-of-range scores → clamped to 1-10 ──
const case3 = `{
  "moatScore": 15,
  "upsideScore": 0,
  "marketConditionScore": -3,
  "compAdvScore": 10.7,
  "moatRationale": "Exceptional moat.",
  "upsideRationale": "No upside.",
  "marketConditionRationale": "Terrible conditions.",
  "compAdvRationale": "Best in class.",
  "thesis": "Short-term pain, long-term gain."
}`
const r3 = parseWallStreet(case3)
console.log('\n-- Case 3 (out-of-range clamping):', JSON.stringify(r3, null, 1))
check('moatScore 15 → clamped to 10',        r3.moatScore === 10)
check('upsideScore 0 → clamped to 1',        r3.upsideScore === 1)
check('marketConditionScore -3 → clamped to 1', r3.marketConditionScore === 1)
check('compAdvScore 10.7 → rounded+clamped to 10', r3.compAdvScore === 10)

// ── Case 4: completely malformed — no JSON at all, must not throw and return safe zeros ──
const r4 = parseWallStreet('The model refused and returned only prose. No JSON here.')
console.log('\n-- Case 4 (garbage/no-JSON):', JSON.stringify(r4, null, 1))
check('garbage → moatScore 0 (fallback)',     r4.moatScore === 0)
check('garbage → upsideScore 0',              r4.upsideScore === 0)
check('garbage → marketConditionScore 0',     r4.marketConditionScore === 0)
check('garbage → compAdvScore 0',             r4.compAdvScore === 0)
check('garbage → thesis empty string',        r4.thesis === '')
check('garbage → moatRationale empty string', r4.moatRationale === '')

// ── Case 5: partial JSON — some fields missing → missing scores fall back to 0, present ones parsed ──
const case5 = `{"moatScore": 7, "thesis": "Partial output from model."}`
const r5 = parseWallStreet(case5)
console.log('\n-- Case 5 (partial JSON):', JSON.stringify(r5, null, 1))
check('moatScore present → 7',              r5.moatScore === 7)
check('missing upsideScore → 0',            r5.upsideScore === 0)
check('missing compAdvScore → 0',           r5.compAdvScore === 0)
check('thesis captured',                    r5.thesis === 'Partial output from model.')
check('missing rationale → empty string',   r5.moatRationale === '')

console.log(`\n=== ${pass} passed, ${fail} failed ===`)
process.exit(fail === 0 ? 0 : 1)
