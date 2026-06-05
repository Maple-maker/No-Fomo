import type { ChatMessage } from './types'

export function createMemory(systemPrompt: string, userContext?: string) {
  const messages: ChatMessage[] = []

  messages.push({ role: 'system', content: systemPrompt })

  if (userContext) {
    messages.push({ role: 'system', content: userContext })
  }

  return {
    addAssistant(content: string | null, toolCalls?: ChatMessage['tool_calls']) {
      messages.push({ role: 'assistant', content, tool_calls: toolCalls })
    },

    addUser(content: string) {
      messages.push({ role: 'user', content })
    },

    addTool(toolCallId: string, result: string, name?: string) {
      messages.push({ role: 'tool', content: result, tool_call_id: toolCallId, name })
    },

    getMessages(): ChatMessage[] {
      return messages
    },
  }
}
