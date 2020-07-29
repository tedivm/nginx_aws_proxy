#!/bin/bash

set -euo pipefail

workspace=$1

if [ "$workspace" == "master" ]; then
    tag="latest"
elif [ "$workspace" == "prod" ]; then
    tag="v1"
else
    tag="$workspace"
fi

echo "pulling previous image for layer cache... "
docker pull radaisystems/nginx-dynamic-acm:latest &>/dev/null || echo 'warning: pull failed'

echo "building image... "
docker build \
    -f dockerfile \
    -t radaisystems/nginx-dynamic-acm:$tag \
    .

if [ "$workspace" == "master" ] || [ "$workspace" == "prod" ]; then
  docker push radaisystems/nginx-dynamic-acm:$tag
fi
