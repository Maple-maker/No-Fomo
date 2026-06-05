import OpenAI from 'openai'
import Anthropic from '@anthropic-ai/sdk'
import { GoogleGenAI } from '@google/genai'

// DeepSeek (OpenAI-compatible) — primary research agent
const DEEPSEEK_BASE_URL = 'https://api.deepseek.com/v1'

let deepseekClient: OpenAI | null = null
export function getDeepSeekClient(): OpenAI {
  if (!deepseekClient) {
    deepseekClient = new OpenAI({
      apiKey: process.env.DEEPSEEK_API_KEY,
      baseURL: DEEPSEEK_BASE_URL,
    })
  }
  return deepseekClient
}

// Anthropic Claude — CIO arbiter
let anthropicClient: Anthropic | null = null
export function getAnthropicClient(): Anthropic {
  if (!anthropicClient) {
    anthropicClient = new Anthropic({
      apiKey: process.env.ANTHROPIC_API_KEY,
    })
  }
  return anthropicClient
}

// Google Gemini — council member
let geminiClient: GoogleGenAI | null = null
export function getGeminiClient(): GoogleGenAI {
  if (!geminiClient) {
    geminiClient = new GoogleGenAI({
      apiKey: process.env.GEMINI_API_KEY!,
    })
  }
  return geminiClient
}

export const DEEPSEEK_MODEL = process.env.DEEPSEEK_MODEL || 'deepseek-chat'
export const ANTHROPIC_MODEL = process.env.ANTHROPIC_MODEL || 'claude-sonnet-4-5-20250901'
export const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-2.5-pro'
