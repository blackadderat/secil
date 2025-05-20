#!/bin/bash

# This script checks the status of Let's Encrypt certificates
DOMAIN="api.secompanion.de"

echo "=== Let's Encrypt Certificate Check ==="
echo

# Check if Certbot is installed
echo -n "1. Checking if Certbot is installed... "
if command -v certbot &> /dev/null; then
    echo "OK"
    echo "   $(certbot --version)"
else
    echo "FAILED"
    echo "   Certbot is not installed. Install it first."
    exit 1
fi

# Check if certificates exist
echo -n "2. Checking if Let's Encrypt certificates exist for $DOMAIN... "
if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    echo "OK"
    echo "   Certificates found in /etc/letsencrypt/live/$DOMAIN"
    
    # Check certificate expiration date
    echo -n "3. Checking certificate expiration date... "
    EXPIRATION_DATE=$(sudo openssl x509 -enddate -noout -in /etc/letsencrypt/live/$DOMAIN/fullchain.pem | cut -d= -f2)
    EXPIRATION_SECONDS=$(sudo date -d "$EXPIRATION_DATE" +%s)
    CURRENT_SECONDS=$(date +%s)
    DAYS_LEFT=$(( ($EXPIRATION_SECONDS - $CURRENT_SECONDS) / 86400 ))
    
    echo "$DAYS_LEFT days left"
    if [ $DAYS_LEFT -lt 15 ]; then
        echo "   WARNING: Certificate will expire in less than 15 days."
    fi
else
    echo "FAILED"
    echo "   No Let's Encrypt certificates found for $DOMAIN"
    echo "   Run setup-letsencrypt.sh to obtain certificates."
    exit 1
fi

# Check if certificates are copied to the SSL directory
echo -n "4. Checking if certificates are copied to the SSL directory... "
if [ -f "ssl/$DOMAIN.crt" ] && [ -f "ssl/$DOMAIN.key" ]; then
    echo "OK"
else
    echo "FAILED"
    echo "   Certificates are not copied to ssl/ directory."
    echo "   Copy them manually:"
    echo "   sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ssl/$DOMAIN.crt"
    echo "   sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ssl/$DOMAIN.key"
    echo "   sudo chmod 644 ssl/$DOMAIN.crt ssl/$DOMAIN.key"
fi

# Check SSL configuration in APISIX
echo -n "5. Checking if SSL certificate is configured in APISIX... "
SSL_RESPONSE=$(curl -s "http://127.0.0.1:9180/apisix/admin/ssls" -H "X-API-KEY: BTLvdLB6XptSridgdmuV")
if [[ "$SSL_RESPONSE" == *"\"total\":0"* ]]; then
    echo "FAILED"
    echo "   No SSL certificates found in APISIX."
else
    echo "OK"
    COUNT=$(echo $SSL_RESPONSE | grep -o '"total":[0-9]*' | cut -d ":" -f2)
    echo "   Found $COUNT SSL certificate(s) configured in APISIX."
    
    echo "   Details of configured SSL certificates:"
    curl -s "http://127.0.0.1:9180/apisix/admin/ssls" -H "X-API-KEY: BTLvdLB6XptSridgdmuV" | \
        grep -o '"snis":\[[^]]*\]' || echo "   No SNIs found in certificates."
fi

# Check port mapping in docker-compose file
echo -n "6. Checking port mapping in docker-compose file... "
if grep -q "80:9080" docker-composel.yml && grep -q "443:9443" docker-composel.yml; then
    echo "OK"
else
    echo "FAILED"
    echo "   Port mapping not properly configured in docker-composel.yml."
    echo "   Add the following to the apisix service ports section:"
    echo "   - \"80:9080\""
    echo "   - \"443:9443\""
fi

# Check if APISIX is running
echo -n "7. Checking if APISIX is running... "
if docker ps --filter name=apisix --format "{{.Names}}: {{.Status}}" | grep -q "Up"; then
    echo "OK"
    echo "   $(docker ps --filter name=apisix --format "{{.Names}}: {{.Status}}")"
else
    echo "FAILED"
    echo "   APISIX container is not running."
    echo "   Start it with: docker compose -f docker-composel.yml up -d apisix"
fi

# Test HTTPS connection
echo "8. Testing HTTPS connection..."
HTTPS_RESPONSE=$(curl -s -I -m 5 "https://$DOMAIN" || echo "Failed to connect")
if [[ "$HTTPS_RESPONSE" == *"200"* ]] || [[ "$HTTPS_RESPONSE" == *"302"* ]] || [[ "$HTTPS_RESPONSE" == *"404"* ]]; then
    echo "   OK - HTTPS connection works (status code found)"
else
    echo "   FAILED - HTTPS connection issue"
    echo "   Response:"
    echo "$HTTPS_RESPONSE"
fi

# Check TLS/SSL information
echo "9. Checking TLS/SSL information:"
echo "   $ openssl s_client -connect ${DOMAIN}:443 -servername ${DOMAIN} </dev/null 2>/dev/null | grep 'subject\|issuer'"
openssl s_client -connect ${DOMAIN}:443 -servername ${DOMAIN} </dev/null 2>/dev/null | grep "subject\|issuer" || echo "   Failed to get TLS information"

# Check renewal configuration
echo -n "10. Checking renewal configuration... "
if crontab -l 2>/dev/null | grep -q "renew-letsencrypt.sh"; then
    echo "OK"
    echo "   Renewal cron job is configured:"
    crontab -l | grep "renew-letsencrypt.sh"
else
    echo "FAILED"
    echo "   No renewal cron job found."
    echo "   Add it with: (crontab -l 2>/dev/null; echo \"0 3 * * * $(pwd)/renew-letsencrypt.sh > $(pwd)/renewal.log 2>&1\") | crontab -"
fi

echo
echo "Let's Encrypt certificate check complete!"
echo "If any checks failed, refer to the instructions above to fix them."
echo "You can also run fix-port-conflict.sh to reconfigure everything."
