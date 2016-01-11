#!/bin/bash
#
# docker-test.sh
#
# Start PostgreSQL in a container and then start App::Dochazka::REST
# Dockerized testing environment in another container, linked to the
# PostgreSQL container.

if [ "$#" -eq 1 ]
then
    case $1 in
        13.2|42.1|tumbleweed)
            echo "Valid argument" && TARGET=$1 ;;
        *)
            echo "Invalid argument" && exit -1 ;;
    esac
else
    TARGET=42.1
fi
echo "TARGET is $TARGET"
exit 0

echo "Destroying any existing containers called 'dochazka' and 'postgres'"
docker rm -f dochazka >/dev/null 2>&1
docker rm -f postgres >/dev/null 2>&1

echo "Starting postgres container"
docker run \
    --name=postgres \
    -e POSTGRES_PASSWORD=chisel \
    -d \
    -p "5432:5432" \
    postgres:9.4

echo "Waiting 5 seconds for postgres container to settle"
sleep 5

echo "Starting Dochazka REST server"
docker run \
    --name=dochazka \
    --link=postgres \
    -h dochazka \
    -d \
    -p "5000:5000" \
    dochazka/rest-$TARGET
