# Session 16 demo image - Pragya Tripathi (24BCS10032)
#
# Stage 1 runs the unit tests. If any test fails, `docker build` fails,
# so a broken build can never become an image.
FROM node:24-alpine AS test
WORKDIR /app
COPY package.json ./
COPY src ./src
COPY test ./test
RUN node --test

# Stage 2 is what actually ships: only package.json + src, no tests.
FROM node:24-alpine
LABEL org.opencontainers.image.source="https://github.com/16pragyatripathi/Devops-Assignment-1" \
      org.opencontainers.image.description="Session 16 CI/CD demo API" \
      org.opencontainers.image.authors="Pragya Tripathi <pragya.24bcs10032@sst.scaler.com>"
WORKDIR /app
COPY --from=test /app/package.json ./
COPY --from=test /app/src ./src
ARG APP_VERSION=local
ENV NODE_ENV=production \
    PORT=3000 \
    APP_VERSION=${APP_VERSION}
EXPOSE 3000
# The official node image ships a non-root "node" user.
USER node
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD wget -qO- http://127.0.0.1:3000/healthz || exit 1
CMD ["node", "src/server.js"]
