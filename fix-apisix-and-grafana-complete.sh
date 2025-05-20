#!/bin/bash

# This script performs a complete fix for APISIX and Grafana integration

DOMAIN="api.secompanion.de"

echo "=== Complete Fix for APISIX and Grafana Integration ==="
echo

# First, check if APISIX is running
echo "1. Checking if APISIX is running..."
if docker ps | grep -q apisix; then
    echo "   APISIX is running."
else
    echo "   APISIX is not running! Starting APISIX..."
    docker start apisix
    sleep 10
fi

# Check APISIX port binding
echo "2. Checking APISIX port binding..."
APISIX_PORTS=$(docker port apisix)
echo "   APISIX current port mappings:"
echo "$APISIX_PORTS"

# Check if port 9080 is correctly mapped
if ! echo "$APISIX_PORTS" | grep -q "9080"; then
    echo "   WARNING: APISIX port 9080 is not correctly mapped! Checking docker-compose file..."
    grep -A 10 "apisix:" docker-composel.yml || echo "   Could not find port mapping in docker-composel.yml"
fi

# Fix Grafana configuration
echo "3. Updating Grafana configuration..."
mkdir -p conf/grafana/config

cat > conf/grafana/config/grafana.ini << EOL
[server]
root_url = https://${DOMAIN}/grafana
serve_from_sub_path = true
enforce_domain = false

[auth.anonymous]
enabled = true
org_role = Admin

[security]
allow_embedding = true

[log]
mode = console file
level = debug
EOL

# Restart Grafana to apply configuration changes
echo "4. Restarting Grafana..."
docker restart grafana
sleep 10

# Update APISIX configuration to ensure admin API is accessible
echo "5. Ensuring APISIX admin API is correctly configured..."
mkdir -p conf/apisix

cat > conf/apisix/config.yaml << EOL
deployment:
  admin:
    admin_key_required: true
    admin_key:
      - name: admin
        key: BTLvdLB6XptSridgdmuV
        role: admin
    allow_admin:
      - 0.0.0.0/0
    admin_listen:
      ip: 0.0.0.0
      port: 9180
  etcd:
    host:
      - http://etcd:2379

apisix:
  node_listen: 9080
  enable_admin: true
  enable_control: true
  # Set the control port to a different value
  control:
    ip: "0.0.0.0"
    port: 9190
  ssl:
    enable: true
    listen_port: 9443
EOL

# Restart APISIX to apply configuration changes
echo "6. Restarting APISIX..."
docker restart apisix
sleep 15

# Check if APISIX admin API is accessible
echo "7. Checking APISIX admin API..."
curl -s "http://127.0.0.1:9180/apisix/admin/routes" -H "X-API-KEY: BTLvdLB6XptSridgdmuV" | grep -o '"total":[0-9]*' || echo "   Cannot access APISIX admin API!"

# Fix Grafana route in APISIX
echo "8. Creating Grafana route in APISIX..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/4" \
     -H "X-API-KEY: BTLvdLB6XptSridgdmuV" \
     -H "Content-Type: application/json" \
     -d '{
        "uri": "/grafana*",
        "host": "'"$DOMAIN"'",
        "upstream": {
            "type": "roundrobin",
            "nodes": {
                "grafana:3000": 1
            }
        }
    }'

# Add a route for the base Grafana path (without trailing slash)
echo "9. Adding a route for the base Grafana path..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/40" \
     -H "X-API-KEY: BTLvdLB6XptSridgdmuV" \
     -H "Content-Type: application/json" \
     -d '{
        "uri": "/grafana",
        "host": "'"$DOMAIN"'",
        "upstream": {
            "type": "roundrobin",
            "nodes": {
                "grafana:3000": 1
            }
        }
    }'

# Create a route to test direct access to APISIX
echo "10. Creating a test route to verify APISIX is working..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/99" \
     -H "X-API-KEY: BTLvdLB6XptSridgdmuV" \
     -H "Content-Type: application/json" \
     -d '{
        "uri": "/apisix-test",
        "host": "'"$DOMAIN"'",
        "upstream": {
            "type": "roundrobin",
            "nodes": {
                "httpbin:8080": 1
            }
        }
    }'

# Test local access to APISIX
echo "11. Testing local access to APISIX..."
curl -s -I "http://localhost:9080/apisix-test" -H "Host: $DOMAIN" || echo "   Still cannot access APISIX locally!"

echo
echo "Integration fix complete!"
echo
echo "If you're still having issues, please check:"
echo "1. If APISIX is properly bound to all interfaces:"
echo "   docker exec apisix cat /usr/local/apisix/conf/config.yaml | grep node_listen"
echo "2. If your docker-compose file correctly maps port 9080 and 9443:"
echo "   grep -A 10 ports docker-composel.yml"
echo "3. Try restarting all services:"
echo "   docker-compose -f docker-composel.yml down"
echo "   docker-compose -f docker-composel.yml up -d"
echo
echo "Then try accessing Grafana at:"
echo "https://$DOMAIN/grafana/"
