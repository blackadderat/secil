#!/bin/bash

# This script checks APISIX port configuration and verifies no conflicts exist

echo "=== APISIX Port Configuration Check ==="
echo

# Check APISIX configuration for port settings
echo "Checking APISIX configuration for port settings..."
docker exec apisix cat /usr/local/apisix/conf/config.yaml | grep -A 3 "admin_listen:" || echo "admin_listen not found"
docker exec apisix cat /usr/local/apisix/conf/config.yaml | grep -A 3 "control:" || echo "control not found"

# Check running ports in APISIX container
echo -e "\nChecking which ports APISIX is listening on..."
docker exec apisix netstat -tulpn | grep -E '9080|9180|9190|9443' || echo "Failed to get listening ports"

# Check Docker port mappings
echo -e "\nChecking Docker port mappings..."
docker port apisix

# Check APISIX logs for port conflict messages
echo -e "\nChecking APISIX logs for port conflict messages..."
docker logs apisix | grep -E "port conflict|conflicts with" | tail -10

# Check if APISIX is running correctly
echo -e "\nChecking if APISIX is running correctly..."
if docker ps | grep apisix | grep -q "Up"; then
    echo "APISIX is running."
    echo "Status: $(docker ps | grep apisix | awk '{print $NF, $7, $8}')"
else
    echo "APISIX is not running or has issues."
    echo "Container status: $(docker ps -a | grep apisix)"
fi

# Test admin API
echo -e "\nTesting admin API..."
curl -s -i "http://127.0.0.1:9180/apisix/admin/routes" -H "X-API-KEY: BTLvdLB6XptSridgdmuV" | head -20

# Check SSL configuration
echo -e "\nChecking SSL configuration..."
curl -s "http://127.0.0.1:9180/apisix/admin/ssls" -H "X-API-KEY: BTLvdLB6XptSridgdmuV" | grep -o '"snis":\[[^]]*\]' || echo "No SSL configuration found."

echo
echo "Port configuration check complete."
echo "If you see port conflict messages or APISIX is not running correctly,"
echo "run fix-port-conflict.sh to resolve the issues."
