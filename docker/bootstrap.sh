#!/bin/bash
su - postgres <<EOF
/usr/lib/postgresql93/bin/pg_ctl start \
    -s \
    -w \
    -D /var/lib/pgsql/data \
    -l /var/lib/pgsql/data/postmaster.log \
    -o ""
EOF
/bin/bash
