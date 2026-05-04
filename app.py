"""
Local read-only browser UI for the VideoPlatform schema (project.sql + seed_sample_data.sql).
Copy env.example to .env and set MYSQL_PASSWORD (and user if needed).
"""

import os
from contextlib import contextmanager
from pathlib import Path
from urllib.parse import unquote, urlparse

import mysql.connector
from dotenv import load_dotenv
from flask import Flask, render_template
from mysql.connector import errors as mysql_errors

# Always load .env from this folder (not the shell cwd).
load_dotenv(Path(__file__).resolve().parent / ".env")

app = Flask(__name__)


def _mysql_database_name(path_from_url: str = "") -> str:
    """Railway may inject MYSQL_DATABASE=railway from the plugin; MYSQL_DATABASE_OVERRIDE wins."""
    override = (os.environ.get("MYSQL_DATABASE_OVERRIDE") or os.environ.get("MYSQL_DATABASE") or "").strip()
    if override:
        return override
    if path_from_url:
        return path_from_url
    return "VideoPlatform"


@app.errorhandler(mysql_errors.Error)
def handle_mysql_error(err):
    msg = str(err)
    if "1045" in msg or "Access denied" in msg:
        hint = (
            "MySQL rejected the login. Put the same username and password you use in "
            "Workbench into <code>.env</code> next to <code>app.py</code> "
            "(<code>MYSQL_USER</code>, <code>MYSQL_PASSWORD</code>). "
            "If you use a socket or non-default port, set <code>MYSQL_HOST</code> / <code>MYSQL_PORT</code> too."
        )
    elif "1049" in msg or "Unknown database" in msg:
        hint = (
            "Database name not found. Run <code>project.sql</code> in Workbench to create "
            "<code>VideoPlatform</code>, or set <code>MYSQL_DATABASE</code> in <code>.env</code>."
        )
    elif "2003" in msg or "127.0.0.1" in msg or "Can't connect to MySQL server" in msg:
        hint = (
            "The app is trying to reach MySQL on <code>127.0.0.1</code> (your laptop’s default). "
            "On Railway, open your <strong>web</strong> service → <strong>Variables</strong> → add "
            "<code>MYSQL_URL</code> = <code>${{ MySQL.MYSQL_URL }}</code> (use your MySQL service’s name if not "
            "<code>MySQL</code>). Optionally set <code>MYSQL_DATABASE=VideoPlatform</code>. "
            "Redeploy after saving."
        )
    elif "1146" in msg or "doesn't exist" in msg:
        hint = (
            "Wrong database or schema not loaded. Railway’s URL often ends in <code>/railway</code>, but "
            "<code>project.sql</code> creates tables in <code>VideoPlatform</code>. "
            "On your <strong>web</strong> service set <code>MYSQL_DATABASE=VideoPlatform</code> "
            "(or if Railway keeps resetting it, set <code>MYSQL_DATABASE_OVERRIDE=VideoPlatform</code>), "
            "redeploy, and ensure you ran <code>project.sql</code> + <code>seed_sample_data.sql</code> on this server "
            "(e.g. <code>railway connect MySQL</code> then <code>SOURCE …/project.sql</code>)."
        )
    else:
        hint = (
            "Confirm MySQL is running, the schema matches <code>project.sql</code>, "
            "and <code>.env</code> points at the right host and database."
        )
    return render_template("error.html", message=msg, hint=hint), 503


