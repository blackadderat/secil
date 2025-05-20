#!/bin/bash

# This script creates or updates all routes for the services

DOMAIN="api.secompanion.de"

echo "=== Creating Routes for All Services ==="
echo

# 1. Vendor-Viasat-Truck Route
echo "1. Creating/updating Vendor-Viasat-Truck route..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/2" \
     -H "X-API-KEY: BTLvdLB6XptSridgdmuV" \
     -H "Content-Type: application/json" \
     -d '{
        "uri": "/vendor-viasat-truck*",
        "host": "'"$DOMAIN"'",
        "upstream": {
            "type": "roundrobin",
            "nodes": {
                "vendor-viasat-truck:7001": 1
            }
        }
    }'

# 2. Prometheus Route
echo "2. Creating/updating Prometheus route..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/3" \
     -H "X-API-KEY: BTLvdLB6XptSridgdmuV" \
     -H "Content-Type: application/json" \
     -d '{
        "uri": "/prometheus*",
        "host": "'"$DOMAIN"'",
        "plugins": {
            "proxy-rewrite": {
                "regex_uri": ["^/prometheus(/.*)?$", "/$1"],
                "headers": {
                    "X-Forwarded-Proto": "https"
                }
            }
        },
        "upstream": {
            "type": "roundrobin",
            "nodes": {
                "prometheus:9090": 1
            }
        }
    }'

# 3. Grafana Route (already updated in fix-grafana.sh)
echo "3. Grafana route already updated in fix-grafana.sh"

# 4. Jaeger Route
echo "4. Creating/updating Jaeger route..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/5" \
     -H "X-API-KEY: BTLvdLB6XptSridgdmuV" \
     -H "Content-Type: application/json" \
     -d '{
        "uri": "/jaeger*",
        "host": "'"$DOMAIN"'",
        "plugins": {
            "proxy-rewrite": {
                "regex_uri": ["^/jaeger(/.*)?$", "/$1"],
                "headers": {
                    "X-Forwarded-Proto": "https"
                }
            }
        },
        "upstream": {
            "type": "roundrobin",
            "nodes": {
                "jaeger:16686": 1
            }
        }
    }'

# 5. Kafka Route (if needed)
echo "5. Creating/updating Kafka route..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/6" \
     -H "X-API-KEY: BTLvdLB6XptSridgdmuV" \
     -H "Content-Type: application/json" \
     -d '{
        "uri": "/kafka*",
        "host": "'"$DOMAIN"'",
        "plugins": {
            "proxy-rewrite": {
                "regex_uri": ["^/kafka(/.*)?$", "/$1"],
                "headers": {
                    "X-Forwarded-Proto": "https"
                }
            }
        },
        "upstream": {
            "type": "roundrobin",
            "nodes": {
                "kafka:9092": 1
            }
        }
    }'

# 6. Loki Route (for logging visualization)
echo "6. Creating/updating Loki route..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/7" \
     -H "X-API-KEY: BTLvdLB6XptSridgdmuV" \
     -H "Content-Type: application/json" \
     -d '{
        "uri": "/loki*",
        "host": "'"$DOMAIN"'",
        "plugins": {
            "proxy-rewrite": {
                "regex_uri": ["^/loki(/.*)?$", "/$1"],
                "headers": {
                    "X-Forwarded-Proto": "https"
                }
            }
        },
        "upstream": {
            "type": "roundrobin",
            "nodes": {
                "loki:3100": 1
            }
        }
    }'

# 7. Httpbin Route (for testing)
echo "7. Creating/updating Httpbin route..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/8" \
     -H "X-API-KEY: BTLvdLB6XptSridgdmuV" \
     -H "Content-Type: application/json" \
     -d '{
        "uri": "/httpbin*",
        "host": "'"$DOMAIN"'",
        "plugins": {
            "proxy-rewrite": {
                "regex_uri": ["^/httpbin(/.*)?$", "/$1"],
                "headers": {
                    "X-Forwarded-Proto": "https"
                }
            }
        },
        "upstream": {
            "type": "roundrobin",
            "nodes": {
                "httpbin:8080": 1
            }
        }
    }'

# 8. Root route (for default landing page)
echo "8. Creating/updating Root route..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/11" \
     -H "X-API-KEY: BTLvdLB6XptSridgdmuV" \
     -H "Content-Type: application/json" \
     -d '{
        "uri": "/",
        "host": "'"$DOMAIN"'",
        "upstream": {
            "type": "roundrobin",
            "nodes": {
                "web1:80": 1
            }
        }
    }'

echo
echo "All routes created successfully!"
echo
echo "Now you can access the following services:"
echo "- API: https://$DOMAIN/vendor-viasat-truck"
echo "- Prometheus: https://$DOMAIN/prometheus"
echo "- Grafana: https://$DOMAIN/grafana"
echo "- Jaeger: https://$DOMAIN/jaeger"
echo "- Kafka: https://$DOMAIN/kafka (Note: This might not work directly, as Kafka isn't HTTP-based)"
echo "- Loki: https://$DOMAIN/loki"
echo "- Httpbin: https://$DOMAIN/httpbin"
echo
echo "Remember to run the fix-grafana.sh script to properly set up Grafana with sub-path support."
