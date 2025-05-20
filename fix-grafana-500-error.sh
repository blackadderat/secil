#!/bin/bash

# This script fixes the 500 error when accessing Grafana through APISIX

DOMAIN="api.secompanion.de"

echo "=== Fixing Grafana 500 Internal Server Error ==="
echo

# First, create a proper Grafana configuration
echo "1. Creating updated Grafana configuration..."

# Create grafana.ini with simpler settings, focusing on the essentials
cat > conf/grafana/config/grafana.ini << EOL
[server]
# The full URL that is used to access Grafana from a web browser
root_url = https://${DOMAIN}/grafana/
# Serve Grafana from subpath specified in root_url setting
serve_from_sub_path = true

[auth.anonymous]
# enable anonymous access
enabled = true
org_role = Admin

[security]
# set to true if you want to allow browsers to render Grafana in a <frame>, <iframe>, <embed> or <object>
allow_embedding = true

[log]
# Either "console", "file", "syslog". Default is console and file
mode = console file
# Either "debug", "info", "warn", "error", "critical", default is "info"
level = debug
EOL

# Restart Grafana with the new configuration
echo "2. Restarting Grafana..."
docker restart grafana
sleep 10

# Modify APISIX route with a simpler configuration
echo "3. Creating a simpler Grafana route in APISIX..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/4" \
     -H "X-API-KEY: BTLvdLB6XptSridgdmuV" \
     -H "Content-Type: application/json" \
     -d '{
        "uri": "/grafana/*",
        "host": "'"$DOMAIN"'",
        "upstream": {
            "type": "roundrobin",
            "nodes": {
                "grafana:3000": 1
            }
        }
    }'

# Create a second route for Grafana without trailing slash
echo "4. Creating a second Grafana route for the base path..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/40" \
     -H "X-API-KEY: BTLvdLB6XptSridgdmuV" \
     -H "Content-Type: application/json" \
     -d '{
        "uri": "/grafana",
        "host": "'"$DOMAIN"'",
        "plugins": {
            "redirect": {
                "http_to_https": false,
                "uri": "/grafana/"
            }
        }
    }'

echo
echo "5. Checking the Grafana logs for any errors..."
docker logs grafana --tail 20

echo
echo "Grafana 500 error fix complete!"
echo
echo "Please follow these steps to verify:"
echo "1. Clear your browser cache completely"
echo "2. Try accessing Grafana at https://$DOMAIN/grafana/"
echo "   (Note the trailing slash is important)"
echo
echo "If you still experience issues, try the following:"
echo "1. Run: docker logs grafana --tail 50"
echo "2. Try accessing with curl: curl -L https://$DOMAIN/grafana/"
echo "3. Try accessing directly: curl -L http://localhost:3000"
