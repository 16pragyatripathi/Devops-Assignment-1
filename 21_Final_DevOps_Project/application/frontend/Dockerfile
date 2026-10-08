# Stage 1: build the static site with Node
FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: serve it with nginx, as a non-root user. No Node/npm in the final image.
# nginx:1.27-alpine (alpine 3.21) failed the Trivy gate with 44 HIGH/CRITICAL OS CVEs,
# so the base moved to 1.31 and OS packages are upgraded at build time.
FROM nginx:1.31-alpine
RUN apk upgrade --no-cache \
 && sed -i 's#^pid .*#pid /tmp/nginx.pid;#' /etc/nginx/nginx.conf \
 && chown -R nginx:nginx /var/cache/nginx /etc/nginx/conf.d
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
USER nginx
EXPOSE 8080
