#!/bin/bash
#
# docker-test.sh
#
# Start PostgreSQL in a container and then start App::Dochazka::REST
# Dockerized testing environment in another container, linked to the
# PostgreSQL container.

docker rm -f dr >/dev/null 2>&1
docker rm -f dr-postgres >/dev/null 2>&1
docker run \
    --name dr-postgres \
    -e POSTGRES_PASSWORD=chisel \
    -d \
    postgres:9.3
docker run \
    --user smithfarm \
    -t \
    --name dr \
    --link dr-postgres:postgres \
    -h dr \
    -d \
    dochazka-rest
