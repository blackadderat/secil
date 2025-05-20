#!/bin/bash

# Stop APISIX temporarily
docker compose -f docker-compose.yml stop apisix

# Wait for it to stop
sleep 5

# Renew certificates
certbot renew --quiet

# Copy certificates
if [ -d "/etc/letsencrypt/live/api.secompanion.de" ]; then
    cp /etc/letsencrypt/live/api.secompanion.de/fullchain.pem ssl/api.secompanion.de.crt
    cp /etc/letsencrypt/live/api.secompanion.de/privkey.pem ssl/api.secompanion.de.key
    chmod 644 ssl/api.secompanion.de.crt ssl/api.secompanion.de.key
fi

# Start APISIX again
docker compose -f docker-compose.yml start apisix

# Wait for APISIX to start
sleep 10

# Format certificate and key
CERT=$(cat ssl/api.secompanion.de.crt | sed ':a;N;$!ba;s/\n/\\n/g')
KEY=$(cat ssl/api.secompanion.de.key | sed ':a;N;$!ba;s/\n/\\n/g')

# Create JSON
cat > ssl/cert.json << CERT_EOF
{
    "cert": "$CERT",
    "key": "$KEY",
    "snis": ["api.secompanion.de"]
}
CERT_EOF

# Update certificate in APISIX
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/ssls/1" \
     -H "X-API-KEY: BTLvdLB6XptSridgdmuV" \
     -H "Content-Type: application/json" \
     --data-binary @./ssl/cert.json
