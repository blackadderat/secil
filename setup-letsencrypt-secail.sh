#!/bin/bash

# Script to add SSL support to the existing APISIX setup using Let's Encrypt Certbot
# This script is compatible with the existing docker-compose-apisix-secail.yml

# Define your domain names
API_DOMAIN="api.secompanion.de"  # Replace with your actual domain
DASHBOARD_DOMAIN="api.secompanion.de"  # Replace with your actual domain
EMAIL="rudi.maldaner@secompanion.de"  # Replace with your email for Let's Encrypt notifications

# Create necessary directories
mkdir -p ./ssl
mkdir -p ./conf/apisix
mkdir -p ./conf/dashboard
mkdir -p ./certbot/www
mkdir -p ./certbot/conf

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

# Create APISIX configuration file with SSL support
cat > ./conf/apisix/config.yaml << EOL
apisix:
  node_listen: 9080              # APISIX listening port
  ssl:
    enable: true
    listen_port: 9443            # HTTPS listening port
    ssl_protocols: TLSv1.2 TLSv1.3
    ssl_ciphers: ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
  enable_admin: true
  enable_ipv6: false
  enable_control: true
  control:
    ip: "0.0.0.0"
    port: 9180
  admin_key:
    - name: "admin"
      key: "edgex"
      role: admin

deployment:
  role: traditional
  role_traditional:
    config_provider: etcd

etcd:
  host:
    - "http://etcd:2379"
  prefix: "/apisix"
  timeout: 30

plugin_attr:
  prometheus:
    export_addr:
      ip: "0.0.0.0"
      port: 9091
EOL

# Create Dashboard configuration file
cat > ./conf/dashboard/conf.yaml << EOL
conf:
  listen:
    host: 0.0.0.0
    port: 9000
  etcd:
    endpoints:
      - etcd:2379
    username: ~
    password: ~
  log:
    error_log:
      level: warn
      file_path: /usr/local/apisix-dashboard/logs/error.log
    access_log:
      file_path: /usr/local/apisix-dashboard/logs/access.log
  allowed_origins: []
authentication:
  secret: secail-dashboard-secret  # Change this to a secure secret key
  expire_time: 3600  # JWT token expiration time in seconds
  users:
    - username: admin
      password: admin  # Change this to a secure password
    - username: user
      password: user  # Change this to a secure password
EOL

# Create a temporary Nginx configuration for Certbot challenge
cat > ./certbot/nginx.conf << EOL
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    keepalive_timeout  65;

    server {
        listen 80;
        server_name ${API_DOMAIN} ${DASHBOARD_DOMAIN};
        
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }
        
        location / {
            return 301 https://\$host\$request_uri;
        }
    }
}
EOL

# Create Docker Compose file for temporary Nginx and Certbot
cat > ./certbot-docker-compose.yml << EOL
version: '3'
services:
  nginx:
    image: nginx:alpine
    container_name: certbot-nginx
    ports:
      - "80:80"
    volumes:
      - ./certbot/nginx.conf:/etc/nginx/nginx.conf
      - ./certbot/www:/var/www/certbot
    restart: unless-stopped
EOL

echo "Configuration files created."
echo ""
echo "Let's Encrypt setup instructions:"
echo "---------------------------------"
echo ""
echo "1. Make sure your domain names (${API_DOMAIN} and ${DASHBOARD_DOMAIN}) point to this server's IP address."
echo ""
echo "2. Start the temporary Nginx server for Certbot challenge:"
echo "   docker-compose -f certbot-docker-compose.yml up -d"
echo ""
echo "3. Obtain certificates with Certbot (run this command):"
echo "   sudo certbot certonly --webroot -w ./certbot/www -d ${API_DOMAIN} -d ${DASHBOARD_DOMAIN} --email ${EMAIL} --agree-tos --non-interactive"
echo ""
echo "4. After obtaining certificates, copy them to the SSL directory:"
echo "   sudo cp /etc/letsencrypt/live/${API_DOMAIN}/fullchain.pem ./ssl/${API_DOMAIN}.crt"
echo "   sudo cp /etc/letsencrypt/live/${API_DOMAIN}/privkey.pem ./ssl/${API_DOMAIN}.key"
echo "   sudo cp /etc/letsencrypt/live/${DASHBOARD_DOMAIN}/fullchain.pem ./ssl/${DASHBOARD_DOMAIN}.crt"
echo "   sudo cp /etc/letsencrypt/live/${DASHBOARD_DOMAIN}/privkey.pem ./ssl/${DASHBOARD_DOMAIN}.key"
echo "   sudo chmod -R 755 ./ssl"
echo ""
echo "5. Stop the temporary Nginx server:"
echo "   docker-compose -f certbot-docker-compose.yml down"
echo ""
echo "6. Start your APISIX stack:"
echo "   docker-compose -f docker-compose-apisix-secail.yml up -d"
echo ""
echo "7. Configure APISIX to use the Let's Encrypt certificates:"
echo "   ./configure-ssl-routes.sh"
echo ""

