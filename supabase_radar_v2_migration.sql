alter table public.radar_opportunities
  add column if not exists score_breakdown jsonb,
  add column if not exists reprice_gap jsonb,
  add column if not exists council_explanation jsonb,
  add column if not exists regime_flags text[];

create index if not exists radar_opportunities_score_breakdown_gin
  on public.radar_opportunities using gin (score_breakdown);

create index if not exists radar_opportunities_regime_flags_gin
  on public.radar_opportunities using gin (regime_flags);
