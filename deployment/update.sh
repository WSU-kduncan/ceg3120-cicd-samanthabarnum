#!/bin/bash

CONTAINER_NAME="angular-app"
IMAGE_NAME="barnum9/barnum-ceg3120:latest"

# get container id matching the container name, whether running or exited
CONTAINER_ID=$(docker ps -aq -f name=$CONTAINER_NAME)

# if container exists, stop and remove them
if [ ! -z "$CONTAINER_ID" ]; then
    docker ps -a -f name=$CONTAINER_NAME
    docker rm -f $CONTAINER_ID
else
    echo "none here"
fi

docker pull $IMAGE_NAME

docker run -d --restart unless-stopped --name $CONTAINER_NAME -p 80:4200 $IMAGE_NAME