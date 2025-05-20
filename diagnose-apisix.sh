#!/bin/bash

# This script performs comprehensive diagnostics on APISIX

DOMAIN="api.secompanion.de"

echo "=== APISIX Comprehensive Diagnostics ==="
echo

# Check if APISIX container is running
echo "1. Checking APISIX container status..."
if docker ps | grep -q apisix; then
    echo "   APISIX container is running"
    docker ps | grep apisix
else
    echo "   ERROR: APISIX container is not running!"
    docker ps -a | grep apisix
    echo "   Try starting it with: docker start apisix"
    exit 1
fi

# Check APISIX port bindings
echo -e "\n2. Checking APISIX port bindings..."
APISIX_PORTS=$(docker port apisix)
echo "$APISIX_PORTS"

# Verify configuration
echo -e "\n3. Checking APISIX configuration..."
docker exec apisix cat /usr/local/apisix/conf/config.yaml | grep -E "node_listen|admin_listen|control:|port:"

# Check if APISIX is listening on ports internally
echo -e "\n4. Checking ports APISIX is listening on internally..."
docker exec apisix netstat -tulpn | grep -E "9080|9180|9190|9443" || echo "   APISIX is not listening on expected ports!"

# Check if admin API is accessible
echo -e "\n5. Checking admin API access..."
curl -s "http://127.0.0.1:9180/apisix/admin/routes" -H "X-API-KEY: BTLvdLB6XptSridgdmuV" | grep -o '"total":[0-9]*' || echo "   Cannot access admin API!"

# Check network interfaces in APISIX container
echo -e "\n6. Checking network interfaces in APISIX container..."
docker exec apisix ip addr

# Check if APISIX is accessible from localhost
echo -e "\n7. Testing local access to APISIX..."
curl -s -I "http://localhost:9080" || echo "   Cannot access APISIX on port 9080!"

# Check if APISIX responds on public IP
echo -e "\n8. Testing access to APISIX on public interfaces..."
PUBLIC_IP=$(hostname -I | awk '{print $1}')
curl -s -I "http://$PUBLIC_IP:9080" || echo "   Cannot access APISIX on public interface!"

# Check Docker network configuration
echo -e "\n9. Checking Docker network configuration..."
docker network inspect secail_default | grep -A 20 "Containers" | grep -A 5 "apisix"

# Check APISIX logs for errors
echo -e "\n10. Checking APISIX logs for errors..."
docker logs apisix --tail 50 | grep -i "error\|warn\|failed"

# Check if SSL is properly configured
echo -e "\n11. Checking SSL configuration..."
curl -s "http://127.0.0.1:9180/apisix/admin/ssls" -H "X-API-KEY: BTLvdLB6XptSridgdmuV" | grep -o '"snis":\[[^]]*\]' || echo "   No SSL configuration found!"

# Test SSL access
echo -e "\n12. Testing SSL access..."
curl -k -s -I "https://localhost:9443" || echo "   Cannot access APISIX SSL endpoint!"

# Check docker-compose file
echo -e "\n13. Checking docker-compose file port mappings..."
if [ -f docker-compose.yml ]; then
    grep -A 15 "apisix:" docker-compose.yml | grep -A 10 "ports:"
else
    echo "   docker-compose.yml not found!"
fi

# Create a test route and verify it works
echo -e "\n14. Creating and testing a simple route..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/999" \
     -H "X-API-KEY: BTLvdLB6XptSridgdmuV" \
     -H "Content-Type: application/json" \
     -d '{
        "uri": "/test",
        "upstream": {
            "type": "roundrobin",
            "nodes": {
                "httpbin:8080": 1
            }
        }
    }'

echo -e "\n    Testing the route..."
curl -s -I "http://localhost:9080/test" || echo "   Route test failed!"

echo
echo "APISIX diagnostics complete!"
echo
echo "If you're seeing issues with APISIX accessibility, check:"
echo "1. Docker port bindings (should map 9080 and 9443 to host)"
echo "2. APISIX node_listen configuration (should be 9080)"
echo "3. Firewall settings that might be blocking access"
echo "4. Network mode in docker-compose (bridge vs host)"
echo
echo "If admin API is not accessible, check:"
echo "1. admin_listen configuration (should be 0.0.0.0:9180)"
echo "2. admin_key settings (should match what you're using in API calls)"
echo
echo "To restart APISIX cleanly:"
echo "docker-compose -f docker-composel.yml stop apisix"
echo "docker-compose -f docker-composel.yml start apisix"
