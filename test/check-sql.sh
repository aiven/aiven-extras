#!/usr/bin/env bash

set -e
sql_files=$(ls sql/*.sql)
psql -U postgres -c "CREATE SCHEMA aiven_extras;"
for file in ${sql_files}
do
    psql -U postgres -f ${file}
    echo "File ${file} passes syntax check"
done

