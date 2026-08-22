-- Build script for ipl-nao.ipl_db.match_info_v2
-- Paste this into your AI agent as context when writing queries, or re-run it to rebuild the table.
--
-- What this is:
--   A cleaned, denormalized copy of `ipl-nao.ipl_db.ipl_match_info` (same grain: one row
--   per match, PK `match_id`). The original `ipl_match_info` table is left untouched
--   (a benchmark depends on it staying messy) — this is a NEW table built from it via
--   CREATE OR REPLACE TABLE ... AS SELECT with inline mapping CTEs.
--
-- Cleanups applied (see match_info_v2_column_reference.md for full column-by-column detail):
--   1. venue    -> canonicalized to one name per physical ground (60 raw strings -> 36 grounds).
--                  Collapses bare/", City"-suffix duplicates, punctuation slips, and genuine
--                  stadium renames (Feroz Shah Kotla -> Arun Jaitley Stadium; Sardar Patel
--                  Stadium, Motera -> Narendra Modi Stadium; Subrata Roy Sahara Stadium ->
--                  Maharashtra Cricket Association Stadium; Zayed Cricket Stadium, Abu Dhabi ->
--                  Sheikh Zayed Stadium — the last two confirmed by non-overlapping season
--                  usage, consistent with a mid-tenure rename of the same ground).
--   2. city     -> re-derived FROM the cleaned venue (not from the raw city column), so every
--                  canonical venue always yields exactly one city. Fixes the 2017
--                  Bangalore/Bengaluru intra-season split and fills the 2 UAE rows that had a
--                  NULL raw city. The Mohali ground's city is fixed to "Mohali" and the
--                  Mullanpur ground's city to "Mullanpur" (kept distinct, needed for the
--                  home/away logic below).
--   3. team1, team2, winner, toss_winner, eliminator -> canonicalized franchise names, 4
--                  rename pairs merged consistently across all 5 columns (NULLs preserved):
--                    Delhi Daredevils           -> Delhi Capitals
--                    Kings XI Punjab             -> Punjab Kings
--                    Royal Challengers Bangalore -> Royal Challengers Bengaluru
--                    Rising Pune Supergiants     -> Rising Pune Supergiant
--                  Gujarat Lions and Gujarat Titans are kept SEPARATE (different franchises).
--   4. season_start_year (NEW, INT64) -> first 4-digit year parsed from raw `season`
--                  (e.g. '2007/08' -> 2007, '2020/21' -> 2020). Raw `season` kept unchanged.
--   5. target_overs -> fixes the single outlier row (filename = '392186.yaml'), which stored
--                  9.2 in over.ball cricket notation (9 overs + 2 balls) instead of decimal
--                  overs. Corrected to 9.333. Every other value was already a valid decimal
--                  and is left as-is.
--   6. neutral_venue -> converted from FLOAT64 (1.0 / NULL) to BOOL NOT NULL
--                  (TRUE / FALSE, no NULLs).
--   7. home_team, away_team (NEW, STRING) -> derived by comparing the cleaned team names
--                  against a fixed franchise -> home-city table, matched against the cleaned
--                  `city`. NULL/NULL when neutral_venue is TRUE, when neither team's home city
--                  matches the match city, or (degenerate case) when both would match. Punjab
--                  Kings counts as home for BOTH Mohali and Mullanpur.
--
-- Notes carried over from the source table:
--   `date` is a STRING in ISO format 'YYYY-MM-DD' (e.g. '2008-04-18'), not a DATE type.
--   `season` is a STRING and can look like '2007/08' or '2009' - do not treat as a number.
--
-- Verified after build: 1,243 rows (matches source exactly), 36 distinct venues (down from 60),
-- neutral_venue TRUE for 77 rows / FALSE for 1,166, no NULLs.

