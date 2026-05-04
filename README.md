# Video Platform UI

A small **Flask** web app that **reads** data from a **MySQL** database built from **`project.sql`** and **`seed_sample_data.sql`**. It lists users, creators, videos, comments, subscriptions, and subtitles in simple HTML tables.

This README covers **local development**, **Railway deployment**, **environment variables**, **how the database name override works**, and **how to change schema or data** safely.

---

## Prerequisites

- **Python 3.10+** (3.12 used in development)
- **MySQL** running locally (e.g. via MySQL Workbench), **or** a hosted MySQL (e.g. Railway)
- **Git**

Optional for deployment: **Railway** account, **GitHub** repo, **Railway CLI** for DB tunnels

---

## Repository layout

| Path | Purpose |
|------|---------|
| `app.py` | Flask app, DB config, routes |
| `main.py` | WSGI shim (`from app import app`) for hosts that run `gunicorn main:app` |
| `project.sql` | Creates **`VideoPlatform`** DB, DDL, views, sample DML |
| `seed_sample_data.sql` | Inserts seed rows (run **after** `project.sql`) |
| `templates/` | Jinja HTML (`base.html`, `index.html`, `table.html`, `error.html`) |
| `static/css/` | Styles |
| `requirements.txt` | Python dependencies |
| `env.example` | Template for **`.env`** (safe to commit) |
| `.env` | **Your** secrets (create locally; **never commit**) |
| `Procfile` | `gunicorn` start command for Railway/Heroku-style hosts |
| `railway.toml` | Railway deploy start command fallback |

---

## Quick start (local)

### 1. Clone and virtual environment

```bash
cd video_platform_ui
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

### 2. Configure environment

```bash
cp env.example .env
```

Edit **`.env`** and set at least **`MYSQL_PASSWORD`** to match the MySQL user you use in Workbench (often **`root`** on **`127.0.0.1:3306`**). See **Environment variables** below for all keys.

### 3. Create and seed the database (local MySQL)

In **MySQL Workbench** (or the `mysql` CLI), connect to your **local** server and run **in order**:

1. **`project.sql`** (creates database **`VideoPlatform`**, tables, views)
2. **`seed_sample_data.sql`** (inserts sample data)

Or from a terminal (adjust password/host if needed):

```bash
mysql -h 127.0.0.1 -P 3306 -u root -p < project.sql
mysql -h 127.0.0.1 -P 3306 -u root -p VideoPlatform < seed_sample_data.sql
```

### 4. Run the app

```bash
python app.py
```

Open **http://127.0.0.1:5000** (or the port shown if **`PORT`** is set).

### 5. Routes

| URL | Content |
|-----|---------|
| `/` | Home / links |
| `/health` | Plain **`ok`** — no DB; use for uptime checks |
| `/users` | `User` rows |
| `/creators` | Creators + user info |
| `/videos` | Videos |
| `/comments` | Comments |
| `/subscriptions` | Subscription edges |
| `/subtitles` | Subtitle previews |

The app is **read-only**: there are no web forms that insert or update data. Changes to data happen in MySQL (Workbench, CLI, or SQL scripts).

---

## Environment variables

### Local development (no `MYSQL_URL`)

Create **`.env`** next to **`app.py`** (copy from **`env.example`**).

| Variable | Required | Description |
|----------|----------|-------------|
| `MYSQL_HOST` | No | Default `127.0.0.1` |
| `MYSQL_PORT` | No | Default `3306` |
| `MYSQL_USER` | No | Default `root` |
| `MYSQL_PASSWORD` | Usually yes | MySQL password |
| `MYSQL_DATABASE` | No | Default `VideoPlatform` |
| `MYSQL_SSL_DISABLED` | No | Set `true` if localhost SSL errors |

Leave **`MYSQL_URL`** unset locally unless you are testing a cloud URL.

### Production (Railway) — web service

| Variable | Description |
|----------|-------------|
| `MYSQL_URL` | Reference: `${{ MySQL.MYSQL_URL }}` (name **`MySQL`** must match your DB service) |
| `MYSQL_DATABASE` | Prefer **`VideoPlatform`** if your tables live there |
| `MYSQL_DATABASE_OVERRIDE` | Set to **`VideoPlatform`** if Railway keeps injecting **`MYSQL_DATABASE=railway`** from the plugin |

Railway also sets **`PORT`** and often **`RAILWAY_ENVIRONMENT`**. The app binds to **`PORT`** when using **`python app.py`** or **`gunicorn`**.

### Why `MYSQL_DATABASE_OVERRIDE` exists

Railway’s **`MYSQL_URL`** often ends with **`/railway`**, and the platform may inject **`MYSQL_DATABASE=railway`**. Your coursework schema lives in **`VideoPlatform`** (see **`project.sql`**). The app resolves the catalog name in **`_mysql_database_name()`** in **`app.py`**:

1. **`MYSQL_DATABASE_OVERRIDE`** (if set) — wins  
2. **`MYSQL_DATABASE`**  
3. Database name from the URL path  
4. Default **`VideoPlatform`**

So you can force **`VideoPlatform`** even when the URL path says **`railway`**.

---

## Deployment (Railway)

### Overview

1. Push this repo to **GitHub**.
2. **New Project** → **Deploy from GitHub** → select the repo.  
   If the Flask app is not at the repo root, set **Root Directory** to **`video_platform_ui`** (or your folder name).
3. Add **MySQL** from **New** → **Database** → **MySQL**.
4. On the **web** service → **Variables**:
   - **`MYSQL_URL`** = `${{ MySQL.MYSQL_URL }}` (adjust service name if needed)
   - **`MYSQL_DATABASE_OVERRIDE`** = **`VideoPlatform`** (recommended)
5. **Settings** → ensure start command is effectively:

   ```bash
   gunicorn app:app --bind 0.0.0.0:$PORT
   ```

   Or rely on **`Procfile`** / **`railway.toml`**. **`main.py`** exists so **`gunicorn main:app`** also works.

6. **Generate domain** (or use Railway’s URL) for the public site.

### Load schema and data on Railway’s MySQL

Your **local** MySQL and **Railway’s** MySQL are **different**. After deploy, load **`project.sql`** and **`seed_sample_data.sql`** against **Railway’s** server.

**Option A — Railway CLI (tunnel)**

```bash
railway login
railway link    # in repo folder; pick project
railway connect MySQL
```

That opens **`mysql`** connected to the cloud DB. Then:

```sql
SOURCE /full/path/to/project.sql;
SOURCE /full/path/to/seed_sample_data.sql;
```

Keep **`railway connect`** running while you use that session.

**Option B — Public host in Workbench**

Use **Public** connection details from Railway MySQL → **Connect**.  
Hostname = proxy host only (not the full `mysql://` URL). Port = public port.

