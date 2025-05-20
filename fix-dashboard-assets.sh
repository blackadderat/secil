#!/bin/bash

# This script fixes the issue with static assets not loading for the dashboard

DOMAIN="api.secompanion.de"

echo "=== Fixing Dashboard Static Assets Issue ==="
echo

# Create a route for dashboard static assets
echo "Creating route for dashboard static assets..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/10" \
     -H "X-API-KEY: BTLvdLB6XptSridgdmuV" \
     -H "Content-Type: application/json" \
     -d '{
        "uri": "/*",
        "host": "'"$DOMAIN"'",
        "plugins": {
            "proxy-rewrite": {
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
        },
        "priority": 5
    }'

# Set a priority of 5 to make it lower priority than the specific routes,
# but higher than the default catch-all route which has priority 0

echo
echo "Static assets routing has been fixed!"
echo "You should now be able to access the dashboard with all static assets loading properly."
echo "Visit https://$DOMAIN/dashboard to verify."
