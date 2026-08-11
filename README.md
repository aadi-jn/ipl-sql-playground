# IPL SQL Playground

A tiny Streamlit app that lets workshop attendees run **read-only** SQL against the
IPL BigQuery warehouse (`ipl-nao.ipl_db`), see results or BigQuery's error message,
and download output as CSV. Attendees write queries with their own AI agent, then
paste and run them here — no GCP/BigQuery account needed.

## Features
- **Query runner** — paste SQL, run it, get a results table. A friendly SELECT/WITH-only
  check runs client-side (the real safeguard is the read-only service account).
- **Errors are copyable** — BigQuery's own error message is shown in a code block with a
  one-click copy icon, so attendees can paste it back to their AI agent.
- **CSV download** of any result set.
- **Table preview** — 4 tabs, 50 rows each, with a **"Copy schema"** button per table that
  hands over an annotated `CREATE TABLE` (with data-trap notes) to paste into an agent.
- **Light by default**, with a working dark toggle via the top-right **⋮ → Settings → Theme**
  (Streamlit re-themes everything, including the results grid — set in `.streamlit/config.toml`).

## Safety & cost
- **Read-only** is enforced by the service account's IAM roles (`dataViewer` + `jobUser`),
  not by app code. Writes are physically impossible (verified: `DELETE` returns Access Denied).
- **Cost is ~$0**: the whole dataset is ~6 MB (queries scan a few MB vs the 1 TB/month free
  tier). `maximum_bytes_billed` (~100 MB) makes any runaway query *error*, not cost.
- Access is gated by a single **shared password**.

## The 4 tables & known data quirks
`ipl_match_info`, `ipl_players`, `ipl_batter_match_stats`, `ipl_bowler_match_stats`.

The app normalizes a few BigQuery storage quirks **at display time only** (the tables are
never modified). Full details live in `schemas/*.sql`:
- **`match_date`** (batter & bowler tables) is stored as `INT64` epoch **nanoseconds**
  (e.g. `1208476800000000000` = `2008-04-18`). Shown as a readable date in the app.
  In SQL: `DATE(TIMESTAMP_MICROS(CAST(match_date/1000 AS INT64)))`.
- **`date`** (match_info) is a `STRING` `'YYYY-MM-DD'`, not a DATE type. Shown as literal
  text (Streamlit would otherwise auto-render ISO strings as epoch numbers).
- **BOOLEAN** columns (`dismissed`, `not_out`, `is_duck`, `is_player_of_match`) are shown as
  `true`/`false` text instead of Streamlit's default checkboxes.

## Files
```
.
├── app.py                     # the Streamlit app
├── requirements.txt           # streamlit, google-cloud-bigquery, pandas, db-dtypes
├── schemas/                   # one annotated schema per table (served by "Copy schema")
│   ├── ipl_match_info.sql
│   ├── ipl_players.sql
│   ├── ipl_batter_match_stats.sql
│   └── ipl_bowler_match_stats.sql
├── .streamlit/
│   ├── config.toml            # Light theme default (committed)
│   ├── secrets.toml.example    # template (committed)
│   └── secrets.toml            # real password + SA key (GIT-IGNORED — never commit)
└── README.md
```

## Run locally
```bash
pip install -r requirements.txt
# put the SA key + password in .streamlit/secrets.toml (see secrets.toml.example)
streamlit run app.py
```

## One-time GCP setup (dedicated read-only service account)
Already done for this project. To reproduce, run with the GA4 impersonation disabled
(it otherwise shadows access to `ipl-nao`):
```bash
export CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT=""

gcloud iam service-accounts create bq-playground \
  --project=ipl-nao --display-name="BQ Playground (read-only)"

gcloud projects add-iam-policy-binding ipl-nao \
  --member="serviceAccount:bq-playground@ipl-nao.iam.gserviceaccount.com" \
  --role="roles/bigquery.jobUser" --condition=None

# dataViewer scoped to the dataset via its ACL (bq add-iam-policy-binding needs
# allowlisting, so edit the dataset access list instead — mirrors the nao-run grant):
#   bq show --format=prettyjson ipl-nao:ipl_db  -> add
#   {"role":"READER","userByEmail":"bq-playground@ipl-nao.iam.gserviceaccount.com"}
#   -> bq update --source <edited.json> ipl-nao:ipl_db

gcloud iam service-accounts keys create bq-playground-key.json \
  --iam-account=bq-playground@ipl-nao.iam.gserviceaccount.com
```
The key goes only into `.streamlit/secrets.toml` (local) or the Streamlit Cloud Secrets UI.
Never commit it — it's git-ignored.

> **Note on `to_dataframe`:** results are fetched with `create_bqstorage_client=False` so the
> SA needs only `jobUser` + `dataViewer` (not the extra `bigquery.readsessions.create` the
> BigQuery Storage API would require). Results are tiny, so there's no speed cost.

## Deploy (free, Streamlit Community Cloud)
1. This repo is public and contains code only (no key).
2. share.streamlit.io → New app → repo `aadi-jn/ipl-sql-playground`, main file `app.py`.
3. In the app's **Secrets**, paste `app_password` and the `[gcp_service_account]` block
   (contents of the key JSON, as TOML — see `secrets.toml.example`).
