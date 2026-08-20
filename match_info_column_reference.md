# `ipl_match_info` — Column Reference

Companion to [schemas/ipl_match_info.sql](schemas/ipl_match_info.sql) and [match_info_data_quality_report.md](match_info_data_quality_report.md). This is the detailed, AI-friendly version — paste it into an agent's context before it writes queries against this table.

**Table:** `ipl-nao.ipl_db.ipl_match_info` · **Grain:** one row per match · **Primary key:** `match_id` (also join key to `ipl_batter_match_stats` / `ipl_bowler_match_stats`) · **Rows checked against:** `2026-08-20T10-01_export.csv`, 1,243 rows, 2008-04-18 to 2026-05-31.

---

### filename
- **Description:** Source YAML filename the match was parsed from.
- **Type:** STRING
- **Categories:** free text, 1,243 distinct (one per row)
- **Gotchas:** numeric prefix always equals `match_id` (verified, 0 mismatches) — prefer `match_id` as the join key, not this column.
- **Clarification:** —

### season
- **Description:** IPL season label.
- **Type:** STRING
- **Categories:** `2007/08`, `2009`, `2009/10`, `2011`, `2012`, `2013`, `2014`, `2015`, `2016`, `2017`, `2018`, `2019`, `2020/21`, `2021`, `2022`, `2023`, `2024`, `2025`, `2026` (19 values)
- **Gotchas:** mixes single-year and split-year formats with no consistent rule — don't sort or compare as a number or plain string. `2009` and `2009/10` are two genuinely different seasons, not a duplicate (IPL 2009 was played Apr–May 2009 entirely in South Africa; `2009/10` is a separate season Mar–Apr 2010). For chronological sort/filter, derive a `season_start_year` (first 4-digit year) instead of parsing this column directly.
- **Clarification:** —

### match_number
- **Description:** League-stage (round-robin) match sequence number within the season.
- **Type:** FLOAT64 (stored as float though values are whole numbers)
- **Categories:** numeric, not categorical
- **Gotchas:** NULL for every playoff/knockout match — confirmed 1:1 with `event_stage` being set (null here exactly when `event_stage` is non-null). Use `event_stage` to identify/label those rows instead.
- **Clarification:** —

### date
- **Description:** Match date.
- **Type:** STRING, ISO `YYYY-MM-DD` (not a DATE type)
- **Categories:** n/a
- **Gotchas:** stored as STRING — cast explicitly (e.g. `SAFE.PARSE_DATE('%Y-%m-%d', date)` in BigQuery) before doing date arithmetic or sorting. All 1,243 values verified parseable, range 2008-04-18 to 2026-05-31.
- **Clarification:** —

### team1
- **Description:** One of the two teams playing.
- **Type:** STRING
- **Categories:** 19 distinct franchise-name strings (see full list under `team2`, identical set)
- **Gotchas:** **not reliably the "home" team.** Checked empirically against each franchise's home city: `team1` is playing at its own home city only ~52% of the time, `team2` ~14%, neither ~34% (neutral venues / playoffs). Don't assume `team1`=home or any fixed batting/toss order. Also: franchise renames mean the same real-world team appears under different name strings by era — see gotcha under `winner` for the full rename list. `Gujarat Lions` and `Gujarat Titans` are **not** the same franchise despite the shared word — don't merge them.
- **Clarification:** —

### team2
- **Description:** The other team playing.
- **Type:** STRING
- **Categories:** `Chennai Super Kings`, `Deccan Chargers`, `Delhi Capitals`, `Delhi Daredevils`, `Gujarat Lions`, `Gujarat Titans`, `Kings XI Punjab`, `Kochi Tuskers Kerala`, `Kolkata Knight Riders`, `Lucknow Super Giants`, `Mumbai Indians`, `Pune Warriors`, `Punjab Kings`, `Rajasthan Royals`, `Rising Pune Supergiant`, `Rising Pune Supergiants`, `Royal Challengers Bangalore`, `Royal Challengers Bengaluru`, `Sunrisers Hyderabad`
- **Gotchas:** same as `team1`. `team1 == team2` never happens in the same row (verified).
- **Clarification:** —

### city
- **Description:** City the match was played in.
- **Type:** STRING
- **Categories:** 37 distinct values, spanning India, South Africa (2009 season), and UAE (2014 leg, some 2020s seasons)
- **Gotchas:** NULL for 2 rows — both Dubai/Sharjah UAE matches where only `venue` was recorded, not city. Also: `Bangalore`/`Bengaluru` overlap **within the same 2017 season** (not a clean rename cutover like the team-name renames) — one 2017 match is tagged `Bengaluru` while the other seven at the same stadium that season are tagged `Bangalore`. Treat as a data-entry inconsistency, not a real mid-season rename.
- **Clarification:** —

