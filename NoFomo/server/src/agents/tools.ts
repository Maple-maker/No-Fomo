import type { ToolDef, AgentContext } from './types'

export function createToolRegistry() {
  const tools = new Map<string, ToolDef>()

  return {
    register(tool: ToolDef) {
      tools.set(tool.name, tool)
    },

    get(name: string): ToolDef | undefined {
      return tools.get(name)
    },

    getOpenAITools() {
      return Array.from(tools.values()).map(t => ({
        type: 'function' as const,
        function: {
          name: t.name,
          description: t.description,
          parameters: t.parameters,
        },
      }))
    },

    async execute(name: string, args: string, ctx: AgentContext): Promise<string> {
      const tool = tools.get(name)
      if (!tool) return `Error: unknown tool "${name}"`
      try {
        const parsed = JSON.parse(args) as Record<string, unknown>
        return await tool.execute(parsed, ctx)
      } catch (err) {
        return `Tool error: ${err instanceof Error ? err.message : String(err)}`
      }
    },
  }
}
