#!/usr/bin/env bash
# Applies the migrations to a throwaway Postgres 15 and runs the SQL tests.
# Needs Docker. Usage: bash supabase/tests/run.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NAME=hearth-pg-test
docker rm -f $NAME >/dev/null 2>&1 || true
docker run -d --name $NAME -e POSTGRES_PASSWORD=pw -p 55432:5432 postgres:15-alpine >/dev/null
trap 'docker rm -f $NAME >/dev/null 2>&1 || true' EXIT
for i in $(seq 1 40); do
  docker exec $NAME pg_isready -U postgres >/dev/null 2>&1 && break
  sleep 1
done
sleep 2
run() { docker exec -i $NAME psql -U postgres -v ON_ERROR_STOP=1 -q -o /dev/null "$@"; }
run < tests/00_stub.sql
for f in migrations/*.sql; do echo "== $f"; run < "$f"; done
for f in tests/*_test.sql; do echo "== $f"; run < "$f"; done
echo "== engine against the real SQL (round trip)"
HEARTH_PG_CONTAINER=$NAME node --test "tests/db_roundtrip.test.ts"
echo "SQL tests passed"
