#!/bin/bash

# This script fixes all issues with APISIX SSL configuration and routing
# It addresses certificate loading, routing configuration, and port mapping

# Define your domain name
DOMAIN="api.secompanion.de"

# Set proper permissions
chmod 644 ./ssl/$DOMAIN.key ./ssl/$DOMAIN.crt

# Stop and restart the containers
echo "Restarting the containers with new configuration..."
docker-compose -f docker-compose.yml down
docker-compose -f docker-compose.yml up -d

# Wait for APISIX to start
echo "Waiting for APISIX to start..."
sleep 15

# Create the SSL configuration
echo "Creating SSL configuration in APISIX..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/ssls/1" -H "X-API-KEY: BTLvdLB6XptSridgdmuV" -d '{
    "cert": "'"$(cat ./ssl/$DOMAIN.crt | sed 's/$/\\n/' | tr -d '\n')"'",
    "key": "'"$(cat ./ssl/$DOMAIN.key | sed 's/$/\\n/' | tr -d '\n')"'",
    "snis": ["'"$DOMAIN"'"]
}'

# Verify the SSL configuration was created
echo -e "\nVerifying SSL configuration:"
curl -s "http://127.0.0.1:9180/apisix/admin/ssls/1" -H "X-API-KEY: BTLvdLB6XptSridgdmuV"

echo -e "\nCreating route for the APISIX Dashboard..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/1" -H "X-API-KEY: BTLvdLB6XptSridgdmuV" -d '{
    "uri": "/dashboard*",
    "host": "'"$DOMAIN"'",
    "plugins": {
        "proxy-rewrite": {
            "regex_uri": ["^/dashboard(/.*)?$", "/$1"],
            "headers": {
                "X-Forwarded-Proto": "https"
            }
        }
    },
    "upstream": {
        "type": "roundrobin",
        "nodes": {
            "apisix-dashboard:9000": 1
        }
    }
}'

echo -e "\nCreating route for the Viasat Truck API..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/2" -H "X-API-KEY: BTLvdLB6XptSridgdmuV" -d '{
    "uri": "/vendor-viasat-truck/*",
    "host": "'"$DOMAIN"'",
    "upstream": {
        "type": "roundrobin",
        "nodes": {
            "vendor-viasat-truck:7001": 1
        }
    }
}'

echo -e "\nCreating Prometheus route..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/3" -H "X-API-KEY: BTLvdLB6XptSridgdmuV" -d '{
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

echo -e "\nCreating Grafana route..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/4" -H "X-API-KEY: BTLvdLB6XptSridgdmuV" -d '{
    "uri": "/grafana*",
    "host": "'"$DOMAIN"'",
    "plugins": {
        "proxy-rewrite": {
            "regex_uri": ["^/grafana(/.*)?$", "/$1"],
            "headers": {
                "X-Forwarded-Proto": "https"
            }
        }
    },
    "upstream": {
        "type": "roundrobin",
        "nodes": {
            "grafana:3000": 1
        }
    }
}'

echo -e "\nCreating Jaeger route..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/5" -H "X-API-KEY: BTLvdLB6XptSridgdmuV" -d '{
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

echo -e "\nCreating HTTPBin route..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/6" -H "X-API-KEY: BTLvdLB6XptSridgdmuV" -d '{
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

echo -e "\nCreating Loki route..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/7" -H "X-API-KEY: BTLvdLB6XptSridgdmuV" -d '{
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

echo -e "\nCreating root route..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/8" -H "X-API-KEY: BTLvdLB6XptSridgdmuV" -d '{
    "uri": "/",
    "host": "'"$DOMAIN"'",
    "upstream": {
        "type": "roundrobin",
        "nodes": {
            "web1:80": 1
        }
    }
}'

# Adding HTTP to HTTPS redirect
echo -e "\nCreating HTTP to HTTPS redirect..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/9" -H "X-API-KEY: BTLvdLB6XptSridgdmuV" -d '{
    "uri": "/*",
    "host": "'"$DOMAIN"'",
    "plugins": {
        "redirect": {
            "http_to_https": true
        }
    }
}'

echo -e "\nVerifying all routes have been created:"
curl -s "http://127.0.0.1:9180/apisix/admin/routes" -H "X-API-KEY: BTLvdLB6XptSridgdmuV" | grep -o '"id":"[^"]*"' | sort

echo -e "\nConfiguration complete!"
echo "You should now be able to access your services at:"
echo "- Dashboard: https://$DOMAIN/dashboard"
echo "- API: https://$DOMAIN/vendor-viasat-truck"
echo "- Prometheus: https://$DOMAIN/prometheus"
echo "- Grafana: https://$DOMAIN/grafana"
echo "- Jaeger: https://$DOMAIN/jaeger"
echo "- HTTPBin: https://$DOMAIN/httpbin"
echo "- Loki: https://$DOMAIN/loki"
echo ""
echo "Note: Since this is using a self-signed certificate, your browser will show a security warning."
echo "This is normal for testing environments."

# Run the diagnostic tool again to verify everything is working
echo -e "\nRunning diagnostic tool to verify the fix..."
./diagnose-apisix.sh
