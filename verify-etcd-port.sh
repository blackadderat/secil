#!/bin/bash

echo "===== Verifying ETCD Port Configuration ====="

# Check if etcd is running
if ! docker ps | grep -q etcd; then
  echo "Error: etcd container is not running!"
  exit 1
fi

# Check what port etcd is actually listening on
echo "Checking etcd configuration..."
docker exec etcd netstat -tlnp | grep -E '2379|2397'

# Check the environment variables in etcd
echo -e "\nChecking etcd environment variables..."
docker exec etcd env | grep -E 'ETCD_.*URL'

# Try to access etcd version endpoint directly
echo -e "\nTrying to access etcd version endpoint..."
docker exec etcd curl -s http://localhost:2379/version && echo " (Port 2379 working!)" || echo " (Port 2379 NOT working)"
docker exec etcd curl -s http://localhost:2397/version && echo " (Port 2397 working!)" || echo " (Port 2397 NOT working)"

# Restart the containers in the right order
echo -e "\nRestarting containers in the correct order..."
docker restart etcd
sleep 5
docker restart apisix
sleep 5

# Check APISIX logs after restart
echo -e "\nChecking APISIX logs after restart..."
docker logs apisix --tail 20

echo -e "\nVerification complete."
