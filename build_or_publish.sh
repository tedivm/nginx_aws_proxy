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


echo "building image... "
echo docker build --no-cache -f dockerfile -t "radaisystems/nginx-dynamic-acm:$tag" .
docker build --no-cache -f dockerfile -t "radaisystems/nginx-dynamic-acm:$tag" .

if [ "$workspace" == "master" ] || [ "$workspace" == "prod" ]; then
    echo docker push "radaisystems/nginx-dynamic-acm:$tag"
    docker push "radaisystems/nginx-dynamic-acm:$tag"
fi
