#!/bin/bash

# Create the storage directory if it doesn't exist
mkdir -p /opt/store-scripts/o11y-pub

# Create the nginx config for o11y.pub
cat > /opt/store-scripts/o11y-pub/o11y-pub.conf << 'EOF'
server {
        listen 80;
        listen [::]:80;
        root /var/www/html;
        index index.html index.htm index.nginx-debian.html;
        server_name o11y.pub;
        location / {
                proxy_pass http://172.17.0.2:80;
                include proxy_params;
        }
        error_log /var/log/nginx/o11y.error;
        access_log /var/log/nginx/o11y.access;
}
EOF

# Create the nginx config for www.o11y.pub
cat > /opt/store-scripts/o11y-pub/www-o11y-pub.conf << 'EOF'
server {
        listen 80;
        listen [::]:80;
        root /var/www/html;
        index index.html index.htm index.nginx-debian.html;
        server_name www.o11y.pub;
        location / {
                proxy_pass http://172.17.0.99:80;
                include proxy_params;
        }
        error_log /var/log/nginx/www-o11y.error;
        access_log /var/log/nginx/www-o11y.access;
}
EOF

# Create the nginx config for 01.wbsrv.mpit.onboard
cat > /opt/store-scripts/o11y-pub/01-wbsrv-mpit-onboard.conf << 'EOF'
server {
        listen 80;
        listen [::]:80;
        root /var/www/01-wbsrv-mpit-onboard;
        index index.html index.htm;
        server_name 01.wbsrv.mpit.onboard;
        
        location / {
                try_files $uri $uri/ =404;
        }
        
        error_log /var/log/nginx/01-wbsrv-mpit.error;
        access_log /var/log/nginx/01-wbsrv-mpit.access;
}
EOF

# Create directory and index.html for 01.wbsrv.mpit.onboard
mkdir -p /var/www/01-wbsrv-mpit-onboard
cat > /var/www/01-wbsrv-mpit-onboard/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Hello World</title>
</head>
<body>
    <h1>hello world</h1>
</body>
</html>
EOF

# Create default server block to catch unrecognized requests
cat > /opt/store-scripts/o11y-pub/00-default.conf << 'EOF'
server {
        listen 80 default_server;
        listen [::]:80 default_server;
        listen 443 ssl default_server;
        listen [::]:443 ssl default_server;
        
        # Self-signed cert for default SSL (will be replaced if needed)
        ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
        ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;
        
        server_name _;
        
        location / {
                return 444;
        }
        
        error_log /var/log/nginx/default.error;
        access_log /var/log/nginx/default.access;
}
EOF

# Copy configs from local storage to nginx sites-available
cp /opt/store-scripts/o11y-pub/o11y-pub.conf /etc/nginx/sites-available/o11y-pub.conf
cp /opt/store-scripts/o11y-pub/www-o11y-pub.conf /etc/nginx/sites-available/www-o11y-pub.conf
cp /opt/store-scripts/o11y-pub/01-wbsrv-mpit-onboard.conf /etc/nginx/sites-available/01-wbsrv-mpit-onboard.conf
cp /opt/store-scripts/o11y-pub/00-default.conf /etc/nginx/sites-available/00-default.conf

# Remove any existing default site that might conflict
sudo rm -f /etc/nginx/sites-enabled/default

# Create symbolic links to enable the sites
sudo ln -s /etc/nginx/sites-available/00-default.conf /etc/nginx/sites-enabled/00-default.conf
sudo ln -s /etc/nginx/sites-available/www-o11y-pub.conf /etc/nginx/sites-enabled/www-o11y-pub.conf
sudo ln -s /etc/nginx/sites-available/o11y-pub.conf /etc/nginx/sites-enabled/o11y-pub.conf
sudo ln -s /etc/nginx/sites-available/01-wbsrv-mpit-onboard.conf /etc/nginx/sites-enabled/01-wbsrv-mpit-onboard.conf

# Restart nginx to apply changes
sudo systemctl restart nginx

# Get SSL certificates from Let's Encrypt
certbot --nginx --non-interactive --agree-tos --domains o11y.pub --email jr@cribl.io
certbot --nginx --non-interactive --agree-tos --domains www.o11y.pub --email jr@cribl.io
certbot --nginx --non-interactive --agree-tos --domains 01.wbsrv.mpit.onboard --email jr@cribl.io

# Create directory for Apache content
mkdir -p /opt/docker/apache/html/

# Download the index.html from GitHub
curl -o /opt/docker/apache/html/index.html "https://raw.githubusercontent.com/cribl-jr/splashpages_011y-pub/refs/heads/main/html/index.html"

# Start the Apache container
docker run -dit --name my-apache-app -p 8080:80 -v "/opt/docker/apache/html/":"/usr/local/apache2/htdocs/" httpd:2.4
