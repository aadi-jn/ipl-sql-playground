# `ipl_match_info` — Data Quality Report

Source: `2026-08-20T10-01_export.csv` (1,243 rows, 31 columns, 2008-04-18 to 2026-05-31, no duplicate `match_id`/`filename`).

This report separates **real inconsistencies** (need cleaning) from **nulls that are actually correct business logic** (no action needed), so the redesign only fixes what's actually broken.

---

## 1. Real inconsistencies (need cleaning)

### 1.1 `venue` — the biggest issue. ~60 raw values, but far fewer actual stadiums.
The same physical ground is recorded under multiple strings — sometimes bare, sometimes with a trailing city, sometimes with a rename, sometimes with a punctuation slip. Examples:

| Group | Variants found |
|---|---|
| Chinnaswamy (Bangalore) | `M Chinnaswamy Stadium` (65), `M.Chinnaswamy Stadium` (15, stray period), `M Chinnaswamy Stadium, Bengaluru` |
| Delhi | `Feroz Shah Kotla` (old name), `Arun Jaitley Stadium` (renamed 2019), `Arun Jaitley Stadium, Delhi` |
| Mohali/Chandigarh | `Punjab Cricket Association Stadium, Mohali`, `Punjab Cricket Association IS Bindra Stadium`, `...IS Bindra Stadium, Mohali`, `...IS Bindra Stadium, Mohali, Chandigarh` (4 variants, one ground) |
| Hyderabad | `Rajiv Gandhi International Stadium`, `...Uppal`, `...Uppal, Hyderabad` |
| Chennai | `MA Chidambaram Stadium`, `...Chepauk`, `...Chepauk, Chennai` |
| Ahmedabad | `Sardar Patel Stadium, Motera` (old name) vs `Narendra Modi Stadium, Ahmedabad` (renamed 2021, same ground) |
| Also bare vs `, City` suffix pairs | `Wankhede Stadium` / `Wankhede Stadium, Mumbai`; `Eden Gardens` / `Eden Gardens, Kolkata`; `Brabourne Stadium` / `..., Mumbai`; `Dr DY Patil Sports Academy` / `..., Mumbai`; `Sawai Mansingh Stadium` / `..., Jaipur`; `Himachal Pradesh Cricket Association Stadium` / `..., Dharamsala`; `Maharashtra Cricket Association Stadium` / `..., Pune`; `Shaheed Veer Narayan Singh International Stadium` / `..., Raipur`; `Dr. Y.S. Rajasekhara Reddy ACA‑VDCA Cricket Stadium` / `..., Visakhapatnam`; `Maharaja Yadavindra Singh International Cricket Stadium, Mullanpur` / `..., New Chandigarh` |

**Fix for the new table:** build a `venue` dimension keyed by physical ground (with a canonical name + city + country), and map every raw variant to it. This is the single highest-value cleanup.

### 1.2 `city` — inconsistent within the same season, not just across seasons
Bangalore was administratively renamed Bengaluru, and most of the data reflects a clean cutover by season (pre-2017 = `Bangalore`, 2018+ = `Bengaluru`). But **2017 itself mixes both**: 7 matches say `Bangalore`, 1 match (`1082595.yaml`, 2017-04-08) says `Bengaluru` — same stadium, same season. This is a genuine data-entry inconsistency, not a rename boundary.

**Fix:** normalize to one canonical city name per venue (tie to the venue dimension above rather than storing city as free text per match).

### 1.3 `season` — mixed formats with no consistent rule
Values mix single-year (`2009`, `2013`, `2021`) and split-year (`2007/08`, `2009/10`, `2020/21`) with no clear pattern — e.g. `2009` and `2009/10` are *both present as distinct seasons* (IPL 2009 played Apr–May 2009 in South Africa, vs a separate `2009/10` season Mar–Apr 2010 — the label doesn't actually describe the year range consistently with `2007/08`'s convention). The schema comment flags this as a known string quirk but doesn't fix it.

