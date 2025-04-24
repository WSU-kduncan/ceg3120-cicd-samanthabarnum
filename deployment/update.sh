#!/bin/bash

CONTAINER_NAME="angular-app"
IMAGE_NAME="barnum9/barnum-ceg3120:latest"

#stop and remove existing container if exists
if [ "$(docker ps -aq -f name=$CONTAINER_NAME)" ]; then
    docker rm -f $CONTAINER_NAME
fi

#pull latest
docker pull $IMAGE_NAME

#run new container
docker run -d --restart unless-stopped --name $CONTAINER_NAME -p 80:4200 $IMAGE_NAME