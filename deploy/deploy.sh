#!/usr/bin/env bash
set -e

IMAGE_NAME=$1
echo "Starting Blue/Green Zero-Downtime Deployment for ${IMAGE_NAME}..."

# Create internal docker network
docker network create kanban-net 2>/dev/null || true

# Determine target deployment color
if [ "$(docker ps -q -f name=kanban-app-blue)" ]; then
    NEW_COLOR="green"
    OLD_COLOR="blue"
else
    NEW_COLOR="blue"
    OLD_COLOR="green"
fi

echo "Deploying new container: kanban-app-${NEW_COLOR}..."

# Clean up any stopped container of target color
docker stop "kanban-app-${NEW_COLOR}" 2>/dev/null || true
docker rm "kanban-app-${NEW_COLOR}" 2>/dev/null || true

# Run new container inside internal network (no host port binding needed)
docker run -d \
  --name "kanban-app-${NEW_COLOR}" \
  --network kanban-net \
  --memory=300m \
  --cpus=0.5 \
  "${IMAGE_NAME}"

# Wait for container HEALTHCHECK
echo "Waiting for kanban-app-${NEW_COLOR} health status..."
ATTEMPTS=0
until [ "$(docker inspect --format='{{.State.Health.Status}}' kanban-app-${NEW_COLOR} 2>/dev/null)" == "healthy" ] || [ $ATTEMPTS -eq 10 ]; do
    sleep 3
    ATTEMPTS=$((ATTEMPTS+1))
    echo "Health poll attempt ${ATTEMPTS}/10..."
done

if [ "$(docker inspect --format='{{.State.Health.Status}}' kanban-app-${NEW_COLOR} 2>/dev/null)" != "healthy" ]; then
    echo "Health check failed for kanban-app-${NEW_COLOR}!"
    docker stop "kanban-app-${NEW_COLOR}" || true
    docker rm "kanban-app-${NEW_COLOR}" || true
    exit 1
fi

# Ensure Nginx Edge Router is running on host port 8081
if [ ! "$(docker ps -q -f name=kanban-router)" ]; then
    echo "Initializing Nginx Router on port 8081..."
    docker stop kanban-router 2>/dev/null || true
    docker rm kanban-router 2>/dev/null || true
    docker run -d \
      --name kanban-router \
      --network kanban-net \
      -p 8081:80 \
      nginx:alpine
fi

# Update router configuration and reload Nginx
docker exec kanban-router sh -c "cat << 'NCONF' > /etc/nginx/conf.d/default.conf
server {
    listen 80;
    location / {
        proxy_pass http://kanban-app-${NEW_COLOR}:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
NCONF
nginx -s reload"

echo "Switched live traffic to kanban-app-${NEW_COLOR}."

# Remove old container
if [ "$(docker ps -q -f name=kanban-app-${OLD_COLOR})" ]; then
    echo "Cleaning up kanban-app-${OLD_COLOR}..."
    docker stop "kanban-app-${OLD_COLOR}" || true
    docker rm "kanban-app-${OLD_COLOR}" || true
fi

echo "Deployment finished successfully!"
