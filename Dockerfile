# =========================================================
# Stage 1: BUILD - compile the React/Vite/TypeScript app
# =========================================================
FROM node:invalid-tag-for-testing
#FROM node:20-alpine AS build

WORKDIR /app

# Install dependencies first (better layer caching)
COPY package.json package-lock.json ./
RUN npm ci

# Copy source and build the production bundle
COPY . .
RUN npm run build
# Output lands in /app/dist (static HTML/CSS/JS - no server code)


# =========================================================
# Stage 2: RUNTIME - slim, non-root, static file server
# =========================================================
# nginx-unprivileged already runs as a non-root user (uid 101)
# and listens on 8080 by default, which keeps us off port 80
# (needs root) and off 8080/Jenkins-adjacent conflicts on the host.
FROM nginxinc/nginx-unprivileged:1.27-alpine AS runtime

LABEL maintainer="Arun <rarun84in@gmail.com>" \
      app="kanban-style-task-manager"

# Temporarily switch to root only to install curl (used by HEALTHCHECK)
# and to set file ownership - the container still RUNS as non-root (see USER below).
USER root
RUN apk add --no-cache curl \
    && rm -rf /var/cache/apk/*

# Custom nginx config: serves the SPA and falls back to index.html for client-side routing
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Only the built static artifacts are copied into the final image - no source,
# no node_modules, no build tools end up in the shipped image.
COPY --from=build --chown=nginx:nginx /app/dist /usr/share/nginx/html

# Drop back to the non-root user for everything at runtime
USER nginx

# Only the app port is exposed - nothing else
EXPOSE 8080

# Container is only considered healthy once nginx actually serves the app
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://127.0.0.1:8080/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
HEALTHCHECK --interval=5s --timeout=3s --retries=3 \
  CMD curl -f http://localhost:8080/ || exit 1
