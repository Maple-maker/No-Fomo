export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

export interface Database {
  public: {
    Tables: {
      profiles: {
        Row: {
          id: string
          full_name: string | null
          timezone: string
          avatar_url: string | null
          onboarded: boolean
          created_at: string
          updated_at: string
        }
        Insert: {
          id: string
          full_name?: string | null
          timezone?: string
          avatar_url?: string | null
          onboarded?: boolean
        }
        Update: Partial<Database['public']['Tables']['profiles']['Insert']>
      }
      accounts: {
        Row: {
          id: string
          user_id: string
          slug: string
          name: string
          type: string
          broker: string | null
          color: string
          display_order: number
          created_at: string
        }
        Insert: Omit<Database['public']['Tables']['accounts']['Row'], 'id' | 'created_at'>
        Update: Partial<Database['public']['Tables']['accounts']['Insert']>
      }
      holdings: {
        Row: {
          id: string
          account_id: string
          user_id: string
          ticker: string
          label: string | null
          shares: number
          cost_per_share: number | null
          coingecko_id: string | null
          created_at: string
          updated_at: string
        }
        Insert: Omit<Database['public']['Tables']['holdings']['Row'], 'id' | 'created_at' | 'updated_at'>
        Update: Partial<Database['public']['Tables']['holdings']['Insert']>
      }
      networth_history: {
        Row: {
          id: string
          user_id: string
          date: string
          total: number
        }
        Insert: Omit<Database['public']['Tables']['networth_history']['Row'], 'id'>
        Update: Partial<Database['public']['Tables']['networth_history']['Insert']>
      }
      networth_intraday: {
        Row: {
          id: string
          user_id: string
          ts: string
          total: number
        }
        Insert: Omit<Database['public']['Tables']['networth_intraday']['Row'], 'id'>
        Update: Partial<Database['public']['Tables']['networth_intraday']['Insert']>
      }
      todos: {
        Row: {
          id: string
          user_id: string
          text: string
          done: boolean
          source: string
          tags: string[]
          display_order: number
          created_at: string
          completed_at: string | null
        }
        Insert: Omit<Database['public']['Tables']['todos']['Row'], 'id' | 'created_at'>
        Update: Partial<Database['public']['Tables']['todos']['Insert']>
      }
      brief_log: {
        Row: {
          id: string
          user_id: string
          text: string
          audio_url: string | null
          tool_calls: number
          created_at: string
        }
        Insert: Omit<Database['public']['Tables']['brief_log']['Row'], 'id' | 'created_at'>
        Update: Partial<Database['public']['Tables']['brief_log']['Insert']>
      }
      alerts: {
        Row: {
          id: string
          user_id: string
          ticker: string
          type: string
          threshold: number
          channel: string
          active: boolean
          triggered_at: string | null
          created_at: string
        }
        Insert: Omit<Database['public']['Tables']['alerts']['Row'], 'id' | 'created_at'>
        Update: Partial<Database['public']['Tables']['alerts']['Insert']>
      }
      user_integrations: {
        Row: {
          id: string
          user_id: string
          provider: string
          access_token: string | null
          refresh_token: string | null
          expires_at: string | null
          config: Json
          created_at: string
          updated_at: string
        }
        Insert: Omit<Database['public']['Tables']['user_integrations']['Row'], 'id' | 'created_at' | 'updated_at'>
        Update: Partial<Database['public']['Tables']['user_integrations']['Insert']>
      }
    }
  }
}
