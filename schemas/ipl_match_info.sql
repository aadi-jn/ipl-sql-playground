-- Schema for ipl-nao.ipl_db.ipl_match_info
-- Paste this into your AI agent as context when writing queries.
--
-- Notes:
--   `date` is a STRING in ISO format 'YYYY-MM-DD' (e.g. '2008-04-18'), not a DATE type.
--   `neutral_venue` is FLOAT64 (1.0 / NULL), used as a 0/1 flag.
--   `season` is a STRING and can look like '2007/08' or '2009' - do not treat as a number.

CREATE TABLE `ipl-nao.ipl_db.ipl_match_info`
(
  filename STRING,
  season STRING,
  match_number FLOAT64,
  date STRING,
  team1 STRING,
  team2 STRING,
  city STRING,
  venue STRING,
  neutral_venue FLOAT64,
  toss_winner STRING,
  toss_decision STRING,
  winner STRING,
  win_type STRING,
  win_margin FLOAT64,
  result STRING,
  method STRING,
  eliminator STRING,
  player_of_match STRING,
  umpire1 STRING,
  umpire2 STRING,
  event_stage STRING,
  target_overs FLOAT64,
  target_runs FLOAT64,
  match_referee STRING,
  tv_umpire STRING,
  reserve_umpire STRING,
  team1_impact_in STRING,
  team1_impact_out STRING,
  team2_impact_in STRING,
  team2_impact_out STRING,
  match_id INT64
);
