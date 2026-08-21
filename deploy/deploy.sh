#!/usr/bin/env bash
set -e

IMAGE_NAME=$1
echo "Deploying image with resource limits: ${IMAGE_NAME}"

# Stop and remove existing container instance if running
docker stop kanban-app-running || true
docker rm kanban-app-running || true

# Start container with CPU (0.5 vCPU) and Memory (300 MB) limits
docker run -d \
  --name kanban-app-running \
  --memory=300m \
  --cpus=0.5 \
  -p 8081:8080 \
  ${IMAGE_NAME}

echo "Container started successfully with resource caps."
