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
