# Hardened Dockerfile - this is the image the pipeline scans, pushes and deploys.
# Pragya Tripathi (24BCS10032)
#
#  1. Base images pinned by digest  -> the build cannot silently change underneath us
#  2. Tests run in a build stage     -> a failing test means no image
#  3. npm ci from the lockfile      -> exact, reproducible dependency tree
#  4. Distroless runtime            -> no shell, no apt/apk, no npm in the final image
#  5. Non-root user (uid 65532)     -> matches runAsNonRoot in the k8s manifest
#  6. Only src/ + package.json copied into the runtime stage

# ---- stage 1: install + test ------------------------------------------------
FROM node:24-alpine@sha256:ebfe2f90462722a7a4de65e91990e97fe0d401c70e0e762c5b53302f905ec1c1 AS build
WORKDIR /app
COPY package.json package-lock.json ./
# The app has zero runtime dependencies today, and then npm ci does not create
# node_modules at all - mkdir keeps the COPY below working either way.
RUN npm ci --omit=dev --ignore-scripts && mkdir -p node_modules
COPY src ./src
COPY test ./test
RUN node --test

# ---- stage 2: runtime ---------------------------------------------------------
FROM gcr.io/distroless/nodejs24-debian13:nonroot@sha256:9eeb7f5887d0e239e78264b06f7f11d2e14be534050481803a9e4728fcdd278e
LABEL org.opencontainers.image.source="https://github.com/16pragyatripathi/Devops-Assignment-1" \
      org.opencontainers.image.description="Session 17 DevSecOps demo API (hardened)" \
      org.opencontainers.image.authors="Pragya Tripathi <pragya.24bcs10032@sst.scaler.com>"
WORKDIR /app
COPY --from=build /app/package.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/src ./src
ARG APP_VERSION=local
ENV NODE_ENV=production \
    PORT=3000 \
    APP_VERSION=${APP_VERSION}
EXPOSE 3000
USER 65532:65532
# No shell or curl in distroless, so the health check uses node itself.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD ["/nodejs/bin/node", "-e", "fetch('http://127.0.0.1:3000/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"]
# The distroless entrypoint is already "node".
CMD ["src/server.js"]
