-- Schema for ipl-nao.ipl_db.ipl_batter_match_stats
-- Paste this into your AI agent as context when writing queries.
--
-- Notes:
--   `match_date` is INT64 epoch NANOSECONDS (e.g. 1208476800000000000 = 2008-04-18).
--      To read it as a date: DATE(TIMESTAMP_MICROS(CAST(match_date/1000 AS INT64))).
--   `dismissed`, `not_out`, `is_duck`, `is_player_of_match` are BOOL (true/false).
--   Rate columns (`strike_rate`, `boundary_pct`, `dot_ball_pct`) are per-row; never AVG() a rate across rows.
--   Join to ipl_players on player_id; to ipl_match_info on match_id.

CREATE TABLE `ipl-nao.ipl_db.ipl_batter_match_stats`
(
  match_id INT64,
  match_date INT64,
  season STRING,
  match_number INT64,
  innings INT64,
  batter STRING,
  player_id STRING,
  team STRING,
  runs INT64,
  balls_faced INT64,
  strike_rate FLOAT64,
  fours INT64,
  sixes INT64,
  boundary_pct FLOAT64,
  dots_faced INT64,
  dot_ball_pct FLOAT64,
  dismissed BOOL,
  dismissal_kind STRING,
  not_out BOOL,
  is_duck BOOL,
  batting_position INT64,
  is_player_of_match BOOL,
  match_result STRING
);
