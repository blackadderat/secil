#!/bin/bash

# This script checks the Grafana configuration and helps diagnose issues

DOMAIN="api.secompanion.de"

echo "=== Grafana Configuration Check ==="
echo

# Check if Grafana container is running
echo "1. Checking if Grafana container is running..."
if docker ps | grep -q grafana; then
    echo "   OK - Grafana container is running"
    docker ps | grep grafana
else
    echo "   ERROR - Grafana container is not running"
    docker ps -a | grep grafana
    exit 1
fi

# Check Grafana configuration
echo -e "\n2. Checking Grafana configuration..."
echo "   Current grafana.ini contents:"
docker exec grafana cat /etc/grafana/grafana.ini | grep -v "^;" | grep -v "^$"

# Check APISIX Grafana route
echo -e "\n3. Checking APISIX Grafana route configuration..."
curl -s "http://127.0.0.1:9180/apisix/admin/routes/4" -H "X-API-KEY: BTLvdLB6XptSridgdmuV"

# Test direct connection to Grafana
echo -e "\n4. Testing direct connection to Grafana container..."
curl -s -I http://localhost:3000 | head -5 || echo "   Cannot connect directly to Grafana"

# Test Grafana through APISIX
echo -e "\n5. Testing Grafana through APISIX (HTTP)..."
curl -s -I "http://localhost:9080/grafana" -H "Host: $DOMAIN" | head -5 || echo "   Cannot connect to Grafana through APISIX HTTP"

echo -e "\n6. Checking for redirection issues..."
docker logs grafana --tail 50 | grep -i "redirect\|not found\|error"

echo -e "\n7. Testing basic Grafana API endpoint..."
curl -s "http://localhost:9080/grafana/api/health" -H "Host: $DOMAIN" || echo "   Cannot connect to Grafana API"

echo
echo "Grafana configuration check complete!"
echo
echo "If you're still experiencing redirection loop issues:"
echo "1. Try accessing using curl:"
echo "   curl -L -v https://$DOMAIN/grafana"
echo "2. Clear browser cache or use incognito/private mode"
echo "3. Try a different browser"
echo "4. Check Grafana logs for more details: docker logs grafana"
