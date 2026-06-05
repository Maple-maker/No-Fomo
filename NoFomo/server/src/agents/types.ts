import type { SupabaseClient } from '@supabase/supabase-js'

export type AgentContext = {
  userId: string
  supabase: SupabaseClient
}

export type ToolDef = {
  name: string
  description: string
  parameters: Record<string, unknown>
  execute: (args: Record<string, unknown>, ctx: AgentContext) => Promise<string>
}

export type AgentDef = {
  name: string
  systemPrompt: string
  tools: string[]
}

export type AgentResult = {
  text: string
  toolCalls: number
}

export type ChatMessage = {
  role: 'system' | 'user' | 'assistant' | 'tool'
  content: string | null
  tool_call_id?: string
  name?: string
  tool_calls?: {
    id: string
    type: 'function'
    function: { name: string; arguments: string }
  }[]
}

export type Verdict = 'BULL' | 'BEAR'

export type CouncilVerdict = {
  verdict: Verdict
  reasoning: string
}

export type CIOArbiter = {
  verdict: Verdict
  synthesis: string
  tier: number
  score: number
  tripleSignal: boolean
}

export type StructuredOpportunity = {
  ticker: string
  companyName: string
  sector: string
  tier: number
  score: number
  tripleSignal: boolean
  bluf: string
  price: number
  upside: number
  marketCap: string
  probability: number
  catalyst: string
  council: { gemini: string; deepseek: string; cio: string }
  buyZones: { aggressive: number; base: number; conservative: number }
  bullCase: string
  bearCase: string
  financials: string[][]
  redFlags: string[]
  invalidation: string
  fullReportMd: string
}
