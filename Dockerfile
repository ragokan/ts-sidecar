FROM alpine:latest

# Install dependencies and tailscale
RUN apk add --no-cache \
    curl \
    iptables \
    ip6tables \
    tailscale

# Create directories for tailscale
RUN mkdir -p /var/run/tailscale \
    /var/cache/tailscale \
    /var/lib/tailscale

# Create a non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Set correct permissions
RUN chown -R appuser:appgroup /var/run/tailscale \
    /var/cache/tailscale \
    /var/lib/tailscale

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Define environment variables with defaults
ENV TAILSCALE_AUTHKEY=""
ENV TAILSCALE_HOSTNAME=""
ENV TAILSCALE_PORT=""

ENTRYPOINT ["/entrypoint.sh"]