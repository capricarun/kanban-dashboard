#!/usr/bin/env bash
set -e

IMAGE_NAME=$1
echo "Deploying image: ${IMAGE_NAME}"

# Stop and remove existing container instance if running
docker stop kanban-app-running || true
docker rm kanban-app-running || true

# Start new container mapping port 8081 on host to 8080 in container
docker run -d --name kanban-app-running -p 8081:8080 ${IMAGE_NAME}
echo "Container started successfully."
