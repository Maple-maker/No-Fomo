import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://jmtkygwvmrolfvwueggs.supabase.co'

let adminClient: ReturnType<typeof createClient> | null = null

export function getSupabaseAdmin() {
  if (!adminClient) {
    const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY
    if (!serviceRoleKey) {
      throw new Error('SUPABASE_SERVICE_ROLE_KEY is required for server-side writes')
    }
    adminClient = createClient(SUPABASE_URL, serviceRoleKey, {
      auth: { persistSession: false },
    })
  }
  return adminClient
}
