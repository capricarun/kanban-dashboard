#!/usr/bin/env bash
set -e

IMAGE_NAME=$1
echo "Starting Blue/Green Zero-Downtime Deployment..."

# 1. Create docker network if it doesn't exist
docker network create kanban-net 2>/dev/null || true

# 2. Determine active container color (blue or green)
if [ "$(docker ps -q -f name=kanban-app-blue)" ]; then
    NEW_COLOR="green"
    OLD_COLOR="blue"
    NEW_PORT=8082
else
    NEW_COLOR="blue"
    OLD_COLOR="green"
    NEW_PORT=8081
fi

echo "Deploying to target: kanban-app-${NEW_COLOR}..."

# 3. Stop/remove any existing container of the target color
docker stop "kanban-app-${NEW_COLOR}" 2>/dev/null || true
docker rm "kanban-app-${NEW_COLOR}" 2>/dev/null || true

# 4. Start NEW container alongside OLD container
docker run -d \
  --name "kanban-app-${NEW_COLOR}" \
  --network kanban-net \
  --memory=300m \
  --cpus=0.5 \
  "${IMAGE_NAME}"

# 5. Poll container health until status is 'healthy' (up to 30 seconds)
echo "Waiting for kanban-app-${NEW_COLOR} to report healthy..."
HEALTH_STATUS="starting"
ATTEMPTS=0
until [ "$HEALTH_STATUS" == "healthy" ] || [ $ATTEMPTS -eq 10 ]; do
    sleep 3
    HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' "kanban-app-${NEW_COLOR}" 2>/dev/null || echo "starting")
    echo "Health status: ${HEALTH_STATUS} (Attempt $((ATTEMPTS+1))/10)"
    ATTEMPTS=$((ATTEMPTS+1))
done

if [ "$HEALTH_STATUS" != "healthy" ]; then
    echo "New deployment failed health check! Keeping kanban-app-${OLD_COLOR} active."
    docker stop "kanban-app-${NEW_COLOR}" || true
    docker rm "kanban-app-${NEW_COLOR}" || true
    exit 1
fi

# 6. Setup or reload Nginx Edge Router container
if [ ! "$(docker ps -q -f name=kanban-router)" ]; then
    echo "Starting edge router container on port 8081..."
    docker run -d \
      --name kanban-router \
      --network kanban-net \
      -p 8081:80 \
      nginx:alpine
fi

# 7. Hot-reload Nginx config to switch traffic
docker exec kanban-router sh -c "cat << 'ROUTER_EOF' > /etc/nginx/conf.d/default.conf
server {
    listen 80;
    location / {
        proxy_pass http://kanban-app-${NEW_COLOR}:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
ROUTER_EOF
nginx -s reload"

echo "Traffic switched to kanban-app-${NEW_COLOR} successfully!"

# 8. Clean up old container after switch
if [ "$(docker ps -q -f name=kanban-app-${OLD_COLOR})" ]; then
    echo "Stopping old container kanban-app-${OLD_COLOR}..."
    docker stop "kanban-app-${OLD_COLOR}" || true
    docker rm "kanban-app-${OLD_COLOR}" || true
fi

echo "Blue/Green deployment completed with zero downtime."
