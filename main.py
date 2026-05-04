"""
WSGI entry for hosts that run `gunicorn main:app` (Railway / Nixpacks default).
The real app lives in `app.py`.
"""

from app import app

__all__ = ["app"]
