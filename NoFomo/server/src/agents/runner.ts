import type { AgentDef, AgentContext, AgentResult, ChatMessage } from './types'
import { createMemory } from './memory'
import { createToolRegistry } from './tools'
import { getDeepSeekClient, getDeepSeekModel } from './client'

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function toOpenAIMessages(msgs: ChatMessage[]): any[] {
  return msgs.map(m => {
    if (m.role === 'tool') {
      return { role: 'tool' as const, content: m.content ?? '', tool_call_id: m.tool_call_id! }
    }
    if (m.role === 'system') return { role: 'system' as const, content: m.content! }
    if (m.role === 'user') return { role: 'user' as const, content: m.content! }
    if (m.role === 'assistant' && m.tool_calls) {
      return { role: 'assistant' as const, content: m.content, tool_calls: m.tool_calls }
    }
    return { role: 'assistant' as const, content: m.content! }
  })
}

export async function runAgent(
  agent: AgentDef,
  ctx: AgentContext,
  input: string,
  toolRegistry: ReturnType<typeof createToolRegistry>,
  userContext?: string,
  maxTurns = 8,
): Promise<AgentResult> {
  const client = getDeepSeekClient()
  const memory = createMemory(agent.systemPrompt, userContext)
  memory.addUser(input)

  let toolCalls = 0

  for (let turn = 0; turn < maxTurns; turn++) {
    const msgs = memory.getMessages()

    const response = await client.chat.completions.create({
      model: getDeepSeekModel(),
      messages: toOpenAIMessages(msgs),
      tools: toolRegistry.getOpenAITools(),
      temperature: 0.3,
      max_tokens: 4096,
    })

    const choice = response.choices[0]
    if (!choice) {
      return { text: 'Error: no response from model', toolCalls }
    }

    const { message } = choice

    if (message.tool_calls && message.tool_calls.length > 0) {
      const fnCalls = message.tool_calls.filter(
        (tc: { type: string }) => tc.type === 'function',
      )

      if (fnCalls.length > 0) {
        const toolCallsData = fnCalls.map(
          (tc: { id: string; type: 'function'; function: { name: string; arguments: string } }) => ({
            id: tc.id,
            type: 'function' as const,
            function: { name: tc.function.name, arguments: tc.function.arguments },
          }),
        )

        memory.addAssistant(null, toolCallsData)

        for (const tc of fnCalls as {
          id: string
          function: { name: string; arguments: string }
        }[]) {
          const result = await toolRegistry.execute(tc.function.name, tc.function.arguments, ctx)
          memory.addTool(tc.id, result, tc.function.name)
          toolCalls++
        }
        continue
      }
    }

    const text = message.content || 'No response.'
    memory.addAssistant(text)
    return { text, toolCalls }
  }

  // Max turns hit — force final answer
  memory.addUser(
    'Please provide your final answer now based on all the information gathered.',
  )
  const finalMsgs = memory.getMessages()
  const finalResponse = await client.chat.completions.create({
    model: getDeepSeekModel(),
    messages: toOpenAIMessages(finalMsgs),
    temperature: 0.3,
    max_tokens: 4096,
  })

  const finalText = finalResponse.choices[0]?.message.content || 'No response.'
  memory.addAssistant(finalText)
  return { text: finalText, toolCalls }
}
