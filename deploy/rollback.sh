#!/usr/bin/env bash

set -e

echo "Executing Blue/Green rollback strategy..."

ROUTER="kanban-router"

if ! docker ps -q -f name="^${ROUTER}$" | grep -q .; then
    echo "No active router found. Nothing to rollback."
    exit 0
fi

CURRENT_COLOR=$(docker exec "${ROUTER}" sh -c \
    "grep -o 'kanban-app-[a-z]*:8080' /etc/nginx/conf.d/default.conf 2>/dev/null | head -1 | sed 's/kanban-app-//;s/:8080//' || true")

if [ "${CURRENT_COLOR}" = "blue" ]; then
    PREVIOUS_COLOR="green"
elif [ "${CURRENT_COLOR}" = "green" ]; then
    PREVIOUS_COLOR="blue"
else
    echo "Unable to determine current deployment color."
    exit 1
fi

CURRENT_CONTAINER="kanban-app-${CURRENT_COLOR}"
PREVIOUS_CONTAINER="kanban-app-${PREVIOUS_COLOR}"

echo "Current version: ${CURRENT_CONTAINER}"
echo "Rollback target: ${PREVIOUS_CONTAINER}"

if ! docker ps -q -f name="^${PREVIOUS_CONTAINER}$" | grep -q .; then
    echo "Rollback target ${PREVIOUS_CONTAINER} is not running."
    exit 1
fi

STATUS=$(docker inspect \
    --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' \
    "${PREVIOUS_CONTAINER}" 2>/dev/null || echo "missing")

if [ "${STATUS}" != "healthy" ]; then
    echo "Rollback target is not healthy: ${STATUS}"
    exit 1
fi

echo "Switching router to ${PREVIOUS_CONTAINER}..."

docker exec "${ROUTER}" sh -c \
    "sed -i 's/kanban-app-${CURRENT_COLOR}:8080/kanban-app-${PREVIOUS_COLOR}:8080/' /etc/nginx/conf.d/default.conf"

docker exec "${ROUTER}" nginx -t

docker exec "${ROUTER}" nginx -s reload -c /etc/nginx/nginx.conf

sleep 1

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    --max-time 5 \
    http://127.0.0.1:8081/healthz || true)

if [ "${HTTP_CODE}" != "200" ]; then
    echo "Rollback validation failed: HTTP ${HTTP_CODE}"
    exit 1
fi

echo "Rollback successful."
echo "Live version: ${PREVIOUS_CONTAINER}"

echo "Removing failed version..."

docker stop "${CURRENT_CONTAINER}" || true
docker rm "${CURRENT_CONTAINER}" || true

echo "Rollback sequence complete."
