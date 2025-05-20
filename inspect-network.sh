#!/bin/bash

echo "=== Docker Network Inspection ==="
echo "Checking which networks each container is connected to..."

echo -e "\n--- ETCD Networks ---"
docker inspect -f '{{range $net, $config := .NetworkSettings.Networks}}{{$net}} {{end}}' etcd

echo -e "\n--- APISIX Networks ---"
docker inspect -f '{{range $net, $config := .NetworkSettings.Networks}}{{$net}} {{end}}' apisix

echo -e "\n--- Network Details ---"
docker network ls

echo -e "\n--- Containers in the 'internal' network ---"
docker network inspect internal -f '{{range .Containers}}{{.Name}} {{end}}'

echo -e "\n--- Testing DNS Resolution from APISIX ---"
docker exec apisix ping -c 2 etcd

echo -e "\n--- Checking Network Interface in APISIX ---"
docker exec apisix ip addr

echo -e "\n--- Checking hosts file in APISIX ---"
docker exec apisix cat /etc/hosts
