#!/bin/bash

set -e # fail fast

: ${credentials:?required}
wait_til_running=${wait_til_running:-60}

echo Sanity testing ${service_plan_image:-${image:-PostgreSQL}} with $credentials

uri=$(echo $credentials | jq -r '.uri // .credentials.uri // ""')

: ${uri:?missing from binding credentials}

username=$( echo "$uri" | sed 's|[[:blank:]]*postgres://\([^:]\+\):\([^@]\+\)@\([^:]\+\):\([^/]\+\)\/\(.*\)[[:blank:]]*|\1|' )
password=$( echo "$uri" | sed 's|[[:blank:]]*postgres://\([^:]\+\):\([^@]\+\)@\([^:]\+\):\([^/]\+\)\/\(.*\)[[:blank:]]*|\2|' )
host=$(     echo "$uri" | sed 's|[[:blank:]]*postgres://\([^:]\+\):\([^@]\+\)@\([^:]\+\):\([^/]\+\)\/\(.*\)[[:blank:]]*|\3|' )
port=$(     echo "$uri" | sed 's|[[:blank:]]*postgres://\([^:]\+\):\([^@]\+\)@\([^:]\+\):\([^/]\+\)\/\(.*\)[[:blank:]]*|\4|' )
dbname=$(   echo "$uri" | sed 's|[[:blank:]]*postgres://\([^:]\+\):\([^@]\+\)@\([^:]\+\):\([^/]\+\)\/\(.*\)[[:blank:]]*|\5|' )

echo "Waiting for $uri to be ready (max ${wait_til_running}s)"
for ((n=0; n<$wait_til_running; n++)); do
  if [[ pg_isready -h $host -p $port -d $dbname ]]; then
    echo "Postgres is ready"
    break
  fi
  print .
  sleep 1
done
if [[ ! pg_isready -h $host -p $port -d $dbname ]]; then
  echo "Postgres not running"
  exit 1
fi

set -x
psql ${uri} -c 'DROP TABLE IF EXISTS sanitytest;'
psql ${uri} -c 'CREATE TABLE sanitytest(value text);'
psql ${uri} -c "INSERT INTO sanitytest VALUES ('storage-test');"
psql ${uri} -c 'SELECT value FROM sanitytest;' | grep 'storage-test' || {
  echo Could not store and retrieve value in cluster!
  exit 1
}
