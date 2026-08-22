# `match_info_v2` — Column Reference

Companion to [schemas/match_info_v2.sql](schemas/match_info_v2.sql). This is the cleaned v2 of
[`ipl_match_info`](match_info_column_reference.md) — same grain (one row per match, PK
`match_id`), same 31 original columns, plus 3 new ones (`season_start_year`, `home_team`,
`away_team`). The original `ipl_match_info` table is left unmodified; this is a separate table
built from it. This is the AI-friendly version — paste it into an agent's context before it
writes queries against this table.

**Table:** `ipl-nao.ipl_db.match_info_v2` · **Grain:** one row per match · **Primary key:**
`match_id` (also join key to `ipl_batter_match_stats` / `ipl_bowler_match_stats`) · **Rows
checked:** 1,243 rows (identical row count to `ipl_match_info`), 2008-04-18 to 2026-05-31.

**If you were using `ipl_match_info`, read this first:** venue and city are now canonical (no
normalization needed before `GROUP BY`), team names are canonicalized (no rename pairs left to
merge), `neutral_venue` is a proper BOOL, the `target_overs` unit-format outlier is fixed, and
two new derived columns (`home_team`/`away_team`) exist so you don't have to compute
home-advantage yourself.

---

### filename
- **Description:** Source YAML filename the match was parsed from. Unchanged from `ipl_match_info`.
- **Type:** STRING
- **Categories:** free text, 1,243 distinct (one per row)
- **Gotchas:** numeric prefix always equals `match_id` — prefer `match_id` as the join key.
- **Clarification:** —

### season
- **Description:** IPL season label, raw and unchanged. Use `season_start_year` (below) for
  chronological sort/filter/comparison instead of parsing this column.
- **Type:** STRING
- **Categories:** `2007/08`, `2009`, `2009/10`, `2011`–`2026` (19 values)
- **Gotchas:** mixes single-year and split-year formats — `2009` and `2009/10` are two genuinely
  different seasons, not a duplicate.
- **Clarification:** —

### season_start_year — NEW
- **Description:** First 4-digit year parsed out of `season` (e.g. `2007/08` → `2007`,
  `2020/21` → `2020`, `2009` → `2009`). Purely derived — `season` itself is untouched.
- **Type:** INT64
- **Categories:** 2007–2026, one value per season
- **Gotchas:** none — this is a straight `CAST(SUBSTR(season, 1, 4) AS INT64)`. Safe to sort,
  filter, or bucket by.
- **Clarification:** —

### match_number
- **Description:** League-stage (round-robin) match sequence number within the season. Unchanged.
- **Type:** FLOAT64
- **Gotchas:** NULL for every playoff/knockout match (use `event_stage` for those rows instead).
- **Clarification:** —

### date
- **Description:** Match date. Unchanged.
- **Type:** STRING, ISO `YYYY-MM-DD` (not a DATE type)
- **Gotchas:** cast explicitly (`SAFE.PARSE_DATE('%Y-%m-%d', date)` in BigQuery) before date
  arithmetic.
- **Clarification:** —

### team1 / team2 — CHANGED (canonicalized)
- **Description:** The two teams playing. Franchise-name strings are now canonical — the 4
  rename pairs below are merged, applied consistently across `team1`, `team2`, `winner`,
  `toss_winner`, and `eliminator`.
- **Type:** STRING
- **Categories:** 15 distinct franchise names (down from 19 raw strings):
  `Chennai Super Kings`, `Deccan Chargers`, `Delhi Capitals`, `Gujarat Lions`, `Gujarat Titans`,
  `Kochi Tuskers Kerala`, `Kolkata Knight Riders`, `Lucknow Super Giants`, `Mumbai Indians`,
  `Pune Warriors`, `Punjab Kings`, `Rajasthan Royals`, `Rising Pune Supergiant`,
  `Royal Challengers Bengaluru`, `Sunrisers Hyderabad`
- **Gotchas:** merged pairs — `Delhi Daredevils`→`Delhi Capitals`,
  `Kings XI Punjab`→`Punjab Kings`, `Royal Challengers Bangalore`→`Royal Challengers Bengaluru`,
  `Rising Pune Supergiants`→`Rising Pune Supergiant`. **`Gujarat Lions` and `Gujarat Titans` are
  kept SEPARATE** — different franchises despite the shared word, do not merge them.
  `team1`/`team2` still aren't reliably "home"/"away" in fixed order — use the new `home_team`/
  `away_team` columns instead of guessing from `team1`.
