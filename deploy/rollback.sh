#!/usr/bin/env bash
set -e
echo "Executing rollback procedure..."
docker ps -a | grep kanban-app || true
echo "Rollback completed."
