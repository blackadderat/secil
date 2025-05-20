#!/bin/bash

# Domain name
DOMAIN="api.secompanion"

# Wait for APISIX to start up
echo "Waiting for APISIX to start up..."
sleep 10

# Create SSL certificate object in APISIX
echo "Creating SSL certificate object in APISIX..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/ssls/1" -H "X-API-KEY: BTLvdLB6XptSridgdmuV" -d '{
    "cert": "'""'",
    "key": "'""'",
    "snis": ["'api.secompanion'"]
}'

# Create a route for the APISIX Dashboard under /dashboard
echo "Creating route for the APISIX Dashboard..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/1" -H "X-API-KEY: BTLvdLB6XptSridgdmuV" -d '{
    "uri": "/dashboard*",
    "host": "'api.secompanion'",
    "plugins": {
        "proxy-rewrite": {
            "regex_uri": ["^/dashboard(/.*)?$", "/"]
        }
    },
    "upstream": {
        "type": "roundrobin",
        "nodes": {
            "apisix-dashboard:9000": 1
        }
    }
}'

# Create a route for the vendor-viasat-truck API
echo "Creating route for the Viasat Truck API..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/2" -H "X-API-KEY: BTLvdLB6XptSridgdmuV" -d '{
    "uri": "/vendor-viasat-truck/*",
    "host": "'api.secompanion'",
    "upstream": {
        "type": "roundrobin",
        "nodes": {
            "vendor-viasat-truck:7001": 1
        }
    }
}'

# Create route for Prometheus
echo "Creating route for Prometheus..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/3" -H "X-API-KEY: BTLvdLB6XptSridgdmuV" -d '{
    "uri": "/prometheus*",
    "host": "'api.secompanion'",
    "plugins": {
        "proxy-rewrite": {
            "regex_uri": ["^/prometheus(/.*)?$", "/"]
        }
    },
    "upstream": {
        "type": "roundrobin",
        "nodes": {
            "prometheus:9090": 1
        }
    }
}'

# Create route for Grafana
echo "Creating route for Grafana..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/4" -H "X-API-KEY: BTLvdLB6XptSridgdmuV" -d '{
    "uri": "/grafana*",
    "host": "'api.secompanion'",
    "plugins": {
        "proxy-rewrite": {
            "regex_uri": ["^/grafana(/.*)?$", "/"]
        }
    },
    "upstream": {
        "type": "roundrobin",
        "nodes": {
            "grafana:3000": 1
        }
    }
}'

# Create route for Jaeger
echo "Creating route for Jaeger..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/5" -H "X-API-KEY: BTLvdLB6XptSridgdmuV" -d '{
    "uri": "/jaeger*",
    "host": "'api.secompanion'",
    "plugins": {
        "proxy-rewrite": {
            "regex_uri": ["^/jaeger(/.*)?$", "/"]
        }
    },
    "upstream": {
        "type": "roundrobin",
        "nodes": {
            "jaeger:16686": 1
        }
    }
}'

# Create route for HTTPBin
echo "Creating route for HTTPBin..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/6" -H "X-API-KEY: BTLvdLB6XptSridgdmuV" -d '{
    "uri": "/httpbin*",
    "host": "'api.secompanion'",
    "plugins": {
        "proxy-rewrite": {
            "regex_uri": ["^/httpbin(/.*)?$", "/"]
        }
    },
    "upstream": {
        "type": "roundrobin",
        "nodes": {
            "httpbin:8080": 1
        }
    }
}'

# Create route for Loki
echo "Creating route for Loki..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/7" -H "X-API-KEY: BTLvdLB6XptSridgdmuV" -d '{
    "uri": "/loki*",
    "host": "'api.secompanion'",
    "plugins": {
        "proxy-rewrite": {
            "regex_uri": ["^/loki(/.*)?$", "/"]
        }
    },
    "upstream": {
        "type": "roundrobin",
        "nodes": {
            "loki:3100": 1
        }
    }
}'

# Create a catch-all route for the root path
echo "Creating a route for the root path..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/8" -H "X-API-KEY: BTLvdLB6XptSridgdmuV" -d '{
    "uri": "/",
    "host": "'api.secompanion'",
    "upstream": {
        "type": "roundrobin",
        "nodes": {
            "web1:80": 1
        }
    }
}'

echo "APISIX SSL and routing configuration complete!"
echo ""
echo "Access your services securely at:"
echo "- Dashboard: https://api.secompanion/dashboard"
echo "- API: https://api.secompanion/vendor-viasat-truck"
echo "- Prometheus: https://api.secompanion/prometheus"
echo "- Grafana: https://api.secompanion/grafana"
echo "- Jaeger: https://api.secompanion/jaeger"
echo "- HTTPBin: https://api.secompanion/httpbin"
echo "- Loki: https://api.secompanion/loki"
echo ""
echo "Setting up automatic renewal for Let's Encrypt certificates..."
echo "Creating a cron job for certificate renewal..."

# Create a renewal script
cat > ./renew-certs.sh << RENEW
#!/bin/bash
# Renew certificates
certbot renew --noninteractive

# Copy renewed certificates to APISIX
if [ -f /etc/letsencrypt/live/api.secompanion/fullchain.pem ]; then
    cp /etc/letsencrypt/live/api.secompanion/fullchain.pem ./ssl/api.secompanion.crt
    cp /etc/letsencrypt/live/api.secompanion/privkey.pem ./ssl/api.secompanion.key
    chmod 644 ./ssl/api.secompanion.crt ./ssl/api.secompanion.key
fi

# Update certificates in APISIX
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/ssls/1" -H "X-API-KEY: BTLvdLB6XptSridgdmuV" -d '{
    "cert": "'""'",
    "key": "'""'",
    "snis": ["api.secompanion"]
}'
RENEW

chmod +x ./renew-certs.sh

echo "Adding cron job for certificate renewal..."
(crontab -l 2>/dev/null; echo "0 3 * * * /opt/containerd/secail/renew-certs.sh > /opt/containerd/secail/renewal.log 2>&1") | crontab -

echo "Let's Encrypt certificates will be automatically renewed."
