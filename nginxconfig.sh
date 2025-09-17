Filename: **safecode\_1.sh**

```bash
#!/usr/bin/env bash
# Consolidated Nginx lab setup:
# - o11y.pub        (reverse proxy to healthy backend container)
# - www.o11y.pub    (reverse proxy to intentional bad upstream for troubleshooting)
# - 01.wbsrv.mpit.onboard (static site with TLS; dual-stack)
#
# All configs are first written to /opt/websrv/config_files, then linked into Nginx.
# Only external fetch: o11y.pub index.html from O11Y_INDEX_URL (default set below).
#
# Usage:
#   sudo -E bash safecode_1.sh
#   DO_INSTALL=1 RUN_CERTBOT=1 EMAIL=you@example.com sudo -E bash safecode_1.sh

set -euo pipefail

### ---------- Tunables ----------
CONFIG_DIR="${CONFIG_DIR:-/opt/websrv/config_files}"
STATIC_ROOT="${STATIC_ROOT:-/opt/store_websrv}"
APACHE_VOL="${APACHE_VOL:-/opt/docker/apache/html}"
# Default to the corrected URL (HTML index)
O11Y_INDEX_URL="${O11Y_INDEX_URL:-https://raw.githubusercontent.com/cribl-jr/splashpages_011y-pub/refs/heads/main/html/index.html}"
DO_INSTALL="${DO_INSTALL:-0}"          # 1 = apt-get install nginx certbot docker curl
RUN_CERTBOT="${RUN_CERTBOT:-1}"        # 1 = request/expand certs with certbot --nginx
EMAIL="${EMAIL:-}"                     # certbot email; if empty uses --register-unsafely-without-email
# Domains
DOMAIN_O11Y="o11y.pub"
DOMAIN_WWW_O11Y="www.o11y.pub"
DOMAIN_ONBOARD="01.wbsrv.mpit.onboard"
# Intentional bad upstream for troubleshooting lab
BAD_UPSTREAM_IP="172.17.0.99"

### ---------- Helpers ----------
log() { printf '%s\n' "[$(date +'%F %T')] $*"; }

install_prereqs() {
  log "Installing prerequisites (nginx, certbot, docker.io, curl)…"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y nginx certbot python3-certbot-nginx docker.io curl
  systemctl enable --now nginx docker || true
}

ensure_dirs() {
  mkdir -p "${CONFIG_DIR}"
  mkdir -p "${STATIC_ROOT}/${DOMAIN_ONBOARD}/public"
  mkdir -p "${APACHE_VOL}"
}

start_backend_container() {
  # Healthy backend for o11y.pub
  local cid=""
  if command -v docker >/dev/null 2>&1; then
    if ! docker ps --format '{{.Names}}' | grep -q '^healthyweb$'; then
      if ! docker ps -a --format '{{.Names}}' | grep -q '^healthyweb$'; then
        log "Starting httpd:2.4 container 'healthyweb' publishing 8080->80…"
        docker run -d --name healthyweb -p 8080:80 -v "${APACHE_VOL}":/usr/local/apache2/htdocs:ro httpd:2.4
      else
        log "Container 'healthyweb' exists but not running. Starting…"
        docker start healthyweb
      fi
    fi
    cid="$(docker ps --filter name=^healthyweb$ --format '{{.ID}}')"
    if [[ -n "${cid}" ]]; then
      local ip
      ip="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${cid}")"
      if [[ -n "${ip}" ]]; then
        echo "${ip}"
        return 0
      fi
    fi
  fi
  # Fallback when Docker is not available
  echo "127.0.0.1:8080"
}

write_local_content() {
  # External fetch for o11y.pub index
  if [[ -n "${O11Y_INDEX_URL}" ]]; then
    log "Fetching o11y.pub index from ${O11Y_INDEX_URL}"
    if ! curl -fsSL "${O11Y_INDEX_URL}" -o "${APACHE_VOL}/index.html"; then
      log "Fetch failed; writing local fallback for ${DOMAIN_O11Y}"
      cat > "${APACHE_VOL}/index.html" <<'HTML'
<!doctype html><html><body><h1>o11y.pub fallback</h1><p>Remote fetch failed; local page served.</p></body></html>
HTML
    fi
  fi

  # Custom static index for 01.wbsrv.mpit.onboard
  cat > "${STATIC_ROOT}/${DOMAIN_ONBOARD}/public/index.html" <<'HTML'
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>01.wbsrv.mpit.onboard</title>
<style>
body { font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif; margin: 3rem; }
.card { max-width: 48rem; border: 1px solid #ddd; padding: 2rem; border-radius: 12px; }
code { background: #f6f8fa; padding: .15rem .35rem; border-radius: 6px; }
</style>
</head>
<body>
  <div class="card">
    <h1>It works: 01.wbsrv.mpit.onboard</h1>
    <p>Served by Nginx from <code>/opt/store_websrv/01.wbsrv.mpit.onboard/public/</code>.</p>
    <ul>
      <li>HTTP on 80 and HTTPS on 443</li>
      <li>Dual-stack listeners</li>
      <li>Nginx troubleshooting lab</li>
    </ul>
  </div>
</body>
</html>
HTML
}

write_nginx_confs() {
  local o11y_upstream="$1"

  local O11Y_PROXY
  if [[ "${o11y_upstream}" == *:* ]]; then
    O11Y_PROXY="http://${o11y_upstream}"
  else
    O11Y_PROXY="http://${o11y_upstream}:80"
  fi

  # o11y.pub — good upstream
  cat > "${CONFIG_DIR}/o11y-pub.conf" <<NGINX
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN_O11Y};

    access_log /var/log/nginx/o11y.access.log;
    error_log  /var/log/nginx/o11y.error.log;

    location / {
        proxy_pass ${O11Y_PROXY};
        include proxy_params;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }
}
NGINX

  # www.o11y.pub — intentionally bad upstream
  cat > "${CONFIG_DIR}/www-o11y-pub.conf" <<NGINX
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN_WWW_O11Y};

    access_log /var/log/nginx/www-o11y.access.log;
    error_log  /var/log/nginx/www-o11y.error.log;

    location / {
        proxy_pass http://${BAD_UPSTREAM_IP}:80;
        include proxy_params;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }
}
NGINX

  # 01.wbsrv.mpit.onboard — static site, dual stack; certbot will inject HTTPS
  cat > "${CONFIG_DIR}/01-wbsrv-mpit-onboard.conf" <<NGINX
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN_ONBOARD};

    access_log /var/log/nginx/01-wbsrv-mpit-onboard.access.log;
    error_log  /var/log/nginx/01-wbsrv-mpit-onboard.error.log;

    root ${STATIC_ROOT}/${DOMAIN_ONBOARD}/public;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
NGINX
}

deploy_nginx_confs() {
  for f in "${CONFIG_DIR}/"*.conf; do
    cp -f "$f" /etc/nginx/sites-available/
    ln -sf "/etc/nginx/sites-available/$(basename "$f")" "/etc/nginx/sites-enabled/$(basename "$f")"
  done
  nginx -t
  if command -v systemctl >/dev/null 2>&1; then
    systemctl reload nginx
  else
    service nginx reload
  fi
}

run_certbot_for() {
  local domain="$1"
  [[ "${RUN_CERTBOT}" == "1" ]] || { log "Skipping certbot for ${domain}"; return 0; }
  log "Requesting certificate for ${domain} via certbot --nginx"
  if [[ -n "${EMAIL}" ]]; then
    certbot --nginx -d "${domain}" --non-interactive --agree-tos --redirect -m "${EMAIL}"
  else
    certbot --nginx -d "${domain}" --non-interactive --agree-tos --redirect --register-unsafely-without-email
  fi
}

certbot_all() {
  run_certbot_for "${DOMAIN_O11Y}"
  run_certbot_for "${DOMAIN_WWW_O11Y}"
  run_certbot_for "${DOMAIN_ONBOARD}"
  nginx -t
  if command -v systemctl >/dev/null 2>&1; then
    systemctl reload nginx
  else
    service nginx reload
  fi
}

### ---------- Main ----------
[[ "${DO_INSTALL}" == "1" ]] && install_prereqs
ensure_dirs
O11Y_UPSTREAM="$(start_backend_container)"
write_local_content
write_nginx_confs "${O11Y_UPSTREAM}"
deploy_nginx_confs
certbot_all

log "Done."
log "Configs: ${CONFIG_DIR}"
log "Static root: ${STATIC_ROOT}/${DOMAIN_ONBOARD}/public"
log "Healthy upstream for ${DOMAIN_O11Y}: ${O11Y_UPSTREAM}"
log "Troubleshooting upstream for ${DOMAIN_WWW_O11Y}: ${BAD_UPSTREAM_IP}"
```
