import OpenAI from 'openai'

// ── OpenRouter — single key for all models ──────────────────────
const OPENROUTER_BASE_URL = 'https://openrouter.ai/api/v1'

let openrouterClient: OpenAI | null = null
export function getOpenRouterClient(): OpenAI {
  if (!openrouterClient) {
    openrouterClient = new OpenAI({
      apiKey: process.env.OPENROUTER_API_KEY,
      baseURL: OPENROUTER_BASE_URL,
    })
  }
  return openrouterClient
}

// ── AnyAPI — free tier alternative to OpenRouter ────────────────
const ANYAPI_BASE_URL = 'https://api.anyapi.ai/v1'

let anyapiClient: OpenAI | null = null
export function getAnyAPIClient(): OpenAI {
  if (!anyapiClient) {
    anyapiClient = new OpenAI({
      apiKey: process.env.ANYAPI_API_KEY,
      baseURL: ANYAPI_BASE_URL,
    })
  }
  return anyapiClient
}

/** Pick the right router client: AnyAPI preferred when key is set, else OpenRouter */
function getRouterClient(): OpenAI {
  if (process.env.ANYAPI_API_KEY) return getAnyAPIClient()
  return getOpenRouterClient()
}

/** Free models on AnyAPI/OpenRouter free tier — intentionally different architectures per role */
const ANYAPI_FREE_MODELS = {
  deepseek: 'deepseek/deepseek-chat-v3-0324',
  gemini: 'meta-llama/llama-4-maverick',
  claude: 'qwen/qwen3-235b-a22b-instruct',
} as const

// ── DeepSeek — primary research agent ──────────────────────────
let deepseekClient: OpenAI | null = null
export function getDeepSeekClient(): OpenAI {
  // Prefer direct key if set (cheaper), fall back to router
  if (process.env.DEEPSEEK_API_KEY) {
    if (!deepseekClient) {
      deepseekClient = new OpenAI({
        apiKey: process.env.DEEPSEEK_API_KEY,
        baseURL: 'https://api.deepseek.com/v1',
      })
    }
    return deepseekClient
  }
  return getRouterClient()
}

export function getDeepSeekModel(): string {
  if (process.env.DEEPSEEK_API_KEY) return process.env.DEEPSEEK_MODEL || 'deepseek-chat'
  if (process.env.ANYAPI_API_KEY) return ANYAPI_FREE_MODELS.deepseek
  return process.env.DEEPSEEK_MODEL || 'deepseek/deepseek-chat-v3-0324:free'
}

export function getGeminiModel(): string {
  if (process.env.GEMINI_API_KEY) return process.env.GEMINI_MODEL || 'gemini-2.5-pro'
  if (process.env.ANYAPI_API_KEY) return ANYAPI_FREE_MODELS.gemini
  return process.env.GEMINI_MODEL || 'meta-llama/llama-3.3-70b-instruct:free'
}

export function getClaudeModel(): string {
  if (process.env.ANTHROPIC_API_KEY) return process.env.ANTHROPIC_MODEL || 'claude-sonnet-4-5-20250901'
  if (process.env.ANYAPI_API_KEY) return ANYAPI_FREE_MODELS.claude
  return process.env.ANTHROPIC_MODEL || 'qwen/qwen3-235b-a22b-instruct:free'
}

// ── Anthropic Claude — CIO arbiter ─────────────────────────────
export async function callClaude(systemPrompt: string, userPrompt: string) {
  if (process.env.ANTHROPIC_API_KEY) {
    // Direct Anthropic SDK
    const { default: Anthropic } = await import('@anthropic-ai/sdk')
    const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY })
    const response = await client.messages.create({
      model: process.env.ANTHROPIC_MODEL || 'claude-sonnet-4-5-20250901',
      max_tokens: 1024,
      temperature: 0.3,
      system: systemPrompt,
      messages: [{ role: 'user', content: userPrompt }],
    })
    const text = response.content
      .filter(block => block.type === 'text')
      .map(block => (block as { type: 'text'; text: string }).text)
      .join('\n')
    return text
  }

  // Fallback to router (AnyAPI or OpenRouter)
  const client = getRouterClient()
  const model = getClaudeModel()

  const response = await client.chat.completions.create({
    model,
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userPrompt },
    ],
    temperature: 0.3,
    max_tokens: 1024,
  })
  return response.choices[0]?.message.content || ''
}

// ── Google Gemini — council member ─────────────────────────────
export async function callGemini(systemPrompt: string, userPrompt: string) {
  if (process.env.GEMINI_API_KEY) {
    // Direct Gemini SDK
    const { GoogleGenAI } = await import('@google/genai')
    const client = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY })
    const model = process.env.GEMINI_MODEL || 'gemini-2.5-pro'
    const result = await client.models.generateContent({
      model,
      contents: [{ role: 'user', parts: [{ text: `${systemPrompt}\n\n${userPrompt}` }] }],
      config: { temperature: 0.3, maxOutputTokens: 1024 },
    })
    const text =
      result.candidates?.[0]?.content?.parts
        ?.filter((p: { text?: string }) => p.text)
        .map((p: { text?: string }) => p.text)
        .join('\n') ?? ''
    return text
  }

  // Fallback to router
  const client = getRouterClient()
  const model = getGeminiModel()

  const response = await client.chat.completions.create({
    model,
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userPrompt },
    ],
    temperature: 0.3,
    max_tokens: 1024,
  })
  return response.choices[0]?.message.content || ''
}

export const DEEPSEEK_MODEL = process.env.DEEPSEEK_MODEL || 'deepseek/deepseek-chat'
export const ANTHROPIC_MODEL = process.env.ANTHROPIC_MODEL || 'anthropic/claude-sonnet-4-5'
export const GEMINI_MODEL = process.env.GEMINI_MODEL || 'google/gemini-2.5-pro-preview-03-25'