def db_config():
    # Railway: add MYSQL_URL = ${{ MySQL.MYSQL_URL }} on the web service (private or public URL).
    mysql_url = (os.environ.get("MYSQL_URL") or "").strip()
    if mysql_url:
        parsed = urlparse(mysql_url)
        if not parsed.hostname:
            raise ValueError("MYSQL_URL must include a host (e.g. mysql://user:pass@host:3306/db)")
        path_db = parsed.path.lstrip("/").split("?", 1)[0]
        path_db = unquote(path_db) if path_db else ""
        db_name = _mysql_database_name(path_db)
        cfg = {
            "host": parsed.hostname,
            "port": int(parsed.port or 3306),
            "user": unquote(parsed.username) if parsed.username else "",
            "password": unquote(parsed.password) if parsed.password else "",
            "database": db_name,
        }
    else:
        cfg = {
            "host": os.environ.get("MYSQL_HOST", "127.0.0.1"),
            "port": int(os.environ.get("MYSQL_PORT", "3306")),
            "user": os.environ.get("MYSQL_USER", "root"),
            "password": os.environ.get("MYSQL_PASSWORD", ""),
            "database": _mysql_database_name(""),
        }
    # If Workbench uses TLS but the Python client fails on SSL, try MYSQL_SSL_DISABLED=true
    if os.environ.get("MYSQL_SSL_DISABLED", "").lower() in ("1", "true", "yes"):
        cfg["ssl_disabled"] = True
    return cfg


@contextmanager
def get_conn():
    conn = mysql.connector.connect(**db_config())
    try:
        yield conn
    finally:
        conn.close()


def query_all(sql, params=None):
    with get_conn() as conn:
        cur = conn.cursor(dictionary=True)
        cur.execute(sql, params or ())
        rows = cur.fetchall()
        cur.close()
        return rows


@app.get("/health")
def health():
    """No DB — use for Railway / load balancer checks."""
    return "ok", 200


@app.get("/")
def home():
    return render_template("index.html")


@app.get("/users")
def users():
    rows = query_all(
        "SELECT user_id, username, email FROM `User` ORDER BY user_id"
    )
    return render_template("table.html", title="Users", rows=rows)


@app.get("/creators")
def creators():
    rows = query_all(
        """
        SELECT c.user_id, u.username, u.email, c.subscriber_count
        FROM Creator c
        JOIN `User` u ON u.user_id = c.user_id
        ORDER BY c.user_id
        """
    )
    return render_template("table.html", title="Creators", rows=rows)


@app.get("/videos")
def videos():
    rows = query_all(
        """
        SELECT v.video_id, v.user_id AS creator_id, u.username AS creator,
               v.views, v.like_count, v.dislike_count
        FROM Video v
        JOIN `User` u ON u.user_id = v.user_id
        ORDER BY v.video_id
        """
    )
    return render_template("table.html", title="Videos", rows=rows)


@app.get("/comments")
def comments():
    rows = query_all(
        """
        SELECT c.comment_id, c.video_id, c.user_id, u.username,
               c.`text`, c.`timestamp`
        FROM Comment c
        JOIN `User` u ON u.user_id = c.user_id
        ORDER BY c.`timestamp` DESC, c.comment_id
        """
    )
    return render_template("table.html", title="Comments", rows=rows)


@app.get("/subscriptions")
def subscriptions():
    rows = query_all(
        """
        SELECT s.user_id AS viewer_id, vu.username AS viewer,
               s.creator_id, cu.username AS creator
        FROM SubscribesTo s
        JOIN `User` vu ON vu.user_id = s.user_id
        JOIN `User` cu ON cu.user_id = s.creator_id
        ORDER BY s.user_id, s.creator_id
        """
    )
    return render_template("table.html", title="Subscriptions", rows=rows)


@app.get("/subtitles")
def subtitles():
    rows = query_all(
        """
        SELECT s.subtitle_id, s.video_id, s.user_id, u.username,
               LEFT(s.subtitle_text, 120) AS subtitle_preview
        FROM VideoSubtitle s
        JOIN `User` u ON u.user_id = s.user_id
        ORDER BY s.subtitle_id
        """
    )
    return render_template("table.html", title="Video subtitles", rows=rows)


if __name__ == "__main__":
    # Railway sets PORT; binding to 5000 only makes the platform kill/restart the container.
    port = int(os.environ.get("PORT", "5000"))
    debug = not os.environ.get("RAILWAY_ENVIRONMENT")
    app.run(debug=debug, host="0.0.0.0", port=port)
