#!/bin/bash

set -euo pipefail

workspace=$1

if [ "$workspace" == "master" ]; then
    tag="latest"
elif [ "$workspace" == "prod" ]; then
    tag="stable"
else
    tag="$workspace"
fi

echo "pulling previous image for layer cache... "
$(docker login -u "$DOCKERHUB_USERNAME" --password "$DOCKERHUB_PASSWORD") &>/dev/null || echo 'warning: docker hub login failed'
docker pull radaisystems/nginx-dynamic-acm:latest &>/dev/null || echo 'warning: pull failed'

echo "building image... "
docker build \
    --cache-from radaisystems/nginx-dynamic-acm:latest \
    -f Dockerfile.nginx \
    -t radaisystems/nginx-dynamic-acm:$tag \
    .

if [ "$workspace" == "master" ] || [ "$workspace" == "prod" ]; then
  docker push radaisystems/nginx-dynamic-acm::$tag
fi
