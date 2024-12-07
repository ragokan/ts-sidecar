#!/bin/sh
# entrypoint.sh

# Store process PIDs
TAILSCALED_PID=""
TAILSCALE_SERVE_PID=""

# Cleanup function
cleanup() {
    echo "Received signal to stop. Performing cleanup..."

    # Stop tailscale serve if running
    if [ -n "$TAILSCALE_SERVE_PID" ]; then
        echo "Stopping tailscale serve..."
        kill $TAILSCALE_SERVE_PID 2>/dev/null
        wait $TAILSCALE_SERVE_PID 2>/dev/null
    fi

    # Log out of tailscale network
    echo "Logging out of Tailscale network..."
    tailscale down 2>/dev/null
    tailscale logout 2>/dev/null

    # Kill tailscaled if it's still running
    if [ -n "$TAILSCALED_PID" ]; then
        echo "Stopping tailscaled..."
        kill $TAILSCALED_PID 2>/dev/null
        wait $TAILSCALED_PID 2>/dev/null
    fi

    echo "Cleanup complete. Exiting."
    exit 0
}

# Set up signal handling for multiple signals
trap cleanup INT TERM QUIT HUP

# Check for required auth key
if [ -z "$TAILSCALE_AUTHKEY" ]; then
    echo "Error: TAILSCALE_AUTHKEY environment variable is required"
    exit 1
fi

# Start tailscaled in the background and capture its PID
tailscaled --state=/var/lib/tailscale/tailscaled.state --tun=userspace-networking &
TAILSCALED_PID=$!

# Wait for tailscaled socket to be ready
MAX_RETRIES=30
RETRY_COUNT=0
echo "Waiting for tailscaled to be ready..."
while [ ! -e /var/run/tailscale/tailscaled.sock ]; do
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo "Error: tailscaled socket failed to appear after $MAX_RETRIES retries"
        cleanup # Call cleanup on failure
        exit 1
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Attempt $RETRY_COUNT/$MAX_RETRIES: Waiting for tailscaled socket..."
    sleep 1
done
echo "tailscaled socket is ready!"

# Authenticate with Tailscale using environment variables
echo "Authenticating with Tailscale..."
if ! tailscale up \
    --authkey="$TAILSCALE_AUTHKEY" \
    --hostname="$TAILSCALE_HOSTNAME" \
    --accept-routes \
    --accept-dns=false \
    $TAILSCALE_EXTRA_ARGS; then
    echo "Failed to authenticate with Tailscale"
    cleanup # Call cleanup on failure
    exit 1
fi

# Start tailscale serve and capture its PID
echo "Starting Tailscale serve on port $TAILSCALE_PORT..."
tailscale serve "$TAILSCALE_PORT" &
TAILSCALE_SERVE_PID=$!

# Wait for any process to exit
wait -n

# Cleanup after process exit
cleanup
