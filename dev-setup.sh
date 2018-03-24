#!/usr/bin/env bash

set -x

docker-compose build app
docker-compose run --rm app mix ecto.setup
