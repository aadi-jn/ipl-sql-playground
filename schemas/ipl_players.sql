-- Schema for ipl-nao.ipl_db.ipl_players
-- Paste this into your AI agent as context when writing queries.
--
-- Notes:
--   `player_id` is the STRING join key to the stats tables.
--   `key_cricinfo` is a FLOAT64 external id, not a metric.

CREATE TABLE `ipl-nao.ipl_db.ipl_players`
(
  player_id STRING,
  player_name STRING,
  unique_name STRING,
  key_cricinfo FLOAT64
);