Verify:

```sql
SHOW DATABASES;
USE VideoPlatform;
SHOW TABLES;
```

---

## Changing the database

### Changing **data** (rows only)

Use **MySQL Workbench** or **`mysql`** against the same server your app uses:

- **INSERT** / **UPDATE** / **DELETE** as usual.
- Respect **foreign keys** (e.g. don’t delete a **`User`** that is referenced by **`Video`** without fixing dependents).

After commits, **refresh the browser** — no app restart needed.

To copy **local** data to **Railway**, use **`mysqldump`** from local and import on Railway, or re-run **`seed_sample_data.sql`** on the cloud DB.

### Changing **schema** (tables, columns, views)

1. Edit **`project.sql`** (and **`seed_sample_data.sql`** if inserts must match new columns).
2. **Locally:** either run **altered** DDL in Workbench, or drop/recreate carefully. **`project.sql`** starts with **`DROP DATABASE IF EXISTS VideoPlatform`** — running the whole file **wipes** that database on that server.
3. **Railway:** run the updated **`project.sql`** (and seed) via **`railway connect MySQL`** or Workbench, same as initial load.
4. If you add **new pages** or queries in Flask, update **`app.py`** and templates accordingly.

### Changing **app** behavior or queries

- Routes and SQL live in **`app.py`**.
- HTML/CSS in **`templates/`** and **`static/`**.
- After Git push, Railway **redeploys** automatically if connected to the repo.

---

## Troubleshooting

| Symptom | Likely cause |
|---------|----------------|
| `127.0.0.1` connection refused | MySQL not running locally, or wrong **`MYSQL_*`** |
| `Table 'railway.User' doesn't exist` | App using **`railway`** DB; set **`MYSQL_DATABASE_OVERRIDE=VideoPlatform`** on web service |
| `No module named 'main'` | Use **`gunicorn app:app`** or keep **`main.py`** |
| Workbench can’t connect to `*.railway.internal` | Use **public** host/port or **`railway connect`** |
| “Invalid hostname” in Workbench | Don’t paste full **`mysql://`** URL into hostname — use host, port, user, password separately |
| Help text when running `mysql` in Workbench | Shell commands belong in **Terminal**, not the SQL editor |

---

## Security notes

- **Never commit `.env`** or paste live passwords into public repos or chats.
- Rotate MySQL passwords if they were exposed.
- This UI is meant for **course / demo** use; do not expose production secrets on the public internet without proper auth and hardening.

---

## License / course use

Academic / personal project for CS4354-style database coursework. Adjust as needed for your syllabus.