CREATE OR REPLACE TABLE `ipl-nao.ipl_db.match_info_v2` AS
WITH venue_map AS (
  -- raw_venue (as it appears in ipl_match_info.venue) -> canonical venue_clean, city_clean
  SELECT * FROM UNNEST([
    STRUCT('Arun Jaitley Stadium' AS raw_venue, 'Arun Jaitley Stadium' AS venue_clean, 'Delhi' AS city_clean),
    STRUCT('Arun Jaitley Stadium, Delhi', 'Arun Jaitley Stadium', 'Delhi'),
    STRUCT('Feroz Shah Kotla', 'Arun Jaitley Stadium', 'Delhi'),
    STRUCT('Barabati Stadium', 'Barabati Stadium', 'Cuttack'),
    STRUCT('Barsapara Cricket Stadium, Guwahati', 'Barsapara Cricket Stadium', 'Guwahati'),
    STRUCT('Bharat Ratna Shri Atal Bihari Vajpayee Ekana Cricket Stadium, Lucknow', 'Bharat Ratna Shri Atal Bihari Vajpayee Ekana Cricket Stadium', 'Lucknow'),
    STRUCT('Brabourne Stadium', 'Brabourne Stadium', 'Mumbai'),
    STRUCT('Brabourne Stadium, Mumbai', 'Brabourne Stadium', 'Mumbai'),
    STRUCT('Buffalo Park', 'Buffalo Park', 'East London'),
    STRUCT('De Beers Diamond Oval', 'De Beers Diamond Oval', 'Kimberley'),
    STRUCT('Dr DY Patil Sports Academy', 'Dr DY Patil Sports Academy', 'Mumbai'),
    STRUCT('Dr DY Patil Sports Academy, Mumbai', 'Dr DY Patil Sports Academy', 'Mumbai'),
    STRUCT('Dr. Y.S. Rajasekhara Reddy ACA-VDCA Cricket Stadium', 'Dr. Y.S. Rajasekhara Reddy ACA-VDCA Cricket Stadium', 'Visakhapatnam'),
    STRUCT('Dr. Y.S. Rajasekhara Reddy ACA-VDCA Cricket Stadium, Visakhapatnam', 'Dr. Y.S. Rajasekhara Reddy ACA-VDCA Cricket Stadium', 'Visakhapatnam'),
    STRUCT('Dubai International Cricket Stadium', 'Dubai International Cricket Stadium', 'Dubai'),
    STRUCT('Eden Gardens', 'Eden Gardens', 'Kolkata'),
    STRUCT('Eden Gardens, Kolkata', 'Eden Gardens', 'Kolkata'),
    STRUCT('Green Park', 'Green Park', 'Kanpur'),
    STRUCT('Himachal Pradesh Cricket Association Stadium', 'Himachal Pradesh Cricket Association Stadium', 'Dharamsala'),
    STRUCT('Himachal Pradesh Cricket Association Stadium, Dharamsala', 'Himachal Pradesh Cricket Association Stadium', 'Dharamsala'),
    STRUCT('Holkar Cricket Stadium', 'Holkar Cricket Stadium', 'Indore'),
    STRUCT('JSCA International Stadium Complex', 'JSCA International Stadium Complex', 'Ranchi'),
    STRUCT('Kingsmead', 'Kingsmead', 'Durban'),
    STRUCT('M Chinnaswamy Stadium', 'M Chinnaswamy Stadium', 'Bengaluru'),
    STRUCT('M Chinnaswamy Stadium, Bengaluru', 'M Chinnaswamy Stadium', 'Bengaluru'),
    STRUCT('M.Chinnaswamy Stadium', 'M Chinnaswamy Stadium', 'Bengaluru'),
    STRUCT('MA Chidambaram Stadium', 'MA Chidambaram Stadium', 'Chennai'),
    STRUCT('MA Chidambaram Stadium, Chepauk', 'MA Chidambaram Stadium', 'Chennai'),
    STRUCT('MA Chidambaram Stadium, Chepauk, Chennai', 'MA Chidambaram Stadium', 'Chennai'),
    STRUCT('Maharaja Yadavindra Singh International Cricket Stadium, Mullanpur', 'Maharaja Yadavindra Singh International Cricket Stadium', 'Mullanpur'),
    STRUCT('Maharaja Yadavindra Singh International Cricket Stadium, New Chandigarh', 'Maharaja Yadavindra Singh International Cricket Stadium', 'Mullanpur'),
    STRUCT('Maharashtra Cricket Association Stadium', 'Maharashtra Cricket Association Stadium', 'Pune'),
    STRUCT('Maharashtra Cricket Association Stadium, Pune', 'Maharashtra Cricket Association Stadium', 'Pune'),
    STRUCT('Narendra Modi Stadium, Ahmedabad', 'Narendra Modi Stadium', 'Ahmedabad'),
    STRUCT('Nehru Stadium', 'Nehru Stadium', 'Kochi'),
    STRUCT('New Wanderers Stadium', 'New Wanderers Stadium', 'Johannesburg'),
    STRUCT('Newlands', 'Newlands', 'Cape Town'),
    STRUCT('OUTsurance Oval', 'OUTsurance Oval', 'Bloemfontein'),
    STRUCT('Punjab Cricket Association IS Bindra Stadium', 'Punjab Cricket Association IS Bindra Stadium', 'Mohali'),
    STRUCT('Punjab Cricket Association IS Bindra Stadium, Mohali', 'Punjab Cricket Association IS Bindra Stadium', 'Mohali'),
    STRUCT('Punjab Cricket Association IS Bindra Stadium, Mohali, Chandigarh', 'Punjab Cricket Association IS Bindra Stadium', 'Mohali'),
    STRUCT('Punjab Cricket Association Stadium, Mohali', 'Punjab Cricket Association IS Bindra Stadium', 'Mohali'),
    STRUCT('Rajiv Gandhi International Stadium', 'Rajiv Gandhi International Stadium', 'Hyderabad'),
    STRUCT('Rajiv Gandhi International Stadium, Uppal', 'Rajiv Gandhi International Stadium', 'Hyderabad'),
    STRUCT('Rajiv Gandhi International Stadium, Uppal, Hyderabad', 'Rajiv Gandhi International Stadium', 'Hyderabad'),
    STRUCT('Sardar Patel Stadium, Motera', 'Narendra Modi Stadium', 'Ahmedabad'),
    STRUCT('Saurashtra Cricket Association Stadium', 'Saurashtra Cricket Association Stadium', 'Rajkot'),
    STRUCT('Sawai Mansingh Stadium', 'Sawai Mansingh Stadium', 'Jaipur'),
    STRUCT('Sawai Mansingh Stadium, Jaipur', 'Sawai Mansingh Stadium', 'Jaipur'),
    STRUCT('Shaheed Veer Narayan Singh International Stadium', 'Shaheed Veer Narayan Singh International Stadium', 'Raipur'),
    STRUCT('Shaheed Veer Narayan Singh International Stadium, Raipur', 'Shaheed Veer Narayan Singh International Stadium', 'Raipur'),
    STRUCT('Sharjah Cricket Stadium', 'Sharjah Cricket Stadium', 'Sharjah'),
    STRUCT('Sheikh Zayed Stadium', 'Sheikh Zayed Stadium', 'Abu Dhabi'),
    STRUCT("St George's Park", "St George's Park", 'Port Elizabeth'),
    STRUCT('Subrata Roy Sahara Stadium', 'Maharashtra Cricket Association Stadium', 'Pune'),
    STRUCT('SuperSport Park', 'SuperSport Park', 'Centurion'),
    STRUCT('Vidarbha Cricket Association Stadium, Jamtha', 'Vidarbha Cricket Association Stadium', 'Nagpur'),
    STRUCT('Wankhede Stadium', 'Wankhede Stadium', 'Mumbai'),
    STRUCT('Wankhede Stadium, Mumbai', 'Wankhede Stadium', 'Mumbai'),
    STRUCT('Zayed Cricket Stadium, Abu Dhabi', 'Sheikh Zayed Stadium', 'Abu Dhabi')
  ])
),

