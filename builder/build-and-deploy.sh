#!/bin/sh
# Simple builder script that clones example repos (or uses provided git URLs) and copies built artifacts into the app data volumes
# It expects SSH agent to be forwarded into the container at /ssh-agent (docker compose mounts SSH_AUTH_SOCK)
set -e
echo "[builder] starting build-and-deploy.sh"

# Example: build static artifacts - in a real repo you'd run npm build / mvn package etc.
# For this demo we'll just write a distinct index.html into each app volume
cat > /app1_dist/index.html <<'EOF'
<!doctype html><html><body><h1>App1 - built by builder</h1></body></html>
EOF

cat > /app2_dist/index.html <<'EOF'
<!doctype html><html><body><h1>App2 - built by builder</h1></body></html>
EOF

cat > /app3_dist/index.html <<'EOF'
<!doctype html><html><body><h1>App3 - built by builder</h1></body></html>
EOF

echo "[builder] copied artifacts to volumes"
# keep container running long enough for manual inspection; exit when done (discardable)
sleep 2
echo "[builder] done"
exit 0
