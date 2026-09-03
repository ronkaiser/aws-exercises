#!/usr/bin/env bash
set -e

export IMAGE="ronkaiser86/myapp:$1"
docker-compose -f docker-compose.yaml up --detach
