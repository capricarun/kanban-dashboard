#!/usr/bin/env bash
set -e

echo "Starting Blue-Green Deployment..."
# Run the application container on port 8081
docker stop kanban-app-running || true
docker rm kanban-app-running || true
docker run -d --name kanban-app-running -p 8081:8080 $1

echo "Deployment successful!"