team_clean AS (
  -- canonicalize the 4 franchise rename pairs consistently across all 5 team columns; NULLs pass through
  SELECT
    m.*,
    CASE m.team1
      WHEN 'Delhi Daredevils' THEN 'Delhi Capitals'
      WHEN 'Kings XI Punjab' THEN 'Punjab Kings'
      WHEN 'Royal Challengers Bangalore' THEN 'Royal Challengers Bengaluru'
      WHEN 'Rising Pune Supergiants' THEN 'Rising Pune Supergiant'
      ELSE m.team1
    END AS team1_clean,
    CASE m.team2
      WHEN 'Delhi Daredevils' THEN 'Delhi Capitals'
      WHEN 'Kings XI Punjab' THEN 'Punjab Kings'
      WHEN 'Royal Challengers Bangalore' THEN 'Royal Challengers Bengaluru'
      WHEN 'Rising Pune Supergiants' THEN 'Rising Pune Supergiant'
      ELSE m.team2
    END AS team2_clean,
    CASE m.toss_winner
      WHEN 'Delhi Daredevils' THEN 'Delhi Capitals'
      WHEN 'Kings XI Punjab' THEN 'Punjab Kings'
      WHEN 'Royal Challengers Bangalore' THEN 'Royal Challengers Bengaluru'
      WHEN 'Rising Pune Supergiants' THEN 'Rising Pune Supergiant'
      ELSE m.toss_winner
    END AS toss_winner_clean,
    CASE m.winner
      WHEN 'Delhi Daredevils' THEN 'Delhi Capitals'
      WHEN 'Kings XI Punjab' THEN 'Punjab Kings'
      WHEN 'Royal Challengers Bangalore' THEN 'Royal Challengers Bengaluru'
      WHEN 'Rising Pune Supergiants' THEN 'Rising Pune Supergiant'
      ELSE m.winner
    END AS winner_clean,
    CASE m.eliminator
      WHEN 'Delhi Daredevils' THEN 'Delhi Capitals'
      WHEN 'Kings XI Punjab' THEN 'Punjab Kings'
      WHEN 'Royal Challengers Bangalore' THEN 'Royal Challengers Bengaluru'
      WHEN 'Rising Pune Supergiants' THEN 'Rising Pune Supergiant'
      ELSE m.eliminator
    END AS eliminator_clean
  FROM `ipl-nao.ipl_db.ipl_match_info` m
),

