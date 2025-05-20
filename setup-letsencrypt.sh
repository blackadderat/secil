#!/bin/bash

# This script sets up Let's Encrypt certificates for APISIX
# It uses certbot with the standalone plugin to obtain certificates

# Define your domain name and email
DOMAIN="api.secompanion.de"
EMAIL="rudi.maldaner@secompanion.de"  # Replace with your real email


# Check if Certbot is installed
if ! command -v certbot &> /dev/null; then
    echo "Certbot is required but not installed. Installing Certbot..."
    # For Ubuntu/Debian
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y certbot
    # For CentOS/RHEL
    elif command -v yum &> /dev/null; then
        sudo yum install -y certbot
    else
        echo "Error: Could not determine package manager. Please install Certbot manually."
        exit 1
    fi
fi

# Stop APISIX temporarily to free up port 80
echo "Stopping APISIX temporarily to free up port 80..."
docker compose -f docker-compose.yml stop apisix

# Wait for APISIX to stop
sleep 5

# Obtain Let's Encrypt certificate
echo "Obtaining Let's Encrypt certificate for $DOMAIN..."
sudo certbot certonly --standalone --preferred-challenges http \
  -d $DOMAIN --email $EMAIL --force-renewal --agree-tos --non-interactive

# Check if certificate was obtained
if [ ! -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    echo "Error: Failed to obtain Let's Encrypt certificate."
    echo "Starting APISIX again..."
    docker compose -f docker-compose.yml start apisix
    exit 1
fi

# Copy certificates to the SSL directory
echo "Copying Let's Encrypt certificates to SSL directory..."
sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ssl/$DOMAIN.crt
sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ssl/$DOMAIN.key
sudo chmod 644 ./ssl/$DOMAIN.crt ./ssl/$DOMAIN.key

# Prepare certificate and key for APISIX
echo "Formatting certificate and key for APISIX..."
CERT=$(cat ssl/$DOMAIN.crt | sed ':a;N;$!ba;s/\n/\\n/g')
KEY=$(cat ssl/$DOMAIN.key | sed ':a;N;$!ba;s/\n/\\n/g')

# Create a JSON file for the SSL certificate
echo "Creating JSON file for SSL certificate..."
cat > ssl/cert.json << EOL
{
    "cert": "$CERT",
    "key": "$KEY",
    "snis": ["$DOMAIN"]
}
EOL

# Start APISIX again
echo "Starting APISIX again..."
docker compose -f docker-compose.yml start apisix

# Wait for APISIX to start
echo "Waiting for APISIX to start..."
sleep 15

# Update docker compose for proper port mapping
echo "Checking Docker Compose port mapping..."
if ! grep -q "80:9080" docker-compose.yml; then
    echo "Updating Docker Compose file with proper port mapping..."
    # Create backup
    cp docker-compose.yml docker-compose.yml.bak
    # Update ports
    sed -i 's/- "9080:9080"/- "80:9080"\n      - "443:9443"/' docker-compose.yml
    # Reload with new configuration
    docker compose -f docker-compose.yml up -d
    # Wait for services to start
    sleep 10
fi

# Upload the SSL certificate to APISIX
echo "Uploading SSL certificate to APISIX..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/ssls/1" \
     -H "X-API-KEY: BTLvdLB6XptSridgdmuV" \
     -H "Content-Type: application/json" \
     --data-binary @./ssl/cert.json

# Verify if the certificate was uploaded
echo "Verifying SSL certificate..."
curl -s "http://127.0.0.1:9180/apisix/admin/ssls/1" -H "X-API-KEY: BTLvdLB6XptSridgdmuV"

# Create the necessary routes
echo "Creating routes..."

# Dashboard route
echo "Creating dashboard route..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/1" \
     -H "X-API-KEY: BTLvdLB6XptSridgdmuV" \
     -H "Content-Type: application/json" \
     -d '{
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

# API route
echo "Creating API route..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/2" \
     -H "X-API-KEY: BTLvdLB6XptSridgdmuV" \
     -H "Content-Type: application/json" \
     -d '{
        "uri": "/vendor-viasat-truck/*",
        "host": "'"$DOMAIN"'",
        "upstream": {
            "type": "roundrobin",
            "nodes": {
                "vendor-viasat-truck:7001": 1
            }
        }
    }'

# Prometheus route
echo "Creating Prometheus route..."
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

# Grafana route
echo "Creating Grafana route..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/4" \
     -H "X-API-KEY: BTLvdLB6XptSridgdmuV" \
     -H "Content-Type: application/json" \
     -d '{
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

# Jaeger route
echo "Creating Jaeger route..."
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

# HTTPBin route
echo "Creating HTTPBin route..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/6" \
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

# Loki route
echo "Creating Loki route..."
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

# Root route
echo "Creating root route..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/8" \
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

# Add HTTP to HTTPS redirect
echo "Adding HTTP to HTTPS redirect..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/9" \
     -H "X-API-KEY: BTLvdLB6XptSridgdmuV" \
     -H "Content-Type: application/json" \
     -d '{
        "uri": "/*",
        "host": "'"$DOMAIN"'",
        "vars": [
            ["scheme", "==", "http"]
        ],
        "plugins": {
            "redirect": {
                "http_to_https": true
            }
        }
    }'

# Set up automatic renewal
echo "Setting up automatic certificate renewal..."

# Create renewal script
cat > ./renew-letsencrypt.sh << EOL
#!/bin/bash

# Stop APISIX temporarily
docker compose -f docker-compose.yml stop apisix

# Wait for it to stop
sleep 5

# Renew certificates
certbot renew --quiet

# Copy certificates
if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ssl/$DOMAIN.crt
    cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ssl/$DOMAIN.key
    chmod 644 ssl/$DOMAIN.crt ssl/$DOMAIN.key
fi

# Start APISIX again
docker compose -f docker-compose.yml start apisix

# Wait for APISIX to start
sleep 10

# Format certificate and key
CERT=\$(cat ssl/$DOMAIN.crt | sed ':a;N;\$!ba;s/\\n/\\\\n/g')
KEY=\$(cat ssl/$DOMAIN.key | sed ':a;N;\$!ba;s/\\n/\\\\n/g')

# Create JSON
cat > ssl/cert.json << CERT_EOF
{
    "cert": "\$CERT",
    "key": "\$KEY",
    "snis": ["$DOMAIN"]
}
CERT_EOF

# Update certificate in APISIX
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/ssls/1" \\
     -H "X-API-KEY: BTLvdLB6XptSridgdmuV" \\
     -H "Content-Type: application/json" \\
     --data-binary @./ssl/cert.json
EOL

chmod +x ./renew-letsencrypt.sh

# Add cron job for renewal
echo "Adding cron job for automatic renewal..."
(crontab -l 2>/dev/null | grep -v "renew-letsencrypt.sh"; echo "0 3 * * * $(pwd)/renew-letsencrypt.sh > $(pwd)/renewal.log 2>&1") | crontab -

echo "Let's Encrypt certificate setup complete!"
echo "You should now be able to access your services via HTTPS:"
echo "- Dashboard: https://$DOMAIN/dashboard"
echo "- API: https://$DOMAIN/vendor-viasat-truck"
echo "- Prometheus: https://$DOMAIN/prometheus"
echo "- Grafana: https://$DOMAIN/grafana"
echo "- Jaeger: https://$DOMAIN/jaeger"
echo "- HTTPBin: https://$DOMAIN/httpbin"
echo "- Loki: https://$DOMAIN/loki"
echo ""
echo "The certificate will be automatically renewed before it expires."
