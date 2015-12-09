#!/bin/bash
/usr/lib/postgresql93/bin/pg_ctl start \
    -s \
    -w \
    -D /var/lib/pgsql/data \
    -l /var/lib/pgsql/data/postmaster.log \
    -o ""
/usr/bin/psql postgres -c "ALTER ROLE postgres WITH PASSWORD 'mypass';"
/usr/lib/postgresql93/bin/pg_ctl stop \
    -s \
    -D /var/lib/pgsql/data \
    -m fast
