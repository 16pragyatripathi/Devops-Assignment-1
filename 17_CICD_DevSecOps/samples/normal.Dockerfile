# "Normal" Dockerfile - the way most people write their first one.
# INTENTIONALLY NOT HARDENED. Kept for comparison with app/Dockerfile (the hardened one);
# the pipeline builds and scans it in report-only mode but never pushes or
# deploys it. Build context is app/:
#   docker build -f samples/normal.Dockerfile -t pragya-devsecops-demo:normal app
#
# Problems on purpose:
#   - full Debian-based node image (compilers, shells, package managers, ...)
#   - floating tag, no digest pin
#   - copies the whole folder, tests included
#   - runs as root
#   - npm and its own dependencies stay in the runtime image
FROM node:24
WORKDIR /app
COPY . .
RUN npm install
ENV PORT=3000
EXPOSE 3000
CMD ["npm", "start"]
