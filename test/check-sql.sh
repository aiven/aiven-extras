#!/usr/bin/env bash

set -e
sql_files=$(ls sql/*.sql)
psql -v ON_ERROR_STOP=1 -U postgres -c "CREATE SCHEMA aiven_extras;"
for file in ${sql_files}
do
    psql -v ON_ERROR_STOP=1 -U postgres -f ${file}
    echo "File ${file} passes syntax check"
done

