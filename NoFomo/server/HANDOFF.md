# NoFomo Radar Server — Handoff to Hermes

This server is the execution engine for the NoFomo research pipeline. It runs the AI agent loop, the multi-model council, and persists structured opportunities to Supabase — the same `radar_opportunities` table the iOS app reads from.

## Quickstart

```bash
cd NoFomo/server
npm install
# Set SUPABASE_SERVICE_ROLE_KEY in .env (currently blank)
npm run dev
# → http://localhost:3001
```

## Endpoints

### `POST /radar`

Full pipeline: research → structure → council → persist.

```bash
curl -X POST http://localhost:3001/radar \
  -H 'Content-Type: application/json' \
  -d '{"ticker": "CRVO"}'
```

**Request body:**
| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `ticker` | string | **yes** | Any US equity ticker |
| `skip_council` | boolean | no | Skip 3-model debate (faster, for batch scanning) |
| `skip_persist` | boolean | no | Don't write to Supabase (dry run / debugging) |
| `user_id` | string | no | Attribution (defaults to `radar-server`) |

**Response (200):**
```json
{
  "ticker": "CRVO",
  "tier": 1,
  "score": 91,
  "tripleSignal": true,
  "council": { "gemini": "BULL", "deepseek": "BULL", "cio": "BULL" },
  "bluf": "FDA granted accelerated approval...",
  "persisted": true,
  "toolCalls": 7,
  "dossierLength": 4823
}
```

**What happens under the hood:**
1. **Research agent loop** (DeepSeek) — searches the web 4-8 times across business model, financials, sentiment, and macro lanes. Uses Brave Search API + Yahoo Finance for price.
2. **Structured extraction** — parses the JSON scoring block from the markdown dossier.
3. **AI Council** — Gemini and DeepSeek independently deliver BULL/BEAR verdicts. Claude (CIO) weighs both and produces the final tier, score, and tripleSignal.
4. **Persist** — writes the assembled row to `radar_opportunities`. The iOS app picks it up on next feed refresh.

**Typical runtime:** 45-90 seconds for a full run (6-8 web searches + 3 LLM calls for council).

### `POST /council`

Standalone 3-model debate on a dossier you already have.

```bash
curl -X POST http://localhost:3001/council \
  -H 'Content-Type: application/json' \
  -d '{"dossier": "## NoFomo Radar Dossier: $CRVO ..."}'
```

**Request body:**
| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `dossier` | string | **yes** | Full markdown dossier (max ~12k chars processed) |

**Response (200):**
```json
{
  "gemini": { "verdict": "BULL", "reasoning": "..." },
  "deepseek": { "verdict": "BEAR", "reasoning": "..." },
  "cio": { "verdict": "BULL", "synthesis": "...", "tier": 2, "score": 79, "tripleSignal": false }
}
```

### `GET /health`

Status check — confirms which API keys are configured.

## Architecture

```
src/
├── index.ts              # Express server (port 3001)
├── routes/
│   ├── radar.ts          # POST /radar — full pipeline orchestrator
│   └── council.ts        # POST /council — standalone 3-model debate
├── agents/
│   ├── types.ts          # Shared types: AgentDef, ToolDef, CouncilVerdict, etc.
│   ├── runner.ts         # Agent loop — sends to LLM, executes tools, loops up to 8 turns
│   ├── memory.ts         # In-memory conversation state
│   ├── client.ts         # LLM client singletons (DeepSeek, Anthropic, Gemini)
│   ├── tools.ts          # Tool registry — register, list as OpenAI tools, execute
│   └── radar.ts          # Radar agent definition — system prompt + tool list
├── tools/
│   ├── web.ts            # Brave Search API tool
│   └── market.ts         # Stock price tool (Polygon with Yahoo fallback)
└── lib/
    ├── supabase.ts       # Supabase admin client (service_role)
    └── opportunity.ts    # Maps AI output → radar_opportunities row schema
```

## Integration points for Hermes

### 1. Dispatch a single ticker

When a user asks Hermes to research a ticker, call `/radar`:

```
→ Hermes receives: "research $CRVO"
→ Hermes POSTs to http://localhost:3001/radar {"ticker":"CRVO"}
→ Server returns the Opportunity row
→ Hermes reports the result to the user
→ iOS app sees it in the feed automatically (reads from Supabase)
```

### 2. Batch scanning

For sector scans or watchlist refresh, use `skip_council: true` for speed, then run council only on promising candidates:

```
→ Hermes POSTs /radar {"ticker":"TICK1","skip_council":true} for N tickers
→ Filter results where tier ≤ 2 and score ≥ 70
→ For top candidates, POST /council {"dossier":"..."} separately
→ Or re-run /radar without skip_council for the full pipeline
```

### 3. Supabase write path

The server writes directly to `radar_opportunities` using the service_role key. The row schema matches exactly what the iOS app's `RadarRow` struct expects — no client changes needed.

**Important:** `SUPABASE_SERVICE_ROLE_KEY` must be set in `server/.env`. You can get this from the Supabase dashboard → Project Settings → API → `service_role` key.

### 4. What Hermes does NOT need to do

- **Do not run the deep-research subagent for the raw dossier.** The `/radar` endpoint does the full 4-lane web research via the agent loop. Hermes should use `/radar` as the research engine, then add its own synthesis on top of the results if needed.
- **Do not write to `radar_opportunities` manually.** The server handles persistence. Hermes can call `/radar` and trust the row lands in Supabase.
- **Do not run the council separately unless optimizing for batch.** The default `/radar` call includes the council. Only skip it for high-throughput scanning.

### 5. Extending the agent

The agent definition lives in `src/agents/radar.ts`. To add new research capabilities:

1. **Add a tool** — create a new `ToolDef` in `src/tools/`, register it in `src/routes/radar.ts` in the `registry.register()` block, and add its name to the `tools` array in `src/agents/radar.ts`.
2. **Modify the system prompt** — edit `SYSTEM_PROMPT` in `src/agents/radar.ts`. The prompt controls the research lanes, output format, and scoring guide.
3. **Add a new LLM provider** — add the client to `src/agents/client.ts`, then use it in `src/routes/council.ts` for council participation.

## Environment variables

All required vars are documented in `.env.example`. The critical one that's currently missing:

```
SUPABASE_SERVICE_ROLE_KEY=   ← GET THIS from Supabase dashboard
```

Without it, the server starts but `/radar` calls with persistence will fail. The health endpoint will show `"supabase": false`.

## Running on Railway

1. Set root directory to `NoFomo/server`
2. Set build command: `npm run build`
3. Set start command: `npm start`
4. Set all env vars from `.env.example` in Railway dashboard
5. Ensure Node >= 20
