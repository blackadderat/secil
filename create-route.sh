#!/bin/bash
# Beispiel: Erstellt eine Route in APISIX für den Viasat Truck Adapter

curl -X PUT http://localhost:9180/apisix/admin/routes/1 \
  -H 'X-API-KEY: edgex' \
  -d '
{
  "uri": "/viasat-truck",
  "methods": ["POST"],
  "plugins": {
    "key-auth": {},
    "limit-count": {
      "count": 100,
      "time_window": 60,
      "rejected_code": 429
    }
  },
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "vendor-viasat-truck:7001": 1
    }
  }
}'
