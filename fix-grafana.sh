#!/bin/bash

# This script fixes the Grafana integration

DOMAIN="api.secompanion.de"

echo "=== Fixing Grafana Integration ==="
echo

# Update Grafana configuration to support sub-path
echo "1. Updating Grafana configuration..."

# Create grafana.ini config file directory if it doesn't exist
mkdir -p conf/grafana/config

# Create grafana.ini with root_url config for sub-path
cat > conf/grafana/config/grafana.ini << EOL
[server]
domain = ${DOMAIN}
root_url = https://${DOMAIN}/grafana
serve_from_sub_path = true

[security]
allow_embedding = true

[auth.anonymous]
enabled = true
EOL

# Restart Grafana to apply the changes
echo "2. Restarting Grafana..."
docker restart grafana
sleep 5

# Update the Grafana route in APISIX with specialized proxy-rewrite configuration
echo "3. Updating Grafana route in APISIX..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/4" \
     -H "X-API-KEY: BTLvdLB6XptSridgdmuV" \
     -H "Content-Type: application/json" \
     -d '{
        "uri": "/grafana*",
        "host": "'"$DOMAIN"'",
        "plugins": {
            "proxy-rewrite": {
                "regex_uri": ["^/grafana(/.*)?$", "/$1"],
                "headers": {
                    "X-Forwarded-Proto": "https"
                }
            }
        },
        "upstream": {
            "type": "roundrobin",
            "nodes": {
                "grafana:3000": 1
            }
        },
        "priority": 10
    }'

echo
echo "Grafana integration has been fixed!"
echo "You should now be able to access Grafana at https://$DOMAIN/grafana"
echo
echo "Note: It may take a moment for Grafana to restart and the changes to take effect."
echo "If you still see the error message, try clearing your browser cache or opening in a private/incognito window."
