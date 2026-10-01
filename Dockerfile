FROM caddy:2-alpine
ENV PORT=8080
COPY Caddyfile /etc/caddy/Caddyfile
COPY public/ /srv/
EXPOSE 8080
