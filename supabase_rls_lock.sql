-- =============================================================================
-- supabase_rls_lock.sql
-- WP-A: RLS lock for radar_opportunities base table
--
-- !! DO NOT APPLY until WP-E has reshipped the iOS app !!
--
-- PREREQUISITE: The iOS fetch path must be updated to read `radar_feed_public`
-- (the view) instead of `radar_opportunities` (the base table) for any request
-- that uses the anon key or unauthenticated path. If you apply this migration
-- before that reship lands in production, the live app will receive 0 rows and
-- appear broken.
--
-- SAFE to apply after:
--   1. WP-E updates SupabaseService.swift to query `radar_feed_public`
--   2. A new build is submitted and live (or TestFlight distributes the update)
--
-- What this does:
--   - Drops the "Allow public read access" policy (qual = true on {public})
--     that currently lets any anon key SELECT * from radar_opportunities.
--   - Replaces it with a policy that restricts direct base-table reads to
--     authenticated (JWT-bearing) users only.
--   - Revokes the raw SELECT privilege from the anon role on the base table.
--   - The `radar_feed_public` view is NOT affected — anon can still read it
--     because the view runs with the view-owner's privileges (SECURITY INVOKER
--     is NOT set, so Postgres executes under the definer's grants, which include
--     the service role's access to the base table).
-- =============================================================================

-- Step 1: Drop the existing open policy
DROP POLICY IF EXISTS "Allow public read access" ON public.radar_opportunities;

-- Step 2: Create an authenticated-only SELECT policy on the base table
CREATE POLICY "Authenticated read only"
  ON public.radar_opportunities
  FOR SELECT
  TO authenticated
  USING (auth.role() = 'authenticated');

-- Step 3: Revoke direct anon SELECT on the base table
--         (anon can still read via the radar_feed_public view)
REVOKE SELECT ON public.radar_opportunities FROM anon;
