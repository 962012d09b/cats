#!/bin/sh

# Fix ownership on bind-mounted volumes so celeryuser can write
chown -R celeryuser:celeryuser /app/datasets /app/backend/database 2>/dev/null || true

exec gosu celeryuser "$@"
