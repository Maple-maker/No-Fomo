-- Founder seed posts for Community Trade Ideas
-- 1. Run supabase_trade_ideas_migration.sql first
-- 2. User UUID: e21f5ebc-f357-49fc-80b3-6b99661a70ec
-- 3. Run with service role or as authenticated user via SQL editor

insert into user_profiles (user_id, display_name, reputation_score, current_streak, longest_streak, ideas_posted, win_count)
values ('e21f5ebc-f357-49fc-80b3-6b99661a70ec', 'Jaiden', 240, 3, 5, 5, 2)
on conflict (user_id) do update set
  display_name = excluded.display_name,
  reputation_score = greatest(user_profiles.reputation_score, excluded.reputation_score),
  updated_at = now();

insert into trade_ideas (user_id, ticker, body, direction, entry_price, target_price, timeframe_days, status, upvote_count)
values
  (
    'e21f5ebc-f357-49fc-80b3-6b99661a70ec',
    'MRVL',
    'AI networking backlog + custom silicon cycle not fully priced. Data center spend inflecting while street still models flat YoY.',
    'long',
    72.50,
    95.00,
    45,
    'open',
    12
  ),
  (
    'e21f5ebc-f357-49fc-80b3-6b99661a70ec',
    'SMCI',
    'Liquid cooling rack demand is a multi-quarter setup. Short thesis crowd overstating margin compression risk.',
    'long',
    42.00,
    58.00,
    30,
    'open',
    8
  ),
  (
    'e21f5ebc-f357-49fc-80b3-6b99661a70ec',
    'CRVO',
    'Underfollowed biotech with near-term readout. Insider cluster buys + thin analyst coverage = repricing setup.',
    'long',
    8.20,
    14.00,
    60,
    'open',
    15
  ),
  (
    'e21f5ebc-f357-49fc-80b3-6b99661a70ec',
    'KTOS',
    'Drone / autonomous systems budget line accelerating. Government lane signal stacking with backlog growth.',
    'long',
    28.50,
    38.00,
    45,
    'won',
    22
  ),
  (
    'e21f5ebc-f357-49fc-80b3-6b99661a70ec',
    'PLTR',
    'Commercial adoption curve steepening but valuation already prices perfection. Risk/reward skewed down near highs.',
    'short',
    24.80,
    19.00,
    30,
    'lost',
    5
  );

-- Update resolved ideas with performance scores (hybrid formula approximation)
update trade_ideas set performance_score = 48, resolved_at = now() - interval '10 days'
where ticker = 'KTOS' and user_id = 'e21f5ebc-f357-49fc-80b3-6b99661a70ec';

update trade_ideas set performance_score = -15, resolved_at = now() - interval '5 days'
where ticker = 'PLTR' and user_id = 'e21f5ebc-f357-49fc-80b3-6b99661a70ec';
