#!/bin/bash

# This script specifically fixes the SNI issue with Let's Encrypt certificates in APISIX
DOMAIN="api.secompanion.de"

echo "=== Fixing SNI Issue for Let's Encrypt Certificates ==="
echo

# Check if certificates exist
if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ] || [ ! -f "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]; then
    echo "Error: Let's Encrypt certificates not found for $DOMAIN."
    echo "Run setup-letsencrypt.sh first to obtain certificates."
    exit 1
fi

# Create SSL directory if it doesn't exist

# Copy certificates
echo "Copying certificates from Let's Encrypt to SSL directory..."
sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ssl/$DOMAIN.crt
sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ssl/$DOMAIN.key
sudo chmod 644 ./ssl/$DOMAIN.crt ./ssl/$DOMAIN.key

# Verify certificates
echo "Verifying certificate files..."
if [ ! -f "ssl/$DOMAIN.crt" ] || [ ! -f "ssl/$DOMAIN.key" ]; then
    echo "Error: Failed to copy certificates."
    exit 1
fi

echo "Certificate files verified."

# Format certificates for JSON
echo "Formatting certificates for APISIX..."
CERT=$(cat ssl/$DOMAIN.crt | awk 'NF {sub(/\r/, ""); printf "%s\\n", $0}')
KEY=$(cat ssl/$DOMAIN.key | awk 'NF {sub(/\r/, ""); printf "%s\\n", $0}')

# Create a proper JSON file for SSL configuration
echo "Creating JSON configuration file..."
cat > ssl/cert.json << EOL
{
    "cert": "$CERT",
    "key": "$KEY",
    "snis": ["$DOMAIN"]
}
EOL

# Check for existing SSL configuration
echo "Checking for existing SSL configuration in APISIX..."
SSL_IDS=$(curl -s "http://127.0.0.1:9180/apisix/admin/ssls" -H "X-API-KEY: BTLvdLB6XptSridgdmuV" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

if [ -n "$SSL_IDS" ]; then
    echo "Removing existing SSL configurations..."
    for ID in $SSL_IDS; do
        echo "Removing SSL configuration with ID: $ID"
        curl -X DELETE "http://127.0.0.1:9180/apisix/admin/ssls/$ID" -H "X-API-KEY: BTLvdLB6XptSridgdmuV"
    done
fi

# Upload SSL configuration with proper SNI
echo "Uploading new SSL configuration with proper SNI..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/ssls/1" \
     -H "X-API-KEY: BTLvdLB6XptSridgdmuV" \
     -H "Content-Type: application/json" \
     --data-binary @./ssl/cert.json

# Verify the new SSL configuration
echo "Verifying new SSL configuration..."
curl -s "http://127.0.0.1:9180/apisix/admin/ssls/1" -H "X-API-KEY: BTLvdLB6XptSridgdmuV"

# Restart APISIX to apply changes
echo "Restarting APISIX to apply changes..."
docker compose -f docker-compose.yml restart apisix

# Wait for APISIX to restart
echo "Waiting for APISIX to restart..."
sleep 15

# Test connection
echo "Testing HTTPS connection to $DOMAIN..."
curl -s -I -m 5 -k "https://$DOMAIN" || echo "Connection test failed"

echo
echo "SNI fix complete! Check if HTTPS is working now."
echo "You can run check-letsencrypt.sh again to verify the configuration."
echo
echo "If issues persist, check the APISIX logs with:"
echo "docker logs apisix"
