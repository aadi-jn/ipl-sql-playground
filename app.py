"""BigQuery SQL Playground.

A single-page Streamlit app that lets workshop attendees run read-only SQL against
the IPL warehouse (project `ipl-nao`, dataset `ipl_db`), see results or BigQuery's
own error message, and download results as CSV. Four tables can be previewed, each
with a copyable schema to paste into their AI agent.

Read-only is enforced by the service account's IAM roles (dataViewer + jobUser), not
by this app. `maximum_bytes_billed` caps any runaway scan so nothing can cost money.

Theme: Light by default (`.streamlit/config.toml`); users switch to dark via the
top-right ⋮ → Settings → Theme menu, which re-themes everything including the table.

Secrets (set in Streamlit Cloud's Secrets UI, or a local .streamlit/secrets.toml):
    app_password = "..."
    [gcp_service_account]
    <contents of the service-account JSON key as a TOML table>
"""

from __future__ import annotations

from pathlib import Path

import pandas as pd
import streamlit as st
from google.cloud import bigquery
from google.oauth2 import service_account

# --- Constants ----------------------------------------------------------------
PROJECT_ID = "ipl-nao"
DATASET_ID = "ipl_db"
LOCATION = "asia-south1"
MAX_BYTES_BILLED = 100_000_000  # ~100 MB; the whole dataset is ~6 MB, so this is safe and free
PREVIEW_ROWS = 50
TABLES = [
    "ipl_match_info",
    "ipl_players",
    "ipl_batter_match_stats",
    "ipl_bowler_match_stats",
    "match_info_v2",
]
# Columns stored as INT64 epoch NANOSECONDS in BigQuery; shown as dates, not numbers.
DATE_NANOS_COLS = {"match_date"}
SCHEMA_DIR = Path(__file__).parent / "schemas"

st.set_page_config(page_title="IPL SQL Playground", page_icon="🏏", layout="wide")


# --- Auth ---------------------------------------------------------------------
def check_password() -> bool:
    """Gate the app behind a single shared password held in secrets."""
    if st.session_state.get("authed"):
        return True

    st.title("🏏 IPL SQL Playground")
    st.caption("Enter the workshop password to continue.")
    entered = st.text_input("Password", type="password")
    if entered:
        if entered == st.secrets.get("app_password"):
            st.session_state["authed"] = True
            st.rerun()
        else:
            st.error("Incorrect password.")
    return False


# --- BigQuery -----------------------------------------------------------------
@st.cache_resource
def get_client() -> bigquery.Client:
    creds = service_account.Credentials.from_service_account_info(
        dict(st.secrets["gcp_service_account"])
    )
    return bigquery.Client(project=PROJECT_ID, credentials=creds, location=LOCATION)


def run_query(sql: str) -> tuple[pd.DataFrame | None, int, str | None]:
    """Run a query. Returns (dataframe, bytes_processed, error_message)."""
    client = get_client()
    job_config = bigquery.QueryJobConfig(maximum_bytes_billed=MAX_BYTES_BILLED)
    try:
        job = client.query(sql, job_config=job_config)
        # create_bqstorage_client=False keeps us on the REST path, so the SA needs
        # only jobUser + dataViewer (no bigquery.readsessions.create). Results are
        # small, so there's no speed cost.
        df = job.result().to_dataframe(create_bqstorage_client=False)
        return df, job.total_bytes_processed or 0, None
    except Exception as exc:  # surface BigQuery's own message to the user
        return None, 0, str(exc)


@st.cache_data(ttl=3600)
def preview(table: str) -> pd.DataFrame:
    sql = f"SELECT * FROM `{PROJECT_ID}.{DATASET_ID}.{table}` LIMIT {PREVIEW_ROWS}"
    df, _, err = run_query(sql)
    if err:
        raise RuntimeError(err)
    return df


@st.cache_data(ttl=3600)
def load_schema(table: str) -> str:
    path = SCHEMA_DIR / f"{table}.sql"
    return path.read_text() if path.exists() else f"-- schema file for {table} not found"