**Fix:** derive a clean `season_year` (INT, the year the season *started*) or a canonical `YYYY` label, independent of the display string.

### 1.4 Team names — franchise renames, cleanly split by season boundary, but still fragment the franchise
Each of these switches cleanly at a season boundary (not intra-season, unlike the city issue above), so they're not data-entry errors, but they still mean one franchise is stored as 2+ distinct strings:
- `Delhi Daredevils` (≤2018) → `Delhi Capitals` (2019+)
- `Kings XI Punjab` (≤2020/21) → `Punjab Kings` (2021+)
- `Royal Challengers Bangalore` (≤2023) → `Royal Challengers Bengaluru` (2024+)
- `Rising Pune Supergiants` (2016) → `Rising Pune Supergiant` (2017, dropped the "s" after a trademark dispute)

Note `Gujarat Lions` (2016–17) and `Gujarat Titans` (2022+) are **not** the same franchise despite the shared "Gujarat" — different ownership, don't merge these.

**Fix:** add a `team_id`/canonical franchise name mapping so the renamed groups roll up together for history, while keeping the raw name available for display.

### 1.5 `target_overs` — one record uses a different unit notation than the rest
1,202 of 1,203 non-null values are plain integers (whole overs). One record (`392186.yaml`, 2009-04-21, D/L match) is `9.2` — cricket over.ball notation (9 overs + 2 balls), not a decimal fraction of an over like the rest of the column would imply.

**Fix:** decide on one representation (e.g. store overs and balls separately, or convert consistently to decimal overs) and correct this one record.

### 1.6 `neutral_venue` — boolean stored as a sparse flag with only one value ever populated
Column only ever contains `1` (77 rows) or blank (1,166 rows) — never `0`. NULL is being used to mean "not neutral," which is ambiguous (could also mean "unknown").

**Fix:** convert to a proper `BOOLEAN NOT NULL DEFAULT FALSE` in the new table.

---

## 2. Nulls that are correct — not bugs, just document the logic

These all checked out as internally consistent, so the new table should preserve the same logic rather than "fixing" them:

- **`match_number`** (null in 74 rows) — null exactly when `event_stage` is set (playoffs/qualifiers/final use a stage name instead of a league match number). 1:1 correlation confirmed.
- **`winner` / `win_type` / `win_margin`** — `win_type`/`win_margin` are null for all 25 tie/no-result matches (no margin makes sense there). `winner` itself is null only for the 9 "no result" (abandoned) matches; for the 16 "tie" matches, `winner` is still populated because it was decided by Super Over (`eliminator` also holds this).
- **`team1_impact_in/out`, `team2_impact_in/out`** — null for all matches before 2023 (Impact Player rule didn't exist until IPL 2023). ~950–976 nulls, exactly matching pre-2023 row counts.
- **`target_overs` / `target_runs`** nulls (6 rows) — all are "no result" matches with no second innings, so no target was ever set.
- **`city`** null (51 rows) — all in Dubai/Sharjah (UAE leg matches where city wasn't recorded, only venue).
- **`result`, `method`, `eliminator`, `event_stage`** — sparse by design (only populated for tie/no-result/D-L/knockout matches respectively). No inconsistency found within them.

## 3. Checked and clean
No issues found in: `filename`↔`match_id` correspondence, date format/parseability (all valid `YYYY-MM-DD`, range 2008–2026), `toss_winner`/`winner` always being one of `team1`/`team2`, `team1 == team2` (no self-matches), `win_margin` ranges (wickets 1–10, runs 1–146), duplicate `match_number` within a season, umpire1/umpire2 collisions, leading/trailing whitespace, or casing variants in name columns (umpires, referees, player_of_match).

---

## Next step
Ready to design the cleaned table — recommend splitting into a normalized `match` fact table plus small dimension tables for `venue` and `team` (with canonical-name mappings), and a derived `season_year`. Let me know if you want to start there.
