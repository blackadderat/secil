#!/bin/bash

# This script performs deep diagnostics on Grafana's 500 error

DOMAIN="api.secompanion.de"

echo "=== Deep Diagnostics for Grafana 500 Error ==="
echo

# 1. Get Grafana container info
echo "1. Checking Grafana container details..."
docker inspect grafana | grep -E "\"Image\"|\"Name\"|\"Status\"|\"Health\""

# 2. Check if Grafana is listening properly
echo -e "\n2. Checking if Grafana is listening on port 3000..."
docker exec grafana netstat -tulpn | grep 3000 || echo "   Grafana is not listening on port 3000!"

# 3. Check direct access to Grafana
echo -e "\n3. Testing direct access to Grafana..."
# First check internally in the container
echo "   a. Testing directly inside container:"
docker exec grafana wget -qO- localhost:3000/api/health || echo "   Cannot access Grafana health endpoint inside container!"

# Then check from host
echo "   b. Testing from host to container:"
curl -s http://localhost:3000/api/health || echo "   Cannot access Grafana health endpoint from host!"

# 4. Check all APISIX routes to understand the routing configuration
echo -e "\n4. Checking all APISIX routes..."
curl -s "http://127.0.0.1:9180/apisix/admin/routes" -H "X-API-KEY: BTLvdLB6XptSridgdmuV" | grep -o '"id":"[0-9]*"'

# 5. Test APISIX routing to Grafana specifically
echo -e "\n5. Testing APISIX routing to Grafana..."
curl -s -I "http://localhost:9080/grafana/" -H "Host: $DOMAIN" || echo "   Cannot access Grafana through APISIX"

# 6. Check volume mounts to ensure configuration is properly mounted
echo -e "\n6. Checking volume mounts for Grafana..."
docker inspect grafana | grep -A 10 "Mounts"

# 7. Check Grafana logs specifically focusing on 500 errors
echo -e "\n7. Checking Grafana logs for 500 errors..."
docker logs grafana --tail 50 | grep -i "error\|warn\|exception\|failed"

# 8. Try making a basic non-proxied Grafana test page to check if Grafana works at all
echo -e "\n8. Creating a basic test page to check if Grafana is functional..."
cat > test-grafana.html << EOL
<!DOCTYPE html>
<html>
<head>
    <title>Grafana Test</title>
</head>
<body>
    <h1>Grafana Direct Access Test</h1>
    <p>Testing direct access to Grafana (no APISIX proxy):</p>
    <iframe src="http://localhost:3000" width="800" height="600"></iframe>
</body>
</html>
EOL

echo "   Created test-grafana.html - you can open this in your browser to test direct access"

# 9. Check if APISIX is modifying the request in some problematic way
echo -e "\n9. Checking APISIX request modification (tracing a request)..."
curl -v "http://localhost:9080/grafana/" -H "Host: $DOMAIN" 2>&1 | grep -E "^\*|^>|^<" | head -20

echo
echo "Deep diagnostics complete!"
echo
echo "Based on the output above, check for:"
echo "1. Is Grafana running and accessible directly? (Steps 1-3)"
echo "2. Are the APISIX routes configured correctly? (Steps 4-5)"
echo "3. Is the Grafana configuration properly mounted? (Step 6)"
echo "4. Are there errors in the Grafana logs? (Step 7)"
echo "5. Can you access Grafana directly (non-proxied)? (Step 8)"
echo "6. Is APISIX modifying the request in a problematic way? (Step 9)"
echo
echo "Next steps:"
echo "- Compare the diagnostics against expected results"
echo "- Try the fix-grafana-500-error.sh script"
echo "- Consider temporarily simplifying the configuration for testing"