### venue
- **Description:** Stadium name.
- **Type:** STRING
- **Categories:** 60 raw distinct strings — but these map to noticeably fewer actual physical stadiums (see gotcha)
- **Gotchas:** **biggest data-quality issue in the table.** The same physical ground is recorded under multiple different strings: bare name vs. `"Name, City"` suffix (e.g. `Wankhede Stadium` / `Wankhede Stadium, Mumbai`), punctuation slips (`M Chinnaswamy Stadium` vs `M.Chinnaswamy Stadium`), and genuine renames of the same ground (`Feroz Shah Kotla` → `Arun Jaitley Stadium`; `Sardar Patel Stadium, Motera` → `Narendra Modi Stadium, Ahmedabad`). Do **not** `GROUP BY venue` for venue-level aggregates without normalizing first. Full variant list in [match_info_data_quality_report.md](match_info_data_quality_report.md) §1.1.
- **Clarification:** —

### neutral_venue
- **Description:** Flags a match played at a venue neutral to both competing teams (e.g. the 2009 season in South Africa, the 2014 UAE leg).
- **Type:** FLOAT64
- **Categories:** only `1` (true, 77 rows) or blank — there is no explicit `0`
- **Gotchas:** NULL is being used to mean "not neutral" here — treat NULL as false, not as "unknown," when filtering on this column. Recommend casting to a proper BOOLEAN with `DEFAULT FALSE` in any cleaned version of this table.
- **Clarification:** —

### toss_winner
- **Description:** Team that won the pre-match coin toss.
- **Type:** STRING
- **Categories:** same 19 franchise names as `team1`/`team2`
- **Gotchas:** always equals `team1` or `team2` for that row (verified, 0 exceptions).
- **Clarification:** —

### toss_decision
- **Description:** What the toss winner chose to do.
- **Type:** STRING
- **Categories:** `field` (825), `bat` (418) — no other values, no nulls
- **Gotchas:** none found.
- **Clarification:** —

### winner
- **Description:** Team that won the match.
- **Type:** STRING
- **Categories:** same 19 franchise names, or NULL
- **Gotchas:** NULL only for the 9 `no result` (abandoned) rows — always equals `team1` or `team2` otherwise (verified). For `tie` matches, `winner` **is** populated (decided by the Super Over/tie-breaker, see `eliminator`) even though `win_type`/`win_margin` are null. Franchise renames to be aware of when grouping by team over time: `Delhi Daredevils`→`Delhi Capitals` (2019), `Kings XI Punjab`→`Punjab Kings` (2021), `Royal Challengers Bangalore`→`Royal Challengers Bengaluru` (2024), `Rising Pune Supergiants`→`Rising Pune Supergiant` (2017, trademark dispute). Each switches cleanly at a season boundary (not mid-season).
- **Clarification:** A team **winning** the match and a player winning **Player of the Match** are independent — see `player_of_match` below. Don't assume the `player_of_match`'s team equals `winner`.

### win_type
- **Description:** Unit that `win_margin` is measured in.
- **Type:** STRING
- **Categories:** `wickets` (660), `runs` (558), else NULL
- **Gotchas:** NULL for all 25 tie/no-result matches (no conventional margin applies to those).
- **Clarification:** —

