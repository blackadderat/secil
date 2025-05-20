#!/bin/bash

# This script fixes the redirection loop in Grafana

DOMAIN="api.secompanion.de"

echo "=== Fixing Grafana Redirection Loop ==="
echo

# Update Grafana configuration to handle sub-path correctly
echo "1. Updating Grafana configuration..."

# Create grafana.ini with the correct settings
cat > conf/grafana/config/grafana.ini << EOL
[server]
domain = ${DOMAIN}
root_url = %(protocol)s://%(domain)s/grafana
serve_from_sub_path = true

[security]
allow_embedding = true

[auth.anonymous]
enabled = true

[analytics]
reporting_enabled = false
check_for_updates = false
EOL

# Update the APISIX route for Grafana with more precise configuration
echo "2. Updating Grafana route in APISIX..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/4" \
     -H "X-API-KEY: BTLvdLB6XptSridgdmuV" \
     -H "Content-Type: application/json" \
     -d '{
        "uri": "/grafana*",
        "host": "'"$DOMAIN"'",
        "plugins": {
            "proxy-rewrite": {
                "regex_uri": ["^/grafana(/?.*)", "$1"],
                "headers": {
                    "X-Forwarded-Proto": "https",
                    "X-Forwarded-Prefix": "/grafana"
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

# Restart Grafana to apply changes
echo "3. Restarting Grafana..."
docker restart grafana
sleep 5

echo
echo "Grafana redirection loop fixed!"
echo
echo "Please follow these steps to verify:"
echo "1. Clear your browser cache completely (or use incognito/private mode)"
echo "2. Try accessing Grafana at https://$DOMAIN/grafana"
echo
echo "Note: It may take a moment for Grafana to restart and apply the changes."