# Create the configure-ssl-routes.sh script
cat > ./configure-ssl-routes.sh << EOL
#!/bin/bash

# Wait for APISIX to start up
echo "Waiting for APISIX to start up..."
sleep 10

# Create SSL certificate object in APISIX
echo "Creating SSL certificate object in APISIX..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/ssls/1" -H "X-API-KEY: edgex" -d '{
    "cert": "'"$(cat ./ssl/${API_DOMAIN}.crt | sed 's/$/\\n/' | tr -d '\n')"'",
    "key": "'"$(cat ./ssl/${API_DOMAIN}.key | sed 's/$/\\n/' | tr -d '\n')"'",
    "snis": ["${API_DOMAIN}"]
}'

curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/ssls/2" -H "X-API-KEY: edgex" -d '{
    "cert": "'"$(cat ./ssl/${DASHBOARD_DOMAIN}.crt | sed 's/$/\\n/' | tr -d '\n')"'",
    "key": "'"$(cat ./ssl/${DASHBOARD_DOMAIN}.key | sed 's/$/\\n/' | tr -d '\n')"'",
    "snis": ["${DASHBOARD_DOMAIN}"]
}'

# Create a route for the dashboard
echo "Creating route for the APISIX Dashboard..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/1" -H "X-API-KEY: edgex" -d '{
    "uri": "/*",
    "host": "${DASHBOARD_DOMAIN}",
    "upstream": {
        "type": "roundrobin",
        "nodes": {
            "apisix-dashboard:9000": 1
        }
    }
}'

# Create a route for your vendor-viasat-truck API
echo "Creating route for the Viasat Truck API..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/2" -H "X-API-KEY: edgex" -d '{
    "uri": "/vendor-viasat-truck/*",
    "host": "${API_DOMAIN}",
    "upstream": {
        "type": "roundrobin",
        "nodes": {
            "vendor-viasat-truck:7001": 1
        }
    }
}'

# Create routes for other services in your stack
echo "Creating routes for monitoring services..."
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/3" -H "X-API-KEY: edgex" -d '{
    "uri": "/prometheus/*",
    "host": "${API_DOMAIN}",
    "upstream": {
        "type": "roundrobin",
        "nodes": {
            "prometheus:9090": 1
        }
    }
}'

curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/4" -H "X-API-KEY: edgex" -d '{
    "uri": "/grafana/*",
    "host": "${API_DOMAIN}",
    "upstream": {
        "type": "roundrobin",
        "nodes": {
            "grafana:3000": 1
        }
    }
}'

curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/5" -H "X-API-KEY: edgex" -d '{
    "uri": "/jaeger/*",
    "host": "${API_DOMAIN}",
    "upstream": {
        "type": "roundrobin",
        "nodes": {
            "jaeger:16686": 1
        }
    }
}'

curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/routes/6" -H "X-API-KEY: edgex" -d '{
    "uri": "/httpbin/*",
    "host": "${API_DOMAIN}",
    "upstream": {
        "type": "roundrobin",
        "nodes": {
            "httpbin:8080": 1
        }
    }
}'

echo "APISIX SSL configuration complete!"
echo ""
echo "Access your services securely:"
echo "- Dashboard: https://${DASHBOARD_DOMAIN}:9443"
echo "- API: https://${API_DOMAIN}:9443/vendor-viasat-truck/"
echo "- Prometheus: https://${API_DOMAIN}:9443/prometheus/"
echo "- Grafana: https://${API_DOMAIN}:9443/grafana/"
echo "- Jaeger: https://${API_DOMAIN}:9443/jaeger/"
echo "- HTTPBin: https://${API_DOMAIN}:9443/httpbin/"
echo ""
echo "Setting up automatic renewal for Let's Encrypt certificates..."
echo "Creating a cron job for certificate renewal..."

# Create a renewal script
cat > ./renew-certs.sh << RENEW
#!/bin/bash
# Renew certificates
certbot renew --noninteractive

# Copy renewed certificates to APISIX
if [ -f /etc/letsencrypt/live/${API_DOMAIN}/fullchain.pem ]; then
    cp /etc/letsencrypt/live/${API_DOMAIN}/fullchain.pem ./ssl/${API_DOMAIN}.crt
    cp /etc/letsencrypt/live/${API_DOMAIN}/privkey.pem ./ssl/${API_DOMAIN}.key
    chmod 644 ./ssl/${API_DOMAIN}.crt ./ssl/${API_DOMAIN}.key
