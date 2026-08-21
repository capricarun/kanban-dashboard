#!/usr/bin/env bash
echo "Executing rollback strategy..."
docker stop kanban-app-running || true
docker rm kanban-app-running || true
echo "Rollback sequence complete."
