########################################################################
# nginx/Dockerfile
#
# Reads /sites.json (bind-mounted from the project root — see
# docker-compose.yml) and generates one HTTP+HTTPS vhost per site,
# each proxying .php requests to the linux container's php-fpm at
# linux:9000. SSL certs are self-signed (auto-generated per domain,
# persisted under /etc/nginx/ssl so they survive restarts) — there's
# no real CA that can issue trusted certs for .local/dev-only domains.
########################################################################

FROM nginx:stable-alpine

RUN apk add --no-cache openssl jq

# Sensible default: refuse unmatched Host headers rather than falling
# back to serving something unintended.
COPY conf.d/default.conf /etc/nginx/conf.d/default.conf

# nginx's official image automatically runs every executable script in
# /docker-entrypoint.d/ (alphabetically) before starting nginx — no
# custom ENTRYPOINT needed, which keeps the base image's own signal
# handling/graceful shutdown behavior intact.
COPY docker-entrypoint.d/50-provision-sites.sh /docker-entrypoint.d/50-provision-sites.sh
RUN sed -i 's/\r$//' /docker-entrypoint.d/50-provision-sites.sh \
    && chmod +x /docker-entrypoint.d/50-provision-sites.sh