### win_margin
- **Description:** Size of the win, in the unit given by `win_type`.
- **Type:** FLOAT64
- **Categories:** numeric; verified ranges: wickets 1–10, runs 1–146
- **Gotchas:** NULL alongside `win_type` for tie/no-result matches. Unit depends on `win_type` — never aggregate or compare `win_margin` across both types without splitting first (a 10-wicket win and a 10-run win aren't the same "10").
- **Clarification:** —

### result
- **Description:** Special-case outcome flag. NULL means a normal decisive win/loss (the common case).
- **Type:** STRING
- **Categories:** `tie` (16), `no result` (9), else NULL (1,218 normal matches)
- **Gotchas:** don't read NULL here as "unknown" — it means "nothing unusual happened," and the actual outcome lives in `winner`/`win_type`/`win_margin`.
- **Clarification:** —

### method
- **Description:** Rain-affected target-reset method applied, if any (Duckworth–Lewis(–Stern)).
- **Type:** STRING
- **Categories:** `D/L` (23 rows), else NULL
- **Gotchas:** only one category ever appears; NULL = standard match, no target adjustment needed.
- **Clarification:** —

### eliminator
- **Description:** Team that won the match's tie-breaker; only populated for `tie` results.
- **Type:** STRING
- **Categories:** same 19 franchise names, or NULL
- **Gotchas:** non-null in exactly the 16 rows where `result = 'tie'`, and always equal to that row's `winner` — i.e. redundant with `winner` specifically for tie matches. **Not independently confirmed** whether every tie across all 19 seasons was resolved by a Super Over specifically, vs. an older bowl-out rule possibly used in the earliest seasons — flag this if the exact tie-break mechanism matters for your analysis.
- **Clarification:** —

### player_of_match
- **Description:** Player of the Match ("Man of the Match") award recipient.
- **Type:** STRING
- **Categories:** 321 distinct player names — free text, not a fixed enum
- **Gotchas:** NULL for the 9 `no result` matches (no award when the match doesn't complete). No casing/spacing duplicate variants found for this column (checked, unlike `venue`).
- **Clarification:** **The Player of the Match does not necessarily play for the winning team** — a standout individual performance in a losing effort (e.g. a century in a losing chase) can still win the award. Never assume `player_of_match`'s team equals `winner` without checking. This table alone can't tell you which team a player belonged to in a given match; that requires joining to `ipl_batter_match_stats` or `ipl_bowler_match_stats` on `match_id` (those tables weren't loaded into this session, so this clarification is stated per your instruction, not independently re-verified here — happy to cross-check the exact rate once those tables are imported).

### umpire1
- **Description:** One of the two on-field umpires.
- **Type:** STRING
- **Categories:** 76 distinct names
- **Gotchas:** never equal to `umpire2` in the same row (verified). No confirmed meaning to the `umpire1`/`umpire2` ordering (e.g. bowler's-end vs. striker's-end) — treat as an unordered pair unless you can confirm otherwise.
- **Clarification:** —

### umpire2
- **Description:** The other on-field umpire.
- **Type:** STRING
- **Categories:** 71 distinct names
- **Gotchas:** same as `umpire1`.
- **Clarification:** —

### event_stage
- **Description:** Named knockout/playoff stage; populated only for non-league matches (complement of `match_number`).
- **Type:** STRING
- **Categories:** `Final` (19), `Qualifier 2` (16), `Qualifier 1` (16), `Eliminator` (13), `Semi Final` (6), `Elimination Final` (3), `3rd Place Play-Off` (1)
- **Gotchas:** the playoff *format* has changed across seasons (older seasons used `Semi Final`, newer ones use the `Qualifier 1/2` + `Eliminator` format) — which stage names apply to which season hasn't been mapped out here; ask if you need that breakdown before building season-by-season playoff logic.
- **Clarification:** —

### target_overs
- **Description:** Overs allotted to the team batting second (the chase target) — 20 for a standard uninterrupted match, lower when reduced by weather/DLS.
- **Type:** FLOAT64
- **Categories:** mostly whole numbers 5–20; one exception (see gotcha)
- **Gotchas:** **one record (`filename = 392186.yaml`, 2009-04-21) has the value `9.2`, in cricket over.ball notation (9 overs + 2 balls) — not a decimal `9.2` overs.** Every other value in the column is a plain whole-over integer. This is a unit-format inconsistency, not a real "9.2 overs" — it must be corrected/normalized before any aggregate math on this column (e.g. `AVG(target_overs)` would be silently wrong including this row as-is).
- **Clarification:** —

### target_runs
- **Description:** Runs the second-batting team needs to win (the chase target).
- **Type:** FLOAT64
- **Categories:** numeric, 184 distinct values
- **Gotchas:** NULL for exactly the 6 `no result` matches with no second innings played (out of the 9 total `no result` rows — the other 3 had already started a chase before being abandoned).
- **Clarification:** —

### match_referee
- **Description:** Match referee (off-field official).
- **Type:** STRING
- **Categories:** 32 distinct names
- **Gotchas:** no nulls found.
- **Clarification:** —

### tv_umpire
- **Description:** Third/TV umpire.
- **Type:** STRING
- **Categories:** 84 distinct names
- **Gotchas:** 4 nulls (unrecorded in source).
- **Clarification:** —

### reserve_umpire
- **Description:** Reserve/fourth umpire.
- **Type:** STRING
- **Categories:** 81 distinct names
- **Gotchas:** 24 nulls (unrecorded in source; not checked whether this concentrates in older seasons where the role may not have existed yet).
- **Clarification:** —

### team1_impact_in / team1_impact_out / team2_impact_in / team2_impact_out
- **Description:** Substitute player brought on (`_in`) and the player replaced (`_out`) for that team under IPL's Impact Player rule.
- **Type:** STRING
- **Categories:** `team1_impact_in` 125 names, `team1_impact_out` 84 names, `team2_impact_in` 83 names, `team2_impact_out` 73 names
- **Gotchas:** **NULL for every match before the 2023 season** — the Impact Player rule didn't exist until IPL 2023, confirmed 1:1 (all nulls fall exactly in pre-2023 rows; ~950–976 nulls out of 1,243, matching the pre-2023 row count almost exactly). Treat pre-2023 nulls as "rule didn't exist," not "no substitution happened."
- **Clarification:** —

### match_id
- **Description:** Unique numeric match identifier. Primary key of this table.
- **Type:** INT64
- **Categories:** 1,243 distinct values, no duplicates
- **Gotchas:** matches the numeric portion of `filename` exactly (verified, 0 mismatches). Use this — not `filename` — as the join key to `ipl_batter_match_stats` / `ipl_bowler_match_stats`.
- **Clarification:** —
