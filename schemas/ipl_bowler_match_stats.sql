-- Schema for ipl-nao.ipl_db.ipl_bowler_match_stats
-- Paste this into your AI agent as context when writing queries.
--
-- Notes:
--   `match_date` is INT64 epoch NANOSECONDS (e.g. 1208476800000000000 = 2008-04-18).
--      To read it as a date: DATE(TIMESTAMP_MICROS(CAST(match_date/1000 AS INT64))).
--   `is_player_of_match` is BOOL (true/false).
--   Rate columns (`economy`, `bowling_strike_rate`, `dot_ball_pct`) are per-row; never AVG() a rate across rows.
--   Join to ipl_players on player_id; to ipl_match_info on match_id.

CREATE TABLE `ipl-nao.ipl_db.ipl_bowler_match_stats`
(
  match_id INT64,
  match_date INT64,
  season STRING,
  match_number INT64,
  innings INT64,
  bowler STRING,
  player_id STRING,
  team STRING,
  overs_bowled FLOAT64,
  balls_bowled INT64,
  runs_conceded INT64,
  wickets INT64,
  economy FLOAT64,
  bowling_strike_rate FLOAT64,
  dots INT64,
  dot_ball_pct FLOAT64,
  fours_conceded INT64,
  sixes_conceded INT64,
  wides INT64,
  noballs INT64,
  maidens INT64,
  is_player_of_match BOOL,
  match_result STRING
);
