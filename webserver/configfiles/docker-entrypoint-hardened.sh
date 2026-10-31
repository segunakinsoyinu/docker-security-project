#!/bin/sh
set -e

# Create runtime directories (tmpfs mount starts empty)
mkdir -p /run/nginx /run/php

# Create Nginx temp directories (required for proper operation)
mkdir -p /var/lib/nginx/tmp/client_body
mkdir -p /var/lib/nginx/tmp/proxy
mkdir -p /var/lib/nginx/tmp/fastcgi
mkdir -p /var/lib/nginx/tmp/uwsgi
mkdir -p /var/lib/nginx/tmp/scgi

# Verify directories were created successfully
if [ ! -d "/run/nginx" ] || [ ! -d "/run/php" ] || [ ! -d "/var/lib/nginx/tmp/client_body" ]; then
    echo "Error: Failed to create required directories!"
    exit 1
fi

echo "Runtime directories created successfully"

# Start PHP-FPM in background using the main configuration
php-fpm82 --fpm-config /etc/php82/php-fpm.conf

# Start Nginx in foreground  
exec nginx -g "daemon off;"