# --- Display helpers ----------------------------------------------------------
def prepare_for_display(df: pd.DataFrame) -> tuple[pd.DataFrame, dict]:
    """Make a dataframe read as it does in BigQuery, working around Streamlit's grid:

    - BOOL columns -> 'true'/'false' text instead of checkboxes.
    - `match_date` (INT64 epoch nanoseconds) -> a readable 'YYYY-MM-DD' date.
    - String columns forced to TextColumn so ISO-date strings aren't auto-rendered
      as epoch numbers.
    Returns (display_df, column_config) for st.dataframe.
    """
    df = df.copy()
    col_config: dict = {}
    for col in df.columns:
        s = df[col]
        if pd.api.types.is_bool_dtype(s):
            df[col] = s.map({True: "true", False: "false"}).astype("object")
            col_config[col] = st.column_config.TextColumn(col)
        elif col in DATE_NANOS_COLS and pd.api.types.is_integer_dtype(s):
            df[col] = pd.to_datetime(s, unit="ns", errors="coerce").dt.strftime("%Y-%m-%d")
            col_config[col] = st.column_config.TextColumn(col)
        elif pd.api.types.is_object_dtype(s) or pd.api.types.is_string_dtype(s):
            col_config[col] = st.column_config.TextColumn(col)
    return df, col_config


def show_dataframe(df: pd.DataFrame, **kwargs) -> None:
    disp, cfg = prepare_for_display(df)
    st.dataframe(disp, column_config=cfg, width="stretch", **kwargs)


def looks_read_only(sql: str) -> bool:
    """Friendly client-side check. The SA's IAM role is the real safeguard."""
    stripped = sql.strip().rstrip(";").lstrip().lower()
    return stripped.startswith(("select", "with"))


def human_bytes(n: float) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024
    return f"{n:.1f} GB"


# --- UI -----------------------------------------------------------------------
def main() -> None:
    st.title("🏏 IPL SQL Playground")
    st.caption(
        f"Read-only queries against `{PROJECT_ID}.{DATASET_ID}` (BigQuery, {LOCATION}). "
        "Write your query with your AI agent, paste it below, and run. "
        "Switch light/dark via the ⋮ menu, top-right."
    )

    with st.expander("📋 Preview the tables (50 rows each) + copy schemas", expanded=False):
        tabs = st.tabs(TABLES)
        for tab, table in zip(tabs, TABLES):
            with tab:
                try:
                    df = preview(table)
                    st.caption(f"`{table}` — showing {len(df)} rows · {len(df.columns)} columns")
                    show_dataframe(df, height=300)
                except Exception as exc:
                    st.error("Could not load preview:")
                    st.code(str(exc), language="text")
                with st.popover("📄 Copy schema (for your AI agent)"):
                    st.caption("Click the copy icon (top-right of the box), then paste into your agent.")
                    st.code(load_schema(table), language="sql")

    st.subheader("Run a query")
    sql = st.text_area(
        "SQL",
        height=180,
        placeholder="SELECT * FROM ipl_db.ipl_players LIMIT 10",
        label_visibility="collapsed",
    )
    run = st.button("▶ Run query", type="primary")

    if run:
        if not sql.strip():
            st.warning("Enter a query first.")
            return
        if not looks_read_only(sql):
            st.error("Only SELECT / WITH queries are allowed. (This warehouse is read-only.)")
            return

        with st.spinner("Running…"):
            df, processed, err = run_query(sql)

        if err:
            st.error("❌ Query failed — copy the message below with the icon on its right:")
            st.code(err, language="text")
            return

        st.success(f"{len(df):,} rows · {human_bytes(processed)} processed")
        show_dataframe(df)
        st.download_button(
            "⬇ Download CSV",
            data=df.to_csv(index=False).encode("utf-8"),
            file_name="query_results.csv",
            mime="text/csv",
        )


if check_password():
    main()
