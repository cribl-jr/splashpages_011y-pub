#!/bin/bash
curl -o /etc/nginx/sites-available/www-011y-pub.conf "https://raw.githubusercontent.com/cribl-jr/training_labs/main/www-o11y-pub.conf"
curl -o /etc/nginx/sites-available/011y-pub.conf "https://raw.githubusercontent.com/cribl-jr/training_labs/main/o11y-pub.conf"
sudo ln -s /etc/nginx/sites-available/www-011y-pub.conf /etc/nginx/sites-enabled/www-011y-pub.conf
sudo ln -s /etc/nginx/sites-available/011y-pub.conf /etc/nginx/sites-enabled/o11y-pub.conf
sudo systemctl restart nginx
certbot --nginx --non-interactive --agree-tos --domains o11y.pub --email jr@cribl.io
certbot --nginx --non-interactive --agree-tos --domains www.o11y.pub --email jr@cribl.io
mkdir -p /opt/docker/apache/html/
touch /opt/docker/apache/html/index.html
curl -o /opt/docker/apache/html/index.html "https://raw.githubusercontent.com/cribl-jr/training_labs/main/o11y-pub-index.html"
#cat o11y-pub-index.html | tee -a /opt/docker/apache/html/index.html
docker run -dit --name my-apache-app -p 8080:80 -v "/opt/docker/apache/html/":"/usr/local/apache2/htdocs/" httpd:2.4