- **Clarification:** —

### city — CHANGED (now derived from cleaned venue)
- **Description:** City the match was played in. Re-derived from the cleaned `venue` (not from
  the raw `city` column), so every canonical venue maps to exactly one city.
- **Type:** STRING
- **Categories:** 34 distinct values, spanning India, South Africa (2009 season), and UAE
- **Gotchas:** **no NULLs** (down from 2 in `ipl_match_info` — the Dubai/Sharjah rows now get
  city filled in from the venue). The 2017 Bangalore/Bengaluru intra-season split is gone — any
  M Chinnaswamy Stadium match is always `Bengaluru`. The Mohali ground's city is fixed to
  `Mohali` and the Mullanpur ground's city to `Mullanpur` (kept distinct on purpose — both are
  Punjab Kings home venues, see `home_team`).
- **Clarification:** —

### venue — CHANGED (canonicalized)
- **Description:** Stadium name, canonicalized to one string per physical ground.
- **Type:** STRING
- **Categories:** 36 distinct canonical grounds (down from 60 raw strings in `ipl_match_info`).
  Full list (venue — city — row count):
  Arun Jaitley Stadium — Delhi — 104 · Barabati Stadium — Cuttack — 7 · Barsapara Cricket
  Stadium — Guwahati — 8 · Bharat Ratna Shri Atal Bihari Vajpayee Ekana Cricket Stadium —
  Lucknow — 29 · Brabourne Stadium — Mumbai — 27 · Buffalo Park — East London — 3 · De Beers
  Diamond Oval — Kimberley — 3 · Dr DY Patil Sports Academy — Mumbai — 37 · Dr. Y.S.
  Rajasekhara Reddy ACA-VDCA Cricket Stadium — Visakhapatnam — 17 · Dubai International
  Cricket Stadium — Dubai — 46 · Eden Gardens — Kolkata — 107 · Green Park — Kanpur — 4 ·
  Himachal Pradesh Cricket Association Stadium — Dharamsala — 19 · Holkar Cricket Stadium —
  Indore — 9 · JSCA International Stadium Complex — Ranchi — 7 · Kingsmead — Durban — 15 ·
  M Chinnaswamy Stadium — Bengaluru — 104 · MA Chidambaram Stadium — Chennai — 98 · Maharaja
  Yadavindra Singh International Cricket Stadium — Mullanpur — 17 · Maharashtra Cricket
  Association Stadium — Pune — 51 · Narendra Modi Stadium — Ahmedabad — 53 · Nehru Stadium —
  Kochi — 5 · New Wanderers Stadium — Johannesburg — 8 · Newlands — Cape Town — 7 · OUTsurance
  Oval — Bloemfontein — 2 · Punjab Cricket Association IS Bindra Stadium — Mohali — 61 · Rajiv
  Gandhi International Stadium — Hyderabad — 90 · Saurashtra Cricket Association Stadium —
  Rajkot — 10 · Sawai Mansingh Stadium — Jaipur — 68 · Shaheed Veer Narayan Singh
  International Stadium — Raipur — 8 · Sharjah Cricket Stadium — Sharjah — 28 · Sheikh Zayed
  Stadium — Abu Dhabi — 37 · St George's Park — Port Elizabeth — 7 · SuperSport Park —
  Centurion — 12 · Vidarbha Cricket Association Stadium — Nagpur — 3 · Wankhede Stadium —
  Mumbai — 132
