#!/bin/bash

# Print header
echo "===== APISIX Integration Troubleshooter ====="

# Function to check if a container exists and is running
check_container() {
  local container=$1
  if ! docker ps -q -f name=$container | grep -q .; then
    echo "Error: $container container is not running!"
    return 1
  else
    echo "$container container is running"
    return 0
  fi
}

# Check if all required containers are running
echo -e "\n--- Container Status ---"
containers=("etcd" "apisix" "kafka" "zookeeper" "vendor-viasat-truck")
all_running=true

for container in "${containers[@]}"; do
  if ! check_container "$container"; then
    all_running=false
  fi
done

if [ "$all_running" = false ]; then
  echo "Not all required containers are running. Starting them up..."
  docker-compose up -d
  echo "Waiting for containers to start..."
  sleep 10
fi

# Get IP addresses of all containers in the internal network
echo -e "\n--- Container IP Addresses ---"
for container in "${containers[@]}"; do
  ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $container)
  echo "$container: $ip"
done

# Fix /etc/hosts in APISIX container to ensure DNS resolution
echo -e "\n--- Fixing APISIX hosts file ---"
etcd_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' etcd)
echo "ETCD IP: $etcd_ip"

echo "Adding etcd to APISIX hosts file..."
docker exec apisix bash -c "echo '$etcd_ip etcd' >> /etc/hosts"
docker exec apisix cat /etc/hosts

# Test DNS resolution from APISIX to etcd
echo -e "\n--- Testing DNS resolution ---"
docker exec apisix ping -c 2 etcd || echo "Ping failed, but this might be due to ICMP being blocked"

# Test HTTP connection from APISIX to etcd
echo -e "\n--- Testing HTTP connection ---"
docker exec apisix curl -s http://etcd:2379/version || echo "HTTP connection failed"

# Try running APISIX init commands manually
echo -e "\n--- Running APISIX init commands manually ---"
docker exec apisix /usr/bin/apisix init
docker exec apisix /usr/bin/apisix init_etcd

# Check APISIX logs
echo -e "\n--- APISIX Logs ---"
docker logs apisix --tail 20

# Restart APISIX to apply changes
echo -e "\n--- Restarting APISIX ---"
docker restart apisix
echo "Waiting for APISIX to restart..."
sleep 10

# Check APISIX logs after restart
echo -e "\n--- APISIX Logs after restart ---"
docker logs apisix --tail 20

echo -e "\n--- Troubleshooting complete ---"
echo "If issues persist, try the following:"
echo "1. docker-compose down -v"
echo "2. docker-compose up -d"
echo "3. Run this script again after services have started"
