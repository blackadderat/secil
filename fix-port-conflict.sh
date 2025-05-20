#!/bin/bash

# This script fixes the port conflict between control port and admin port in APISIX
# APISIX is reporting: "control port 9180 conflicts with admin port"

DOMAIN="api.secompanion.de"

echo "=== Fixing APISIX Port Conflict ==="
echo

# Create config directory if it doesn't exist

# Create SSL directory if it doesn't exist

# Update APISIX configuration to use different ports for control and admin
echo "Updating APISIX configuration..."
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
    # Set the admin port to 9180
    admin_listen:
      ip: 0.0.0.0
      port: 9180
  etcd:
    host:
      - http://etcd:2379

# APISIX configuration
apisix:
  node_listen: 9080
  enable_admin: true
  enable_control: true
  # Set the control port to a different value, e.g., 9190
  control:
    ip: "0.0.0.0"
    port: 9190
  ssl:
    enable: true
    listen_port: 9443
    ssl_protocols: TLSv1.2 TLSv1.3
    ssl_ciphers: ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384

plugins:
  - http-logger
  - ip-restriction
  - jwt-auth
  - key-auth
  - basic-auth
  - limit-conn
  - limit-count
  - limit-req
  - prometheus
  - serverless-post-function
  - serverless-pre-function
  - zipkin
  - traffic-split
  - azure-functions
  - public-api
  - consumer-restriction
  - loki-logger
  - opentelemetry
  - proxy-rewrite
  - cors
  - redirect

plugin_attr:
  prometheus:
    export_addr:
      ip: 0.0.0.0
      port: 9091
  opentelemetry:
    collector:
      address: jaeger:4318

ext-plugin:
  path_for_test: /tmp/runner.sock
EOL

echo "APISIX configuration updated. Now restarting APISIX..."
docker compose -f docker-compose.yml restart apisix

# Wait for APISIX to restart
echo "Waiting for APISIX to restart..."
sleep 15

# Check if APISIX is running
echo "Checking if APISIX is running..."
if docker ps | grep -q apisix; then
    echo "APISIX is running."
else
    echo "APISIX is not running. Check logs."
    docker logs apisix
    exit 1
fi

# Now that APISIX is running with the fixed configuration, let's set up the SSL certificate
echo "Setting up SSL certificate..."

# Check if Let's Encrypt certificates exist
if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ] || [ ! -f "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]; then
    echo "Error: Let's Encrypt certificates not found for $DOMAIN."
    echo "You need to obtain Let's Encrypt certificates first."
    exit 1
fi

# Copy certificates
echo "Copying Let's Encrypt certificates..."
sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ssl/$DOMAIN.crt
sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ssl/$DOMAIN.key
sudo chmod 644 ssl/$DOMAIN.crt ssl/$DOMAIN.key

# Format certificates for APISIX
echo "Formatting certificates for APISIX..."
CERT=$(cat ssl/$DOMAIN.crt | awk 'NF {sub(/\r/, ""); printf "%s\\n", $0}')
KEY=$(cat ssl/$DOMAIN.key | awk 'NF {sub(/\r/, ""); printf "%s\\n", $0}')

# Create a JSON file for SSL configuration
echo "Creating JSON file for SSL configuration..."
cat > ssl/cert.json << EOL
{
    "cert": "$CERT",
    "key": "$KEY",
    "snis": ["$DOMAIN"]
}
EOL

# Check for existing SSL configurations
echo "Checking for existing SSL configurations..."
SSL_IDS=$(curl -s "http://127.0.0.1:9180/apisix/admin/ssls" -H "X-API-KEY: BTLvdLB6XptSridgdmuV" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

if [ -n "$SSL_IDS" ]; then
    echo "Removing existing SSL configurations..."
    for ID in $SSL_IDS; do
        echo "Removing SSL configuration with ID: $ID"
        curl -X DELETE "http://127.0.0.1:9180/apisix/admin/ssls/$ID" -H "X-API-KEY: BTLvdLB6XptSridgdmuV"
    done
fi

# Upload the SSL certificate
echo "Uploading SSL certificate to APISIX..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/ssls/1" \
     -H "X-API-KEY: BTLvdLB6XptSridgdmuV" \
     -H "Content-Type: application/json" \
     --data-binary @ssl/cert.json

# Verify the SSL configuration
echo "Verifying SSL configuration..."
curl -s "http://127.0.0.1:9180/apisix/admin/ssls" -H "X-API-KEY: BTLvdLB6XptSridgdmuV"

# Set up routes
echo "Setting up routes..."

# Dashboard route
echo "Creating dashboard route..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/1" \
     -H "X-API-KEY: BTLvdLB6XptSridgdmuV" \
     -H "Content-Type: application/json" \
     -d '{
        "uri": "/dashboard*",
        "host": "'"$DOMAIN"'",
        "plugins": {
            "proxy-rewrite": {
                "regex_uri": ["^/dashboard(/.*)?$", "/$1"],
                "headers": {
                    "X-Forwarded-Proto": "https"
                }
            }
        },
        "upstream": {
            "type": "roundrobin",
            "nodes": {
                "apisix-dashboard:9000": 1
            }
        }
    }'

# API route
echo "Creating API route..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/2" \
     -H "X-API-KEY: BTLvdLB6XptSridgdmuV" \
     -H "Content-Type: application/json" \
     -d '{
        "uri": "/vendor-viasat-truck/*",
        "host": "'"$DOMAIN"'",
        "upstream": {
            "type": "roundrobin",
            "nodes": {
                "vendor-viasat-truck:7001": 1
            }
        }
    }'

# Add HTTP to HTTPS redirect
echo "Adding HTTP to HTTPS redirect..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/9" \
     -H "X-API-KEY: BTLvdLB6XptSridgdmuV" \
     -H "Content-Type: application/json" \
     -d '{
        "uri": "/*",
        "plugins": {
            "redirect": {
                "http_to_https": true
            }
        }
    }'

echo
echo "Port conflict fixed and SSL configuration set up!"
echo "You should now be able to access your services via HTTPS:"
echo "- Dashboard: https://$DOMAIN/dashboard"
echo "- API: https://$DOMAIN/vendor-viasat-truck"
echo
echo "Run check-letsencrypt.sh again to verify the configuration."
