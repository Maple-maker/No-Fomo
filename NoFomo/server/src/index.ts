import 'dotenv/config'
import express from 'express'
import radarRouter from './routes/radar'
import councilRouter from './routes/council'
import discoverRouter from './routes/discover'
import cronRouter from './routes/cron'
import sweepRouter from './routes/sweep'
import kalshiRouter from './routes/kalshi'

const app = express()
const PORT = parseInt(process.env.PORT || '3001', 10)

app.use(express.json({ limit: '5mb' }))

// Health check
app.get('/health', (_req, res) => {
  res.json({
    status: 'ok',
    service: 'nofomo-radar',
    version: '1.0.0',
    providers: {
      openrouter: !!process.env.OPENROUTER_API_KEY,
      deepseek: !!process.env.DEEPSEEK_API_KEY,
      anthropic: !!process.env.ANTHROPIC_API_KEY,
      gemini: !!process.env.GEMINI_API_KEY,
      brave: !!process.env.BRAVE_API_KEY,
      supabase: !!process.env.SUPABASE_SERVICE_ROLE_KEY,
    },
  })
})

// Routes
app.use('/radar', radarRouter)
app.use('/radar', discoverRouter)
app.use('/radar', cronRouter)
app.use('/radar', sweepRouter)
app.use('/radar', kalshiRouter)
app.use('/council', councilRouter)

// Only bind a port in local dev — on Vercel the app is exported as a serverless handler.
if (!process.env.VERCEL) {
  app.listen(PORT, () => {
    console.log(`\n  NoFomo Radar Server`)
    console.log(`  ────────────────────────────────────`)
    console.log(`  http://localhost:${PORT}`)
    console.log(`  /health         — status check`)
    console.log(`  /radar          — POST { ticker } → research + council + persist`)
    console.log(`  /radar/discover — POST → open-universe discovery pipeline`)
    console.log(`  /radar/cron     — GET/POST → daily discover → radar → persist → sweep`)
    console.log(`  /radar/sweep    — POST → prune closed/stale opportunities`)
    console.log(`  /council        — POST { dossier } → 3-model verdict\n`)
  })
}

export default app