- **Gotchas:** collapses bare/`", City"`-suffix duplicates, punctuation slips (`M
  Chinnaswamy Stadium` vs `M.Chinnaswamy Stadium`), and genuine ground renames: `Feroz Shah
  Kotla` → `Arun Jaitley Stadium`; `Sardar Patel Stadium, Motera` → `Narendra Modi Stadium`;
  `Subrata Roy Sahara Stadium` → `Maharashtra Cricket Association Stadium`; `Zayed Cricket
  Stadium, Abu Dhabi` → `Sheikh Zayed Stadium` (the last two confirmed by checking that the two
  raw names never co-occur in the same season — consistent with a rename partway through a
  ground's tenure, not two different grounds). `GROUP BY venue` is now safe to use directly for
  venue-level aggregates. Full raw→canonical mapping is in
  [schemas/match_info_v2.sql](schemas/match_info_v2.sql).
- **Clarification:** —

### neutral_venue — CHANGED (type)
- **Description:** Flags a match played at a venue neutral to both competing teams (e.g. the
  2009 season in South Africa, the 2014 UAE leg).
- **Type:** BOOL, **NOT NULL** (was FLOAT64 1.0/NULL in `ipl_match_info`)
- **Categories:** `TRUE` (77 rows), `FALSE` (1,166 rows) — no NULLs
- **Gotchas:** none — the FLOAT64→BOOL conversion (`1.0`→`TRUE`, `NULL`→`FALSE`) is exactly the
  DEFAULT-FALSE cast recommended in the `ipl_match_info` reference doc.
- **Clarification:** —

### home_team — NEW
- **Description:** Which of `team1`/`team2` was playing at its own home city for this match,
  derived from a fixed franchise → home-city table matched against the cleaned `city`.
- **Type:** STRING (nullable)
- **Categories:** same 15 canonical franchise names, or NULL
- **Gotchas:** **NULL in 412 of 1,243 rows** — 77 of those are `neutral_venue = TRUE` (both
  columns always NULL together in that case, verified); the remaining 335 are non-neutral
  matches where the match city doesn't match either team's home city (e.g. a Kolkata Knight
  Riders vs. Sunrisers Hyderabad match played at a third city, or a playoff at a venue that
  isn't either finalist's home). Franchise → home-city table used:
  Chennai Super Kings→Chennai, Mumbai Indians→Mumbai, Kolkata Knight Riders→Kolkata, Delhi
  Capitals→Delhi, Royal Challengers Bengaluru→Bengaluru, Rajasthan Royals→Jaipur, Sunrisers
  Hyderabad→Hyderabad, Deccan Chargers→Hyderabad, Gujarat Titans→Ahmedabad, Gujarat
  Lions→Rajkot, Lucknow Super Giants→Lucknow, Pune Warriors→Pune, Rising Pune
  Supergiant→Pune, Kochi Tuskers Kerala→Kochi, **Punjab Kings→Mohali OR Mullanpur (both count
  as home)** — spot-checked: Punjab Kings matches at both Mohali (e.g. match_id 1175368,
  2019) and Mullanpur (e.g. match_id 1426275, 2024) both correctly resolve `home_team =
  'Punjab Kings'`. If both teams' home cities happen to match the match city (a degenerate
  case that doesn't occur in this dataset — no two co-existing franchises ever share a home
  city and play each other), this also resolves to NULL rather than guessing.
- **Clarification:** derived, not sourced from raw data — recompute from `schemas/match_info_v2.sql`
  if the franchise→home-city table needs to change (e.g. a franchise relocates).

### away_team — NEW
- **Description:** The other team in the match when `home_team` is non-NULL — i.e. whichever of
  `team1`/`team2` is not the home team.
- **Type:** STRING (nullable)
- **Categories:** same 15 canonical franchise names, or NULL
- **Gotchas:** NULL exactly when `home_team` is NULL (same 412 rows, verified). Not simply
  "the other of team1/team2" when both are NULL — in the neutral/neither-home case there is no
  designated away team either.
- **Clarification:** —

### toss_winner — CHANGED (canonicalized)
- **Description:** Team that won the pre-match coin toss. Same franchise-name canonicalization
  as `team1`/`team2` applied here (NULLs, if any, preserved).
- **Type:** STRING
- **Categories:** same 15 canonical franchise names
- **Gotchas:** always equals `team1` or `team2` for that row.
- **Clarification:** —

### toss_decision
- **Description:** What the toss winner chose to do. Unchanged.
- **Type:** STRING
- **Categories:** `field` (825), `bat` (418) — no nulls
- **Gotchas:** none.
- **Clarification:** —

### winner — CHANGED (canonicalized)
- **Description:** Team that won the match. Same franchise-name canonicalization as `team1`/
  `team2`.
- **Type:** STRING
- **Categories:** same 15 canonical franchise names, or NULL
- **Gotchas:** NULL only for the 9 `no result` (abandoned) rows. No rename pairs left to worry
  about when grouping by team over time — `Delhi Daredevils`, `Kings XI Punjab`, `Royal
  Challengers Bangalore`, `Rising Pune Supergiants` no longer appear anywhere in this table.
- **Clarification:** a team **winning** the match and a player winning **Player of the Match**
  are independent — see `player_of_match` below.

