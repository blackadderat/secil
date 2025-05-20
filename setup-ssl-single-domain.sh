#!/bin/bash

# Set your domain name and email
DOMAIN="api.secompanion"
EMAIL="rudi.maldaner@secompanion.de"

# Update script files with actual domain names
sed -i "s/${DOMAIN}/api.secompanion/g" ./configure-routes.sh

# Start the temporary Nginx server for Certbot challenge
echo "Starting temporary Nginx server for Certbot challenge..."
docker compose -f certbot-docker-compose.yml up -d

# Wait for Nginx to start
sleep 5

# Obtain certificates with Certbot
echo "Obtaining Let's Encrypt certificates..."
sudo certbot certonly --webroot -w ./certbot/www -d api.secompanion --email rudi.maldaner@secompanion.de --agree-tos --non-interactive

# Copy certificates to SSL directory
echo "Copying certificates to SSL directory..."
sudo mkdir -p ./ssl
sudo cp /etc/letsencrypt/live/api.secompanion/fullchain.pem ./ssl/api.secompanion.crt
sudo cp /etc/letsencrypt/live/api.secompanion/privkey.pem ./ssl/api.secompanion.key
sudo chmod -R 755 ./ssl

# Stop the temporary Nginx server
echo "Stopping temporary Nginx server..."
docker compose -f certbot-docker-compose.yml down

# Start APISIX stack
echo "Starting APISIX stack..."
docker compose -f docker-compose-apisix-secail.yml up -d

# Wait for APISIX to start
sleep 15

# Configure APISIX to use Let's Encrypt certificates
echo "Configuring APISIX with Let's Encrypt certificates and routes..."
./configure-routes.sh

echo "Setup complete! Your APISIX stack is now running with Let's Encrypt SSL certificates."
echo "All services are accessible under https://api.secompanion/ with path-based routing."
