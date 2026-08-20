-- Schema for season_standings.csv (derived table, not in ipl-nao.ipl_db)
-- Paste this into your AI agent as context when writing queries.
--
-- Derivation:
--   Built from ipl_match_info, one row per (season, team). Source file:
--   2026-08-20T10-01_export.csv. Regenerate by re-running the same logic if
--   ipl_match_info is refreshed with new matches.
--
-- Scope:
--   Only league-stage (round-robin) matches are counted. Playoff/knockout
--   matches (Qualifier 1/2, Eliminator, Semi Final, Final, 3rd Place Play-Off)
--   are EXCLUDED, identified via ipl_match_info.match_number IS NOT NULL
--   (match_number is null exactly on playoff rows, confirmed 1:1).
--
-- Points logic:
--   win        -> 2 points
--   no result  -> 1 point (abandoned match, both teams credited)
--   loss       -> 0 points
--   A `tie` in ipl_match_info (result = 'tie') is resolved by Super Over and
--   counted as a normal win/loss here using ipl_match_info.winner, NOT split
--   as a draw. `lost` = played - won - no_result.
--
-- Ranking:
--   `rank` is standard competition ranking on `points` ALONE within each
--   `season` (ties share a rank, next rank skips - e.g. 1, 2, 2, 4).
--   Net Run Rate is NOT used as a tiebreaker (source data has no reliable
--   per-innings run-rate for wicket-margin wins), so ties here may not match
--   the official real-world standings order when points are equal.
--
-- Known data caveats (do not silently "fix" - flag to the user if it matters):
--   - `played` is not uniform across every team within some seasons (e.g.
--     2007/08: Delhi Daredevils and Kolkata Knight Riders show 13 games vs
--     14 for the rest of the field; 2024: Kolkata Knight Riders and Gujarat
--     Titans show 12). This may reflect genuine non-round-robin schedule
--     formats in some IPL seasons, or a missing match row in the source
--     data - not yet root-caused.
--   - `season` mixes single-year ('2013') and split-year ('2020/21') string
--     formats (see ipl_match_info notes); use `season_start_year` for any
--     chronological sort or year-range filter instead of parsing `season`.
--   - Team names are franchise names as used THAT season, not a canonical
--     franchise id (e.g. 'Delhi Daredevils' and 'Delhi Capitals' are the
--     same franchise in different eras; 'Gujarat Lions' and 'Gujarat
--     Titans' are NOT the same franchise despite the shared "Gujarat").
--     Don't aggregate `team` across seasons without accounting for this.

CREATE TABLE `season_standings`
(
  season STRING,              -- raw season label from ipl_match_info, e.g. '2013', '2020/21'
  season_start_year INT64,     -- first 4-digit year in `season`; use this for sorting/filtering by year
  rank INT64,                  -- 1 = top of table that season; ties share a rank (points-only, no NRR)
  team STRING,                 -- franchise name as used in that season (see caveats above)
  played INT64,                -- league-stage matches played (playoffs excluded)
  won INT64,
  lost INT64,
  no_result INT64,
  points INT64                 -- won*2 + no_result*1
);
