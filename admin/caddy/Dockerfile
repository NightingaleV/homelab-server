# Use the official Caddy builder image to build Caddy with the forwardproxy module
FROM caddy:builder AS builder

RUN xcaddy build --with github.com/caddyserver/forwardproxy

# Use the official Caddy image for the final container
FROM caddy:latest

COPY --from=builder /usr/bin/caddy /usr/bin/caddy