fi

if [ -f /etc/letsencrypt/live/${DASHBOARD_DOMAIN}/fullchain.pem ]; then
    cp /etc/letsencrypt/live/${DASHBOARD_DOMAIN}/fullchain.pem ./ssl/${DASHBOARD_DOMAIN}.crt
    cp /etc/letsencrypt/live/${DASHBOARD_DOMAIN}/privkey.pem ./ssl/${DASHBOARD_DOMAIN}.key
    chmod 644 ./ssl/${DASHBOARD_DOMAIN}.crt ./ssl/${DASHBOARD_DOMAIN}.key
fi

# Update certificates in APISIX
curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/ssls/1" -H "X-API-KEY: edgex" -d '{
    "cert": "'"$(cat ./ssl/${API_DOMAIN}.crt | sed 's/$/\\\\n/' | tr -d '\n')"'",
    "key": "'"$(cat ./ssl/${API_DOMAIN}.key | sed 's/$/\\\\n/' | tr -d '\n')"'",
    "snis": ["${API_DOMAIN}"]
}'

curl -i -X PUT "http://127.0.0.1:9180/apisix/admin/ssls/2" -H "X-API-KEY: edgex" -d '{
    "cert": "'"$(cat ./ssl/${DASHBOARD_DOMAIN}.crt | sed 's/$/\\\\n/' | tr -d '\n')"'",
    "key": "'"$(cat ./ssl/${DASHBOARD_DOMAIN}.key | sed 's/$/\\\\n/' | tr -d '\n')"'",
    "snis": ["${DASHBOARD_DOMAIN}"]
}'
RENEW

chmod +x ./renew-certs.sh

echo "Adding cron job for certificate renewal..."
(crontab -l 2>/dev/null; echo "0 3 * * * $(pwd)/renew-certs.sh > $(pwd)/renewal.log 2>&1") | crontab -

echo "Let's Encrypt certificates will be automatically renewed."
EOL

chmod +x ./configure-ssl-routes.sh

# Create a script to automate the entire process
cat > ./setup-letsencrypt-ssl.sh << EOL
#!/bin/bash

# Set your domain names and email
API_DOMAIN="${API_DOMAIN}"
DASHBOARD_DOMAIN="${DASHBOARD_DOMAIN}"
EMAIL="${EMAIL}"

# Update script files with actual domain names
sed -i "s/\${API_DOMAIN}/$API_DOMAIN/g" ./configure-ssl-routes.sh
sed -i "s/\${DASHBOARD_DOMAIN}/$DASHBOARD_DOMAIN/g" ./configure-ssl-routes.sh

# Start the temporary Nginx server for Certbot challenge
echo "Starting temporary Nginx server for Certbot challenge..."
docker-compose -f certbot-docker-compose.yml up -d

# Wait for Nginx to start
sleep 5

# Obtain certificates with Certbot
echo "Obtaining Let's Encrypt certificates..."
sudo certbot certonly --webroot -w ./certbot/www -d $API_DOMAIN -d $DASHBOARD_DOMAIN --email $EMAIL --agree-tos --non-interactive

# Copy certificates to SSL directory
echo "Copying certificates to SSL directory..."
sudo mkdir -p ./ssl
sudo cp /etc/letsencrypt/live/$API_DOMAIN/fullchain.pem ./ssl/$API_DOMAIN.crt
sudo cp /etc/letsencrypt/live/$API_DOMAIN/privkey.pem ./ssl/$API_DOMAIN.key
sudo cp /etc/letsencrypt/live/$DASHBOARD_DOMAIN/fullchain.pem ./ssl/$DASHBOARD_DOMAIN.crt
sudo cp /etc/letsencrypt/live/$DASHBOARD_DOMAIN/privkey.pem ./ssl/$DASHBOARD_DOMAIN.key
sudo chmod -R 755 ./ssl

# Stop the temporary Nginx server
echo "Stopping temporary Nginx server..."
docker-compose -f certbot-docker-compose.yml down

# Start APISIX stack
echo "Starting APISIX stack..."
docker-compose -f docker-compose-apisix-secail.yml up -d

# Wait for APISIX to start
sleep 15

# Configure APISIX to use Let's Encrypt certificates
echo "Configuring APISIX with Let's Encrypt certificates..."
./configure-ssl-routes.sh

echo "Setup complete! Your APISIX stack is now running with Let's Encrypt SSL certificates."
EOL

chmod +x ./setup-letsencrypt-ssl.sh

echo "Setup scripts created!"
echo "Replace the domain names and email in the scripts with your actual values."
echo "Then run ./setup-letsencrypt-ssl.sh to set up Let's Encrypt SSL for your APISIX stack."