base AS (
  SELECT
    t.filename,
    t.season,
    CAST(SUBSTR(t.season, 1, 4) AS INT64) AS season_start_year,
    t.match_number,
    t.date,
    t.team1_clean AS team1,
    t.team2_clean AS team2,
    vm.city_clean AS city,
    vm.venue_clean AS venue,
    COALESCE(t.neutral_venue = 1.0, FALSE) AS neutral_venue,
    t.toss_winner_clean AS toss_winner,
    t.toss_decision,
    t.winner_clean AS winner,
    t.win_type,
    t.win_margin,
    t.result,
    t.method,
    t.eliminator_clean AS eliminator,
    t.player_of_match,
    t.umpire1,
    t.umpire2,
    t.event_stage,
    CASE WHEN t.filename = '392186.yaml' THEN 9.333 ELSE t.target_overs END AS target_overs,
    t.target_runs,
    t.match_referee,
    t.tv_umpire,
    t.reserve_umpire,
    t.team1_impact_in,
    t.team1_impact_out,
    t.team2_impact_in,
    t.team2_impact_out,
    t.match_id
  FROM team_clean t
  JOIN venue_map vm ON t.venue = vm.raw_venue
),

home_calc AS (
  -- franchise -> home city, matched against the cleaned `city`. Punjab Kings is home at
  -- both Mohali and Mullanpur.
  SELECT
    b.*,
    (CASE b.team1
       WHEN 'Chennai Super Kings' THEN b.city = 'Chennai'
       WHEN 'Mumbai Indians' THEN b.city = 'Mumbai'
       WHEN 'Kolkata Knight Riders' THEN b.city = 'Kolkata'
       WHEN 'Delhi Capitals' THEN b.city = 'Delhi'
       WHEN 'Royal Challengers Bengaluru' THEN b.city = 'Bengaluru'
       WHEN 'Rajasthan Royals' THEN b.city = 'Jaipur'
       WHEN 'Sunrisers Hyderabad' THEN b.city = 'Hyderabad'
       WHEN 'Deccan Chargers' THEN b.city = 'Hyderabad'
       WHEN 'Gujarat Titans' THEN b.city = 'Ahmedabad'
       WHEN 'Gujarat Lions' THEN b.city = 'Rajkot'
       WHEN 'Lucknow Super Giants' THEN b.city = 'Lucknow'
       WHEN 'Pune Warriors' THEN b.city = 'Pune'
       WHEN 'Rising Pune Supergiant' THEN b.city = 'Pune'
       WHEN 'Kochi Tuskers Kerala' THEN b.city = 'Kochi'
       WHEN 'Punjab Kings' THEN b.city IN ('Mohali', 'Mullanpur')
       ELSE FALSE
     END) AS team1_home,
    (CASE b.team2
       WHEN 'Chennai Super Kings' THEN b.city = 'Chennai'
       WHEN 'Mumbai Indians' THEN b.city = 'Mumbai'
       WHEN 'Kolkata Knight Riders' THEN b.city = 'Kolkata'
       WHEN 'Delhi Capitals' THEN b.city = 'Delhi'
       WHEN 'Royal Challengers Bengaluru' THEN b.city = 'Bengaluru'
       WHEN 'Rajasthan Royals' THEN b.city = 'Jaipur'
       WHEN 'Sunrisers Hyderabad' THEN b.city = 'Hyderabad'
       WHEN 'Deccan Chargers' THEN b.city = 'Hyderabad'
       WHEN 'Gujarat Titans' THEN b.city = 'Ahmedabad'
       WHEN 'Gujarat Lions' THEN b.city = 'Rajkot'
       WHEN 'Lucknow Super Giants' THEN b.city = 'Lucknow'
       WHEN 'Pune Warriors' THEN b.city = 'Pune'
       WHEN 'Rising Pune Supergiant' THEN b.city = 'Pune'
       WHEN 'Kochi Tuskers Kerala' THEN b.city = 'Kochi'
       WHEN 'Punjab Kings' THEN b.city IN ('Mohali', 'Mullanpur')
       ELSE FALSE
     END) AS team2_home
  FROM base b
)

SELECT
  filename,
  season,
  season_start_year,
  match_number,
  date,
  team1,
  team2,
  city,
  venue,
  neutral_venue,
  CASE
    WHEN neutral_venue THEN NULL
    WHEN team1_home AND NOT team2_home THEN team1
    WHEN team2_home AND NOT team1_home THEN team2
    ELSE NULL
  END AS home_team,
  CASE
    WHEN neutral_venue THEN NULL
    WHEN team1_home AND NOT team2_home THEN team2
    WHEN team2_home AND NOT team1_home THEN team1
    ELSE NULL
  END AS away_team,
  toss_winner,
  toss_decision,
  winner,
  win_type,
  win_margin,
  result,
  method,
  eliminator,
  player_of_match,
  umpire1,
  umpire2,
  event_stage,
  target_overs,
  target_runs,
  match_referee,
  tv_umpire,
  reserve_umpire,
  team1_impact_in,
  team1_impact_out,
  team2_impact_in,
  team2_impact_out,
  match_id
FROM home_calc;