### win_type
- **Description:** Unit that `win_margin` is measured in. Unchanged.
- **Type:** STRING
- **Categories:** `wickets` (660), `runs` (558), else NULL
- **Gotchas:** NULL for all 25 tie/no-result matches.
- **Clarification:** —

### win_margin
- **Description:** Size of the win, in the unit given by `win_type`. Unchanged.
- **Type:** FLOAT64
- **Gotchas:** unit depends on `win_type` — never mix wickets and runs in one aggregate.
- **Clarification:** —

### result
- **Description:** Special-case outcome flag. Unchanged.
- **Type:** STRING
- **Categories:** `tie` (16), `no result` (9), else NULL (1,218 normal matches)
- **Gotchas:** NULL means "nothing unusual happened," not "unknown."
- **Clarification:** —

### method
- **Description:** Rain-affected target-reset method applied, if any. Unchanged.
- **Type:** STRING
- **Categories:** `D/L` (23 rows), else NULL
- **Gotchas:** —
- **Clarification:** —

### eliminator — CHANGED (canonicalized)
- **Description:** Team that won the match's tie-breaker; only populated for `tie` results.
  Same franchise-name canonicalization as `team1`/`team2`.
- **Type:** STRING
- **Categories:** same 15 canonical franchise names, or NULL
- **Gotchas:** non-null in exactly the 16 rows where `result = 'tie'`, always equal to that
  row's `winner`.
- **Clarification:** —

### player_of_match
- **Description:** Player of the Match award recipient. Unchanged.
- **Type:** STRING
- **Categories:** 321 distinct player names
- **Gotchas:** NULL for the 9 `no result` matches. Doesn't necessarily play for the winning
  team.
- **Clarification:** —

### umpire1 / umpire2
- **Description:** The two on-field umpires. Unchanged.
- **Type:** STRING
- **Gotchas:** unordered pair, never equal within a row.
- **Clarification:** —

### event_stage
- **Description:** Named knockout/playoff stage. Unchanged.
- **Type:** STRING
- **Categories:** `Final` (19), `Qualifier 2` (16), `Qualifier 1` (16), `Eliminator` (13),
  `Semi Final` (6), `Elimination Final` (3), `3rd Place Play-Off` (1)
- **Gotchas:** playoff format has changed across seasons.
- **Clarification:** —

### target_overs — CHANGED (outlier fixed)
- **Description:** Overs allotted to the team batting second (the chase target).
- **Type:** FLOAT64
- **Gotchas:** the single outlier row (`filename = '392186.yaml'`, 2009-04-21) that stored `9.2`
  in cricket over.ball notation (9 overs + 2 balls) is now corrected to decimal overs `9.333`.
  Every other value was already a valid whole-number decimal and is unchanged. Safe to
  `AVG()`/aggregate directly now.
- **Clarification:** —

### target_runs
- **Description:** Runs the second-batting team needs to win. Unchanged.
- **Type:** FLOAT64
- **Gotchas:** NULL for 6 of the 9 `no result` matches (the other 3 had a chase already
  underway).
- **Clarification:** —

### match_referee
- **Description:** Match referee (off-field official). Unchanged.
- **Type:** STRING
- **Categories:** 32 distinct names
- **Gotchas:** no nulls.
- **Clarification:** —

### tv_umpire
- **Description:** Third/TV umpire. Unchanged.
- **Type:** STRING
- **Gotchas:** 4 nulls.
- **Clarification:** —

### reserve_umpire
- **Description:** Reserve/fourth umpire. Unchanged.
- **Type:** STRING
- **Gotchas:** 24 nulls.
- **Clarification:** —

### team1_impact_in / team1_impact_out / team2_impact_in / team2_impact_out
- **Description:** Substitute brought on (`_in`) and player replaced (`_out`) under IPL's
  Impact Player rule. Unchanged.
- **Type:** STRING
- **Gotchas:** NULL for every match before the 2023 season (rule didn't exist yet).
- **Clarification:** —

### match_id
- **Description:** Unique numeric match identifier. Primary key of this table. Unchanged.
- **Type:** INT64
- **Categories:** 1,243 distinct values, no duplicates
- **Gotchas:** matches the numeric portion of `filename`. Use this — not `filename` — as the
  join key to `ipl_batter_match_stats` / `ipl_bowler_match_stats`.
- **Clarification:** —
